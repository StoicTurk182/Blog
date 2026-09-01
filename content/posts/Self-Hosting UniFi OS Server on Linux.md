---
title: "Self-Hosting UniFi OS Server on Linux"
date: 2026-08-30
draft: false
description: "Install guide for UniFi OS Server on Debian and Ubuntu, covering Podman dependencies, the installer binary, service management, port changes from Network Server, and migration from the legacy controller"
categories: ["System Administration"]
tags: ["unifi", "networking", "linux", "podman", "containers", "self-hosted", "ubiquiti"]
readingTime: true
toc: true
author: "Andrew Jones"
authorImage: "/images/authors/devops-team.jpg"
authorBio: "Linux system administration and automation experts"
featuredImage: "/images/posts/swtich.jpg"
socialShare: true
---
# Self-Hosting UniFi OS Server on Linux

UniFi OS Server is Ubiquiti's current self-hosting platform, replacing the legacy UniFi Network Server. Ubiquiti's position is that the Network Server provided basic hosting but lacked UniFi OS features such as Organizations, IdP Integration, and Site Magic SD-WAN, and that UniFi OS Server delivers the same management experience as UniFi-native hardware including CloudKeys and Cloud Gateways, with full Site Manager compatibility.

It is license-free and available to all UniFi users.

Unlike the Network Server, this is not an APT package. It ships as a self-extracting installer binary that provisions a Podman container, a `uosserver` system user, and a systemd unit on the host.

## What It Is Not

Establish these constraints before building, as several are not reversible without a rebuild.

| Question | Answer |
| :--- | :--- |
| Available as a standalone Docker/Podman container? | No. Certain services must run on the host to enable device discovery, adoption, and automatic system updates. |
| Docker supported? | No. Podman only. |
| Can it self-host Protect, Access, Talk, or Connect? | No. Those require a compatible UniFi Console. |
| Can it manage a Cloud Gateway (UDM, UCG, Fortress)? | No. Cloud Gateways include Network in their own control plane. Pairing requires an Independent Gateway from the UXG series. |
| Can a CloudKey run alongside it? | Not for Network, since devices are managed by a single host. A CloudKey can supplement it by running Protect, Access, Talk, and Connect. |
| Can it view devices adopted by another controller? | No. It is not a viewer for other UniFi Network applications. |

The Cloud Gateway exclusion is the one that catches people out. A UDM or UCG cannot be adopted into a UniFi OS Server deployment at all.

## Requirements

Ubiquiti's stated requirements:

| Component | Requirement |
| :--- | :--- |
| Linux | Ubuntu 24.04 or later, Debian 13 or later, or any modern distribution meeting the component requirements below |
| Init system | systemd |
| libc | 2.31 or later |
| Podman | 4.9.3 or later, using pasta networking |
| slirp4netns | 1.2 or later, usually installed with Podman but sometimes packaged separately |
| CPU | x86-64 processor |
| RAM | Minimum 2GB |
| Storage | At least 10GB free |
| Network | 100Mbps wired Ethernet |

Two of these are worth treating with caution. Community installation reports put the practical RAM floor at 4GB, with the most common cause of a failed start being insufficient memory, and describe the installer pre-checking free space and refusing to run below roughly 25GB. Ubiquiti's published minimums appear to be absolute floors rather than working figures, so sizing to 4GB RAM and 25GB disk is the safer starting point.

Older third-party guides cite Podman 4.3.1 as the minimum. Ubiquiti's current documentation states 4.9.3 with pasta networking, which is the figure to build against.

## Step 1: Install Podman

```bash
sudo apt-get update
sudo apt-get install podman slirp4netns -y
```

Verify the versions meet the requirements before continuing:

```bash
podman --version
slirp4netns --version
ldd --version | head -n1
```

Where the distribution repository ships a Podman older than required, the host is on too old a release. Upgrading the distribution is preferable to adding a third-party container repository, as the installer depends on host-level networking behaviour.

## Step 2: Obtain the Installer Link

