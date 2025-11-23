---
title: "Veeam Application Introduction"
date: 2025-11-08
draft: false
description: "Simple introduction to the industry standard backup and recovery software"
categories: ["Security", "Penetration Testing"]
tags: ["kali-linux", "automation"]
featuredImage: "/images/posts/hero_veeam_backup-v2.jpg"
readingTime: true
toc: true
author: "Andrew Jones"
authorImage: "/images/authors/security-team.jpg"
authorBio: ""
socialShare: true
tool_image: "/darkreader.png"
---


---
# Comprehensive Guide: Veeam Agent-Level Backups with User Self-Service
## Linux VMs & Windows Workstations
---

---

## Overview
---

This guide covers implementing Veeam agent-level backups for Linux VMs and Windows workstations with user self-service capabilities, allowing remote users to initiate and manage their own backups while maintaining centralized control.

### Key Capabilities
---
- **Centralized Management**: Manage agents from Veeam Backup & Replication console
- **User Self-Service**: Users can initiate backups from their machines
- **Flexible Control**: Choose between full control and read-only modes
- **Cross-Platform**: Unified approach for Linux and Windows systems

---

## Architecture & Concepts
---

### Agent Operation Modes
---

**1. Standalone Mode**
- Agent operates independently on the endpoint
- User has full control via local interface
- Can still backup to Veeam-managed repositories
- Best for: Power users, administrators, remote workers

**2. Managed Mode (via Veeam B&R)**
- Centrally managed from Veeam Backup & Replication
- Two sub-modes:
  - **Backup Job (Server-managed)**: Backups orchestrated from Veeam server
  - **Backup Policy (Agent-managed)**: Backups run on endpoints using centrally-defined policies

**3. Read-Only vs Full Access**
- **Read-Only Mode**: Users can view status, run manual backups, restore files
- **Full Access Mode**: Users can modify job settings, change schedules, configure backups

### Management Components
---

**Protection Groups**
- Container for organizing computers by type, location, or policy
- Types:
  - Individual computers
  - Active Directory objects (domains, OUs, groups)
  - CSV file imports
  - Pre-installed agents
  - Cloud machines (Azure VM, AWS EC2)

**Backup Jobs vs Backup Policies**
- **Backup Job (Managed by Server)**: Runs from Veeam server, pulls data from agents
- **Backup Policy (Managed by Agent)**: Configuration template pushed to agents; agents execute backups locally

---

## Prerequisites
---

### Veeam Backup & Replication Server
---
- Veeam Backup & Replication 12.0 or later
- Appropriate licensing (see Licensing Requirements below)
- Network connectivity to agent endpoints
- Backup repository configured

### Linux VMs Requirements
---
**Supported Distributions** (as of v6.0):
- RHEL/CentOS/Rocky Linux/AlmaLinux 7-9
- Ubuntu 18.04-24.04 LTS
- Debian 9-12
- SLES 12 SP5, 15 SP2-SP6
- Oracle Linux 7-9

**System Requirements**:
- CPU: x86-64 or ARM64
- Memory: 512 MB minimum, 2 GB recommended
- Disk: 200 MB for agent installation
- Kernel: 2.6.32 or later (RHEL 6), 3.10.0 or later (RHEL 7+)

**Required Packages**:
```bash
# For RHEL/CentOS
- dkms (from EPEL)
- kernel-devel
- gcc, make
- perl

# For Debian/Ubuntu
- dkms
- linux-headers-$(uname -r)
- build-essential
```

### Windows Workstations Requirements
---
**Supported OS**:
- Windows 11 (22H2, 23H2, 24H2)
- Windows 10 (1809 and later)
- Windows Server 2025, 2022, 2019, 2016

**System Requirements**:
- CPU: x86-64 processor
- Memory: 2 GB RAM minimum
- Disk: 200 MB for installation
- .NET Framework 4.5.2 or later (auto-installed if missing)

### Network Requirements
---
- Port 6160/TCP: Veeam Installer Service
- Port 2500-3300/TCP: Data transmission
- Port 10005-10007/TCP: Agent communication
- DNS resolution between server and agents

### Licensing Requirements
---

**License Types**:
1. **Per-Instance License**: Based on number of protected machines
2. **Per-Socket License**: Up to 6 instances for agent protection
3. **Community Edition**: Limited free functionality

**Agent Editions**:
- **Server Edition**: Full functionality for servers
- **Workstation Edition**: For desktops/laptops with some limitations
- **Free Edition**: Basic functionality, single backup job

