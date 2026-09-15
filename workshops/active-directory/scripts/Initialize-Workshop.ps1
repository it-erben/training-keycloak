<#
.SYNOPSIS
Bereitet Workshop-CA, LDAPS-Zertifikat, Team-OUs, Konten und Delegation auf dem DC vor.

.DESCRIPTION
Laeuft auf dem Domain Controller als Domaenen-Administrator, nachdem Initialize-Domain.ps1
die Phase "ready" gemeldet hat. Wiederholte Aufrufe legen nur Fehlendes an; Passwoerter
werden nur mit -ResetPasswords neu gesetzt. Geheimnisse landen ausschliesslich in
$SecretsPath mit eingeschraenkter ACL, das oeffentliche CA-Zertifikat in $OutputPath.
#>
#Requires -RunAsAdministrator
[CmdletBinding()]
param(
    [ValidatePattern('^\d{2}$')][string[]]$Teams = @('01', '02', '03'),
    [Parameter(Mandatory)][datetime]$CertificateValidUntil,
    [string]$DcFqdn = 'dc01.ad.mustertech.test',
    [string]$OutputPath = 'C:\Workshop\out',
    [string]$SecretsPath = 'C:\Workshop\secrets',
    [ValidateRange(16, 64)][int]$PasswordLength = 20,
    [switch]$ResetPasswords
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory

if ($CertificateValidUntil -le (Get-Date).AddDays(1)) { throw 'CertificateValidUntil muss mindestens einen Tag in der Zukunft liegen' }
$domain = Get-ADDomain
if ("$env:COMPUTERNAME.$($domain.DNSRoot)".ToLower() -ne $DcFqdn.ToLower()) { throw "Dieser Host ist $env:COMPUTERNAME.$($domain.DNSRoot), erwartet wird $DcFqdn" }
$baseDn = "OU=Workshop,$($domain.DistinguishedName)"
$netbios = $domain.NetBIOSName
New-Item -ItemType Directory -Path $OutputPath, $SecretsPath -Force | Out-Null

function New-WorkshopPassword {
    param([int]$Length)
    $alphabet = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789'.ToCharArray()
    $symbols = '!$%&*+-=?@'.ToCharArray()
    $bytes = [byte[]]::new($Length)
    # RNGCryptoServiceProvider gibt es in Windows PowerShell 5.1 und in PowerShell 7.
    $rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::new()
    $rng.GetBytes($bytes)
    $rng.Dispose()
    $chars = [char[]]::new($Length)
    for ($i = 0; $i -lt $Length; $i++) { $chars[$i] = $alphabet[$bytes[$i] % $alphabet.Length] }
    # Komplexitaetsregel von AD: drei der vier Klassen. Feste Positionen sichern Symbol, Grossbuchstabe und Ziffer.
    $chars[3] = $symbols[$bytes[0] % $symbols.Length]
    $chars[7] = 'Q'
    $chars[11] = '7'
    return -join $chars
}

function Get-OrCreateCa {
    $ca = Get-ChildItem Cert:\LocalMachine\My | Where-Object { $_.Subject -eq 'CN=Keycloak Workshop CA' -and $_.HasPrivateKey } | Select-Object -First 1
    if (-not $ca) {
        Write-Host 'Erzeuge Workshop-CA'
        $ca = New-SelfSignedCertificate -Subject 'CN=Keycloak Workshop CA' -KeyAlgorithm RSA -KeyLength 4096 -HashAlgorithm SHA256 `
            -KeyUsage CertSign, CRLSign, DigitalSignature -KeyExportPolicy NonExportable -NotAfter $CertificateValidUntil `
            -CertStoreLocation Cert:\LocalMachine\My -TextExtension @('2.5.29.19={critical}{text}ca=true&pathlength=0')
    }
    $root = [System.Security.Cryptography.X509Certificates.X509Store]::new('Root', 'LocalMachine')
    $root.Open('ReadWrite')
    if (-not ($root.Certificates | Where-Object { $_.Thumbprint -eq $ca.Thumbprint })) {
        $root.Add([System.Security.Cryptography.X509Certificates.X509Certificate2]::new($ca.RawData))
    }
    $root.Close()
    return $ca
}

function Get-OrCreateServerCertificate {
    param($Ca)
    $existing = Get-ChildItem Cert:\LocalMachine\My | Where-Object {
        $_.Issuer -eq $Ca.Subject -and $_.HasPrivateKey -and ($_.DnsNameList | ForEach-Object { $_.Unicode }) -contains $DcFqdn -and $_.NotAfter -ge $CertificateValidUntil.AddMinutes(-5)
    } | Select-Object -First 1
    if ($existing) { return $existing }
    Write-Host "Erzeuge LDAPS-Serverzertifikat fuer $DcFqdn"
    $cert = New-SelfSignedCertificate -DnsName $DcFqdn, ($DcFqdn.Split('.')[0]) -Signer $Ca -KeyAlgorithm RSA -KeyLength 2048 -HashAlgorithm SHA256 `
        -KeyExportPolicy NonExportable -KeySpec KeyExchange -NotAfter $CertificateValidUntil -CertStoreLocation Cert:\LocalMachine\My `
        -TextExtension @('2.5.29.37={text}1.3.6.1.5.5.7.3.1')
    $cert = Get-Item "Cert:\LocalMachine\My\$($cert.Thumbprint)"
    # AD DS liest ein neues Zertifikat ohne Neustart nach dieser RootDSE-Operation ein.
    $rootDse = [ADSI]'LDAP://localhost/RootDSE'
    $rootDse.Put('renewServerCertificate', 1)
    $rootDse.SetInfo()
    return $cert
}

function Export-CaPem {
    param($Ca)
    $b64 = [Convert]::ToBase64String($Ca.RawData, 'InsertLineBreaks')
    $pem = "-----BEGIN CERTIFICATE-----`n$b64`n-----END CERTIFICATE-----`n"
    [System.IO.File]::WriteAllText((Join-Path $OutputPath 'workshop-ca.crt'), $pem, [System.Text.Encoding]::ASCII)
    return (($Ca.GetCertHash('SHA256') | ForEach-Object { $_.ToString('X2') }) -join ':')
}

function Test-Ldaps {
    # Liefert den Thumbprint des auf 636 ausgelieferten Zertifikats; AD DS braucht nach
    # renewServerCertificate einen Moment, deshalb mehrere Versuche.
    $last = $null
    foreach ($attempt in 1..10) {
        $client = [System.Net.Sockets.TcpClient]::new($DcFqdn, 636)
        try {
            $ssl = [System.Net.Security.SslStream]::new($client.GetStream(), $false)
            $ssl.AuthenticateAsClient($DcFqdn)
            if ($null -ne $ssl.RemoteCertificate) {
                $remote = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($ssl.RemoteCertificate)
                return [string]$remote.Thumbprint
            }
        } catch { $last = $_.Exception.Message } finally { $client.Close() }
        Start-Sleep -Seconds 3
    }
    throw "LDAPS-Handshake auf ${DcFqdn}:636 fehlgeschlagen: $last"
}

function Confirm-Ou {
    param([string]$Name, [string]$Parent)
    $dn = "OU=$Name,$Parent"
    if (-not (Get-ADOrganizationalUnit -LDAPFilter "(ou=$Name)" -SearchBase $Parent -SearchScope OneLevel)) {
        New-ADOrganizationalUnit -Name $Name -Path $Parent -ProtectedFromAccidentalDeletion $false | Out-Null
    }
    return $dn
}

function Confirm-Group {
    param([string]$Name, [string]$Sam, [string]$Path)
    $g = Get-ADGroup -LDAPFilter "(sAMAccountName=$Sam)"
    if (-not $g) { $g = New-ADGroup -Name $Name -SamAccountName $Sam -GroupScope Global -GroupCategory Security -Path $Path -PassThru }
    return $g
}

function Confirm-User {
    param([string]$Sam, [string]$Given, [string]$Surname, [string]$Path, [string]$Password, [switch]$Service)
    $upn = "$Sam@$($domain.DNSRoot)"
    $u = Get-ADUser -LDAPFilter "(sAMAccountName=$Sam)"
    if (-not $u) {
        $u = New-ADUser -Name "$Given $Surname" -DisplayName "$Given $Surname" -GivenName $Given -Surname $Surname -SamAccountName $Sam `
            -UserPrincipalName $upn -EmailAddress $upn -Path $Path -AccountPassword (ConvertTo-SecureString $Password -AsPlainText -Force) `
            -Enabled $true -PasswordNeverExpires $true -CannotChangePassword ([bool]$Service) -ChangePasswordAtLogon $false -PassThru
    } elseif ($ResetPasswords) {
        Set-ADAccountPassword -Identity $u -Reset -NewPassword (ConvertTo-SecureString $Password -AsPlainText -Force)
    }
    return $u
}

function Confirm-Member {
    param($Group, $Member)
    $members = @(Get-ADGroupMember -Identity $Group | ForEach-Object { $_.distinguishedName })
    if ($members -notcontains $Member.DistinguishedName) { Add-ADGroupMember -Identity $Group -Members $Member }
}

function Grant-Delegation {
    # Uebungskonto: Attribute und Verschiebung der Testbenutzer, Mitgliedschaften der Testgruppen. Sonst nichts.
    param([string]$Operator, [string]$UsersDn, [string]$MovedDn, [string]$GroupsDn)
    $principal = "${netbios}\${Operator}"
    foreach ($ou in $UsersDn, $MovedDn) {
        & dsacls $ou /G "${principal}:CCDC;user" | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "dsacls CCDC auf $ou fehlgeschlagen" }
        & dsacls $ou /I:S /G "${principal}:WP;userAccountControl;user" "${principal}:WP;cn;user" "${principal}:WP;name;user" "${principal}:WP;description;user" | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "dsacls WP auf $ou fehlgeschlagen" }
    }
    & dsacls $GroupsDn /I:S /G "${principal}:WP;member;group" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "dsacls member auf $GroupsDn fehlgeschlagen" }
}

