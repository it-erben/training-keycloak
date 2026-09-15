<#
.SYNOPSIS
Prueft eine Workshop-Umgebung vom Trainerrechner (-Mode Trainer) oder auf dem DC (-Mode Guest).

.DESCRIPTION
Trainer: Manifest, Instanz, Metadaten, effektive Firewall, TCP/TLS/Namenspruefung ueber das
LDAP-Werkzeugimage, LDAP-Suche und delegierte Schreibgrenzen, optional IAP-Tunnel. Die
LDAP-Aufrufe laufen in einem eigenen Container mit der IP aus dem Manifest und dem CA-Zertifikat
aus dem Laufzeitverzeichnis; der Teilnehmer-Stack wird dafuer nicht angefasst.
Guest: Domaene, Datentraeger, DNS, KMS, Zeitquelle, LDAPS-Zertifikat, AD-Objekte, Delegation.
Schreibt einen JSON-Bericht und beendet sich mit Exit-Code 1 bei mindestens einem FAIL.
#>
[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'IapLocalPort', Justification = 'in T15 verwendet')]
param(
    [Parameter(Mandatory)][ValidateSet('Trainer', 'Guest')][string]$Mode,
    [ValidatePattern('^[a-z][a-z0-9]{2,11}$')][string]$Prefix = 'kcad',
    [string]$RunPath = '',
    [string]$LabPath = ([System.IO.Path]::Combine($PSScriptRoot, '..', 'lab')),
    [string]$DcFqdn = 'dc01.ad.mustertech.test',
    [string]$BaseDn = 'DC=ad,DC=mustertech,DC=test',
    [int]$IapLocalPort = 33389,
    [switch]$IncludeIap,
    [switch]$HelpersOnly
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:Report = [System.Collections.Generic.List[object]]::new()

function Add-Check {
    param([Parameter(Mandatory)][string]$Id, [Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][scriptblock]$Test)
    $entry = [pscustomobject]@{ id = $Id; name = $Name; result = 'PASS'; detail = '' }
    try {
        $detail = & $Test
        if ($detail -is [array]) { $detail = ($detail | ForEach-Object { [string]$_ }) -join '; ' }
        $entry.detail = [string]$detail
    } catch {
        $entry.result = 'FAIL'
        $entry.detail = $_.Exception.Message
    }
    $script:Report.Add($entry)
    $color = if ($entry.result -eq 'PASS') { 'Green' } else { 'Red' }
    Write-Host ("[{0}] {1} {2}: {3}" -f $entry.result, $Id, $Name, $entry.detail) -ForegroundColor $color
}

function Add-Skip {
    param([string]$Id, [string]$Name, [string]$Reason)
    $script:Report.Add([pscustomobject]@{ id = $Id; name = $Name; result = 'SKIP'; detail = $Reason })
    Write-Host "[SKIP] $Id $Name`: $Reason" -ForegroundColor Yellow
}

function Get-ReportExitCode {
    param([Parameter(Mandatory)]$Report)
    if (@($Report | Where-Object { $_.result -eq 'FAIL' }).Count -gt 0) { return 1 }
    return 0
}

function Test-PortCovered {
    # Portliste einer Regel ("636", "630-640", leer = alle) gegen einen Port.
    param($Ports, [int]$Port)
    if ($null -eq $Ports -or @($Ports).Count -eq 0) { return $true }
    foreach ($p in $Ports) {
        if ($p -match '^(\d+)-(\d+)$') { if ($Port -ge [int]$Matches[1] -and $Port -le [int]$Matches[2]) { return $true } }
        elseif ([int]$p -eq $Port) { return $true }
    }
    return $false
}

function Test-EffectiveFirewall {
    # $Rules: Objekte mit direction, sourceRanges, allowed[] (IPProtocol, ports). Firewall-Policy-Regeln werden
    # vorher in dieselbe Form gebracht.
    param([Parameter(Mandatory)]$Rules, [Parameter(Mandatory)][string[]]$AllowedLdapsRanges, [string]$IapRange = '35.235.240.0/20', [switch]$AllowIapSsh)
    $problems = @()
    $ldapsSeen = $false
    $rdpSeen = $false
    foreach ($r in $Rules) {
        if ($r.direction -ne 'INGRESS') { continue }
        if (-not $r.PSObject.Properties['allowed'] -or -not $r.allowed) { continue }
        $sources = @()
        if ($r.PSObject.Properties['sourceRanges'] -and $r.sourceRanges) { $sources = @($r.sourceRanges) }
        foreach ($a in $r.allowed) {
            $proto = [string]$a.IPProtocol
            if ($proto -notin 'tcp', 'all') { continue }
            $ports = $null
            if ($a.PSObject.Properties['ports']) { $ports = $a.ports }
            foreach ($port in 636, 3389, 22) {
                if (-not (Test-PortCovered -Ports $ports -Port $port)) { continue }
                if ($sources -contains '0.0.0.0/0') { $problems += "Port $port aus 0.0.0.0/0 erlaubt"; continue }
                if ($port -eq 22 -and -not $AllowIapSsh) { $problems += "Port 22 aus $($sources -join ',') erlaubt, Trainer-SSH ist nicht vorgesehen"; continue }
                $allowed = if ($port -eq 636) { $AllowedLdapsRanges } else { @($IapRange) }
                foreach ($s in $sources) {
                    if ($allowed -notcontains $s) { $problems += "Port $port aus unerwarteter Quelle $s erlaubt" }
                }
                if ($port -eq 636) { $ldapsSeen = $true } elseif ($port -eq 3389) { $rdpSeen = $true }
            }
        }
    }
    if (-not $ldapsSeen) { $problems += 'keine Regel fuer TCP 636 gefunden' }
    if (-not $rdpSeen) { $problems += 'keine Regel fuer TCP 3389 aus dem IAP-Bereich gefunden' }
    if ($problems) { return [pscustomobject]@{ Result = 'FAIL'; Detail = ($problems -join '; ') } }
    return [pscustomobject]@{ Result = 'PASS'; Detail = "636 nur aus $($AllowedLdapsRanges -join ','), 3389 nur aus $IapRange" }
}

function ConvertFrom-FirewallPolicyRule {
    # Hierarchische Firewall-Policy-Regeln in die Form der VPC-Regeln bringen.
    param($PolicyRule)
    $ranges = @()
    if ($PolicyRule.match.PSObject.Properties['srcIpRanges']) { $ranges = @($PolicyRule.match.srcIpRanges) }
    $allowed = @()
    if ($PolicyRule.action -eq 'allow' -and $PolicyRule.match.PSObject.Properties['layer4Configs']) {
        foreach ($l4 in $PolicyRule.match.layer4Configs) {
            $ports = $null
            if ($l4.PSObject.Properties['ports']) { $ports = $l4.ports }
            $allowed += [pscustomobject]@{ IPProtocol = $l4.ipProtocol; ports = $ports }
        }
    }
    return [pscustomobject]@{ direction = $PolicyRule.direction; sourceRanges = $ranges; allowed = $allowed }
}

function Test-TcpOpen {
    param([string]$TargetHost, [int]$Port, [int]$TimeoutMs = 5000)
    $client = [System.Net.Sockets.TcpClient]::new()
    try {
        $task = $client.ConnectAsync($TargetHost, $Port)
        if (-not $task.Wait($TimeoutMs)) { return $false }
        return $client.Connected
    } catch { return $false } finally { $client.Dispose() }
}

function Save-Report {
    param([string]$ModeName, [string]$Directory)
    New-Item -ItemType Directory -Path $Directory -Force | Out-Null
    $file = Join-Path $Directory ("report-{0}-{1}.json" -f $ModeName.ToLower(), (Get-Date -Format 'yyyyMMdd-HHmm'))
    [ordered]@{ mode = $ModeName; at = (Get-Date).ToUniversalTime().ToString('o'); checks = $script:Report } | ConvertTo-Json -Depth 5 | Set-Content $file -Encoding utf8
    return $file
}

if ($HelpersOnly) { return }

$reportDir = if ($RunPath) { $RunPath } elseif ($Mode -eq 'Guest') { 'C:\Workshop\out' } else { [System.IO.Path]::Combine($PSScriptRoot, '..', '.run', $Prefix) }

# =====================================================================================================
if ($Mode -eq 'Trainer') {
    if (-not (Get-Module -Name Workshop.Common)) { Import-Module ([System.IO.Path]::Combine($PSScriptRoot, 'lib', 'Workshop.Common.psm1')) }
    $paths = Get-WorkshopRunPaths -Prefix $Prefix -RunRoot ([System.IO.Path]::Combine($PSScriptRoot, '..', '.run'))
    if ($RunPath) { $paths = Get-WorkshopRunPaths -Prefix $Prefix -RunRoot (Split-Path -Parent $RunPath) }
    $m = Read-WorkshopManifest -Path $paths.Manifest
    $P = "--project=$($m.projectId)"
    $Z = "--zone=$($m.zone)"
    $instanceName = $m.resources.instance.name
    $externalIp = $m.network.externalIp
    $caPath = Join-Path $paths.Run 'workshop-ca.crt'
    $secretFile = Join-Path $paths.Secrets 'workshop.json'
    $toolImage = 'keycloak-ad-workshop-ldap-tools'
    $tmpSecrets = Join-Path $paths.Run 'test-secrets'

    & docker image inspect $toolImage 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Baue Werkzeugimage $toolImage"
        & docker build -q -t $toolImage (Join-Path $LabPath 'ldap-tools') | Out-Null
    }
    function Invoke-LabTool {
        # Eigener Container je Aufruf: Hosteintrag auf die Manifest-IP, CA und Passwortdateien nur lesend.
        param([string[]]$ToolArgs, [string]$Stdin)
        $dockerArgs = @('run', '--rm', '-i', '--add-host', "${DcFqdn}:${externalIp}", '-e', 'LDAPTLS_REQCERT=demand', '-e', 'LDAPTLS_CACERT=/certs/workshop-ca.crt',
            '-v', "${caPath}:/certs/workshop-ca.crt:ro", '-v', "${tmpSecrets}:/secrets:ro", $toolImage) + $ToolArgs
        $out = if ($null -ne $Stdin) { $Stdin | & docker @dockerArgs 2>&1 } else { & docker @dockerArgs 2>&1 }
        return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = (@($out) | ForEach-Object { [string]$_ }) -join "`n" }
    }

    Add-Check -Id 'T01' -Name 'Projektnummer entspricht Manifest' -Test {
        $p = Get-GcloudJson -Arguments @('projects', 'describe', $m.projectId)
        if ([string]$p.projectNumber -ne [string]$m.projectNumber) { throw "gcloud: $($p.projectNumber), Manifest: $($m.projectNumber)" }
        "$($m.projectId) ($($m.projectNumber))"
    }
    $instance = $null
    Add-Check -Id 'T02' -Name 'Instanz laeuft und gehoert zum Workshop' -Test {
        $script:instance = Get-GcloudJson -Arguments @('compute', 'instances', 'describe', $instanceName, $Z, $P)
        if ($script:instance.status -ne 'RUNNING') { throw "Status $($script:instance.status)" }
        if (-not (Test-WorkshopOwnedResource -Resource $script:instance -RunId $m.runId)) { throw 'Labels passen nicht zur run-id' }
        if ($script:instance.selfLink -ne $m.resources.instance.selfLink) { throw 'selfLink weicht ab' }
        if ($script:instance.PSObject.Properties['serviceAccounts'] -and $script:instance.serviceAccounts) { throw 'Instanz hat ein Service-Konto' }
        "$instanceName RUNNING, kein Service-Konto"
    }
    Add-Check -Id 'T03' -Name 'Gast-Account-Manager deaktiviert' -Test {
        $items = @()
        if ($script:instance.metadata.PSObject.Properties['items'] -and $script:instance.metadata.items) { $items = @($script:instance.metadata.items) }
        if (-not ($items | Where-Object { $_.key -eq 'disable-account-manager' -and $_.value -eq 'true' })) { throw 'disable-account-manager fehlt oder ist nicht true' }
        'disable-account-manager=true'
    }
    Add-Check -Id 'T04' -Name 'Effektive Firewall der Instanz' -Test {
        $eff = Get-GcloudJson -Arguments @('compute', 'instances', 'network-interfaces', 'get-effective-firewalls', $instanceName, $Z, $P)
        $rules = @()
        if ($eff.PSObject.Properties['firewalls'] -and $eff.firewalls) { $rules += @($eff.firewalls) }
        if ($eff.PSObject.Properties['firewallPolicys'] -and $eff.firewallPolicys) {
            foreach ($pol in $eff.firewallPolicys) { foreach ($rule in $pol.rules) { $rules += ConvertFrom-FirewallPolicyRule -PolicyRule $rule } }
        }
        $sshAllowed = $m.network.ContainsKey('trainerSsh') -and [bool]$m.network.trainerSsh
        $r = Test-EffectiveFirewall -Rules $rules -AllowedLdapsRanges @($m.network.ldapsSourceRanges) -AllowIapSsh:$sshAllowed
        if ($r.Result -ne 'PASS') { throw $r.Detail }
        $r.Detail
    }
    Add-Check -Id 'T05' -Name 'TCP 636 erreichbar' -Test {
        if (-not (Test-TcpOpen -TargetHost $externalIp -Port 636)) { throw "keine Verbindung zu ${externalIp}:636 (Quell-IP freigegeben?)" }
        "${externalIp}:636 offen"
    }
    if (-not (Test-Path $caPath)) {
        Add-Skip -Id 'T06' -Name 'TLS-Pruefungen' -Reason "CA-Zertifikat fehlt: $caPath"
    } else {
        New-Item -ItemType Directory -Path $tmpSecrets -Force | Out-Null
        $tlsBase = @('openssl', 's_client', '-connect', "${DcFqdn}:636", '-servername', $DcFqdn, '-verify_return_error', '-brief')
        Add-Check -Id 'T06' -Name 'TLS mit Workshop-CA und richtigem Namen' -Test {
            $r = Invoke-LabTool -ToolArgs ($tlsBase + @('-CAfile', '/certs/workshop-ca.crt', '-verify_hostname', $DcFqdn)) -Stdin ''
            if ($r.ExitCode -ne 0 -or $r.Output -notmatch 'Verification: OK') { throw "openssl Exit $($r.ExitCode): $($r.Output -split "`n" | Select-Object -First 3)" }
            'Verification: OK'
        }
        Add-Check -Id 'T07' -Name 'TLS mit falschem Hostnamen scheitert' -Test {
            $r = Invoke-LabTool -ToolArgs ($tlsBase + @('-CAfile', '/certs/workshop-ca.crt', '-verify_hostname', 'wrong.example')) -Stdin ''
            if ($r.ExitCode -eq 0 -and $r.Output -match 'Verification: OK') { throw 'Verbindung mit falschem Namen wurde akzeptiert' }
            "abgelehnt (Exit $($r.ExitCode))"
        }
        Add-Check -Id 'T08' -Name 'TLS ohne Workshop-CA scheitert' -Test {
            $r = Invoke-LabTool -ToolArgs ($tlsBase + @('-verify_hostname', $DcFqdn, '-CAfile', '/dev/null')) -Stdin ''
            if ($r.ExitCode -eq 0 -and $r.Output -match 'Verification: OK') { throw 'Verbindung ohne CA wurde akzeptiert' }
            "abgelehnt (Exit $($r.ExitCode))"
        }
    }
    Add-Check -Id 'T09' -Name 'TCP 3389 und 22 direkt geschlossen' -Test {
        foreach ($port in 3389, 22) { if (Test-TcpOpen -TargetHost $externalIp -Port $port) { throw "${externalIp}:$port ist direkt erreichbar" } }
        "${externalIp}:3389 und :22 nicht erreichbar"
    }

    if (-not (Test-Path $secretFile) -or -not (Test-Path $caPath)) {
        Add-Skip -Id 'T10' -Name 'LDAP-Pruefungen' -Reason "Geheimnisdatei $secretFile oder CA $caPath fehlt"
    } else {
        $secret = Get-Content $secretFile -Raw | ConvertFrom-Json
        $workshopDn = "OU=Workshop,$BaseDn"
        $usersDn = "OU=Users,$workshopDn"
        $bindUpn = "bind@ad.mustertech.test"
        $operatorUpn = "operator@ad.mustertech.test"
        $ldapUrl = "ldaps://${DcFqdn}:636"
        [System.IO.File]::WriteAllText((Join-Path $tmpSecrets 'bind.pw'), [string]$secret.bind)
        [System.IO.File]::WriteAllText((Join-Path $tmpSecrets 'operator.pw'), [string]$secret.operator)
        if ($IsLinux -or $IsMacOS) { & chmod -R go-rwx $tmpSecrets }
        try {
            Add-Check -Id 'T10' -Name 'Bind-Suche liefert genau Hans und Anna' -Test {
                $r = Invoke-LabTool -ToolArgs @('ldapsearch', '-LLL', '-x', '-H', $ldapUrl, '-D', $bindUpn, '-y', '/secrets/bind.pw', '-b', $workshopDn, '(|(sAMAccountName=hans)(sAMAccountName=anna))', 'sAMAccountName')
                if ($r.ExitCode -ne 0) { throw "ldapsearch Exit $($r.ExitCode): $($r.Output)" }
                $found = @($r.Output -split "`n" | Where-Object { $_ -match '^sAMAccountName: ' } | ForEach-Object { $_ -replace '^sAMAccountName: ', '' } | Sort-Object)
                if (($found -join ',') -ne 'anna,hans') { throw "gefunden: $($found -join ',')" }
                $found -join ', '
            }
            Add-Check -Id 'T11' -Name 'Users-OU enthaelt keine Dienstkonten' -Test {
                $r = Invoke-LabTool -ToolArgs @('ldapsearch', '-LLL', '-x', '-H', $ldapUrl, '-D', $bindUpn, '-y', '/secrets/bind.pw', '-b', $usersDn, '(objectClass=user)', 'sAMAccountName')
                if ($r.ExitCode -ne 0) { throw "ldapsearch Exit $($r.ExitCode): $($r.Output)" }
                $found = @($r.Output -split "`n" | Where-Object { $_ -match '^sAMAccountName: ' } | ForEach-Object { $_ -replace '^sAMAccountName: ', '' })
                if ($found | Where-Object { $_ -in 'bind', 'operator' }) { throw "Dienstkonto unter Users: $($found -join ',')" }
                "unter Users: $($found -join ', ')"
            }
            $r = Invoke-LabTool -ToolArgs @('ldapsearch', '-LLL', '-x', '-H', $ldapUrl, '-D', $bindUpn, '-y', '/secrets/bind.pw', '-b', $workshopDn, '(sAMAccountName=hans)', 'dn')
            $hansDn = ($r.Output -split "`n" | Where-Object { $_ -match '^dn: ' } | Select-Object -First 1) -replace '^dn: ', ''
            $bindDn = "CN=Bind Keycloak,OU=ServiceAccounts,$workshopDn"
            $ldifSet = "dn: $hansDn`nchangetype: modify`nreplace: description`ndescription: workshop-test`n"
            $ldifClear = "dn: $hansDn`nchangetype: modify`ndelete: description`n"
            Add-Check -Id 'T12' -Name 'Bind-Konto darf nicht schreiben' -Test {
                $r = Invoke-LabTool -ToolArgs @('ldapmodify', '-x', '-H', $ldapUrl, '-D', $bindUpn, '-y', '/secrets/bind.pw') -Stdin $ldifSet
                if ($r.ExitCode -eq 0) { throw 'Bind-Konto konnte description setzen' }
                if ($r.ExitCode -ne 50) { throw "unerwarteter Exit $($r.ExitCode): $($r.Output)" }
                'Exit 50 insufficientAccessRights'
            }
            Add-Check -Id 'T13' -Name 'Uebungskonto darf Dienstkonten nicht aendern' -Test {
                $r = Invoke-LabTool -ToolArgs @('ldapmodify', '-x', '-H', $ldapUrl, '-D', $operatorUpn, '-y', '/secrets/operator.pw') -Stdin "dn: $bindDn`nchangetype: modify`nreplace: description`ndescription: workshop-test`n"
                if ($r.ExitCode -eq 0) { throw "Uebungskonto konnte $bindDn aendern" }
                if ($r.ExitCode -ne 50) { throw "unerwarteter Exit $($r.ExitCode): $($r.Output)" }
                'Exit 50 insufficientAccessRights'
            }
            Add-Check -Id 'T14' -Name 'Uebungskonto darf Hans aendern' -Test {
                $r = Invoke-LabTool -ToolArgs @('ldapmodify', '-x', '-H', $ldapUrl, '-D', $operatorUpn, '-y', '/secrets/operator.pw') -Stdin $ldifSet
                if ($r.ExitCode -ne 0) { throw "setzen Exit $($r.ExitCode): $($r.Output)" }
                $r = Invoke-LabTool -ToolArgs @('ldapmodify', '-x', '-H', $ldapUrl, '-D', $operatorUpn, '-y', '/secrets/operator.pw') -Stdin $ldifClear
                if ($r.ExitCode -ne 0) { throw "loeschen Exit $($r.ExitCode): $($r.Output)" }
                'description gesetzt und entfernt'
            }
        } finally {
            Remove-Item $tmpSecrets -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    if ($IncludeIap) {
        Add-Check -Id 'T15' -Name 'IAP-Tunnel auf 3389' -Test {
            $proc = Start-Process -FilePath gcloud -ArgumentList @('compute', 'start-iap-tunnel', $instanceName, '3389', "--local-host-port=localhost:$IapLocalPort", $Z, $P) -PassThru -NoNewWindow -RedirectStandardOutput ([System.IO.Path]::GetTempFileName()) -RedirectStandardError ([System.IO.Path]::GetTempFileName())
            try {
                $ok = $false
                foreach ($i in 1..15) { Start-Sleep -Seconds 2; if (Test-TcpOpen -TargetHost 'localhost' -Port $IapLocalPort -TimeoutMs 2000) { $ok = $true; break } }
                if (-not $ok) { throw "localhost:$IapLocalPort ueber IAP nicht erreichbar" }
                "Tunnel auf localhost:$IapLocalPort verbunden"
            } finally { if (-not $proc.HasExited) { $proc.Kill() } }
        }
    } else { Add-Skip -Id 'T15' -Name 'IAP-Tunnel auf 3389' -Reason 'ohne -IncludeIap' }
}

# =====================================================================================================
if ($Mode -eq 'Guest') {
    Import-Module ActiveDirectory
    $secretFile = 'C:\Workshop\secrets\workshop.json'
    $domain = Get-ADDomain
    $expectedDomain = ($DcFqdn -split '\.', 2)[1]
    $workshopDn = "OU=Workshop,$($domain.DistinguishedName)"

    Add-Check -Id 'G01' -Name 'Domaene und Hostname' -Test {
        if ($domain.DNSRoot -ne $expectedDomain) { throw "Domaene ist $($domain.DNSRoot)" }
        $fqdn = "$env:COMPUTERNAME.$($domain.DNSRoot)".ToLower()
        if ($fqdn -ne $DcFqdn.ToLower()) { throw "Host ist $fqdn" }
        $fqdn
    }
    Add-Check -Id 'G02' -Name 'NTDS und SYSVOL auf der Datendisk' -Test {
        $ntds = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\NTDS\Parameters').'DSA Working Directory'
        $sysvol = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters').SysVol
        if ($ntds -notlike 'D:\*' -or $sysvol -notlike 'D:\*') { throw "NTDS=$ntds SYSVOL=$sysvol" }
        "NTDS=$ntds SYSVOL=$sysvol"
    }
    Add-Check -Id 'G03' -Name 'DNS-Forwarder und Fremdaufloesung' -Test {
        $fw = @((Get-DnsServerForwarder).IPAddress | ForEach-Object { $_.IPAddressToString })
        if ($fw -notcontains '169.254.169.254') { throw "Forwarder: $($fw -join ',')" }
        $null = Resolve-DnsName kms.windows.googlecloud.com -Type A
        "Forwarder $($fw -join ','), kms.windows.googlecloud.com aufloesbar"
    }
    Add-Check -Id 'G04' -Name 'KMS erreichbar und Windows lizenziert' -Test {
        $kms = Test-NetConnection kms.windows.googlecloud.com -Port 1688 -WarningAction SilentlyContinue
        if (-not $kms.TcpTestSucceeded) { throw 'TCP 1688 zu kms.windows.googlecloud.com nicht erreichbar' }
        $lic = Get-CimInstance SoftwareLicensingProduct -Filter "PartialProductKey IS NOT NULL AND Name LIKE 'Windows%'" | Select-Object -First 1
        if ($lic.LicenseStatus -ne 1) { throw "LicenseStatus $($lic.LicenseStatus)" }
        'KMS erreichbar, LicenseStatus 1'
    }
    Add-Check -Id 'G05' -Name 'Zeitquelle' -Test {
        $src = (& w32tm /query /source) -join ''
        if ($src -notmatch 'metadata.google.internal') { throw "Quelle: $src" }
        $src
    }
    Add-Check -Id 'G06' -Name 'LDAPS-Zertifikat gueltig' -Test {
        $client = [System.Net.Sockets.TcpClient]::new($DcFqdn, 636)
        try {
            $ssl = [System.Net.Security.SslStream]::new($client.GetStream(), $false)
            $ssl.AuthenticateAsClient($DcFqdn)
            $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($ssl.RemoteCertificate)
            $sans = @($cert.DnsNameList | ForEach-Object { $_.Unicode })
            if ($sans -notcontains $DcFqdn) { throw "SAN: $($sans -join ',')" }
            $ekuExt = $cert.Extensions | Where-Object { $_.Oid.Value -eq '2.5.29.37' } | Select-Object -First 1
            $eku = @()
            if ($ekuExt) { $eku = @($ekuExt.EnhancedKeyUsages | ForEach-Object { $_.Value }) }
            if ($eku -notcontains '1.3.6.1.5.5.7.3.1') { throw 'Server-Authentication-EKU fehlt' }
            if ($cert.NotAfter -lt (Get-Date).AddDays(1)) { throw "laeuft ab: $($cert.NotAfter)" }
            "Aussteller $($cert.Issuer), gueltig bis $($cert.NotAfter.ToString('u'))"
        } finally { $client.Close() }
    }
    Add-Check -Id 'G07' -Name 'Workshop-OU: Objekte und Baseline' -Test {
        foreach ($ou in 'Users', 'Moved', 'Groups', 'ServiceAccounts') {
            if (-not (Get-ADOrganizationalUnit -LDAPFilter "(ou=$ou)" -SearchBase $workshopDn -SearchScope OneLevel)) { throw "OU $ou fehlt" }
        }
        $hans = Get-ADUser -LDAPFilter '(sAMAccountName=hans)' -SearchBase $workshopDn
        $anna = Get-ADUser -LDAPFilter '(sAMAccountName=anna)' -SearchBase $workshopDn
        $bind = Get-ADUser -LDAPFilter '(sAMAccountName=bind)' -SearchBase "OU=ServiceAccounts,$workshopDn"
        $op = Get-ADUser -LDAPFilter '(sAMAccountName=operator)' -SearchBase "OU=ServiceAccounts,$workshopDn"
        if (-not ($hans -and $anna -and $bind -and $op)) { throw 'Konto fehlt' }
        if (-not ($hans.Enabled -and $anna.Enabled)) { throw 'Testbenutzer deaktiviert' }
        if ($hans.DistinguishedName -notlike "*,OU=Users,$workshopDn") { throw "Hans liegt in $($hans.DistinguishedName)" }
        $staff = Get-ADGroup -LDAPFilter '(sAMAccountName=staff)' -SearchBase $workshopDn
        $leads = Get-ADGroup -LDAPFilter '(sAMAccountName=leads)' -SearchBase $workshopDn
        $managers = Get-ADGroup -LDAPFilter '(sAMAccountName=managers)' -SearchBase $workshopDn
        $staffM = @(Get-ADGroupMember $staff | ForEach-Object SamAccountName | Sort-Object)
        $leadsM = @(Get-ADGroupMember $leads | ForEach-Object SamAccountName)
        $mgrM = @(Get-ADGroupMember $managers | ForEach-Object SamAccountName)
        if (($staffM -join ',') -ne 'anna,hans') { throw "Mitarbeiter: $($staffM -join ',')" }
        if (($leadsM -join ',') -ne 'anna') { throw "Teamleitung: $($leadsM -join ',')" }
        if (($mgrM -join ',') -ne 'leads') { throw "Manager: $($mgrM -join ',')" }
        'OUs, 4 Konten, 3 Gruppen, Baseline-Mitgliedschaften'
    }
    Add-Check -Id 'G10' -Name 'Firewallregel LDAPS aktiv' -Test {
        $rule = Get-NetFirewallRule | Where-Object { $_.Enabled -eq 'True' -and $_.Direction -eq 'Inbound' -and $_.Action -eq 'Allow' } | Where-Object {
            ($_ | Get-NetFirewallPortFilter).LocalPort -contains '636'
        } | Select-Object -First 1
        if (-not $rule) { throw 'keine aktive Eingangsregel fuer TCP 636' }
        $rule.DisplayName
    }
    if (-not (Test-Path $secretFile)) {
        Add-Skip -Id 'G08' -Name 'Delegation' -Reason "Geheimnisdatei $secretFile fehlt"
    } else {
        # Windows PowerShell 5.1 kennt -AsHashtable nicht; Eigenschaftszugriff genuegt hier.
        $secret = Get-Content $secretFile -Raw | ConvertFrom-Json
        $cred = [pscredential]::new("$($domain.NetBIOSName)\operator", (ConvertTo-SecureString $secret.operator -AsPlainText -Force))
        Add-Check -Id 'G08' -Name 'Uebungskonto aendert eigene Objekte' -Test {
            $hans = Get-ADUser -LDAPFilter '(sAMAccountName=hans)' -SearchBase $workshopDn
            $leads = Get-ADGroup -LDAPFilter '(sAMAccountName=leads)' -SearchBase $workshopDn
            Set-ADUser -Identity $hans -Description 'workshop-test' -Credential $cred
            Set-ADUser -Identity $hans -Clear description -Credential $cred
            Add-ADGroupMember -Identity $leads -Members $hans -Credential $cred
            Remove-ADGroupMember -Identity $leads -Members $hans -Credential $cred -Confirm:$false
            'description und member gesetzt und zurueckgenommen'
        }
        Add-Check -Id 'G09' -Name 'Uebungskonto scheitert an Dienstkonten und Domaenen-Admin' -Test {
            $bind = Get-ADUser -LDAPFilter '(sAMAccountName=bind)' -SearchBase $workshopDn
            $admin = Get-ADUser -Identity 'Administrator'
            foreach ($target in $bind, $admin) {
                $denied = $false
                try { Set-ADUser -Identity $target -Description 'workshop-test' -Credential $cred } catch { $denied = $_.Exception.Message -match 'Insufficient access rights|Zugriff verweigert|Access is denied' }
                if (-not $denied) { Set-ADUser -Identity $target -Clear description; throw "Aenderung an $($target.SamAccountName) wurde nicht verweigert" }
            }
            'beide Aenderungen verweigert'
        }
    }
}

$file = Save-Report -ModeName $Mode -Directory $reportDir
Write-Host ''
$script:Report | Format-Table -AutoSize id, result, name | Out-String -Width 160 | Write-Host
Write-Host "Bericht: $file"
exit (Get-ReportExitCode -Report $script:Report)
