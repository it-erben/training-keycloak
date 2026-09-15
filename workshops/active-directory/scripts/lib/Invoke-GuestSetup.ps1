<#
.SYNOPSIS
Fuehrt die Gastseite einer Workshop-Umgebung ueber SSH per IAP aus, ohne RDP.

.DESCRIPTION
Erwartet eine mit New-Workshop.ps1 -TrainerSsh angelegte Umgebung. Oeffnet einen IAP-Tunnel auf
einen lokalen Port, erkennt den Zustand des Gastes und fuehrt die fehlenden Schritte aus:
Neustart fuer das SSH-Startskript, Initialize-Domain.ps1 in drei Phasen (Passwoerter werden
lokal erzeugt und per stdin uebergeben), Protect-Workshop.ps1, Initialize-Workshop.ps1,
Abholen von CA, Zusammenfassung und Geheimnissen, Test-Workshop.ps1 -Mode Guest.
Wiederholte Aufrufe setzen dort fort, wo der Gast steht.
#>
[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'LocalPort', Justification = 'in Start-Tunnel und Invoke-Ssh verwendet')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'SshTimeoutMinutes', Justification = 'in Wait-Ssh verwendet')]
param(
    [Parameter(Mandatory)][ValidatePattern('^[a-z][a-z0-9]{2,11}$')][string]$Prefix,
    [Parameter(Mandatory)][datetime]$CertificateValidUntil,
    [ValidateRange(1024, 65000)][int]$LocalPort = 2222,
    [string]$RunRoot = ([System.IO.Path]::Combine($PSScriptRoot, '..', '..', '.run')),
    [string]$ScriptsPath = ([System.IO.Path]::Combine($PSScriptRoot, '..')),
    [int]$SshTimeoutMinutes = 20
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not (Get-Module -Name Workshop.Common)) { Import-Module ([System.IO.Path]::Combine($PSScriptRoot, 'Workshop.Common.psm1')) }
$env:CLOUDSDK_CORE_DISABLE_PROMPTS = '1'

$paths = Get-WorkshopRunPaths -Prefix $Prefix -RunRoot $RunRoot
$m = Read-WorkshopManifest -Path $paths.Manifest
if (-not ($m.network.ContainsKey('trainerSsh') -and [bool]$m.network.trainerSsh)) { throw "Umgebung $Prefix wurde ohne -TrainerSsh angelegt" }
$instance = $m.resources.instance.name
$P = "--project=$($m.projectId)"
$Z = "--zone=$($m.zone)"
$knownHosts = Join-Path $paths.Run 'known_hosts'
$statePath = Join-Path $paths.Run 'setup-state.json'
$adminSecret = Join-Path $paths.Secrets 'domain-admin.json'
New-Item -ItemType Directory -Path $paths.Secrets -Force | Out-Null

function Write-SetupLog { param([string]$Text) Write-Host ("{0} [{1}] {2}" -f (Get-Date -Format 'HH:mm:ss'), $Prefix, $Text) }

function Get-SetupState { if (Test-Path $statePath) { return Get-Content $statePath -Raw | ConvertFrom-Json -AsHashtable } return @{} }
function Save-SetupState { param([hashtable]$State) $State | ConvertTo-Json | Set-Content $statePath -Encoding utf8 }

function New-RandomPassword {
    $bytes = [byte[]]::new(24)
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
    return (([Convert]::ToBase64String($bytes) -replace '[^A-Za-z0-9]', 'x').Substring(0, 18)) + 'Q7!'
}

$script:tunnel = $null
function Start-Tunnel {
    Stop-Tunnel
    $out = [System.IO.Path]::GetTempFileName()
    $script:tunnel = Start-Process -FilePath gcloud -ArgumentList @('compute', 'start-iap-tunnel', $instance, '22', "--local-host-port=localhost:$LocalPort", $Z, $P) -PassThru -NoNewWindow -RedirectStandardOutput $out -RedirectStandardError ([System.IO.Path]::GetTempFileName())
    Start-Sleep -Seconds 8
}
function Stop-Tunnel {
    if ($script:tunnel -and -not $script:tunnel.HasExited) { $script:tunnel.Kill() }
    $script:tunnel = $null
}

