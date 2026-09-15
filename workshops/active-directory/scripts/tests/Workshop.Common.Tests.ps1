BeforeAll {
    Import-Module "$PSScriptRoot/../lib/Workshop.Common.psm1" -Force
}

Describe 'Get-WorkshopResourceNames' {
    It 'derives every name from the prefix' {
        $n = Get-WorkshopResourceNames -Prefix 'kcad'
        $n.Network | Should -Be 'kcad-vpc'
        $n.Subnet | Should -Be 'kcad-subnet'
        $n.FirewallLdaps | Should -Be 'kcad-allow-ldaps'
        $n.FirewallIapRdp | Should -Be 'kcad-allow-iap-rdp'
        $n.InternalAddress | Should -Be 'kcad-dc01-internal'
        $n.ExternalAddress | Should -Be 'kcad-dc01-external'
        $n.DataDisk | Should -Be 'kcad-dc01-data'
        $n.Instance | Should -Be 'kcad-dc01'
        $n.BootDisk | Should -Be 'kcad-dc01'
        $n.NetworkTag | Should -Be 'kcad-dc'
    }
}

Describe 'Test-WorkshopOwnedResource' {
    It 'accepts matching labels' {
        $r = [pscustomobject]@{ labels = [pscustomobject]@{ workshop = 'keycloak-ad'; 'run-id' = '20260915-1200' } }
        Test-WorkshopOwnedResource -Resource $r -RunId '20260915-1200' | Should -BeTrue
    }
    It 'accepts a matching description' {
        $r = [pscustomobject]@{ description = 'keycloak-ad-workshop run-id=20260915-1200' }
        Test-WorkshopOwnedResource -Resource $r -RunId '20260915-1200' | Should -BeTrue
    }
    It 'rejects foreign resources' {
        $r = [pscustomobject]@{ name = 'kcad-vpc'; labels = [pscustomobject]@{ workshop = 'other' } }
        Test-WorkshopOwnedResource -Resource $r -RunId '20260915-1200' | Should -BeFalse
    }
    It 'rejects another run id' {
        $r = [pscustomobject]@{ description = 'keycloak-ad-workshop run-id=20260101-0000' }
        Test-WorkshopOwnedResource -Resource $r -RunId '20260915-1200' | Should -BeFalse
    }
}

Describe 'Invoke-GcloudChange' {
    BeforeEach { Reset-WorkshopPlanState }
    AfterEach { Reset-WorkshopPlanState }
    It 'records instead of executing in plan mode' {
        Mock Invoke-GcloudRaw { throw 'must not run' } -ModuleName Workshop.Common
        Enable-WorkshopPlanOnly
        $r = Invoke-GcloudChange -Arguments @('compute', 'networks', 'create', 'x') -Description 'create network x'
        $r | Should -BeNullOrEmpty
        (Get-WorkshopPlannedChanges) | Should -Contain 'create network x'
        Should -Invoke Invoke-GcloudRaw -ModuleName Workshop.Common -Times 0
    }
    It 'executes with --quiet and --format=json otherwise' {
        Mock Invoke-GcloudRaw { '{"name":"x"}' } -ModuleName Workshop.Common
        $r = Invoke-GcloudChange -Arguments @('compute', 'networks', 'create', 'x') -Description 'create'
        $r.name | Should -Be 'x'
        Should -Invoke Invoke-GcloudRaw -ModuleName Workshop.Common -Times 1 -ParameterFilter {
            $Arguments -contains '--quiet' -and $Arguments -contains '--format=json'
        }
    }
}

Describe 'Get-GcloudJson' {
    It 'returns null for not found when requested' {
        Mock Invoke-GcloudRaw { throw 'ERROR: (gcloud.compute.networks.describe) Could not fetch resource: - The resource was not found' } -ModuleName Workshop.Common
        Get-GcloudJson -Arguments @('compute', 'networks', 'describe', 'x') -IgnoreNotFound | Should -BeNullOrEmpty
    }
    It 'rethrows other errors' {
        Mock Invoke-GcloudRaw { throw 'ERROR: PERMISSION_DENIED' } -ModuleName Workshop.Common
        { Get-GcloudJson -Arguments @('compute', 'networks', 'describe', 'x') -IgnoreNotFound } | Should -Throw '*PERMISSION_DENIED*'
    }
    It 'refuses mutating verbs' {
        Mock Invoke-GcloudRaw { '{}' } -ModuleName Workshop.Common
        { Get-GcloudJson -Arguments @('compute', 'networks', 'delete', 'x') } | Should -Throw '*mutierenden*'
        Should -Invoke Invoke-GcloudRaw -ModuleName Workshop.Common -Times 0
    }
}

Describe 'Manifest' {
    It 'round-trips through JSON' {
        $path = Join-Path $TestDrive 'manifest.json'
        $m = New-WorkshopManifest -ProjectId 'p' -ProjectNumber '1' -Region 'europe-west3' -Zone 'europe-west3-a' -Prefix 'kcad' -RunId '20260915-1200' -ExpiresAt ([datetime]'2026-09-17T12:00:00Z')
        $m.resources['network'] = @{ name = 'kcad-vpc'; selfLink = 'https://example/x'; createdAt = '2026-09-15T12:00:00Z' }
        Save-WorkshopManifest -Manifest $m -Path $path
        $back = Read-WorkshopManifest -Path $path
        $back.projectId | Should -Be 'p'
        $back.resources.network.selfLink | Should -Be 'https://example/x'
        $back.runId | Should -Be '20260915-1200'
    }
    It 'refuses a manifest without project number' {
        $path = Join-Path $TestDrive 'bad.json'
        '{"projectId":"p"}' | Set-Content $path
        { Read-WorkshopManifest -Path $path } | Should -Throw '*projectNumber*'
    }
}
