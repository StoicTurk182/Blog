# Hugo Submodule Deployment Guide

Guide for managing a Hugo site that uses a custom theme fork as a git submodule, covering the full local-to-VPS deployment workflow.

## Background

Hugo themes managed as git submodules require two separate repositories to stay in sync:

- The parent blog repo (StoicTurk182/Blog) — stores site content, config, and a pointer to a specific submodule commit
- The theme fork repo (StoicTurk182/Mainroad) — stores the custom theme on a `custom-theme` branch

The parent repo does not store the theme files directly. It stores a commit hash pointer. If the submodule branch is not pushed to its remote, or the parent repo pointer is not updated, the VPS will not pick up theme changes regardless of how many times you deploy.

## Problem Summary

Theme changes made locally were not appearing on the live site after deployment. Root cause was a chain of three issues:

1. Local `custom-theme` commits were not pushed to `origin/custom-theme` on the submodule remote
2. The parent repo was pointing at a stale submodule commit hash
3. The VPS deploy script was not initialising or updating the submodule after pulling the parent repo

---

## Local Workflow

### Step 1: Commit and push theme changes

If changes were made inside `themes/mainroad`:

```powershell
cd themes\mainroad
git add .
git commit -m "UI: description of change"
git push origin custom-theme
```

Verify the push succeeded — if the output says `Everything up-to-date` but you have local commits not on the remote, the submodule is in a detached HEAD state. Fix it:

```powershell
git checkout custom-theme
git push origin custom-theme
```

### Step 2: Update the parent repo submodule pointer

Return to the site root and lock in the new theme commit:

```powershell
cd ..\..
git add .gitmodules
git add themes/mainroad
git commit -m "Chore: update mainroad submodule pointer to latest custom-theme"
git push origin main
```

Verify `.gitmodules` points to your fork, not the upstream:

```powershell
Get-Content .gitmodules
```

Should show:

```
[submodule "themes/mainroad"]
    path = themes/mainroad
    url = https://github.com/StoicTurk182/Mainroad.git
    branch = custom-theme
```

---

## VPS Deployment

### Step A: Fix permissions

Ensure the debian user owns the directory before running git operations:

```bash
sudo chown -R debian:debian /var/www/html
```

### Step B: Pull and sync submodule

```bash
cd /var/www/html
git pull origin main
git submodule sync --recursive
git submodule update --init --recursive
```

`git submodule sync` updates the local submodule URL from `.gitmodules` in case it has changed. `git submodule update --init --recursive` forces the submodule to match the commit pointer stored in the parent repo.

### Step C: Build the site

```bash
hugo --minify --destination /var/www/html/public
```

### Step D: Restore webserver ownership

```bash
sudo chown -R www-data:www-data /var/www/html
sudo chmod -R 755 /var/www/html
sudo systemctl reload nginx
```

---

## Deploy Script

The deploy script at `/usr/local/bin/deploy` should contain the following:

```bash
#!/bin/bash
# Production Deployment Script
set -e

echo "Starting deployment..."
cd /var/www/html/

echo "Fetching latest changes..."
git fetch origin

echo "Stashing local changes..."
git stash

echo "Resetting to origin/main..."
git reset --hard origin/main

echo "Cleaning untracked files..."
git clean -fd

echo "Syncing submodules..."
git submodule sync --recursive
git submodule update --init --recursive

echo "Building application..."
hugo --minify --destination /var/www/html/public

echo "Reloading nginx..."
sudo systemctl reload nginx

echo "Deployment completed successfully!"
```

---

## Troubleshooting

| Issue | Command |
|-------|---------|
| Permission denied on git | `sudo chown -R debian:debian /var/www/html` |
| Submodule path not found | `git submodule update --init --recursive` |
| Theme folder is empty | `git submodule update --init` |
| Formatting not updating after build | `hugo --minify` then hard refresh (`Ctrl + Shift + R`) |
| Wrong submodule URL | Check `.gitmodules` or run `git remote -v` inside `themes/mainroad` |
| Push says Everything up-to-date but commits are missing | `git checkout custom-theme` then `git push origin custom-theme` |
| Server submodule on wrong commit | `cd themes/mainroad && git fetch origin && git checkout custom-theme && git pull origin custom-theme` |

---

## Verify Submodule State

Check what commit the submodule is pointing at locally:

```powershell
git submodule status
```

A `+` prefix means the submodule has local uncommitted changes. A `-` prefix means it has not been initialised. No prefix means clean.

Check the submodule branch and recent commits:

```powershell
cd themes\mainroad
git branch
git log --oneline -5
```

Check origin is pointing at your fork:

```powershell
git remote -v
```

---

## References

- Git Submodules: https://git-scm.com/book/en/v2/Git-Tools-Submodules
- Hugo Theme Components: https://gohugo.io/hugo-modules/theme-components/
- Git Submodule Update: https://git-scm.com/docs/git-submodule
