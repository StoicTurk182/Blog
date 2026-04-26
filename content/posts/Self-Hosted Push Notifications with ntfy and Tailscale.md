---
title: "Self-Hosted Push Notifications with ntfy and Tailscale"
date: 2026-04-26
lastmod: 2026-04-26
draft: false
author: "Andrew Jones"
description: "How to deploy a self-hosted ntfy notification server on a Debian VPS, bound exclusively to a Tailscale network interface with TLS, and wired up to real monitoring triggers."
categories: ["Homelab"]
tags: ["ntfy", "Tailscale", "VPS", "Notifications", "Linux", "Self-Hosted", "CrowdSec"]
featuredImage: "/images/posts/ntfy_banner.C-upLjMo_1S59W2.png"
toc: true
---

## Why ntfy

Most self-hosted notification setups require either a cloud relay, a Firebase account, or exposing a service to the public internet. ntfy sidesteps all of that. It is a lightweight HTTP pub/sub notification server — you publish a message to a topic via `curl`, and any subscribed client receives it. No accounts, no third-party relay, no Firebase.

The missing piece for a home lab or VPS deployment is keeping it off the public internet entirely. Tailscale solves that cleanly. By binding ntfy exclusively to the Tailscale network interface, the service is only reachable by devices on your Tailnet — encrypted end-to-end by WireGuard, with no firewall rules to manage beyond blocking the default HTTP listener.

This post covers the full deployment: ntfy install, Tailscale certificate, monitoring triggers, and CrowdSec integration.

---

## Architecture

The setup is deliberately minimal:

```bash
[Any device on your Tailnet]
        |
   Tailscale mesh (WireGuard)
        |
   VPS Tailscale interface
        |
   ntfy (listening on Tailscale IP only, HTTPS)
        |
   Topic-based pub/sub (alerts, crowdsec, etc.)
```

ntfy binds only to the Tailscale-assigned IP. It is not reachable on the public interface regardless of firewall state, because the socket is never opened there. A Tailscale-issued TLS certificate covers the Tailscale hostname, giving you proper HTTPS without a reverse proxy or public DNS.

---

## Prerequisites

- A Debian 12 VPS (the instructions will work on Ubuntu with minor changes)
- Tailscale installed and authenticated — `tailscale up` completed
- Your Tailscale IP and hostname noted:

```bash
tailscale ip -4
tailscale status | head -1
```

These two values are used throughout. The Tailscale hostname takes the form `machine-name.tail-xxxxx.ts.net`.

---

## Installing ntfy

The official ntfy Debian repository moved to `archive.ntfy.sh` in September 2025. Add it and install:

```bash
sudo mkdir -p /etc/apt/keyrings

sudo curl -L -o /etc/apt/keyrings/ntfy.gpg \
  https://archive.ntfy.sh/apt/keyring.gpg

sudo apt install -y apt-transport-https

echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/ntfy.gpg] https://archive.ntfy.sh/apt stable main" \
  | sudo tee /etc/apt/sources.list.d/ntfy.list

sudo apt update && sudo apt install -y ntfy
```

GPG fingerprint for verification: `55BA 774A 6F5E E674 31E4 B6B7 CFDB 962D 4F1E C4AF`

---

## Issuing a Tailscale TLS Certificate

Before configuring ntfy, issue a TLS certificate for your Tailscale hostname. This requires HTTPS certificates to be enabled in the Tailscale admin console first.

Go to `https://login.tailscale.com/admin/dns`, scroll to HTTPS Certificates, and enable it. MagicDNS must also be active on the same page.

Then on the VPS:

```bash
sudo mkdir -p /etc/ntfy/certs

sudo tailscale cert \
  --cert-file /etc/ntfy/certs/<your-hostname>.crt \
  --key-file  /etc/ntfy/certs/<your-hostname>.key \
  <your-hostname>
```

Set ownership so ntfy can read the key:

```bash
sudo chown -R ntfy:ntfy /etc/ntfy/certs
sudo chmod 750 /etc/ntfy/certs
```

Verify the cert was issued correctly:

```bash
openssl x509 -in /etc/ntfy/certs/<your-hostname>.crt \
  -noout -subject -dates
```

Certificates are issued by Let's Encrypt via Tailscale and expire after 90 days. Auto-renewal is covered later.

---

## Configuring ntfy

Write the server configuration bound to your Tailscale IP:

```bash
sudo tee /etc/ntfy/server.yml > /dev/null << 'EOF'
# Bind exclusively to Tailscale interface
listen-https: "<your-tailscale-ip>:2586"

cert-file: "/etc/ntfy/certs/<your-hostname>.crt"
key-file:  "/etc/ntfy/certs/<your-hostname>.key"

base-url: "https://<your-hostname>:2586"

cache-file: "/var/cache/ntfy/cache.db"
cache-duration: "12h"

visitor-request-limit-burst: 60
visitor-request-limit-replenish: "5s"
visitor-subscription-limit: 30

log-level: "info"

# Disable the default public HTTP listener
listen-http: "-"
EOF
```

The `listen-http: "-"` line is important. Without it, ntfy opens a default listener on `:80` bound to all interfaces including your public IP. Always include it when using `listen-https`.

### Ensuring ntfy Starts After Tailscale

Without this, ntfy may attempt to bind before Tailscale assigns the IP:

```bash
sudo mkdir -p /etc/systemd/system/ntfy.service.d

sudo tee /etc/systemd/system/ntfy.service.d/tailscale.conf > /dev/null << 'EOF'
[Unit]
After=tailscaled.service
Wants=tailscaled.service
EOF

sudo systemctl daemon-reload
```

### Start and Verify

```bash
sudo systemctl enable ntfy
sudo systemctl start ntfy
sudo journalctl -u ntfy -n 5 --no-pager | grep Listening
```

Expected output:

```bash
Listening on <your-tailscale-ip>:2586[https]
```

A single HTTPS listener on the Tailscale IP. No `:80` entry.

Test the health endpoint from the VPS:

```bash
curl https://<your-hostname>:2586/v1/health
```

Expected: `{"healthy":true}`

---

## The Alert Helper Script

Rather than calling curl directly from every script, a small wrapper keeps things consistent. The key pattern when writing this to disk is to avoid any automated tooling that might corrupt the hostname — write a placeholder and replace it in a text editor.

```bash
sudo tee /usr/local/bin/ntfy-alert.sh > /dev/null << 'EOF'
#!/bin/bash
NTFY_HOST="PLACEHOLDER"
NTFY_PORT="2586"
NTFY_TOPIC="alerts"
NTFY_URL="https://${NTFY_HOST}:${NTFY_PORT}"

ntfy_send() {
    local title="${1:?title required}"
    local message="${2:?message required}"
    local priority="${3:-default}"
    if ! tailscale ip -4 &>/dev/null; then
        echo "ERROR: Tailscale not running" >&2
        return 1
    fi
    curl -s -H "Title: ${title}" -H "Priority: ${priority}" \
        -d "${message}" "${NTFY_URL}/${NTFY_TOPIC}" > /dev/null
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    [ $# -lt 2 ] && { echo "Usage: $0 Title Message [priority]"; exit 1; }
    ntfy_send "$1" "$2" "${3:-default}"
fi
EOF

sudo chmod 755 /usr/local/bin/ntfy-alert.sh
```

Open the file and replace `PLACEHOLDER` with your Tailscale hostname:

```bash
sudo nano /usr/local/bin/ntfy-alert.sh
```

Test it:

```bash
ntfy-alert.sh "Test" "ntfy is working" "default"
```

---

## Monitoring Triggers

With the helper in place, a single cron script handles all polling-based alerts. It checks disk usage, systemd service state, Postfix relay errors, and Fail2ban bans every five minutes.

State files in `/var/lib/vps-monitor/` prevent the same alert firing repeatedly while a condition persists. A single notification fires when the condition is first detected, and clears automatically when it resolves.

