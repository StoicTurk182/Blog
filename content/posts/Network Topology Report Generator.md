---
title: "Network Topology Report Generator"
date: 2025-11-08
draft: false
description: "Complete guide to automated network topology documentation with practical examples, best practices, and troubleshooting tips for Linux servers"
categories: ["System Administration"]
tags: ["networking", "linux", "bash", "automation", "documentation", "monitoring"]
readingTime: true
toc: true
author: "Andrew Jones"
authorImage: "/images/authors/devops-team.jpg"
authorBio: "Linux system administration and automation experts"
socialShare: true
---

# Network Topology Report Generator

**Brief introduction:** The Network Topology Report Generator is a comprehensive bash script that automatically documents your entire network infrastructure. Whether you're managing VPS servers, home labs, or enterprise networks, this tool creates detailed reports covering interfaces, routing, VPN connections, firewall rules, Docker networks, and active services. Perfect for troubleshooting, documentation, compliance audits, or understanding inherited infrastructure.

I created this as a vanity project as I really like seeing changes in my network and I had the idea to create it, I am unsure as to it utility outside of my use case but I did have a lot of fun troubleshooting it. 

## Overview
---

The Network Topology Report Generator is a single bash script that collects and organizes comprehensive network configuration data from Linux systems. It produces human-readable reports that include visual ASCII diagrams, making complex network setups easy to understand at a glance.

This tool is invaluable when:
- Documenting existing infrastructure
- Troubleshooting network connectivity issues
- Planning infrastructure changes
- Diagnosing service availability problems

### Why Use Network Topology Report Generator?
---

- **Complete Visibility**: Captures everything from physical interfaces to virtual Docker networks and VPN tunnels
- **Zero Dependencies**: Uses only standard Linux utilities available on most distributions
- **Automated Documentation**: Generates consistent, detailed reports in seconds vs hours of manual work
- **Visual Diagrams**: Includes ASCII topology diagrams that make complex networks easy to understand
- **Troubleshooting Ready**: Shows active connections, listening services, and firewall rules in one place
- **Version Control Friendly**: Plain text output perfect for git repositories and change tracking

## Prerequisites
---

Before you begin, ensure you have the following:

- **Linux Operating System**: Tested on Ubuntu 20.04+, Debian 11+, CentOS 7+, RHEL 8+
- **Bash Shell**: Version 4.0 or higher
- **Root/Sudo Access**: Required for full network introspection (limited info without)
- **Standard Utilities**: `ip`, `ss` or `netstat`, `awk`, `grep` (typically pre-installed)

```bash
# Verify prerequisites
bash --version  # Should be 4.0+
which ip ss awk grep

# Check if you have necessary permissions
sudo -v && echo "✅ Sudo access confirmed" || echo "❌ No sudo access"
```

## Key Features
---

### Comprehensive Network Interface Reporting
---

Captures all network interfaces including physical NICs, virtual interfaces, VPN tunnels (WireGuard, Tailscale), Docker bridges, and loopback devices. Shows IP addresses (both IPv4 and IPv6), MAC addresses, MTU values, and interface states.

### Routing and Neighbor Discovery
---

Documents complete routing tables including default gateways, static routes, and policy-based routing. Captures ARP/NDP tables showing MAC address mappings and neighbor reachability states.

### Service and Port Analysis
---

Lists all listening TCP and UDP ports with associated processes, PIDs, and protocol versions. Identifies web servers, SSH daemons, VPN endpoints, database servers, and custom services.

### Firewall Configuration Export
---

Exports complete UFW or iptables configurations showing all rules, chains, policies, and NAT configurations. Essential for security audits and troubleshooting connectivity issues.

### VPN Status Reporting
---

Detailed WireGuard peer information including handshake times, allowed IPs, endpoints, and data transfer statistics. Tailscale interface status with IP assignments and DNS configuration.

### Docker Network Integration
---

Maps Docker networks, containers, IP address assignments, and network drivers. Shows bridge networks, overlay networks, and custom network configurations.

### Samba/SMB Connection Tracking
---

Lists active Samba connections with usernames, client IPs, mounted shares, protocol versions, and file locks. Perfect for troubleshooting file server issues.

### Visual ASCII Topology Diagrams
---

Automatically generates hierarchical network diagrams showing the relationship between internet gateways, public interfaces, VPNs, Docker networks, and active connections.

## Installation & Setup
---

### Step 1: Download the Script
---

```bash
# Download directly
wget https://example.com/network_topology_report.sh

# Or clone from repository
git clone https://github.com/yourrepo/network-tools.git
cd network-tools
```

### Step 2: Make Executable
---

```bash
# Set execute permissions
chmod +x network_topology_report.sh

# Optionally, move to system path
sudo cp network_topology_report.sh /usr/local/bin/network-report
```

### Step 3: Verify Installation
---

```bash
# Test basic execution (without sudo - limited info)
./network_topology_report.sh --help

# Full test with sudo
sudo ./network_topology_report.sh test_report.txt

# Check the output
ls -lh test_report.txt
cat test_report.txt | head -20
```

## Configuration Options
---

The script accepts minimal command-line options to keep it simple:
```bash
| Option | Description | Default | Example |
|--------|------------|---------|---------|
| `filename` | Output filename | `network_topology_report_HOSTNAME_TIMESTAMP.txt` | `my_network.txt` |
| `--help` | Show usage information | N/A | `./script.sh --help` |

### Environment Variables
---

You can customize behavior via environment variables:

```bash
# Disable color output
export NO_COLOR=1

# Change default output directory
export REPORT_DIR=/var/reports/network

