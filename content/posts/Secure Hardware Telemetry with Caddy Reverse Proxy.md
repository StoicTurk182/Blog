---
title: "Secure Hardware Telemetry with Caddy"
date: 2026-02-05
draft: false
description: "Implementing a secure reverse proxy architecture for LibreHardwareMonitor using Caddy with internal TLS, HTTP Basic Authentication, granular firewall controls, and Tailscale overlay networking on Windows infrastructure."
categories: ["Infrastructure", "Security"]
tags: ["caddy", "tailscale", "windows", "reverse-proxy", "librehardwaremonitor", "networking", "authentication", "firewall"]
featuredImage: "/images/posts/caddy_logo.png"
readingTime: true
toc: true
author: "Andrew Jones"
authorBio: "L2 IT Support Engineer specializing in system administration and network infrastructure"
socialShare: true
codemirror: true
---

## Overview
---

The convergence of home lab infrastructure, remote systems administration, and Zero Trust networking principles has necessitated robust solutions for exposing internal telemetry without compromising security. This guide provides a comprehensive implementation for securing LibreHardwareMonitor using Caddy as a reverse proxy and Tailscale as the transport layer.

The architecture moves beyond simple port forwarding, utilizing an overlay network (Tailscale) to render the service invisible to the public internet, while employing application-layer encryption (TLS) via Caddy. Version 5.0 adds HTTP Basic Authentication and granular firewall rule management, adhering to the principle of Defence in Depth.

## Architecture Overview
---

The solution integrates three distinct technologies with multiple security layers:

| Component | Role | Port |
|-----------|------|------|
| LibreHardwareMonitor | Hardware telemetry source | 8085 (HTTP) |
| Caddy | Reverse proxy with TLS termination and authentication | 8086 (HTTPS) |
| Tailscale | Encrypted overlay network | WireGuard tunnel |

### Security Layers
---

| Layer | Protection |
|-------|------------|
| Network | Windows Firewall with scope-based rules |
| Overlay | Tailscale mesh - invisible to public internet |
| Transport | WireGuard encryption (ChaCha20-Poly1305) |
| Application | Caddy internal TLS (self-signed) |
| Authentication | HTTP Basic Auth with bcrypt hashing |
| Binding | Tailscale IP only - no LAN exposure |

## Prerequisites
---

### LibreHardwareMonitor Configuration
---

LibreHardwareMonitor must be configured to expose its web server on the local network.

1. Download from [GitHub Releases](https://github.com/LibreHardwareMonitor/LibreHardwareMonitor/releases)
2. Extract to `C:\Tools\LibreHardwareMonitor`
3. Run as Administrator (required for hardware sensor access)
4. Enable web server: **Options** > **Remote Web Server** > **IP** > Select your LAN IP
5. Enable web server: **Options** > **Remote Web Server** > **Run**

Verify the upstream is accessible locally:

```powershell
Test-NetConnection -ComputerName 10.1.10.30 -Port 8085
```

### Tailscale Installation
---

Ensure Tailscale is installed and authenticated on the host system. Verify your Tailscale IP:

```powershell
tailscale ip -4
```

Example output: `100.0.0.0`

## Implementation
---

### Quick Start
---

For automated deployment with recommended security settings:

```powershell
.\Setup-CaddyProxy.ps1 -Action Install -EnableAuth -FirewallScope TailscaleOnly
```

This enables authentication (prompts for credentials) and restricts firewall access to Tailscale devices only.

### Step 1: Create Directory Structure
---

```powershell
New-Item -ItemType Directory -Path "C:\Caddy" -Force
New-Item -ItemType Directory -Path "C:\Caddy\data" -Force
New-Item -ItemType Directory -Path "C:\Caddy\logs" -Force
```

### Step 2: Download Caddy
---

```powershell
Invoke-WebRequest -Uri "https://caddyserver.com/api/download?os=windows&arch=amd64" -OutFile "C:\Caddy\caddy.exe"
```

Verify installation:

```powershell
C:\Caddy\caddy.exe version
```

### Step 3: Create Caddyfile
---

Open Notepad to create the configuration:

```powershell
notepad C:\Caddy\Caddyfile
```

Paste the following configuration (without authentication):

```caddy
100.0.0.0:8086 {
    reverse_proxy 10.1.10.30:8085
    tls internal
}
```

Or with HTTP Basic Authentication:

```caddy
100.0.0.0:8086 {
    basicauth {
        admin $2a$14$Zkx19XLiW6VYouLHR5NmfOFU0z2GTNmpkT/5qqR7hx4IjWJPDhjvG
    }
    reverse_proxy 10.1.10.30:8085
    tls internal
}
```

Generate a password hash using Caddy:

```powershell
"YourPassword" | C:\Caddy\caddy.exe hash-password
```

Configuration breakdown:

| Directive | Purpose |
|-----------|---------|
| `100.0.0.0:8086` | Bind only to Tailscale interface on port 8086 |
| `basicauth` | Require username/password authentication |
| `reverse_proxy` | Forward requests to LibreHardwareMonitor |
| `tls internal` | Generate self-signed certificate for HTTPS |

### Step 4: Configure Windows Firewall
---

The script provides three firewall scope options for different security requirements:

#### Tailscale Only (Recommended)
---

Restricts access to the Tailscale CGNAT range (100.64.0.0/10):

```powershell
New-NetFirewallRule -DisplayName "Caddy Reverse Proxy (Tailscale Only)" `
    -Direction Inbound `
    -Protocol TCP `
    -LocalPort 8086 `
    -RemoteAddress 100.64.0.0/10 `
    -Action Allow `
    -Profile Any
```

#### LAN Restricted
---

Allows specific IP addresses or subnets:

```powershell
New-NetFirewallRule -DisplayName "Caddy Reverse Proxy (LAN Restricted)" `
    -Direction Inbound `
    -Protocol TCP `
    -LocalPort 8086 `
    -RemoteAddress 10.1.10.0/24 `
    -Action Allow `
    -Profile Private,Domain
```

#### Any (Least Secure)
---

Allows all connections (not recommended for production):

```powershell
New-NetFirewallRule -DisplayName "Caddy Reverse Proxy (Any)" `
    -Direction Inbound `
    -Protocol TCP `
    -LocalPort 8086 `
    -Action Allow `
    -Profile Any
```

### Step 5: Test Configuration
---

Run Caddy in foreground mode to verify the configuration:

```powershell
C:\Caddy\caddy.exe run --config C:\Caddy\Caddyfile
```

Expected output:

```powershell
INFO    admin   admin endpoint started
INFO    tls.cache.maintenance   started background certificate maintenance
INFO    http.log        server running
INFO    autosaved config
INFO    serving initial configuration
```

Test from another terminal:

```powershell
Test-NetConnection -ComputerName 100.0.0.0 -Port 8086
```

### Step 6: Install as Windows Service
---

Stop the foreground process (Ctrl+C), then create the service:

```powershell
sc.exe create Caddy start= auto binPath= "C:\Caddy\caddy.exe run --config C:\Caddy\Caddyfile"
```

**Important:** Note the space after each equals sign - this is required by `sc.exe` syntax.

Configure automatic restart on failure:

```powershell
sc.exe failure Caddy reset= 86400 actions= restart/60000/restart/60000/restart/60000
```

This configures:
- Reset failure count after 24 hours (86400 seconds)
- Restart after 60 seconds on first, second, and subsequent failures

Start the service:

```powershell
Start-Service Caddy
```

## Authentication
---

### How It Works
---

Caddy's `basicauth` directive provides HTTP Basic Authentication with bcrypt-hashed passwords. The script uses Caddy's built-in `hash-password` command to generate secure hashes, ensuring passwords are never stored in plain text.

### Password Requirements
---

| Requirement | Value |
|-------------|-------|
| Minimum length | 8 characters |
| Hash algorithm | bcrypt (Caddy default) |
| Storage | auth.json (admin-only ACL) |

### Managing Authentication via Script
---

The interactive menu provides full authentication management:

| Option | Action |
|--------|--------|
| Enable/Update Authentication | Set username and password |
| Change Password | Update password for existing user |
| Disable Authentication | Remove auth and regenerate Caddyfile |

Command-line usage:

```powershell
# Enable during install
.\Setup-CaddyProxy.ps1 -Action Install -EnableAuth -AuthUsername "monitor"

# With custom username
.\Setup-CaddyProxy.ps1 -Action Install -EnableAuth -AuthUsername "admin"
```

### Security Considerations for Authentication
---

The script handles password security by:
1. Accepting passwords via `SecureString` (masked input)
2. Converting to plain text only for hashing
3. Immediately clearing plain text from memory
4. Storing only the bcrypt hash in `auth.json`
5. Restricting file permissions to Administrators and SYSTEM only

## Firewall Management
---

### Scope Options
---

| Scope | Remote Address | Profile | Security Level |
|-------|----------------|---------|----------------|
| TailscaleOnly | 100.64.0.0/10 | Any | Highest |
| LAN | User-specified | Private,Domain | Medium |
| Any | Any | Any | Lowest |

### Command-Line Usage
---

```powershell
# Tailscale only (default, most secure)
.\Setup-CaddyProxy.ps1 -Action Install -FirewallScope TailscaleOnly

# LAN subnet
.\Setup-CaddyProxy.ps1 -Action Install -FirewallScope LAN -AllowedAddresses "10.1.10.0/24"

# Specific hosts
.\Setup-CaddyProxy.ps1 -Action Install -FirewallScope LAN -AllowedAddresses "10.1.10.10,10.1.10.30"

# Mixed (subnet + specific IPs)
.\Setup-CaddyProxy.ps1 -Action Install -FirewallScope LAN -AllowedAddresses "10.1.10.0/24,192.168.1.50"
```

### Interactive Menu
---

The firewall submenu (`[F]` from main menu) provides:

| Option | Action |
|--------|--------|
| [1] Tailscale Only | Restrict to 100.64.0.0/10 |
| [2] LAN Restricted | Specify addresses interactively |
| [3] Any | Allow all (with confirmation) |
| [4] Remove All Rules | Delete all Caddy firewall rules |
| [5] Refresh Status | View current rule configuration |

### Viewing Current Rules
---

```powershell
Get-NetFirewallRule -DisplayName "Caddy Reverse Proxy*" | ForEach-Object {
    $port = Get-NetFirewallPortFilter -AssociatedNetFirewallRule $_
    $addr = Get-NetFirewallAddressFilter -AssociatedNetFirewallRule $_
    [PSCustomObject]@{
        Name = $_.DisplayName
        Enabled = $_.Enabled
        Port = $port.LocalPort
        RemoteAddress = $addr.RemoteAddress
        Profile = $_.Profile
    }
} | Format-Table -AutoSize
```

## Verification
---

### Service Status
---

```powershell
Get-Service Caddy
```

### Port Listening
---

```powershell
Get-NetTCPConnection -LocalPort 8086 -State Listen | Format-Table LocalAddress, LocalPort
```

Expected output:

```powershell
LocalAddress   LocalPort
------------   ---------
100.0.0.0        8086
```

### Browser Test
---

From any Tailscale-connected device, navigate to:

```powershell
https://100.0.0.0:8086/
```

If authentication is enabled, you will be prompted for credentials. Accept the certificate warning (expected for self-signed certificates), and the LibreHardwareMonitor dashboard should load.

## Service Management
---

| Action | Command |
|--------|---------|
| Start | `Start-Service Caddy` |
| Stop | `Stop-Service Caddy` |
| Restart | `Restart-Service Caddy` |
| Status | `Get-Service Caddy` |
| Delete | `sc.exe delete Caddy` |


# Local Scheduled Task setup

## LibreHardwareMonitor Setup Guide
---

Configuration guide for LibreHardwareMonitor with persistent settings and automatic restart watchdog.

Repository: https://github.com/LibreHardwareMonitor/LibreHardwareMonitor

## Download and Install
---

1. Download latest release from: https://github.com/LibreHardwareMonitor/LibreHardwareMonitor/releases
2. Extract ZIP to `C:\LibreHardwareMonitor`
3. Run `LibreHardwareMonitor.exe` as Administrator

Alternatively, install via WinGet:

```powershell
winget install LibreHardwareMonitor.LibreHardwareMonitor
```

## Configure Web Server
---

1. Open LibreHardwareMonitor
2. **Options** > **Remote Web Server** > **Run** (enable checkbox)
3. **Options** > **Remote Web Server** > **Port**: `8085`
4. **Options** > **Remote Web Server** > **IP**: Select your LAN IP

Avoid selecting Hyper-V virtual switch IPs (172.x.x.x range). Choose your physical NIC IP.

## Configure Startup Behaviour
---

1. **Options** > **Run On Windows Startup** (if available)
2. **Options** > **Start Minimized**
3. **Options** > **Minimize To Tray**
4. **Options** > **Minimize On Close**

## Verify Web Server
---

```powershell
Test-NetConnection -ComputerName localhost -Port 8085
```

Browser test:

```powershell
http://localhost:8085/
```

## Watchdog Task
---

Creates a scheduled task that checks every 5 minutes and restarts LHM if not running.

### Option A: Interactive Mode (Recommended)
---

Runs in your desktop session with visible tray icon. Use this if you need to access LHM settings or view the GUI.

```powershell
$LHMPath = "C:\LibreHardwareMonitor"

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -Command `"if (-not (Get-Process -Name 'LibreHardwareMonitor' -ErrorAction SilentlyContinue)) { Start-Process '$LHMPath\LibreHardwareMonitor.exe' -WorkingDirectory '$LHMPath' }`""

$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 5) -RepetitionDuration (New-TimeSpan -Days 9999)

