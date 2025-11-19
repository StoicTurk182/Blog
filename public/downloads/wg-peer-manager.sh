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
    
    # Validate required parameters
    if [ -z "$peer_name" ]; then
        print_error "Peer name is required"
        show_usage
        exit 1
    fi
    
    # Auto-assign IP if not provided
    if [ -z "$peer_ip" ]; then
        peer_ip=$(get_next_ip)
        print_info "Auto-assigned IP: $peer_ip"
    fi
    
    # Get server info
    get_server_public_ip
    get_server_public_key
    
    # Create the peer
    create_peer "$peer_name" "$peer_ip" "$show_qr" "$tunnel_mode"
}

# Run main function
main "$@"
