# Hugo Blog Category Cleanup Guide

Documented process for consolidating Hugo blog categories from 27 down to 10 core categories.

## Overview

This guide covers the complete process of analysing, mapping, and cleaning up Hugo blog categories using PowerShell scripts and manual fixes.

## Before and After

| Metric | Before | After |
|--------|--------|-------|
| Total Categories | 27 | 10 |
| Posts | 18 | 18 |
| Duplicate/Redundant | 17 | 0 |

### Final Category Structure

| Category | Description |
|----------|-------------|
| Infrastructure | Servers, deployment, home lab |
| Security | Security, penetration testing, monitoring |
| Networking | Networks, VPN, remote access, remote management |
| Microsoft | Intune, M365, MDM, enterprise Windows |
| Linux | Linux administration, DevOps |
| Hardware | PC builds, technology |
| Tools | Software tools, applications, utilities |
| System Administration | General sysadmin tasks |
| Professional | Career and professional content |
| page | Hugo internal (ignore) |

## Process

### Step 1: Analyse Current Categories

Run from Hugo site root to get category count:

```powershell
$cats = @{}
Get-ChildItem -Path "content" -Filter "*.md" -Recurse | ForEach-Object {
    $content = Get-Content $_.FullName -Raw
    if ($content -match 'categories:\s*\[([^\]]*)\]') {
        $Matches[1] -split ',' | ForEach-Object {
            $cat = $_.Trim().Trim('"').Trim("'")
            if ($cat) { $cats[$cat]++ }
        }
    }
}
$cats.GetEnumerator() | Sort-Object Value -Descending | Format-Table @{L='Category';E={$_.Name}}, @{L='Posts';E={$_.Value}} -AutoSize
```

### Step 2: View Posts with Categories

```powershell
Get-ChildItem -Path "content/posts" -Filter "*.md" | ForEach-Object {
    $content = Get-Content $_.FullName -Raw
    $title = if ($content -match 'title:\s*"([^"]+)"') { $Matches[1] } else { $_.BaseName }
    $categories = if ($content -match 'categories:\s*\[([^\]]*)\]') { $Matches[1] } else { "NONE" }
    [PSCustomObject]@{ Post = $title.Substring(0, [Math]::Min(40, $title.Length)); Categories = $categories }
} | Format-Table -AutoSize
```

### Step 3: Define Category Mapping

Categories were consolidated using this mapping:

| Old Category | New Category |
|--------------|--------------|
| Home Lab | Infrastructure |
| Penetration Testing | Security |
| Monitoring | Security |
| Remote Access | Networking |
| Remote Management | Networking |
| Intune | Microsoft |
| Microsoft 365 | Microsoft |
| MDM | Microsoft |
| Enterprise | (removed) |
| DevOps | Linux |
| Technology | Hardware |
| Business | (removed) |
| Investigation | (removed) |
| Open Source | Tools |
| Mobile | Tools |
| Android | Tools |
| Useful Tools and Applications | Tools |
| Getting Started Server Deployment - Debian VPS | Infrastructure |

### Step 4: Run Bulk Replacement

```powershell
$mapping = @{
    '"Home Lab"' = ''
    '"Penetration Testing"' = '"Security"'
    '"Intune"' = '"Microsoft"'
    '"Microsoft 365"' = '"Microsoft"'
    '"MDM"' = ''
    '"Enterprise"' = ''
    '"DevOps"' = '"Linux"'
    '"Remote Access"' = '"Networking"'
    '"Remote Management"' = '"Networking"'
    '"Monitoring"' = '"Security"'
    '"Technology"' = '"Hardware"'
    '"Business"' = ''
    '"Investigation"' = ''
    '"Open Source"' = '"Tools"'
    '"Mobile"' = '"Tools"'
    '"Android"' = '"Tools"'
    '"Useful Tools and Applications"' = '"Tools"'
    "'Getting Started Server Deployment - Debian VPS'" = '"Infrastructure"'
}

Get-ChildItem "content\posts" -Filter "*.md" | ForEach-Object {
    $content = Get-Content $_.FullName -Raw
    foreach ($old in $mapping.Keys) {
        $content = $content -replace [regex]::Escape($old), $mapping[$old]
    }
    # Clean up empty entries
    $content = $content -replace ',\s*,', ','
    $content = $content -replace '\[\s*,', '['
    $content = $content -replace ',\s*\]', ']'
    Set-Content $_.FullName -Value $content -NoNewline
    Write-Host "Updated: $($_.Name)" -ForegroundColor Green
}
```