$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest

$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 1)

Register-ScheduledTask -TaskName "LibreHardwareMonitor-Watchdog" -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description "Restarts LHM if not running (interactive)" -Force
```

### Option B: Background Mode (Headless)
---

Runs as SYSTEM in session 0. No tray icon visible. Use for servers or headless monitoring where GUI access is not required.

```powershell
$LHMPath = "C:\LibreHardwareMonitor"

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -Command `"if (-not (Get-Process -Name 'LibreHardwareMonitor' -ErrorAction SilentlyContinue)) { Start-Process '$LHMPath\LibreHardwareMonitor.exe' -WorkingDirectory '$LHMPath' }`""

$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 5) -RepetitionDuration (New-TimeSpan -Days 9999)

$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 1)

Register-ScheduledTask -TaskName "LibreHardwareMonitor-Watchdog" -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description "Restarts LHM if not running (background)" -Force
```

### Start Watchdog Immediately
---

```powershell
Start-ScheduledTask -TaskName "LibreHardwareMonitor-Watchdog"
```

### Test Watchdog
---

```powershell
# Stop LHM
Stop-Process -Name "LibreHardwareMonitor" -Force -ErrorAction SilentlyContinue

# Trigger watchdog
Start-ScheduledTask -TaskName "LibreHardwareMonitor-Watchdog"