**Key Limitations**:
- Workstation Edition: Limited to 1 job to local/network/repository + unlimited Cloud Connect jobs
- Free Edition: 1 job total, no Cloud Connect, no database processing

---

## Installation & Deployment
---

### Method 1: Automatic Deployment (Recommended)
---

#### Step 1: Create Protection Group
---

1. In Veeam B&R console, go to **Inventory** → **Physical Infrastructure**
2. Right-click → **Add Protection Group**
3. Choose type:
   - **Individual computers**: Enter IP addresses/hostnames
   - **Microsoft Active Directory**: Select domain, OUs, or computers
   - **CSV file**: Import computer list
   - **Pre-installed agents**: For manual/GPO deployment

#### Step 2: Configure Protection Group Settings
---

**For Active Directory Objects**:
```
Name: Linux-VMs-Production
Type: Microsoft Active Directory objects
Scope: OU=LinuxServers,DC=company,DC=local
Credentials: DOMAIN\VeeamAgentInstaller (with local admin rights)
```

**Discovery Options**:
- **Automatic discovery schedule**: Daily at 2:00 AM
- **Install backup agent automatically**: Enabled
- **Automatic upgrade**: Enabled
- **Distribution server**: Select closest Veeam proxy/repository

#### Step 3: Credentials Configuration
---

For Linux systems:
```
Account: root or sudo user
Authentication: SSH key-based (recommended) or password
```

For Windows systems:
```
Account: DOMAIN\AgentInstaller
Requirements: Local Administrator group membership
```

### Method 2: Manual Installation (Linux)
---

#### For RHEL/CentOS/Rocky/AlmaLinux:
---

```bash
# Add Veeam repository (RHEL 8 example)
sudo yum install http://repository.veeam.com/backup/linux/agent/rpm/el/8/x86_64/veeam-release-el8-1.0.7-1.x86_64.rpm

# Install dependencies (if needed)
sudo yum install epel-release
sudo yum install dkms kernel-devel gcc make perl

# Install Veeam Agent
sudo yum install veeam

# Start configuration
sudo veeam
```

#### For Debian/Ubuntu:
---

```bash
# Download repository package
wget https://repository.veeam.com/backup/linux/agent/dpkg/debian/public/pool/veeam/v/veeam-release-deb/veeam-release-deb_1.0.9_amd64.deb

# Install repository
sudo dpkg -i veeam-release-deb_1.0.9_amd64.deb

# Update package list
sudo apt-get update

# Install dependencies
sudo apt-get install dkms linux-headers-$(uname -r)

# Install Veeam Agent
sudo apt-get install veeam

# Start configuration
sudo veeam
```

#### Configure Agent for Management:
---

```bash
# Apply configuration from Veeam B&R
sudo veeamconfig setup --cfg /path/to/config.xml

# Or manually configure connection
sudo veeamconfig vbrserver add \
    --address veeam-server.company.local \
    --port 10002 \
    --login DOMAIN\\veeamagent \
    --password <password>
```

### Method 3: Manual Installation (Windows)
---

#### Silent Installation:
---

```powershell
# Download installer from Veeam
# Run silent install with configuration

.\VeeamAgentWindows_6.3.exe /silent /accepteula /acceptthirdparty

# Or MSI-based installation
msiexec /i VeeamAgentWindows.msi /quiet ACCEPT_EULA=1 ACCEPT_THIRDPARTY_LICENSES=1
```

#### Configure via Command Line:
---

```powershell
# Import configuration from Veeam B&R
"C:\Program Files\Veeam\Endpoint Backup\Veeam.Agent.Configurator.exe" /install /p:"\\server\share\config.xml"

# Or configure manually
"C:\Program Files\Veeam\Endpoint Backup\Veeam.Agent.Configurator.exe" /server.add /address:"veeam-server.company.local" /port:10002 /login:"DOMAIN\user" /password:"password"
```

#### Group Policy Deployment (Enterprise):
---