```bash
sudo tee /usr/local/bin/vps-monitor.sh > /dev/null << 'EOF'
#!/bin/bash
NTFY_HOST="PLACEHOLDER"
NTFY_PORT="2586"
NTFY_TOPIC="alerts"
NTFY_URL="https://${NTFY_HOST}:${NTFY_PORT}"
HOSTNAME_SHORT=$(hostname)
SERVICES=("ntfy" "postfix" "crowdsec" "fail2ban")
DISK_THRESHOLD=80
STATE_DIR="/var/lib/vps-monitor"
mkdir -p "${STATE_DIR}"

send_alert() {
    curl -s -H "Title: $1" -H "Priority: ${3:-high}" \
        -d "$2" "${NTFY_URL}/${NTFY_TOPIC}" > /dev/null
}

# Disk check
DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
STATE_FILE="${STATE_DIR}/disk_alert"
if [ "${DISK_USAGE}" -ge "${DISK_THRESHOLD}" ]; then
    [ ! -f "${STATE_FILE}" ] && send_alert \
        "Disk Warning - ${HOSTNAME_SHORT}" \
        "Root at ${DISK_USAGE}% on ${HOSTNAME_SHORT}" "high" && touch "${STATE_FILE}"
else
    rm -f "${STATE_FILE}"
fi

# Service checks
for SERVICE in "${SERVICES[@]}"; do
    STATE_FILE="${STATE_DIR}/service_${SERVICE}"
    if ! systemctl is-active --quiet "${SERVICE}"; then
        [ ! -f "${STATE_FILE}" ] && send_alert \
            "Service Down - ${HOSTNAME_SHORT}" \
            "${SERVICE} is not running on ${HOSTNAME_SHORT}" "urgent" && touch "${STATE_FILE}"
    else
        rm -f "${STATE_FILE}"
    fi
done

# Postfix errors
STATE_FILE="${STATE_DIR}/postfix_alert"
POSTFIX_ERRORS=$(journalctl -u postfix --since "5 minutes ago" --no-pager -q 2>/dev/null | \
    grep -cE "SASL authentication failed|Connection refused|relay.*refused" || true)
if [ "${POSTFIX_ERRORS}" -gt 0 ]; then
    [ ! -f "${STATE_FILE}" ] && send_alert \
        "Postfix Error - ${HOSTNAME_SHORT}" \
        "${POSTFIX_ERRORS} relay error(s) in last 5 min" "high" && touch "${STATE_FILE}"
else
    rm -f "${STATE_FILE}"
fi

# Fail2ban bans
BANS=$(journalctl -u fail2ban --since "5 minutes ago" --no-pager -q 2>/dev/null | \
    grep -c "Ban " || true)
if [ "${BANS}" -gt 0 ]; then
    IPS=$(journalctl -u fail2ban --since "5 minutes ago" --no-pager -q 2>/dev/null | \
        grep "Ban " | awk '{print $NF}' | tr '\n' ' ')
    send_alert "Fail2ban - ${HOSTNAME_SHORT}" "${BANS} IP(s) banned: ${IPS}" "default"
fi
EOF
```

Replace PLACEHOLDER in nano, then install the cron job:

```bash
sudo chmod 755 /usr/local/bin/vps-monitor.sh
sudo mkdir -p /var/lib/vps-monitor

echo "*/5 * * * * root /usr/local/bin/vps-monitor.sh" \
  | sudo tee /etc/cron.d/vps-monitor

sudo chmod 644 /etc/cron.d/vps-monitor
```

---

## CrowdSec Integration

CrowdSec has a native HTTP notification plugin that fires on every ban decision in real time — no polling needed. Create the notification config:

```bash
sudo tee /etc/crowdsec/notifications/http.yaml > /dev/null << 'EOF'
type: http
name: ntfy_alerts

log_level: info

format: |
  {{range . -}}
  CrowdSec alert on <your-hostname-short>
  Scenario: {{.Scenario}}
  {{end -}}

url: https://<your-hostname>:2586/crowdsec

method: POST

headers:
  Title: "CrowdSec Ban"
  Priority: "high"
  Tags: "ban,crowdsec"

timeout: 10s
EOF
```

A note on the format template: the `cscli notifications test` command sends a minimal mock object. Fields like `.Value`, `.Type`, and `.Source.IP` are not available in the test context and will cause template errors. Only `.Scenario` is reliably available for testing. Real ban decisions expose the full set of fields.