# LHM should restart (check tray for Option A, or process list for Option B)
Get-Process -Name "LibreHardwareMonitor"
```

### Verify Watchdog
---

```powershell
Get-ScheduledTask -TaskName "LibreHardwareMonitor-Watchdog" | Select-Object TaskName, State
```

### Remove Watchdog
---

```powershell
Unregister-ScheduledTask -TaskName "LibreHardwareMonitor-Watchdog" -Confirm:$false
```

## Persistent Settings
---

Settings are stored in `LibreHardwareMonitor.config` in the application folder.

### Lock Settings (Read-Only)
---

Prevents accidental changes after configuration is complete:

```powershell
Set-ItemProperty -Path "C:\LibreHardwareMonitor\LibreHardwareMonitor.config" -Name IsReadOnly -Value $true
```

### Unlock Settings
---

Required before making changes:

```powershell
Set-ItemProperty -Path "C:\LibreHardwareMonitor\LibreHardwareMonitor.config" -Name IsReadOnly -Value $false
```

### Backup Settings
---

```powershell
Copy-Item "C:\LibreHardwareMonitor\LibreHardwareMonitor.config" "C:\LibreHardwareMonitor\LibreHardwareMonitor.config.bak"
```

### Restore Settings
---

```powershell
Copy-Item "C:\LibreHardwareMonitor\LibreHardwareMonitor.config.bak" "C:\LibreHardwareMonitor\LibreHardwareMonitor.config" -Force
```

## Verification Commands
---

Check LHM process:

```powershell
Get-Process -Name "LibreHardwareMonitor" -ErrorAction SilentlyContinue
```

Check web server port:

```powershell
Get-NetTCPConnection -LocalPort 8085 -State Listen -ErrorAction SilentlyContinue
```

Check which IP the web server is bound to:

```powershell
Get-NetTCPConnection -LocalPort 8085 -State Listen | Select-Object LocalAddress, LocalPort
```

## Troubleshooting
---

### Web Server Not Responding
---

1. Verify LHM is running: `Get-Process -Name "LibreHardwareMonitor"`
2. Check port binding: `Get-NetTCPConnection -LocalPort 8085 -State Listen`
3. Confirm correct IP selected in Options > Remote Web Server > IP
4. Restart LHM after changing web server settings

### Bound to Wrong IP
---

If bound to Hyper-V IP (172.x.x.x):

1. Options > Remote Web Server > IP > Select correct LAN IP
2. Uncheck then re-check Run to restart web server

### Settings Not Persisting
---

1. Close LHM properly via tray icon > Exit (not Task Manager kill)
2. Check config file exists: `Test-Path "C:\LibreHardwareMonitor\LibreHardwareMonitor.config"`
3. Check file is not read-only when trying to save

### Watchdog Not Starting LHM
---

1. Verify path is correct in task
2. Check task is running with correct principal (SYSTEM for background, username for interactive)
3. View task history in Task Scheduler for errors

### LHM Running But No Tray Icon
---

This occurs when using Background Mode (Option B). The process runs in session 0 (SYSTEM) which is isolated from your desktop. Switch to Interactive Mode (Option A) if you need tray access.

## Directory Structure
---

```powershell
C:\LibreHardwareMonitor\
├── LibreHardwareMonitor.exe
├── LibreHardwareMonitor.config
├── LibreHardwareMonitorLib.dll
└── [other DLLs]
```

## Integration with Caddy Proxy
---

After configuring LHM, use the Caddy proxy script for secure Tailscale access:

```powershell
.\Setup-CaddyProxy.ps1 -Action Install -UpstreamIP 127.0.0.1 -Force
```

Access via Tailscale:

```powershell
https://<tailscale-ip>:8086/
```

## References
---

- LibreHardwareMonitor GitHub: https://github.com/LibreHardwareMonitor/LibreHardwareMonitor
- LibreHardwareMonitor Releases: https://github.com/LibreHardwareMonitor/LibreHardwareMonitor/releases
- Scheduled Tasks: https://learn.microsoft.com/en-us/powershell/module/scheduledtasks/register-scheduledtask
- WinGet: https://learn.microsoft.com/en-us/windows/package-manager/winget/


## Menu Options
---

The interactive menu provides comprehensive management:

| Key | Option | Description |
|-----|--------|-------------|
| 1 | Install Caddy Proxy | Full installation with auth and firewall prompts |
| 2 | Uninstall Caddy | Remove service, files, firewall rules |
| 3 | Test Installation | Verify all components |
| 4 | Restart Caddy Service | Restart after config changes |
| 5 | View Caddyfile | Display current configuration |
| 6 | Edit Caddyfile | Open in Notepad |
| 7 | LHM Setup Instructions | Display setup guide |
| 8 | Open Install Folder | Open C:\Caddy in Explorer |
| A | Authentication Settings | Manage auth credentials |
| F | Firewall Settings | Manage firewall rules |
| S | Scan/Select Upstream IP | Find LHM on local interfaces |
| Q | Quit | Exit menu |

## File Structure
---

```powershell
C:\Caddy\
├── caddy.exe        # Caddy binary
├── Caddyfile        # Proxy configuration
├── auth.json        # Authentication config (restricted ACL)
├── firewall.json    # Firewall scope config
├── data\            # Caddy data directory
└── logs\            # Log files
```

## Troubleshooting
---

### Common Issues
---

| Symptom | HTTP Code | Cause | Resolution |
|---------|-----------|-------|------------|
| Connection Refused | N/A | Firewall or service not running | Check `Get-Service Caddy` and firewall rules |
| Bad Gateway | 502 | Upstream unreachable | Verify LHM is running on correct IP/port |
| Certificate Error | N/A | Self-signed certificate | Accept warning or install root CA |
| 401 Unauthorized | 401 | Wrong credentials | Check username/password or reset via menu |
| Blank Page | 200 | JavaScript/header mismatch | Update LibreHardwareMonitor |

### Diagnostic Commands
---

Check if Caddy is listening:

```powershell
netstat -ano | findstr ":8086"
```

View Caddy process:

```powershell
Get-Process -Name caddy -ErrorAction SilentlyContinue | Format-Table Id, ProcessName, Path
```

Test upstream connectivity:

```powershell
Invoke-RestMethod -Uri "http://10.1.10.30:8085/data.json" | ConvertTo-Json -Depth 3
```

Check firewall rules:

```powershell
Get-NetFirewallRule -DisplayName "Caddy*" | Select-Object DisplayName, Enabled, Direction, Action
```

Verify authentication config:

```powershell
Get-Content C:\Caddy\Caddyfile | Select-String "basicauth" -Context 0,3
```

## Updating Caddy
---

Caddy is distributed as a static binary, making updates straightforward:

```powershell
Stop-Service Caddy
Invoke-WebRequest -Uri "https://caddyserver.com/api/download?os=windows&arch=amd64" -OutFile "C:\Caddy\caddy.exe"
Start-Service Caddy
```

## Uninstallation
---

```powershell
# Stop and remove service
Stop-Service Caddy -ErrorAction SilentlyContinue
sc.exe delete Caddy

# Remove firewall rules
Remove-NetFirewallRule -DisplayName "Caddy Reverse Proxy*"

# Remove files
Remove-Item -Path "C:\Caddy" -Recurse -Force
```

Or use the script:

```powershell
.\Setup-CaddyProxy.ps1 -Action Uninstall -Force
```

## Security Considerations
---

### Why Tailscale-Only Binding?
---

By binding Caddy exclusively to the Tailscale IP (`100.0.0.0`), the service is inaccessible from:
- The local LAN (unless devices are on Tailscale)
- The public internet (Tailscale IPs are not routable)
- Port scanners (Shodan, Censys)

### Why Scope-Based Firewall Rules?
---

The script creates port-based rules with address filtering rather than program-based rules:

| Approach | Pros | Cons |
|----------|------|------|
| Program-based | Simple, follows executable | Allows all connections if program runs |
| Port + Address | Granular control, explicit allow list | Requires address management |

For Tailscale-only deployments, restricting to `100.64.0.0/10` ensures only Tailnet devices can connect, even if the firewall rule is accidentally modified.

### Internal TLS Rationale
---

While Tailscale already encrypts traffic using WireGuard, adding application-layer TLS provides:
- End-to-end encryption where the private key is held by Caddy
- Protection against potential malicious actors within the tailnet
- Defence in depth if the VPN tunnel is somehow compromised

### Authentication Rationale
---

HTTP Basic Authentication adds a credential layer that:
- Prevents unauthorized access even if someone gains Tailnet access
- Provides audit capability (who authenticated)
- Allows different credentials per deployment
- Uses bcrypt hashing (computationally expensive to brute force)

### Recommended Configuration
---

For maximum security, combine all layers:

```powershell
.\Setup-CaddyProxy.ps1 -Action Install -EnableAuth -FirewallScope TailscaleOnly
```

This provides:
1. Firewall blocks all non-Tailscale traffic (100.64.0.0/10 only)
2. Tailscale provides authenticated mesh network access
3. TLS encrypts all traffic
4. basicauth requires username/password

### Alternative: Tailscale HTTPS Certificates
---

Caddy can use Tailscale's built-in certificate provisioning:

```caddy
100.0.0.0:8086 {
    basicauth {
        admin $2a$14$hashedpassword...
    }
    reverse_proxy 10.1.10.30:8085
    tls {
        get_certificate tailscale
    }
}
```

This provides valid Let's Encrypt certificates with no browser warnings, but requires additional Tailscale socket permissions on Windows.

## Full Script
---

Presented using CodeMirror for a more complete visualization, this was an off the cuff project that I had an idea to a while ago but never followed through with. I have always felt that HW Info is limited when it comes to remote HW telemetry even though it is a truly excellent piece of software.

This is a simple & secure solution to remotely monitor your PC / Server hardware details. The requirements are Tailscale and Caddy, with optional HTTP Basic Authentication and granular firewall controls.

{{< codemirror lang="powershell" >}}
<#
.SYNOPSIS
    Caddy reverse proxy setup for LibreHardwareMonitor via Tailscale with optional authentication.

.DESCRIPTION
    Installs and configures Caddy as a reverse proxy for LibreHardwareMonitor,
    binding to your Tailscale IP for secure remote access. Supports HTTP Basic
    Authentication using Caddy's built-in bcrypt password hashing.
    
    Prerequisites:
    - Tailscale installed and connected
    - LibreHardwareMonitor installed with web server enabled
    
    LibreHardwareMonitor Setup:
    1. Download from: https://github.com/LibreHardwareMonitor/LibreHardwareMonitor/releases
    2. Extract and run LibreHardwareMonitor.exe
    3. Options > Remote Web Server > Run (enable)
    4. Options > Remote Web Server > Port: 8085
    5. Options > Remote Web Server > IP: Select your LAN IP (not Hyper-V)

.PARAMETER Action
    Install, Uninstall, Status, Test, or Menu

.PARAMETER InstallPath
    Caddy installation directory (default: C:\Caddy)

.PARAMETER ProxyPort
    Port for Caddy to listen on (default: 8086)

.PARAMETER UpstreamPort
    LibreHardwareMonitor port (default: 8085)

.PARAMETER UpstreamIP
    LibreHardwareMonitor IP (default: 127.0.0.1)

.PARAMETER TailscaleIP
    Tailscale IP to bind to (default: auto-detect)

.PARAMETER EnableAuth
    Enable HTTP Basic Authentication

.PARAMETER AuthUsername
    Username for basic auth (default: admin)

.PARAMETER FirewallScope
    Firewall rule scope: TailscaleOnly, LAN, or Any (default: TailscaleOnly)

.PARAMETER AllowedAddresses
    Comma-separated list of allowed addresses/subnets for LAN scope

.PARAMETER Force
    Skip confirmation prompts

.EXAMPLE
    .\Setup-CaddyProxy.ps1
    Interactive menu

.EXAMPLE
    .\Setup-CaddyProxy.ps1 -Action Install -Force
    Automated installation with defaults (no auth, Tailscale-only firewall)

.EXAMPLE
    .\Setup-CaddyProxy.ps1 -Action Install -EnableAuth -AuthUsername "monitor"
    Install with authentication enabled (prompts for password)

.EXAMPLE
    .\Setup-CaddyProxy.ps1 -Action Install -FirewallScope LAN -AllowedAddresses "10.1.10.0/24"
    Install with LAN access restricted to specified subnet

.EXAMPLE
    .\Setup-CaddyProxy.ps1 -Action Install -FirewallScope LAN -AllowedAddresses "10.1.10.10,10.1.10.30"
    Install with LAN access restricted to specific hosts

.NOTES
    Author: Andrew Jones
    Version: 5.0
    Date: 2026-02-05
    
    Authentication: Uses Caddy's built-in HTTP Basic Auth with bcrypt hashing
    LibreHardwareMonitor: https://github.com/LibreHardwareMonitor/LibreHardwareMonitor
    Caddy basicauth: https://caddyserver.com/docs/caddyfile/directives/basicauth
#>

#Requires -RunAsAdministrator
#Requires -Version 5.1

[CmdletBinding()]
param (
    [Parameter(Position = 0)]
    [ValidateSet("Install", "Uninstall", "Status", "Test", "Menu")]
    [string]$Action = "Menu",

    [Parameter()]
    [string]$InstallPath = "C:\Caddy",

    [Parameter()]
    [int]$ProxyPort = 8086,

    [Parameter()]
    [int]$UpstreamPort = 8085,

    [Parameter()]
    [string]$UpstreamIP = "127.0.0.1",

    [Parameter()]
    [string]$TailscaleIP,

    [Parameter()]
    [switch]$EnableAuth,

    [Parameter()]
    [string]$AuthUsername = "admin",

    [Parameter()]
    [ValidateSet("TailscaleOnly", "LAN", "Any")]
    [string]$FirewallScope = "TailscaleOnly",

    [Parameter()]
    [string]$AllowedAddresses,

    [Parameter()]
    [switch]$Force
)

# ============================================================================
# CONFIGURATION
# ============================================================================

$Script:Config = @{
    CaddyDownloadUrl   = "https://caddyserver.com/api/download?os=windows&arch=amd64"
    CaddyExe           = "caddy.exe"
    CaddyFile          = "Caddyfile"
    AuthFile           = "auth.json"
    FirewallFile       = "firewall.json"
    ServiceName        = "Caddy"
    FirewallRuleBase   = "Caddy Reverse Proxy"
    TailscaleRange     = "100.64.0.0/10"
    LHMGitHub          = "https://github.com/LibreHardwareMonitor/LibreHardwareMonitor"
    LHMReleases        = "https://github.com/LibreHardwareMonitor/LibreHardwareMonitor/releases"
}

# Script-scope auth settings
$Script:AuthEnabled = $EnableAuth
$Script:AuthUser = $AuthUsername
$Script:AuthHash = $null

# Script-scope firewall settings
$Script:FWScope = $FirewallScope
$Script:FWAllowedAddresses = $AllowedAddresses

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
    $prefix = switch ($Level) {
        "HEADER"  { "`n=== " }
        "SUCCESS" { "[+] " }
        "ERROR"   { "[-] " }
        "WARNING" { "[!] " }
        default   { "[*] " }
    }
    $suffix = if ($Level -eq "HEADER") { " ===" } else { "" }
    Write-Host "$prefix$Message$suffix" -ForegroundColor $colors[$Level]
}

