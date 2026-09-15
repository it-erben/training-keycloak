<#
.SYNOPSIS
Baut die GCP-Ressourcen des AD-Workshops anhand des Manifests ab.

.DESCRIPTION
Prueft Projektnummer, selfLinks und Eigentum jeder Ressource, entfernt die
Workshop-IAM-Bindung und loescht in fester Reihenfolge: Instanz, Disks, Adressen,
Firewallregeln, Subnetz, VPC. Fremde oder abweichende Ressourcen fuehren zum Abbruch.
-Local entfernt zusaetzlich den Compose-Stack ueber seinen Projektnamen.
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [ValidatePattern('^[a-z][a-z0-9]{2,11}$')][string]$Prefix = 'kcad',
    [string]$ManifestPath = '',
    [string]$LabPath = ([System.IO.Path]::Combine($PSScriptRoot, '..', 'lab')),
    [switch]$Local,
    [switch]$PlanOnly
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not (Get-Module -Name Workshop.Common)) { Import-Module ([System.IO.Path]::Combine($PSScriptRoot, 'lib', 'Workshop.Common.psm1')) }
Reset-WorkshopPlanState
if (-not $ManifestPath) { $ManifestPath = (Get-WorkshopRunPaths -Prefix $Prefix -RunRoot ([System.IO.Path]::Combine($PSScriptRoot, '..', '.run'))).Manifest }
if ($PlanOnly) { Enable-WorkshopPlanOnly }

$m = Read-WorkshopManifest -Path $ManifestPath
$P = "--project=$($m.projectId)"
$Z = "--zone=$($m.zone)"
$R = "--region=$($m.region)"

$project = Get-GcloudJson -Arguments @('projects', 'describe', $m.projectId)
if ([string]$project.projectNumber -ne [string]$m.projectNumber) { throw "Projektnummer $($project.projectNumber) passt nicht zum Manifest ($($m.projectNumber)). Abbruch." }

if (-not $PlanOnly -and -not $PSCmdlet.ShouldProcess($m.projectId, "Workshop-Ressourcen run-id $($m.runId) loeschen")) { return }

function Set-RemovedMark {
    param([string]$Key, [string]$Note)
    $m.removed[$Key] = "$((Get-Date).ToUniversalTime().ToString('o')) $Note"
    if (-not (Test-WorkshopPlanOnly)) { Save-WorkshopManifest -Manifest $m -Path $ManifestPath }
}

function Remove-Resource {
    param([string]$Key, [string[]]$DescribeArgs, [string[]]$DeleteArgs, [string]$ExpectedSelfLink, [switch]$SkipOwnership)
    if ($m.removed.ContainsKey($Key)) { Write-WorkshopStep "$Key bereits erledigt: $($m.removed[$Key])"; return }
    $found = Get-GcloudJson -Arguments $DescribeArgs -IgnoreNotFound
    if ($null -eq $found) { Set-RemovedMark -Key $Key -Note 'already deleted'; Write-WorkshopStep "$Key nicht mehr vorhanden"; return }
    if ($ExpectedSelfLink -and $found.selfLink -ne $ExpectedSelfLink) { throw "$Key`: selfLink $($found.selfLink) weicht vom Manifest ($ExpectedSelfLink) ab. Abbruch." }
    if (-not $SkipOwnership -and -not (Test-WorkshopOwnedResource -Resource $found -RunId $m.runId)) { throw "$Key`: $($found.name) ohne Eigentumsnachweis fuer run-id $($m.runId). Abbruch." }
    if ($found.PSObject.Properties['users'] -and $found.users) { throw "$Key`: $($found.name) wird noch verwendet von $($found.users -join ', '). Abbruch." }
    Invoke-GcloudChange -Arguments $DeleteArgs -Description "$Key $($found.name) loeschen" | Out-Null
    Set-RemovedMark -Key $Key -Note 'deleted'
}

function Get-ResourceName {
    param([string]$Key)
    if ($m.resources.ContainsKey($Key)) { return [string]$m.resources[$Key].name }
    return (Get-WorkshopResourceNames -Prefix $m.prefix)[($Key.Substring(0, 1).ToUpper() + $Key.Substring(1))]
}
function Get-ResourceSelfLink {
    param([string]$Key)
    if ($m.resources.ContainsKey($Key) -and $m.resources[$Key].ContainsKey('selfLink')) { return [string]$m.resources[$Key].selfLink }
    return $null
}

# 1. IAM-Bindung auf der Tunnel-Instanz
foreach ($b in @($m.iamBindings)) {
    if (-not $b.instanceId) { continue }
    $key = "iam:$($b.principal)"
    if ($m.removed.ContainsKey($key)) { continue }
    if (Test-WorkshopPlanOnly) { Write-Host "[plan] IAP-Bindung $($b.role) fuer $($b.principal) entfernen" -ForegroundColor Yellow; continue }
    Write-WorkshopStep "IAP-Bindung $($b.role) fuer $($b.principal) entfernen"
    try {
        $policy = Get-IapTunnelPolicy -ProjectNumber $m.projectNumber -Zone $m.zone -InstanceId $b.instanceId
    } catch {
        Write-Warning "IAP-Policy nicht lesbar (Instanz weg oder keine Rechte): $($_.Exception.Message)"
        continue
    }
    $bindings = @()
    if ($policy.PSObject.Properties['bindings'] -and $policy.bindings) { $bindings = @($policy.bindings) }
    $kept = @()
    $changed = $false
    foreach ($binding in $bindings) {
        $isOurs = $binding.role -eq $b.role -and $binding.PSObject.Properties['condition'] -and $binding.condition.title -eq $b.conditionTitle
        if ($isOurs -and $binding.members -contains $b.principal) {
            $rest = @($binding.members | Where-Object { $_ -ne $b.principal })
            $changed = $true
            if ($rest.Count -gt 0) { $binding.members = $rest; $kept += $binding }
        } else { $kept += $binding }
    }
    if ($changed) {
        $newPolicy = [ordered]@{ bindings = $kept; version = 3 }
        if ($policy.PSObject.Properties['etag']) { $newPolicy.etag = $policy.etag }
        Set-IapTunnelPolicy -ProjectNumber $m.projectNumber -Zone $m.zone -InstanceId $b.instanceId -Policy $newPolicy | Out-Null
    }
    Set-RemovedMark -Key $key -Note 'binding removed'
}

