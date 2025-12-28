---
title: "iVentoy PXE Server"
description: "Network boot solution for booting and installing multiple operating systems from ISO files over the network"
version: "1.0.20"
categories: ["Tools"]
tags: ["pxe", "network-boot", "os-deployment"]
layout: "tools-single"
download_url: "https://www.iventoy.com/en/download.html"
buy_url: "https://www.iventoy.com/en/doc_edition.html"
tool_image: "iventoy.png"  # Add this line
---

# iVentoy PXE Server

iVentoy is an enhanced PXE server that allows you to boot and install multiple operating systems simultaneously over the network directly from ISO files, eliminating the need for individual bootable USB drives.

## Overview
---

iVentoy brings the multi-boot convenience of Ventoy to network deployment. It serves as a central network boot server that can handle over 110 different operating systems without requiring ISO extraction or modification. Originally created by the developer of Ventoy, it's designed for both home labs and enterprise environments.

## Key Features
---

### Core Functionality
---
- **Direct ISO Booting**: Boot directly from ISO files without extraction or conversion
- **Massive OS Support**: Supports 110+ Windows, Linux, WinPE, and VMware versions
- **Full Architecture Support**: Works with Legacy BIOS, IA32 UEFI, x86_64 UEFI, and ARM64 UEFI simultaneously
- **Cross-Platform**: Runs on both Windows and Linux operating systems

### Deployment & Management
---
- **Web Interface**: Easy management through browser-based interface (port 26000)
- **MAC Address Filtering**: Control client access through permit/deny lists
- **File Injection**: Add drivers, scripts, or files to ISOs without repacking
- **Auto Installation**: Supports Windows (unattend.xml) and Linux (cloud-init, preseed) automated setups

### Network Integration
---
- **Flexible DHCP Modes**: Internal DHCP server or integration with third-party DHCP servers
- **Dual Operation Modes**: External mode for same VLAN, ExternalNet mode for different VLANs
- **Client Monitoring**: Real-time view of connected clients and their boot status

## System Requirements
---

- **Server OS**: Windows 7/8/10/11 or Linux
- **Network**: Wired Ethernet connection (PXE does not work over Wi-Fi)
- **Storage**: Sufficient space for ISO library
- **Ports**: 26000 (Web UI), 16000 (HTTP), 69 (TFTP), 67/68 (DHCP)

## Usage Guide
---

### Basic Setup
---
1. Download and extract iVentoy package
2. Copy ISO files to the `iso` directory
3. Run iVentoy executable (`iVentoy.exe` on Windows or `./iventoy.sh start` on Linux)
4. Access web interface at `http://your-server-ip:26000`
5. Configure IP settings and start PXE service

### Advanced Configuration
---
- **Third-party DHCP**: Set next-server to iVentoy IP and bootfile to `iventoy_loader_16000`
- **Enterprise Deployment**: Use Pro edition for unlimited clients and commercial use
- **Automated Installs**: Create scripts for unattended OS installations

## Comparison: Free vs Pro Edition
---

| Feature | Free Edition | Pro Edition |
|---------|--------------|-------------|
| Client Limit | 20 clients | Unlimited |
| Commercial Use | Not allowed | Allowed |
| ARM64 Support | No | Yes |
| Cost | Free | $49 one-time |

## Use Cases
---

### Ideal For
---
- **IT Departments**: Rapid OS deployment across multiple machines
- **Home Labs**: Easy testing of different Linux distributions
- **System Administrators**: Centralized management of installation media
- **Tech Support**: Diagnostic and recovery tool distribution

### Limitations
---
- Requires wired network connections
- Free edition limited to 20 concurrent clients
- No ARM64 support in free edition

## Troubleshooting
---

### Common Issues
---
- **PXE Boot Fails**: Verify DHCP configuration and network connectivity
- **ISO Not Appearing**: Ensure filenames contain no spaces or unicode characters
- **UEFI/Legacy Mismatch**: Configure correct bootfile names for client firmware

### Best Practices
---
- Use descriptive ISO filenames without special characters
- Organize ISOs in subdirectories for better management
- Regularly update to latest iVentoy version for new OS support

---

*iVentoy is developed by the Ventoy project team. Last updated: January 2024*