function Test-TailscaleInstalled {
    $tailscale = Get-Command tailscale -ErrorAction SilentlyContinue
    return $null -ne $tailscale
}

function Get-TailscaleIP {
    if (-not (Test-TailscaleInstalled)) { return $null }
    try {
        $ip = & tailscale ip -4 2>$null
        if ($ip -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$') {
            return $ip.Trim()
        }
    }
    catch { return $null }
    return $null
}

function Test-PortOpen {
    param (
        [string]$ComputerName,
        [int]$Port
    )
    try {
        $result = Test-NetConnection -ComputerName $ComputerName -Port $Port -WarningAction SilentlyContinue -InformationLevel Quiet
        return $result
    }
    catch { 
        return $false 
    }
}

function Confirm-Action {
    param ([string]$Message)
    if ($Force) { return $true }
    $response = Read-Host "$Message (Y/N)"
    return $response -match '^[Yy]'
}

# ============================================================================
# FIREWALL FUNCTIONS
# ============================================================================

function Get-FirewallRules {
    $rules = Get-NetFirewallRule -DisplayName "$($Script:Config.FirewallRuleBase)*" -ErrorAction SilentlyContinue
    return $rules
}

function Show-FirewallStatus {
    $rules = Get-FirewallRules
    
    if (-not $rules) {
        Write-Host "  No Caddy firewall rules found" -ForegroundColor Yellow
        return
    }
    
    foreach ($rule in $rules) {
        $portFilter = Get-NetFirewallPortFilter -AssociatedNetFirewallRule $rule
        $addressFilter = Get-NetFirewallAddressFilter -AssociatedNetFirewallRule $rule
        
        Write-Host ""
        Write-Host "  Rule: " -NoNewline
        Write-Host $rule.DisplayName -ForegroundColor Cyan
        Write-Host "  Status: " -NoNewline
        if ($rule.Enabled -eq "True") {
            Write-Host "Enabled" -ForegroundColor Green
        }
        else {
            Write-Host "Disabled" -ForegroundColor Red
        }
        Write-Host "  Direction: " -NoNewline
        Write-Host $rule.Direction -ForegroundColor White
        Write-Host "  Action: " -NoNewline
        Write-Host $rule.Action -ForegroundColor White
        Write-Host "  Protocol: " -NoNewline
        Write-Host $portFilter.Protocol -ForegroundColor White
        Write-Host "  Port: " -NoNewline
        Write-Host $portFilter.LocalPort -ForegroundColor White
        Write-Host "  Remote Addresses: " -NoNewline
        Write-Host $addressFilter.RemoteAddress -ForegroundColor White
        Write-Host "  Profile: " -NoNewline
        Write-Host $rule.Profile -ForegroundColor White
    }
}

function Set-FirewallRule {
    param (
        [ValidateSet("TailscaleOnly", "LAN", "Any")]
        [string]$Scope = "TailscaleOnly",
        
        [string]$Addresses
    )
    
    Write-Log "Configuring firewall rule (Scope: $Scope)..." "INFO"
    
    Remove-FirewallRules -Silent
    
    $ruleName = $Script:Config.FirewallRuleBase
    $ruleParams = @{
        DisplayName = $ruleName
        Direction   = "Inbound"
        Protocol    = "TCP"
        LocalPort   = $ProxyPort
        Action      = "Allow"
        Enabled     = "True"
    }
    
    switch ($Scope) {
        "TailscaleOnly" {
            $ruleParams.DisplayName = "$ruleName (Tailscale Only)"
            $ruleParams.RemoteAddress = $Script:Config.TailscaleRange
            $ruleParams.Profile = "Any"
            $ruleParams.Description = "Allow Caddy reverse proxy - Tailscale CGNAT range only (100.64.0.0/10)"
        }
        "LAN" {
            if ([string]::IsNullOrWhiteSpace($Addresses)) {
                Write-Log "LAN scope requires addresses to be specified" "ERROR"
                return $false
            }
            $ruleParams.DisplayName = "$ruleName (LAN Restricted)"
            $ruleParams.RemoteAddress = $Addresses -split ',' | ForEach-Object { $_.Trim() }
            $ruleParams.Profile = "Private,Domain"
            $ruleParams.Description = "Allow Caddy reverse proxy - Restricted to: $Addresses"
        }
        "Any" {
            $ruleParams.DisplayName = "$ruleName (Any)"
            $ruleParams.Profile = "Any"
            $ruleParams.Description = "Allow Caddy reverse proxy - All addresses (least secure)"
        }
    }
    
    try {
        New-NetFirewallRule @ruleParams | Out-Null
        Write-Log "Firewall rule created: $($ruleParams.DisplayName)" "SUCCESS"
        Save-FirewallConfig -Scope $Scope -Addresses $Addresses
        return $true
    }
    catch {
        Write-Log "Failed to create firewall rule: $_" "ERROR"
        return $false
    }
}

function Remove-FirewallRules {
    param ([switch]$Silent)
    
    $rules = Get-FirewallRules
    
    if ($rules) {
        foreach ($rule in $rules) {
            Remove-NetFirewallRule -DisplayName $rule.DisplayName -ErrorAction SilentlyContinue
            if (-not $Silent) {
                Write-Log "Removed rule: $($rule.DisplayName)" "SUCCESS"
            }
        }
        
        $fwConfigPath = Join-Path $InstallPath $Script:Config.FirewallFile
        if (Test-Path $fwConfigPath) {
            Remove-Item $fwConfigPath -Force -ErrorAction SilentlyContinue
        }
        return $true
    }
    else {
        if (-not $Silent) {
            Write-Log "No Caddy firewall rules found" "INFO"
        }
        return $false
    }
}

function Save-FirewallConfig {
    param (
        [string]$Scope,
        [string]$Addresses
    )
    
    $fwConfigPath = Join-Path $InstallPath $Script:Config.FirewallFile
    
    $fwConfig = @{
        Scope     = $Scope
        Addresses = $Addresses
        Port      = $ProxyPort
        Updated   = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    }
    
    try {
        $fwConfig | ConvertTo-Json | Out-File -FilePath $fwConfigPath -Encoding UTF8 -Force
        return $true
    }
    catch {
        Write-Log "Failed to save firewall config: $_" "WARNING"
        return $false
    }
}

