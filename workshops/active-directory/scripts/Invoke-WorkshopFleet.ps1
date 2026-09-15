<#
.SYNOPSIS
Verwaltet mehrere Workshop-Umgebungen, eine je Person: anlegen, pruefen, stoppen, starten, abbauen.

.DESCRIPTION
Deploy legt je Praefix eine Umgebung mit New-Workshop.ps1 -TrainerSsh an, fuehrt die Gastseite
parallel ueber lib/Invoke-GuestSetup.ps1 aus (Log unter .run/<praefix>/setup.log) und prueft
anschliessend jede Umgebung mit Test-Workshop.ps1 -Mode Trainer. Stop und Start schalten die VMs
aus und ein; Start wartet auf LDAPS und prueft erneut. Remove baut jede Umgebung ueber ihr
Manifest ab. Status zeigt Instanzzustand und externe IP.
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)][ValidateSet('Deploy', 'Test', 'Stop', 'Start', 'Remove', 'Status', 'Packages')][string]$Action,
    [ValidateRange(1, 20)][int]$Count = 5,
    [string[]]$Prefixes = @(),
    [string]$ProjectId = '',
    [string]$Region = 'europe-west3',
    [string]$Zone = 'europe-west3-a',
    [string[]]$LdapsSourceRanges = @(),
    [string]$TrainerPrincipal = '',
    [datetime]$ExpiresAt = (Get-Date).AddHours(48),
    [datetime]$CertificateValidUntil = (Get-Date).AddDays(7),
    [string]$TrainerSshPublicKeyPath = ([System.IO.Path]::Combine($HOME, '.ssh', 'id_ed25519.pub')),
    [switch]$IncludeIap,
    [switch]$PlanOnly
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not (Get-Module -Name Workshop.Common)) { Import-Module ([System.IO.Path]::Combine($PSScriptRoot, 'lib', 'Workshop.Common.psm1')) }
$runRoot = [System.IO.Path]::Combine($PSScriptRoot, '..', '.run')
if (-not $Prefixes -or $Prefixes.Count -eq 0) { $Prefixes = 1..$Count | ForEach-Object { "kcad$_" } }
$fleetFile = Join-Path $runRoot 'fleet.json'

function Get-Envs {
    foreach ($p in $Prefixes) {
        $paths = Get-WorkshopRunPaths -Prefix $p -RunRoot $runRoot
        if (Test-Path $paths.Manifest) { [pscustomobject]@{ Prefix = $p; Paths = $paths; Manifest = (Read-WorkshopManifest -Path $paths.Manifest) } }
        else { Write-Warning "Kein Manifest fuer $p ($($paths.Manifest))" }
    }
}

