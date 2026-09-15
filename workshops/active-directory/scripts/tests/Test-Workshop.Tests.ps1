BeforeAll {
    . "$PSScriptRoot/../Test-Workshop.ps1" -Mode Trainer -HelpersOnly
}

Describe 'Test-EffectiveFirewall' {
    It 'flags an allow rule from anywhere on 636' {
        $fw = @([pscustomobject]@{ direction = 'INGRESS'; sourceRanges = @('0.0.0.0/0'); allowed = @([pscustomobject]@{ IPProtocol = 'tcp'; ports = @('636') }) })
        (Test-EffectiveFirewall -Rules $fw -AllowedLdapsRanges @('203.0.113.0/24')).Result | Should -Be 'FAIL'
    }
    It 'flags an all-ports rule from a foreign range' {
        $fw = @(
            [pscustomobject]@{ direction = 'INGRESS'; sourceRanges = @('198.51.100.0/24'); allowed = @([pscustomobject]@{ IPProtocol = 'tcp' }) },
            [pscustomobject]@{ direction = 'INGRESS'; sourceRanges = @('203.0.113.0/24'); allowed = @([pscustomobject]@{ IPProtocol = 'tcp'; ports = @('636') }) },
            [pscustomobject]@{ direction = 'INGRESS'; sourceRanges = @('35.235.240.0/20'); allowed = @([pscustomobject]@{ IPProtocol = 'tcp'; ports = @('3389') }) }
        )
        $r = Test-EffectiveFirewall -Rules $fw -AllowedLdapsRanges @('203.0.113.0/24')
        $r.Result | Should -Be 'FAIL'
        $r.Detail | Should -Match '198.51.100.0/24'
    }
    It 'accepts the two workshop rules' {
        $fw = @(
            [pscustomobject]@{ direction = 'INGRESS'; sourceRanges = @('203.0.113.0/24'); allowed = @([pscustomobject]@{ IPProtocol = 'tcp'; ports = @('636') }) },
            [pscustomobject]@{ direction = 'INGRESS'; sourceRanges = @('35.235.240.0/20'); allowed = @([pscustomobject]@{ IPProtocol = 'tcp'; ports = @('3389') }) },
            [pscustomobject]@{ direction = 'EGRESS'; destinationRanges = @('0.0.0.0/0'); allowed = @([pscustomobject]@{ IPProtocol = 'all' }) }
        )
        (Test-EffectiveFirewall -Rules $fw -AllowedLdapsRanges @('203.0.113.0/24')).Result | Should -Be 'PASS'
    }
    It 'fails when the LDAPS rule is missing' {
        $fw = @([pscustomobject]@{ direction = 'INGRESS'; sourceRanges = @('35.235.240.0/20'); allowed = @([pscustomobject]@{ IPProtocol = 'tcp'; ports = @('3389') }) })
        (Test-EffectiveFirewall -Rules $fw -AllowedLdapsRanges @('203.0.113.0/24')).Detail | Should -Match '636'
    }
    It 'normalises hierarchical policy rules' {
        $rule = [pscustomobject]@{ direction = 'INGRESS'; action = 'allow'; match = [pscustomobject]@{ srcIpRanges = @('0.0.0.0/0'); layer4Configs = @([pscustomobject]@{ ipProtocol = 'tcp'; ports = @('22', '3389') }) } }
        $n = ConvertFrom-FirewallPolicyRule -PolicyRule $rule
        $n.sourceRanges | Should -Contain '0.0.0.0/0'
        (Test-EffectiveFirewall -Rules @($n) -AllowedLdapsRanges @('203.0.113.0/24')).Detail | Should -Match '3389 aus 0.0.0.0/0'
    }
}

Describe 'Test-EffectiveFirewall trainer ssh' {
    BeforeAll {
        $script:fw = @(
            [pscustomobject]@{ direction = 'INGRESS'; sourceRanges = @('203.0.113.0/24'); allowed = @([pscustomobject]@{ IPProtocol = 'tcp'; ports = @('636') }) },
            [pscustomobject]@{ direction = 'INGRESS'; sourceRanges = @('35.235.240.0/20'); allowed = @([pscustomobject]@{ IPProtocol = 'tcp'; ports = @('3389') }) },
            [pscustomobject]@{ direction = 'INGRESS'; sourceRanges = @('35.235.240.0/20'); allowed = @([pscustomobject]@{ IPProtocol = 'tcp'; ports = @('22') }) }
        )
    }
    It 'rejects port 22 unless trainer ssh is declared' {
        (Test-EffectiveFirewall -Rules $script:fw -AllowedLdapsRanges @('203.0.113.0/24')).Result | Should -Be 'FAIL'
    }
    It 'accepts port 22 from the IAP range when declared' {
        (Test-EffectiveFirewall -Rules $script:fw -AllowedLdapsRanges @('203.0.113.0/24') -AllowIapSsh).Result | Should -Be 'PASS'
    }
    It 'still rejects port 22 from elsewhere' {
        $bad = $script:fw + @([pscustomobject]@{ direction = 'INGRESS'; sourceRanges = @('198.51.100.0/24'); allowed = @([pscustomobject]@{ IPProtocol = 'tcp'; ports = @('22') }) })
        (Test-EffectiveFirewall -Rules $bad -AllowedLdapsRanges @('203.0.113.0/24') -AllowIapSsh).Result | Should -Be 'FAIL'
    }
}

Describe 'Get-ReportExitCode' {
    It 'is 1 when a check fails' {
        Get-ReportExitCode -Report @([pscustomobject]@{ result = 'PASS' }, [pscustomobject]@{ result = 'FAIL' }) | Should -Be 1
    }
    It 'is 0 with passes and skips' {
        Get-ReportExitCode -Report @([pscustomobject]@{ result = 'PASS' }, [pscustomobject]@{ result = 'SKIP' }) | Should -Be 0
    }
}

Describe 'Test-PortCovered' {
    It 'handles ranges and empty lists' {
        Test-PortCovered -Ports @('630-640') -Port 636 | Should -BeTrue
        Test-PortCovered -Ports @('22') -Port 636 | Should -BeFalse
        Test-PortCovered -Ports $null -Port 636 | Should -BeTrue
    }
}
