BeforeAll {
    Import-Module "$PSScriptRoot/../lib/Workshop.Common.psm1" -Force
    $script:Script = "$PSScriptRoot/../New-Workshop.ps1"
    function script:Get-CommonArgs {
        return @{
            ProjectId = 'demo-project'; LdapsSourceRanges = @('203.0.113.0/24'); TrainerPrincipal = 'user:trainer@example.org'
            ExpiresAt = (Get-Date).AddHours(24); ManifestPath = (Join-Path $TestDrive 'manifest.json')
        }
    }
    function script:Set-ReadMocks {
        param([hashtable]$Overrides = @{})
        $global:KcadOverrides = $Overrides
        Mock Invoke-GcloudRaw -ModuleName Workshop.Common {
            $a = $Arguments -join ' '
            foreach ($k in $global:KcadOverrides.Keys) { if ($a -match $k) { return $global:KcadOverrides[$k] } }
            switch -Regex ($a) {
                '^projects describe' { return '{"projectId":"demo-project","projectNumber":"123"}' }
                '^billing projects describe' { return '{"billingEnabled":true,"billingAccountName":"billingAccounts/x"}' }
                '^services list' { return '[{"config":{"name":"compute.googleapis.com"}},{"config":{"name":"iap.googleapis.com"}}]' }
                'images describe-from-family' { return '{"name":"windows-server-2022-dc-v20260909","selfLink":"https://x/img"}' }
                'machine-types describe' { return '{"name":"e2-standard-2","guestCpus":2,"memoryMb":8192}' }
                'regions describe' { return '{"quotas":[{"metric":"CPUS","limit":24,"usage":0},{"metric":"IN_USE_ADDRESSES","limit":8,"usage":0},{"metric":"STATIC_ADDRESSES","limit":8,"usage":0}]}' }
                '^version' { return '{"Google Cloud SDK":"565.0.0"}' }
                'describe' { throw 'ERROR: (gcloud) Could not fetch resource: - The resource was not found' }
                default { throw "unexpected gcloud call: $a" }
            }
        }
        Mock Invoke-IapApi -ModuleName Workshop.Common { throw 'IAP must not be called' }
    }
}

Describe 'New-Workshop -PlanOnly' {
    It 'issues no mutating gcloud call and writes no manifest' {
        Set-ReadMocks
        $common = Get-CommonArgs
        & $Script @common -PlanOnly | Out-Null
        Should -Invoke Invoke-GcloudRaw -ModuleName Workshop.Common -Times 0 -ParameterFilter {
            ($Arguments -join ' ') -match '\b(create|delete|add-metadata|reset-windows-password|add-iam-policy-binding|enable)\b'
        }
        Should -Invoke Invoke-IapApi -ModuleName Workshop.Common -Times 0
        Test-Path $common.ManifestPath | Should -BeFalse
    }
    It 'rejects 0.0.0.0/0 as LDAPS source' {
        Set-ReadMocks
        $common = Get-CommonArgs
        { & $Script @common -LdapsSourceRanges @('0.0.0.0/0') -PlanOnly } | Should -Throw '*0.0.0.0/0*'
    }
    It 'rejects a prefix shorter than /24' {
        Set-ReadMocks
        $common = Get-CommonArgs
        { & $Script @common -LdapsSourceRanges @('203.0.0.0/16') -PlanOnly } | Should -Throw '*zu weit*'
    }
    It 'rejects an expiry beyond 48 hours' {
        Set-ReadMocks
        $common = Get-CommonArgs
        { & $Script @common -ExpiresAt (Get-Date).AddHours(72) -PlanOnly } | Should -Throw '*48*'
    }
    It 'rejects a zone outside the region' {
        Set-ReadMocks
        $common = Get-CommonArgs
        { & $Script @common -Region 'europe-west3' -Zone 'europe-west1-b' -PlanOnly } | Should -Throw '*Zone*'
    }
    It 'aborts when a same-named resource exists without ownership' {
        Set-ReadMocks -Overrides @{ 'networks describe' = '{"name":"kcad-vpc","description":"someone else","selfLink":"https://x/vpc"}' }
        $common = Get-CommonArgs
        { & $Script @common -PlanOnly } | Should -Throw '*kcad-vpc*'
    }
    It 'aborts when the compute API is missing' {
        Set-ReadMocks -Overrides @{ '^services list' = '[{"config":{"name":"iap.googleapis.com"}}]' }
        $common = Get-CommonArgs
        { & $Script @common -PlanOnly } | Should -Throw '*compute.googleapis.com*'
    }
    It 'aborts when billing is disabled' {
        Set-ReadMocks -Overrides @{ '^billing projects describe' = '{"billingEnabled":false}' }
        $common = Get-CommonArgs
        { & $Script @common -PlanOnly } | Should -Throw '*Abrechnung*'
    }
    It 'aborts when a manifest for another project exists' {
        Set-ReadMocks
        $common = Get-CommonArgs
        $m = New-WorkshopManifest -ProjectId 'other' -ProjectNumber '9' -Region 'europe-west3' -Zone 'europe-west3-a' -Prefix 'kcad' -RunId '20260101-0000' -ExpiresAt (Get-Date).AddHours(1)
        Save-WorkshopManifest -Manifest $m -Path $common.ManifestPath
        { & $Script @common -PlanOnly } | Should -Throw '*Manifest*'
    }
}

