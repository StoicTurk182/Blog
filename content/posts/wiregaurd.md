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

### Dual Operation Modes

**Interactive Mode** - Perfect for beginners or when you need guidance:
```bash
sudo ./wg-peer-manager.sh
```

**Flag-Based Mode** - Quick operations for power users:
```bash
sudo ./wg-peer-manager.sh -n server-backend -q
```

### Split vs Full Tunnel

The script defaults to **split-tunnel mode** - routing only your internal network (10.0.0.0/24) through the VPN. This is perfect for point-to-point connections like RDP, SSH, or database access without interfering with internet traffic.

```bash
# Split-tunnel (default) - infrastructure only
sudo ./wg-peer-manager.sh -n rdp-server

# Full-tunnel - complete VPN
sudo ./wg-peer-manager.sh -n mobile-device -f
```

**Why this matters:** DNS settings in VPN configs can cause the operating system to route internet traffic through the tunnel even when you only want infrastructure access. Split-tunnel mode comments out the DNS line and restricts routing to your internal network only.

### Automatic Backups

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

The original version only checked client configs for IP assignments. If you had legacy peers in your main config without matching client files, the script would assign duplicate IPs.

The fixed version checks **both** locations:
- `/etc/wireguard/clients/*.conf` - Client configurations
- `/etc/wireguard/wg0.conf` - Main server config

This prevents duplicate IP assignments across your entire infrastructure.

## Installation

```bash
# Download the script
wget https://example.com/wg-peer-manager.sh

# Make it executable
chmod +x wg-peer-manager.sh

# Move to system path (optional)
sudo mv wg-peer-manager.sh /usr/local/bin/wg-peer-manager
```

## Usage Examples

### Creating Infrastructure Peers

```bash
# RDP server with auto-assigned IP
sudo ./wg-peer-manager.sh -n rdp-server

# Database with specific IP
sudo ./wg-peer-manager.sh -n database-primary -i 10.0.0.50

# Mobile device with QR code (split-tunnel)
sudo ./wg-peer-manager.sh -n ipad-admin -q
```

### Creating Full VPN Peers

```bash
# Laptop needing complete VPN
sudo ./wg-peer-manager.sh -n john-laptop -f

# Mobile with QR code and internet routing
sudo ./wg-peer-manager.sh -n android-phone -f -q
```

### Management Operations

```bash
# List all peers and their status
sudo ./wg-peer-manager.sh -l

# List all backups
sudo ./wg-peer-manager.sh -b

# Restore from backup
sudo ./wg-peer-manager.sh -r /etc/wireguard/wg0.conf.backup-TIMESTAMP
```

## Interactive Mode Walkthrough

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

### Append-Only Design

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

Instead of restarting WireGuard (which drops active connections), the script uses `wg syncconf`:

```bash
wg syncconf "$WG_INTERFACE" <(wg-quick strip "$WG_INTERFACE")
```

This applies configuration changes without interrupting existing connections.

### Configuration Templates

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

### 1. DNS Can Route Internet Traffic

Even with `AllowedIPs` set to only your internal network, having DNS configured in the client can cause the OS to route traffic through the tunnel. For infrastructure-only use cases, omit the DNS line entirely.

### 2. Check All Configuration Sources

Don't assume all peers have matching client config files. Always validate IP assignments against both the client configs directory and the main server configuration.

### 3. Backups Are Essential

A single character difference (`>` vs `>>`) can wipe out your entire peer configuration. Automatic backups before every change saved me multiple times during development.

### 4. `wg syncconf` vs Restart

Use `wg syncconf` for adding/updating peers to avoid dropping active connections. However, when **removing** peers, you need a full restart:

```bash
sudo wg-quick down wg0 && sudo wg-quick up wg0
```

`wg syncconf` only adds and updates - it doesn't remove peers from the running configuration.

## Use Cases

### Point-to-Point Infrastructure

Perfect for accessing internal services without routing internet traffic:

- RDP servers (3389)
- SSH access to internal servers
- Database connections
- Internal APIs and web services
- Service mesh between applications

### Full VPN Solution

When you need complete privacy and security:

- Remote workers needing secure internet
- Public WiFi protection
- Geo-restriction bypass
- Complete traffic encryption

## Safety Checklist

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

Potential additions I'm considering:

- Peer removal with confirmation prompts
- Bulk peer creation from CSV
- Email notifications on peer creation
- Integration with monitoring systems
- Automatic backup rotation/cleanup
- Config validation before applying


## Conclusion

---

After accidentally deleting an active peer with my old script, building a safer alternative was essential. The key improvements - automatic backups, append-only operations, split-tunnel defaults, and interactive mode - make WireGuard peer management reliable and safe for infrastructure deployments.
The script has been running in production for over a month managing point-to-point connections for RDP access, database connections, and service mesh networking across our infrastructure without incident. Do not forget that there is a QR code option for mobile device enrollment, so please do not try importing and exporting configs this is dangerous. 