1. **Prepare Installation Package**:
   - Place installer in network share: `\\server\share\Veeam\`
   - Create config file: `config.xml`

2. **Create GPO**:
   - Computer Configuration → Policies → Software Settings
   - Software Installation → New → Package
   - Select `VeeamAgentWindows.msi`

3. **Add Startup Script** (for configuration):
   ```batch
   @echo off
   "C:\Program Files\Veeam\Endpoint Backup\Veeam.Agent.Configurator.exe" /install /p:"\\server\share\Veeam\config.xml"
   ```

---

## User Permissions & Roles
---

### Veeam Backup & Replication Roles
---

**Built-in Roles**:

1. **Veeam Backup Administrator**
   - Full control over all operations
   - Can create/modify/delete all objects
   - Manage licenses and infrastructure

2. **Veeam Backup Operator**
   - Start/stop backup jobs
   - Perform restores
   - View job statistics
   - Cannot modify infrastructure

3. **Veeam Restore Operator**
   - Perform restore operations only
   - View backup files
   - Cannot run backups

4. **Custom Roles**
   - Create tailored permission sets
   - Scope to specific jobs/computers

### Configuring User Roles
---

#### Add Users to Veeam Console:
---

1. In Veeam B&R console: **Users and Roles** → **Security**
2. Click **Add**
3. Select **Active Directory Object** or **Local User/Group**
4. Enter user/group: `DOMAIN\Username` or `DOMAIN\BackupOperators`
5. Assign role:
   - **Veeam Backup Operator** (recommended for most users)
   - **Custom Role** (for fine-grained control)

#### Create Custom Role:
---

1. **Users and Roles** → **Roles**
2. Click **Add**
3. Name: "Agent Backup User"
4. Grant permissions:
   - ✅ Start backup jobs
   - ✅ Stop backup jobs
   - ✅ View job sessions
   - ✅ Restore files
   - ❌ Modify jobs
   - ❌ Delete backups
   - ❌ Modify infrastructure

5. **Scope Objects** tab:
   - Select specific protection groups
   - Select individual backup jobs
   - Restrict to only their computers

### Local Agent Permissions
---

**For Users to Control Agents Locally**:

**Windows**:
- User must be local Administrator on their workstation
- OR add user to "Veeam Endpoint Users" local group (if using full access mode)

**Linux**:
- User must be root or in sudo group
- Veeam commands require elevation:
  ```bash
  sudo veeam
  sudo veeamconfig
  ```

---

## Self-Service Configuration
---

### Configuration Options
---

#### Option 1: Full Agent Control (Standalone-like)
---

**When to Use**:
- Power users who understand backup concepts
- Remote workers with limited connectivity
- Users who need schedule flexibility

**Setup**:
1. Create Protection Group
2. Create Backup Policy (not Backup Job)
3. Set **Read-Only Mode** to **OFF**
4. Users get full control via local agent interface

**User Capabilities**:
- Create/modify backup jobs
- Change schedules
- Select backup locations
- Initiate manual backups
- Perform restores

#### Option 2: Limited Self-Service (Read-Only Mode)
---

**When to Use**:
- Standard users needing occasional manual backups
- Compliance requirements for change control
- Centralized backup management preferred

**Setup**:
1. Create Protection Group
2. Create Backup Job OR Backup Policy
3. Enable **Read-Only Mode**
4. Users can only:
   - Run manual backup (using existing schedule/config)
   - View backup status
   - Restore individual files

**Configuration Steps**:

For Agents managed by Veeam B&R:
```
1. Inventory → Physical Infrastructure → Protection Group
2. Right-click agent computer → Properties
3. Options → Access Mode → Read-only
```

Or set during Protection Group creation:
```
Protection Group wizard → Options step →
☑ Enable read-only access mode for backup agents
```

#### Option 3: Hybrid Approach (Backup Policies)
---

**Best for**: Most enterprise environments

**Configuration**:
1. Use Backup Policies (agent-managed jobs)
2. Define backup configuration centrally
3. Agents execute backups locally on schedule
4. Users can manually trigger between scheduled runs (read-only) OR modify locally (full access)

---

## Operating Modes Explained
---

### Backup Job vs Backup Policy
---

| Feature | Backup Job (Server-Managed) | Backup Policy (Agent-Managed) |
|---------|---------------------------|----------------------------|
| **Execution** | Runs from Veeam server | Runs on agent computer |
| **Data Transfer** | Pulled from agents | Agent pushes to repository |
| **Network Requirements** | Constant connectivity | Periodic sync (6 hours) |
| **Best For** | Servers, stable network | Workstations, roaming laptops |
| **User Control** | None (server-side job) | Full or read-only (agent-side) |
| **Backup Target** | Veeam repository only | Repository, Cloud Connect, local, network share |
| **Multiple Jobs** | Servers: unlimited, Workstations: limited | Per licensing edition |

### Creating Backup Jobs (Server-Managed)
---

**Use Case**: Linux VMs in datacenter, stable connectivity

```
1. Backup → Agent Backup → Add Agent Backup Job
2. Job Mode: Managed by backup server
3. Name: Linux-VMs-Daily
4. Add protection groups or individual computers
5. Backup Mode: 
   - Entire computer (image-level)
   - Volume level
   - File level