# Example usage
sudo NO_COLOR=1 ./network_topology_report.sh
```

### Customization via Script Editing
---

For advanced users, edit the script directly:

```bash
# Edit to change default behavior
nano network_topology_report.sh

# Key variables to customize:
# - OUTPUT_FILE: Default output location
# - Color codes: RED, GREEN, YELLOW, BLUE
# - Section inclusion: Comment out sections you don't need
```

## Usage Examples
---

### Basic Usage
---

Generate a report with default filename:

```bash
# Simple execution (creates auto-named file)
sudo ./network_topology_report.sh

# Output: network_topology_report_hostname_20251108_143022.txt
```

Expected output:
```text
Network topology report generated: network_topology_report_vps-server_20251108_143022.txt
View with: cat network_topology_report_vps-server_20251108_143022.txt
```

### Intermediate Usage
---

#### Use Case 1: Named Report for Documentation
---

```bash
# Generate report with specific name
sudo ./network_topology_report.sh production_network_audit_2025.txt

# Store in specific directory
sudo ./network_topology_report.sh /var/reports/network/baseline.txt
```

#### Use Case 2: Regular Monitoring Setup
---

```bash
# Daily report with timestamp
sudo ./network_topology_report.sh "network_$(date +%Y%m%d).txt"

# Weekly baseline for comparison
sudo ./network_topology_report.sh /var/backups/network_baseline.txt
```

#### Use Case 3: Quick Status Check
---

```bash
# Pipe specific sections to terminal
sudo ./network_topology_report.sh /tmp/quick.txt && grep -A 20 "ACTIVE CONNECTIONS" /tmp/quick.txt

# Check only firewall status
sudo ./network_topology_report.sh /tmp/fw.txt && grep -A 50 "FIREWALL STATUS" /tmp/fw.txt
```

### Advanced Usage
---

#### Complex Scenario 1: Multi-Server Fleet Documentation
---

Document entire server fleet with coordinated naming:

```bash
#!/bin/bash
# fleet_network_audit.sh

SERVERS=("web-01" "web-02" "db-01" "cache-01")
DATE=$(date +%Y%m%d)
OUTPUT_DIR="/reports/fleet_audit_${DATE}"

mkdir -p "$OUTPUT_DIR"

for server in "${SERVERS[@]}"; do
    echo "Documenting $server..."
    ssh root@$server 'bash -s' < network_topology_report.sh > "${OUTPUT_DIR}/${server}_network.txt"
done

echo "Fleet audit complete: $OUTPUT_DIR"
```

#### Complex Scenario 2: Change Detection and Alerting
---

Compare reports to detect configuration changes:

```bash
#!/bin/bash
# network_change_detection.sh

BASELINE="/var/baselines/network_baseline.txt"
CURRENT="/tmp/network_current.txt"

# Generate current report
sudo ./network_topology_report.sh "$CURRENT"

# Compare to baseline
if diff -u "$BASELINE" "$CURRENT" > /tmp/network_diff.txt; then
    echo "✅ No network changes detected"
else
    echo "⚠️  Network changes detected!"
    cat /tmp/network_diff.txt
    
    # Send alert
    mail -s "Network Configuration Changed" admin@example.com < /tmp/network_diff.txt
    
    # Update baseline if changes are expected
    # cp "$CURRENT" "$BASELINE"
fi
```

#### Complex Scenario 3: Incident Documentation
---

Capture network state during incident investigation:

```bash
#!/bin/bash
# incident_snapshot.sh

INCIDENT_ID="INC-12345"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
INCIDENT_DIR="/incidents/${INCIDENT_ID}/network_snapshots"

mkdir -p "$INCIDENT_DIR"

echo "Capturing network snapshot for incident $INCIDENT_ID..."

# Initial snapshot
sudo ./network_topology_report.sh "${INCIDENT_DIR}/snapshot_${TIMESTAMP}_initial.txt"

# Continuous monitoring during incident (every 5 minutes for 1 hour)
for i in {1..12}; do
    sleep 300
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    sudo ./network_topology_report.sh "${INCIDENT_DIR}/snapshot_${TIMESTAMP}.txt"
    echo "Snapshot $i/12 completed"
done

echo "Incident documentation complete: $INCIDENT_DIR"
```

## Automation & Scheduling
---

### Using Cron
---

Set up automated daily/weekly reports:

```bash
# Edit crontab
crontab -e

# Daily baseline at 2 AM
0 2 * * * /usr/local/bin/network-report /var/reports/daily/network_$(date +\%Y\%m\%d).txt 2>&1 | logger -t network-report

# Weekly detailed audit (Sunday at 3 AM)
0 3 * * 0 /usr/local/bin/network-report /var/reports/weekly/network_week_$(date +\%U).txt && find /var/reports/weekly -mtime +90 -delete

# Hourly change detection
0 * * * * /usr/local/bin/network_change_detection.sh

# Before/after maintenance windows
# Add these manually before scheduled maintenance
```

### Using Systemd Timer
---

Create a systemd service and timer for more control:

```ini
# /etc/systemd/system/network-report.service
[Unit]
Description=Network Topology Report Generator
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
User=root
ExecStart=/usr/local/bin/network-report /var/reports/network/latest.txt
ExecStartPost=/bin/bash -c 'cp /var/reports/network/latest.txt /var/reports/network/network_$(date +\%%Y\%%m\%%d_\%%H\%%M\%%S).txt'
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

```ini
# /etc/systemd/system/network-report.timer
[Unit]
Description=Network Report Timer - Daily at 2 AM
Requires=network-report.service

[Timer]
OnCalendar=daily
OnCalendar=02:00
Persistent=true

[Install]
WantedBy=timers.target

Enable and start the timer:
```



