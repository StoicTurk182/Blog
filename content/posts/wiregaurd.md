---
title: "Building a Safe WireGuard Peer Management Script"
date: 2025-11-20
draft: false
description: "A comprehensive bash script for managing WireGuard VPN peers with automatic backups, split-tunnel support, and interactive mode for safe infrastructure management."
categories: ["Infrastructure", "Networking"]
tags: ["wireguard", "vpn", "networking", "bash", "automation", "infrastructure", "system-administration"]
featuredImage: "/images/posts/wg.png"
readingTime: true
toc: true
author: "Andrew Jones"
authorBio: "IT professional documenting infrastructure and network management"
socialShare: true
---

## The Problem with Manual WireGuard Management ##
---

Managing WireGuard peers manually can be error-prone. After accidentally deleting an active peer with my old management script, I needed something better - a tool that would never overwrite existing configurations and always create backups before making changes. This makes adding new devices to my personal network much easier. Also it is worth mentioning that this allows you to set the parameters for you specific devices in accordance to the use case without the need to do this manually. 

For example DNS traffic does not need to be passed through a device that is only operating in split tunnel mode. My mobile device is used for various remote management tasks but DNS is handled externally to the WireGuard interface this prevents issues like not being able to access the wider internet because 2 DNS servers are being called within the same network at the same time. 

There can be only one primary DNS, for a more detailed explanation please review the sections below. I cannot overstate how frustrating this issue can be when you cannot identify the problem. 

```bash
> Without WireGuard (Normal):
Primary Interface (WiFi/Ethernet)
├─ IP: 192.168.1.100
├─ Gateway: 192.168.1.1
└─ DNS: 192.168.1.1 or ISP DNS
   └─ All DNS queries → Primary interface DNS
> With WireGuard DNS Configured:
Primary Interface (WiFi/Ethernet)        WireGuard Interface (wg0)
├─ IP: 192.168.1.100                    ├─ IP: 10.0.0.5
├─ Gateway: 192.168.1.1                 ├─ Routes: 10.0.0.0/24 only
└─ DNS: 192.168.1.1                     └─ DNS: 1.1.1.1, 1.0.0.1
                                           └─ Tries to become PRIMARY DNS
```



## Why DNS Configuration Breaks Split-Tunnel Mode
---

---

**The Intent of Split-Tunnel**

In split-tunnel mode, only traffic destined for your internal network (10.0.0.0/24) should route through the WireGuard VPN. All other traffic - web browsing, email, general internet use - should continue using your device's normal network connection. This is controlled by the `AllowedIPs = 10.0.0.0/24` setting in the client configuration.

**What the DNS Setting Does**

When you include `DNS = 1.1.1.1, 1.0.0.1` in the WireGuard interface configuration, you're instructing the operating system to:
1. Use these DNS servers for all DNS lookups when the VPN is active
2. Route DNS queries (UDP port 53) to these servers
3. Reconfigure the system's DNS resolver to prioritize these servers

**The Routing Conflict**

Here's where the problem occurs:

1. **DNS servers are outside your tunnel range**: 1.1.1.1 and 1.0.0.1 are public Cloudflare DNS servers, not part of 10.0.0.0/24
2. **Split-tunnel only routes 10.0.0.0/24**: Your routing table says "only 10.0.0.x traffic goes through WireGuard"
3. **DNS queries need to reach 1.1.1.1**: But 1.1.1.1 isn't in the 10.0.0.0/24 range
4. **OS gets confused**: The system tries to send DNS queries to servers it can't route to through the tunnel

**What Actually Happens**

Different operating systems handle this conflict differently:

- **Windows/macOS**: May ignore the split-tunnel `AllowedIPs` and start routing additional traffic through the VPN to reach the DNS servers, defeating the purpose of split-tunnel
- **Linux**: May fail DNS resolution entirely because it can't route to the specified DNS servers through the tunnel
- **iOS/Android**: Often try to use the VPN DNS for all queries, causing intermittent failures when those queries can't complete
- **All platforms**: DNS lookups become unreliable - sometimes working (when using the VPN DNS), sometimes failing (when routing conflicts occur)

**The Cascading Effect**

Even though you only want to access 10.0.0.50:3389 (your RDP server), here's what happens:

1. You type a website like `google.com` in your browser
2. Your device needs to resolve `google.com` to an IP address
3. It tries to use 1.1.1.1 (the VPN DNS)
4. **Routing problem**: Can't reach 1.1.1.1 through the tunnel (not in 10.0.0.0/24)
5. **OS workaround**: Tries to route more traffic through VPN or fails the lookup entirely
6. **Result**: Internet access breaks or becomes unreliable