6. Storage: Select Veeam backup repository
7. Guest Processing: Enable if needed (for Linux: requires Perl)
8. Schedule: Daily at 10:00 PM
9. Advanced settings:
   - Retention: 14 restore points
   - Encryption: Enable if required
   - Notifications: Email on failures
```

### Creating Backup Policies (Agent-Managed)
---

**Use Case**: Windows workstations, laptops, remote workers

```
1. Backup → Agent Backup → Add Agent Backup Job
2. Job Mode: Managed by agent
3. Name: Workstations-Policy
4. Add protection groups or individual computers
5. Backup Mode:
   - Entire computer (recommended for laptops)
   - Volume level
   - File level
6. Backup Target:
   - Veeam backup repository (if accessible)
   - Shared folder: \\fileserver\backups\%COMPUTERNAME%
   - Local: D:\Backups (for temporary storage)
   - Cloud Connect repository
7. Schedule: 
   - Daily at 6:00 PM (when users typically online)
   - Monthly on 1st Sunday (full)
   - Retry failed jobs: Yes
8. Advanced:
   - Backup window: 6 PM - 10 PM
   - Pre-/post-job scripts (optional)
   - Application-aware processing
```

**Policy Application**:
- Policy pushed to agents immediately upon creation
- Agents sync every 6 hours for updates
- Manual sync: 
  - Linux: `sudo veeamconfig job sync`
  - Windows: Right-click agent tray icon → **Synchronize with Veeam Backup & Replication**

---

## Step-by-Step Implementation
---

### Scenario 1: Linux VMs with Full User Control
---

**Environment**: 50 Linux VMs in production, sysadmins need backup flexibility

**Implementation**:

1. **Create Protection Group**:
   ```
   Name: Linux-Production-Servers
   Type: CSV file import
   File: \\veeam\config\linux-servers.csv
   Credentials: root (SSH key)
   Discovery: Daily at 1 AM
   Auto-install: Yes
   Auto-upgrade: Yes
   ```

2. **CSV File Format** (`linux-servers.csv`):
   ```csv
   Name,IP,Description
   web01,192.168.1.10,Web Server
   db01,192.168.1.20,Database Server
   app01,192.168.1.30,Application Server
   ```

3. **Create Backup Policy**:
   ```
   Name: Linux-Servers-Policy
   Mode: Managed by agent
   Protection Groups: Linux-Production-Servers
   Backup Mode: Entire computer
   Target: Veeam Repository (linux-backups)
   Schedule: Daily at 11 PM
   Retention: 14 restore points
   Read-Only Mode: Disabled (users have full control)
   ```

4. **Configure User Permissions**:
   ```
   Add AD Group: DOMAIN\LinuxAdmins
   Role: Veeam Backup Operator
   Scope: Linux-Production-Servers protection group
   ```

5. **User Access Setup**:
   - Users SSH to their Linux VMs
   - Run: `sudo veeam` for interactive TUI
   - Or: `sudo veeamconfig` for CLI management
   - Can modify job settings, run manual backups, perform restores

### Scenario 2: Windows Workstations with Read-Only Mode
---

**Environment**: 200 Windows 10/11 laptops, users need manual backup initiation only

**Implementation**:

1. **Create Protection Group**:
   ```
   Name: Corporate-Workstations
   Type: Active Directory Objects
   Scope: OU=Workstations,OU=Computers,DC=company,DC=local
   Exclude: OU=Kiosks (optional)
   Credentials: DOMAIN\VeeamAgentDeployer
   Discovery: Every 4 hours
   Auto-install: Yes
   ```

2. **Create Backup Policy**:
   ```
   Name: Workstation-Daily-Backup
   Mode: Managed by agent
   Protection Groups: Corporate-Workstations
   Backup Mode: Entire computer
   Target: \\fileserver\backups\%COMPUTERNAME%
   Fallback: C:\LocalBackups (if network unavailable)
   Schedule: 
     - Workdays at 7 PM
     - Allow backup on battery (laptops)
   Retention: 7 restore points
   Read-Only Mode: ENABLED
   ```

3. **Configure Permissions**:
   ```
   Add AD Group: DOMAIN\Domain Users
   Role: Custom "Workstation Backup Users"
   Permissions:
     - View backup jobs: Yes
     - Run manual backup: Yes
     - Restore files: Yes
     - Modify settings: No
   Scope: Corporate-Workstations
   ```

4. **User Workflow**:
   - User sees Veeam icon in system tray
   - Right-click → **Backup Now** (runs configured policy)
   - View status: **Control Panel** (read-only view)
   - Restore: **Control Panel** → **Restore** → **File-level restore**

### Scenario 3: Mixed Environment (Linux + Windows)
---

**Environment**: 30 Linux servers, 100 Windows workstations, different policies

**Implementation**:

1. **Create Multiple Protection Groups**:

   **Linux Servers**:
   ```
   Name: Linux-Servers
   Type: Individual computers (manually added)
   Computers: [linux01, linux02, ..., linux30]
   Credentials: root (SSH key)
   Auto-install: Yes
   ```

   **Windows Workstations**:
   ```
   Name: Windows-Workstations
   Type: Active Directory (OU)
   Credentials: DOMAIN\AgentInstaller
   Auto-install: Yes
   ```

2. **Create Separate Backup Policies**:

   **Linux Policy**:
   ```
   Name: Linux-Backup-Job
   Mode: Managed by agent
   Computers: Linux-Servers
   Type: Volume-level (system volumes only)
   Target: Veeam Repository
   Schedule: Daily 2 AM
   Read-Only: Disabled
   ```

   **Windows Policy**:
   ```
   Name: Workstation-Policy
   Mode: Managed by agent
   Computers: Windows-Workstations
   Type: Entire computer
   Target: Network Share
   Schedule: Daily 7 PM
   Read-Only: Enabled
   ```

3. **Role Assignments**:
   - Linux Admins → Full control on Linux-Servers group
   - Windows Users → Read-only on Windows-Workstations group

---

## Best Practices
---

### Security
---

1. **Credential Management**:
   - Use service accounts for agent deployment
   - Implement least privilege principle
   - Rotate passwords regularly
   - Use SSH keys for Linux (not passwords)

2. **Network Security**:
   - Segment backup traffic (VLAN)
   - Use TLS for agent communication
   - Firewall rules: only allow Veeam server → agents
   - VPN for remote agents

3. **Backup Repository Security**:
   - Immutability where possible
   - Access control on shares
   - Encryption at rest and in transit
   - Air-gapped copies for critical data

### Performance
---

1. **Scheduling**:
   - Stagger backup windows across protection groups
   - Linux servers: 10 PM - 6 AM
   - Workstations: 7 PM - 10 PM (when online)
   - Avoid peak business hours

2. **Resource Management**:
   - Set concurrent tasks limits
   - Throttle network bandwidth if needed
   - Enable CBT (Changed Block Tracking) for faster incrementals
   - Use appropriate block size for repositories

3. **Repository Configuration**:
   - Deduplicated storage for workstations
   - Fast storage tier for active backups
   - Archive tier for long-term retention
   - Per-VM backup files for granular management

### Monitoring
---

1. **Configure Notifications**:
   ```
   Email notifications:
   - Failed jobs → Administrators
   - Successful jobs → Log only
   - Warnings → Daily digest
   ```

2. **Reporting**:
   - Weekly backup status reports
   - Capacity planning reports
   - License usage tracking
   - Agent health checks

3. **Health Checks**:
   - Daily: Check failed jobs
   - Weekly: Review agent connectivity
   - Monthly: Validate restore capability
   - Quarterly: Test DR procedures

### Maintenance
---

1. **Regular Tasks**:
   - Update agents (automatic or scheduled)
   - Review and adjust retention
   - Clean up old/orphaned jobs
   - Archive to tape/cloud for long-term

2. **Documentation**:
   - Protection group inventory
   - User access matrix
   - Network diagram
   - Runbook for common tasks

3. **Training**:
   - User guides for self-service
   - Admin training for troubleshooting
   - Documentation of custom configurations

---

## Troubleshooting
---

### Common Issues
---

#### Agent Installation Failures
---

**Linux - Missing Dependencies**:
```bash
# Problem: dkms not found
# Solution:
sudo yum install epel-release
sudo yum install dkms kernel-devel