```bash
# Enable the timer
sudo systemctl daemon-reload
sudo systemctl enable network-report.timer
sudo systemctl start network-report.timer

# Check status
sudo systemctl status network-report.timer
sudo systemctl list-timers --all | grep network-report

# Test manually
sudo systemctl start network-report.service
sudo journalctl -u network-report.service -n 50
```

### Using Scripts for Pre/Post Deployment
---

```bash
#!/bin/bash
# deployment_wrapper.sh

DEPLOY_ID="deploy_$(date +%Y%m%d_%H%M%S)"
REPORT_DIR="/deployments/${DEPLOY_ID}"

mkdir -p "$REPORT_DIR"

# Capture PRE-deployment state
echo "📸 Capturing PRE-deployment network state..."
sudo /usr/local/bin/network-report "${REPORT_DIR}/pre_deployment.txt"

# Run your deployment
echo "🚀 Running deployment..."
./run_deployment.sh

# Capture POST-deployment state
echo "📸 Capturing POST-deployment network state..."
sudo /usr/local/bin/network-report "${REPORT_DIR}/post_deployment.txt"

# Compare states
echo "🔍 Analyzing changes..."
diff -u "${REPORT_DIR}/pre_deployment.txt" "${REPORT_DIR}/post_deployment.txt" > "${REPORT_DIR}/deployment_changes.diff"

if [ $? -eq 0 ]; then
    echo "✅ No unexpected network changes"
else
    echo "⚠️  Network configuration changed during deployment"
    echo "Review: ${REPORT_DIR}/deployment_changes.diff"
fi

# Create deployment summary
cat > "${REPORT_DIR}/README.md" <<EOF
# Deployment: ${DEPLOY_ID}

**Date**: $(date)
**User**: ${USER}

## Files
---
- pre_deployment.txt: Network state before deployment
- post_deployment.txt: Network state after deployment
- deployment_changes.diff: Detected changes

## Quick Stats
---
- Pre-deployment connections: $(grep -c "ESTAB" "${REPORT_DIR}/pre_deployment.txt")
- Post-deployment connections: $(grep -c "ESTAB" "${REPORT_DIR}/post_deployment.txt")
EOF

echo "📋 Deployment documentation: ${REPORT_DIR}"
```

## Best Practices
---

1. **Regular Baseline Updates**: Generate and store baseline reports weekly or after approved changes to use for comparison during troubleshooting

2. **Secure Storage**: Store reports in secure locations with restricted access as they contain sensitive network configuration details including VPN keys and internal IP addressing

3. **Version Control Integration**: Commit sanitized reports (with secrets removed) to git for infrastructure-as-code repositories to track configuration drift over time

4. **Automated Monitoring**: Combine with change detection scripts to automatically alert on unexpected network configuration changes

5. **Incident Response**: Include report generation as first step in incident response runbooks to capture network state before investigation changes anything

6. **Documentation Updates**: Re-generate reports after every infrastructure change and update your network documentation accordingly

7. **Retention Policy**: Implement automated cleanup to maintain reports for compliance periods (typically 90 days to 7 years depending on industry)

8. **Sanitization for Sharing**: Always redact sensitive information (public IPs, VPN keys, internal network details) before sharing reports externally



> ⚠️ **IMPORTANT SECURITY DISCLAIMER**

The information that is pulled is to be treated as OPSEC in the extreme!

> #### Do's!
- Run with sudo for complete information
- Generate reports before and after major changes
- Store reports in backed-up locations
- Review reports regularly for unexpected changes
- Include reports in post-mortem documentation
- Automate report generation for consistency

> #### Don'ts! 
- Never commit unsanitized reports to public repositories
- Avoid running without sudo (provides incomplete data)
- Don't delete old reports without retention policy
- Never share reports containing production secrets
- Don't ignore failed sections (investigate why they failed)
- Avoid manual report creation (always use automation)
> 
> This script is for **educational and authorized testing purposes only**. 

## Performance Optimization
---

### Tip 1: Parallel Collection
---

For faster execution on systems with many interfaces:

```bash
# Modify script to run some commands in parallel
# Example optimization inside script:
{
    ip addr show > /tmp/ip_addr.txt &
    ip route show > /tmp/ip_route.txt &
    ss -tulpn > /tmp/ss_output.txt &
    wait
} 2>/dev/null
```

### Tip 2: Selective Sections
---

Comment out sections you don't need for faster execution:

```bash
# Edit the script and comment out Docker section if not using Docker
# if command_exists docker; then
#     print_header "DOCKER NETWORKS"
#     docker network ls 2>/dev/null
# fi
```

### Tip 3: Output Compression
---

For large fleets, compress reports automatically:

```bash
# Generate and compress
sudo ./network_topology_report.sh report.txt && gzip report.txt

# Compressed storage saves 80-90% space
ls -lh report.txt.gz
```

### Benchmarking
---

Measure script execution time:

```bash
# Time the execution
time sudo ./network_topology_report.sh /tmp/benchmark.txt

# Typical execution times:
# Basic VPS: 1-2 seconds
# Docker host: 3-5 seconds
# Complex setup: 5-10 seconds

# Profile which sections are slow
bash -x ./network_topology_report.sh 2>&1 | grep "print_header" | ts -i "%.s"
```

## Troubleshooting
---

### Common Issues
---

#### Issue 1: "Permission denied" Errors
---

**Symptoms:**
- Script runs but many sections show "not accessible" or are empty
- WireGuard section shows "not accessible"
- Firewall section is incomplete

