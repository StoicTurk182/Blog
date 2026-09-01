---
title: "Windows 11 and Windows Server Local Account Password Reset via WinRE"
date: 2026-08-30
draft: false
description: "Resetting a forgotten local account password on Windows 11 and Windows Server using the utilman.exe swap in WinRE, including BitLocker gating, Server and Server Core variants, and Domain Controller exceptions"
categories: ["System Administration"]
tags: ["windows", "windows-server", "winre", "password-reset", "bitlocker", "active-directory", "troubleshooting"]
readingTime: true
toc: true
author: "Andrew Jones"
authorImage: "/images/authors/devops-team.jpg"
authorBio: "Systems administration and IT infrastructure"
featuredImage: "/images/posts/winre.jpg"
socialShare: true
---
# Windows 11 / Windows Server Local Account Password Reset via WinRE (utilman Method)

Procedure for resetting a forgotten **local account** password on Windows 11 and Windows Server using the Windows Recovery Environment (WinRE). Works by temporarily replacing the accessibility binary (`utilman.exe`) with `cmd.exe` to obtain a SYSTEM-level command prompt at the login screen. Verified on a personal Windows 11 device where the OS volume mounted as `E:` under WinRE; the same technique applies to Windows Server (Desktop Experience) editions with the deltas noted below.

**Table of Contents**