# Problem: Kernel module compilation fails
# Solution: Install matching kernel headers
sudo yum install kernel-devel-$(uname -r)

# Rebuild Veeam modules
sudo dkms install veeamsnap/$(rpm -q --qf '%{VERSION}' veeamsnap)
```

**Windows - Installation Hangs**:
```powershell
# Check Windows Installer service
Get-Service msiserver | Restart-Service

# Clear temp files
Remove-Item -Path "$env:TEMP\*" -Recurse -Force

# Disable antivirus temporarily during install
# Add Veeam directories to exclusions:
# C:\Program Files\Veeam\Endpoint Backup\
# C:\ProgramData\Veeam\Endpoint\
```

#### Connectivity Issues
---

**Agent Cannot Connect to Veeam Server**:

Linux:
```bash
# Test connectivity
telnet veeam-server.company.local 10002
nc -zv veeam-server.company.local 10002

# Check agent status
sudo systemctl status veeamservice

# View logs
sudo cat /var/log/veeam/veeamservice.log

# Manual sync
sudo veeamconfig vbrserver sync
```

Windows:
```powershell
# Test connectivity
Test-NetConnection -ComputerName veeam-server.company.local -Port 10002

# Check service
Get-Service VeeamEndpointBackupSvc | Restart-Service

# View logs
Get-EventLog -LogName "Veeam Agent" -Newest 50

