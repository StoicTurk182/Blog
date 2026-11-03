---
title: "Security-First IT Support: Great Support Without Compromising Security"
date: 2026-11-03
draft: false
description: "What it means to be a security-first IT support professional, with a worked example of securing a personal VPS and tenant, identity-based controls, defence in depth, AI-driven social engineering, network and physical controls, and how to deliver great support without adding friction"
categories: ["Security"]
tags: ["security", "zero-trust", "least-privilege", "defence-in-depth", "mfa", "fido2", "tailscale", "crowdsec", "fail2ban", "agdlp", "802.1x", "vlan", "social-engineering", "ai", "helpdesk", "msp"]
readingTime: true
toc: true
author: "Andrew Jones"
authorBio: "Systems administration and IT infrastructure"
featuredImage: "/images/posts/newsecurity.png"
socialShare: true
---
# Security-First IT Support: Great Support Without Compromising Security

Talk notes and discussion framework built around one question:

> What does it mean to be a security-first IT support professional in a modern organisation, and how do you deliver exceptional support without compromising on security?

My short answer is that security is not a hindrance to work, it is what makes work possible. Work is pointless if it is lost, stolen or compromised. A security-first support professional makes the secure way of working the easy way of working, and builds it into every interaction rather than treating it as an extra step.

This post uses my own setup as an example, a personal VPS and Microsoft tenant. It then moves on to AI-driven social engineering, network and physical controls, and how to put all of it in place without degrading the support experience.

## The Core Idea

Security and support are not opposing goals. A control that users understand and can easily follow gets followed. A control that gets in the way gets bypassed, and the workaround is usually less secure than having no control at all.

The NCSC has argued since 2017 that people can be the strongest link in security when systems are designed around how they actually work, rather than treating users as the weakest link.

## Why Friction Undermines Security

| Friction | Typical Workaround | Result |
|----------|--------------------|--------|
| Forced 30/60/90-day password changes | Password1, Password2, written on a sticky note | Weaker passwords |
| Constant MFA prompts | Approving prompts without reading them | MFA fatigue attacks succeed |
| Blocking file sharing tools with no alternative | Personal Gmail, WeTransfer, USB sticks | Data leaves managed systems |
| Slow access requests | Shared accounts and credentials | No accountability |
| Blocking all AI tools | Staff use personal AI accounts | Shadow AI and data leakage |
| Unhelpful or hostile helpdesk | Users stop reporting suspicious emails | Late detection |

NIST SP 800-63B and NCSC password guidance both advise against forced periodic password changes for this reason. Passwords should only be changed when there is evidence of compromise.

## Worked Example: Securing a Personal VPS and Tenant

These are the methods I apply to my own infrastructure, and why I use them. The same principles scale up to an organisation.

### Permissions: Zero Trust and Least Privilege

Identity-based protections are the first and last line of defence. Who someone is determines the access they get. This should always combine two principles:

| Principle | What It Controls |
|-----------|------------------|
| Least Privilege | How much access. People only get the access they need to do their role |
| Zero Trust | Where access is allowed from and to. Access granted once is not automatically granted again: who the user is, and what and where they are connecting from, is validated on every request |

As a simplified example, I use Tailscale heavily for remote management of my personal devices. Tailscale lets me:

- Keep devices off the public internet and reach them only through its built-in WireGuard-based VPN
- Use access control policies (ACLs and grants) to define which identities and devices can reach which hosts and ports
- Tie every connection to an authenticated identity rather than to an IP address or network location

The result is that every device is isolated and scoped, but I can still work without restriction. Security does not need to come at the expense of productivity.

Tailscale is one way to do identity-based networking. Others include Microsoft Entra Private Access, Cloudflare Zero Trust, and Headscale or plain WireGuard with firewall policy. The principle matters more than the product.

### Defence in Depth

No single control is relied on. Each layer covers a different failure.

| Layer | Control | Purpose |
|-------|---------|---------|
| Patching | Automatic security updates (e.g. `unattended-upgrades` on Debian), regular version checks | Closes known vulnerabilities before they are exploited |
| Brute-force protection | Fail2ban | Watches logs and bans IPs after repeated failed logins |
| Collaborative threat blocking | CrowdSec | Detects malicious behaviour and shares IP reputation across a community blocklist |
| Encryption in transit | TLS | Protects data between client and server |
| Review | Regular security audits | Confirms that controls are still in place and still effective |

On TLS: TLS (Transport Layer Security) is the protocol that encrypts data sent between a client, such as a web browser, and a server. It replaced SSL (Secure Sockets Layer). All versions of SSL are deprecated and insecure, as are TLS 1.0 and 1.1 (RFC 8996), so only TLS 1.2 and 1.3 should be enabled. "SSL certificate" is still common shorthand, but the certificate is used by TLS.

Example baseline on a Debian VPS:

```bash
# Automatic security updates
sudo apt install unattended-upgrades
sudo dpkg-reconfigure --priority=low unattended-upgrades

# Fail2ban for SSH brute-force protection
sudo apt install fail2ban
sudo systemctl enable --now fail2ban
sudo fail2ban-client status sshd

# Check listening services (anything unexpected is a finding)
sudo ss -tulpn
```

### Identity-Based Security

Modern security is moving towards identity-bound scope. Access is tied to the individual rather than to the resource, service or network. That lets many layers of control combine through one approach without a single point of failure.

**MFA, phishing-resistant.** Use FIDO2 security keys, passkeys or Windows Hello for Business. Avoid SMS, email and OTP codes where possible, because they can be phished or intercepted. CISA identifies FIDO/WebAuthn as the phishing-resistant standard. Where push notifications are used, number matching should be enforced.

**Access control with AGDLP.** AGDLP is Microsoft's recommended model for role-based access control in Active Directory:

| Step | Meaning |
|------|---------|
| A - Accounts | User and computer accounts |
| G - Global groups | Group accounts by role (e.g. "Finance Staff") |
| DL - Domain Local groups | Groups that represent access to a resource (e.g. "Finance Share - Modify") |
| P - Permissions | Permissions are assigned only to the domain local group |

The role group is nested into the resource group, and permissions are never assigned directly to users. Access then becomes a group membership change that is auditable and easy to revoke. The same thinking still applies in Entra ID: assign access to security groups, not to individuals. That is how traditional resource control integrates with identity.

## AI and Social Engineering: The Elephant in the Room

Kevin Mitnick, one of the most famous hackers of the 1990s, was primarily a social engineer. His most effective attacks were against people, not machines. He later wrote in *The Art of Deception* that the human factor is security's weakest link.

What has changed is that, for the first time, people without his skill can pull off similar attacks with the help of AI:

- **Phishing:** fluent, personalised and typo-free, at scale. Microsoft reported AI-automated phishing reaching a 54% click-through rate, compared with 12% for standard phishing.
- **Impersonation:** voice cloning and deepfake video of executives or staff.
- **Helpdesk attacks:** in the 2025 UK retail incidents, attackers impersonated staff to the IT helpdesk to get passwords and MFA reset.

I consider AI-assisted social engineering the most dangerous threat currently facing organisations. It is very hard for a non-technical person to defend against, and technical people are still vulnerable to it. The NCSC assesses that AI lowers the barrier to entry for novice criminals and will increase the frequency and intensity of attacks through 2027.

### The Defence: Authentication and Authorisation

In my experience, the best defence is a consistent authentication and authorisation process. It must be completed before any action is taken:

| Step | Question |
|------|----------|
| 1. Identify | Who made the request? |
| 2. Confirm | Is the request genuine? Confirm it through a separate, known channel |
| 3. Record | Log the request in the ticketing system |
| 4. Authorise | Validate the request with an authorising person |

This matters most for change requests that would have a wide impact or would give access to restricted material.

### Identity Verification Procedure

| Request Type | Minimum Verification |
|--------------|----------------------|
| General support / how-to | Name and known contact details |
| Password reset | Direct to SSPR, or call back on a number held in HR/AD records, not one the caller gives |
| MFA reset or new device registration | Call-back plus manager or second-party approval, or a Temporary Access Pass issued through a verified channel |
| Admin / privileged account changes | In-person or video verification plus a second approver |
| Payment or bank detail changes (finance) | Out-of-band confirmation with a known contact |

Avoid knowledge-based questions such as date of birth or employee number, because these are easily found or guessed. Following the retail incidents, the NCSC advised organisations to review their helpdesk password reset processes, particularly for privileged accounts.

### Scripting the Conversation

Good support means the security step doesn't feel like an accusation:

- "For your security I'll call you back on the number we have on file. It'll take two minutes."
- "I can't reset that over chat, but you can do it yourself right now at the self-service page. Want me to walk you through it?"
- "We do this for everyone, including directors. It's what stops someone pretending to be you."

A consistent, polite script also takes the pressure off the technician. An attacker using urgency or seniority ("I'm the MD and I need this now") gets the same answer as everyone else.

## Physical and Network Security

Identity controls can be undermined if someone can plug into the network or walk into the comms room.

| Control | Purpose |
|---------|---------|
| VLAN segmentation | Separate users, servers, guests, IoT and management traffic, with firewall rules between them |
| 802.1X | IEEE standard for port-based network access control. Combined with RADIUS, devices and users must authenticate before a switch port or Wi-Fi network grants access, which ties network access to identity |
| Dedicated management VLAN, not the native VLAN | Management interfaces live on their own VLAN. The native VLAN on trunks is set to an unused VLAN, and VLAN 1 is not used for management, to reduce VLAN-hopping risk |
| No DHCP on management | Management devices use static addressing. DHCP snooping on access switches blocks rogue DHCP servers |
| Secured trunks | Trunk ports carry only explicitly allowed VLANs, auto-negotiation of trunks (DTP) is disabled, and unused ports are shut down or placed in an unused VLAN |
| Strong device credentials | Long, randomly generated passwords (20 to 40+ mixed characters) for network device admin accounts, stored in a password manager. NIST SP 800-63B-4 requires a 15-character minimum where a password is the only factor |
| Locked comms room | Physical access to switches, firewalls and servers is restricted and logged |

