<#
.SYNOPSIS
Legt die GCP-Ressourcen des AD-Workshops an und schreibt ein Manifest.

.DESCRIPTION
Prueft Projekt, Billing, APIs, Image, Maschinentyp und Quota nur lesend, erkennt vorhandene
Ressourcen anhand des Manifests und legt fehlende in fester Reihenfolge an. -PlanOnly gibt
die vorgesehenen Aenderungen aus, ohne etwas zu veraendern.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidatePattern('^[a-z][a-z0-9-]{4,28}[a-z0-9]$')][string]$ProjectId,
    [ValidatePattern('^[a-z]+-[a-z]+\d$')][string]$Region = 'europe-west3',
    [ValidatePattern('^[a-z]+-[a-z]+\d-[a-z]$')][string]$Zone = 'europe-west3-a',
    [ValidatePattern('^[a-z][a-z0-9]{2,11}$')][string]$Prefix = 'kcad',
    [Parameter(Mandatory)][string[]]$LdapsSourceRanges,
    [Parameter(Mandatory)][ValidatePattern('^(user|group|serviceAccount):.+@.+$')][string]$TrainerPrincipal,
    [Parameter(Mandatory)][datetime]$ExpiresAt,
    [string]$MachineType = 'e2-standard-2',
    [ValidateRange(50, 200)][int]$BootDiskGb = 64,
    [ValidateRange(10, 100)][int]$DataDiskGb = 20,
    [string]$SubnetRange = '10.80.0.0/24',
    [string]$InternalIp = '10.80.0.10',
    [ValidatePattern('^[a-z][a-z0-9]{2,19}$')][string]$AdminUser = 'wsadmin',
    [string]$ManifestPath = '',
    [int]$ReadyTimeoutMinutes = 15,
    [switch]$TrainerSsh,
    [string]$TrainerSshPublicKeyPath = ([System.IO.Path]::Combine($HOME, '.ssh', 'id_ed25519.pub')),
    [switch]$PlanOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not (Get-Module -Name Workshop.Common)) { Import-Module ([System.IO.Path]::Combine($PSScriptRoot, 'lib', 'Workshop.Common.psm1')) }
Reset-WorkshopPlanState
if (-not $ManifestPath) { $ManifestPath = (Get-WorkshopRunPaths -Prefix $Prefix -RunRoot ([System.IO.Path]::Combine($PSScriptRoot, '..', '.run'))).Manifest }
if ($PlanOnly) { Enable-WorkshopPlanOnly }

$IapRange = '35.235.240.0/20'
$IapRole = 'roles/iap.tunnelResourceAccessor'
$IapConditionTitle = 'keycloak-ad-workshop rdp'
$IapConditionExpression = if ($TrainerSsh) { 'destination.port == 3389 || destination.port == 22' } else { 'destination.port == 3389' }
$trainerSshKey = ''
if ($TrainerSsh) {
    if (-not (Test-Path $TrainerSshPublicKeyPath)) { throw "Oeffentlicher SSH-Schluessel fehlt: $TrainerSshPublicKeyPath" }
    $trainerSshKey = (Get-Content $TrainerSshPublicKeyPath -Raw).Trim()
    if ($trainerSshKey -notmatch '^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp256) ') { throw "Keine OpenSSH-Public-Key-Zeile: $TrainerSshPublicKeyPath" }
}
$trainerSshScript = [System.IO.Path]::Combine($PSScriptRoot, 'lib', 'Enable-TrainerSsh.ps1')

function Test-Cidr {
    param([string]$Cidr)
    if ($Cidr -notmatch '^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})/(\d{1,2})$') { return $false }
    foreach ($o in $Matches[1..4]) { if ([int]$o -gt 255) { return $false } }
    return ([int]$Matches[5] -le 32)
}

function ConvertTo-IpNumber {
    param([string]$Ip)
    $bytes = [System.Net.IPAddress]::Parse($Ip).GetAddressBytes()
    return ([uint32]$bytes[0] -shl 24) -bor ([uint32]$bytes[1] -shl 16) -bor ([uint32]$bytes[2] -shl 8) -bor [uint32]$bytes[3]
}

