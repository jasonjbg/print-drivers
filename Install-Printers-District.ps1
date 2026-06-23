<#
.DESCRIPTION
    JumpCloud Windows (PowerShell) command — run as SYSTEM.
    Downloads and installs the Kyocera TASKalfa 6054ci KX driver,
    then creates the printer ports and queues for this location.
#>

$DriverZipUrl    = "https://github.com/jasonjbg/print-drivers/releases/download/drivers%2Fv8.6A.1412/TASKalfa_6054ci-v8.6A.1412.zip"
$DriverModelName = "Kyocera TASKalfa 6054ci KX"
$Printers = @(
    @{ QueueName = "District Office #5531"; IP = "10.7.144.174"; PortName = "IP_10.7.144.174" }
)
$DriverLabel = "TASKalfa_6054ci"
$WorkDir     = Join-Path $env:TEMP "jc_driver_$DriverLabel"
$ZipPath     = Join-Path $WorkDir  "$DriverLabel.zip"
$ExtractDir  = Join-Path $WorkDir  "extracted"
$LogDir      = Join-Path $env:ProgramData "JumpCloud\Logs"
$LogPath     = Join-Path $LogDir   "driver_install_$DriverLabel.log"

function Write-Log {
    param([string]$Message, [ValidateSet('INFO','WARN','ERROR')]$Level = 'INFO')
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"
    $line | Tee-Object -FilePath $LogPath -Append | Write-Host
}

function Exit-Script {
    param([int]$Code, [string]$Reason)
    if ($Code -ne 0) { Write-Log $Reason 'ERROR' } else { Write-Log $Reason 'INFO' }
    exit $Code
}

New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
Write-Log "Kyocera TASKalfa 6054ci KX — Driver Deploy"
Write-Log "Queues to add: $($Printers.Count)"

# ── Phase 0: Remove all known old/current queues and ports ───────────────────
Write-Log "────────────────────────────────────────────────"
Write-Log "Removing existing queues and ports (clean slate)..."

$QueuesToRemove = @(
    "Elm Hallway #5529", "Elm Hallway",
    "Elm Front Office #5530", "Elm Front Office",
    "HS Front Office", "Hs Front Office",
    "HS Library", "Hs Library",
    "District Office #5531", "District Office"
)
$PortsToRemove = @(
    "IP_10.7.144.170","IP_10.7.144.171","IP_10.7.144.172","IP_10.7.144.173","IP_10.7.144.174"
)

foreach ($q in $QueuesToRemove) {
    if (Get-Printer -Name $q -ErrorAction SilentlyContinue) {
        try { Remove-Printer -Name $q; Write-Log "  Removed queue: $q" }
        catch { Write-Log "  Could not remove queue '$q': $_" 'WARN' }
    }
}
foreach ($port in $PortsToRemove) {
    if (Get-PrinterPort -Name $port -ErrorAction SilentlyContinue) {
        try { Remove-PrinterPort -Name $port; Write-Log "  Removed port: $port" }
        catch { Write-Log "  Could not remove port '$port': $_" 'WARN' }
    }
}

try {
    if (Test-Path $WorkDir) { Remove-Item $WorkDir -Recurse -Force }
    New-Item -ItemType Directory -Path $WorkDir, $ExtractDir -Force | Out-Null
} catch { Exit-Script 1 "Could not create work directory: $_" }

Write-Log "Downloading driver zip..."
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $wc = New-Object System.Net.WebClient
    $wc.DownloadFile($DriverZipUrl, $ZipPath)
    Write-Log "Download complete — $([math]::Round((Get-Item $ZipPath).Length/1MB,2)) MB"
} catch { Exit-Script 1 "Download failed: $_" }

if ((Get-Item $ZipPath).Length -lt 1KB) { Exit-Script 1 "Downloaded file too small — check release URL." }

Write-Log "Extracting..."
try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipPath, $ExtractDir)
} catch { Exit-Script 1 "Extraction failed: $_" }

$infFiles = Get-ChildItem -Path $ExtractDir -Filter "*.inf" -Recurse
if ($infFiles.Count -eq 0) { Exit-Script 1 "No .inf files found in zip." }

$errCount = 0; $needReboot = $false
foreach ($inf in $infFiles) {
    Write-Log "Staging: $($inf.Name)"
    $out = & "$env:SystemRoot\System32\pnputil.exe" /add-driver "$($inf.FullName)" /install 2>&1
    $out | ForEach-Object { Write-Log "  $_" }
    switch ($LASTEXITCODE) {
        0    { Write-Log "  OK: $($inf.Name)" }
        3010 { Write-Log "  Staged (reboot required): $($inf.Name)" 'WARN'; $needReboot = $true }
        default { Write-Log "  pnputil exit $LASTEXITCODE" 'WARN'; $errCount++ }
    }
}
if ($errCount -gt 0) { Exit-Script 1 "$errCount INF(s) failed to stage." }

Write-Log "Creating printer ports and queues..."
$queueErrors = 0
foreach ($p in $Printers) {
    $q = $p.QueueName; $ip = $p.IP; $port = $p.PortName

    if (-not (Get-PrinterPort -Name $port -ErrorAction SilentlyContinue)) {
        try { Add-PrinterPort -Name $port -PrinterHostAddress $ip; Write-Log "  Port created: $port" }
        catch { Write-Log "  Failed to create port '$port': $_" 'ERROR'; $queueErrors++; continue }
    }

    if (-not (Get-Printer -Name $q -ErrorAction SilentlyContinue)) {
        try { Add-Printer -Name $q -DriverName $DriverModelName -PortName $port; Write-Log "  Queue created: $q" }
        catch { Write-Log "  Failed to create queue '$q': $_" 'ERROR'; $queueErrors++; continue }
    }

    try { Set-Printer -Name $q -PortName $port; Write-Log "  Port confirmed: $q → $port" }
    catch { Write-Log "  Could not force-set port on '$q': $_" 'WARN' }
}

Write-Log "Results:"
foreach ($p in $Printers) {
    $status = if (Get-Printer -Name $p.QueueName -ErrorAction SilentlyContinue) { "OK     " } else { "MISSING" }
    Write-Log ("  [{0}] {1} ({2})" -f $status, $p.QueueName, $p.IP)
}
if ($needReboot) { Write-Log "NOTE: Reboot required to fully activate driver." 'WARN' }

try { Remove-Item $WorkDir -Recurse -Force; Write-Log "Temp files cleaned up." }
catch { Write-Log "Cleanup failed (non-fatal): $_" 'WARN' }

if ($queueErrors -gt 0) { Exit-Script 1 "$queueErrors queue(s) failed. See $LogPath" }
Exit-Script 0 "All done. Log: $LogPath"