Register the notification in `/etc/crowdsec/profiles.yaml` under the `default_ip_remediation` block:

```yaml
notifications:
  - ntfy_alerts
```

Indentation is two spaces before the dash. Then restart CrowdSec and test:

```bash
sudo systemctl restart crowdsec
sudo cscli notifications test ntfy_alerts
```

Verify delivery:

```bash
curl https://<your-hostname>:2586/crowdsec/json?since=10m
```

Test with a real decision:

```bash
sudo cscli decisions add --ip 1.2.3.4 --duration 1m --reason "ntfy test"
sudo cscli decisions delete --ip 1.2.3.4
```

---

## Certificate Auto-Renewal

Tailscale certificates expire after 90 days. A monthly cron job handles renewal and only restarts ntfy if the certificate actually changed:

```bash
sudo tee /usr/local/bin/ntfy-cert-renew.sh > /dev/null << 'EOF'
#!/bin/bash
HOSTNAME="PLACEHOLDER"
CERT_FILE="/etc/ntfy/certs/${HOSTNAME}.crt"
KEY_FILE="/etc/ntfy/certs/${HOSTNAME}.key"
LOG_TAG="ntfy-cert-renew"

BEFORE=$(openssl x509 -in "${CERT_FILE}" -noout -fingerprint 2>/dev/null)

tailscale cert --cert-file "${CERT_FILE}" --key-file "${KEY_FILE}" \
  "${HOSTNAME}" 2>&1 | logger -t "${LOG_TAG}"

chown ntfy:ntfy "${CERT_FILE}" "${KEY_FILE}"
chmod 640 "${KEY_FILE}" && chmod 644 "${CERT_FILE}"

AFTER=$(openssl x509 -in "${CERT_FILE}" -noout -fingerprint 2>/dev/null)

if [ "${BEFORE}" != "${AFTER}" ]; then
    logger -t "${LOG_TAG}" "Certificate renewed - restarting ntfy"
    systemctl restart ntfy
else
    logger -t "${LOG_TAG}" "Certificate unchanged - no restart needed"
fi
EOF

sudo chmod 755 /usr/local/bin/ntfy-cert-renew.sh

echo "0 3 1 * * root /usr/local/bin/ntfy-cert-renew.sh" \
  | sudo tee /etc/cron.d/ntfy-cert-renew

sudo chmod 644 /etc/cron.d/ntfy-cert-renew
```

Replace PLACEHOLDER in nano before saving.

---

## Mobile App

Install the ntfy app from F-Droid for self-hosted use. The Play Store build uses Firebase for background push, which requires the server to be internet-accessible. The F-Droid build polls over Tailscale directly.

- F-Droid: `io.heckel.ntfy`

Add your server in the app settings, then subscribe to your topics (`alerts`, `crowdsec`, or whatever you have configured). Tailscale must be active on the phone for the app to connect.

---

## What You End Up With

A fully private notification stack with no cloud dependency, no public exposure, and no third-party accounts beyond Tailscale:

- ntfy running on your VPS, reachable only from your Tailnet
- HTTPS via a Tailscale-issued Let's Encrypt certificate
- Disk, service, Postfix, and Fail2ban alerts via a five-minute cron script
- Real-time CrowdSec ban notifications
- Mobile delivery over Tailscale to the ntfy Android app

The entire setup survives a VPS reboot cleanly provided the systemd ordering drop-in is in place — ntfy waits for Tailscale before attempting to bind.

---

## References

- ntfy Documentation: https://docs.ntfy.sh/
- ntfy Installation: https://docs.ntfy.sh/install/
- ntfy Server Configuration: https://docs.ntfy.sh/config/
- Tailscale HTTPS Certificates: https://tailscale.com/kb/1153/enabling-https/
- CrowdSec HTTP Notification Plugin: https://docs.crowdsec.net/docs/notification_plugins/http/
- ntfy Android App (F-Droid): https://f-droid.org/en/packages/io.heckel.ntfy/
- Let's Encrypt Certificate Validity: https://letsencrypt.org/docs/faq/