switch ($Action) {
    'Deploy' {
        foreach ($name in 'ProjectId', 'TrainerPrincipal') { if (-not (Get-Variable $name -ValueOnly)) { throw "-$name ist fuer Deploy erforderlich" } }
        if (-not $LdapsSourceRanges) { throw '-LdapsSourceRanges ist fuer Deploy erforderlich' }
        New-Item -ItemType Directory -Path $runRoot -Force | Out-Null
        foreach ($p in $Prefixes) {
            Write-WorkshopStep "Umgebung $p anlegen"
            $newArgs = @('-ProjectId', $ProjectId, '-Region', $Region, '-Zone', $Zone, '-Prefix', $p, '-LdapsSourceRanges', ($LdapsSourceRanges -join ','), '-TrainerPrincipal', $TrainerPrincipal,
                '-ExpiresAt', $ExpiresAt.ToString('o'), '-TrainerSsh', '-TrainerSshPublicKeyPath', $TrainerSshPublicKeyPath)
            if ($PlanOnly) { $newArgs += '-PlanOnly' }
            & pwsh -NoProfile -File (Join-Path $PSScriptRoot 'New-Workshop.ps1') @newArgs
            if ($LASTEXITCODE -ne 0) { throw "New-Workshop.ps1 fuer $p fehlgeschlagen" }
        }
        if ($PlanOnly) { Write-Host 'PlanOnly: keine Gastschritte.' -ForegroundColor Green; return }
        [ordered]@{ prefixes = $Prefixes; projectId = $ProjectId; zone = $Zone; createdAt = (Get-Date).ToUniversalTime().ToString('o') } | ConvertTo-Json | Set-Content $fleetFile -Encoding utf8

        Write-WorkshopStep 'Gastseite aller Umgebungen parallel ausfuehren'
        $procs = @{}
        $i = 0
        foreach ($p in $Prefixes) {
            $i++
            $paths = Get-WorkshopRunPaths -Prefix $p -RunRoot $runRoot
            $log = Join-Path $paths.Run 'setup.log'
            $procs[$p] = Start-Process -FilePath pwsh -ArgumentList @('-NoProfile', '-File', (Join-Path $PSScriptRoot 'lib' 'Invoke-GuestSetup.ps1'), '-Prefix', $p, '-LocalPort', (2200 + $i), '-CertificateValidUntil', $CertificateValidUntil.ToString('o'), '-RunRoot', $runRoot) -PassThru -NoNewWindow -RedirectStandardOutput $log -RedirectStandardError ($log + '.err')
            Write-Host "  $p gestartet, Log: $log"
        }
        foreach ($p in $Prefixes) { $procs[$p].WaitForExit() }
        $failed = @($Prefixes | Where-Object { $procs[$_].ExitCode -ne 0 })
        foreach ($p in $Prefixes) {
            $status = if ($procs[$p].ExitCode -eq 0) { 'fertig' } else { "FEHLER (Exit $($procs[$p].ExitCode))" }
            Write-Host ("  {0,-8} {1}" -f $p, $status)
        }
        if ($failed) { throw "Gastseite fehlgeschlagen fuer: $($failed -join ', '). Logs unter .run/<praefix>/setup.log; erneuter Aufruf setzt fort." }

        foreach ($p in $Prefixes) {
            Write-WorkshopStep "Trainerpruefung $p"
            $testArgs = @('-Mode', 'Trainer', '-Prefix', $p)
            if ($IncludeIap) { $testArgs += '-IncludeIap' }
            & pwsh -NoProfile -File (Join-Path $PSScriptRoot 'Test-Workshop.ps1') @testArgs | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "Trainerpruefung fuer $p fehlgeschlagen" }
        }
        & pwsh -NoProfile -File $PSCommandPath -Action Packages -Prefixes $Prefixes
    }
    'Test' {
        foreach ($e in Get-Envs) {
            $testArgs = @('-Mode', 'Trainer', '-Prefix', $e.Prefix)
            if ($IncludeIap) { $testArgs += '-IncludeIap' }
            & pwsh -NoProfile -File (Join-Path $PSScriptRoot 'Test-Workshop.ps1') @testArgs
        }
    }
    'Status' {
        foreach ($e in Get-Envs) {
            $inst = Get-GcloudJson -Arguments @('compute', 'instances', 'describe', $e.Manifest.resources.instance.name, "--zone=$($e.Manifest.zone)", "--project=$($e.Manifest.projectId)") -IgnoreNotFound
            $status = if ($inst) { $inst.status } else { 'FEHLT' }
            Write-Host ("{0,-8} {1,-12} {2,-16} Manifest {3}" -f $e.Prefix, $status, $e.Manifest.network.externalIp, $e.Manifest.status)
        }
    }
    'Stop' {
        foreach ($e in Get-Envs) {
            Invoke-GcloudChange -Arguments @('compute', 'instances', 'stop', $e.Manifest.resources.instance.name, "--zone=$($e.Manifest.zone)", "--project=$($e.Manifest.projectId)") -Description "$($e.Prefix): VM stoppen" | Out-Null
        }
    }
    'Start' {
        foreach ($e in Get-Envs) {
            Invoke-GcloudChange -Arguments @('compute', 'instances', 'start', $e.Manifest.resources.instance.name, "--zone=$($e.Manifest.zone)", "--project=$($e.Manifest.projectId)") -Description "$($e.Prefix): VM starten" | Out-Null
        }
        foreach ($e in Get-Envs) {
            $ip = $e.Manifest.network.externalIp
            $deadline = (Get-Date).AddMinutes(10)
            $open = $false
            while ((Get-Date) -lt $deadline) {
                $client = [System.Net.Sockets.TcpClient]::new()
                try { if ($client.ConnectAsync($ip, 636).Wait(3000) -and $client.Connected) { $open = $true; break } }
                catch { Write-Verbose "636 noch zu: $($_.Exception.Message)" }
                finally { $client.Dispose() }
                Start-Sleep -Seconds 10
            }
            Write-Host ("{0,-8} LDAPS {1}" -f $e.Prefix, $(if ($open) { 'erreichbar' } else { 'NICHT erreichbar' }))
        }
        & pwsh -NoProfile -File $PSCommandPath -Action Test -Prefixes $Prefixes
    }
    'Remove' {
        if (-not $PlanOnly -and -not $PSCmdlet.ShouldProcess(($Prefixes -join ', '), 'Alle Umgebungen abbauen')) { return }
        foreach ($e in Get-Envs) {
            $rmArgs = @('-Prefix', $e.Prefix, '-Confirm:$false')
            if ($PlanOnly) { $rmArgs += '-PlanOnly' }
            & pwsh -NoProfile -File (Join-Path $PSScriptRoot 'Remove-Workshop.ps1') @rmArgs
            if ($LASTEXITCODE -ne 0) { throw "Remove-Workshop.ps1 fuer $($e.Prefix) fehlgeschlagen" }
        }
    }
    'Packages' {
        # Je Person: IP, CA-Fingerprint und die vier Passwoerter; Ausgabe nur auf dem Trainerrechner.
        foreach ($e in Get-Envs) {
            $summary = if (Test-Path $e.Paths.Summary) { Get-Content $e.Paths.Summary -Raw | ConvertFrom-Json } else { $null }
            $secretFile = Join-Path $e.Paths.Secrets 'workshop.json'
            $secret = if (Test-Path $secretFile) { Get-Content $secretFile -Raw | ConvertFrom-Json } else { $null }
            Write-Host ''
            Write-Host "=== $($e.Prefix)" -ForegroundColor Cyan
            Write-Host "AD_PUBLIC_IP:   $($e.Manifest.network.externalIp)"
            Write-Host "CA-Datei:       $($e.Paths.Ca)"
            if ($summary) { Write-Host "CA-Fingerprint: $($summary.caFingerprintSha256)" }
            if ($secret) {
                Write-Host "hans:           $($secret.hans)"
                Write-Host "anna:           $($secret.anna)"
                Write-Host "bind:           $($secret.bind)"
                Write-Host "operator:       $($secret.operator)"
            } else { Write-Host "Geheimnisse:    fehlen ($secretFile)" }
        }
    }
}