Describe 'New-Workshop create path' {
    It 'creates resources in order, binds IAP and records the manifest' {
        $global:KcadCalls = [System.Collections.Generic.List[string]]::new()
        Mock Invoke-GcloudRaw -ModuleName Workshop.Common {
            $a = $Arguments -join ' '
            $global:KcadCalls.Add($a)
            switch -Regex ($a) {
                '^projects describe' { return '{"projectId":"demo-project","projectNumber":"123"}' }
                '^billing projects describe' { return '{"billingEnabled":true}' }
                '^services list' { return '[{"config":{"name":"compute.googleapis.com"}},{"config":{"name":"iap.googleapis.com"}}]' }
                'images describe-from-family' { return '{"name":"img-1","selfLink":"https://x/img"}' }
                'machine-types describe' { return '{"name":"e2-standard-2","guestCpus":2,"memoryMb":8192}' }
                'regions describe' { return '{"quotas":[]}' }
                '^version' { return '{"Google Cloud SDK":"565.0.0"}' }
                'addresses describe kcad-dc01-external' {
                    if ($global:KcadCalls | Where-Object { $_ -match 'addresses create kcad-dc01-external' }) { return '{"name":"kcad-dc01-external","address":"198.51.100.7","selfLink":"https://x/ext"}' }
                    throw 'ERROR: The resource was not found'
                }
                'get-serial-port-output' { return 'GCEInstanceSetup: Instance setup finished. kcad-dc01 is ready to use.' }
                'reset-windows-password' { return '{"username":"wsadmin","password":"s3cret","ip_address":"198.51.100.7"}' }
                'describe' { throw 'ERROR: The resource was not found' }
                ' create ' { $name = ($Arguments | Where-Object { $_ -like 'kcad-*' } | Select-Object -First 1); return "[{""name"":""$name"",""selfLink"":""https://x/$name"",""id"":""42""}]" }
                default { throw "unexpected gcloud call: $a" }
            }
        }
        Mock Invoke-IapApi -ModuleName Workshop.Common {
            if ($Url -match 'getIamPolicy') { return [pscustomobject]@{ etag = 'e1'; version = 1; bindings = @([pscustomobject]@{ role = 'roles/viewer'; members = @('user:other@example.org') }) } }
            return [pscustomobject]@{ etag = 'e2' }
        }
        $common = Get-CommonArgs
        & $Script @common | Out-Null
        $creates = @($global:KcadCalls | Where-Object { $_ -match ' create ' })
        $creates[0] | Should -Match 'networks create kcad-vpc'
        $creates[1] | Should -Match 'subnets create kcad-subnet'
        $creates[-1] | Should -Match 'instances create kcad-dc01 '
        $creates[-1] | Should -Match '--no-service-account'
        $creates[-1] | Should -Match '--no-scopes'
        ($creates | Where-Object { $_ -match 'allow-ldaps' }) | Should -Match '--source-ranges=203.0.113.0/24'
        ($creates | Where-Object { $_ -match 'allow-iap-rdp' }) | Should -Match '--source-ranges=35.235.240.0/20'
        ($creates | Where-Object { $_ -match '0\.0\.0\.0/0' }) | Should -BeNullOrEmpty
        Should -Invoke Invoke-IapApi -ModuleName Workshop.Common -Times 1 -ParameterFilter {
            $Url -match 'setIamPolicy' -and ($Body.policy.bindings | Measure-Object).Count -eq 2 -and $Body.policy.version -eq 3
        }
        $m = Read-WorkshopManifest -Path $common.ManifestPath
        $m.status | Should -Be 'created'
        $m.resources.Keys | Should -Contain 'instance'
        $m.iamBindings[0].principal | Should -Be 'user:trainer@example.org'
        $m.network.externalIp | Should -Be '198.51.100.7'
        (Get-Content $common.ManifestPath -Raw) | Should -Not -Match 's3cret'
        (Get-Content (Join-Path $TestDrive 'secrets' 'wsadmin.json') -Raw) | Should -Match 's3cret'
    }
}

AfterAll {
    Remove-Variable -Name KcadOverrides, KcadCalls -Scope Global -ErrorAction SilentlyContinue
}