### Step 5: Fix Remaining Stragglers

After initial cleanup, check for remaining old categories:

```powershell
$oldCats = @("Home Lab", "Penetration Testing", "Intune", "Microsoft 365", "MDM", "Enterprise", "DevOps", "Remote Access", "Remote Management", "Useful Tools")
Get-ChildItem "content\posts" -Filter "*.md" | ForEach-Object {
    $content = Get-Content $_.FullName -Raw
    foreach ($cat in $oldCats) {
        if ($content -match [regex]::Escape($cat)) {
            Write-Host "$($_.Name): still has '$cat'" -ForegroundColor Yellow
        }
    }
}
```

Fix any remaining:

```powershell
Get-ChildItem "content\posts" -Filter "*.md" | ForEach-Object {
    $content = Get-Content $_.FullName -Raw
    $original = $content
    
    $content = $content -replace '"Remote Management"', '"Networking"'
    $content = $content -replace '"Useful Tools and Applications"', '"Tools"'
    
    if ($content -ne $original) {
        Set-Content $_.FullName -Value $content -NoNewline
        Write-Host "Fixed: $($_.Name)" -ForegroundColor Green
    }
}
```

### Step 6: Move Backup Folder

If the cleanup script created a backup inside `content/`, move it out to prevent Hugo processing it:

```powershell
Move-Item "content\posts_backup_*" -Destination "..\posts_backup" -Force
```

### Step 7: Clean Rebuild

```powershell
Remove-Item "public", "resources" -Recurse -Force -ErrorAction SilentlyContinue
hugo --gc --cleanDestinationDir
```

### Step 8: Verify Final Categories

```powershell
Get-ChildItem "public/categories" -Directory | Select-Object Name
```

Expected output:

```
hardware
infrastructure
linux
microsoft
networking
professional
security
system-administration
tools
```

## Troubleshooting

### Old categories still appearing in sidebar

The Mainroad theme's sidebar widget pulls from Hugo's taxonomy system. Ensure:

1. `public/` folder is deleted before rebuild
2. `resources/` folder is deleted before rebuild
3. No backup folders exist inside `content/`
4. Run `hugo --gc --cleanDestinationDir`

### Backup folder being processed as content

Hugo processes everything in `content/`. Move backups outside:

```powershell
Move-Item "content\posts_backup_*" -Destination "C:\backups\" -Force
```

### Duplicate categories in array

Clean up malformed category arrays:

```powershell
# Find posts with empty or duplicate entries
Select-String -Path "content\posts\*.md" -Pattern 'categories:\s*\[' | ForEach-Object {
    $_.Line
}
```

### Check specific post categories

```powershell
$file = "content\posts\example.md"
$content = Get-Content $file -Raw
if ($content -match 'categories:\s*\[([^\]]*)\]') {
    Write-Host "Categories: $($Matches[1])"
}
```

## Hugo Configuration

The sidebar categories widget is configured in `hugo.toml`:

```toml
[params.sidebar]
  home = true
  single = false
  list = false
  widgets = ["recent", "categories"]

[params.widgets]
  categories_counter = true
```

The widget automatically displays all categories found in posts. No manual category list is required.

## Files Created

| File | Purpose |
|------|---------|
| Cleanup-HugoCategories.ps1 | Interactive menu-driven cleanup tool |
| This guide | Documentation of the process |

## References

- Hugo Front Matter: https://gohugo.io/content-management/front-matter/
- Hugo Taxonomies: https://gohugo.io/content-management/taxonomies/
- Mainroad Theme: https://github.com/Vimux/Mainroad