I have hands-on experience with all of the above, though I'm not an expert. In my own time I apply these principles to my personal setup, which is the most practical way to learn them.

## Controls That Improve Both Security and UX

These are the strongest talking points, because they remove the trade-off altogether.

| Control | Security Gain | User Experience Gain |
|---------|---------------|----------------------|
| Passkeys / Windows Hello for Business / FIDO2 | Phishing-resistant, no password to steal | No password to remember or type |
| Single sign-on (SSO) | One well-protected identity, central revocation | One login for all apps |
| Conditional Access (trusted compliant device) | Access tied to device health and risk | Fewer MFA prompts on known devices |
| Self-service password reset (SSPR) with strong methods | Removes the helpdesk as a reset target | Instant reset, any time |
| Password manager | Unique strong passwords everywhere | Autofill, nothing to remember |
| Number-matching MFA | Stops blind approval of prompts | Clear, simple prompt |
| Identity-based remote access (e.g. Tailscale, Entra Private Access) | No exposed services, per-user scoping | Works from anywhere without a clunky VPN |
| Approved AI tools with data protection | Controls data leakage | Staff get the tools they want legitimately |
| Just-in-time admin (Entra PIM) | No standing admin rights | Elevation in minutes, no ticket wait |

## Principles for Secure Support

| Principle | What It Means for Support |
|-----------|---------------------------|
| Make the secure path the easy path | Default to secure settings so users don't need to make security decisions |
| Explain the why | A one-line reason ("this stops someone using a stolen password") cuts pushback |
| Offer an alternative when you block something | "Not WeTransfer, use this OneDrive link" rather than just "No" |
| Reward reporting | Thank users who report phishing, even false positives. Never blame them for clicking |
| Consistent procedures | Every request is handled the same way, regardless of seniority or urgency |
| Self-service where safe | Reduces wait times and removes the human social-engineering target |
| Measure both sides | Track ticket volume and user satisfaction alongside security metrics after a change |

## Rolling Out a New Control

| Step | Action |
|------|--------|
| 1. Pilot | Test with IT and a friendly user group first |
| 2. Communicate early | Explain what's changing, when, why, and what users need to do |
| 3. Report-only mode | Use Conditional Access report-only or audit mode to see impact before enforcing |
| 4. Phase it | Roll out by department, not all at once |
| 5. Prepare the helpdesk | Give technicians the script, FAQs and an escalation path before go-live |
| 6. Provide a break-glass option | Emergency access accounts, excluded from Conditional Access and monitored |
| 7. Review | Check ticket volume, user feedback and sign-in logs, then adjust |

## Mapping to the Core Principles

| Principle | Support-Friendly Implementation |
|-----------|---------------------------------|
| CIA Triad | Availability is a security goal too. A control that stops people working is a failure |
| Least Privilege | Just-in-time elevation and group-based access (AGDLP) instead of permanent admin rights or long ticket waits |
| Defence in Depth | Layers run in the background (patching, EDR, Fail2ban, CrowdSec, filtering) so users notice few of them |
| Zero Trust | Device trust, Conditional Access and identity-based networking reduce prompts for low-risk access |
| Assume Breach | A blame-free reporting culture gets incidents reported early |

## Security as a Habit

I think habit-forming is the best approach to security: developing the right way of working with computers until it is automatic. That has been my own approach for a long time. Instead of seeing security as a hindrance to work, I now see it as what makes safe and secure work possible.

All of the above has to be applied and maintained consistently by technicians and users alike. Practice is what defines any skill, and getting people into the habit of repeating good behaviour is likely to improve security more than any single tool. To achieve that, people need to be interested in these topics and in why the protections exist.

From an organisational perspective, security must be encouraged as well as enforced. Enforcement without buy-in creates workarounds; buy-in without enforcement creates gaps. For a support professional, providing support with a security focus should be the baseline, not the exception.

## Talk Summary

**Anchor line:** "If security makes someone's job harder, they'll find a way around it, and that way around is our new vulnerability."

**Key points:**

1. Identity is the first and last line of defence. Combine Zero Trust with Least Privilege.
2. Defence in depth means no single point of failure, from patching to TLS to physical locks.
3. AI-assisted social engineering is the most dangerous current threat. Identify, confirm, record and authorise before acting.
4. The best modern controls (passkeys, SSO, SSPR, identity-based networking) are both more secure and easier to use.
5. Security is a habit. It has to be encouraged as well as enforced.