**Solution:**
```bash
# Always run with sudo for complete information
sudo ./network_topology_report.sh output.txt

# Check sudo permissions
sudo -v

# If sudo not available, request root access
su -
./network_topology_report.sh output.txt
exit
```

#### Issue 2: "Command not found" Warnings
---

**Symptoms:**
- Warning messages about missing commands (`ip`, `ss`, `docker`, etc.)
- Some sections completely missing from report

**Solution:**
```bash
# Install missing networking tools
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install iproute2 net-tools

# RHEL/CentOS
sudo yum install iproute net-tools

# Verify installation
which ip ss netstat docker wg

# The script gracefully degrades - missing tools won't break it
# But you'll get incomplete information
```

#### Issue 3: Docker Commands Fail
---

**Symptoms:**
- Docker section empty despite Docker being installed
- "Cannot connect to Docker daemon" errors

**Solution:**
```bash
# Ensure Docker service is running
sudo systemctl status docker
sudo systemctl start docker

# Check Docker socket permissions
ls -l /var/run/docker.sock

# Add user to docker group (requires logout/login)
sudo usermod -aG docker $USER

# Or always use sudo
sudo ./network_topology_report.sh
```

#### Issue 4: Output File is Empty or Truncated
---

**Symptoms:**
- Output file created but contains no data or cuts off mid-section
- "Disk quota exceeded" or "No space left" errors

**Solution:**
```bash
# Check available disk space
df -h

# Check output directory permissions
ls -ld /path/to/output/directory

# Try writing to /tmp (usually has space)
sudo ./network_topology_report.sh /tmp/network_report.txt

# Check disk quota
quota -v
```

#### Issue 5: WireGuard Section Shows "Not accessible"
---

**Symptoms:**
- WireGuard is running but status not captured
- "Operation not permitted" for wg command

**Solution:**
```bash
# Verify WireGuard is installed
which wg

# Run with sudo
sudo ./network_topology_report.sh

# Check WireGuard interface status
sudo wg show

# Ensure kernel module loaded
lsmod | grep wireguard
```

### Debugging Commands
---

```bash
# Enable bash debug mode to see what's executing
bash -x ./network_topology_report.sh 2>&1 | tee debug.log

# Check which commands are available
for cmd in ip ss docker wg ufw; do
    which $cmd && echo "✅ $cmd found" || echo "❌ $cmd missing"
done

# Test individual sections manually
ip addr show
sudo ss -tulpn
sudo wg show
sudo ufw status

# Verify script syntax
bash -n ./network_topology_report.sh && echo "✅ Syntax OK" || echo "❌ Syntax error"

# Check file permissions
ls -l ./network_topology_report.sh
# Should show -rwxr-xr-x (executable)
```

### Getting Help
---

```bash
# Check script version (if versioned)
./network_topology_report.sh --version

# View script contents to understand logic
less ./network_topology_report.sh

# Search for specific functions
grep "function\|print_header" ./network_topology_report.sh

# Online resources
# - Linux networking: man ip, man ss
# - WireGuard: https://www.wireguard.com/
# - Docker networking: https://docs.docker.com/network/
# - UFW firewall: man ufw
```

## Security Considerations
---

### Important Security Notes
---

- **Sensitive Information**: Reports contain sensitive data including internal IP addresses, VPN configurations, network topology, and service information
- **VPN Keys**: WireGuard public keys are included (private keys are never exposed)
- **Access Control**: Restrict report storage locations to administrators only (chmod 600)
- **Credential Exposure**: Samba usernames and connected clients are logged
- **Public Disclosure**: Never commit unsanitized reports to public repositories
- **Compliance**: Reports may contain data subject to compliance regulations (GDPR, HIPAA, PCI-DSS)

### Secure Configuration Example
---

```bash
# Create secure directory for reports
sudo mkdir -p /var/reports/network
sudo chmod 700 /var/reports/network
sudo chown root:root /var/reports/network

# Generate report with secure permissions
sudo ./network_topology_report.sh /var/reports/network/$(date +%Y%m%d).txt
sudo chmod 600 /var/reports/network/*.txt

# Verify permissions
ls -la /var/reports/network/

# Set up log rotation with encryption
cat > /etc/logrotate.d/network-reports <<EOF
/var/reports/network/*.txt {
    monthly
    rotate 12
    compress
    delaycompress
    missingok
    notifempty
    create 600 root root
    postrotate
        # Optionally encrypt old reports
        find /var/reports/network -name "*.txt.1.gz" -exec gpg --encrypt --recipient admin@example.com {} \;
    endscript
}
EOF
```

### Sanitizing Reports for Sharing
---

```bash
#!/bin/bash
# sanitize_report.sh - Remove sensitive data before sharing

INPUT="$1"
OUTPUT="${INPUT%.txt}_sanitized.txt"

cp "$INPUT" "$OUTPUT"

# Replace public IPs with placeholders
sed -i 's/[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}/XXX.XXX.XXX.XXX/g' "$OUTPUT"

# Replace IPv6 addresses
sed -i 's/[0-9a-f:]\{10,\}/XXXX:XXXX:XXXX:XXXX/g' "$OUTPUT"

# Replace MAC addresses
sed -i 's/[0-9a-f]\{2\}:[0-9a-f]\{2\}:[0-9a-f]\{2\}:[0-9a-f]\{2\}:[0-9a-f]\{2\}:[0-9a-f]\{2\}/XX:XX:XX:XX:XX:XX/g' "$OUTPUT"

# Replace WireGuard keys
sed -i 's/\b[A-Za-z0-9+/]\{43\}=\b/XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX=/g' "$OUTPUT"

# Replace hostnames
sed -i "s/$(hostname)/HOSTNAME/g" "$OUTPUT"

echo "Sanitized report created: $OUTPUT"
echo "⚠️  Always manually review before sharing!"
```