function Read-FirewallConfig {
    $fwConfigPath = Join-Path $InstallPath $Script:Config.FirewallFile
    
    if (Test-Path $fwConfigPath) {
        try {
            $fwConfig = Get-Content $fwConfigPath -Raw | ConvertFrom-Json
            $Script:FWScope = $fwConfig.Scope
            $Script:FWAllowedAddresses = $fwConfig.Addresses
            return $true
        }
        catch {
            return $false
        }
    }
    return $false
}

function Show-FirewallMenu {
    while ($true) {
        Clear-Host
        Write-Host ""
        Write-Host "  ╔═══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "  ║          Firewall Rule Management                     ║" -ForegroundColor Cyan
        Write-Host "  ╚═══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
        
        Show-FirewallStatus
        
        Write-Host ""
        Write-Host "  ─────────────────────────────────────────────────────────" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "  [1] Tailscale Only (100.64.0.0/10) - Recommended"
        Write-Host "  [2] LAN Restricted (specify addresses)"
        Write-Host "  [3] Any (all addresses) - Least secure"
        Write-Host "  [4] Remove All Caddy Rules"
        Write-Host "  [5] Refresh Status"
        Write-Host "  [B] Back to Main Menu"
        Write-Host ""
        
        $choice = Read-Host "  Select option"
        
        switch ($choice.ToUpper()) {
            "1" {
                Set-FirewallRule -Scope "TailscaleOnly"
                Read-Host "`n  Press Enter to continue"
            }
            "2" {
                Write-Host ""
                Write-Host "  Enter allowed addresses (comma-separated)" -ForegroundColor Cyan
                Write-Host "  Examples:" -ForegroundColor Gray
                Write-Host "    Single IP:    10.1.10.10" -ForegroundColor Gray
                Write-Host "    Multiple IPs: 10.1.10.10,10.1.10.30" -ForegroundColor Gray
                Write-Host "    Subnet:       10.1.10.0/24" -ForegroundColor Gray
                Write-Host "    Mixed:        10.1.10.10,192.168.1.0/24" -ForegroundColor Gray
                Write-Host ""
                
                $addresses = Read-Host "  Addresses"
                
                if ([string]::IsNullOrWhiteSpace($addresses)) {
                    Write-Log "No addresses specified" "WARNING"
                }
                else {
                    Set-FirewallRule -Scope "LAN" -Addresses $addresses
                }
                Read-Host "`n  Press Enter to continue"
            }
            "3" {
                Write-Host ""
                Write-Log "Warning: This allows connections from any IP address" "WARNING"
                if (Confirm-Action "  Create unrestricted firewall rule?") {
                    Set-FirewallRule -Scope "Any"
                }
                Read-Host "`n  Press Enter to continue"
            }
            "4" {
                if (Confirm-Action "  Remove all Caddy firewall rules?") {
                    Remove-FirewallRules
                }
                Read-Host "`n  Press Enter to continue"
            }
            "5" { }
            "B" { return }
        }
    }
}

# ============================================================================
# AUTHENTICATION FUNCTIONS
# ============================================================================

function Get-CaddyPasswordHash {
    param (
        [Parameter(Mandatory)]
        [SecureString]$Password
    )
    
    $exePath = Join-Path $InstallPath $Script:Config.CaddyExe
    
    if (-not (Test-Path $exePath)) {
        Write-Log "Caddy not installed. Install Caddy first." "ERROR"
        return $null
    }
    
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
    $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
    
    try {
        $hash = $plainPassword | & $exePath hash-password 2>$null
        
        if ($hash -and $hash -match '^\$2[aby]?\$') {
            return $hash.Trim()
        }
        else {
            Write-Log "Failed to generate password hash" "ERROR"
            return $null
        }
    }
    catch {
        Write-Log "Error generating hash: $_" "ERROR"
        return $null
    }
    finally {
        $plainPassword = $null
        [System.GC]::Collect()
    }
}

function Request-AuthCredentials {
    Write-Host ""
    Write-Host "  ╔═══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║           Authentication Setup                        ║" -ForegroundColor Cyan
    Write-Host "  ╚═══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    $defaultUser = $Script:AuthUser
    $inputUser = Read-Host "  Username [$defaultUser]"
    if ([string]::IsNullOrWhiteSpace($inputUser)) {
        $Script:AuthUser = $defaultUser
    }
    else {
        $Script:AuthUser = $inputUser.Trim()
    }
    
    $passwordMatch = $false
    $attempts = 0
    
    while (-not $passwordMatch -and $attempts -lt 3) {
        Write-Host ""
        $password1 = Read-Host "  Password" -AsSecureString
        $password2 = Read-Host "  Confirm Password" -AsSecureString
        
        $BSTR1 = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password1)
        $BSTR2 = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password2)
        $plain1 = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR1)
        $plain2 = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR2)
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR1)
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR2)
        
        if ($plain1 -eq $plain2) {
            if ($plain1.Length -lt 8) {
                Write-Log "Password must be at least 8 characters" "WARNING"
                $attempts++
            }
            else {
                $passwordMatch = $true
                Write-Host ""
                Write-Log "Generating password hash..." "INFO"
                $Script:AuthHash = Get-CaddyPasswordHash -Password $password1
                
                if ($Script:AuthHash) {
                    Write-Log "Password hash generated" "SUCCESS"
                    $Script:AuthEnabled = $true
                    return $true
                }
                else {
                    return $false
                }
            }
        }
        else {
            Write-Log "Passwords do not match" "WARNING"
            $attempts++
        }
        
        $plain1 = $null
        $plain2 = $null
        [System.GC]::Collect()
    }
    
    if (-not $passwordMatch) {
        Write-Log "Too many failed attempts" "ERROR"
        return $false
    }
    return $false
}

function Save-AuthConfig {
    $authPath = Join-Path $InstallPath $Script:Config.AuthFile
    
    $authConfig = @{
        Enabled  = $Script:AuthEnabled
        Username = $Script:AuthUser
        Hash     = $Script:AuthHash
        Updated  = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    }
    
    try {
        $authConfig | ConvertTo-Json | Out-File -FilePath $authPath -Encoding UTF8 -Force
        
        $acl = Get-Acl $authPath
        $acl.SetAccessRuleProtection($true, $false)
        $adminRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            "BUILTIN\Administrators", "FullControl", "Allow"
        )
        $systemRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            "NT AUTHORITY\SYSTEM", "FullControl", "Allow"
        )
        $acl.SetAccessRule($adminRule)
        $acl.SetAccessRule($systemRule)
        Set-Acl -Path $authPath -AclObject $acl
        
        Write-Log "Auth config saved: $authPath" "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Failed to save auth config: $_" "ERROR"
        return $false
    }
}

function Read-AuthConfig {
    $authPath = Join-Path $InstallPath $Script:Config.AuthFile
    
    if (Test-Path $authPath) {
        try {
            $authConfig = Get-Content $authPath -Raw | ConvertFrom-Json
            $Script:AuthEnabled = $authConfig.Enabled
            $Script:AuthUser = $authConfig.Username
            $Script:AuthHash = $authConfig.Hash
            return $true
        }
        catch {
            Write-Log "Failed to read auth config: $_" "WARNING"
            return $false
        }
    }
    return $false
}

function Remove-AuthConfig {
    $Script:AuthEnabled = $false
    $Script:AuthUser = "admin"
    $Script:AuthHash = $null
    
    $authPath = Join-Path $InstallPath $Script:Config.AuthFile
    if (Test-Path $authPath) {
        Remove-Item $authPath -Force -ErrorAction SilentlyContinue
    }
    
    New-Caddyfile
    
    $service = Get-Service -Name $Script:Config.ServiceName -ErrorAction SilentlyContinue
    if ($service -and $service.Status -eq "Running") {
        Restart-Service -Name $Script:Config.ServiceName -Force
        Write-Log "Authentication disabled and service restarted" "SUCCESS"
    }
    else {
        Write-Log "Authentication disabled" "SUCCESS"
    }
}

# ============================================================================
# CADDY FUNCTIONS
# ============================================================================

function Install-Caddy {
    Write-Log "Installing Caddy..." "HEADER"
    
    if (-not (Test-Path $InstallPath)) {
        New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
        Write-Log "Created directory: $InstallPath" "SUCCESS"
    }
    
    @("data", "logs") | ForEach-Object {
        $subDir = Join-Path $InstallPath $_
        if (-not (Test-Path $subDir)) {
            New-Item -ItemType Directory -Path $subDir -Force | Out-Null
        }
    }
    
    $exePath = Join-Path $InstallPath $Script:Config.CaddyExe
    Write-Log "Downloading Caddy..." "INFO"
    try {
        Invoke-WebRequest -Uri $Script:Config.CaddyDownloadUrl -OutFile $exePath -UseBasicParsing
        Write-Log "Download complete" "SUCCESS"
    }
    catch {
        Write-Log "Download failed: $_" "ERROR"
        return $false
    }
    
    $version = & $exePath version 2>$null
    if ($version) {
        Write-Log "Caddy version: $version" "SUCCESS"
    }
    else {
        Write-Log "Could not verify Caddy" "ERROR"
        return $false
    }
    
    return $true
}