# Manual sync
& "C:\Program Files\Veeam\Endpoint Backup\Veeam.Agent.Configurator.exe" /server.sync
```

**Firewall Issues**:
```bash
# Linux - Allow Veeam ports (firewalld)
sudo firewall-cmd --permanent --add-port=2500-3300/tcp
sudo firewall-cmd --permanent --add-port=6160/tcp
sudo firewall-cmd --reload

# Linux - Allow Veeam ports (iptables)
sudo iptables -A INPUT -p tcp --dport 2500:3300 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 6160 -j ACCEPT
sudo service iptables save
```

```powershell
# Windows - Allow Veeam through firewall
New-NetFirewallRule -DisplayName "Veeam Agent" -Direction Inbound -Protocol TCP -LocalPort 2500-3300,6160,10005-10007 -Action Allow
```

#### Backup Job Failures
---

**Insufficient Permissions**:
```bash
# Linux - Grant Veeam access to volumes
sudo usermod -aG disk veeam
sudo usermod -aG veeam veeam

# Check mount points are accessible
ls -la /mnt /media
```

**Snapshot Failures (Linux)**:
```bash
# Check available space for snapshots
df -h /

# Verify snapshot store location
sudo veeamconfig snapshot info

# Change snapshot location if needed
sudo veeamconfig snapshot set --path /var/veeam/snapshots
```

**Volume Shadow Copy Service Issues (Windows)**:
```powershell
# Check VSS writers
vssadmin list writers

# Restart VSS service
Restart-Service VSS

# Clear old shadow copies
vssadmin delete shadows /all /quiet
```

#### Read-Only Mode Not Working
---

**Issue**: Users can still modify backup settings despite read-only mode enabled

**Solution**:
1. Verify mode in Veeam console:
   ```
   Inventory → Computer → Properties → Options → Access Mode
   ```

2. Force policy sync:
   ```
   Protection Group → Rescan
   ```

3. Check agent local permissions:
   - Windows: Remove user from local Administrators
   - Linux: Revoke sudo access for veeam commands

#### Performance Issues
---

**Slow Backups**:
```bash
# Check network throughput
iperf3 -c veeam-server.company.local

# Linux - Monitor I/O
iostat -x 5 10

# Check if compression/deduplication is bottleneck
# Disable in job settings if CPU-constrained
```

**High CPU Usage During Backup**:
- Reduce compression level (job settings)
- Enable application-aware processing only if needed
- Stagger backup schedules more
- Add processing cores to agents

### Log Locations
---

**Linux**:
```bash
# Main service log
/var/log/veeam/veeamservice.log

# Job logs
/var/log/veeam/Backup/

# Configuration
/etc/veeam/

# Database
/var/lib/veeam/
```

**Windows**:
```
# Event Viewer
Applications and Services Logs → Veeam Agent

# File logs
C:\ProgramData\Veeam\Endpoint\Logs\

# Configuration
C:\ProgramData\Veeam\Endpoint\
```

### Support Commands
---

**Linux Diagnostic Bundle**:
```bash
# Generate support bundle
sudo veeamconfig support export --path /tmp/veeam-support.zip

# Include system info
sudo veeamconfig support export --path /tmp/veeam-support.zip --include-system-info
```

**Windows Diagnostic Bundle**:
```powershell
# Generate support bundle
& "C:\Program Files\Veeam\Endpoint Backup\Veeam.Agent.Configurator.exe" /createSupportBundle /file:"C:\Temp\veeam-support.zip"
```

---

## Appendix A: Command Reference
---

### Linux (veeamconfig)
---

**General**:
```bash
# Show version
sudo veeamconfig --version

# Show license info
sudo veeamconfig license show

# View all jobs
sudo veeamconfig job list

