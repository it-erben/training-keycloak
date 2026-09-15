BeforeAll {
    Import-Module "$PSScriptRoot/../lib/Workshop.Common.psm1" -Force
    $script:Script = "$PSScriptRoot/../Protect-Workshop.ps1"
    function script:New-TestManifest {
        $path = Join-Path $TestDrive 'manifest.json'
        $m = New-WorkshopManifest -ProjectId 'demo-project' -ProjectNumber '123' -Region 'europe-west3' -Zone 'europe-west3-a' -Prefix 'kcad' -RunId '20260915-1200' -ExpiresAt (Get-Date).AddDays(1)
        $m.resources['instance'] = @{ name = 'kcad-dc01'; selfLink = 'https://x/kcad-dc01'; scope = 'zone' }
        Save-WorkshopManifest -Manifest $m -Path $path
        return $path
    }
    function script:Set-InstanceMock {
        param([string]$Json)
        $global:KcadInstanceJson = $Json
        Mock Invoke-GcloudRaw -ModuleName Workshop.Common {
            if (($Arguments -join ' ') -match 'instances describe') { return $global:KcadInstanceJson }
            return '{}'
        }
    }
    $script:Owned = '{"name":"kcad-dc01","selfLink":"https://x/kcad-dc01","labels":{"workshop":"keycloak-ad","run-id":"20260915-1200"},"metadata":{"items":[{"key":"enable-oslogin","value":"FALSE"}]}}'
}
AfterAll { Remove-Variable -Name KcadInstanceJson -Scope Global -ErrorAction SilentlyContinue }

Describe 'Protect-Workshop' {
    It 'adds the metadata exactly once and records it' {
        $path = New-TestManifest
        Set-InstanceMock -Json $script:Owned
        & $script:Script -ManifestPath $path
        Should -Invoke Invoke-GcloudRaw -ModuleName Workshop.Common -Times 1 -ParameterFilter {
            ($Arguments -join ' ') -match 'instances add-metadata kcad-dc01 --zone=europe-west3-a --project=demo-project --metadata=disable-account-manager=true'
        }
        (Read-WorkshopManifest -Path $path).domain.accountManagerDisabledAt | Should -Not -BeNullOrEmpty
    }
    It 'does nothing in plan mode' {
        $path = New-TestManifest
        Set-InstanceMock -Json $script:Owned
        & $script:Script -ManifestPath $path -PlanOnly
        Should -Invoke Invoke-GcloudRaw -ModuleName Workshop.Common -Times 0 -ParameterFilter { ($Arguments -join ' ') -match 'add-metadata' }
    }
    It 'skips when already disabled' {
        $path = New-TestManifest
        Set-InstanceMock -Json ($script:Owned -replace 'enable-oslogin","value":"FALSE"', 'disable-account-manager","value":"true"')
        & $script:Script -ManifestPath $path
        Should -Invoke Invoke-GcloudRaw -ModuleName Workshop.Common -Times 0 -ParameterFilter { ($Arguments -join ' ') -match 'add-metadata' }
    }
    It 'aborts on a foreign instance' {
        $path = New-TestManifest
        Set-InstanceMock -Json '{"name":"kcad-dc01","selfLink":"https://x/kcad-dc01","labels":{"workshop":"other"},"metadata":{}}'
        { & $script:Script -ManifestPath $path } | Should -Throw '*Labels*'
        Should -Invoke Invoke-GcloudRaw -ModuleName Workshop.Common -Times 0 -ParameterFilter { ($Arguments -join ' ') -match 'add-metadata' }
    }
}