function New-Caddyfile {
    Write-Log "Creating Caddyfile..." "HEADER"
    
    $caddyfilePath = Join-Path $InstallPath $Script:Config.CaddyFile
    
    $authBlock = ""
    if ($Script:AuthEnabled -and $Script:AuthHash) {
        $authBlock = @"

    # HTTP Basic Authentication
    basicauth {
        $($Script:AuthUser) $($Script:AuthHash)
    }
"@
    }
    
    $authStatus = if ($Script:AuthEnabled) { "Enabled (User: $($Script:AuthUser))" } else { "Disabled" }
    
    $caddyfileContent = @"
# Caddy Reverse Proxy for LibreHardwareMonitor
# Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
# Tailscale IP: $($Script:TailscaleIP)
# Upstream: $($UpstreamIP):$($UpstreamPort)
# Authentication: $authStatus

$($Script:TailscaleIP):$ProxyPort {$authBlock
    reverse_proxy $($UpstreamIP):$($UpstreamPort)
    tls internal
}
"@
    
    try {
        $caddyfileContent | Out-File -FilePath $caddyfilePath -Encoding UTF8 -Force
        Write-Log "Created Caddyfile: $caddyfilePath" "SUCCESS"
        
        Write-Host "`n--- Caddyfile Contents ---" -ForegroundColor DarkGray
        Get-Content $caddyfilePath | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
        Write-Host "--- End Caddyfile ---`n" -ForegroundColor DarkGray
        
        return $true
    }
    catch {
        Write-Log "Failed to create Caddyfile: $_" "ERROR"
        return $false
    }
}

function Install-CaddyService {
    Write-Log "Installing Caddy service..." "HEADER"
    
    $exePath = Join-Path $InstallPath $Script:Config.CaddyExe
    $configPath = Join-Path $InstallPath $Script:Config.CaddyFile
    $serviceName = $Script:Config.ServiceName
    
    $existingService = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    if ($existingService) {
        Write-Log "Removing existing service..." "INFO"
        Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
        & sc.exe delete $serviceName 2>$null | Out-Null
        Start-Sleep -Seconds 2
    }
    
    $binPath = "`"$exePath`" run --config `"$configPath`""
    
    $result = & sc.exe create $serviceName start= auto binPath= $binPath 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Failed to create service: $result" "ERROR"
        return $false
    }
    Write-Log "Created service: $serviceName" "SUCCESS"
    
    & sc.exe failure $serviceName reset= 86400 actions= restart/60000/restart/60000/restart/60000 2>$null | Out-Null
    & sc.exe description $serviceName "Caddy reverse proxy for LibreHardwareMonitor via Tailscale" 2>$null | Out-Null
    Write-Log "Configured auto-restart on failure" "SUCCESS"
    
    Write-Log "Starting service..." "INFO"
    try {
        Start-Service -Name $serviceName -ErrorAction Stop
        Start-Sleep -Seconds 2
        $service = Get-Service -Name $serviceName
        if ($service.Status -eq "Running") {
            Write-Log "Service started" "SUCCESS"
            return $true
        }
        else {
            Write-Log "Service status: $($service.Status)" "WARNING"
            return $false
        }
    }
    catch {
        Write-Log "Failed to start service: $_" "ERROR"
        return $false
    }
}

# ============================================================================
# WORKFLOW FUNCTIONS
# ============================================================================

function Select-UpstreamIP {
    Clear-Host
    Write-Host "`n  ╔═══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║           LHM Upstream IP Scanner                     ║" -ForegroundColor Cyan
    Write-Host "  ╚═══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Scanning local interfaces for Port $UpstreamPort..." -ForegroundColor Gray
    Write-Host ""

    $ipList = @("127.0.0.1")
    try {
        $adapters = Get-NetIPAddress -AddressFamily IPv4 -AddressState Preferred | Where-Object { $_.InterfaceAlias -notlike "*Loopback*" }
        $ipList += $adapters.IPAddress
    }
    catch {
        Write-Log "Could not enumerate network adapters." "WARNING"
    }

    $validOptions = @()
    for ($i = 0; $i -lt $ipList.Count; $i++) {
        $currentIP = $ipList[$i]
        $isResponsive = Test-PortOpen -ComputerName $currentIP -Port $UpstreamPort
        
        $indexTag = "  [$($i+1)]".PadRight(7)
        $ipTag = "$currentIP".PadRight(18)
        
        if ($isResponsive) { 
            Write-Host "$indexTag$ipTag" -NoNewline -ForegroundColor White
            Write-Host " [FOUND LHM!] " -ForegroundColor Green
            $validOptions += $currentIP
        }
        else {
            Write-Host "$indexTag$ipTag" -NoNewline -ForegroundColor Gray
            Write-Host " [No Response] " -ForegroundColor DarkGray
        }
    }

    Write-Host ""
    if ($validOptions.Count -gt 0) {
        Write-Host "  LHM was detected on $($validOptions.Count) interface(s)." -ForegroundColor Green
    }
    else {
        Write-Host "  LHM was not detected on any interface." -ForegroundColor Red
        Write-Host "  Ensure LHM is running and the Web Server is enabled." -ForegroundColor Yellow
    }

    $choice = Read-Host "  Select IP number to use [1-$($ipList.Count)] or Enter to cancel"

    if ($choice -match '^\d+$' -and $choice -ge 1 -and $choice -le $ipList.Count) {
        $selected = $ipList[$choice - 1]
        $Script:UpstreamIP = $selected
        Write-Host ""
        Write-Log "Upstream IP updated to: $selected" "SUCCESS"
        Start-Sleep -Seconds 2
    }
}

function Select-FirewallScope {
    Write-Host ""
    Write-Host "  ╔═══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║           Firewall Scope Selection                    ║" -ForegroundColor Cyan
    Write-Host "  ╚═══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  [1] Tailscale Only (100.64.0.0/10)" -ForegroundColor Green
    Write-Host "      Recommended - Only Tailscale devices can connect" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [2] LAN Restricted (specify addresses)"
    Write-Host "      Allow specific IPs or subnets" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [3] Any (all addresses)" -ForegroundColor Yellow
    Write-Host "      Least secure - allows all connections" -ForegroundColor Gray
    Write-Host ""
    
    $choice = Read-Host "  Select scope [1]"
    
    switch ($choice) {
        "2" {
            Write-Host ""
            Write-Host "  Enter allowed addresses (comma-separated)" -ForegroundColor Cyan
            Write-Host "  Example: 10.1.10.0/24 or 10.1.10.10,10.1.10.30" -ForegroundColor Gray
            $addresses = Read-Host "  Addresses"
            
            if ([string]::IsNullOrWhiteSpace($addresses)) {
                Write-Log "No addresses specified, defaulting to Tailscale Only" "WARNING"
                $Script:FWScope = "TailscaleOnly"
                $Script:FWAllowedAddresses = $null
            }
            else {
                $Script:FWScope = "LAN"
                $Script:FWAllowedAddresses = $addresses
            }
        }
        "3" {
            $Script:FWScope = "Any"
            $Script:FWAllowedAddresses = $null
        }
        default {
            $Script:FWScope = "TailscaleOnly"
            $Script:FWAllowedAddresses = $null
        }
    }
}

function Test-Prerequisites {
    Write-Log "Checking prerequisites..." "HEADER"
    
    $passed = $true
    
    if (Test-TailscaleInstalled) {
        $Script:TailscaleIP = if ($TailscaleIP) { $TailscaleIP } else { Get-TailscaleIP }
        if ($Script:TailscaleIP) {
            Write-Log "Tailscale IP: $($Script:TailscaleIP)" "SUCCESS"
        }
        else {
            Write-Log "Tailscale not connected" "ERROR"
            $passed = $false
        }
    }
    else {
        Write-Log "Tailscale not installed" "ERROR"
        $passed = $false
    }
    
    Write-Log "Checking LibreHardwareMonitor at $($UpstreamIP):$($UpstreamPort)..." "INFO"
    if (Test-PortOpen -ComputerName $UpstreamIP -Port $UpstreamPort) {
        Write-Log "LibreHardwareMonitor responding" "SUCCESS"
    }
    else {
        Write-Log "LibreHardwareMonitor not responding on $($UpstreamIP):$($UpstreamPort)" "WARNING"
        Write-Log "Make sure LHM is running with web server enabled" "WARNING"
        Write-Log "Download: $($Script:Config.LHMReleases)" "INFO"
    }
    
    return $passed
}

