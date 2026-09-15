BeforeAll {
    Import-Module "$PSScriptRoot/../lib/Workshop.Common.psm1" -Force
    $script:Script = "$PSScriptRoot/../Remove-Workshop.ps1"
    function script:New-TestManifest {
        $path = Join-Path $TestDrive 'manifest.json'
        $m = New-WorkshopManifest -ProjectId 'demo-project' -ProjectNumber '123' -Region 'europe-west3' -Zone 'europe-west3-a' -Prefix 'kcad' -RunId '20260915-1200' -ExpiresAt (Get-Date).AddDays(1)
        $names = Get-WorkshopResourceNames -Prefix 'kcad'
        foreach ($k in 'network', 'subnet', 'firewallLdaps', 'firewallIapRdp', 'internalAddress', 'externalAddress', 'dataDisk', 'instance') {
            $n = $names[($k.Substring(0, 1).ToUpper() + $k.Substring(1))]
            $m.resources[$k] = @{ name = $n; selfLink = "https://x/$n"; scope = 'zone' }
        }
        $m.iamBindings = @(@{ principal = 'user:t@example.org'; role = 'roles/iap.tunnelResourceAccessor'; conditionTitle = 'keycloak-ad-workshop rdp'; instanceId = '42' })
        Save-WorkshopManifest -Manifest $m -Path $path
        return $path
    }
    function script:Owned { param([string]$Name) return "{""name"":""$Name"",""selfLink"":""https://x/$Name"",""labels"":{""workshop"":""keycloak-ad"",""run-id"":""20260915-1200""},""description"":""keycloak-ad-workshop run-id=20260915-1200""}" }
}
AfterAll { Remove-Variable -Name KcadCalls -Scope Global -ErrorAction SilentlyContinue }

Describe 'Remove-Workshop' {
    It 'deletes owned resources in order and marks missing ones as removed' {
        $path = New-TestManifest
        $global:KcadCalls = [System.Collections.Generic.List[string]]::new()
        Mock Invoke-GcloudRaw -ModuleName Workshop.Common {
            $a = $Arguments -join ' '
            $global:KcadCalls.Add($a)
            if ($a -match '^projects describe') { return '{"projectNumber":"123"}' }
            if ($a -match 'disks describe kcad-dc01 ') { throw 'ERROR: was not found' }
            if ($a -match 'describe') { return (Owned ($Arguments | Where-Object { $_ -like 'kcad-*' } | Select-Object -First 1)) }
            return '{}'
        }
        Mock Invoke-IapApi -ModuleName Workshop.Common {
            if ($Url -match 'getIamPolicy') {
                return [pscustomobject]@{ etag = 'e'; version = 3; bindings = @(
                    [pscustomobject]@{ role = 'roles/iap.tunnelResourceAccessor'; members = @('user:t@example.org'); condition = [pscustomobject]@{ title = 'keycloak-ad-workshop rdp'; expression = 'destination.port == 3389' } },
                    [pscustomobject]@{ role = 'roles/viewer'; members = @('user:other@example.org') }) }
            }
            return [pscustomobject]@{ etag = 'e2' }
        }
        & $script:Script -ManifestPath $path -Confirm:$false
        $deletes = @($global:KcadCalls | Where-Object { $_ -match ' delete ' })
        $deletes[0] | Should -Match 'instances delete kcad-dc01 --zone=europe-west3-a --project=demo-project'
        $deletes[1] | Should -Match 'disks delete kcad-dc01-data'
        $deletes[-2] | Should -Match 'subnets delete kcad-subnet'
        $deletes[-1] | Should -Match 'networks delete kcad-vpc'
        $deletes.Count | Should -Be 8
        $back = Read-WorkshopManifest -Path $path
        $back.status | Should -Be 'removed'
        $back.removed.bootDisk | Should -Match 'already'
        Should -Invoke Invoke-IapApi -ModuleName Workshop.Common -Times 1 -ParameterFilter {
            $Url -match 'setIamPolicy' -and ($Body.policy.bindings | Measure-Object).Count -eq 1 -and $Body.policy.bindings[0].role -eq 'roles/viewer'
        }
    }
    It 'aborts on a foreign resource with the same name' {
        $path = New-TestManifest
        Mock Invoke-GcloudRaw -ModuleName Workshop.Common {
            $a = $Arguments -join ' '
            if ($a -match '^projects describe') { return '{"projectNumber":"123"}' }
            if ($a -match 'instances describe') { return '{"name":"kcad-dc01","selfLink":"https://x/kcad-dc01","labels":{"workshop":"other"}}' }
            throw 'ERROR: was not found'
        }
        Mock Invoke-IapApi -ModuleName Workshop.Common { [pscustomobject]@{ bindings = @() } }
        { & $script:Script -ManifestPath $path -Confirm:$false } | Should -Throw '*Eigentumsnachweis*'
        Should -Invoke Invoke-GcloudRaw -ModuleName Workshop.Common -Times 0 -ParameterFilter { ($Arguments -join ' ') -match ' delete ' }
    }
    It 'aborts on a project number mismatch' {
        $path = New-TestManifest
        Mock Invoke-GcloudRaw -ModuleName Workshop.Common { return '{"projectNumber":"999"}' }
        { & $script:Script -ManifestPath $path -Confirm:$false } | Should -Throw '*Projektnummer*'
    }
    It 'does nothing in plan mode' {
        $path = New-TestManifest
        Mock Invoke-GcloudRaw -ModuleName Workshop.Common {
            $a = $Arguments -join ' '
            if ($a -match '^projects describe') { return '{"projectNumber":"123"}' }
            if ($a -match 'describe') { return (Owned ($Arguments | Where-Object { $_ -like 'kcad-*' } | Select-Object -First 1)) }
            throw "unexpected $a"
        }
        Mock Invoke-IapApi -ModuleName Workshop.Common { [pscustomobject]@{ bindings = @() } }
        & $script:Script -ManifestPath $path -PlanOnly
        Should -Invoke Invoke-GcloudRaw -ModuleName Workshop.Common -Times 0 -ParameterFilter { ($Arguments -join ' ') -match ' delete ' }
        Should -Invoke Invoke-IapApi -ModuleName Workshop.Common -Times 0
        (Read-WorkshopManifest -Path $path).status | Should -Be 'creating'
    }
}