1. [Overview](#overview)
2. [Applicability and Limitations](#applicability-and-limitations)
3. [Windows Server Applicability](#windows-server-applicability)
4. [Prerequisites](#prerequisites)
5. [Procedure](#procedure)
	1. [Step 1: Boot into WinRE](#step-1-boot-into-winre)
	2. [Step 2: Identify the Windows Volume](#step-2-identify-the-windows-volume)
	3. [Step 3: Verify BitLocker Status](#step-3-verify-bitlocker-status)
	4. [Step 4: Swap utilman.exe with cmd.exe](#step-4-swap-utilmanexe-with-cmdexe)
	5. [Step 5: Reset the Password](#step-5-reset-the-password)
	6. [Step 6: Restore utilman.exe](#step-6-restore-utilmanexe)
6. [Critical Notes](#critical-notes)
7. [Troubleshooting](#troubleshooting)
8. [Command Reference](#command-reference)
9. [References](#references)


## Overview

The `utilman.exe` swap is a physical-access recovery technique. At the Windows login screen, the Accessibility (Ease of Access) button launches `utilman.exe` with SYSTEM privileges. Replacing that binary with `cmd.exe` yields an elevated command prompt before authentication, from which `net user` can reset any local account password.

The technique requires the ability to boot the machine into WinRE (physical or console access) and an **unencrypted** system volume, or the BitLocker recovery key if the volume is encrypted. It applies only to hardware you own or are authorised to administer; use on a machine without authorisation is unauthorised access.

## Applicability and Limitations

| Scenario | Supported | Notes |
|----------|-----------|-------|
| Local account | Yes | `net user` resets the password directly |
| Microsoft account (MSA) | No | Reset online at account.live.com, then sign in with internet connectivity |
| Entra ID / Azure AD joined | No (for the primary user) | Reset via the identity provider; local accounts on the box still work |
| BitLocker / Device Encryption enabled | Conditional | Requires the 48-digit recovery key to unlock/suspend before modifying System32 |
| Managed / work device | Policy-dependent | Local recovery may be blocked; defer to organisation IT |
| Windows Server (member/standalone) | Yes | Same mechanism; see Windows Server Applicability |
| Domain Controller | No local reset | No local SAM exists; domain accounts reset via Active Directory |

On Windows 11, Device Encryption (a BitLocker variant) is enabled automatically on compatible hardware, so treat the volume as encrypted until confirmed otherwise. Modifying files on an encrypted volume triggers the recovery-key prompt on next boot. (Windows OS Hub; Pureinfotech — see References.)

## Windows Server Applicability

The same `utilman.exe` swap works on Windows Server (Desktop Experience) editions — 2012 R2, 2016, 2019, 2022, and 2025 — using the identical Procedure below. The differences are operational, not mechanical. (Clouvider; PhoenixNAP; ServerAdminz — see References.)

| Aspect | Client (Windows 11) | Windows Server |
|--------|---------------------|----------------|
| WinRE availability | Enabled by default | Often not configured; booting from install media (ISO/USB) is the reliable path |
| Console access | Local keyboard/monitor | Frequently headless — mount the ISO and reach the console via IPMI / remote KVM (iDRAC, iLO) |
| Login-screen trigger | Click the Accessibility button | Press `Ctrl+Alt+Del`, then `Win+U` — keyboard trigger is reliable on a server console |
| Typical target account | Named local user | Built-in `Administrator` (enable with `net user administrator /active:yes` if disabled) |

Server-specific swap (drive letter substituted; `E:` shown), run in the recovery Command Prompt:

``` powershell
move E:\Windows\System32\utilman.exe E:\utilman.bak
copy E:\Windows\System32\cmd.exe E:\Windows\System32\utilman.exe
```

After reboot, at the login screen, press `Ctrl+Alt+Del` then `Win+U` for the SYSTEM prompt, then:

``` powershell
net user administrator /active:yes
net user administrator NewP@ssw0rd!
```

Restore `utilman.exe` afterward exactly as in Step 6.

### Exceptions

- **Domain Controllers.** A DC has no local SAM — the local account database is removed during promotion (`dcpromo`), so `net user` for a local account resets nothing. Domain accounts are reset through Active Directory by an authorised administrator using `Set-ADAccountPassword` or Active Directory Users and Computers from another domain-joined admin session. Console and physical access to a DC is itself a critical security boundary and should be controlled accordingly. (Diengdoh — see References.)
- **Server Core.** The minimal logon UI has no Ease of Access button, so the `utilman.exe` swap has nothing to click. Use the Sticky Keys variant instead: swap `sethc.exe` (triggered by pressing `Shift` five times at the logon screen) rather than `utilman.exe`, with the same backup and restore discipline. (Inferred: Server Core retains Winlogon/LogonUI but omits the Explorer shell and accessibility button; the Sticky Keys trigger is a Winlogon-level feature and therefore still fires.)

### Operational Note

On a server, treat this as emergency access only. Record the action in change control and audit logs, and after regaining access review account lockout policy, local/domain security policy, and the Security event log for anything unexpected. (ServerAdminz — see References.)

## Prerequisites

- Physical or console access to the device (for headless servers: IPMI / remote KVM with ISO mount capability)
- Ability to reach WinRE (Shift+Restart, forced boot interruption, or Windows install media)
- The exact local account name (retrieved via `net user` during the process)
- BitLocker recovery key on hand **if** the volume is encrypted — retrieve from https://account.microsoft.com/devices/recoverykey

## Procedure

### Step 1: Boot into WinRE

From a reachable login screen:

``` powershell
Hold Shift > Power > Restart
```

If the desktop is inaccessible, force WinRE by interrupting boot three times (hard power-off during the boot spinner). Alternatively — and the standard path on Server — boot Windows install media and press `Shift + F10` at the setup screen for a command prompt.

Then navigate:

``` powershell
Troubleshoot > Advanced options > Command Prompt
```

### Step 2: Identify the Windows Volume

In WinRE, `X:` is the RAM disk. The Windows volume is frequently **not** `C:` — in the verified case it was `E:`. Enumerate volumes:

``` powershell
diskpart
list volume
exit
```

The Windows volume is the large NTFS partition (typically 100+ GB). Ignore:

| Volume type | Size (approx) | Identity |
|-------------|---------------|----------|
| FAT32 | 100–500 MB | EFI System Partition |
| NTFS | 500 MB–1 GB | Recovery / WinRE |
| Removable | varies | USB install media |

Confirm the correct letter by checking for the Windows folder (substitute the letter found — `E:` shown here):

``` powershell
dir E:\Windows\System32\utilman.exe
```

If the file lists, the volume is correct. If "File Not Found", try the next letter until it resolves.

### Step 3: Verify BitLocker Status

This is the go/no-go gate before writing to System32:

``` powershell
manage-bde -status E:
```

Read **Conversion Status** and **Protection Status**:

- `Fully Decrypted` / Protection **Off** — safe to proceed to Step 4.
- `Fully Encrypted` / Protection **On** — unlock or suspend first.

Unlock with the recovery key:

``` powershell
manage-bde -unlock E: -RecoveryPassword <48-digit-key>
``` powershell

Or suspend protection to avoid the reboot prompt:

```  powershell
manage-bde -protectors -disable E:
```

### Step 4: Swap utilman.exe with cmd.exe

Back up the original to the **root of the fixed OS volume** (not the USB, so it survives reboot), then overwrite:

``` powershell
copy E:\Windows\System32\utilman.exe E:\utilman.bak
copy E:\Windows\System32\cmd.exe E:\Windows\System32\utilman.exe
```

When prompted `Overwrite ...utilman.exe?`, respond:

``` powershell
Yes
```

The overwrite is expected — `utilman.exe` already exists and the original is preserved at `E:\utilman.bak`. Reboot into normal Windows:

``` powershell
wpeutil reboot
```

### Step 5: Reset the Password

At the Windows login screen, click the **Accessibility / Ease of Access** button (bottom-right), or on a server press `Ctrl+Alt+Del` then `Win+U`. A SYSTEM-level command prompt opens instead of Utility Manager.

List local accounts to confirm the exact name:

``` powershell
net user
```

Reset the target account:

``` powershell
net user "YourAccount" NewP@ssw0rd!
```

If the account is disabled:

``` powershell
net user "YourAccount" /active:yes
```

Log in with the new password.

### Step 6: Restore utilman.exe

Once booted into normal Windows, the OS volume reverts to its standard letter — `C:` — so the backup made at `E:\utilman.bak` is now at `C:\utilman.bak`. Open an elevated Command Prompt (Run as administrator) and restore:

``` powershell
copy C:\utilman.bak C:\Windows\System32\utilman.exe
del C:\utilman.bak
```

When prompted to overwrite, respond `Yes`. This closes the SYSTEM-level access left by the swapped binary. Do not skip this step.

If BitLocker protection was suspended in Step 3, re-enable it:

``` powershell
manage-bde -protectors -enable C:
```

## Critical Notes

- **Volume letter changes between environments.** WinRE mounted the OS volume as `E:`; normal Windows mounts the same volume as `C:`. Back up and reference files using the letter valid in the current environment. This was the primary point of confusion during the verified run.
- **Restore is mandatory.** A swapped `utilman.exe` (or `sethc.exe`) is a persistent SYSTEM-level command prompt reachable from the lock screen by anyone with physical access. Restoring the original binary closes it.
- **Data loss on reset.** Resetting a local password invalidates that user's EFS-encrypted files, Credential Manager entries, and DPAPI-protected secrets (browser-saved passwords, etc.). This is the most likely follow-on issue and is not recoverable. (Inferred from Windows credential architecture; consistent with Microsoft password-reset guidance.)
- **Microsoft accounts and domain accounts are out of scope.** `net user` only affects local accounts. An MSA must be reset online; a domain account must be reset through Active Directory.
- **Physical access is the real control.** This technique exists because console access to a machine is equivalent to control of its local accounts. For servers — and especially Domain Controllers — physical and out-of-band (IPMI/KVM) access is the security boundary that matters.

## Troubleshooting

| Symptom | Likely cause | Action |
|---------|--------------|--------|
| `dir <letter>\Windows` returns File Not Found | Wrong volume letter | Re-run `list volume`; try the next large NTFS volume |
| Volume filesystem shows `Unknown` / `RAW`, letter won't open | BitLocker encrypted | `manage-bde -unlock <letter> -RecoveryPassword <key>` |
| Recovery-key prompt appears on reboot after swap | Modified an encrypted volume | Enter the 48-digit key from account.microsoft.com/devices/recoverykey |
| `net user` shows the account but `Access is denied` | Prompt not elevated / wrong context | Ensure the prompt was opened via the Accessibility button or `Win+U` (SYSTEM) |
| `The user name could not be found` | Name mismatch | Run `net user` and copy the exact name, including spaces (quote it) |
| CMD reports a Microsoft account | Target is an MSA, not local | Reset online instead |
| Accessibility button does nothing at login | Swap did not apply | Re-enter WinRE and re-verify the `copy` completed on the correct volume |
| No Ease of Access button (Server Core) | Minimal logon UI has no button | Use the `sethc.exe` Sticky Keys variant (Shift x5) instead |
| Headless server, cannot reach WinRE | No local console | Mount install media via IPMI / remote KVM and `Shift + F10` at setup |
| `net user` resets nothing on a Domain Controller | DC has no local SAM | Reset the domain account via `Set-ADAccountPassword` / ADUC from another admin session |

## Command Reference

| Command | Purpose |
|---------|---------|
| `diskpart` / `list volume` | Enumerate volumes and letters in WinRE |
| `dir <letter>\Windows\System32\utilman.exe` | Confirm the OS volume |
| `manage-bde -status <letter>` | Check BitLocker encryption/protection state |
| `manage-bde -unlock <letter> -RecoveryPassword <key>` | Unlock an encrypted volume with the recovery key |
| `manage-bde -protectors -disable <letter>` | Suspend BitLocker protection |
| `copy ...\cmd.exe ...\utilman.exe` | Swap in the SYSTEM shell |
| `wpeutil reboot` | Reboot from WinRE |
| `net user` | List local accounts |
| `net user "<name>" <password>` | Set a local account password |
| `net user "<name>" /active:yes` | Enable a disabled account |
| `Set-ADAccountPassword <name>` | Reset a domain account (from an authorised AD session, not WinRE) |