---
title: "Linux Double-Lock Deletion Protection - SOP"
date: 2026-01-25
lastmod: 2026-01-25
draft: false
author: "Andrew Jones"
description: "Standard Operating Procedure establishing dual-layer protection against catastrophic data loss from accidental rm -rf commands on Debian-based servers"
categories: ["Linux", "Security"]
tags: ["Debian", "Ubuntu", "safe-rm", "System Administration", "Data Protection", "VPS", "Server Management"]
featuredImage: "/images/rm-rf-danger-dark.png"
toc: true
---


# The Evil Command 

*A single command, or a slight variation of it, has led to the death of thousands of innocent servers. The most frustrating part? It is entirely preventable. I consider the following setup a mandatory part of any deployment process—even for non-production systems. For a sobering reminder of the absolute worst-case scenario, [read this account](https://www.reddit.com/r/cscareerquestions/comments/1qjsfv8/accidentally_rm_rfd_a_production_server/) of a production server being wiped in an instant.*

## Standard Operating Procedure: The "Double-Lock"
> This SOP establishes a redundant protection system for Debian-based servers to prevent catastrophic data loss caused by accidental `rm -rf /` execution.

## Target Systems

- Debian (all versions)
- Ubuntu (all versions)

## Protection Layers

1. **Layer 1 (Application)**: `safe-rm` binary wrapper
2. **Layer 2 (System)**: `sudoers` command-level exclusion

### Layer 1: Application-Level Protection (safe-rm)

The `safe-rm` utility acts as a binary wrapper that intercepts deletion commands before they reach the system `rm` binary. When a protected path is targeted, `safe-rm` refuses to execute the command regardless of user privileges.

### Layer 2: System-Level Protection (sudoers)

The sudoers configuration implements command-level exclusion rules that prevent specific dangerous command patterns from executing, even when invoked with elevated privileges. This layer operates independently of Layer 1 and provides redundant protection.

## Implementation

### Step 1: Install and Intercept

The default `safe-rm` installation does not replace the system `rm` binary. Manual intervention is required to redirect system calls to the protected version.

```bash
# Update package index and install safe-rm
sudo apt update && sudo apt install safe-rm -y

# Create symbolic link in /usr/local/bin to override system rm
# /usr/local/bin takes priority over /bin in the default $PATH
sudo ln -sf /usr/bin/safe-rm /usr/local/bin/rm

# Verify the system is now using safe-rm
which rm
```

Expected output: `/usr/local/bin/rm`

The symbolic link placement leverages the standard Linux PATH resolution order where `/usr/local/bin` is evaluated before `/bin`. This ensures `safe-rm` intercepts all `rm` commands without modifying the base system binary.

### Step 2: Configure Protected Paths

Define the "No-Fly Zone." Any path listed in `/etc/safe-rm.conf` will be skipped by `safe-rm`, even if the user is root.

```bash
sudo tee /etc/safe-rm.conf > /dev/null << 'EOF'
# Root & System Directories
/
/bin
/boot
/dev
/etc
/home
/lib
/lib64
/opt
/proc
/root
/run
/sbin
/srv
/sys
/tmp
/usr
/var

# Custom Data Paths
/Backup_Data
/mnt/data
EOF
```

The configuration file uses one path per line. Add any additional custom paths that contain critical data or system configurations specific to your deployment.

### Step 3: Deploy the Sudoers "Kill-Switch"

This prevents the `rm -rf /` command string from even executing. It acts as the primary barrier before the command reaches the binary.

```bash
sudo tee /etc/sudoers.d/prevent_nuke > /dev/null << 'EOF'
# Block dangerous rm patterns regardless of flags or spaces
ALL ALL=(ALL) ALL, !/bin/rm * /, !/usr/bin/rm * /, !/usr/local/bin/rm * /
ALL ALL=(ALL) ALL, !/bin/rm * /*, !/usr/bin/rm * /*, !/usr/local/bin/rm * /*
EOF

# Set required strict permissions (sudoers files must be mode 0440)
sudo chmod 440 /etc/sudoers.d/prevent_nuke

# Verify syntax - CRITICAL: If this fails, do not logout
sudo visudo -c
```

Expected output: `parsed OK`

The sudoers file must have permissions of 0440 (read-only for root and group). Incorrect permissions will cause sudo to ignore the file. The `visudo -c` command validates syntax before the configuration takes effect. A syntax error in sudoers can lock you out of sudo access.

### Step 4: Verification Procedure (The Canary Test)

Use this test sequence to confirm both protection layers are active without targeting actual protected paths.

```bash
# Create a test canary directory
sudo mkdir -p /tmp/safe-zone
sudo touch /tmp/safe-zone/canary.txt

# Temporarily add to safe-rm configuration
sudo sh -c 'echo "/tmp/safe-zone" >> /etc/safe-rm.conf'

# Test Layer 1 (safe-rm)
# Expected output: safe-rm: Skipping /tmp/safe-zone
rm -rf /tmp/safe-zone

# Test Layer 2 (Sudoers)
# Expected output: Sorry, user ... is not allowed to execute...
sudo /usr/local/bin/rm -rf /
```

The first test verifies `safe-rm` is intercepting commands and checking the configuration file. The second test verifies the sudoers exclusion rules are active. Both should fail to execute the deletion command.

### Step 5: Final Summary Script

Run this on every new server to ensure the SOP was followed correctly:

```bash
echo "=== DOUBLE-LOCK STATUS ==="
echo "Binary Path: $(which rm)"
echo "Sudoers File: $(ls -l /etc/sudoers.d/prevent_nuke | awk '{print $1, $3}')"
echo "Protected Paths: $(grep -c '^/' /etc/safe-rm.conf) directories secured."
sudo visudo -c | grep -q "parsed OK" && echo "Sudoers Syntax: VALID" || echo "Sudoers Syntax: ERROR"
echo "=========================="
```

## Maintenance & Removal

To add a new protected path: Add the line to `/etc/safe-rm.conf`.

To remove protection: Delete `/etc/sudoers.d/prevent_nuke` and the symlink `/usr/local/bin/rm`.

## Technical Details

### PATH Resolution Order

The standard Linux PATH on Debian/Ubuntu systems is evaluated in this order:

1. /usr/local/bin
2. /usr/bin
3. /bin

By placing the `safe-rm` symlink at `/usr/local/bin/rm`, all invocations of `rm` resolve to `safe-rm` before reaching the system binary at `/bin/rm`.

### Sudoers Pattern Matching

The sudoers exclusion rules use wildcard pattern matching to block commands regardless of how they are invoked:

- `!/bin/rm * /` blocks `rm -rf /`
- `!/bin/rm * /*` blocks `rm -rf /*`

The patterns account for various flag combinations and whitespace variations. The asterisk wildcard matches any flags between `rm` and the path target.

## Limitations

This protection system has the following limitations:

- Does not protect against deletion via alternative tools (find -delete, shred, etc.)
- Can be bypassed by calling `/bin/rm` directly to avoid Layer 1
- Requires proper sudoers syntax to maintain Layer 2 effectiveness
- Does not protect against deliberate removal of the protection mechanisms by root user
- Protection effectiveness depends on PATH environment variable configuration

The system is designed to prevent accidental catastrophic deletion, not to protect against deliberate circumvention by an adversary with root access.

## Full Deployment Script

Single-line command to deploy all protection layers on your VPS instances:

```bash
sudo apt update && sudo apt install safe-rm -y && sudo ln -sf /usr/bin/safe-rm /usr/local/bin/rm && sudo tee /etc/safe-rm.conf > /dev/null << 'EOF'
/
/bin
/boot
/dev
/etc
/home
/lib
/lib64
/opt
/proc
/root
/run
/sbin
/srv
/sys
/tmp
/usr
/var
/Backup_Data
/mnt/data
EOF
sudo tee /etc/sudoers.d/prevent_nuke > /dev/null << 'EOF'
ALL ALL=(ALL) ALL, !/bin/rm * /, !/usr/bin/rm * /, !/usr/local/bin/rm * /
ALL ALL=(ALL) ALL, !/bin/rm * /*, !/usr/bin/rm * /*, !/usr/local/bin/rm * /*
EOF
sudo chmod 440 /etc/sudoers.d/prevent_nuke && sudo visudo -c
```

This single-line deployment script combines all steps for rapid deployment across multiple VPS instances.

## References

- safe-rm package: https://packages.debian.org/stable/safe-rm
- safe-rm source repository: https://github.com/lagerspetz/safe-rm
- sudoers manual: https://www.sudo.ws/docs/man/sudoers.man/
- Debian PATH configuration: https://wiki.debian.org/EnvironmentVariables
- Linux Filesystem Hierarchy Standard: https://refspecs.linuxfoundation.org/FHS_3.0/fhs/index.html