function Invoke-Installation {
    Write-Log "Starting Caddy Installation" "HEADER"
    
    if (-not (Test-Prerequisites)) {
        Write-Log "Prerequisites check failed" "ERROR"
        return $false
    }
    
    if (-not (Install-Caddy)) { return $false }
    
    if ($EnableAuth -or $Script:AuthEnabled) {
        if (-not $Script:AuthHash) {
            if (-not (Request-AuthCredentials)) {
                Write-Log "Authentication setup cancelled. Proceeding without auth." "WARNING"
                $Script:AuthEnabled = $false
            }
        }
        
        if ($Script:AuthEnabled) {
            Save-AuthConfig
        }
    }
    
    if (-not (New-Caddyfile)) { return $false }
    
    if (-not (Set-FirewallRule -Scope $Script:FWScope -Addresses $Script:FWAllowedAddresses)) {
        Write-Log "Firewall rule creation failed - continuing anyway" "WARNING"
    }
    
    if (-not (Install-CaddyService)) { return $false }
    
    Test-Installation
    
    return $true
}

function Invoke-Uninstall {
    Write-Log "Uninstalling Caddy..." "HEADER"
    
    if (-not $Force) {
        if (-not (Confirm-Action "This will remove Caddy. Continue?")) {
            Write-Log "Uninstall cancelled" "INFO"
            return $false
        }
    }
    
    $service = Get-Service -Name $Script:Config.ServiceName -ErrorAction SilentlyContinue
    if ($service) {
        Write-Log "Removing service..." "INFO"
        Stop-Service -Name $Script:Config.ServiceName -Force -ErrorAction SilentlyContinue
        & sc.exe delete $Script:Config.ServiceName 2>$null | Out-Null
        Write-Log "Service removed" "SUCCESS"
    }
    
    Remove-FirewallRules
    
    if (Test-Path $InstallPath) {
        Remove-Item -Path $InstallPath -Recurse -Force -ErrorAction SilentlyContinue
        Write-Log "Removed directory: $InstallPath" "SUCCESS"
    }
    
    Write-Log "Uninstall complete" "SUCCESS"
    return $true
}

function Test-Installation {
    Write-Log "Verifying Installation" "HEADER"
    
    $allPassed = $true
    
    $service = Get-Service -Name $Script:Config.ServiceName -ErrorAction SilentlyContinue
    Write-Host "  Caddy Service:   " -NoNewline
    if ($service -and $service.Status -eq "Running") {
        Write-Host "Running" -ForegroundColor Green
    }
    else {
        Write-Host "Not Running" -ForegroundColor Red
        $allPassed = $false
    }
    
    Write-Host "  Proxy Port:      " -NoNewline
    if ($Script:TailscaleIP -and (Test-PortOpen -ComputerName $Script:TailscaleIP -Port $ProxyPort)) {
        Write-Host "Listening ($($Script:TailscaleIP):$ProxyPort)" -ForegroundColor Green
    }
    else {
        Write-Host "Not Responding" -ForegroundColor Red
        $allPassed = $false
    }
    
    Write-Host "  LHM Upstream:    " -NoNewline
    if (Test-PortOpen -ComputerName $UpstreamIP -Port $UpstreamPort) {
        Write-Host "Responding ($($UpstreamIP):$($UpstreamPort))" -ForegroundColor Green
    }
    else {
        Write-Host "Not Responding" -ForegroundColor Yellow
    }
    
    Write-Host "  Authentication:  " -NoNewline
    if ($Script:AuthEnabled) {
        Write-Host "Enabled (User: $($Script:AuthUser))" -ForegroundColor Green
    }
    else {
        Write-Host "Disabled" -ForegroundColor Yellow
    }
    
    Write-Host "  Firewall:        " -NoNewline
    $fwRules = Get-FirewallRules
    if ($fwRules) {
        $ruleName = ($fwRules | Select-Object -First 1).DisplayName
        Write-Host $ruleName -ForegroundColor Green
    }
    else {
        Write-Host "No rules configured" -ForegroundColor Yellow
    }
    
    if ($allPassed) {
        Write-Host ""
        Write-Log "Installation verified!" "SUCCESS"
        Write-Host ""
        Write-Host "  ╔═══════════════════════════════════════════════════════╗" -ForegroundColor Green
        Write-Host "  ║                    ACCESS URL                         ║" -ForegroundColor Green
        Write-Host "  ╠═══════════════════════════════════════════════════════╣" -ForegroundColor Green
        Write-Host "  ║  " -ForegroundColor Green -NoNewline
        Write-Host "https://$($Script:TailscaleIP):$ProxyPort/" -ForegroundColor Cyan -NoNewline
        $padding = 55 - "https://$($Script:TailscaleIP):$ProxyPort/".Length - 2
        Write-Host (" " * $padding) -NoNewline
        Write-Host "║" -ForegroundColor Green
        Write-Host "  ╚═══════════════════════════════════════════════════════╝" -ForegroundColor Green
        Write-Host ""
        Write-Host "  Note: Accept the self-signed certificate warning" -ForegroundColor Yellow
        if ($Script:AuthEnabled) {
            Write-Host "  Login: $($Script:AuthUser) / [your password]" -ForegroundColor Yellow
        }
    }
    else {
        Write-Log "Some components failed verification" "WARNING"
    }
    
    return $allPassed
}

function Show-Status {
    $Script:TailscaleIP = if ($TailscaleIP) { $TailscaleIP } else { Get-TailscaleIP }
    
    Read-AuthConfig | Out-Null
    Read-FirewallConfig | Out-Null
    
    Write-Host ""
    Write-Host "  ╔═══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║          Caddy Proxy Status                           ║" -ForegroundColor Cyan
    Write-Host "  ╚═══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "  Tailscale IP:    " -NoNewline
    if ($Script:TailscaleIP) {
        Write-Host $Script:TailscaleIP -ForegroundColor Green
    }
    else {
        Write-Host "Not Connected" -ForegroundColor Red
    }
    
    $service = Get-Service -Name $Script:Config.ServiceName -ErrorAction SilentlyContinue
    Write-Host "  Caddy Service:   " -NoNewline
    if ($service) {
        $color = if ($service.Status -eq "Running") { "Green" } else { "Yellow" }
        Write-Host $service.Status -ForegroundColor $color
    }
    else {
        Write-Host "Not Installed" -ForegroundColor Red
    }
    
    Write-Host "  Proxy Port:      " -NoNewline
    if ($Script:TailscaleIP -and (Test-PortOpen -ComputerName $Script:TailscaleIP -Port $ProxyPort)) {
        Write-Host "Listening (:$ProxyPort)" -ForegroundColor Green
    }
    else {
        Write-Host "Not Responding" -ForegroundColor Red
    }
    
    Write-Host "  LHM Upstream:    " -NoNewline
    if (Test-PortOpen -ComputerName $UpstreamIP -Port $UpstreamPort) {
        Write-Host "Responding ($($UpstreamIP):$($UpstreamPort))" -ForegroundColor Green
    }
    else {
        Write-Host "Not Responding" -ForegroundColor Yellow
    }
    
    Write-Host "  Authentication:  " -NoNewline
    if ($Script:AuthEnabled) {
        Write-Host "Enabled (User: $($Script:AuthUser))" -ForegroundColor Green
    }
    else {
        Write-Host "Disabled" -ForegroundColor Yellow
    }
    
    Write-Host "  Firewall:        " -NoNewline
    $fwRules = Get-FirewallRules
    if ($fwRules) {
        $ruleName = ($fwRules | Select-Object -First 1).DisplayName
        $shortName = $ruleName -replace "^Caddy Reverse Proxy ", ""
        Write-Host $shortName -ForegroundColor Green
    }
    else {
        Write-Host "No rules" -ForegroundColor Yellow
    }
    
    if ($Script:TailscaleIP -and $service -and $service.Status -eq "Running") {
        Write-Host ""
        Write-Host "  Access URL:      " -NoNewline
        Write-Host "https://$($Script:TailscaleIP):$ProxyPort/" -ForegroundColor Cyan
    }
}

function Show-LHMSetup {
    Write-Host ""
    Write-Host "  ╔═══════════════════════════════════════════════════════╗" -ForegroundColor Magenta
    Write-Host "  ║     LibreHardwareMonitor Setup Instructions           ║" -ForegroundColor Magenta
    Write-Host "  ╚═══════════════════════════════════════════════════════╝" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "  1. Download LibreHardwareMonitor:" -ForegroundColor White
    Write-Host "     $($Script:Config.LHMReleases)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  2. Extract and run " -NoNewline -ForegroundColor White
    Write-Host "LibreHardwareMonitor.exe" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  3. Enable Web Server:" -ForegroundColor White
    Write-Host "     Options > Remote Web Server > Run (check)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  4. Configure Port:" -ForegroundColor White
    Write-Host "     Options > Remote Web Server > Port: " -NoNewline -ForegroundColor Gray
    Write-Host "$UpstreamPort" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  5. Select correct IP (important!):" -ForegroundColor White
    Write-Host "     Options > Remote Web Server > IP: " -NoNewline -ForegroundColor Gray
    Write-Host "Your LAN IP" -ForegroundColor Yellow
    Write-Host "     (Avoid Hyper-V IPs like 172.x.x.x)" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  6. (Optional) Disable LHM Authentication:" -ForegroundColor White
    Write-Host "     Caddy + Tailscale + basicauth provides security" -ForegroundColor Gray
    Write-Host ""
}