function Invoke-Ssh {
    # Fuehrt einen PowerShell-Befehl im Gast aus; stdin optional (Passwoerter fuer -Unattended).
    param([string]$User, [string]$Command, [string]$Stdin, [switch]$IgnoreExit)
    $sshArgs = @('-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=no', "-o", "UserKnownHostsFile=$knownHosts", '-o', 'ConnectTimeout=15', '-o', 'ServerAliveInterval=15', '-p', $LocalPort, "$User@127.0.0.1", $Command)
    $out = if ($null -ne $Stdin) { $Stdin | & ssh @sshArgs 2>&1 } else { & ssh @sshArgs 2>&1 }
    $text = (@($out) | ForEach-Object { [string]$_ }) -join "`n"
    if ($LASTEXITCODE -ne 0 -and -not $IgnoreExit) { throw "ssh ($User) Exit $LASTEXITCODE`: $text" }
    return $text
}

function Wait-Ssh {
    # Wartet, bis der Gast per SSH antwortet; startet den Tunnel bei jedem Versuch neu.
    param([string]$User)
    $deadline = (Get-Date).AddMinutes($SshTimeoutMinutes)
    while ((Get-Date) -lt $deadline) {
        Start-Tunnel
        try {
            $null = Invoke-Ssh -User $User -Command 'hostname'
            return $true
        } catch { Start-Sleep -Seconds 20 }
    }
    return $false
}

function Copy-ToGuest {
    param([string]$User, [string[]]$Files, [string]$Target)
    $scpArgs = @('-O', '-o', 'StrictHostKeyChecking=no', '-o', "UserKnownHostsFile=$knownHosts", '-P', $LocalPort) + $Files + @("$User@127.0.0.1:$Target")
    & scp @scpArgs 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "scp nach $Target fehlgeschlagen" }
}

function Copy-FromGuest {
    param([string]$User, [string]$Source, [string]$Target)
    & scp -O -o StrictHostKeyChecking=no -o "UserKnownHostsFile=$knownHosts" -P $LocalPort "$User@127.0.0.1:$Source" $Target 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "scp von $Source fehlgeschlagen" }
}

function Get-GuestRole {
    # 0 = kein Zugang, 1 = wsadmin vor der Umbenennung, 2 = wsadmin auf dc01, 3 = Domaenen-Administrator
    try {
        $r = Invoke-Ssh -User 'Administrator' -Command '(Get-CimInstance Win32_ComputerSystem).DomainRole'
        if ([int]($r.Trim()) -ge 4) { return 3 }
    } catch { Write-Verbose "Administrator noch nicht erreichbar: $($_.Exception.Message)" }
    try {
        $h = (Invoke-Ssh -User 'wsadmin' -Command 'hostname').Trim()
        if ($h -eq 'dc01') { return 2 }
        return 1
    } catch { return 0 }
}

$guestScripts = @('Initialize-Domain.ps1', 'Initialize-Workshop.ps1', 'Reset-Baseline.ps1', 'Test-Workshop.ps1') | ForEach-Object { Join-Path $ScriptsPath $_ }
$state = Get-SetupState

