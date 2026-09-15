Set-StrictMode -Version Latest

$script:PlanOnly = $false
$script:PlannedChanges = [System.Collections.Generic.List[string]]::new()
$script:WorkshopLabel = 'keycloak-ad'
$script:MutatingVerbs = '^(create|delete|add-metadata|remove-metadata|reset-windows-password|add-iam-policy-binding|remove-iam-policy-binding|enable|update|set-iam-policy|start|stop|reset)$'

function Write-WorkshopStep {
    param([Parameter(Mandatory)][string]$Text)
    Write-Host "==> $Text" -ForegroundColor Cyan
}

function Reset-WorkshopPlanState {
    $script:PlanOnly = $false
    $script:PlannedChanges.Clear()
}

function Enable-WorkshopPlanOnly { $script:PlanOnly = $true }
function Test-WorkshopPlanOnly { return $script:PlanOnly }
function Get-WorkshopPlannedChanges { return @($script:PlannedChanges) }

function Invoke-GcloudRaw {
    # Einziger Aufrufpunkt fuer gcloud. Tests ersetzen diese Funktion per Mock.
    param([Parameter(Mandatory)][string[]]$Arguments)
    $stderr = [System.IO.Path]::GetTempFileName()
    $env:CLOUDSDK_CORE_DISABLE_PROMPTS = '1'
    try {
        $stdout = & gcloud @Arguments 2> $stderr
        if ($LASTEXITCODE -ne 0) {
            throw ("gcloud {0} failed: {1}" -f ($Arguments -join ' '), (Get-Content $stderr -Raw))
        }
        return (@($stdout) -join "`n")
    } finally {
        Remove-Item $stderr -ErrorAction SilentlyContinue
    }
}

function Get-GcloudJson {
    # Lesender Aufruf. Wirft bei einem mutierenden Verb, damit Lesepfade nie versehentlich aendern.
    param([Parameter(Mandatory)][string[]]$Arguments, [switch]$IgnoreNotFound)
    if ($Arguments | Where-Object { $_ -match $script:MutatingVerbs }) {
        throw "Get-GcloudJson darf keine mutierenden Verben ausfuehren: $($Arguments -join ' ')"
    }
    try {
        $raw = Invoke-GcloudRaw -Arguments ($Arguments + '--format=json')
    } catch {
        if ($IgnoreNotFound -and $_.Exception.Message -match 'was not found|NOT_FOUND|HTTPError 404|not found') { return $null }
        throw
    }
    if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
    return $raw | ConvertFrom-Json
}

function Get-GcloudText {
    # Lesender Aufruf mit Textausgabe, etwa fuer die serielle Konsole.
    param([Parameter(Mandatory)][string[]]$Arguments)
    if ($Arguments | Where-Object { $_ -match $script:MutatingVerbs }) {
        throw "Get-GcloudText darf keine mutierenden Verben ausfuehren: $($Arguments -join ' ')"
    }
    return Invoke-GcloudRaw -Arguments $Arguments
}

function Invoke-GcloudChange {
    # Mutierender Aufruf. In PlanOnly wird nur die Beschreibung gesammelt.
    param([Parameter(Mandatory)][string[]]$Arguments, [Parameter(Mandatory)][string]$Description)
    if ($script:PlanOnly) {
        $script:PlannedChanges.Add($Description)
        Write-Host "[plan] $Description" -ForegroundColor Yellow
        Write-Host "       gcloud $($Arguments -join ' ')" -ForegroundColor DarkGray
        return $null
    }
    Write-WorkshopStep $Description
    $raw = Invoke-GcloudRaw -Arguments ($Arguments + @('--quiet', '--format=json'))
    if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
    return $raw | ConvertFrom-Json
}

function Get-WorkshopResourceNames {
    param([Parameter(Mandatory)][string]$Prefix)
    return @{
        Network         = "$Prefix-vpc"
        Subnet          = "$Prefix-subnet"
        FirewallLdaps   = "$Prefix-allow-ldaps"
        FirewallIapRdp  = "$Prefix-allow-iap-rdp"
        FirewallIapSsh  = "$Prefix-allow-iap-ssh"
        InternalAddress = "$Prefix-dc01-internal"
        ExternalAddress = "$Prefix-dc01-external"
        DataDisk        = "$Prefix-dc01-data"
        Instance        = "$Prefix-dc01"
        BootDisk        = "$Prefix-dc01"
        NetworkTag      = "$Prefix-dc"
    }
}

function Get-WorkshopDescription {
    param([Parameter(Mandatory)][string]$RunId)
    return "keycloak-ad-workshop run-id=$RunId"
}

function Get-WorkshopLabels {
    param([Parameter(Mandatory)][string]$RunId)
    return "workshop=$($script:WorkshopLabel),run-id=$RunId"
}

