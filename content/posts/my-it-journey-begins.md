---
title: "Self Hosting a New Blog"
date: 2025-10-30T14:53:39Z
draft: false
author: "Andrew Jones"
tags: ["Blog"]
categories: ["Infrastructure"]
featured_image: "/images/posts/my-it-journey-begins/featured.jpg"
description: "My IT journey Continues - insights from Andrew Jones, IT Engineer in London, UK"
toc: true
---

Welcome to my new blog! After years working in IT, I've decided to document my journey, share what I'm learning, and create a resource for others in the technology field.

<!--more-->

## Why Start This Blog?
---

As an IT Engineer based in London, I constantly encounter interesting challenges and solutions that I believe are worth sharing. This blog will serve as:

- **A knowledge base** for my future self
- **A resource** for other IT professionals
- **A journal** of my growth in the technology field

## What to Expect
---

I'll be covering topics like:

- **System Administration** - Linux, Windows, networking
- **Cloud Technologies** - AWS, Azure, and self-hosting
- **Automation** - Scripting, DevOps practices
- **Career Development** - IT certifications, skill building
- **Project Showcases** - Real-world implementations

## First Steps
---

This blog is built with **Hugo** and the **Mainroad theme**, hosted on my own Debian VPS. It's been a great learning experience setting everything up from scratch!

## My Journey into Production Networking
---

I have long sought to really deploy an extensive real world production network, but I was always held back by time or constraints caused by real life commitments. This project has been me forcing myself to really apply all that I have learned over the last few years by immersing myself in IT, technology and to some extent science fiction.

What was once the purview of my wildest imaginings is now daily routine and the extent by which computers have advanced is truly stunning to me.

Linux has always held deep fascination with me, but I have never really decided to stick at it and use it for major projects; this has changed in recent times as I find myself really engrossed in using this operating system and learning all I can from it.

## The Abstraction of Technology
---

Technology and the understanding of it in the context of computers is like looking at a grain of sand and seeing someone play a modern video game - realizing from a materials perspective all integrated circuits are just that, sand. It really is a complex transformation, that is very abstract at scale.

I want to convey that scale, when it comes to massively disparate systems of complexity where no one person understands every aspect of a system. You are forced to develop specificity as the subject matter is simply, too complex. This leads inexorably to abstraction so the people who work at the layer above can understand the principle of the layer below.

This is the heart of modern computer systems and the networks that connect them, this is why I needed to really focus on mastering Linux. It is not just another OS, it is the backbone of the interlink of 98 percent of all the computers on the planet and to not learn about it in-depth is a gross mis-service to my development as an enthusiast.

## Embracing the Learning Process
---

I had to, very recently, admit to myself that I can never know it all, even if I had a millennium of time, I would never be able to retain all the required knowledge to make a computer. What I can do is work on trying to know a system I created and manage that system as well as I can. Learning as much as I can along the way - it's a process and I would like to detail that process below in as simple terms as I can.

I created this blog via Hugo as an experiment on:

1. Learning modern web development
2. Being able to have an excuse to build and maintain a network that involves many different skills that I have learned over the last few years

Also, as an attempt to try to understand the interplay and relationship between hardware and software and by extension DEV-ops. As most of the technologies I used to build all of this began, as most do, in a notepad. Zero physical interaction pure virtualisation.

### Topology (obfuscated-simple layout)
---