The installer is not on a fixed URL. Download links are per-release and are found on the [Releases](https://community.ui.com/releases) section of the community site or the [Download page](https://ui.com/download), by right-clicking the Linux download and copying the link address.

The resulting URL takes a form similar to:

``` bash
https://fw-download.ubnt.com/data/unifi-os-server/<hash>-linux-x64-<version>-<uuid>-x64
```

Download links expire, so pull a fresh one rather than reusing a URL from an older guide.

## Step 3: Download and Run

```bash
mkdir -p ~/unifi-os && cd ~/unifi-os
curl -O <uos_server_download_link>
chmod +x <downloaded_filename>
sudo ./<downloaded_filename>
```

`wget` works equally well in place of `curl -O`.

The installer scaffolds the Podman container, creates the `uosserver` system user that owns the container namespace, and registers the systemd unit.

A warning that `unifi-core` did not start within 60 seconds is commonly reported and does not indicate failure. The installer times out before initialisation completes while the service continues starting in the background. Allow three to five minutes before opening a browser. If the interface is still unreachable after that, insufficient RAM is the most frequently reported cause.

## Step 4: Service Management

| Action | Command |
| :--- | :--- |
| Start | `sudo systemctl start uosserver` |
| Stop | `sudo systemctl stop uosserver` |
| Enable at boot | `sudo systemctl enable uosserver` |
| Disable at boot | `sudo systemctl disable uosserver` |
| Status | `sudo systemctl status uosserver` |

Container state can be inspected directly under the `uosserver` user:

```bash
sudo -u uosserver podman ps
```

A healthy install shows the container `Up` with a healthy status.

## Step 5: First Run

Browse to `https://<server-ip>:11443` and proceed past the self-signed certificate warning.

Port 11443 is the UniFi OS Server management interface. This differs from the Network Server's 8443.

Setup covers naming the server and choosing an authentication model:

**Local credentials** create a Super Admin account local to the server. No cloud dependency, no remote management.

**UI SSO** signs in with a Ubiquiti account and enables remote management through Site Manager, along with cloud backups, notifications, Teleport, and Site Magic VPN.

Skipping the sign-in gives a fully offline deployment at the cost of those features. The choice is worth making deliberately, since it determines whether the deployment has any recovery path outside the host itself.

## Network Ports

Ubiquiti's own article directs readers to the general ports reference rather than listing a UniFi OS Server set. Third-party sources covering the product consistently list the following:

| Port | Purpose |
| :--- | :--- |
| 11443 | UniFi OS management interface |
| 8080 | Device inform |
| 3478 | STUN |
| 8444 | Captive portal |
| 8880 | Guest portal HTTP redirect |
| 8881, 8882 | Guest portal, additional |
| 6789 | Mobile speed test |
| 5514 | Remote syslog |
| 5005, 9543, 10003 | Platform services |

Treat this list as a starting point rather than an authoritative reference, and confirm against Ubiquiti's ports documentation for a production build. Ubiquiti explicitly calls out TCP 8080 and UDP 3478 as necessary.

**The captive portal moved.** Portals are served on port 8444 under UniFi OS Server, changed from 8843 on Network Server. That port serves the certificate configured in the UniFi OS Console settings, or is served directly from UniFi Network where TLS is not configured. Any firewall rule or upstream NAT referencing 8843 needs updating.

## Certificates

The self-signed certificate warning can be safely ignored, and a custom TLS certificate can be uploaded under:

``` bash
Settings > Control Plane > Console > Certificates
```

## Updates

UniFi OS Server and its applications update from the Update Manager in Site Manager, or from the local Control Plane settings.

Manual upgrade by re-running a newer installer binary is also reported to work: the installer detects the existing installation, stops the container, swaps the image, and restarts the service, with configuration and data surviving in the named Podman volumes.

## Migrating from Network Server

1. Take a backup from the existing UniFi Network Server
2. Close the Network Server before installing UniFi OS Server
3. Install UniFi OS Server following the steps above
4. Migrate the data

On macOS and Windows the installer automatically detects and offers to migrate an existing Network Server installed in the default location. **On Linux there is no auto-migration** — the documented path is to install UniFi OS Server and use the Site Export tool.

Two constraints during migration:

**Do not run both.** Devices are managed by a single host. The Network Server must be stopped before UniFi OS Server is installed.

**Do not clone the VM.** Ubiquiti advises against cloning except for high availability or failover, because cloned VMs reuse the same remote access tokens for Site Manager and Fabrics, producing unexpected behaviour. Build fresh installations instead.

## Uptime Expectations

The server must continue running at all times to view and manage adopted devices. If it goes offline, devices continue running on their last available configuration.

Where continuous uptime is not achievable, Ubiquiti points to a CloudKey or Official UniFi Hosting instead. Functionally, Official UniFi Hosting and UniFi OS Server are the same product, with the difference being that UniFi OS Server is fully self-managed for installation, maintenance, and uptime.

## Troubleshooting

| Symptom | Resolution |
| :--- | :--- |
| Installer reports a missing container runtime | Podman is absent or installed outside the expected path. Confirm with `which podman`. |
| `unifi-core did not start within 60 seconds` | Expected during install. Wait three to five minutes. Persistent failure most commonly indicates insufficient RAM. |
| Installer refuses to run on free space | The pre-check enforces a disk floor above the documented 10GB. Provide 25GB or more. |
| Web interface unreachable on 11443 | Confirm `uosserver` is active, then confirm host firewall rules. |
| No devices appear for adoption | Confirm the host firewall permits the required ports, and that devices share a network with the server. Otherwise remote adoption is required. |
| Captive portal broken after migration | Portal moved from 8843 to 8444. Update firewall and NAT rules. |
| Cloud Gateway will not adopt | Expected. Cloud Gateways cannot be managed by an external UniFi OS Server. |

## Choosing Between the Two

The legacy Network Server remains documented and installable via APT, and stays the lighter option where the host already runs other services and only Network is needed. It is also the only route on distributions older than Ubuntu 24.04 or Debian 13.

UniFi OS Server is where Ubiquiti's development is directed, carries the UniFi OS feature set the legacy server lacks, and is explicitly described as the replacement. For a new build on a current distribution with dedicated resources, it is the more sustainable choice. Given that positioning, the reasonable inference is that the legacy server will see maintenance rather than feature work, though Ubiquiti has published no end-of-life date for it.
