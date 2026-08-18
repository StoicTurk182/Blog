---
title: "Self-Hosted UniFi Network Server on Linux"
date: 2026-08-18
draft: false
description: "Direct install guide for the self-hosted UniFi Network Application on Debian and Ubuntu, covering repository setup, MongoDB and Java dependencies, firewall ports, device adoption, and backups"
categories: ["System Administration"]
tags: ["unifi", "networking", "linux", "debian", "ubuntu", "mongodb", "self-hosted"]
readingTime: true
toc: true
author: "Andrew Jones"
authorImage: "/images/authors/devops-team.jpg"
authorBio: "Linux system administration and automation experts"
featuredImage: "/images/posts/swtich.jpg"
socialShare: true
---
# Self-Hosted UniFi Network Server on Linux

Install guide for the UniFi Network Application on a Debian or Ubuntu server, using Ubiquiti's APT repository. Written against Debian 12 and Ubuntu 22.04/24.04 LTS.

The application is installed as a service with no GUI on the host. All management is done through the web interface on port 8443. Since UniFi Network 5.6.x the service does not run as root, so it cannot bind to privileged ports below 1024.

## Prerequisites

- Debian or Ubuntu server with `sudo` and `wget` available
- Static IP address or a DHCP reservation on the management VLAN
- Outbound HTTPS to `www.ui.com`, `dl.ui.com`, and `repo.mongodb.org`
- Layer 2 reachability to UniFi devices, or a routed path plus DNS/DHCP option 43 for Layer 3 adoption

Back up the existing UniFi database before touching an in-place controller.

## Version Dependencies

The Java and MongoDB requirements changed at several release boundaries. Check these before choosing a MongoDB version, as UniFi will refuse to start against an unsupported database.

| UniFi Network version | Java | MongoDB |
| :--- | :--- | :--- |
| 7.5 to 8.0 | Java 17 | 3.6 minimum, up to 4.4 |
| 8.1 and newer | Java 17 | Up to 7.0 |
| 9.0 and newer | Java 17 or 21 | Up to 8.0 |

On a fresh build, install the newest MongoDB supported by the UniFi version being deployed. On an upgrade, MongoDB must be stepped through major versions in sequence (3.6, 4.0, 4.2, 4.4, 5.0, 6.0, 7.0) rather than jumped directly.

MongoDB 5.0 and later require AVX support on x86-64 CPUs. On older hardware or a VM with a restricted CPU model, MongoDB will fail to start with no useful error. Check with `grep -o avx /proc/cpuinfo | head -1` before committing to 5.0 or above.

Ubiquiti's own APT article still documents a MongoDB 3.6 repository line pinned to Ubuntu `bionic`. That instruction is retained for legacy compatibility and is not the correct choice for a new build on a current release.

## Step 1: Base Dependencies

```bash
sudo apt-get update
sudo apt-get install ca-certificates apt-transport-https wget curl gnupg -y
```

## Step 2: Add the UniFi Repository

```bash
echo 'deb [ arch=amd64,arm64 ] https://www.ui.com/downloads/unifi/debian stable ubiquiti' | sudo tee /etc/apt/sources.list.d/100-ubnt-unifi.list
```

Add the signing key:

```bash
sudo wget -O /etc/apt/trusted.gpg.d/unifi-repo.gpg https://dl.ui.com/unifi/unifi-repo.gpg
```

The `stable` suite tracks the current supported release. Ubiquiti recommends staying on `stable` rather than `testing`.

## Step 3: Add the MongoDB Repository

Example for MongoDB 8.0 on Ubuntu 24.04 (`noble`). Substitute the distribution codename and MongoDB version to match the target release.

```bash
curl -fsSL https://www.mongodb.org/static/pgp/server-8.0.asc | \
  sudo gpg -o /usr/share/keyrings/mongodb-server-8.0.gpg --dearmor

echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] https://repo.mongodb.org/apt/ubuntu noble/mongodb-org/8.0 multiverse" | \
  sudo tee /etc/apt/sources.list.d/mongodb-org-8.0.list
```

For Debian, substitute `apt/debian` and the Debian codename (`bookworm`) in the repository path.

Where the distribution already ships a compatible MongoDB in its own repositories, this step can be skipped.

## Step 4: Install

```bash
sudo apt-get update
sudo apt-get install unifi -y
```

The `unifi` package pulls in the Java runtime and MongoDB server as dependencies. Java 17 can be installed explicitly first if dependency resolution picks an unwanted version:

```bash
sudo apt-get install openjdk-17-jre-headless -y
```

## Step 5: Verify the Service

```bash
sudo systemctl status unifi
sudo systemctl enable unifi
```

Service control uses standard commands:

| Action | Command |
| :--- | :--- |
| Start | `sudo systemctl start unifi` |
| Stop | `sudo systemctl stop unifi` |
| Restart | `sudo systemctl restart unifi` |
| Status | `sudo systemctl status unifi` |

Confirm the listener is up before opening a browser:

```bash
sudo ss -tlnp | grep -E '8080|8443'
```

## Step 6: Firewall Ports

| Port | Protocol | Purpose |
| :--- | :--- | :--- |
| 8080 | TCP | Device inform (required) |
| 8443 | TCP | Web management interface (required) |
| 3478 | UDP | STUN (required) |
| 10001 | UDP | Device discovery (required) |
| 1900 | UDP | Layer 2 discovery from the mobile app |
| 8843 | TCP | Guest portal HTTPS redirect |
| 8880 | TCP | Guest portal HTTP redirect |
| 6789 | TCP | Mobile speed test |
| 5514 | UDP | Remote syslog |
| 27117 | TCP | Local MongoDB, loopback only, do not expose |

UFW example allowing the required set plus guest portal:

```bash
sudo ufw allow 8080/tcp
sudo ufw allow 8443/tcp
sudo ufw allow 3478/udp
sudo ufw allow 10001/udp
sudo ufw allow 8843/tcp
sudo ufw allow 8880/tcp
sudo ufw reload
```

Restrict 8443 to the management VLAN rather than allowing it broadly. Port 8080 must remain reachable from every subnet containing UniFi devices, as that is where devices check in.

## Step 7: First Run

Browse to `https://<server-ip>:8443` and accept the self-signed certificate warning.

The setup wizard covers:

1. Site name
2. Administrator account, with the option of a local-only account rather than a Ubiquiti SSO account
3. Auto-backup and auto-optimise toggles
4. Device adoption for anything already discovered on the local subnet

Choosing a local-only administrator avoids a dependency on Ubiquiti cloud authentication for day-to-day access. Record the credentials somewhere durable, as local accounts have no cloud-based recovery path.

## Device Adoption

Devices on the same Layer 2 segment as the controller are discovered automatically and appear under Devices with a Pending Adoption state.

For devices on a different subnet, the inform URL must be set manually. SSH to the device using the factory credentials `ubnt` / `ubnt`, or the SSH credentials configured on the site if the device was previously adopted:

```bash
ssh ubnt@<device-ip>
set-inform http://<controller-ip>:8080/inform
```

The device then appears as Pending Adoption in the controller. Click Adopt, then run `set-inform` a second time after adoption completes, as the device reverts to its default inform URL during provisioning.

Other options for Layer 3 adoption are DHCP option 43 pointing at the controller IP, or a DNS A record named `unifi` resolving to the controller. The DNS method is the least fragile of the three in a multi-VLAN environment, as it survives controller readdressing with a single record change.

Useful device-side commands over SSH:

| Command | Purpose |
| :--- | :--- |
| `info` | Show model, firmware, inform URL, and adoption status |
| `set-inform <url>` | Point the device at a controller |
| `set-default` | Factory reset, last resort |

## Backups

Auto-backups are written to:

```bash
/usr/lib/unifi/data/backup/autobackup
```

Configure retention under Settings > System > Backups. The backup file is a `.unf` archive that can be restored during the first-run wizard on a rebuilt server.

Copy backups off the host on a schedule. A controller backup held only on the controller is not a backup:

```bash
rsync -av /usr/lib/unifi/data/backup/autobackup/ /mnt/backup/unifi/
```

Backup before every UniFi or MongoDB upgrade. There is no supported downgrade path for the database once a major MongoDB version has been applied.

## Upgrades

```bash
sudo apt-get update
sudo apt-get install unifi -y
```

Where `apt-get update` fails after a major version change, the release metadata has changed and must be accepted:

```bash
sudo apt-get update --allow-releaseinfo-change
```

Application upgrades may cause adopted devices to be re-provisioned, which briefly interrupts client connectivity. Schedule accordingly.

## Log Files

| Path | Contents |
| :--- | :--- |
| `/usr/lib/unifi/logs/server.log` | Application log, first place to check |
| `/usr/lib/unifi/logs/mongod.log` | Database log |

Superuser privileges are required to read both.

## Troubleshooting

| Symptom | Resolution |
| :--- | :--- |
| Service starts then immediately stops | Check `server.log` for a MongoDB version rejection or a Java version mismatch. Confirm the installed MongoDB against the version table above. |
| MongoDB fails to start with no clear error | Confirm AVX support on the CPU if running MongoDB 5.0 or later. |
| Port 8080 reported as in use | Another service holds the port. Identify it with `sudo ss -tlnp \| grep 8080`, or change the port in `/usr/lib/unifi/data/system.properties` and restart. |
| Web interface unreachable | Confirm the service is running, then confirm 8443 is permitted by the host firewall and any upstream firewall. |
| Devices not appearing for adoption | Layer 3 separation between device and controller. Use `set-inform`, DHCP option 43, or a `unifi` DNS record. |
| Slow start or intermittent service failure on a VM | Entropy starvation on headless virtual machines. Installing `haveged` is the documented workaround. |
| Application will not bind to a chosen port | Ports below 1024 are unavailable, as the service does not run as root. |

## Note on UniFi OS Server

Ubiquiti's newer self-hosting path is UniFi OS Server, which runs the UniFi applications in containers using Podman via an official installation script, rather than the APT package and MongoDB pairing described here. It targets Debian 12 and later and Ubuntu 22.04 and later on x64 hardware, and provides the multi-application experience of a Cloud Gateway on self-managed hardware.

The APT method above remains valid for Network-only deployments and is the lighter option where the host is already running other services. For new builds intended to grow beyond Network alone, UniFi OS Server is the more likely long-term direction, though at the time of writing the APT package continues to be published and documented by Ubiquiti.

## References

- Updating and Installing Self-Hosted UniFi Network Servers (Linux): https://help.ui.com/hc/en-us/articles/220066768-Updating-and-Installing-Self-Hosted-UniFi-Network-Servers-Linux
- Self-Hosting a UniFi Network Server: https://help.ui.com/hc/en-us/articles/360012282453-Self-Hosting-a-UniFi-Network-Server
- Required Ports Reference: https://help.ui.com/hc/en-us/articles/218506997-Required-Ports-Reference
- UniFi Network Application release notes: https://community.ui.com/releases
- UniFi downloads: https://ui.com/download
- MongoDB installation on Ubuntu: https://www.mongodb.com/docs/manual/tutorial/install-mongodb-on-ubuntu/
- MongoDB production notes, CPU requirements: https://www.mongodb.com/docs/manual/administration/production-notes/
- Debian sudo documentation: https://wiki.debian.org/sudo