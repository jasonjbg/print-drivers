<#
.DESCRIPTION
    JumpCloud Windows (PowerShell) command " run as SYSTEM.
    Removes all Kyocera TASKalfa 6054ci printer queues and ports from this machine.
    Safe to run on any location " skips anything not found.
#>

# All known queue names (current and legacy) across all locations
$QueuesToRemove = @(
    # Elementary
    "Elm Hallway #5529"
    "Elm Front Office #5530"
    "Elm Hallway"
    "Elm Front Office"
    # High School
    "HS Front Office"
    "HS Library"
    "Hs Front Office"
    "Hs Library"
    # District
    "District Office #5531"
    "District Office"
)

# All known ports across all locations
$PortsToRemove = @(
    "IP_10.7.144.170"
    "IP_10.7.144.171"
    "IP_10.7.144.172"
    "IP_10.7.144.173"
    "IP_10.7.144.174"
)

Write-Host "===================================================="
Write-Host " Kyocera TASKalfa 6054ci " Full Printer Removal"
Write-Host "===================================================="

# "" Remove printer queues """""""""""""""""""""""""""""""""""""""""""""""""""""
Write-Host ""
Write-Host "[Phase 1] Removing printer queues..."
foreach ($name in $QueuesToRemove) {
    if (Get-Printer -Name $name -ErrorAction SilentlyContinue) {
        try {
            Remove-Printer -Name $name
            Write-Host "  [REMOVED] $name"
        } catch {
            Write-Host "  [FAILED]  $name " $_"
        }
    } else {
        Write-Host "  [SKIPPED] $name " not found"
    }
}

# "" Remove printer ports """"""""""""""""""""""""""""""""""""""""""""""""""""""
Write-Host ""
Write-Host "[Phase 2] Removing printer ports..."
foreach ($port in $PortsToRemove) {
    if (Get-PrinterPort -Name $port -ErrorAction SilentlyContinue) {
        try {
            Remove-PrinterPort -Name $port
            Write-Host "  [REMOVED] $port"
        } catch {
            Write-Host "  [FAILED]  $port " $_"
        }
    } else {
        Write-Host "  [SKIPPED] $port " not found"
    }
}

Write-Host ""
Write-Host "===================================================="
Write-Host " Done."
Write-Host "===================================================="