# View job details
sudo veeamconfig job info --name "Backup Job"
```

**Job Management**:
```bash
# Start job manually
sudo veeamconfig job start --name "Backup Job"

# Stop running job
sudo veeamconfig job stop --name "Backup Job"

# Enable/disable job
sudo veeamconfig job enable --name "Backup Job"
sudo veeamconfig job disable --name "Backup Job"

# Delete job
sudo veeamconfig job delete --name "Backup Job"
```

**Backup Server Connection**:
```bash
# Add Veeam server
sudo veeamconfig vbrserver add --address veeam.company.local --port 10002 --login "DOMAIN\user" --password "pass"

# List configured servers
sudo veeamconfig vbrserver list

# Sync with server
sudo veeamconfig vbrserver sync

# Remove server
sudo veeamconfig vbrserver remove --id 1
```

**Recovery**:
```bash
# List restore points
sudo veeamconfig recovery list --job "Backup Job"

# Mount restore point (file-level recovery)
sudo veeamconfig recovery mount --session "Session01" --mountpoint /mnt/backup

# Unmount
sudo veeamconfig recovery unmount --mountpoint /mnt/backup
```

### Windows (Veeam.Agent.Configurator.exe)
---

**General**:
```powershell
$veeam = "C:\Program Files\Veeam\Endpoint Backup\Veeam.Agent.Configurator.exe"

# Show configuration
& $veeam /list

# Show license
& $veeam /info
```

**Job Management**:
```powershell
# Start backup
& $veeam /start "Backup Job"

# Stop backup
& $veeam /stop "Backup Job"

# Enable/disable job
& $veeam /enable "Backup Job"
& $veeam /disable "Backup Job"
```

**Configuration Export/Import**:
```powershell
# Export configuration
& $veeam /export /file:"C:\Temp\config.xml"

# Import configuration
& $veeam /import /file:"C:\Temp\config.xml"
```

---

## Appendix B: Quick Reference Tables
---

### Port Requirements
---

| Port | Protocol | Direction | Purpose |
|------|----------|-----------|---------|
| 2500-3300 | TCP | Bidirectional | Data transfer |
| 6160 | TCP | Inbound to agent | Installer service |
| 10002 | TCP | Outbound from agent | Agent management |
| 10005-10007 | TCP | Bidirectional | Control channel |
| 22 | TCP | Inbound to Linux | SSH (deployment) |
| 445 | TCP | Outbound to repository | SMB shares |

### Backup Modes Comparison
---

| Mode | Description | Use Case | Restore Granularity |
|------|-------------|----------|---------------------|
| **Entire Computer** | Full system image | Bare-metal DR | Full system, volumes, files |
| **Volume Level** | Selected volumes only | Partial system backup | Volumes, files |
| **File Level** | Specific files/folders | User data only | Individual files |

### Retention Policy Examples
---

| Scenario | Configuration | Result |
|----------|--------------|---------|
| **Daily Backups** | 14 restore points | 2 weeks of daily backups |
| **Weekly Fulls** | 4 full backups | 1 month of weekly fulls |
| **GFS** | 7 daily, 4 weekly, 12 monthly, 5 yearly | Comprehensive long-term |
| **Simple** | 7 restore points | 1 week (quick recovery) |

---

## Appendix C: Sample Scripts
---

### PowerShell: Deploy Agents to Multiple Windows Machines
---

```powershell
# Deploy-VeeamAgent.ps1
# Deploys Veeam Agent to computers in a CSV file

param(
    [string]$ComputerListCSV = "C:\Scripts\computers.csv",
    [string]$InstallerPath = "\\server\share\VeeamAgentWindows_6.3.exe",
    [string]$ConfigPath = "\\server\share\config.xml",
    [PSCredential]$Credential
)

$computers = Import-Csv $ComputerListCSV

foreach ($computer in $computers) {
    $computerName = $computer.Name
    Write-Host "Deploying to $computerName..." -ForegroundColor Cyan
    
    try {
        # Copy installer
        $session = New-PSSession -ComputerName $computerName -Credential $Credential
        Copy-Item -Path $InstallerPath -Destination "C:\Temp\" -ToSession $session
        Copy-Item -Path $ConfigPath -Destination "C:\Temp\" -ToSession $session
        
        # Install agent
        Invoke-Command -Session $session -ScriptBlock {
            Start-Process "C:\Temp\VeeamAgentWindows_6.3.exe" -ArgumentList "/silent /accepteula /acceptthirdparty" -Wait
            
            # Apply configuration
            Start-Sleep -Seconds 30
            & "C:\Program Files\Veeam\Endpoint Backup\Veeam.Agent.Configurator.exe" /install /p:"C:\Temp\config.xml"
        }
        
        Remove-PSSession $session
        Write-Host "✓ Completed: $computerName" -ForegroundColor Green
        
    } catch {
        Write-Host "✗ Failed: $computerName - $($_.Exception.Message)" -ForegroundColor Red
    }
}
```

### Bash: Deploy Agents to Multiple Linux Machines
---

```bash
#!/bin/bash
# deploy-veeam-linux.sh
# Deploys Veeam Agent to Linux servers via SSH

