<#
.SYNOPSIS
Stellt den Ausgangszustand eines Teams im AD wieder her.

.DESCRIPTION
Laeuft auf dem DC als Domaenen-Administrator. Hans und Anna liegen danach in OU=Users und
sind aktiviert; Mitarbeiter enthaelt Hans und Anna, Teamleitung enthaelt Anna, Manager
enthaelt Teamleitung. Andere Mitglieder werden entfernt. Delegation und Passwoerter bleiben.
#>
#Requires -RunAsAdministrator
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidatePattern('^\d{2}$')][string]$Team,
    [string]$Description = ''
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory

$domain = Get-ADDomain
$teamDn = "OU=Team$Team,OU=Workshop,$($domain.DistinguishedName)"
$usersDn = "OU=Users,$teamDn"

function Get-TeamUser { param([string]$Sam) Get-ADUser -LDAPFilter "(sAMAccountName=$Sam)" -SearchBase $teamDn -Properties memberOf, userAccountControl, description }
function Get-TeamGroup { param([string]$Sam) Get-ADGroup -LDAPFilter "(sAMAccountName=$Sam)" -SearchBase $teamDn }

$hans = Get-TeamUser "t$Team.hans"
$anna = Get-TeamUser "t$Team.anna"
$staff = Get-TeamGroup "t$Team.staff"
$leads = Get-TeamGroup "t$Team.leads"
$managers = Get-TeamGroup "t$Team.managers"
if (-not ($hans -and $anna -and $staff -and $leads -and $managers)) { throw "Team $Team ist unvollstaendig; zuerst Initialize-Workshop.ps1 ausfuehren" }

foreach ($u in $hans, $anna) {
    if ($u.DistinguishedName -notlike "*,$usersDn") {
        Write-Host "verschiebe $($u.SamAccountName) nach $usersDn"
        Move-ADObject -Identity $u.DistinguishedName -TargetPath $usersDn
    }
    if (-not $u.Enabled) {
        Write-Host "aktiviere $($u.SamAccountName)"
        Enable-ADAccount -Identity $u.SamAccountName
    }
    if ($u.description -ne $Description) {
        if ($Description) { Set-ADUser -Identity $u.SamAccountName -Description $Description } else { Set-ADUser -Identity $u.SamAccountName -Clear description }
    }
}

# Nach Move und Enable neu laden, damit DN und Flags stimmen.
$hans = Get-TeamUser "t$Team.hans"
$anna = Get-TeamUser "t$Team.anna"
$baseline = @{
    ($staff.DistinguishedName)    = @($hans.SID.Value, $anna.SID.Value)
    ($leads.DistinguishedName)    = @($anna.SID.Value)
    ($managers.DistinguishedName) = @($leads.SID.Value)
}
foreach ($g in $staff, $leads, $managers) {
    $current = @(Get-ADGroupMember -Identity $g | ForEach-Object { $_.SID.Value })
    $wanted = $baseline[$g.DistinguishedName]
    foreach ($sid in ($current | Where-Object { $_ -notin $wanted })) {
        Write-Host "entferne $sid aus $($g.Name)"
        Remove-ADGroupMember -Identity $g -Members $sid -Confirm:$false
    }
    foreach ($sid in ($wanted | Where-Object { $_ -notin $current })) {
        Write-Host "fuege $sid zu $($g.Name) hinzu"
        Add-ADGroupMember -Identity $g -Members $sid
    }
}

$(foreach ($sam in "t$Team.hans", "t$Team.anna") {
    $u = Get-TeamUser $sam
    [pscustomobject]@{
        User    = $u.SamAccountName
        DN      = $u.DistinguishedName
        Enabled = $u.Enabled
        UAC     = $u.userAccountControl
        Groups  = (($u.memberOf | ForEach-Object { ($_ -split ',')[0] -replace '^CN=', '' }) -join ', ')
    }
}) | Format-Table -AutoSize
