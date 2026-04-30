---
title: "nfty - Server Alerts"
category: "SysOps"
thumbnail: "/images/posts/nfty_project.png"
status: "Active"
weight: 20
date: 2026-01-01
---


Centralised log ingestion and search via Graylog...

## Overview

lightweight push notification layer. The practical use cases for my context would be alerting on things like VPN tunnel state changes, backup job completions, Ansible playbook results from Semaphore, and disk threshold warnings from the OVH monitoring scripts. 

A big focus here is the alerting from CroudSec and related security software. 

---

## Stack

- ntfy (binwiederhier/ntfy)
- Docker Compose
- Nginx reverse proxy
- SQLite (message cache)
- iOS / Android native app