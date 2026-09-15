<#
.SYNOPSIS
Schaltet den Gast-Account-Manager der Workshop-VM nach der DC-Promotion ab.

.DESCRIPTION
Setzt die Instanz-Metadaten disable-account-manager=true, damit ein spaeterer
gcloud compute reset-windows-password keine Domaenenkonten mehr veraendern kann.
Vorher muss die Anmeldung als Domaenenadministrator geprueft sein.
#>
[CmdletBinding()]
param(
    [string]$ManifestPath = ([System.IO.Path]::Combine($PSScriptRoot, '..', '.run', 'manifest.json')),
    [switch]$PlanOnly
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not (Get-Module -Name Workshop.Common)) { Import-Module ([System.IO.Path]::Combine($PSScriptRoot, 'lib', 'Workshop.Common.psm1')) }
Reset-WorkshopPlanState
if ($PlanOnly) { Enable-WorkshopPlanOnly }

$m = Read-WorkshopManifest -Path $ManifestPath
if (-not $m.resources.ContainsKey('instance')) { throw 'Manifest enthaelt keine Instanz' }
$name = $m.resources.instance.name
$common = @("--zone=$($m.zone)", "--project=$($m.projectId)")
$inst = Get-GcloudJson -Arguments (@('compute', 'instances', 'describe', $name) + $common)
if (-not (Test-WorkshopOwnedResource -Resource $inst -RunId $m.runId)) { throw "Instanz $name traegt nicht die Labels von run-id $($m.runId). Abbruch." }
if ($inst.selfLink -ne $m.resources.instance.selfLink) { throw "selfLink von $name weicht vom Manifest ab. Abbruch." }

$items = @()
if ($inst.metadata.PSObject.Properties['items'] -and $inst.metadata.items) { $items = @($inst.metadata.items) }
if ($items | Where-Object { $_.key -eq 'disable-account-manager' -and $_.value -eq 'true' }) {
    Write-WorkshopStep "Gast-Account-Manager auf $name ist bereits deaktiviert"
    return
}
Invoke-GcloudChange -Arguments (@('compute', 'instances', 'add-metadata', $name) + $common + @('--metadata=disable-account-manager=true')) -Description "Gast-Account-Manager auf $name per Metadaten deaktivieren" | Out-Null
if (Test-WorkshopPlanOnly) { return }
$m.domain.accountManagerDisabledAt = (Get-Date).ToUniversalTime().ToString('o')
Save-WorkshopManifest -Manifest $m -Path $ManifestPath
Write-Host "disable-account-manager=true gesetzt; im Manifest vermerkt."