**Why This Affects Infrastructure Use**

For your use case (RDP, SSH, databases), you're connecting to services by IP address:
- RDP: `mstsc 10.0.0.50:3389`
- SSH: `ssh user@10.0.0.20`
- Database: `mysql -h 10.0.0.30`

These don't require DNS lookups at all. But the moment your device tries to do *anything* else (check email, browse documentation, download updates), it needs DNS for those internet addresses, and the conflict triggers.

**The Solution: Omit DNS in Split-Tunnel**

By commenting out or removing the DNS line:
```ini
# DNS = 1.1.1.1, 1.0.0.1  # Omitted for split-tunnel
```

Your device behavior becomes:
1. **VPN DNS**: Not configured, so system uses its existing DNS settings
2. **Routing table**: Only 10.0.0.0/24 goes through VPN (as intended)
3. **Internet DNS**: Uses your normal network connection (WiFi DNS, cellular DNS, etc.)
4. **Internal IPs**: Still work perfectly (10.0.0.x doesn't need DNS)
5. **No conflicts**: Internet and VPN traffic stay completely separate

**Real-World Impact**

**With DNS configured (broken):**
- Mobile device connects to VPN for RDP access
- After connecting, internet stops working
- Apps fail to load
- Must disconnect VPN to browse web
- Reconnect VPN for RDP, disconnect for everything else

**Without DNS configured (working):**
- Mobile device connects to VPN for RDP access
- RDP works: `10.0.0.50:3389` routes through tunnel
- Internet still works: Uses cellular/WiFi DNS and routing
- Can simultaneously access internal servers AND browse web
- VPN stays connected, no conflicts

**When You DO Want DNS in VPN Config**

DNS should only be included for **full-tunnel mode** where `AllowedIPs = 0.0.0.0/0` routes ALL traffic through the VPN:
- The VPN becomes your internet gateway
- DNS servers are reachable because all traffic goes through the tunnel
- You want privacy/security for all internet activity
- Use case: Remote workers, public WiFi protection, bypassing restrictions

**Summary**

Split-tunnel DNS conflicts occur because you're telling the OS to use DNS servers (1.1.1.1) that 
exist outside your tunnel's routing range (10.0.0.0/24), while simultaneously telling it to only route 
10.0.0.0/24 through the tunnel. This creates irreconcilable routing conflicts that break internet connectivity. 
For infrastructure-only VPN connections, omit DNS entirely - your device's existing DNS configuration handles internet lookups, 
while IP-based internal services work without any DNS requirements.

## What I Built
---

I created a comprehensive WireGuard peer management script with several key safety features this is drop in an use no special configuration or setup so long as the path for the wg0.conf is /etc/wiregaurd you should be good to run the script, you can move the .sh file to the /bin directory for seamless execution but I like to be very deliberate when running script, this helps me remember where they all are:

- **Automatic backups** before every configuration change
- **Append-only mode** to prevent accidental peer deletion
- **Split-tunnel by default** for infrastructure-only connections
- **Interactive mode** for guided setup
- **IP conflict detection** across both client configs and server config

## Key Features
---

---

### Dual Operation Modes
---

**Interactive Mode** - Perfect for beginners or when you need guidance:
```bash
sudo ./wg-peer-manager.sh
```

**Flag-Based Mode** - Quick operations for power users:
```bash
sudo ./wg-peer-manager.sh -n server-backend -q
```

### Split vs Full Tunnel
---

The script defaults to **split-tunnel mode** - routing only your internal network (10.0.0.0/24) through the VPN. This is perfect for point-to-point connections like RDP, SSH, or database access without interfering with internet traffic.

```bash
# Split-tunnel (default) - infrastructure only
sudo ./wg-peer-manager.sh -n rdp-server

# Full-tunnel - complete VPN
sudo ./wg-peer-manager.sh -n mobile-device -f
```

**Why this matters:** DNS settings in VPN configs can cause the operating system to route internet traffic through the tunnel even when you only want infrastructure access. Split-tunnel mode comments out the DNS line and restricts routing to your internal network only.

### Automatic Backups
---

Every peer creation automatically creates a timestamped backup:

```bash
/etc/wireguard/wg0.conf.backup-20241119-143022
```

If something goes wrong, restoration is simple:

```bash
# Via script
sudo ./wg-peer-manager.sh -r /etc/wireguard/wg0.conf.backup-TIMESTAMP

# Or manually
sudo cp /etc/wireguard/wg0.conf.backup-TIMESTAMP /etc/wireguard/wg0.conf
sudo wg syncconf wg0 <(wg-quick strip wg0)
```

### IP Conflict Prevention
---

The original version only checked client configs for IP assignments. If you had legacy peers in your main config without matching client files, the script would assign duplicate IPs.

The fixed version checks **both** locations:
- `/etc/wireguard/clients/*.conf` - Client configurations
- `/etc/wireguard/wg0.conf` - Main server config

This prevents duplicate IP assignments across your entire infrastructure.

## Installation
---

```bash
# Download the script
wget https://example.com/wg-peer-manager.sh

# Make it executable
chmod +x wg-peer-manager.sh

# Move to system path (optional)
sudo mv wg-peer-manager.sh /usr/local/bin/wg-peer-manager
```

## Usage Examples
---

### Creating Infrastructure Peers
---

```bash
# RDP server with auto-assigned IP
sudo ./wg-peer-manager.sh -n rdp-server

# Database with specific IP
sudo ./wg-peer-manager.sh -n database-primary -i 10.0.0.50

# Mobile device with QR code (split-tunnel)
sudo ./wg-peer-manager.sh -n ipad-admin -q
```

### Creating Full VPN Peers
---

```bash
# Laptop needing complete VPN
sudo ./wg-peer-manager.sh -n john-laptop -f

# Mobile with QR code and internet routing
sudo ./wg-peer-manager.sh -n android-phone -f -q
```

### Management Operations
---

```bash
# List all peers and their status
sudo ./wg-peer-manager.sh -l

# List all backups
sudo ./wg-peer-manager.sh -b

# Restore from backup
sudo ./wg-peer-manager.sh -r /etc/wireguard/wg0.conf.backup-TIMESTAMP
```

## Interactive Mode Walkthrough
---

Running the script without arguments launches interactive mode:

```bash
$ sudo ./wg-peer-manager.sh

[INFO] === WireGuard Peer Manager - Interactive Mode ===

What would you like to do?
  1) Create a new peer
  2) List all peers
  3) List backups
  4) Restore from backup
  5) Exit

Select option (1-5): 1

Enter peer name: office-device

Enter IP address (press Enter for auto-assign): 

Select tunnel mode:
  1) Split-tunnel (default) - Infrastructure only, no DNS
  2) Full-tunnel - Complete VPN with internet routing

Select mode (1 or 2) [1]: 1

Generate QR code for mobile device? (y/n): y

[INFO] Auto-assigned IP: 10.0.0.5
[INFO] Summary:
  Name: office-device
  IP: 10.0.0.5
  Mode: split-tunnel
  QR Code: Yes

Create this peer? (y/n): y
```

## Technical Implementation Details
---

### Append-Only Design
---

The script uses `>>` (append) instead of `>` (overwrite) when adding peers:

```bash
cat >> "$WG_CONFIG" <<EOF
# Peer: $peer_name - $peer_ip
[Peer]
PublicKey = $peer_public_key
PresharedKey = $peer_preshared_key
AllowedIPs = $peer_ip/32
EOF
```

This ensures existing peers are never lost.

### Non-Destructive Reloads
---

Instead of restarting WireGuard (which drops active connections), the script uses `wg syncconf`:

```bash
wg syncconf "$WG_INTERFACE" <(wg-quick strip "$WG_INTERFACE")
```

This applies configuration changes without interrupting existing connections.

### Configuration Templates
---

**Split-Tunnel Client Config:**
```ini
[Interface]
PrivateKey = <generated>
Address = 10.0.0.x/32
# DNS = 1.1.1.1, 1.0.0.1  # Commented out

[Peer]
PublicKey = <server-key>
PresharedKey = <generated>
Endpoint = <public-ip>:51820
AllowedIPs = 10.0.0.0/24  # Only tunnel traffic
PersistentKeepalive = 25
```

**Full-Tunnel Client Config:**
```ini
[Interface]
PrivateKey = <generated>
Address = 10.0.0.x/32
DNS = 1.1.1.1, 1.0.0.1  # Active

[Peer]
PublicKey = <server-key>
PresharedKey = <generated>
Endpoint = <public-ip>:51820
AllowedIPs = 0.0.0.0/0, ::/0  # All traffic
PersistentKeepalive = 25
```

## Lessons Learned
---

### 1. DNS Can Route Internet Traffic
---

Even with `AllowedIPs` set to only your internal network, having DNS configured in the client can cause the OS to route traffic through the tunnel. For infrastructure-only use cases, omit the DNS line entirely.

### 2. Check All Configuration Sources
---

Don't assume all peers have matching client config files. Always validate IP assignments against both the client configs directory and the main server configuration.

### 3. Backups Are Essential
---

A single character difference (`>` vs `>>`) can wipe out your entire peer configuration. Automatic backups before every change saved me multiple times during development.

### 4. `wg syncconf` vs Restart
---

Use `wg syncconf` for adding/updating peers to avoid dropping active connections. However, when **removing** peers, you need a full restart:

```bash
sudo wg-quick down wg0 && sudo wg-quick up wg0
```

`wg syncconf` only adds and updates - it doesn't remove peers from the running configuration.

## Use Cases
---

### Point-to-Point Infrastructure
---

Perfect for accessing internal services without routing internet traffic:

- RDP servers (3389)
- SSH access to internal servers
- Database connections
- Internal APIs and web services
- Service mesh between applications

### Full VPN Solution
---

When you need complete privacy and security:

- Remote workers needing secure internet
- Public WiFi protection
- Geo-restriction bypass
- Complete traffic encryption

## Safety Checklist
---

Before deploying in production:

1. **Verify peer count** before and after operations:
   ```bash
   sudo grep -c "\[Peer\]" /etc/wireguard/wg0.conf
   ```

2. **Test backup restoration** in a dev environment first

3. **Keep manual backups** before major changes:
   ```bash
   sudo cp /etc/wireguard/wg0.conf /etc/wireguard/wg0.conf.manual-$(date +%Y%m%d)
   ```

4. **Document IP assignments** for your infrastructure

5. **Monitor logs** after changes:
   ```bash
   sudo tail -f /var/log/wireguard-peers.log
   ```

## Future Enhancements
---

Potential additions I'm considering:

- Peer removal with confirmation prompts
- Bulk peer creation from CSV
- Email notifications on peer creation
- Integration with monitoring systems
- Automatic backup rotation/cleanup
- Config validation before applying

## Full Script 
---

```bash
#!/bin/bash

#################################################################
# WireGuard Peer Management Script
# Manages peer creation, configuration generation, and QR codes
#################################################################

# Configuration
WG_INTERFACE="wg0"
WG_CONFIG="/etc/wireguard/${WG_INTERFACE}.conf"
WG_CLIENTS_DIR="/etc/wireguard/clients"
LOG_FILE="/var/log/wireguard-peers.log"
SERVER_IP="10.0.0.1"
SERVER_SUBNET="10.0.0.0/24"
SERVER_PORT="51820"
SERVER_PUBLIC_IP=""  # Will be auto-detected if empty

# Default tunnel mode: split (infrastructure) or full (internet)
DEFAULT_TUNNEL_MODE="split"  # Change to "full" for VPN routing

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to log messages
log_message() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $1" | tee -a "$LOG_FILE"
}

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        exit 1
    fi
}

# Check required dependencies
check_dependencies() {
    local missing_deps=()
    
    for cmd in wg wg-quick qrencode; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "Missing required dependencies: ${missing_deps[*]}"
        print_info "Install them with: apt install wireguard-tools qrencode"
        exit 1
    fi
}

# Get server public IP
get_server_public_ip() {
    if [ -z "$SERVER_PUBLIC_IP" ]; then
        SERVER_PUBLIC_IP=$(curl -s https://api.ipify.org)
        if [ -z "$SERVER_PUBLIC_IP" ]; then
            SERVER_PUBLIC_IP=$(curl -s https://ifconfig.me)
        fi
        if [ -z "$SERVER_PUBLIC_IP" ]; then
            print_warning "Could not auto-detect public IP"
            read -p "Enter server public IP address: " SERVER_PUBLIC_IP
        fi
    fi
}

# Get server public key
get_server_public_key() {
    if [ ! -f "$WG_CONFIG" ]; then
        print_error "WireGuard config not found at $WG_CONFIG"
        exit 1
    fi
    
    SERVER_PRIVATE_KEY=$(grep PrivateKey "$WG_CONFIG" | awk '{print $3}')
    SERVER_PUBLIC_KEY=$(echo "$SERVER_PRIVATE_KEY" | wg pubkey)
}

# Get next available IP
get_next_ip() {
    mkdir -p "$WG_CLIENTS_DIR"
    
    # Get all assigned IPs from client configs
    local used_ips=()
    if [ -d "$WG_CLIENTS_DIR" ]; then
        while IFS= read -r file; do
            if [ -f "$file" ]; then
                ip=$(grep "Address" "$file" | awk '{print $3}' | cut -d'/' -f1)
                if [ -n "$ip" ]; then
                    used_ips+=("$ip")
                fi
            fi
        done < <(find "$WG_CLIENTS_DIR" -name "*.conf")
    fi
    
    # Also check main server config for existing peer IPs
    if [ -f "$WG_CONFIG" ]; then
        while IFS= read -r line; do
            if [[ "$line" =~ AllowedIPs[[:space:]]*=[[:space:]]*([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+) ]]; then
                ip="${BASH_REMATCH[1]}"
                if [[ "$ip" =~ ^10\.0\.0\. ]]; then
                    used_ips+=("$ip")
                fi
            fi
        done < "$WG_CONFIG"
    fi
    
    # Find next available IP in range 10.0.0.2 - 10.0.0.254
    for i in {2..254}; do
        test_ip="10.0.0.$i"
        if [[ ! " ${used_ips[@]} " =~ " ${test_ip} " ]]; then
            echo "$test_ip"
            return
        fi
    done
    
    print_error "No available IP addresses in range"
    exit 1
}

# Validate IP address
validate_ip() {
    local ip=$1
    local stat=1
    
    if [[ $ip =~ ^10\.0\.0\.([0-9]{1,3})$ ]]; then
        local octet=${BASH_REMATCH[1]}
        if [[ $octet -ge 2 && $octet -le 254 ]]; then
            stat=0
        fi
    fi
    
    return $stat
}

# Check if IP is already in use
check_ip_in_use() {
    local ip=$1
    
    # Check client configs
    if [ -d "$WG_CLIENTS_DIR" ]; then
        while IFS= read -r file; do
            if [ -f "$file" ]; then
                existing_ip=$(grep "Address" "$file" | awk '{print $3}' | cut -d'/' -f1)
                if [ "$existing_ip" == "$ip" ]; then
                    return 0  # IP is in use
                fi
            fi
        done < <(find "$WG_CLIENTS_DIR" -name "*.conf")
    fi
    
    # Check main server config
    if [ -f "$WG_CONFIG" ]; then
        while IFS= read -r line; do
            if [[ "$line" =~ AllowedIPs[[:space:]]*=[[:space:]]*([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)/32 ]]; then
                existing_ip="${BASH_REMATCH[1]}"
                if [ "$existing_ip" == "$ip" ]; then
                    return 0  # IP is in use
                fi
            fi
        done < "$WG_CONFIG"
    fi
    
    return 1  # IP is not in use
}

# Create peer configuration
create_peer() {
    local peer_name=$1
    local peer_ip=$2
    local show_qr=${3:-false}
    local tunnel_mode=${4:-$DEFAULT_TUNNEL_MODE}
    
    # Sanitize peer name
    peer_name=$(echo "$peer_name" | tr ' ' '_' | tr -cd '[:alnum:]_-')
    
    if [ -z "$peer_name" ]; then
        print_error "Invalid peer name"
        exit 1
    fi
    
    # Validate and check IP
    if ! validate_ip "$peer_ip"; then
        print_error "Invalid IP address. Must be in range 10.0.0.2 - 10.0.0.254"
        exit 1
    fi
    
    if check_ip_in_use "$peer_ip"; then
        print_error "IP address $peer_ip is already in use"
        exit 1
    fi
    
    # Create clients directory
    mkdir -p "$WG_CLIENTS_DIR"
    
    # Check if peer already exists
    if [ -f "$WG_CLIENTS_DIR/${peer_name}.conf" ]; then
        print_error "Peer '$peer_name' already exists"
        exit 1
    fi
    
    print_info "Creating peer: $peer_name with IP: $peer_ip (${tunnel_mode} tunnel)"
    
    # Generate keys for peer
    local peer_private_key=$(wg genkey)
    local peer_public_key=$(echo "$peer_private_key" | wg pubkey)
    local peer_preshared_key=$(wg genpsk)
    
    # Determine AllowedIPs and DNS based on tunnel mode
    local allowed_ips
    local dns_line
    
    if [ "$tunnel_mode" == "full" ]; then
        allowed_ips="0.0.0.0/0, ::/0"
        dns_line="DNS = 1.1.1.1, 1.0.0.1"
    else
        # Split tunnel - infrastructure only
        allowed_ips="$SERVER_SUBNET"
        dns_line="# DNS = 1.1.1.1, 1.0.0.1  # Commented out for split-tunnel"
    fi
    
    # Create client config file
    cat > "$WG_CLIENTS_DIR/${peer_name}.conf" <<EOF
[Interface]
PrivateKey = $peer_private_key
Address = $peer_ip/32
$dns_line

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
PresharedKey = $peer_preshared_key
Endpoint = $SERVER_PUBLIC_IP:$SERVER_PORT
AllowedIPs = $allowed_ips
PersistentKeepalive = 25
EOF

    # Backup server config before modification
    local backup_file="${WG_CONFIG}.backup-$(date +%Y%m%d-%H%M%S)"
    print_info "Creating backup: $backup_file"
    cp "$WG_CONFIG" "$backup_file"
    
    # Add peer to server config
    print_info "Adding peer to server configuration..."
    cat >> "$WG_CONFIG" <<EOF

# Peer: $peer_name - $peer_ip
[Peer]
PublicKey = $peer_public_key
PresharedKey = $peer_preshared_key
AllowedIPs = $peer_ip/32
EOF

    # Reload WireGuard
    print_info "Reloading WireGuard interface..."
    wg syncconf "$WG_INTERFACE" <(wg-quick strip "$WG_INTERFACE")
    
    # Log the operation
    log_message "Created peer: $peer_name | IP: $peer_ip | Public Key: $peer_public_key"
    
    # Print success message
    print_success "Peer '$peer_name' created successfully!"
    echo ""
    print_info "Configuration file: $WG_CLIENTS_DIR/${peer_name}.conf"
    print_info "Peer IP: $peer_ip"
    print_info "Tunnel Mode: $tunnel_mode"
    print_info "Public Key: $peer_public_key"
    print_info "Backup created: $backup_file"
    
    # Show QR code if requested
    if [ "$show_qr" == "true" ]; then
        echo ""
        print_info "QR Code for mobile device:"
        echo ""
        qrencode -t ansiutf8 < "$WG_CLIENTS_DIR/${peer_name}.conf"
        echo ""
        print_info "You can also generate QR code later with:"
        print_info "qrencode -t ansiutf8 < $WG_CLIENTS_DIR/${peer_name}.conf"
    fi
    
    echo ""
    print_info "To display configuration:"
    echo "cat $WG_CLIENTS_DIR/${peer_name}.conf"
}

# List all peers
list_peers() {
    print_info "Current WireGuard Peers:"
    echo ""
    
    if [ ! -d "$WG_CLIENTS_DIR" ] || [ -z "$(ls -A "$WG_CLIENTS_DIR" 2>/dev/null)" ]; then
        print_warning "No peers found"
        return
    fi
    
    printf "%-20s %-15s %-10s\n" "NAME" "IP ADDRESS" "STATUS"
    printf "%-20s %-15s %-10s\n" "----" "----------" "------"
    
    for conf_file in "$WG_CLIENTS_DIR"/*.conf; do
        if [ -f "$conf_file" ]; then
            peer_name=$(basename "$conf_file" .conf)
            peer_ip=$(grep "Address" "$conf_file" | awk '{print $3}' | cut -d'/' -f1)
            peer_pubkey=$(grep "PrivateKey" "$conf_file" | awk '{print $3}' | wg pubkey)
            
            # Check if peer is active
            if wg show "$WG_INTERFACE" | grep -q "$peer_pubkey"; then
                status="${GREEN}Active${NC}"
            else
                status="${YELLOW}Inactive${NC}"
            fi
            
            printf "%-20s %-15s %-10b\n" "$peer_name" "$peer_ip" "$status"
        fi
    done
    echo ""
}

# List available backups
list_backups() {
    print_info "Available WireGuard configuration backups:"
    echo ""
    
    local backups=($(ls -t "${WG_CONFIG}.backup-"* 2>/dev/null))
    
    if [ ${#backups[@]} -eq 0 ]; then
        print_warning "No backups found"
        return
    fi
    
    printf "%-30s %-20s %-10s\n" "BACKUP FILE" "DATE" "SIZE"
    printf "%-30s %-20s %-10s\n" "-----------" "----" "----"
    
    for backup in "${backups[@]}"; do
        local filename=$(basename "$backup")
        local filesize=$(du -h "$backup" | cut -f1)
        local filedate=$(echo "$filename" | grep -oP '\d{8}-\d{6}' | sed 's/\([0-9]\{8\}\)-\([0-9]\{6\}\)/\1 \2/')
        
        printf "%-30s %-20s %-10s\n" "$filename" "$filedate" "$filesize"
    done
    echo ""
    print_info "To restore a backup:"
    echo "sudo cp /etc/wireguard/wg0.conf.backup-TIMESTAMP /etc/wireguard/wg0.conf"
    echo "sudo wg syncconf wg0 <(wg-quick strip wg0)"
    echo ""
}

# Restore from backup
restore_backup() {
    local backup_file=$1
    
    if [ ! -f "$backup_file" ]; then
        print_error "Backup file not found: $backup_file"
        exit 1
    fi
    
    print_warning "This will restore WireGuard config from backup"
    read -p "Are you sure? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        print_info "Restore cancelled"
        exit 0
    fi
    
    # Create backup of current config before restoring
    local safety_backup="${WG_CONFIG}.pre-restore-$(date +%Y%m%d-%H%M%S)"
    cp "$WG_CONFIG" "$safety_backup"
    print_info "Safety backup created: $safety_backup"
    
    # Restore
    cp "$backup_file" "$WG_CONFIG"
    print_success "Config restored from: $backup_file"
    
    # Reload
    print_info "Reloading WireGuard..."
    wg syncconf "$WG_INTERFACE" <(wg-quick strip "$WG_INTERFACE")
    
    print_success "Restore complete!"
}

# Show usage
show_usage() {
    cat <<EOF
WireGuard Peer Management Script

Usage: $0 [OPTIONS]

Interactive Mode:
    Run without any options for guided menu-driven interface:
    $0

Options:
    -n, --name NAME         Peer name (required)
    -i, --ip IP            IP address (optional, auto-assigned if not provided)
    -q, --qr               Generate QR code for mobile devices
    -f, --full-tunnel      Full tunnel mode (route all traffic through VPN)
                           Default: split-tunnel (infrastructure only)
    -l, --list             List all peers
    -b, --backups          List all configuration backups
    -r, --restore FILE     Restore from backup file
    -h, --help             Show this help message

Tunnel Modes:
    Split-tunnel (default): Only routes 10.0.0.0/24 through VPN, no DNS
                           Perfect for point-to-point services (RDP, etc)
    
    Full-tunnel (-f):      Routes all traffic through VPN with DNS
                           Use for complete VPN internet access

Examples:
    # Interactive mode (recommended for beginners)
    $0
    
    # Create infrastructure peer (split-tunnel, no DNS)
    $0 -n server-backend

    # Create infrastructure peer with QR code
    $0 -n office-device -q

    # Create full VPN peer with internet routing
    $0 -n mobile-device -f -q

    # Create peer with specific IP
    $0 -n service-host -i 10.0.0.50

    # List all peers
    $0 -l
    
    # List all backups
    $0 -b
    
    # Restore from backup
    $0 -r /etc/wireguard/wg0.conf.backup-20231118-143022

Safety:
    • Automatic backup before each peer creation
    • Append-only mode (never overwrites existing peers)
    • Non-destructive config reload

Log file: $LOG_FILE
Config directory: $WG_CLIENTS_DIR
Backups: ${WG_CONFIG}.backup-*
EOF
}

# Main script
main() {
    check_root
    check_dependencies
    
    # Parse command line arguments
    local peer_name=""
    local peer_ip=""
    local show_qr=false
    local list_mode=false
    local backups_mode=false
    local restore_file=""
    local tunnel_mode=$DEFAULT_TUNNEL_MODE
    local interactive_mode=false
    
    # Check if running with no arguments (interactive mode)
    if [ $# -eq 0 ]; then
        interactive_mode=true
    fi
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--name)
                peer_name="$2"
                shift 2
                ;;
            -i|--ip)
                peer_ip="$2"
                shift 2
                ;;
            -q|--qr)
                show_qr=true
                shift
                ;;
            -f|--full-tunnel)
                tunnel_mode="full"
                shift
                ;;
            -l|--list)
                list_mode=true
                shift
                ;;
            -b|--backups)
                backups_mode=true
                shift
                ;;
            -r|--restore)
                restore_file="$2"
                shift 2
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Interactive mode
    if [ "$interactive_mode" == true ]; then
        echo ""
        print_info "=== WireGuard Peer Manager - Interactive Mode ==="
        echo ""
        
        # Show menu
        echo "What would you like to do?"
        echo "  1) Create a new peer"
        echo "  2) List all peers"
        echo "  3) List backups"
        echo "  4) Restore from backup"
        echo "  5) Exit"
        echo ""
        read -p "Select option (1-5): " menu_choice
        
        case $menu_choice in
            1)
                # Create peer - continue with prompts below
                ;;
            2)
                get_server_public_key
                list_peers
                exit 0
                ;;
            3)
                list_backups
                exit 0
                ;;
            4)
                list_backups
                echo ""
                read -p "Enter backup file path to restore: " restore_file
                if [ -n "$restore_file" ]; then
                    restore_backup "$restore_file"
                fi
                exit 0
                ;;
            5)
                print_info "Goodbye!"
                exit 0
                ;;
            *)
                print_error "Invalid option"
                exit 1
                ;;
        esac
        
        echo ""
        print_info "=== Create New Peer ==="
        echo ""
        
        # Get peer name
        while [ -z "$peer_name" ]; do
            read -p "Enter peer name (e.g., office-device, john-phone): " peer_name
            if [ -z "$peer_name" ]; then
                print_error "Peer name cannot be empty"
            fi
        done
        
        # Get IP address (note: actual auto-assign happens later after server info is loaded)
        echo ""
        read -p "Enter IP address (press Enter for auto-assign): " peer_ip
        
        # Get tunnel mode
        echo ""
        echo "Select tunnel mode:"
        echo "  1) Split-tunnel (default) - Infrastructure only, no DNS"
        echo "     Routes only 10.0.0.0/24 through VPN"
        echo "     Perfect for: RDP, SSH, databases, service mesh"
        echo ""
        echo "  2) Full-tunnel - Complete VPN with internet routing"
        echo "     Routes ALL traffic through VPN with DNS"
        echo "     Perfect for: Remote workers, secure browsing"
        echo ""
        read -p "Select mode (1 or 2) [1]: " mode_choice
        
        case $mode_choice in
            2)
                tunnel_mode="full"
                print_info "Selected: Full-tunnel mode"
                ;;
            1|"")
                tunnel_mode="split"
                print_info "Selected: Split-tunnel mode"
                ;;
            *)
                print_warning "Invalid choice, using default: Split-tunnel"
                tunnel_mode="split"
                ;;
        esac
        
        # Get QR code preference
        echo ""
        read -p "Generate QR code for mobile device? (y/n) [n]: " qr_choice
        case $qr_choice in
            y|Y|yes|Yes)
                show_qr=true
                ;;
            *)
                show_qr=false
                ;;
        esac
    fi
    
    # Backup list mode
    if [ "$backups_mode" == true ]; then
        list_backups
        exit 0
    fi
    
    # Restore mode
    if [ -n "$restore_file" ]; then
        restore_backup "$restore_file"
        exit 0
    fi
    
    # List mode
    if [ "$list_mode" == true ]; then
        get_server_public_key
        list_peers
        exit 0
    fi
    
    # Validate required parameters (only for flag-based mode)
    if [ -z "$peer_name" ] && [ "$interactive_mode" == false ]; then
        print_error "Peer name is required"
        show_usage
        exit 1
    fi
    
    # Auto-assign IP if not provided (for flag-based mode only)
    if [ -z "$peer_ip" ] && [ "$interactive_mode" == false ]; then
        peer_ip=$(get_next_ip)
        print_info "Auto-assigned IP: $peer_ip"
    fi
    
    # Get server info
    get_server_public_ip
    get_server_public_key
    
    # Auto-assign IP if not provided
    if [ -z "$peer_ip" ]; then
        peer_ip=$(get_next_ip)
        if [ "$interactive_mode" == true ]; then
            print_info "Auto-assigned IP: $peer_ip"
        fi
    fi
    
    # Show summary in interactive mode before creating
    if [ "$interactive_mode" == true ]; then
        echo ""
        print_info "Summary:"
        echo "  Name: $peer_name"
        echo "  IP: $peer_ip"
        echo "  Mode: $tunnel_mode-tunnel"
        echo "  QR Code: $([ "$show_qr" == true ] && echo "Yes" || echo "No")"
        echo ""
        read -p "Create this peer? (y/n) [y]: " confirm
        
        case $confirm in
            n|N|no|No)
                print_info "Cancelled"
                exit 0
                ;;
        esac
    fi
    
    # Create the peer
    create_peer "$peer_name" "$peer_ip" "$show_qr" "$tunnel_mode"
}

# Run main function
main "$@"


```


## Conclusion
---

After accidentally deleting an active peer with my old script, building a safer alternative was essential. The key improvements - automatic backups, append-only operations, split-tunnel defaults, and interactive mode - make WireGuard peer management reliable and safe for infrastructure deployments.
The script has been running in production for over a month managing point-to-point connections for RDP access, database connections, and service mesh networking across our infrastructure without incident. Do not forget that there is a QR code option for mobile device enrollment, so please do not try importing and exporting configs this is dangerous. 