```text
====================================
=== DUAL SERVER NETWORK TOPOLOGY ===
====================================

Generated: 2025-11-05 | Active Infrastructure

          INTERNET
             │
             ├── PUBLIC GATEWAY x.x.x.x/x - UFW / Fail2ban / PAM / RSA-K / Password
             │
        SERVER 1 (vps-webserver) - PRODUCTION
             ├── ens3 (PUBLIC: x.x.x.x/x)
             │   ├── SSHD:22 ← x.x.x.x/x
             │   └── Nginx:80,443
             │
             ├── WireGuard (wg0: 10.0.0.16/24)
             │   ├── PEER: x.x.x.x/x:51820
             │   ├── Samba:445 ← x.x.x.x
             │   └── Services Route
             │
             └── Tailscale (100.XXX.XXX.XXX) [Webmin Front end Access]
                 └── Management Access

        SERVER 2 (vps-VPN server) - OBFUSCATED
             ├── ens3 (PUBLIC: x.x.x.x/x)
             │   ├── SSHD:22
             │   └── Nginx:80
             │
             ├── WireGuard (wg0: x.x.x.x/xx) - Server
             │   ├── Multiple Peers
             │   ├── Samba Client
             │   └── Other Peers
             │
             └── Tailscale (100.XXX.XXX.XXX) - [Webmin Front end Access]
                 └── Management Access
             

=== DOCKER INFRASTRUCTURE ===
SERVER 1:
br-XXXXX (192.168.80.XXX) ────┐
  ├─ c5b0f1... (vw-network)   │ ACTIVE
  └─ fe236a6... (vw-network)  │

SERVER 2:  
Multiple bridge networks
  ├─ br-XXXXX (172.17.0.XXX) ✗ DOWN
  ├─ br-XXXXX (172.19.0.XXX) ✗ DOWN
  └─ br-XXXXX (192.168.80.XXX) ✓ ACTIVE

=== CROSS-SERVER TRAFFIC === [Inter Net routing only via VPN]
SERVER 1 ↔ SERVER 2 via:
• WireGuard VPN (10.0.0.XXX)
• Tailscale (100.XXX.XXX.XXX)
• Internet (Public IPs)

=== SECURITY STATUS ===
✅ BOTH SERVERS: Firewall Active
✅ SAMBA: WireGuard-only access
✅ DOCKER: Isolated networks
✅ WIREGUARD: Active multi-peer
✅ SSH: Custom ports - [VPN only]
```

## Project Outcomes & Security
---

The above is the basic framework of what drives the site "you are on right now" and it has been a very interesting project to work on. My understanding of Linux has improved immeasurably, and my theoretical networking comprehension has also been put to the test.

This has also given me a golden opportunity to create my own security architecture and really test my port knowledge and research capabilities, this in turn has presented the opportunity to take a real go at pen testing my own deployments. I have also been using [Lynis](https://cisofy.com/lynis/) as a native security auditing tool to get a better idea of holes in my infrastructure.

## Applied Skills & Automation
---

**Other skills I have applied:**
- Learning about Linux automations like Cron to make task automated and thus, stress free
- Scripting my own backups under my own cadence internal, cloud external and dedicated archive local
- Creating my own VPN server and having be a work horse across my network
- Security testing and weakness testing etc

## Core Technologies & Skills
---

### Infrastructure & Hosting
---
- Cloud VPS Providers (Scaleway, DigitalOcean, etc.)
- Linux Server Administration (Ubuntu/Debian)
- IPv4 & IPv6 Networking
- DNS Management

### VPN Technologies
---
- WireGuard (Site-to-site & remote access VPN)
- Tailscale (Mesh VPN/Magic DNS)
- Firewall Management (UFW/iptables)

### Containerization & Services
---
- Docker + Docker Compose
- Container Networking (Bridge networks)
- Web Server (Nginx/Apache)
- File Sharing (Samba/SMB)
- Database Systems (Based on your apps)
- SSH Server Management

### Monitoring & Management
---
- System Monitoring (PM2, custom scripts)
- Log Management
- Web-based Admin (Webmin)

## Skills Developed
---

### Networking Skills
---
- Subnetting & CIDR (IPv4/IPv6)
- Routing Table Management
- VPN Configuration (WireGuard peers, keys)
- Firewall Policy Design
- Network Segmentation
- DNS Configuration

### Security Skills
---
- SSH Hardening (Key-based auth, custom ports)
- Service Isolation (Public vs VPN-only services)
- Port Management & Service Binding
- Access Control (IP-based restrictions)

### System Administration
---
- Linux Server Management
- Docker Container Orchestration
- Service Configuration (Nginx, Samba, SSH)
- Backup Strategies
- Certificate Management (SSL/TLS)

### Architectural Skills
---
- Multi-homed Service Design (services on multiple interfaces)
- Traffic Flow Optimization
- Failover Planning
- Load Distribution