function Show-AuthMenu {
    while ($true) {
        Clear-Host
        Write-Host ""
        Write-Host "  ╔═══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "  ║          Authentication Management                    ║" -ForegroundColor Cyan
        Write-Host "  ╚═══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
        Write-Host ""
        
        Write-Host "  Current Status:  " -NoNewline
        if ($Script:AuthEnabled) {
            Write-Host "Enabled" -ForegroundColor Green
            Write-Host "  Username:        " -NoNewline
            Write-Host $Script:AuthUser -ForegroundColor Cyan
        }
        else {
            Write-Host "Disabled" -ForegroundColor Yellow
        }
        
        Write-Host ""
        Write-Host "  ─────────────────────────────────────────────────────────" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "  [1] Enable/Update Authentication"
        Write-Host "  [2] Change Password"
        Write-Host "  [3] Disable Authentication"
        Write-Host "  [B] Back to Main Menu"
        Write-Host ""
        
        $choice = Read-Host "  Select option"
        
        switch ($choice.ToUpper()) {
            "1" {
                $exePath = Join-Path $InstallPath $Script:Config.CaddyExe
                if (-not (Test-Path $exePath)) {
                    Write-Log "Caddy not installed. Install Caddy first." "ERROR"
                    Read-Host "`n  Press Enter to continue"
                    continue
                }
                
                if (Request-AuthCredentials) {
                    Save-AuthConfig
                    New-Caddyfile
                    
                    $service = Get-Service -Name $Script:Config.ServiceName -ErrorAction SilentlyContinue
                    if ($service -and $service.Status -eq "Running") {
                        Restart-Service -Name $Script:Config.ServiceName -Force
                        Write-Log "Service restarted with new auth settings" "SUCCESS"
                    }
                }
                Read-Host "`n  Press Enter to continue"
            }
            "2" {
                if (-not $Script:AuthEnabled) {
                    Write-Log "Authentication not enabled" "WARNING"
                    Read-Host "`n  Press Enter to continue"
                    continue
                }
                
                $exePath = Join-Path $InstallPath $Script:Config.CaddyExe
                if (-not (Test-Path $exePath)) {
                    Write-Log "Caddy not installed" "ERROR"
                    Read-Host "`n  Press Enter to continue"
                    continue
                }
                
                Write-Host ""
                Write-Host "  Changing password for user: $($Script:AuthUser)" -ForegroundColor Cyan
                
                $passwordMatch = $false
                $attempts = 0
                
                while (-not $passwordMatch -and $attempts -lt 3) {
                    Write-Host ""
                    $password1 = Read-Host "  New Password" -AsSecureString
                    $password2 = Read-Host "  Confirm Password" -AsSecureString
                    
                    $BSTR1 = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password1)
                    $BSTR2 = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password2)
                    $plain1 = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR1)
                    $plain2 = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR2)
                    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR1)
                    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR2)
                    
                    if ($plain1 -eq $plain2) {
                        if ($plain1.Length -lt 8) {
                            Write-Log "Password must be at least 8 characters" "WARNING"
                            $attempts++
                        }
                        else {
                            $passwordMatch = $true
                            Write-Host ""
                            Write-Log "Generating password hash..." "INFO"
                            $Script:AuthHash = Get-CaddyPasswordHash -Password $password1
                            
                            if ($Script:AuthHash) {
                                Save-AuthConfig
                                New-Caddyfile
                                
                                $service = Get-Service -Name $Script:Config.ServiceName -ErrorAction SilentlyContinue
                                if ($service -and $service.Status -eq "Running") {
                                    Restart-Service -Name $Script:Config.ServiceName -Force
                                    Write-Log "Password changed and service restarted" "SUCCESS"
                                }
                                else {
                                    Write-Log "Password changed" "SUCCESS"
                                }
                            }
                        }
                    }
                    else {
                        Write-Log "Passwords do not match" "WARNING"
                        $attempts++
                    }
                    
                    $plain1 = $null
                    $plain2 = $null
                    [System.GC]::Collect()
                }
                
                Read-Host "`n  Press Enter to continue"
            }
            "3" {
                if (-not $Script:AuthEnabled) {
                    Write-Log "Authentication already disabled" "INFO"
                    Read-Host "`n  Press Enter to continue"
                    continue
                }
                
                if (Confirm-Action "Disable authentication?") {
                    Remove-AuthConfig
                }
                Read-Host "`n  Press Enter to continue"
            }
            "B" { return }
        }
    }
}

function Show-InteractiveMenu {
    Read-AuthConfig | Out-Null
    Read-FirewallConfig | Out-Null
    
    while ($true) {
        Clear-Host
        Show-Status
        
        Write-Host ""
        Write-Host "  ─────────────────────────────────────────────────────────" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "  [1] Install Caddy Proxy"
        Write-Host "  [2] Uninstall Caddy"
        Write-Host "  [3] Test Installation"
        Write-Host "  [4] Restart Caddy Service"
        Write-Host "  [5] View Caddyfile"
        Write-Host "  [6] Edit Caddyfile"
        Write-Host "  [7] LHM Setup Instructions"
        Write-Host "  [8] Open Install Folder"
        Write-Host "  [A] Authentication Settings"
        Write-Host "  [F] Firewall Settings"
        Write-Host "  [S] Scan/Select Upstream IP"
        Write-Host "  [Q] Quit"
        Write-Host ""
        
        $choice = Read-Host "  Select option"
        
        switch ($choice.ToUpper()) {
            "1" {
                Write-Host ""
                $enableAuthChoice = Read-Host "  Enable password authentication? (Y/N)"
                if ($enableAuthChoice -match '^[Yy]') {
                    $Script:AuthEnabled = $true
                }
                else {
                    $Script:AuthEnabled = $false
                }
                
                Select-FirewallScope
                
                Invoke-Installation
                Read-Host "`n  Press Enter to continue"
            }
            "2" {
                Invoke-Uninstall
                Read-Host "`n  Press Enter to continue"
            }
            "3" {
                Test-Installation
                Read-Host "`n  Press Enter to continue"
            }
            "4" {
                Write-Log "Restarting Caddy service..." "INFO"
                Restart-Service -Name $Script:Config.ServiceName -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 2
                $svc = Get-Service -Name $Script:Config.ServiceName -ErrorAction SilentlyContinue
                if ($svc -and $svc.Status -eq "Running") {
                    Write-Log "Service restarted" "SUCCESS"
                }
                else {
                    Write-Log "Service restart failed" "ERROR"
                }
                Read-Host "`n  Press Enter to continue"
            }
            "5" {
                $caddyfilePath = Join-Path $InstallPath $Script:Config.CaddyFile
                if (Test-Path $caddyfilePath) {
                    Write-Host ""
                    Get-Content $caddyfilePath
                }
                else {
                    Write-Log "Caddyfile not found" "ERROR"
                }
                Read-Host "`n  Press Enter to continue"
            }
            "6" {
                $caddyfilePath = Join-Path $InstallPath $Script:Config.CaddyFile
                if (Test-Path $caddyfilePath) {
                    notepad $caddyfilePath
                    Write-Log "Remember to restart Caddy after editing" "WARNING"
                }
                else {
                    Write-Log "Caddyfile not found" "ERROR"
                }
                Read-Host "`n  Press Enter to continue"
            }
            "7" {
                Show-LHMSetup
                Read-Host "`n  Press Enter to continue"
            }
            "8" {
                if (Test-Path $InstallPath) {
                    explorer.exe $InstallPath
                }
                else {
                    Write-Log "Install path does not exist" "ERROR"
                    Read-Host "`n  Press Enter to continue"
                }
            }
            "A" { Show-AuthMenu }
            "F" { Show-FirewallMenu }
            "S" { Select-UpstreamIP }
            "Q" { return }
        }
    }
}

# ============================================================================
# MAIN ENTRY POINT
# ============================================================================

$Script:TailscaleIP = if ($TailscaleIP) { $TailscaleIP } else { Get-TailscaleIP }

switch ($Action) {
    "Menu" { Show-InteractiveMenu }
    "Install" { Invoke-Installation }
    "Uninstall" { Invoke-Uninstall }
    "Status" { Show-Status }
    "Test" { Test-Installation }
}
{{< /codemirror >}}

## Final References
---

- [Caddy Documentation](https://caddyserver.com/docs/)
- [Caddy Reverse Proxy Quick-Start](https://caddyserver.com/docs/quick-starts/reverse-proxy)
- [Caddy TLS Directive](https://caddyserver.com/docs/caddyfile/directives/tls)
- [Caddy basicauth Directive](https://caddyserver.com/docs/caddyfile/directives/basicauth)
- [Caddy hash-password Command](https://caddyserver.com/docs/command-line#caddy-hash-password)
- [Tailscale with Caddy](https://tailscale.com/blog/caddy)
- [Tailscale CGNAT Range](https://tailscale.com/kb/1015/100.x-addresses)
- [LibreHardwareMonitor GitHub](https://github.com/LibreHardwareMonitor/LibreHardwareMonitor)
- [Microsoft sc.exe Documentation](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/sc-create)
- [Windows Firewall PowerShell](https://learn.microsoft.com/en-us/powershell/module/netsecurity/new-netfirewallrule)
- [New-NetFirewallRule](https://learn.microsoft.com/en-us/powershell/module/netsecurity/new-netfirewallrule)