## Integration with Other Tools
---

### Integration 1: Ansible Inventory
---

Use reports to verify Ansible inventory accuracy:

```yaml
# playbook_verify_network.yml
---
- name: Verify Network Configuration
  hosts: all
  tasks:
    - name: Generate network report
      script: /path/to/network_topology_report.sh /tmp/network_report.txt
      become: yes
      
    - name: Fetch report
      fetch:
        src: /tmp/network_report.txt
        dest: reports/{{ inventory_hostname }}_network.txt
        flat: yes
        
    - name: Verify expected interfaces
      shell: grep "{{ expected_interface }}" /tmp/network_report.txt
      register: interface_check
      failed_when: interface_check.rc != 0
```

### Integration 2: Monitoring Systems (Prometheus/Grafana)
---

Parse reports for metrics:

```bash
#!/bin/bash
# export_network_metrics.sh

REPORT="/tmp/network_report.txt"
sudo ./network_topology_report.sh "$REPORT"

# Extract metrics
LISTENING_PORTS=$(grep -c "LISTEN" "$REPORT")
ESTABLISHED_CONN=$(grep -c "ESTAB" "$REPORT")
INTERFACES=$(grep -c "^[0-9]*: " "$REPORT")

# Export to node_exporter textfile collector
cat > /var/lib/node_exporter/network_report.prom <<EOF
# HELP network_listening_ports Number of listening ports
# TYPE network_listening_ports gauge
network_listening_ports $LISTENING_PORTS

# HELP network_established_connections Number of established connections
# TYPE network_established_connections gauge
network_established_connections $ESTABLISHED_CONN

# HELP network_interfaces Total number of network interfaces
# TYPE network_interfaces gauge
network_interfaces $INTERFACES
EOF
```

### Integration 3: Git-based Infrastructure Documentation
---

Automated infrastructure-as-documentation:

```bash
#!/bin/bash
# infra_docs_update.sh

DOCS_REPO="/path/to/infrastructure-docs"
REPORT_DIR="$DOCS_REPO/network-topology"

cd "$DOCS_REPO"

# Generate reports for all environments
for env in production staging development; do
    echo "Documenting $env..."
    
    # SSH to environment and generate report
    ssh admin@${env}.example.com 'sudo bash -s' < network_topology_report.sh > "${REPORT_DIR}/${env}_network.txt"
    
    # Sanitize before committing
    ./sanitize_report.sh "${REPORT_DIR}/${env}_network.txt"
done

# Commit changes
git add ${REPORT_DIR}/*.txt
git commit -m "Network topology update: $(date +%Y-%m-%d)"
git push origin main
```

### Integration 4: Slack/Teams Notifications
---

Alert on significant changes:

```bash
#!/bin/bash
# network_alert.sh

WEBHOOK_URL="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
REPORT="/tmp/network_current.txt"
BASELINE="/var/baselines/network_baseline.txt"

sudo ./network_topology_report.sh "$REPORT"

if ! diff -q "$BASELINE" "$REPORT" > /dev/null; then
    # Extract changes
    CHANGES=$(diff "$BASELINE" "$REPORT" | grep "^[<>]" | head -20)
    
    # Send Slack notification
    curl -X POST -H 'Content-type: application/json' \
        --data "{
            \"text\": \"⚠️ Network Configuration Changed\",
            \"attachments\": [{
                \"color\": \"warning\",
                \"fields\": [{
                    \"title\": \"Server\",
                    \"value\": \"$(hostname)\",
                    \"short\": true
                }, {
                    \"title\": \"Timestamp\",
                    \"value\": \"$(date)\",
                    \"short\": true
                }],
                \"text\": \"\`\`\`${CHANGES}\`\`\`\"
            }]
        }" \
        "$WEBHOOK_URL"
fi
```

## Quick Reference
---

### Essential Commands
---

```bash
# Basic usage
sudo ./network_topology_report.sh

# Named output
sudo ./network_topology_report.sh my_report.txt

# Specific directory
sudo ./network_topology_report.sh /var/reports/network.txt

# Quick view after generation
sudo ./network_topology_report.sh /tmp/report.txt && less /tmp/report.txt

# Compare two reports
diff -u baseline.txt current.txt | less

# Extract specific sections
grep -A 50 "ACTIVE CONNECTIONS" report.txt
grep -A 100 "VISUAL NETWORK TOPOLOGY" report.txt
grep -A 30 "FIREWALL STATUS" report.txt

# Count connections by type
grep ESTAB report.txt | wc -l
grep LISTEN report.txt | wc -l

# Find specific services
grep -i "port.*80\|port.*443" report.txt
grep -i "docker" report.txt
```

### Environment Variables
---

```bash
# Disable colored output
export NO_COLOR=1

# Set custom report directory
export REPORT_DIR=/custom/path/reports

# Example combined usage
NO_COLOR=1 sudo ./network_topology_report.sh
```

### Useful Aliases
---

Add to your `~/.bashrc` or `~/.zshrc`:

```bash
# Quick network report
alias netreport='sudo /usr/local/bin/network-report'

# Report to specific location
alias netdoc='sudo /usr/local/bin/network-report /var/reports/network/latest.txt'

# Quick view
alias netview='sudo /usr/local/bin/network-report /tmp/net.txt && less /tmp/net.txt'

# Compare with baseline
alias netdiff='sudo /usr/local/bin/network-report /tmp/current.txt && diff -u /var/baselines/network.txt /tmp/current.txt | less'

# Extract topology diagram
alias nettopo='sudo /usr/local/bin/network-report /tmp/net.txt && grep -A 200 "VISUAL NETWORK TOPOLOGY" /tmp/net.txt'
```