# 2. Instanz, dann Disks, Adressen, Firewall, Subnetz, VPC
$instanceName = Get-ResourceName 'instance'
Remove-Resource -Key 'instance' -DescribeArgs @('compute', 'instances', 'describe', $instanceName, $Z, $P) -DeleteArgs @('compute', 'instances', 'delete', $instanceName, $Z, $P) -ExpectedSelfLink (Get-ResourceSelfLink 'instance')

$dataDisk = Get-ResourceName 'dataDisk'
Remove-Resource -Key 'dataDisk' -DescribeArgs @('compute', 'disks', 'describe', $dataDisk, $Z, $P) -DeleteArgs @('compute', 'disks', 'delete', $dataDisk, $Z, $P) -ExpectedSelfLink (Get-ResourceSelfLink 'dataDisk')

# Die Bootdisk traegt den Instanznamen und wird normalerweise mit der Instanz geloescht.
$bootDisk = (Get-WorkshopResourceNames -Prefix $m.prefix).BootDisk
if (-not $m.removed.ContainsKey('bootDisk')) {
    $found = Get-GcloudJson -Arguments @('compute', 'disks', 'describe', $bootDisk, $Z, $P) -IgnoreNotFound
    if ($null -eq $found) { Set-RemovedMark -Key 'bootDisk' -Note 'already deleted with instance'; Write-WorkshopStep 'Bootdisk bereits mit der Instanz entfernt' }
    else {
        if (-not (Test-WorkshopOwnedResource -Resource $found -RunId $m.runId)) { throw "bootDisk: $bootDisk ohne Eigentumsnachweis. Abbruch." }
        if ($found.PSObject.Properties['users'] -and $found.users) { throw "bootDisk: $bootDisk noch angehaengt. Abbruch." }
        Invoke-GcloudChange -Arguments @('compute', 'disks', 'delete', $bootDisk, $Z, $P) -Description "bootDisk $bootDisk loeschen" | Out-Null
        Set-RemovedMark -Key 'bootDisk' -Note 'deleted'
    }
}

foreach ($key in 'externalAddress', 'internalAddress') {
    $n = Get-ResourceName $key
    Remove-Resource -Key $key -DescribeArgs @('compute', 'addresses', 'describe', $n, $R, $P) -DeleteArgs @('compute', 'addresses', 'delete', $n, $R, $P) -ExpectedSelfLink (Get-ResourceSelfLink $key)
}
foreach ($key in 'firewallLdaps', 'firewallIapRdp', 'firewallIapSsh') {
    if ($key -eq 'firewallIapSsh' -and -not $m.resources.ContainsKey($key)) { continue }
    $n = Get-ResourceName $key
    Remove-Resource -Key $key -DescribeArgs @('compute', 'firewall-rules', 'describe', $n, $P) -DeleteArgs @('compute', 'firewall-rules', 'delete', $n, $P) -ExpectedSelfLink (Get-ResourceSelfLink $key)
}
$subnet = Get-ResourceName 'subnet'
Remove-Resource -Key 'subnet' -DescribeArgs @('compute', 'networks', 'subnets', 'describe', $subnet, $R, $P) -DeleteArgs @('compute', 'networks', 'subnets', 'delete', $subnet, $R, $P) -ExpectedSelfLink (Get-ResourceSelfLink 'subnet')
$network = Get-ResourceName 'network'
Remove-Resource -Key 'network' -DescribeArgs @('compute', 'networks', 'describe', $network, $P) -DeleteArgs @('compute', 'networks', 'delete', $network, $P) -ExpectedSelfLink (Get-ResourceSelfLink 'network')

if ($Local) {
    $compose = Join-Path $LabPath 'docker-compose.yml'
    if (Test-WorkshopPlanOnly) { Write-Host "[plan] docker compose -f $compose down -v --remove-orphans" -ForegroundColor Yellow }
    else {
        Write-WorkshopStep 'Lokalen Compose-Stack keycloak-ad-workshop entfernen'
        & docker compose -f $compose -p keycloak-ad-workshop down -v --remove-orphans
    }
}

if (Test-WorkshopPlanOnly) {
    Write-Host "PlanOnly: $((Get-WorkshopPlannedChanges).Count) Loeschungen geplant, nichts veraendert." -ForegroundColor Green
    return
}
$m.status = 'removed'
$m.removedAt = (Get-Date).ToUniversalTime().ToString('o')
Save-WorkshopManifest -Manifest $m -Path $ManifestPath
Write-Host "Abbau abgeschlossen. Projekt $($m.projectId) bleibt bestehen; Manifest markiert als removed." -ForegroundColor Green
