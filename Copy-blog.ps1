<#
.SYNOPSIS
    Copies the Obsidian vault from OneDrive to Andrew J IT Labs.
.DESCRIPTION
    Uses Robocopy to mirror all files and folders from
    C:\Users\Administrator\OneDrive\Obsidian to the Andrew J IT Labs destination.
    Existing files at the destination are overwritten. Source files are not
    deleted. A timestamped log is written to the destination root.
.NOTES
    Author: Andrew Jones
    Version: 1.1
    Requires: PowerShell 5.1+, Robocopy (included in Windows)
    Changelog: v1.1 - Changed file filter from *.* to * to correctly mirror
               new folders and extension-less files.
#>
#Requires -Version 5.1

# ============================================================================
# CONFIG
# ============================================================================
$Source      = "C:\Users\%USERNAME%\Documents\my-blog\myblog"
$Destination = "C:\Users\Administrator\Andrew J IT Labs\PROJECTS 2026 - Documents\PROJECTS\Andrew J IT Labs - Andrew J IT Labs\WEB_DEV\myblog"
$LogFile     = "$Destination\CopyLog_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').txt"

# ============================================================================
# FUNCTIONS
# ============================================================================
function Write-Log {
    param (
        [string]$Message,
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR")]
        [string]$Level = "INFO"
    )
    $colours = @{
        "INFO"    = "Cyan"
        "SUCCESS" = "Green"
        "WARNING" = "Yellow"
        "ERROR"   = "Red"
    }
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] [$Level] $Message" -ForegroundColor $colours[$Level]
}

# ============================================================================
# MAIN
# ============================================================================
Write-Host "`n=== Obsidian Vault Copy ===`n" -ForegroundColor Cyan

# Validate source
if (-not (Test-Path -LiteralPath $Source)) {
    Write-Log "Source not found: $Source" -Level ERROR
    exit 1
}

# Create destination if it does not exist
if (-not (Test-Path -LiteralPath $Destination)) {
    Write-Log "Creating destination: $Destination" -Level WARNING
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
}

Write-Log "Source      : $Source"      -Level INFO
Write-Log "Destination : $Destination" -Level INFO
Write-Log "Log file    : $LogFile"     -Level INFO
Write-Host ""

# Robocopy flags:
#   *         - Match ALL files regardless of extension (was *.* - see changelog)
#   /E        - Copy subdirectories including empty ones
#   /COPYALL  - Copy all file attributes (data, timestamps, attributes, owner, ACL)
#   /R:3      - Retry 3 times on failed copies
#   /W:5      - Wait 5 seconds between retries
#   /TEE      - Output to console AND log file simultaneously
#   /LOG+     - Append to log file
$robocopyArgs = @(
    "`"$Source`""
    "`"$Destination`""
    "*"
    "/E"
    "/COPYALL"
    "/R:3"
    "/W:5"
    "/TEE"
    "/LOG+:`"$LogFile`""
)

Write-Log "Starting copy..." -Level INFO
Write-Host ""

$process = Start-Process -FilePath "robocopy" `
                         -ArgumentList $robocopyArgs `
                         -Wait `
                         -PassThru `
                         -NoNewWindow

# Robocopy exit codes: 0-7 = success/warnings, 8+ = one or more failures
# https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/robocopy#exit-return-codes
Write-Host ""
if ($process.ExitCode -lt 8) {
    Write-Log "Copy completed successfully. Exit code: $($process.ExitCode)" -Level SUCCESS
    Write-Log "Log saved to: $LogFile" -Level INFO
}
else {
    Write-Log "Copy completed with errors. Exit code: $($process.ExitCode)" -Level ERROR
    Write-Log "Review log for details: $LogFile" -Level WARNING
}

Write-Host ""