## Real-World Examples
---

### Example 1: Production VPS Setup
---

Complete documentation workflow for production environment:

```bash
#!/bin/bash
# production_network_baseline.sh

# Production server: web-prod-01
# Purpose: Create baseline network documentation
# Schedule: Run during maintenance window

HOSTNAME=$(hostname)
DATE=$(date +%Y%m%d_%H%M%S)
REPORT_DIR="/opt/infrastructure-docs/network"
BASELINE="$REPORT_DIR/baseline"
ARCHIVE="$REPORT_DIR/archive"

# Ensure directories exist
mkdir -p "$BASELINE" "$ARCHIVE"

# Generate comprehensive report
echo "🔍 Generating network topology report for $HOSTNAME..."
sudo /usr/local/bin/network-report "$BASELINE/${HOSTNAME}_baseline.txt"

# Create timestamped archive
cp "$BASELINE/${HOSTNAME}_baseline.txt" "$ARCHIVE/${HOSTNAME}_${DATE}.txt"
gzip "$ARCHIVE/${HOSTNAME}_${DATE}.txt"

# Create summary
cat > "$BASELINE/${HOSTNAME}_summary.md" <<EOF
# Network Baseline: $HOSTNAME

**Generated**: $(date)
**Administrator**: ${USER}

## Quick Stats
---
- **Interfaces**: $(grep -c "^[0-9]*:" "$BASELINE/${HOSTNAME}_baseline.txt")
- **Listening Services**: $(grep -c "LISTEN" "$BASELINE/${HOSTNAME}_baseline.txt")
- **Active Connections**: $(grep -c "ESTAB" "$BASELINE/${HOSTNAME}_baseline.txt")
- **Firewall Rules**: $(grep -c "ALLOW\|DENY" "$BASELINE/${HOSTNAME}_baseline.txt")

## VPN Status
---
$(grep -A 10 "WIREGUARD STATUS" "$BASELINE/${HOSTNAME}_baseline.txt" | tail -8)

## Services
---
\`\`\`
$(grep "tcp.*LISTEN" "$BASELINE/${HOSTNAME}_baseline.txt" | head -10)
\`\`\`

## Next Review
---
Scheduled for: $(date -d "+30 days" +%Y-%m-%d)
EOF

echo "✅ Baseline documentation complete"
echo "📁 Baseline: $BASELINE/${HOSTNAME}_baseline.txt"
echo "📁 Archive: $ARCHIVE/${HOSTNAME}_${DATE}.txt.gz"
echo "📋 Summary: $BASELINE/${HOSTNAME}_summary.md"

# Set secure permissions
chmod 600 "$BASELINE"/*.txt
chmod 600 "$ARCHIVE"/*.txt.gz
```

### Example 2: Development Environment Snapshot
---

Quick documentation for development servers:

```bash
#!/bin/bash
# dev_network_snapshot.sh

# Development server documentation
# Less strict security, focus on speed and readability

DEV_DOCS="$HOME/dev-docs/network"
mkdir -p "$DEV_DOCS"

echo "📸 Capturing development network snapshot..."

# Generate report
./network_topology_report.sh "$DEV_DOCS/dev_network.txt"

# Create markdown documentation
{
    echo "# Development Network Topology"
    echo ""
    echo "**Generated**: $(date)"
    echo ""
    echo "## Visual Topology"
    echo "\`\`\`"
    grep -A 150 "VISUAL NETWORK TOPOLOGY DIAGRAM" "$DEV_DOCS/dev_network.txt" | tail -145
    echo "\`\`\`"
    echo ""
    echo "## Docker Containers"
    echo "\`\`\`"
    grep -A 30 "DOCKER NETWORKS" "$DEV_DOCS/dev_network.txt" | tail -25
    echo "\`\`\`"
    echo ""
    echo "## Listening Services"
    echo "\`\`\`"
    grep "LISTEN" "$DEV_DOCS/dev_network.txt" | grep -v "127.0.0" | sort -t: -k2 -n
    echo "\`\`\`"
} > "$DEV_DOCS/README.md"

echo "✅ Development documentation updated"
echo "📁 View: $DEV_DOCS/README.md"

# Optional: Open in browser if Markdown viewer available
if command -v grip > /dev/null; then
    grip "$DEV_DOCS/README.md" --export "$DEV_DOCS/network.html"
    echo "🌐 HTML version: $DEV_DOCS/network.html"
fi
```

### Example 3: Multi-Server Comparison
---

Compare network configurations across multiple servers:

```bash
#!/bin/bash
# multi_server_comparison.sh

# Servers to compare
SERVERS=(
    "web-01.prod.example.com"
    "web-02.prod.example.com"
    "db-01.prod.example.com"
)

REPORT_DIR="/tmp/server_comparison_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$REPORT_DIR"

echo "🔍 Comparing network topology across ${#SERVERS[@]} servers..."

# Collect reports from all servers
for server in "${SERVERS[@]}"; do
    echo "  📥 Collecting from $server..."
    ssh admin@${server} 'sudo bash -s' < network_topology_report.sh > "${REPORT_DIR}/${server}.txt" 2>&1
done

# Create comparison report
echo "📊 Generating comparison report..."

{
    echo "# Multi-Server Network Comparison"
    echo "**Generated**: $(date)"
    echo ""
    
    for server in "${SERVERS[@]}"; do
        echo "## $server"
        echo ""
        
        REPORT="${REPORT_DIR}/${server}.txt"
        
        if [ -f "$REPORT" ]; then
            echo "### Interfaces"
            IFACES=$(grep -c "^[0-9]*:" "$REPORT")
            echo "- Total interfaces: $IFACES"
            
            echo ""
            echo "### Services"
            LISTEN=$(grep -c "LISTEN" "$REPORT")
            echo "- Listening services: $LISTEN"
            
            echo ""
            echo "### Connections"
            ESTAB=$(grep -c "ESTAB" "$REPORT")
            echo "- Active connections: $ESTAB"
            
            echo ""
            echo "### Docker"
            if grep -q "DOCKER NETWORKS" "$REPORT"; then
                CONTAINERS=$(grep -c "CONTAINER:" "$REPORT")
                echo "- Containers: $CONTAINERS"
            else
                echo "- Docker: Not configured"
            fi
            
            echo ""
            echo "### VPN"
            if grep -q "wg0" "$REPORT"; then
                PEERS=$(grep -c "peer:" "$REPORT")
                echo "- WireGuard peers: $PEERS"
            else
                echo "- WireGuard: Not configured"
            fi
            
            echo ""
        else
            echo "❌ Report generation failed"
            echo ""
        fi
    done
    
    echo "---"
    echo ""
    echo "## Detailed Reports"
    echo ""
    for server in "${SERVERS[@]}"; do
        echo "- [$server](./${server}.txt)"
    done
    
} > "${REPORT_DIR}/COMPARISON.md"

echo ""
echo "✅ Comparison complete!"
echo "📁 Reports: $REPORT_DIR"
echo "📊 Comparison: ${REPORT_DIR}/COMPARISON.md"
echo ""
echo "View comparison:"
echo "  cat ${REPORT_DIR}/COMPARISON.md"
```

### Example 4: Incident Response Toolkit
---

Complete incident response network documentation:

```bash
#!/bin/bash
# incident_response_network.sh

# Emergency network documentation for incident response
# Captures multiple snapshots and critical information

if [ -z "$1" ]; then
    echo "Usage: $0 INCIDENT_ID"
    echo "Example: $0 INC-2025-001"
    exit 1
fi

INCIDENT_ID="$1"
INCIDENT_DIR="/var/incidents/${INCIDENT_ID}"
NETWORK_DIR="${INCIDENT_DIR}/network_analysis"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Create incident structure
mkdir -p "$NETWORK_DIR"/{snapshots,analysis,evidence}

echo "🚨 INCIDENT RESPONSE: Network Documentation"
echo "Incident ID: $INCIDENT_ID"
echo "Timestamp: $TIMESTAMP"
echo ""

# 1. Initial snapshot
echo "📸 [1/5] Capturing initial network state..."
sudo /usr/local/bin/network-report "${NETWORK_DIR}/snapshots/snapshot_${TIMESTAMP}_initial.txt"

# 2. Capture active connections in detail
echo "🔍 [2/5] Analyzing active connections..."
{
    echo "=== ACTIVE CONNECTIONS DETAIL ==="
    echo "Timestamp: $(date)"
    echo ""
    sudo ss -tupn
    echo ""
    echo "=== TCP CONNECTIONS ==="
    sudo ss -tn
    echo ""
    echo "=== UDP CONNECTIONS ==="
    sudo ss -un
} > "${NETWORK_DIR}/evidence/active_connections_${TIMESTAMP}.txt"

# 3. Capture firewall logs
echo "🛡️  [3/5] Collecting firewall logs..."
{
    echo "=== UFW LOGS (Last 1000 lines) ==="
    sudo tail -1000 /var/log/ufw.log
    echo ""
    echo "=== System Firewall Logs ==="
    sudo journalctl -u ufw -n 1000
} > "${NETWORK_DIR}/evidence/firewall_logs_${TIMESTAMP}.txt"

# 4. Capture process network usage
echo "📊 [4/5] Identifying network-using processes..."
{
    echo "=== PROCESS NETWORK USAGE ==="
    echo "Timestamp: $(date)"
    echo ""
    sudo lsof -i -P -n | head -100
    echo ""
    echo "=== HIGH BANDWIDTH PROCESSES ==="
    sudo iftop -t -s 5 -L 20 2>/dev/null || echo "iftop not installed"
} > "${NETWORK_DIR}/evidence/process_network_${TIMESTAMP}.txt"

# 5. Create analysis summary
echo "📋 [5/5] Generating analysis summary..."
{
    echo "# Incident Network Analysis: $INCIDENT_ID"
    echo ""
    echo "**Incident ID**: $INCIDENT_ID"
    echo "**Timestamp**: $(date)"
    echo "**Server**: $(hostname)"
    echo "**Analyst**: ${USER}"
    echo ""
    
    echo "## Summary"
    echo ""
    REPORT="${NETWORK_DIR}/snapshots/snapshot_${TIMESTAMP}_initial.txt"
    echo "- **Active Connections**: $(grep -c "ESTAB" "$REPORT")"
    echo "- **Listening Services**: $(grep -c "LISTEN" "$REPORT")"
    echo "- **Firewall Status**: $(grep "Status:" "$REPORT" | awk '{print $2}')"
    echo ""
    
    echo "## Top 10 Active Connections"
    echo "\`\`\`"
    grep "ESTAB" "$REPORT" | head -10
    echo "\`\`\`"
    echo ""
    
    echo "## Suspicious Indicators"
    echo ""
    echo "### Unusual Ports"
    echo "\`\`\`"
    grep "LISTEN" "$REPORT" | grep -v ":22\|:80\|:443\|:25\|:53" | head -20
    echo "\`\`\`"
    echo ""
    
    echo "### External Connections"
    echo "\`\`\`"
    grep "ESTAB" "$REPORT" | grep -v "127.0.0\|10\.\|172\.\|192\.168\." | head -20
    echo "\`\`\`"
    echo ""
    
    echo "## Evidence Files"
    echo "- Network snapshot: \`snapshots/snapshot_${TIMESTAMP}_initial.txt\`"
    echo "- Active connections: \`evidence/active_connections_${TIMESTAMP}.txt\`"
    echo "- Firewall logs: \`evidence/firewall_logs_${TIMESTAMP}.txt\`"
    echo "- Process analysis: \`evidence/process_network_${TIMESTAMP}.txt\`"
    echo ""
    
    echo "## Next Steps"
    echo "1. Review suspicious indicators above"
    echo "2. Compare with baseline: \`diff /var/baselines/network.txt snapshots/snapshot_${TIMESTAMP}_initial.txt\`"
    echo "3. Check for unauthorized services or connections"
    echo "4. Review firewall logs for denied connections"
    echo "5. Correlate with other system logs (auth, syslog)"
    echo ""
    
    echo "## Timeline"
    echo "- **Incident detected**: [TO BE FILLED]"
    echo "- **Documentation started**: $(date)"
    echo "- **Initial snapshot completed**: $(date)"
    echo ""
    
} > "${NETWORK_DIR}/ANALYSIS_${TIMESTAMP}.md"

# Set secure permissions
chmod -R 600 "$NETWORK_DIR"
chmod 700 "$NETWORK_DIR"

echo ""
echo "✅ Incident network documentation complete"
echo ""
echo "📁 Location: $NETWORK_DIR"
echo "📊 Analysis: ${NETWORK_DIR}/ANALYSIS_${TIMESTAMP}.md"
echo ""
echo "Quick commands:"
echo "  # View analysis"
echo "  cat ${NETWORK_DIR}/ANALYSIS_${TIMESTAMP}.md"
echo ""
echo "  # Compare with baseline"
echo "  diff /var/baselines/network.txt ${NETWORK_DIR}/snapshots/snapshot_${TIMESTAMP}_initial.txt"
echo ""
echo "  # View active connections"
echo "  less ${NETWORK_DIR}/evidence/active_connections_${TIMESTAMP}.txt"
```

