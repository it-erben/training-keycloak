# Startskript fuer die Workshop-VM (Metadaten windows-startup-script-ps1), nur mit -TrainerSsh.
# Richtet den Windows-OpenSSH-Server fuer den IAP-Zugang des Trainers ein. Der oeffentliche
# Schluessel kommt aus dem Metadaten-Attribut trainer-ssh-key; Geheimnisse enthaelt es nicht.
# Laeuft bei jedem Start und aendert nur, was fehlt.
$ErrorActionPreference = 'Stop'
$key = ''
try {
    $key = Invoke-RestMethod -Uri 'http://metadata.google.internal/computeMetadata/v1/instance/attributes/trainer-ssh-key' -Headers @{ 'Metadata-Flavor' = 'Google' }
} catch { return }
if ([string]::IsNullOrWhiteSpace($key)) { return }

$cap = Get-WindowsCapability -Online -Name 'OpenSSH.Server*' | Select-Object -First 1
if ($cap.State -ne 'Installed') { Add-WindowsCapability -Online -Name $cap.Name | Out-Null }

New-Item -Path 'HKLM:\SOFTWARE\OpenSSH' -Force | Out-Null
New-ItemProperty -Path 'HKLM:\SOFTWARE\OpenSSH' -Name DefaultShell -PropertyType String -Force `
    -Value 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' | Out-Null

New-Item -ItemType Directory -Path 'C:\ProgramData\ssh' -Force | Out-Null
$file = 'C:\ProgramData\ssh\administrators_authorized_keys'
$current = if (Test-Path $file) { (Get-Content $file -Raw).Trim() } else { '' }
if ($current -ne $key.Trim()) {
    [System.IO.File]::WriteAllText($file, $key.Trim() + "`n", [System.Text.Encoding]::ASCII)
    & icacls $file /inheritance:r /grant 'Administrators:F' /grant 'SYSTEM:F' | Out-Null
}

if (-not (Get-NetFirewallRule -Name 'Workshop-Trainer-SSH' -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -Name 'Workshop-Trainer-SSH' -DisplayName 'Workshop Trainer SSH (IAP)' -Direction Inbound `
        -Protocol TCP -LocalPort 22 -Action Allow -RemoteAddress 35.235.240.0/20 | Out-Null
}

# Vor der Promotion ist das eingebaute Administratorkonto deaktiviert; fuer die Schluesselanmeldung
# braucht es ein gesetztes Passwort. Initialize-Domain.ps1 ersetzt es spaeter durch das gewaehlte.
try {
    $admin = Get-LocalUser -Name Administrator -ErrorAction Stop
    if (-not $admin.Enabled) {
        $bytes = [byte[]]::new(24)
        [System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
        $pw = ([Convert]::ToBase64String($bytes) -replace '[^A-Za-z0-9]', 'x') + 'Q7!'
        Set-LocalUser -Name Administrator -Password (ConvertTo-SecureString $pw -AsPlainText -Force)
        Enable-LocalUser -Name Administrator
    }
} catch {
    # Auf einem Domain Controller gibt es keine lokalen Konten; der Domaenen-Administrator ist bereits aktiv.
    Write-Verbose "Get-LocalUser nicht verfuegbar: $($_.Exception.Message)"
}

Set-Service -Name sshd -StartupType Automatic
if ((Get-Service sshd).Status -ne 'Running') { Start-Service sshd } else { Restart-Service sshd }
