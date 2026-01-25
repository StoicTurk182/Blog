<#
.SYNOPSIS
    Hugo Blog Category Cleanup Tool

.DESCRIPTION
    Consolidates and cleans up categories across Hugo blog posts.
    Supports preview mode, backup creation, and configurable category mapping.

.EXAMPLE
    .\Cleanup-HugoCategories.ps1
    Runs interactively with menu

.EXAMPLE
    .\Cleanup-HugoCategories.ps1 -ContentPath "C:\myblog\content\posts"
    Specifies custom content path

.NOTES
    Author: Andrew Jones
    Version: 1.0
    Date: 2025-01-25
    
    Reference: https://gohugo.io/content-management/front-matter/
#>

param (
    [string]$ContentPath = "content\posts"
)

# ============================================================================
# CATEGORY MAPPING CONFIGURATION
# ============================================================================
# Edit this section to customize your category consolidation
# Format: "Old Category" = "New Category"
# Set to $null or "" to remove the category entirely

$Script:CategoryMapping = @{
    # Merge into Infrastructure
    "Home Lab"                                      = "Infrastructure"
    
    # Merge into Security
    "Penetration Testing"                           = "Security"
    "Monitoring"                                    = "Security"
    
    # Merge into Networking
    "Remote Access"                                 = "Networking"
    "Remote Management"                             = "Networking"
    
    # Merge into Microsoft
    "Intune"                                        = "Microsoft"
    "Microsoft 365"                                 = "Microsoft"
    "MDM"                                           = "Microsoft"
    "Enterprise"                                    = "Microsoft"
    
    # Merge into Linux
    "DevOps"                                        = "Linux"
    
    # Merge into Hardware
    "Technology"                                    = "Hardware"
    "Business"                                      = "Hardware"
    "Investigation"                                 = "Hardware"
    
    # Merge into Tools
    "Useful Tools and Applications"                 = "Tools"
    "Open Source"                                   = "Tools"
    "Mobile"                                        = "Tools"
    "Android"                                       = "Tools"
    
    # Remove entirely (set to empty string)
    "Getting Started Server Deployment - Debian VPS" = "Infrastructure"
}

# Categories to keep unchanged (no mapping needed, listed for reference)
$Script:KeepCategories = @(
    "Infrastructure"
    "Security"
    "Networking"
    "Microsoft"
    "Linux"
    "Hardware"
    "Tools"
    "System Administration"
    "Professional"
)

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

function Write-Log {
    param (
        [string]$Message,
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR", "HEADER")]
        [string]$Level = "INFO"
    )
    $colors = @{
        "INFO"    = "Cyan"
        "SUCCESS" = "Green"
        "WARNING" = "Yellow"
        "ERROR"   = "Red"
        "HEADER"  = "Magenta"
    }
    Write-Host $Message -ForegroundColor $colors[$Level]
}

function Get-PostCategories {
    param ([string]$FilePath)
    
    $content = Get-Content $FilePath -Raw
    $categories = @()
    
    if ($content -match 'categories:\s*\[([^\]]*)\]') {
        $catString = $Matches[1]
        $categories = $catString -split ',' | ForEach-Object {
            $_.Trim().Trim('"').Trim("'")
        } | Where-Object { $_ -ne "" }
    }
    
    return $categories
}

function Get-PostTitle {
    param ([string]$FilePath)
    
    $content = Get-Content $FilePath -Raw
    if ($content -match 'title:\s*"([^"]+)"') {
        return $Matches[1]
    }
    return (Get-Item $FilePath).BaseName
}

function Convert-Categories {
    param ([string[]]$Categories)
    
    $newCategories = @()
    
    foreach ($cat in $Categories) {
        if ($Script:CategoryMapping.ContainsKey($cat)) {
            $mapped = $Script:CategoryMapping[$cat]
            if ($mapped -and $mapped -ne "") {
                if ($mapped -notin $newCategories) {
                    $newCategories += $mapped
                }
            }
            # If mapped to empty/null, category is removed
        } else {
            # Keep unmapped categories as-is
            if ($cat -notin $newCategories) {
                $newCategories += $cat
            }
        }
    }
    
    return $newCategories | Sort-Object -Unique
}