COMPUTER_LIST="servers.txt"
SSH_KEY="~/.ssh/veeam_deployment_key"
CONFIG_FILE="config.xml"
VEEAM_SERVER="veeam-server.company.local"

while IFS= read -r server; do
    echo "Deploying to $server..."
    
    # Install agent
    ssh -i "$SSH_KEY" root@"$server" << 'EOF'
        # Detect OS
        if [ -f /etc/redhat-release ]; then
            # RHEL/CentOS
            yum install -y epel-release
            yum install -y http://repository.veeam.com/backup/linux/agent/rpm/el/8/x86_64/veeam-release-el8-1.0.7-1.x86_64.rpm
            yum install -y veeam
        elif [ -f /etc/debian_version ]; then
            # Debian/Ubuntu
            wget https://repository.veeam.com/backup/linux/agent/dpkg/debian/public/pool/veeam/v/veeam-release-deb/veeam-release-deb_1.0.9_amd64.deb
            dpkg -i veeam-release-deb_1.0.9_amd64.deb
            apt-get update
            apt-get install -y veeam
        fi
        
        # Start service
        systemctl enable veeamservice
        systemctl start veeamservice
EOF
    
    # Copy config and apply
    scp -i "$SSH_KEY" "$CONFIG_FILE" root@"$server":/tmp/
    ssh -i "$SSH_KEY" root@"$server" "veeamconfig setup --cfg /tmp/$CONFIG_FILE"
    
    echo "✓ Completed: $server"
    
done < "$COMPUTER_LIST"

echo "Deployment complete!"
```

### PowerShell: Check Agent Status Report
---

```powershell
# Get-VeeamAgentStatus.ps1
# Generates report of all agent statuses

$veeamServer = "veeam-server.company.local"
Connect-VBRServer -Server $veeamServer

$report = @()

$protectionGroups = Get-VBRComputerProtectionGroup

foreach ($group in $protectionGroups) {
    $computers = Get-VBRComputerProtectionGroupMember -ProtectionGroup $group
    
    foreach ($computer in $computers) {
        $jobs = Get-VBRComputerBackupJob | Where-Object { $_.Objects -contains $computer }
        
        foreach ($job in $jobs) {
            $lastSession = Get-VBRBackupSession -Job $job | Sort-Object EndTime -Descending | Select-Object -First 1
            
            $report += [PSCustomObject]@{
                ProtectionGroup = $group.Name
                Computer = $computer.Name
                AgentVersion = $computer.Version
                OS = $computer.OSPlatform
                JobName = $job.Name
                LastBackup = $lastSession.EndTime
                Status = $lastSession.Result
                Size = [math]::Round($lastSession.BackupTotalSize / 1GB, 2)
            }
        }
    }
}

$report | Export-Csv "VeeamAgentStatus-$(Get-Date -Format 'yyyy-MM-dd').csv" -NoTypeInformation
$report | Format-Table -AutoSize

Disconnect-VBRServer
```

---

## Conclusion
---

This guide provides a comprehensive framework for implementing Veeam agent-level backups with user self-service capabilities for both Linux VMs and Windows workstations. Key takeaways:

- **Flexible Deployment**: Choose between automatic (AD/CSV) or manual deployment methods
- **User Empowerment**: Grant appropriate self-service capabilities via full access or read-only modes
- **Centralized Control**: Maintain oversight through protection groups and policies
- **Platform Support**: Unified approach for both Linux and Windows environments
- **Scalability**: From small deployments to enterprise-wide implementations

For ongoing support:
- Veeam Help Center: https://helpcenter.veeam.com
- Community Forums: https://forums.veeam.com
- Technical Support: Contact your Veeam representative

---

>**Document Version**: 1.1  
> NOTE: Debian 13 is not supported by the community / main edition, suport will be coming soon. This will allow for full VM backups of Deiban 13 virtual machines.  
>**Last Updated**: 21:47pm - 0911/2025   