try {
    if (-not $state.ContainsKey('resetAt')) {
        Write-SetupLog 'VM neu starten, damit das SSH-Startskript wirkt'
        Invoke-GcloudChange -Arguments @('compute', 'instances', 'reset', $instance, $Z, $P) -Description "$instance zuruecksetzen" | Out-Null
        $state.resetAt = (Get-Date).ToUniversalTime().ToString('o'); Save-SetupState $state
        Start-Sleep -Seconds 60
    }

    if (-not (Test-Path $adminSecret)) {
        [ordered]@{ administrator = (New-RandomPassword); dsrm = (New-RandomPassword); createdAt = (Get-Date).ToUniversalTime().ToString('o') } | ConvertTo-Json | Set-Content $adminSecret -Encoding utf8
        if ($IsLinux -or $IsMacOS) { & chmod 600 $adminSecret }
    }
    $admin = Get-Content $adminSecret -Raw | ConvertFrom-Json

    Write-SetupLog 'Warte auf SSH im Gast'
    if (-not (Wait-Ssh -User 'wsadmin') -and -not (Wait-Ssh -User 'Administrator')) { throw 'SSH im Gast nicht erreichbar' }
    $role = Get-GuestRole
    Write-SetupLog "Gastzustand: $role"

    if ($role -in 1, 2) {
        Invoke-Ssh -User 'wsadmin' -Command 'New-Item -ItemType Directory -Path C:\Workshop\scripts -Force | Out-Null' | Out-Null
        Copy-ToGuest -User 'wsadmin' -Files $guestScripts -Target 'C:/Workshop/scripts/'
    }
    if ($role -eq 1) {
        Write-SetupLog 'Phase 1: Datendisk und Umbenennung'
        Invoke-Ssh -User 'wsadmin' -Command 'powershell -NoProfile -ExecutionPolicy Bypass -File C:\Workshop\scripts\Initialize-Domain.ps1' -IgnoreExit | Out-Null
        Start-Sleep -Seconds 45
        if (-not (Wait-Ssh -User 'wsadmin')) { throw 'Gast nach Phase 1 nicht erreichbar' }
        $role = Get-GuestRole
    }
    if ($role -eq 2) {
        Write-SetupLog 'Phase 2: AD DS und Promotion'
        $stdin = "$($admin.administrator)`n$($admin.dsrm)`n"
        Invoke-Ssh -User 'wsadmin' -Command 'powershell -NoProfile -ExecutionPolicy Bypass -File C:\Workshop\scripts\Initialize-Domain.ps1 -Unattended' -Stdin $stdin -IgnoreExit | Out-Null
        Start-Sleep -Seconds 90
        if (-not (Wait-Ssh -User 'Administrator')) { throw 'Gast nach der Promotion nicht als Administrator erreichbar' }
        $role = Get-GuestRole
    }
    if ($role -ne 3) { throw "Gast ist kein Domain Controller (Zustand $role)" }

    if (-not $state.ContainsKey('phase3At')) {
        Write-SetupLog 'Phase 3: DNS, Zeit, Firewall'
        Invoke-Ssh -User 'Administrator' -Command 'New-Item -ItemType Directory -Path C:\Workshop\scripts -Force | Out-Null' | Out-Null
        Copy-ToGuest -User 'Administrator' -Files $guestScripts -Target 'C:/Workshop/scripts/'
        $out = Invoke-Ssh -User 'Administrator' -Command 'powershell -NoProfile -ExecutionPolicy Bypass -File C:\Workshop\scripts\Initialize-Domain.ps1'
        if ($out -notmatch 'bereit') { throw "Phase 3 ohne Bereit-Meldung: $out" }
        $state.phase3At = (Get-Date).ToUniversalTime().ToString('o'); Save-SetupState $state
    }

    Write-SetupLog 'Gast-Account-Manager deaktivieren'
    & pwsh -NoProfile -File (Join-Path $ScriptsPath 'Protect-Workshop.ps1') -ManifestPath $paths.Manifest | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Protect-Workshop.ps1 fehlgeschlagen' }

    Write-SetupLog 'Initialize-Workshop: CA, Zertifikat, OU, Konten, Delegation'
    $validUntil = $CertificateValidUntil.ToString('yyyy-MM-ddTHH:mm:ss')
    $out = Invoke-Ssh -User 'Administrator' -Command "powershell -NoProfile -ExecutionPolicy Bypass -Command `"& C:\Workshop\scripts\Initialize-Workshop.ps1 -CertificateValidUntil '$validUntil'`""
    if ($out -notmatch 'CA-Fingerprint') { throw "Initialize-Workshop ohne Fingerprint: $out" }

    Write-SetupLog 'Zertifikat, Zusammenfassung und Geheimnisse abholen'
    Copy-FromGuest -User 'Administrator' -Source 'C:/Workshop/out/workshop-ca.crt' -Target $paths.Ca
    Copy-FromGuest -User 'Administrator' -Source 'C:/Workshop/out/workshop-ad.json' -Target $paths.Summary
    Copy-FromGuest -User 'Administrator' -Source 'C:/Workshop/secrets/workshop.json' -Target (Join-Path $paths.Secrets 'workshop.json')
    if ($IsLinux -or $IsMacOS) { & chmod 600 (Join-Path $paths.Secrets 'workshop.json') }

    Write-SetupLog 'Gastpruefung'
    $out = Invoke-Ssh -User 'Administrator' -Command 'powershell -NoProfile -ExecutionPolicy Bypass -Command "& C:\Workshop\scripts\Test-Workshop.ps1 -Mode Guest 2>&1 | Out-String -Width 300"' -IgnoreExit
    $fails = @($out -split "`n" | Where-Object { $_ -match '^\[FAIL\]' })
    if ($fails.Count -gt 0) { throw "Gastpruefung: $($fails -join '; ')" }
    $state.completedAt = (Get-Date).ToUniversalTime().ToString('o'); Save-SetupState $state
    Write-SetupLog "fertig: $((@($out -split "`n" | Where-Object { $_ -match '^\[PASS\]' })).Count) Gastpruefungen PASS"
} finally {
    Stop-Tunnel
}