function Protect-SecretFile {
    param([string]$Path)
    $acl = Get-Acl $Path
    $acl.SetAccessRuleProtection($true, $false)
    foreach ($rule in @($acl.Access)) { $acl.RemoveAccessRule($rule) | Out-Null }
    foreach ($p in 'BUILTIN\Administrators', 'NT AUTHORITY\SYSTEM') {
        $acl.AddAccessRule([System.Security.AccessControl.FileSystemAccessRule]::new($p, 'FullControl', 'Allow'))
    }
    Set-Acl -Path $Path -AclObject $acl
}

$ca = Get-OrCreateCa
$server = Get-OrCreateServerCertificate -Ca $ca
if (-not $server -or -not $server.PSObject.Properties['Thumbprint']) { throw 'Serverzertifikat konnte nicht ermittelt werden' }
$fingerprint = Export-CaPem -Ca $ca
$servedThumbprint = Test-Ldaps
if ($servedThumbprint -ne [string]$server.Thumbprint) { throw "LDAPS liefert Zertifikat $servedThumbprint, erwartet $($server.Thumbprint). Neustart des Dienstes oder der VM noetig." }
Confirm-Ou -Name 'Workshop' -Parent $domain.DistinguishedName | Out-Null

$summary = [ordered]@{
    dcFqdn = $DcFqdn; domain = $domain.DNSRoot; baseDn = $baseDn
    caSubject = $ca.Subject; caFingerprintSha256 = $fingerprint; caNotAfter = $ca.NotAfter.ToString('o')
    serverCertThumbprint = $server.Thumbprint; serverCertNotAfter = $server.NotAfter.ToString('o')
    preparedAt = (Get-Date).ToUniversalTime().ToString('o'); teams = [ordered]@{}
}

