<#
.SYNOPSIS
    Installs the Kyocera TASKalfa 6054ci KX driver and creates all five printer queues.

.DESCRIPTION
    JumpCloud Windows (PowerShell) command â€” run as SYSTEM.
    1. Downloads TASKalfa_6054ci-v8.6A.1412.zip from a GitHub Release.
    2. Extracts and stages the 64-bit KX driver via pnputil.
    3. Creates a TCP/IP port + printer queue for each site printer.
    4. Cleans up temp files.
    Exits 0 (success) or 1 (failure) so JumpCloud can report status.

    â”€â”€ JUMPCLOUD SETUP â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    Admin â†’ Commands â†’ New Command â†’ Windows (PowerShell)
    Run As: SYSTEM
    Fill in $DriverZipUrl below, then assign to device group and run.
    â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
#>

# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
#  CONFIGURATION
# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

# Direct zip asset URL from your GitHub Release.
# After uploading TASKalfa_6054ci-v8.6A.1412.zip to the release, right-click
# the asset and copy the link â€” it will look like:
# https://github.com/YOUR_ORG/YOUR_REPO/releases/download/drivers/v8.6A.1412/TASKalfa_6054ci-v8.6A.1412.zip
$DriverZipUrl = "https://github.com/jasonjbg/print-drivers/releases/download/drivers%2Fv8.6A.1412/TASKalfa_6054ci-v8.6A.1412.zip"

# Confirmed from OEMSETUP.INF in the KX Driver 8.6A.1412 package â€” do not change.
$DriverModelName = "Kyocera TASKalfa 6054ci KX"

# â”€â”€ Printer queue definitions â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
$Printers = @(
    @{ QueueName = "Elm Hallway #5529";      IP = "10.7.144.170"; PortName = "IP_10.7.144.170" }
    @{ QueueName = "Elm Front Office #5530"; IP = "10.7.144.171"; PortName = "IP_10.7.144.171" }
    @{ QueueName = "HS Front Office";        IP = "10.7.144.172"; PortName = "IP_10.7.144.172" }
    @{ QueueName = "HS Library";             IP = "10.7.144.173"; PortName = "IP_10.7.144.173" }
    @{ QueueName = "District Office #5531";  IP = "10.7.144.174"; PortName = "IP_10.7.144.174" }
)

# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
#  INTERNALS
# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

$DriverLabel = "TASKalfa_6054ci"
$WorkDir     = Join-Path $env:TEMP "jc_driver_$DriverLabel"
$ZipPath     = Join-Path $WorkDir  "$DriverLabel.zip"
$ExtractDir  = Join-Path $WorkDir  "extracted"
$LogDir      = Join-Path $env:ProgramData "JumpCloud\Logs"
$LogPath     = Join-Path $LogDir   "driver_install_$DriverLabel.log"

# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
#  HELPERS
# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

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

# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
#  MAIN
# â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
Write-Log "â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•"
Write-Log "Kyocera TASKalfa 6054ci KX â€” Driver Deploy"
Write-Log "Driver package : KX Driver 8.6A.1412 (64-bit)"
Write-Log "Queues to add  : $($Printers.Count)"
Write-Log "â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•"

# â”€â”€ 1. Prepare temp workspace â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
try {
    if (Test-Path $WorkDir) { Remove-Item $WorkDir -Recurse -Force }
    New-Item -ItemType Directory -Path $WorkDir, $ExtractDir -Force | Out-Null
    Write-Log "Work directory ready."
} catch {
    Exit-Script 1 "Could not create work directory: $_"
}

# â”€â”€ 2. Download driver zip â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
Write-Log "Downloading driver zip..."
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $wc = New-Object System.Net.WebClient
    $wc.DownloadFile($DriverZipUrl, $ZipPath)
    $sizeMB = [math]::Round((Get-Item $ZipPath).Length / 1MB, 2)
    Write-Log "Download complete â€” ${sizeMB} MB"
} catch {
    Exit-Script 1 "Download failed: $_"
}

if ((Get-Item $ZipPath).Length -lt 1KB) {
    Exit-Script 1 "Downloaded file is too small â€” check the GitHub Release URL."
}

# â”€â”€ 3. Extract zip â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
Write-Log "Extracting..."
try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipPath, $ExtractDir)
    Write-Log "Extracted to $ExtractDir"
} catch {
    Exit-Script 1 "Extraction failed: $_"
}

