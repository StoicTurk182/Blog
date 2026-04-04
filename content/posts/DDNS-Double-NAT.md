---
title: "Solving Cloudflare DDNS in Double NAT Environments"
date: 2025-12-28
draft: false
description: "How to configure Cloudflare Dynamic DNS when your gateway is behind double NAT and can't detect your real public IP. A PowerShell-based solution for Windows workstations."
categories: ["Infrastructure", "Networking"]
tags: ["cloudflare", "ddns", "dynamic-dns", "double-nat", "openvpn", "unifi", "powershell", "windows", "api", "remote-access"]
featuredImage: "/images/cloudflare-ddns-double-nat.svg"
readingTime: true
toc: true
author: "Andrew Jones"
authorBio: "L2 IT Support Engineer specialising in system administration and network infrastructure"
socialShare: true
---

## The Problem
---

I needed remote VPN access to my home network. The setup seemed straightforward: configure OpenVPN on my UniFi Dream Router, set up Cloudflare DDNS to handle my dynamic IP, and connect from anywhere. Simple enough, right?

Not quite.

I am very aware that this is not the ideal setup but since my Vigor-130 has not yet arrived I needed a good solution that would work in the mean time. This is what I came up with, the UDR is more than capable of doing this but only using PPOE passthrough as my WAN link is only VDSL. I do a lot of labs that need VPNs to work and the below solution works very well.   
 

## DDNS Workaround 
---

My ISP router sits between my UniFi gateway and the internet. This creates a double NAT situation where the UDR's WAN interface receives a private IP (like `192.168.1.12`) from the ISP router rather than my actual public IP. When the UDR's native DDNS tried to update Cloudflare, it dutifully reported `192.168.1.12` - completely useless for external access.

```shell
Internet → ISP Router (public IP) → UDR (private IP) → LAN
```

The UDR has no visibility of the real public IP. It only sees what's on its WAN interface.

## The Solution
---

Rather than fighting the gateway's limitations, I moved the DDNS logic to a Windows workstation inside the network. The key insight: any device on my LAN can query an external service like `api.ipify.org` to discover the true public IP, regardless of how many NAT layers sit between it and the internet.

The solution has three components:

1. A PowerShell script that queries the public IP and updates Cloudflare
2. A Windows scheduled task that runs the script at login, startup, and every 30 minutes
3. Port forwarding on the ISP router to direct VPN traffic to the UDR

## Cloudflare API Token
---

First, create a scoped API token in Cloudflare. Navigate to **My Profile → API Tokens → Create Token** and use the "Edit zone DNS" template.

Configure it with minimal permissions:

- **Permissions**: Zone → DNS → Edit
- **Zone Resources**: Include → Specific zone → your domain
- **Client IP Filtering**: Leave blank (critical for DDNS - you can't filter by an IP that keeps changing)
- **TTL**: Set a reasonable expiry for security rotation

Copy the token immediately - Cloudflare only shows it once.

## The DNS Record
---

The DDNS script updates an existing record; it won't create one. Add an A record in Cloudflare's DNS settings:

- **Name**: `home` (or your preferred subdomain)
- **Type**: A
- **Content**: Your current public IP
- **Proxy status**: DNS only (the grey cloud - required for non-HTTP traffic like VPN)

## The PowerShell Script
---

Create `C:\Scripts\Cloudflare-DDNS.ps1`:

```powershell
#Requires -Version 5.1

$Config = @{
    ApiToken   = "YOUR_API_TOKEN"
    ZoneId     = "YOUR_ZONE_ID"
    RecordId   = "YOUR_RECORD_ID"
    RecordName = "home.yourdomain.com"
    TTL        = 300
    Proxied    = $false
    LogPath    = "C:\Scripts\Logs\cloudflare-ddns.log"
}

# Log rotation
$MaxLogSizeMB = 5
if ((Test-Path $Config.LogPath) -and ((Get-Item $Config.LogPath).Length / 1MB) -gt $MaxLogSizeMB) {
    $ArchivePath = $Config.LogPath -replace '\.log$', "-$(Get-Date -Format 'yyyyMMdd').log"
    Move-Item -Path $Config.LogPath -Destination $ArchivePath -Force
}

# Ensure log directory exists
$LogDir = Split-Path -Parent $Config.LogPath
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

function Write-Log {
    param([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$Timestamp - $Message" | Out-File -FilePath $Config.LogPath -Append
}

function Get-PublicIP {
    $IPServices = @(
        "https://api.ipify.org"
        "https://ifconfig.me/ip"
        "https://icanhazip.com"
    )
    
    foreach ($Service in $IPServices) {
        try {
            $IP = (Invoke-RestMethod -Uri $Service -TimeoutSec 10).Trim()
            if ($IP -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$') {
                return $IP
            }
        } catch {
            continue
        }
    }
    return $null
}

function Get-CloudflareDNS {
    $Headers = @{
        "Authorization" = "Bearer $($Config.ApiToken)"
        "Content-Type"  = "application/json"
    }
    
    $Uri = "https://api.cloudflare.com/client/v4/zones/$($Config.ZoneId)/dns_records/$($Config.RecordId)"
    
    try {
        $Response = Invoke-RestMethod -Uri $Uri -Headers $Headers -Method Get
        if ($Response.success) {
            return $Response.result.content
        }
    } catch {
        Write-Log "ERROR: Failed to query Cloudflare - $($_.Exception.Message)"
    }
    return $null
}

function Update-CloudflareDNS {
    param([string]$NewIP)
    
    $Headers = @{
        "Authorization" = "Bearer $($Config.ApiToken)"
        "Content-Type"  = "application/json"
    }
    
    $Body = @{
        type    = "A"
        name    = $Config.RecordName
        content = $NewIP
        ttl     = $Config.TTL
        proxied = $Config.Proxied
    } | ConvertTo-Json
    
    $Uri = "https://api.cloudflare.com/client/v4/zones/$($Config.ZoneId)/dns_records/$($Config.RecordId)"
    
    try {
        $Response = Invoke-RestMethod -Uri $Uri -Headers $Headers -Method Put -Body $Body
        return $Response.success
    } catch {
        Write-Log "ERROR: Failed to update Cloudflare - $($_.Exception.Message)"
        return $false
    }
}

# Main execution
$CurrentIP = Get-PublicIP

if (-not $CurrentIP) {
    Write-Log "ERROR: Failed to retrieve public IP"
    exit 1
}

$DnsIP = Get-CloudflareDNS

if (-not $DnsIP) {
    Write-Log "ERROR: Failed to retrieve current DNS record"
    exit 1
}

if ($CurrentIP -eq $DnsIP) {
    Write-Log "INFO: No update required ($CurrentIP)"
    exit 0
}

Write-Log "INFO: IP changed from $DnsIP to $CurrentIP"

if (Update-CloudflareDNS -NewIP $CurrentIP) {
    Write-Log "SUCCESS: Updated $($Config.RecordName) to $CurrentIP"
    exit 0
} else {
    Write-Log "ERROR: Update failed"
    exit 1
}
```

The script queries multiple IP detection services as fallbacks, compares against the current DNS record, and only calls the Cloudflare API when an update is needed.

## Retrieving Zone and Record IDs
---

You'll need the Zone ID and Record ID for your configuration. This one-liner retrieves both:

```powershell
$token = "YOUR_TOKEN"
$zone = (Invoke-RestMethod -Uri "https://api.cloudflare.com/client/v4/zones?name=yourdomain.com" -Headers @{"Authorization"="Bearer $token"}).result[0]
$record = (Invoke-RestMethod -Uri "https://api.cloudflare.com/client/v4/zones/$($zone.id)/dns_records?name=home.yourdomain.com" -Headers @{"Authorization"="Bearer $token"}).result[0]
Write-Host "Zone ID: $($zone.id)`nRecord ID: $($record.id)"
```

## Scheduled Task Setup
---

Create the scheduled task to run at login, startup, and every 30 minutes:

```powershell
# Create base task with login and startup triggers
$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"C:\Scripts\Cloudflare-DDNS.ps1`""

$TriggerLogon = New-ScheduledTaskTrigger -AtLogOn
$TriggerStartup = New-ScheduledTaskTrigger -AtStartup

$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RunOnlyIfNetworkAvailable

Register-ScheduledTask -TaskName "Cloudflare-DDNS" -Action $Action -Trigger $TriggerLogon, $TriggerStartup -Settings $Settings -Description "Updates Cloudflare DNS with current public IP"

# Add 30-minute repeating trigger
$TriggerRepeat = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 30) -RepetitionDuration (New-TimeSpan -Days 365)

$Task = Get-ScheduledTask -TaskName "Cloudflare-DDNS"
$Task.Triggers += $TriggerRepeat
Set-ScheduledTask -InputObject $Task
```

The `-WindowStyle Hidden` flag ensures no PowerShell window flashes when the task runs.

## Port Forwarding
---

With DDNS handling the DNS updates, you still need traffic to reach your VPN server. On the ISP router, create a port forward:

| Setting | Value |
|---------|-------|
| External Port | 1194 |
| Protocol | UDP |
| Internal IP | Your UniFi gateway's WAN IP |
| Internal Port | 1194 |

If OpenVPN runs directly on the UniFi gateway (as mine does), no additional port forward is needed on the UDR.

## OpenVPN Client Configuration
---

UniFi's OpenVPN server configuration only accepts IP addresses, not hostnames. The downloaded `.ovpn` file will contain the gateway's WAN IP, which is wrong in double NAT.

Edit the configuration file and change:

```shell
remote 192.168.1.12 1194
```

To:

```shell
remote home.yourdomain.com 1194
```

Now the VPN client performs a DNS lookup on each connection attempt, retrieving your current public IP.

## Testing
---

Run the task manually and check the log:

```powershell
Start-ScheduledTask -TaskName "Cloudflare-DDNS"
Get-Content "C:\Scripts\Logs\cloudflare-ddns.log" -Tail 5
```

Verify DNS resolution:

```powershell
nslookup home.yourdomain.com 1.1.1.1
```

Then test the VPN connection from your phone on mobile data.

## Conclusion
---

This approach elegantly sidesteps the double NAT limitation. Instead of trying to make the gateway aware of the public IP, we query it directly from inside the network and update Cloudflare ourselves.

The solution is also temporary. Once I configure PPPoE passthrough on my ISP router (or replace it entirely), the UDR will receive the public IP directly and native DDNS will work correctly. Until then, this PowerShell script keeps everything running smoothly.

Key takeaways:

- Native gateway DDNS fails in double NAT because the gateway can't see the real public IP
- External IP detection services bypass NAT layers entirely
- Scoped API tokens with minimal permissions reduce security exposure
- The solution requires no changes to the VPN server configuration
- Port forwarding must be configured on the outermost router

The full script and detailed configuration guide are available in my documentation repository.