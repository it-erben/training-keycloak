<#
.SYNOPSIS
Richtet die Workshop-Domaene auf dem Windows-Gast ein (drei Phasen mit Neustarts).

.DESCRIPTION
Phase 1: Datendisk initialisieren, Rechner in dc01 umbenennen, Neustart.
Phase 2: AD DS installieren, lokales Administratorkonto setzen, Forest promoten, Neustart.
Phase 3: DNS-Forwarder, Zeitquelle, Firewall und Verzeichnisse nach der Promotion.
Jeder Aufruf erkennt seine Phase selbst. Eine fremde vorhandene Domaene fuehrt zum Abbruch.
Aufruf in einer PowerShell als Administrator: .\Initialize-Domain.ps1
#>
#Requires -RunAsAdministrator
[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'Unattended', Justification = 'in Read-ConfirmedPassword verwendet')]
param(
    [string]$DomainName = 'ad.mustertech.test',
    [string]$NetbiosName = 'MUSTERTECH',
    [string]$ComputerName = 'dc01',
    [char]$DataDriveLetter = 'D',
    [string]$StatePath = 'C:\Workshop\state',
    [switch]$Unattended
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Path $StatePath -Force | Out-Null

function Write-State {
    param([string]$Phase, [hashtable]$Data)
    $state = [ordered]@{ phase = $Phase; at = (Get-Date).ToUniversalTime().ToString('o') }
    foreach ($k in $Data.Keys) { $state[$k] = $Data[$k] }
    $state | ConvertTo-Json | Set-Content (Join-Path $StatePath 'domain.json') -Encoding utf8
}

function Initialize-DataDisk {
    $vol = Get-Volume -ErrorAction SilentlyContinue | Where-Object { $_.FileSystemLabel -eq 'ADDS' }
    if ($vol) { Write-Host "Datendisk vorhanden: $($vol.DriveLetter):"; return }
    $raw = @(Get-Disk | Where-Object { $_.PartitionStyle -eq 'RAW' })
    if ($raw.Count -ne 1) { throw "Erwartet genau eine RAW-Disk fuer AD DS, gefunden: $($raw.Count)" }
    Write-Host "Initialisiere Datendisk $($raw[0].Number) ($([math]::Round($raw[0].Size / 1GB)) GB) als ${DataDriveLetter}:"
    Initialize-Disk -Number $raw[0].Number -PartitionStyle GPT
    New-Partition -DiskNumber $raw[0].Number -UseMaximumSize -DriveLetter $DataDriveLetter |
        Format-Volume -FileSystem NTFS -NewFileSystemLabel 'ADDS' -Confirm:$false | Out-Null
}

function Read-ConfirmedPassword {
    # Interaktiv mit Wiederholung; mit -Unattended je eine Zeile von stdin (etwa ueber eine SSH-Sitzung, nie aus Metadaten).
    param([string]$Prompt)
    if ($Unattended) {
        $line = [Console]::In.ReadLine()
        if ([string]::IsNullOrEmpty($line) -or $line.Length -lt 14) { throw "Unattended: Passwort fuer '$Prompt' fehlt oder ist kuerzer als 14 Zeichen" }
        return (ConvertTo-SecureString $line -AsPlainText -Force)
    }
    while ($true) {
        $a = Read-Host -AsSecureString $Prompt
        $b = Read-Host -AsSecureString 'Wiederholen'
        $pa = [System.Net.NetworkCredential]::new('', $a).Password
        $pb = [System.Net.NetworkCredential]::new('', $b).Password
        if ($pa -ne $pb) { Write-Warning 'Passwoerter stimmen nicht ueberein'; continue }
        if ($pa.Length -lt 14) { Write-Warning 'Mindestens 14 Zeichen'; continue }
        return $a
    }
}

$role = (Get-CimInstance Win32_ComputerSystem).DomainRole   # 4 = Backup DC, 5 = Primary DC
if ($role -ge 4) {
    Import-Module ActiveDirectory
    $d = Get-ADDomain
    if ($d.DNSRoot -ne $DomainName) { throw "Dieser Server ist Domain Controller der fremden Domaene $($d.DNSRoot). Abbruch." }

    Write-Host "Phase 3: Nacharbeiten fuer $($d.DNSRoot)"
    # Fremde Namen loest der Metadaten-Resolver auf; die eigene Zone beantwortet der DC.
    Set-DnsServerForwarder -IPAddress 169.254.169.254 -UseRootHint $false
    & w32tm /config /manualpeerlist:"metadata.google.internal" /syncfromflags:manual /reliable:yes /update | Out-Null
    Restart-Service w32time
    & w32tm /resync /nowait | Out-Null

    $ldaps = Get-NetFirewallRule -DisplayName 'Active Directory Domain Controller - Secure LDAP (TCP-In)' -ErrorAction SilentlyContinue
    if (-not $ldaps) {
        New-NetFirewallRule -DisplayName 'Workshop LDAPS 636' -Direction Inbound -Protocol TCP -LocalPort 636 -Action Allow | Out-Null
    } elseif (-not $ldaps.Enabled) {
        Enable-NetFirewallRule -DisplayName $ldaps.DisplayName
    }
    New-Item -ItemType Directory -Path 'C:\Workshop\out', 'C:\Workshop\secrets' -Force | Out-Null

    $kms = Test-NetConnection kms.windows.googlecloud.com -Port 1688 -WarningAction SilentlyContinue
    $license = Get-CimInstance SoftwareLicensingProduct -Filter "PartialProductKey IS NOT NULL AND Name LIKE 'Windows%'" | Select-Object -First 1
    Write-State -Phase 'ready' -Data @{ domain = $d.DNSRoot; dc = "$env:COMPUTERNAME.$($d.DNSRoot)".ToLower(); kmsReachable = $kms.TcpTestSucceeded; licenseStatus = $license.LicenseStatus }
    Write-Host "Domaene $($d.DNSRoot) bereit. KMS erreichbar: $($kms.TcpTestSucceeded), Lizenzstatus: $($license.LicenseStatus) (1 = lizenziert)."
    Write-Host 'Naechster Schritt: Anmeldung als Domaenen-Administrator pruefen, dann Initialize-Workshop.ps1.'
    return
}

if ($env:COMPUTERNAME -ne $ComputerName.ToUpper()) {
    Write-Host "Phase 1: Datendisk und Umbenennung $env:COMPUTERNAME -> $ComputerName"
    Initialize-DataDisk
    Write-State -Phase 'renamed' -Data @{ from = $env:COMPUTERNAME; to = $ComputerName }
    Write-Host 'Neustart. Danach erneut anmelden und dieses Skript erneut ausfuehren.'
    Rename-Computer -NewName $ComputerName -Force
    Restart-Computer -Force
    return
}

Write-Host "Phase 2: AD DS installieren und Forest $DomainName promoten"
Initialize-DataDisk
Install-WindowsFeature AD-Domain-Services, DNS -IncludeManagementTools | Out-Null

# Das eingebaute Administratorkonto wird mit der Promotion zum Domaenen-Administrator;
# das per gcloud angelegte lokale Konto verschwindet dabei.
$adminPw = Read-ConfirmedPassword -Prompt "Passwort fuer $NetbiosName\Administrator (Domaenen-Admin nach der Promotion)"
Enable-LocalUser -Name Administrator
Set-LocalUser -Name Administrator -Password $adminPw -PasswordNeverExpires $true
$dsrm = Read-ConfirmedPassword -Prompt 'DSRM-Passwort (Directory Services Restore Mode)'

Write-State -Phase 'promoting' -Data @{ domain = $DomainName }
Import-Module ADDSDeployment
Install-ADDSForest -DomainName $DomainName -DomainNetbiosName $NetbiosName `
    -DatabasePath "${DataDriveLetter}:\NTDS" -LogPath "${DataDriveLetter}:\NTDS" -SysvolPath "${DataDriveLetter}:\SYSVOL" `
    -InstallDns -SafeModeAdministratorPassword $dsrm -Force -NoRebootOnCompletion:$false