# â”€â”€ 4. Locate OEMSETUP.INF â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
$infFiles = Get-ChildItem -Path $ExtractDir -Filter "*.inf" -Recurse
if ($infFiles.Count -eq 0) {
    Exit-Script 1 "No .inf files found in zip â€” verify the zip contents."
}
Write-Log "Found $($infFiles.Count) INF file(s):"
$infFiles | ForEach-Object { Write-Log "  $($_.FullName)" }

# â”€â”€ 5. Stage driver via pnputil â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
$pnputil    = "$env:SystemRoot\System32\pnputil.exe"
$errCount   = 0
$needReboot = $false

foreach ($inf in $infFiles) {
    Write-Log "Staging: $($inf.Name)"
    $out      = & $pnputil /add-driver "$($inf.FullName)" /install 2>&1
    $exitCode = $LASTEXITCODE
    $out | ForEach-Object { Write-Log "  $_" }

    switch ($exitCode) {
        0    { Write-Log "  OK: $($inf.Name)" }
        3010 { Write-Log "  Staged (reboot required): $($inf.Name)" 'WARN'; $needReboot = $true }
        default {
            Write-Log "  pnputil exit $exitCode for $($inf.Name)" 'WARN'
            $errCount++
        }
    }
}

if ($errCount -gt 0) {
    Exit-Script 1 "$errCount INF(s) failed to stage. See $LogPath"
}

# â”€â”€ 6. Verify driver is registered â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
$registeredDriver = Get-PrinterDriver -Name $DriverModelName -ErrorAction SilentlyContinue
if ($registeredDriver) {
    Write-Log "Driver confirmed in Windows driver store: '$DriverModelName'"
} else {
    Write-Log "Driver not yet visible in driver store â€” may need a reboot first." 'WARN'
    Write-Log "Queues will be created; ports will be usable after reboot if driver is missing." 'WARN'
}

# â”€â”€ 7. Create printer ports and queues â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
Write-Log "â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€"
Write-Log "Creating printer ports and queues..."
$queueErrors = 0

foreach ($p in $Printers) {
    $q    = $p.QueueName
    $ip   = $p.IP
    $port = $p.PortName

    # Port
    if (Get-PrinterPort -Name $port -ErrorAction SilentlyContinue) {
        Write-Log "  Port exists, skipping: $port"
    } else {
        try {
            Add-PrinterPort -Name $port -PrinterHostAddress $ip
            Write-Log "  Port created: $port â†’ $ip"
        } catch {
            Write-Log "  Failed to create port '$port': $_" 'ERROR'
            $queueErrors++
            continue
        }
    }

    # Queue
    if (Get-Printer -Name $q -ErrorAction SilentlyContinue) {
        Write-Log "  Queue exists, skipping: $q"
    } else {
        try {
            Add-Printer -Name $q -DriverName $DriverModelName -PortName $port
            Write-Log "  Queue created: '$q' ($ip)"
        } catch {
            Write-Log "  Failed to create queue '$q': $_" 'ERROR'
            $queueErrors++
            continue
        }
    }

    # Force-correct the port in case Windows assigned the wrong one
    try {
        Set-Printer -Name $q -PortName $port
        Write-Log "  Port confirmed: '$q' â†’ $port"
    } catch {
        Write-Log "  Could not force-set port on '$q': $_" 'WARN'
    }
}

# â”€â”€ 8. Summary â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
Write-Log "â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€"
Write-Log "Results:"
foreach ($p in $Printers) {
    $status = if (Get-Printer -Name $p.QueueName -ErrorAction SilentlyContinue) { "OK     " } else { "MISSING" }
    Write-Log ("  [{0}] {1} ({2})" -f $status, $p.QueueName, $p.IP)
}
if ($needReboot) { Write-Log "NOTE: A reboot is required to fully activate the driver." 'WARN' }

# â”€â”€ 9. Cleanup â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
try   { Remove-Item $WorkDir -Recurse -Force; Write-Log "Temp files cleaned up." }
catch { Write-Log "Cleanup failed (non-fatal): $_" 'WARN' }

if ($queueErrors -gt 0) {
    Exit-Script 1 "$queueErrors queue(s) failed. See $LogPath"
}

Exit-Script 0 "All done. Log: $LogPath"