function Test-WorkshopOwnedResource {
    param([Parameter(Mandatory)]$Resource, [Parameter(Mandatory)][string]$RunId)
    $labels = $Resource.PSObject.Properties['labels']
    if ($labels -and $labels.Value) {
        $l = $labels.Value
        $w = $l.PSObject.Properties['workshop']
        $r = $l.PSObject.Properties['run-id']
        if ($w -and $r -and $w.Value -eq $script:WorkshopLabel -and $r.Value -eq $RunId) { return $true }
    }
    $desc = $Resource.PSObject.Properties['description']
    if ($desc -and $desc.Value -eq (Get-WorkshopDescription -RunId $RunId)) { return $true }
    return $false
}

function New-WorkshopManifest {
    param(
        [Parameter(Mandatory)][string]$ProjectId, [Parameter(Mandatory)][string]$ProjectNumber,
        [Parameter(Mandatory)][string]$Region, [Parameter(Mandatory)][string]$Zone,
        [Parameter(Mandatory)][string]$Prefix, [Parameter(Mandatory)][string]$RunId,
        [Parameter(Mandatory)][datetime]$ExpiresAt
    )
    return [ordered]@{
        schema        = 1
        status        = 'creating'
        projectId     = $ProjectId
        projectNumber = $ProjectNumber
        region        = $Region
        zone          = $Zone
        prefix        = $Prefix
        runId         = $RunId
        createdAt     = (Get-Date).ToUniversalTime().ToString('o')
        expiresAt     = $ExpiresAt.ToUniversalTime().ToString('o')
        versions      = [ordered]@{}
        network       = [ordered]@{}
        resources     = [ordered]@{}
        iamBindings   = @()
        domain        = [ordered]@{}
        removed       = [ordered]@{}
    }
}

function Save-WorkshopManifest {
    param([Parameter(Mandatory)]$Manifest, [Parameter(Mandatory)][string]$Path)
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $Manifest | ConvertTo-Json -Depth 12 | Set-Content -Path $Path -Encoding utf8
}

function Read-WorkshopManifest {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path $Path)) { throw "Manifest nicht gefunden: $Path" }
    $m = Get-Content $Path -Raw | ConvertFrom-Json -AsHashtable
    foreach ($k in 'projectId', 'projectNumber', 'zone', 'region', 'runId', 'prefix') {
        if (-not $m.ContainsKey($k) -or [string]::IsNullOrWhiteSpace([string]$m[$k])) { throw "Manifest ohne $k" }
    }
    foreach ($k in 'resources', 'removed', 'domain', 'network', 'versions') {
        if (-not $m.ContainsKey($k) -or $null -eq $m[$k]) { $m[$k] = @{} }
    }
    if (-not $m.ContainsKey('iamBindings') -or $null -eq $m['iamBindings']) { $m['iamBindings'] = @() }
    return $m
}

function Invoke-IapApi {
    # REST-Zugriff auf die IAP-API; die IAM-Policy der Tunnel-Instanz hat keinen gcloud-Befehl.
    param([Parameter(Mandatory)][string]$Method, [Parameter(Mandatory)][string]$Url, $Body)
    $token = (Invoke-GcloudRaw -Arguments @('auth', 'print-access-token')).Trim()
    $headers = @{ Authorization = "Bearer $token" }
    if ($null -ne $Body) {
        return Invoke-RestMethod -Method $Method -Uri $Url -Headers $headers -ContentType 'application/json' -Body ($Body | ConvertTo-Json -Depth 10)
    }
    return Invoke-RestMethod -Method $Method -Uri $Url -Headers $headers
}

function Get-IapTunnelResourceUrl {
    param([Parameter(Mandatory)][string]$ProjectNumber, [Parameter(Mandatory)][string]$Zone, [Parameter(Mandatory)][string]$InstanceId)
    return "https://iap.googleapis.com/v1/projects/$ProjectNumber/iap_tunnel/zones/$Zone/instances/${InstanceId}"
}

function Get-IapTunnelPolicy {
    param([Parameter(Mandatory)][string]$ProjectNumber, [Parameter(Mandatory)][string]$Zone, [Parameter(Mandatory)][string]$InstanceId)
    $url = (Get-IapTunnelResourceUrl -ProjectNumber $ProjectNumber -Zone $Zone -InstanceId $InstanceId) + ':getIamPolicy'
    return Invoke-IapApi -Method Post -Url $url -Body @{ options = @{ requestedPolicyVersion = 3 } }
}

function Set-IapTunnelPolicy {
    param([Parameter(Mandatory)][string]$ProjectNumber, [Parameter(Mandatory)][string]$Zone, [Parameter(Mandatory)][string]$InstanceId, [Parameter(Mandatory)]$Policy)
    $url = (Get-IapTunnelResourceUrl -ProjectNumber $ProjectNumber -Zone $Zone -InstanceId $InstanceId) + ':setIamPolicy'
    return Invoke-IapApi -Method Post -Url $url -Body @{ policy = $Policy }
}

Export-ModuleMember -Function *