function Update-PostCategories {
    param (
        [string]$FilePath,
        [string[]]$NewCategories
    )
    
    $content = Get-Content $FilePath -Raw
    
    # Build new categories string
    $catString = ($NewCategories | ForEach-Object { "`"$_`"" }) -join ", "
    $newCatLine = "categories: [$catString]"
    
    # Replace existing categories line
    $updatedContent = $content -replace 'categories:\s*\[[^\]]*\]', $newCatLine
    
    Set-Content -Path $FilePath -Value $updatedContent -NoNewline
}

# ============================================================================
# ANALYSIS FUNCTIONS
# ============================================================================

function Show-CurrentState {
    Clear-Host
    Write-Log "`n=== Current Category Analysis ===" "HEADER"
    Write-Host ""
    
    $posts = Get-ChildItem -Path $Script:ContentPath -Filter "*.md" -ErrorAction SilentlyContinue
    
    if (-not $posts) {
        Write-Log "No posts found in: $Script:ContentPath" "ERROR"
        Write-Log "Run script from Hugo site root or specify -ContentPath" "WARNING"
        return
    }
    
    $allCategories = @{}
    
    foreach ($post in $posts) {
        $categories = Get-PostCategories -FilePath $post.FullName
        foreach ($cat in $categories) {
            if (-not $allCategories.ContainsKey($cat)) {
                $allCategories[$cat] = @()
            }
            $allCategories[$cat] += $post.BaseName
        }
    }
    
    Write-Log "Categories by usage:" "INFO"
    Write-Host ""
    
    $sorted = $allCategories.GetEnumerator() | Sort-Object { $_.Value.Count } -Descending
    
    foreach ($item in $sorted) {
        $count = $item.Value.Count
        $name = $item.Key
        $willChange = $Script:CategoryMapping.ContainsKey($name)
        
        if ($willChange) {
            $newCat = $Script:CategoryMapping[$name]
            if ($newCat) {
                Write-Host "  $name " -NoNewline -ForegroundColor Yellow
                Write-Host "($count) " -NoNewline -ForegroundColor Gray
                Write-Host "-> $newCat" -ForegroundColor Green
            } else {
                Write-Host "  $name " -NoNewline -ForegroundColor Red
                Write-Host "($count) " -NoNewline -ForegroundColor Gray
                Write-Host "-> REMOVE" -ForegroundColor Red
            }
        } else {
            Write-Host "  $name " -NoNewline -ForegroundColor White
            Write-Host "($count)" -ForegroundColor Gray
        }
    }
    
    Write-Host ""
    Write-Host "  Total: $($posts.Count) posts, $($allCategories.Count) unique categories" -ForegroundColor Gray
}

function Show-Preview {
    Clear-Host
    Write-Log "`n=== Preview Changes ===" "HEADER"
    Write-Host ""
    
    $posts = Get-ChildItem -Path $Script:ContentPath -Filter "*.md" -ErrorAction SilentlyContinue
    
    if (-not $posts) {
        Write-Log "No posts found in: $Script:ContentPath" "ERROR"
        return
    }
    
    $changeCount = 0
    
    foreach ($post in $posts) {
        $title = Get-PostTitle -FilePath $post.FullName
        $currentCats = Get-PostCategories -FilePath $post.FullName
        $newCats = Convert-Categories -Categories $currentCats
        
        $currentStr = ($currentCats | Sort-Object) -join ", "
        $newStr = ($newCats | Sort-Object) -join ", "
        
        if ($currentStr -ne $newStr) {
            $changeCount++
            $shortTitle = $title.Substring(0, [Math]::Min(50, $title.Length))
            Write-Host ""
            Write-Log "  $shortTitle" "WARNING"
            Write-Host "    Current: " -NoNewline -ForegroundColor Gray
            Write-Host $currentStr -ForegroundColor Red
            Write-Host "    New:     " -NoNewline -ForegroundColor Gray
            Write-Host $newStr -ForegroundColor Green
        }
    }
    
    Write-Host ""
    if ($changeCount -eq 0) {
        Write-Log "No changes needed - all posts already use target categories" "SUCCESS"
    } else {
        Write-Log "$changeCount post(s) will be modified" "WARNING"
    }
}

function Show-PostDetails {
    Clear-Host
    Write-Log "`n=== Post Details ===" "HEADER"
    Write-Host ""
    
    $posts = Get-ChildItem -Path $Script:ContentPath -Filter "*.md" -ErrorAction SilentlyContinue
    
    if (-not $posts) {
        Write-Log "No posts found" "ERROR"
        return
    }
    
    $i = 1
    foreach ($post in $posts) {
        $title = Get-PostTitle -FilePath $post.FullName
        $categories = Get-PostCategories -FilePath $post.FullName
        $catStr = if ($categories.Count -gt 0) { $categories -join ", " } else { "NONE" }
        
        $shortTitle = $title.Substring(0, [Math]::Min(45, $title.Length))
        Write-Host "  [$i] " -NoNewline -ForegroundColor Yellow
        Write-Host "$shortTitle" -ForegroundColor White
        Write-Host "      $catStr" -ForegroundColor Gray
        $i++
    }
}

# ============================================================================
# ACTION FUNCTIONS
# ============================================================================

function Backup-Posts {
    $backupPath = "content\posts_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    
    Write-Log "`nCreating backup at: $backupPath" "INFO"
    
    try {
        Copy-Item -Path $Script:ContentPath -Destination $backupPath -Recurse -ErrorAction Stop
        Write-Log "Backup created successfully" "SUCCESS"
        return $true
    } catch {
        Write-Log "Backup failed: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Apply-Changes {
    Clear-Host
    Write-Log "`n=== Applying Changes ===" "HEADER"
    Write-Host ""
    
    # Create backup first
    $backupOk = Backup-Posts
    if (-not $backupOk) {
        Write-Log "Aborting - backup failed" "ERROR"
        return
    }
    
    Write-Host ""
    
    $posts = Get-ChildItem -Path $Script:ContentPath -Filter "*.md" -ErrorAction SilentlyContinue
    $modified = 0
    $skipped = 0
    
    foreach ($post in $posts) {
        $title = Get-PostTitle -FilePath $post.FullName
        $currentCats = Get-PostCategories -FilePath $post.FullName
        $newCats = Convert-Categories -Categories $currentCats
        
        $currentStr = ($currentCats | Sort-Object) -join ", "
        $newStr = ($newCats | Sort-Object) -join ", "
        
        if ($currentStr -ne $newStr) {
            Write-Host "  Updating: " -NoNewline -ForegroundColor Cyan
            Write-Host $post.Name -NoNewline -ForegroundColor White
            
            try {
                Update-PostCategories -FilePath $post.FullName -NewCategories $newCats
                Write-Host " OK" -ForegroundColor Green
                $modified++
            } catch {
                Write-Host " FAILED" -ForegroundColor Red
            }
        } else {
            $skipped++
        }
    }
    
    Write-Host ""
    Write-Log "Complete: $modified modified, $skipped unchanged" "SUCCESS"
}

function Edit-Mapping {
    Clear-Host
    Write-Log "`n=== Current Category Mapping ===" "HEADER"
    Write-Host ""
    Write-Host "  Edit the `$Script:CategoryMapping hashtable at the top of this script" -ForegroundColor Gray
    Write-Host "  to customize which categories get merged or removed." -ForegroundColor Gray
    Write-Host ""
    Write-Log "Current Mapping:" "INFO"
    Write-Host ""
    
    foreach ($item in $Script:CategoryMapping.GetEnumerator() | Sort-Object Name) {
        $target = if ($item.Value) { $item.Value } else { "REMOVE" }
        Write-Host "  `"$($item.Key)`"" -NoNewline -ForegroundColor Yellow
        Write-Host " -> " -NoNewline -ForegroundColor Gray
        $color = if ($item.Value) { "Green" } else { "Red" }
        Write-Host $target -ForegroundColor $color
    }
    
    Write-Host ""
    Write-Log "Target Categories (kept as-is):" "INFO"
    foreach ($cat in $Script:KeepCategories | Sort-Object) {
        Write-Host "  $cat" -ForegroundColor Green
    }
}

function Show-FinalCategories {
    Clear-Host
    Write-Log "`n=== Final Category List After Cleanup ===" "HEADER"
    Write-Host ""
    
    $posts = Get-ChildItem -Path $Script:ContentPath -Filter "*.md" -ErrorAction SilentlyContinue
    $finalCats = @{}
    
    foreach ($post in $posts) {
        $currentCats = Get-PostCategories -FilePath $post.FullName
        $newCats = Convert-Categories -Categories $currentCats
        
        foreach ($cat in $newCats) {
            $finalCats[$cat]++
        }
    }
    
    Write-Log "Categories after cleanup:" "INFO"
    Write-Host ""
    
    $finalCats.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object {
        Write-Host "  $($_.Key) " -NoNewline -ForegroundColor Green
        Write-Host "($($_.Value) posts)" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "  Total: $($finalCats.Count) categories (down from current)" -ForegroundColor Gray
}

# ============================================================================
# MAIN MENU
# ============================================================================

function Show-Menu {
    Write-Host ""
    Write-Log "=== Hugo Category Cleanup Tool ===" "HEADER"
    Write-Host "  Content Path: $Script:ContentPath" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [1] Show Current State (analysis)" -ForegroundColor Yellow
    Write-Host "  [2] Show Post Details" -ForegroundColor Yellow
    Write-Host "  [3] Preview Changes" -ForegroundColor Yellow
    Write-Host "  [4] Show Final Categories (after cleanup)" -ForegroundColor Yellow
    Write-Host "  [5] View/Edit Mapping" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  [A] Apply Changes (creates backup first)" -ForegroundColor Green
    Write-Host ""
    Write-Host "  [0] Exit" -ForegroundColor Gray
    Write-Host ""
}

# ============================================================================
# ENTRY POINT
# ============================================================================

# Resolve content path
if (-not [System.IO.Path]::IsPathRooted($ContentPath)) {
    $Script:ContentPath = Join-Path (Get-Location) $ContentPath
} else {
    $Script:ContentPath = $ContentPath
}

# Verify path exists
if (-not (Test-Path $Script:ContentPath)) {
    Write-Log "Content path not found: $Script:ContentPath" "ERROR"
    Write-Log "Run from Hugo site root or use -ContentPath parameter" "WARNING"
    exit 1
}

# Main loop
$running = $true
while ($running) {
    Show-Menu
    $choice = Read-Host "  Selection"
    
    switch ($choice.ToUpper()) {
        "1" { Show-CurrentState; Read-Host "`n  Press Enter to continue" }
        "2" { Show-PostDetails; Read-Host "`n  Press Enter to continue" }
        "3" { Show-Preview; Read-Host "`n  Press Enter to continue" }
        "4" { Show-FinalCategories; Read-Host "`n  Press Enter to continue" }
        "5" { Edit-Mapping; Read-Host "`n  Press Enter to continue" }
        "A" {
            Write-Host ""
            $confirm = Read-Host "  This will modify files. Continue? (Y/N)"
            if ($confirm -eq "Y" -or $confirm -eq "y") {
                Apply-Changes
                Read-Host "`n  Press Enter to continue"
            }
        }
        "0" { $running = $false }
        default { }
    }
}

Write-Host "`n  Goodbye.`n" -ForegroundColor Cyan
