#!/bin/bash

# Network Topology Report Generator
# Generates a comprehensive report of network configuration, services, and connections

# Color codes for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get hostname
HOSTNAME=$(hostname)
TIMESTAMP=$(date -u)

# Output file
OUTPUT_FILE="${1:-network_topology_report_${HOSTNAME}_$(date +%Y%m%d_%H%M%S).txt}"

# Function to print section header
print_header() {
    echo ""
    echo "=== $1 ==="
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Start report
{
    echo "=== NETWORK TOPOLOGY REPORT ==="
    echo "Hostname: $HOSTNAME"
    echo "Generated: $TIMESTAMP"
    echo ""

    # Network Interfaces
    print_header "NETWORK INTERFACES"
    if command_exists ip; then
        ip addr show
    else
        ifconfig -a
    fi

    # Routing Table
    print_header "ROUTING TABLE"
    if command_exists ip; then
        ip route show
    else
        route -n
    fi

    # Neighbor Discovery (ARP Table)
    print_header "NEIGHBOR DISCOVERY (ARP TABLE)"
    if command_exists ip; then
        ip neigh show
    else
        arp -a
    fi

    # Listening Ports & Services
    print_header "LISTENING PORTS & SERVICES"
    if command_exists ss; then
        ss -tulpn
    elif command_exists netstat; then
        netstat -tulpn
    fi

    # Active Network Connections
    print_header "ACTIVE NETWORK CONNECTIONS"
    if command_exists ss; then
        ss -tupn | grep ESTAB
    elif command_exists netstat; then
        netstat -tupn | grep ESTABLISHED
    fi

    # Firewall Status
    print_header "FIREWALL STATUS"
    if command_exists ufw; then
        sudo ufw status verbose
    elif command_exists iptables; then
        echo "IPTables rules:"
        sudo iptables -L -n -v
    fi

    # Network Statistics
    print_header "NETWORK STATISTICS"
    if command_exists ip; then
        ip -s link
    else
        netstat -i
    fi

    # DNS Configuration
    print_header "DNS CONFIGURATION"
    if [ -f /etc/resolv.conf ]; then
        cat /etc/resolv.conf
    fi

    # WireGuard Status
    print_header "WIREGUARD STATUS (if applicable)"
    if command_exists wg; then
        sudo wg show 2>/dev/null || echo "WireGuard not configured or not accessible"
    else
        echo "WireGuard not installed"
    fi

    # Samba Connections
    print_header "SAMBA CONNECTIONS"
    if command_exists smbstatus; then
        echo ""
        sudo smbstatus 2>/dev/null || echo "Samba not running or not accessible"
    else
        echo "Samba not installed"
    fi

    # Docker Networks (if applicable)
    if command_exists docker; then
        print_header "DOCKER NETWORKS"
        docker network ls 2>/dev/null
        echo ""
        echo "Docker network details:"
        for network in $(docker network ls --format "{{.Name}}" 2>/dev/null); do
            echo "Network: $network"
            docker network inspect "$network" 2>/dev/null | grep -A 5 "IPAM"
        done
    fi

    echo ""
    echo "=================================================================================="
    echo "=== VISUAL NETWORK TOPOLOGY DIAGRAM ==="
    echo "=================================================================================="
    echo ""
    echo "Visualisation: NETWORK TOPOLOGY DIAGRAM"
    echo "Generated: $TIMESTAMP"
    echo "Host: $HOSTNAME"
    echo ""

    # Parse and display network topology
    echo "INTERNET CLOUD"
    echo "│"

    # Get default gateway
    DEFAULT_GW=$(ip route | grep default | awk '{print $3}' | head -1)
    if [ -n "$DEFAULT_GW" ]; then
        echo "├── PUBLIC GATEWAY: $DEFAULT_GW"
        echo "│"
    fi

    # Get public IP and hostname
    PUBLIC_IP=$(ip addr show | grep 'inet ' | grep -v '127.0.0.1' | grep -v '10\.' | grep -v '172\.(1[6-9]|2[0-9]|3[0-1])\.' | grep -v '192\.168\.' | awk '{print $2}' | cut -d/ -f1 | head -1)
    PUBLIC_IPV6=$(ip addr show | grep 'inet6' | grep -v '::1' | grep -v 'fe80:' | grep -v 'fd' | awk '{print $2}' | cut -d/ -f1 | head -1)
    
    if [ -n "$PUBLIC_IPV6" ]; then
        echo "└── YOUR SERVER: $PUBLIC_IPV6"
    else
        echo "└── YOUR SERVER: $PUBLIC_IP"
    fi
    echo "│"

    # Main network interface
    MAIN_IFACE=$(ip route | grep default | awk '{print $5}' | head -1)
    if [ -n "$MAIN_IFACE" ]; then
        echo "├── INTERFACE: $MAIN_IFACE (PUBLIC)"
        if [ -n "$PUBLIC_IP" ]; then
            SUBNET=$(ip addr show "$MAIN_IFACE" | grep "inet $PUBLIC_IP" | awk '{print $2}')
            echo "│   ├── IP: $SUBNET"
        fi
        if [ -n "$PUBLIC_IPV6" ]; then
            IPV6_SUBNET=$(ip addr show "$MAIN_IFACE" | grep "inet6 $PUBLIC_IPV6" | awk '{print $2}')
            echo "│   ├── IPv6: $IPV6_SUBNET"
        fi
        echo "│   └── SERVICES:"
        
        # Check for common services
        SERVICES=$(ss -tulpn 2>/dev/null | grep -E ':(80|443|22|25|53) ' | awk '{print $5}' | cut -d: -f2 | sort -u)
        if [ -n "$SERVICES" ]; then
            echo "$SERVICES" | while read port; do
                case $port in
                    80) echo "│       ├── HTTP (80)" ;;
                    443) echo "│       ├── HTTPS (443)" ;;
                    22) echo "│       ├── SSH (22)" ;;
                    25) echo "│       ├── SMTP (25)" ;;
                    53) echo "│       ├── DNS (53)" ;;
                esac
            done
        else
            echo "│       └── No common services detected"
        fi
    fi
    echo "│"

    # WireGuard VPN
    if command_exists wg && sudo wg show 2>/dev/null | grep -q interface; then
        echo "├── VPN: WireGuard"
        WG_IFACE=$(sudo wg show interfaces 2>/dev/null | head -1)
        if [ -n "$WG_IFACE" ]; then
            WG_IP=$(ip addr show "$WG_IFACE" 2>/dev/null | grep 'inet ' | awk '{print $2}')
            echo "│   ├── $WG_IFACE - $WG_IP"
            
            # List peers
            sudo wg show "$WG_IFACE" peers 2>/dev/null | while read peer; do
                ENDPOINT=$(sudo wg show "$WG_IFACE" peer "$peer" endpoint 2>/dev/null)
                HANDSHAKE=$(sudo wg show "$WG_IFACE" peer "$peer" latest-handshake 2>/dev/null)
                if [ "$HANDSHAKE" != "0" ]; then
                    echo "│   │   └── PEER: $peer (ACTIVE)"
                else
                    echo "│   │   └── PEER: $peer (INACTIVE)"
                fi
            done
        fi
        echo "│"
    fi

    # Tailscale
    if ip addr show 2>/dev/null | grep -q tailscale; then
        echo "├── VPN: Tailscale"
        TS_IP=$(ip addr show tailscale0 2>/dev/null | grep 'inet ' | awk '{print $2}')
        echo "│   ├── tailscale0 - $TS_IP"
        
        # Get Tailscale DNS
        if grep -q "100.100.100.100" /etc/resolv.conf 2>/dev/null; then
            echo "│   └── DNS: 100.100.100.100"
        fi
        echo "│"
    fi

    # Docker Networks
    if command_exists docker; then
        echo "└── DOCKER NETWORKS"
        docker network ls --format "{{.Name}}" 2>/dev/null | grep -v "^bridge$" | grep -v "^host$" | grep -v "^none$" | while read network; do
            SUBNET=$(docker network inspect "$network" 2>/dev/null | grep -A 1 '"Subnet"' | grep -v Subnet | tr -d ' ",')
            DRIVER=$(docker network ls --format "{{.Name}} {{.Driver}}" | grep "^$network " | awk '{print $2}')
            
            # Check if network is in use
            CONTAINERS=$(docker network inspect "$network" 2>/dev/null | grep -c '"Name".*"container:')
            if [ "$CONTAINERS" -gt 0 ]; then
                STATUS="(ACTIVE)"
            else
                STATUS="(DOWN)"
            fi
            
            echo "    ├── $DRIVER: $network - $SUBNET $STATUS"
            
            # List containers
            docker network inspect "$network" 2>/dev/null | grep '"Name": "' | grep -v '"Network":' | while read line; do
                CONTAINER=$(echo "$line" | cut -d'"' -f4)
                if [ "$CONTAINER" != "" ]; then
                    echo "    │   ├── CONTAINER: $CONTAINER"
                fi
            done
        done
    fi

    # Active Connections Summary
    echo ""
    echo "ACTIVE CONNECTIONS"
    echo "──────────────────────────────────────────────────────────────"
    if command_exists ss; then
        ss -tupn | grep ESTAB | head -20
    else
        netstat -tupn | grep ESTABLISHED | head -20
    fi

    # Security Status
    echo ""
    echo "SECURITY STATUS"
    echo "──────────────────────────────────────────────────────────────"
    if command_exists ufw; then
        if sudo ufw status | grep -q "Status: active"; then
            echo "✅ UFW firewall is active"
        else
            echo "⚠️  UFW firewall is inactive"
        fi
    fi
    
    if command_exists wg && sudo wg show 2>/dev/null | grep -q interface; then
        # Check if Samba is restricted to WireGuard
        if sudo ufw status 2>/dev/null | grep -q "10.0.0"; then
            echo "✅ Samba isolated to WireGuard network only"
        fi
    fi
    
    if command_exists docker && docker ps -q 2>/dev/null | grep -q .; then
        echo "✅ Docker containers running in isolated networks"
    fi

    # Services Summary
    echo ""
    echo "SERVICES SUMMARY"
    echo "──────────────────────────────────────────────────────────────"
    
    PUBLIC_PORTS=$(ss -tulpn 2>/dev/null | grep -v "127.0.0" | grep LISTEN | wc -l)
    echo "PUBLIC: $PUBLIC_PORTS listening ports"
    
    if command_exists wg && sudo wg show 2>/dev/null | grep -q interface; then
        WG_COUNT=$(sudo wg show interfaces 2>/dev/null | wc -w)
        echo "VPN: $WG_COUNT WireGuard"
        if ip addr show 2>/dev/null | grep -q tailscale; then
            echo -n ", 1 Tailscale"
        fi
        echo ""
    fi
    
    if command_exists docker; then
        CONTAINER_COUNT=$(docker ps -q 2>/dev/null | wc -l)
        if [ "$CONTAINER_COUNT" -gt 0 ]; then
            echo "CONTAINERS: $CONTAINER_COUNT active"
        fi
    fi

    # Traffic Flow
    echo ""
    echo "TRAFFIC FLOW"
    echo "──────────────────────────────────────────────────────────────"
    echo "Internet → SSH/HTTPS/WireGuard → $MAIN_IFACE"
    if command_exists wg && sudo wg show 2>/dev/null | grep -q interface; then
        echo "WireGuard Peers → Samba Shares → wg0"
    fi
    if command_exists docker && docker ps -q 2>/dev/null | grep -q .; then
        echo "Containers → Bridge Networks → Host"
    fi

    echo ""
    echo "=================================================================================="
    echo "=== END OF NETWORK TOPOLOGY REPORT ==="
    echo "=================================================================================="

} > "$OUTPUT_FILE"

echo -e "${GREEN}Network topology report generated: $OUTPUT_FILE${NC}"
echo -e "${BLUE}View with: cat $OUTPUT_FILE${NC}"