function Test-IpInRange {
    param([string]$Ip, [string]$Cidr)
    $parts = $Cidr.Split('/')
    $mask = if ([int]$parts[1] -eq 0) { [uint32]0 } else { [uint32]::MaxValue -shl (32 - [int]$parts[1]) }
    return (((ConvertTo-IpNumber $Ip) -band $mask) -eq ((ConvertTo-IpNumber $parts[0]) -band $mask))
}

# --- Eingaben -------------------------------------------------------------------------------------
# Ueber pwsh -File kommen mehrere Bereiche als ein kommagetrennter String an.
$LdapsSourceRanges = @($LdapsSourceRanges | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
if (-not $Zone.StartsWith("$Region-")) { throw "Zone $Zone liegt nicht in Region $Region" }
foreach ($r in $LdapsSourceRanges) {
    if (-not (Test-Cidr $r)) { throw "Ungueltiges CIDR fuer LDAPS-Quelle: $r" }
    if ($r -eq '0.0.0.0/0' -or [int]$r.Split('/')[1] -lt 24) { throw "LDAPS-Quelle zu weit gefasst: $r (0.0.0.0/0 und Praefixe kuerzer als /24 sind nicht erlaubt)" }
}
if (-not (Test-Cidr $SubnetRange)) { throw "Ungueltiges Subnetz: $SubnetRange" }
if (-not (Test-IpInRange -Ip $InternalIp -Cidr $SubnetRange)) { throw "InternalIp $InternalIp liegt nicht in $SubnetRange" }
$now = Get-Date
if ($ExpiresAt -le $now) { throw "ExpiresAt $ExpiresAt liegt nicht in der Zukunft" }
if (($ExpiresAt - $now).TotalHours -gt 48) { throw "ExpiresAt $ExpiresAt liegt mehr als 48 Stunden entfernt; freigegeben sind hoechstens 48 Stunden" }

$names = Get-WorkshopResourceNames -Prefix $Prefix
$P = "--project=$ProjectId"

# --- Vorpruefung, nur lesend ------------------------------------------------------------------------
Write-WorkshopStep "Vorpruefung fuer Projekt $ProjectId"
$project = Get-GcloudJson -Arguments @('projects', 'describe', $ProjectId)
if (-not $project.projectNumber) { throw "Projekt $ProjectId nicht lesbar" }
$billing = Get-GcloudJson -Arguments @('billing', 'projects', 'describe', $ProjectId)
if (-not $billing.billingEnabled) { throw "Projekt $ProjectId hat keine aktive Abrechnung" }
$services = @(Get-GcloudJson -Arguments @('services', 'list', '--enabled', $P) | ForEach-Object { $_.config.name })
foreach ($api in 'compute.googleapis.com', 'iap.googleapis.com') {
    if ($services -notcontains $api) { throw "API $api ist im Projekt $ProjectId nicht aktiviert. Aktivierung ist kein Teil dieses Skripts." }
}
$image = Get-GcloudJson -Arguments @('compute', 'images', 'describe-from-family', 'windows-2022', '--project=windows-cloud')
$machine = Get-GcloudJson -Arguments @('compute', 'machine-types', 'describe', $MachineType, "--zone=$Zone", $P)
$regionInfo = Get-GcloudJson -Arguments @('compute', 'regions', 'describe', $Region, $P)
$quotaProblems = @()
if ($regionInfo -and $regionInfo.PSObject.Properties['quotas']) {
    foreach ($q in $regionInfo.quotas) {
        $need = switch ($q.metric) { 'CPUS' { $machine.guestCpus } 'IN_USE_ADDRESSES' { 1 } 'STATIC_ADDRESSES' { 1 } default { 0 } }
        if ($need -gt 0 -and ($q.limit - $q.usage) -lt $need) { $quotaProblems += "$($q.metric): frei $($q.limit - $q.usage), benoetigt $need" }
    }
}
if ($quotaProblems) { throw "Quota reicht nicht aus: $($quotaProblems -join '; ')" }
$gcloudVersion = Get-GcloudJson -Arguments @('version')

# --- Manifest -------------------------------------------------------------------------------------
$manifest = $null
if (Test-Path $ManifestPath) {
    $existing = Read-WorkshopManifest -Path $ManifestPath
    if ($existing.status -ne 'removed') {
        foreach ($pair in @(@('projectId', $ProjectId), @('zone', $Zone), @('prefix', $Prefix))) {
            if ($existing[$pair[0]] -ne $pair[1]) { throw "Manifest $ManifestPath gehoert zu $($pair[0])=$($existing[$pair[0]]), Aufruf verwendet $($pair[1]). Abbruch." }
        }
        $manifest = $existing
        Write-WorkshopStep "Vorhandenes Manifest run-id $($manifest.runId) wird fortgesetzt"
    }
}
if (-not $manifest) {
    $manifest = New-WorkshopManifest -ProjectId $ProjectId -ProjectNumber ([string]$project.projectNumber) -Region $Region -Zone $Zone -Prefix $Prefix -RunId (Get-Date -Format 'yyyyMMdd-HHmm') -ExpiresAt $ExpiresAt
}
$runId = $manifest.runId
$desc = Get-WorkshopDescription -RunId $runId
$labels = Get-WorkshopLabels -RunId $runId
$manifest.versions = [ordered]@{
    image = $image.name; imageSelfLink = $image.selfLink; machineType = $MachineType
    gcloud = ($gcloudVersion.PSObject.Properties | Where-Object Name -eq 'Google Cloud SDK' | ForEach-Object Value)
}
$manifest.network = [ordered]@{ subnetRange = $SubnetRange; internalIp = $InternalIp; ldapsSourceRanges = @($LdapsSourceRanges); iapRange = $IapRange; networkTag = $names.NetworkTag; trainerSsh = [bool]$TrainerSsh }

# --- Ressourcenplan -------------------------------------------------------------------------------
$plan = @(
    [ordered]@{ Key = 'network'; Name = $names.Network; Scope = 'global'
        Describe = @('compute', 'networks', 'describe', $names.Network, $P)
        Create   = @('compute', 'networks', 'create', $names.Network, $P, '--subnet-mode=custom', "--description=$desc") },
    [ordered]@{ Key = 'subnet'; Name = $names.Subnet; Scope = 'region'
        Describe = @('compute', 'networks', 'subnets', 'describe', $names.Subnet, "--region=$Region", $P)
        Create   = @('compute', 'networks', 'subnets', 'create', $names.Subnet, $P, "--region=$Region", "--network=$($names.Network)", "--range=$SubnetRange", "--description=$desc") },
    [ordered]@{ Key = 'firewallLdaps'; Name = $names.FirewallLdaps; Scope = 'global'
        Describe = @('compute', 'firewall-rules', 'describe', $names.FirewallLdaps, $P)
        Create   = @('compute', 'firewall-rules', 'create', $names.FirewallLdaps, $P, "--network=$($names.Network)", '--direction=INGRESS', '--action=ALLOW', '--rules=tcp:636', "--source-ranges=$($LdapsSourceRanges -join ',')", "--target-tags=$($names.NetworkTag)", "--description=$desc") },
    [ordered]@{ Key = 'firewallIapRdp'; Name = $names.FirewallIapRdp; Scope = 'global'
        Describe = @('compute', 'firewall-rules', 'describe', $names.FirewallIapRdp, $P)
        Create   = @('compute', 'firewall-rules', 'create', $names.FirewallIapRdp, $P, "--network=$($names.Network)", '--direction=INGRESS', '--action=ALLOW', '--rules=tcp:3389', "--source-ranges=$IapRange", "--target-tags=$($names.NetworkTag)", "--description=$desc") },
    [ordered]@{ Key = 'firewallIapSsh'; Name = $names.FirewallIapSsh; Scope = 'global'; Optional = (-not $TrainerSsh)
        Describe = @('compute', 'firewall-rules', 'describe', $names.FirewallIapSsh, $P)
        Create   = @('compute', 'firewall-rules', 'create', $names.FirewallIapSsh, $P, "--network=$($names.Network)", '--direction=INGRESS', '--action=ALLOW', '--rules=tcp:22', "--source-ranges=$IapRange", "--target-tags=$($names.NetworkTag)", "--description=$desc") },
    [ordered]@{ Key = 'internalAddress'; Name = $names.InternalAddress; Scope = 'region'
        Describe = @('compute', 'addresses', 'describe', $names.InternalAddress, "--region=$Region", $P)
        Create   = @('compute', 'addresses', 'create', $names.InternalAddress, $P, "--region=$Region", "--subnet=$($names.Subnet)", "--addresses=$InternalIp", "--description=$desc") },
    [ordered]@{ Key = 'externalAddress'; Name = $names.ExternalAddress; Scope = 'region'
        Describe = @('compute', 'addresses', 'describe', $names.ExternalAddress, "--region=$Region", $P)
        Create   = @('compute', 'addresses', 'create', $names.ExternalAddress, $P, "--region=$Region", '--network-tier=PREMIUM', "--description=$desc") },
    [ordered]@{ Key = 'dataDisk'; Name = $names.DataDisk; Scope = 'zone'
        Describe = @('compute', 'disks', 'describe', $names.DataDisk, "--zone=$Zone", $P)
        Create   = @('compute', 'disks', 'create', $names.DataDisk, $P, "--zone=$Zone", "--size=${DataDiskGb}GB", '--type=pd-balanced', "--description=$desc", "--labels=$labels") },
    [ordered]@{ Key = 'instance'; Name = $names.Instance; Scope = 'zone'
        Describe = @('compute', 'instances', 'describe', $names.Instance, "--zone=$Zone", $P)
        Create   = @('compute', 'instances', 'create', $names.Instance, $P, "--zone=$Zone", "--machine-type=$MachineType",
            "--image=$($image.name)", '--image-project=windows-cloud', "--boot-disk-size=${BootDiskGb}GB", '--boot-disk-type=pd-balanced',
            "--boot-disk-device-name=$($names.Instance)", "--disk=name=$($names.DataDisk),device-name=adds-data,mode=rw,boot=no",
            "--network-interface=subnet=$($names.Subnet),private-network-ip=$InternalIp,address=$($names.ExternalAddress)",
            "--tags=$($names.NetworkTag)", '--no-service-account', '--no-scopes', '--shielded-secure-boot', '--shielded-vtpm',
            '--shielded-integrity-monitoring', "--labels=$labels", '--metadata=enable-oslogin=FALSE', "--description=$desc") }
)

# Erst alle Existenzpruefungen, damit ein Abbruch keine halbfertigen Ressourcen hinterlaesst.
$plan = @($plan | Where-Object { -not ($_.Contains('Optional') -and $_.Optional) })
$state = @{}
foreach ($item in $plan) {
    $found = Get-GcloudJson -Arguments $item.Describe -IgnoreNotFound
    if ($null -ne $found) {
        if (-not (Test-WorkshopOwnedResource -Resource $found -RunId $runId)) {
            throw "Ressource $($item.Name) existiert bereits ohne Eigentumsnachweis fuer run-id $runId. Abbruch, nichts wurde veraendert."
        }
        $state[$item.Key] = $found
    }
}

Write-Host ''
Write-Host 'Ressourcenplan:' -ForegroundColor Green
foreach ($item in $plan) {
    $status = if ($state.ContainsKey($item.Key)) { 'vorhanden' } else { 'anlegen' }
    Write-Host ("  {0,-16} {1,-26} {2}" -f $item.Key, $item.Name, $status)
}
Write-Host ("  {0,-16} {1,-26} {2}" -f 'iamBinding', $IapRole, "Bedingung '$IapConditionExpression' fuer $TrainerPrincipal")
Write-Host "  Image: $($image.name), Maschinentyp: $MachineType ($($machine.guestCpus) vCPU, $($machine.memoryMb) MB)"
Write-Host "  LDAPS-Quellen: $($LdapsSourceRanges -join ', '); RDP nur aus $IapRange"
Write-Host "  Ablauf: $($manifest.expiresAt)"
Write-Host ''

# --- Anlegen --------------------------------------------------------------------------------------
foreach ($item in $plan) {
    if ($state.ContainsKey($item.Key)) {
        $obj = $state[$item.Key]
        $manifest.resources[$item.Key] = [ordered]@{ name = $obj.name; selfLink = $obj.selfLink; scope = $item.Scope; createdAt = $obj.creationTimestamp }
        continue
    }
    $created = Invoke-GcloudChange -Arguments $item.Create -Description "$($item.Key) $($item.Name) anlegen"
    if (Test-WorkshopPlanOnly) { continue }
    $obj = if ($created -is [array]) { $created[0] } else { $created }
    if (-not $obj -or -not $obj.PSObject.Properties['selfLink']) { $obj = Get-GcloudJson -Arguments $item.Describe }
    $manifest.resources[$item.Key] = [ordered]@{ name = $obj.name; selfLink = $obj.selfLink; scope = $item.Scope; createdAt = (Get-Date).ToUniversalTime().ToString('o') }
    $state[$item.Key] = $obj
    Save-WorkshopManifest -Manifest $manifest -Path $ManifestPath
}

# --- IAP-Bindung auf die Tunnel-Instanz -----------------------------------------------------------
if (Test-WorkshopPlanOnly) {
    Write-Host "[plan] IAP-Binding $IapRole fuer $TrainerPrincipal auf $($names.Instance), Bedingung '$IapConditionExpression'" -ForegroundColor Yellow
} else {
    $instance = $state['instance']
    $instanceId = [string]$instance.id
    $existingBinding = @($manifest.iamBindings | Where-Object { $_.principal -eq $TrainerPrincipal -and $_.role -eq $IapRole -and $_.conditionExpression -eq $IapConditionExpression })
    if (-not $existingBinding) {
        Write-WorkshopStep "IAP-Tunnelzugriff fuer $TrainerPrincipal auf $($names.Instance):3389"
        try {
            $policy = Get-IapTunnelPolicy -ProjectNumber $manifest.projectNumber -Zone $Zone -InstanceId $instanceId
            $bindings = @()
            if ($policy.PSObject.Properties['bindings'] -and $policy.bindings) { $bindings = @($policy.bindings) }
            # Eine vorhandene Workshop-Bindung (etwa nur 3389) wird durch die gewuenschte ersetzt.
            $bindings = @($bindings | Where-Object { -not ($_.role -eq $IapRole -and $_.PSObject.Properties['condition'] -and $_.condition.title -eq $IapConditionTitle -and $_.members -contains $TrainerPrincipal) })
            $bindings += [pscustomobject]@{ role = $IapRole; members = @($TrainerPrincipal); condition = [pscustomobject]@{ title = $IapConditionTitle; expression = $IapConditionExpression } }
            $newPolicy = [ordered]@{ bindings = $bindings; version = 3 }
            if ($policy.PSObject.Properties['etag']) { $newPolicy.etag = $policy.etag }
            Set-IapTunnelPolicy -ProjectNumber $manifest.projectNumber -Zone $Zone -InstanceId $instanceId -Policy $newPolicy | Out-Null
            $manifest.iamBindings = @($manifest.iamBindings | Where-Object { -not ($_.principal -eq $TrainerPrincipal -and $_.role -eq $IapRole) }) + @([ordered]@{ principal = $TrainerPrincipal; role = $IapRole; conditionTitle = $IapConditionTitle; conditionExpression = $IapConditionExpression; instanceId = $instanceId; resource = (Get-IapTunnelResourceUrl -ProjectNumber $manifest.projectNumber -Zone $Zone -InstanceId $instanceId) })
            Save-WorkshopManifest -Manifest $manifest -Path $ManifestPath
        } catch {
            Save-WorkshopManifest -Manifest $manifest -Path $ManifestPath
            throw "IAP-Bindung fehlgeschlagen (fehlt roles/iap.admin oder Owner?). Ressourcen sind angelegt und im Manifest erfasst. Fehler: $($_.Exception.Message)"
        }
    }
}

# --- Trainer-SSH ueber Startskript (nur oeffentlicher Schluessel in den Metadaten) ----------------
if ($TrainerSsh) {
    if (Test-WorkshopPlanOnly) {
        Write-Host "[plan] Metadaten windows-startup-script-ps1 (Enable-TrainerSsh.ps1) und trainer-ssh-key auf $($names.Instance)" -ForegroundColor Yellow
    } else {
        $items = @()
        if ($state['instance'].metadata.PSObject.Properties['items'] -and $state['instance'].metadata.items) { $items = @($state['instance'].metadata.items) }
        $hasKey = $items | Where-Object { $_.key -eq 'trainer-ssh-key' -and $_.value.Trim() -eq $trainerSshKey }
        $hasScript = $items | Where-Object { $_.key -eq 'windows-startup-script-ps1' }
        if (-not ($hasKey -and $hasScript)) {
            Invoke-GcloudChange -Arguments @('compute', 'instances', 'add-metadata', $names.Instance, "--zone=$Zone", $P, "--metadata=trainer-ssh-key=$trainerSshKey", "--metadata-from-file=windows-startup-script-ps1=$trainerSshScript") -Description 'Trainer-SSH-Startskript und Schluessel in Metadaten setzen' | Out-Null
            $manifest.domain.trainerSshMetadataAt = (Get-Date).ToUniversalTime().ToString('o')
            Save-WorkshopManifest -Manifest $manifest -Path $ManifestPath
        }
    }
}

# --- Warten auf Windows und lokales Administratorkonto ---------------------------------------------
if (Test-WorkshopPlanOnly) {
    Write-Host "[plan] Warten auf 'Instance setup finished' und reset-windows-password --user=$AdminUser" -ForegroundColor Yellow
    Write-Host ''
    Write-Host "PlanOnly: $((Get-WorkshopPlannedChanges).Count) Aenderungen geplant, nichts veraendert, kein Manifest geschrieben." -ForegroundColor Green
    return
}

$externalIp = (Get-GcloudJson -Arguments @('compute', 'addresses', 'describe', $names.ExternalAddress, "--region=$Region", $P)).address
$manifest.network.externalIp = $externalIp
Save-WorkshopManifest -Manifest $manifest -Path $ManifestPath

$secretsDir = Join-Path (Split-Path -Parent $ManifestPath) 'secrets'
$adminSecretPath = Join-Path $secretsDir "$AdminUser.json"
if (-not (Test-Path $adminSecretPath)) {
    Write-WorkshopStep "Warten bis Windows das erste Setup abgeschlossen hat (bis zu $ReadyTimeoutMinutes Minuten)"
    $deadline = (Get-Date).AddMinutes($ReadyTimeoutMinutes)
    $ready = $false
    while ((Get-Date) -lt $deadline) {
        $serial = Get-GcloudText -Arguments @('compute', 'instances', 'get-serial-port-output', $names.Instance, "--zone=$Zone", $P)
        if ($serial -match 'Instance setup finished|Finished running startup scripts') { $ready = $true; break }
        Start-Sleep -Seconds 20
    }
    if (-not $ready) { throw "Windows meldete innerhalb von $ReadyTimeoutMinutes Minuten kein abgeschlossenes Setup. Spaeter erneut aufrufen; das Manifest ist gespeichert." }
    $cred = Invoke-GcloudChange -Arguments @('compute', 'reset-windows-password', $names.Instance, "--zone=$Zone", $P, "--user=$AdminUser") -Description "Lokales Administratorkonto $AdminUser anlegen"
    New-Item -ItemType Directory -Path $secretsDir -Force | Out-Null
    [ordered]@{ username = $cred.username; password = $cred.password; ip = $cred.ip_address; createdAt = (Get-Date).ToUniversalTime().ToString('o') } | ConvertTo-Json | Set-Content -Path $adminSecretPath -Encoding utf8
    if ($IsLinux -or $IsMacOS) { & chmod 600 $adminSecretPath }
    Write-Host "Zugangsdaten fuer $AdminUser liegen in $adminSecretPath (nicht im Manifest, nicht im Log)."
}

$manifest.status = 'created'
Save-WorkshopManifest -Manifest $manifest -Path $ManifestPath

Write-Host ''
Write-Host 'Bereitstellung abgeschlossen.' -ForegroundColor Green
Write-Host "  Manifest:     $ManifestPath"
Write-Host "  Externe IP:   $externalIp   Interne IP: $InternalIp"
Write-Host "  RDP-Tunnel:   gcloud compute start-iap-tunnel $($names.Instance) 3389 --local-host-port=localhost:33389 --zone=$Zone $P"
Write-Host "  Naechster Schritt: RDP auf localhost:33389 als $AdminUser, dann Initialize-Domain.ps1 im Gast."
if ($TrainerSsh) {
    Write-Host "  SSH-Tunnel:   gcloud compute start-iap-tunnel $($names.Instance) 22 --local-host-port=localhost:2222 --zone=$Zone $P"
    Write-Host "  Danach: ssh -p 2222 Administrator@localhost; das Startskript wirkt nach dem naechsten Neustart der VM."
}