## Additional Resources
---

### Official Documentation
---
- [Linux Networking Guide](https://tldp.org/LDP/nag2/index.html) - Comprehensive networking documentation
- [iproute2 Documentation](https://wiki.linuxfoundation.org/networking/iproute2) - Modern Linux networking tools
- [WireGuard Documentation](https://www.wireguard.com/quickstart/) - VPN setup and configuration
- [Docker Networking](https://docs.docker.com/network/) - Container networking guide

### Community Resources
---
- [/r/linuxadmin](https://reddit.com/r/linuxadmin) - Linux system administration community
- [Unix & Linux Stack Exchange](https://unix.stackexchange.com/) - Q&A for networking issues
- [Server Fault](https://serverfault.com/) - Professional server administration Q&A

### Related Tools
---
- **netstat**: Legacy network statistics tool (still widely used)
- **tcpdump**: Packet capture and analysis for deep debugging
- **nmap**: Network discovery and security auditing
- **iperf3**: Network performance testing and bandwidth measurement
- **mtr**: Network diagnostic tool combining ping and traceroute
- **Wireshark**: GUI packet analyzer for detailed traffic inspection

### Further Reading
---
- [Linux Network Administrator's Guide](https://tldp.org/LDP/nag2/nag2.pdf) - Complete network admin reference
- [TCP/IP Illustrated](https://www.amazon.com/TCP-Illustrated-Vol-Addison-Wesley-Professional/dp/0201633469) - Deep dive into networking protocols
- [DevOps Handbook](https://itrevolution.com/product/the-devops-handbook/) - Infrastructure automation best practices
- [Site Reliability Engineering](https://sre.google/books/) - Google's approach to infrastructure management

## Conclusion
---

The Network Topology Report Generator provides a powerful, zero-dependency solution for documenting and understanding Linux network infrastructure. By automating the collection of interface configurations, routing tables, firewall rules, VPN connections, and active services, it saves hours of manual work while ensuring consistency and completeness.

Whether you're troubleshooting connectivity issues, documenting a new environment, preparing for an audit, or responding to an incident, this tool gives you instant visibility into your network configuration. The visual topology diagrams make complex setups immediately understandable, while the detailed sections provide the technical depth needed for serious investigation.

By incorporating this script into your regular operational workflows—through cron jobs, systemd timers, or deployment pipelines—you'll build a valuable historical record of your network's evolution. When combined with version control and change detection, you'll have powerful infrastructure-as-code documentation that catches configuration drift before it causes problems.

### What's Next?
---

- **Expand Coverage**: Modify the script to capture additional services relevant to your environment (nginx, postgresql, redis)
- **Build Dashboards**: Parse reports to extract metrics for Grafana/Prometheus visualization
- **Automate Compliance**: Create compliance checking scripts that verify network configuration against security policies
- **Integrate with ITSM**: Feed reports into your ticketing system for automatic incident context
- **Develop Alerting**: Build change detection systems that notify on unexpected network modifications

---

*Last updated: 2025-11-08*

*Found an error or have a suggestion? Feel free to contribute improvements or report issues.**Found an error or have a suggestion? [Please open an issue](https://github.com/StoicTurk182/Blog) or submit a pull request.*