foreach ($t in $Teams) {
    Write-Host "Team $t"
    $teamDn = Confirm-Ou -Name "Team$t" -Parent $baseDn
    $usersDn = Confirm-Ou -Name 'Users' -Parent $teamDn
    $movedDn = Confirm-Ou -Name 'Moved' -Parent $teamDn
    $groupsDn = Confirm-Ou -Name 'Groups' -Parent $teamDn
    $svcDn = Confirm-Ou -Name 'ServiceAccounts' -Parent $teamDn

    $secretFile = Join-Path $SecretsPath "team$t.json"
    if ((Test-Path $secretFile) -and -not $ResetPasswords) {
        $secrets = Get-Content $secretFile -Raw | ConvertFrom-Json
    } else {
        $secrets = [ordered]@{
            team = $t
            hans = New-WorkshopPassword $PasswordLength; anna = New-WorkshopPassword $PasswordLength
            bind = New-WorkshopPassword $PasswordLength; operator = New-WorkshopPassword $PasswordLength
        }
    }

    $hans = Confirm-User -Sam "t$t.hans" -Given 'Hans' -Surname 'Mueller' -Path $usersDn -Password $secrets.hans
    $anna = Confirm-User -Sam "t$t.anna" -Given 'Anna' -Surname 'Schmidt' -Path $usersDn -Password $secrets.anna
    $bind = Confirm-User -Sam "t$t.bind" -Given 'Bind' -Surname "Team$t" -Path $svcDn -Password $secrets.bind -Service
    $operator = Confirm-User -Sam "t$t.operator" -Given 'Operator' -Surname "Team$t" -Path $svcDn -Password $secrets.operator -Service

    $staff = Confirm-Group -Name 'Mitarbeiter' -Sam "t$t.staff" -Path $groupsDn
    $leads = Confirm-Group -Name 'Teamleitung' -Sam "t$t.leads" -Path $groupsDn
    $managers = Confirm-Group -Name 'Manager' -Sam "t$t.managers" -Path $groupsDn
    Confirm-Member -Group $staff -Member $hans
    Confirm-Member -Group $staff -Member $anna
    Confirm-Member -Group $leads -Member $anna
    Confirm-Member -Group $managers -Member $leads

    Grant-Delegation -Operator "t$t.operator" -UsersDn $usersDn -MovedDn $movedDn -GroupsDn $groupsDn

    $secrets | ConvertTo-Json | Set-Content $secretFile -Encoding utf8
    Protect-SecretFile -Path $secretFile

    $summary.teams["team$t"] = [ordered]@{
        ou = $teamDn; usersDn = $usersDn; movedDn = $movedDn; groupsDn = $groupsDn; serviceAccountsDn = $svcDn
        bindUpn = $bind.UserPrincipalName; operatorUpn = $operator.UserPrincipalName
        users = [ordered]@{ hans = $hans.DistinguishedName; anna = $anna.DistinguishedName }
        groups = [ordered]@{ Mitarbeiter = $staff.DistinguishedName; Teamleitung = $leads.DistinguishedName; Manager = $managers.DistinguishedName }
    }
}

$summary | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $OutputPath 'workshop-ad.json') -Encoding utf8
Write-Host ''
Write-Host "CA-Fingerprint SHA256: $fingerprint"
Write-Host "Oeffentlich: $OutputPath\workshop-ca.crt, $OutputPath\workshop-ad.json"
Write-Host "Geheim:      $SecretsPath\team<NN>.json (nur Administrators und SYSTEM)"
