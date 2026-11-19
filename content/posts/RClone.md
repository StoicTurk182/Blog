---
title: "RClone"
date: 2026-11-17
draft: false
description: "Replace SSHFS-Win with an rclone SFTP mount over Tailscale: diagnosing a slow VPS block volume, a fourfold read gain from read-ahead, the host key mismatch that blocks rclone on first connect, and a Task Scheduler setup with a watchdog that keeps the drive mounted."
categories: ["Windows", "Linux"]
tags: ["windows", "rclone", "sftp", "winfsp", "sshfs-win", "tailscale", "debian", "vps", "read-ahead", "fio", "task-scheduler", "powershell", "msp"]
readingTime: true
toc: true
author: "Andrew Jones"
authorBio: "Systems administration and IT infrastructure"
featuredImage: "/images/posts/RClone.png"
socialShare: true
---


# Rclone SFTP Mount for a VPS Volume on Windows

This guide mounts a directory on a Debian VPS as a Windows drive letter using rclone over SFTP, replacing an SSHFS-Win mapping. It covers diagnosing a slow network-attached VPS volume, a read-ahead change that gave a fourfold single-stream read gain, the rclone setup, a host key mismatch that blocks rclone, and a Task Scheduler setup that keeps the drive mounted. It was tested on Debian 13 (kernel 6.12) and Windows 11 with rclone v1.76.0 and WinFsp, over Tailscale.

## Overview
---

| Component | Role |
|-----------|------|
| Windows 11 workstation | Runs `rclone mount` through WinFsp and presents the remote path as drive `X:` |
| Tailscale | Private transport between the workstation and the VPS (direct WireGuard path, 11 ms in testing) |
| VPS `sshd` | Serves SFTP through the stock `sftp-server` subsystem on a non-standard port |
| VPS add-on volume | ext4 on `/dev/sdb1`, separate from the root disk, holding the shared path |

```text
Explorer / apps -> X: (WinFsp) -> rclone VFS cache -> SFTP over SSH -> Tailscale -> VPS sshd -> sftp-server -> /dev/sdb1
```

Nothing is installed on the VPS for the mount itself. rclone's SFTP backend uses the SSH service that is already running, so the only VPS-side changes in this guide are storage tuning.

## Example Values
---

All addresses, names and paths below are examples. Substitute your own.

| Item | Example used in this guide |
|------|----------------------------|
| VPS Tailscale IP | `100.64.0.10` |
| SSH port | `2222` |
| VPS user | `vpsadmin` |
| Shared path on the VPS | `/srv/backup` (ext4 on `/dev/sdb1`) |
| rclone remote name | `vps` |
| Drive letter | `X:` |
| Dedicated SSH key | `id_ed25519_rclone` |
| Scheduled task name | `rclone-vps-mount` |

## Choosing the Protocol
---

| Option | Outcome | Reason |
|--------|---------|--------|
| iSCSI | Rejected | Block-level only. An existing ext4 volume can be exported, but only one machine may mount a non-cluster filesystem read/write at a time, so the VPS loses local access while it is attached. |
| NFS | Rejected for this case | Fastest Linux-to-Linux option in plaintext benchmarks, but unencrypted, and the Windows client is a weaker fit. |
| SMB | Possible | Native to Windows, but needs Samba installed and hardened on the VPS. |
| SSHFS-Win | Replaced | Works, but reads each file as a single stream. The latest published GitHub release at the time of writing is 2021.1 Beta2. |
| rclone over SFTP | Chosen | Uses the existing `sshd`, supports parallel transfers, offers a local VFS cache, and is actively released. |

## VPS Volume Diagnosis
---

The add-on volume behaved very differently from the root disk, so it was measured before tuning anything on the network side.

```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,ROTA
df -h /srv/backup
findmnt /srv/backup
```

### Sequential Tests with dd
---

```bash
# Root disk, direct write
dd if=/dev/zero of=/var/tmp/ddtest bs=1M count=1000 oflag=direct status=progress; rm /var/tmp/ddtest

# Add-on volume, direct write then direct read
dd if=/dev/zero of=/srv/backup/ddtest bs=1M count=1000 oflag=direct status=progress
echo 3 > /proc/sys/vm/drop_caches
dd if=/srv/backup/ddtest of=/dev/null bs=1M iflag=direct status=progress
rm /srv/backup/ddtest
```

| Test | Block size | Result |
|------|-----------|--------|
| Root disk, direct write | 1M | 912 MB/s |
| Add-on volume, direct write, first run | 1M | 85 MB/s |
| Add-on volume, direct write, second run | 1M | 32.4 MB/s |
| Add-on volume, direct read | 1M | 32.4 MB/s |
| Add-on volume, direct write | 4M | 152 MB/s |
| Add-on volume, direct read | 4M | 39.6 MB/s |

With direct I/O, `dd` issues one request at a time, so on network-attached storage it measures per-request latency more than throughput. Writing zeros can also be short-circuited by some storage backends, and the write results varied fivefold between runs. Both points are inferences from the results, which is why `fio` was used next.

### Queue Depth Tests with fio
---

```bash
apt install -y fio

fio --name=seqwrite --filename=/srv/backup/fiotest --size=2G --bs=1M --rw=write \
    --direct=1 --ioengine=libaio --iodepth=16 --refill_buffers \
    --runtime=60 --time_based --group_reporting

fio --name=seqread --filename=/srv/backup/fiotest --size=2G --bs=1M --rw=read \
    --direct=1 --ioengine=libaio --iodepth=16 \
    --runtime=60 --time_based --group_reporting

rm /srv/backup/fiotest
```

| Test | Bandwidth | Completion latency |
|------|-----------|--------------------|
| Sequential write, 1M, queue depth 16 | 86.1 MiB/s average; 2 to 254 MiB/s per second | 185 ms average, 869 ms at the 99th percentile, 2.08 s maximum |
| Sequential read, 1M, queue depth 16 | 234 MiB/s (246 MB/s) | 39 ms median, 735 ms at the 99th percentile, 6.3 s maximum |

Reads scaled from about 32 MB/s at one request in flight to 234 MiB/s at sixteen, so per-request latency was the limit rather than a hard throughput cap. Latencies of hundreds of milliseconds, with stalls of several seconds, point at shared network storage on the provider side. That is an inference, and no guest-side setting changes it. Writes stayed at about 86 MiB/s on average with stalls.

## VPS Read-Ahead Tuning
---

`read_ahead_kb` is the maximum number of kilobytes the kernel reads ahead for filesystems on a block device. The default is 128 KB. On storage where each request takes tens of milliseconds, a small window leaves single-stream sequential reads waiting on round trips. A larger window keeps more requests in flight.

This setting lives entirely on the VPS. It speeds up anything that reads files sequentially there, including `sftp-server`, so SFTP, SSHFS, rsync and rclone all benefit.

### Test Read-Ahead Values
---

```bash
cat /sys/block/sdb/queue/read_ahead_kb

dd if=/dev/urandom of=/srv/backup/ratest bs=1M count=2048 oflag=direct status=progress

for ra in 128 2048 8192 16384; do
  echo $ra > /sys/block/sdb/queue/read_ahead_kb
  echo 3 > /proc/sys/vm/drop_caches
  echo "== read_ahead_kb=$ra"
  dd if=/srv/backup/ratest of=/dev/null bs=1M 2>&1 | tail -1
done

rm /srv/backup/ratest
echo 128 > /sys/block/sdb/queue/read_ahead_kb
```

| `read_ahead_kb` | Single-stream buffered read | Gain over default |
|-----------------|-----------------------------|-------------------|
| 128 (default) | 27.7 MB/s | baseline |
| 2048 | 56.8 MB/s | 2.1x |
| 8192 | 93.5 MB/s | 3.4x |
| 16384 | 114 MB/s | 4.1x |

These are single runs on a backend with noisy latency; an earlier run at the default gave 54.6 MB/s. Treat the exact figures as approximate. The cost of 16384 is up to 16 MB of page cache per open sequential stream.

### Make Read-Ahead Persistent
---

```bash
sudo tee /etc/udev/rules.d/60-readahead.rules <<'EOF'
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/read_ahead_kb}="16384"
EOF

sudo udevadm control --reload
sudo udevadm trigger --action=change --sysname-match="sd[a-z]"
cat /sys/block/sd?/queue/read_ahead_kb
```

The last command should print `16384` once per disk. The rule matches both disks because `sda` and `sdb` can swap names between boots, and it has no practical effect on the fast root disk.

To roll back, delete the rule file and rerun the two `udevadm` commands.

## Windows Client Setup
---

### Step 1: Install rclone and WinFsp
---

```powershell
winget install Rclone.Rclone
winget install WinFsp.WinFsp
```

Open a new terminal so it picks up the updated PATH, then confirm:

```powershell
rclone version
Get-Service WinFsp.Launcher
```

If SSHFS-Win was in use, WinFsp is already installed.

### Step 2: Create a Dedicated SSH Key
---

Generate the key, pressing Enter twice at the passphrase prompt. An unattended mount cannot answer a passphrase prompt.

```powershell
ssh-keygen -t ed25519 -f $env:USERPROFILE\.ssh\id_ed25519_rclone -C "rclone@WORKSTATION"
```

Copy the public key to the VPS using a key that already has access (here, the existing `id_rsa`):

```powershell
Get-Content $env:USERPROFILE\.ssh\id_ed25519_rclone.pub |
  ssh -p 2222 -i $env:USERPROFILE\.ssh\id_rsa vpsadmin@100.64.0.10 "cat >> ~/.ssh/authorized_keys"
```

Test that the new key logs in on its own. It should print the user name with no prompt:

```powershell
ssh -p 2222 -i $env:USERPROFILE\.ssh\id_ed25519_rclone vpsadmin@100.64.0.10 whoami
```

The filename `id_ed25519_rclone` is not one of the names ssh tries by default. Unless it is loaded into ssh-agent or named in `~/.ssh/config`, normal terminal SSH never offers it.

### Step 3: Create the rclone Remote
---

```powershell
rclone config create vps sftp host=100.64.0.10 port=2222 user=vpsadmin `
  key_file="$env:USERPROFILE\.ssh\id_ed25519_rclone" `
  known_hosts_file="$env:USERPROFILE\.ssh\known_hosts"

rclone config show vps
rclone config paths
```

`user` is the account on the VPS, not the Windows user. `rclone config paths` shows where the config file and cache live (by default `%APPDATA%\rclone\rclone.conf` and `%LOCALAPPDATA%\rclone`).

### Step 4: Fix the Host Key Mismatch
---

The first `rclone lsd` failed with:

```text
CRITICAL: Failed to create file system for "vps:/srv/backup": NewFs: couldn't connect SSH: ssh: handshake failed: knownhosts: key mismatch
```

Check which keys the main `known_hosts` file holds for the host:

```powershell
ssh-keygen -F "[100.64.0.10]:2222" -f $env:USERPROFILE\.ssh\known_hosts
```

It held only the server's `ssh-ed25519` key. The most likely cause is that rclone's SSH library negotiated a different host key type, found no matching entry and reported a mismatch. That is an inference: the fix below worked, but the negotiated algorithm was not captured.

The fix is a separate `known_hosts` file for rclone holding every host key the VPS offers. The keys are fetched through an SSH session that is already verified against the saved ed25519 key, so no unverified key is trusted.

```powershell
ssh -p 2222 -i $env:USERPROFILE\.ssh\id_ed25519_rclone vpsadmin@100.64.0.10 "cat /etc/ssh/ssh_host_*_key.pub" |
  ForEach-Object { $p = $_ -split ' '; "[100.64.0.10]:2222 $($p[0]) $($p[1])" } |
  Out-File -Encoding ascii $env:USERPROFILE\.ssh\known_hosts_rclone

Get-Content $env:USERPROFILE\.ssh\known_hosts_rclone
ssh-keygen -lf $env:USERPROFILE\.ssh\known_hosts_rclone

rclone config update vps known_hosts_file="$env:USERPROFILE\.ssh\known_hosts_rclone"
```

- `-Encoding ascii` matters, because a plain `>` redirect in Windows PowerShell 5.1 writes UTF-16, which rclone cannot parse.
- `ssh-keyscan -p 2222 100.64.0.10` was tried first. It timed out after its default 5 seconds and produced an empty file; the cause was not investigated.
- Normal terminal SSH continues to use the main `known_hosts`.

To cross-check fingerprints on the VPS:

```bash
for f in /etc/ssh/ssh_host_*_key.pub; do ssh-keygen -lf "$f"; done
```

### Step 5: Verify Read and Write
---

```powershell
rclone lsd vps:/srv/backup

"test" | Out-File $env:TEMP\rclone-test.txt
rclone copy $env:TEMP\rclone-test.txt vps:/srv/backup/ -v
rclone ls vps:/srv/backup --max-depth 1
rclone deletefile vps:/srv/backup/rclone-test.txt -v
```

On the VPS, confirm the SSH user can write to the path. In this setup, write access came from an ACL, shown by the `+` in `drwxrwxr-x+`:

```bash
ls -ld /srv/backup
sudo -u vpsadmin test -w /srv/backup && echo "can write" || echo "CANNOT write"
```

## Mounting the Drive
---

### Remove the Old SSHFS-Win Mapping
---

```powershell
net use
net use X: /delete
Remove-Item HKCU:\Network\X -ErrorAction SilentlyContinue
```

Explorer caches network drive labels under `MountPoints2`. After switching, X: kept showing the old `\\sshfs.kr\...` label until those entries were removed and Explorer restarted:

```powershell
Get-ChildItem HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\MountPoints2 |
  Where-Object PSChildName -like '*sshfs*' | Remove-Item -Recurse

Stop-Process -Name explorer -Force
```

Explorer normally restarts itself. If the taskbar does not come back, run `Start-Process explorer`.

### Manual Mount
---

Run this in its own terminal. The drive exists while the window stays open, and Ctrl+C unmounts it.

```powershell
rclone mount vps:/srv/backup X: --network-mode --volname Backup `
  --vfs-cache-mode full --vfs-cache-max-size 20G --dir-cache-time 5m
```

| Flag | Purpose |
|------|---------|
| `--network-mode` | Presents the mount as a network drive, which Windows and Explorer handle as high-latency storage |
| `--volname Backup` | Label shown in Explorer |
| `--vfs-cache-mode full` | Buffers all reads and writes through a local disk cache, so applications that need random access work |
| `--vfs-cache-max-size 20G` | Caps the cache in `%LOCALAPPDATA%\rclone` |
| `--dir-cache-time 5m` | How long directory listings are cached before being refreshed |

On startup, rclone v1.76.0 logged `ERROR : symlinks not supported without the --links flag: /`. A check on the VPS (`find /srv/backup -maxdepth 3 -type l`) found no symlinks, and the mount worked normally. The message was treated as harmless.

## Persistent Mount with Task Scheduler
---

rclone has no background mode on Windows, so the mount needs a host process that keeps it running. This setup uses a scheduled task, designed as follows:

| Setting | Value | Reason |
|---------|-------|--------|
| Trigger | At logon of the user, 30 second delay | The drive must exist in the user's session to appear in Explorer, and the delay gives Tailscale time to connect |
| Repetition | Every 5 minutes, indefinitely | Watchdog. If rclone exits, the next repetition starts it again |
| Multiple instances | `IgnoreNew` | While rclone is running, repetitions do nothing |
| Execution time limit | `PT0S` (none) | By default Task Scheduler stops a task 72 hours after it starts, which would silently unmount X: |
| Run level | Limited (default) | An elevated mount is not visible to a non-elevated Explorer |
| `--no-console` | rclone flag | Hides the console window (Windows only) |
| `--log-file` | `%LOCALAPPDATA%\rclone\mount.log` | Somewhere to look when the drive is missing |

### Register the Task
---

Run this as the account that should see X:. It stops any manual mount first, which is safe as long as nothing is waiting to upload.

```powershell
# 1. Stop any manual mount still holding X:
Get-Process rclone -ErrorAction SilentlyContinue | Stop-Process
Start-Sleep 2

# 2. Paths: prefer the WinGet Links shim so upgrades do not break the task
$rclone = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links\rclone.exe'
if (-not (Test-Path $rclone)) { $rclone = (Get-Command rclone).Source }
$log = Join-Path $env:LOCALAPPDATA 'rclone\mount.log'
New-Item -ItemType Directory (Split-Path $log) -Force | Out-Null

# 3. Mount arguments
$arg = "mount vps:/srv/backup X: --network-mode --volname Backup " +
       "--vfs-cache-mode full --vfs-cache-max-size 20G --dir-cache-time 5m " +
       "--no-console --log-file `"$log`" --log-level NOTICE"

# 4. Trigger: at logon after 30 s, then every 5 minutes as a watchdog
$trigger = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
$trigger.Delay = 'PT30S'
$trigger.Repetition = (New-ScheduledTaskTrigger -Once -At (Get-Date) `
    -RepetitionInterval (New-TimeSpan -Minutes 5)).Repetition

# 5. Settings: no execution time limit, never start a second copy
$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::Zero) `
    -MultipleInstances IgnoreNew -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

# 6. Register (replaces an existing task of the same name)
$action = New-ScheduledTaskAction -Execute $rclone -Argument $arg
Register-ScheduledTask -TaskName 'rclone-vps-mount' -Action $action -Trigger $trigger `
    -Settings $settings -Description 'Mount VPS backup path as X: via rclone SFTP' -Force

# 7. Start now
Start-ScheduledTask rclone-vps-mount
```

If `$rclone` resolves into `WinGet\Packages\...` rather than `WinGet\Links`, a later `winget upgrade` changes that folder and the task will fail to start. In that case, re-run this block after each upgrade.

### Verify the Task and Watchdog
---

```powershell
Start-Sleep 10
Get-PSDrive X
Get-ScheduledTaskInfo rclone-vps-mount | Select-Object LastRunTime, LastTaskResult, NextRunTime
(Get-ScheduledTask rclone-vps-mount).Triggers.Repetition | Format-List Interval, Duration
(Get-ScheduledTask rclone-vps-mount).Settings.ExecutionTimeLimit
```

| Check | Expected |
|-------|----------|
| `Get-PSDrive X` | Drive present |
| `LastTaskResult` | `267009` (0x41301, task is currently running) |
| Repetition | `Interval` is `PT5M`, `Duration` is empty (indefinite) |
| `ExecutionTimeLimit` | `PT0S` |

Test the watchdog by killing rclone and waiting for the next repetition:

```powershell
Stop-Process -Name rclone
Get-PSDrive X -ErrorAction SilentlyContinue    # gone
Start-Sleep 300
Get-PSDrive X                                  # back
```

Finally, sign out and back in, and confirm X: appears on its own after about 30 seconds.

### Change Mount Options Later
---

```powershell
$task = Get-ScheduledTask rclone-vps-mount
$act  = $task.Actions[0]
$act.Arguments                                       # current arguments
$act.Arguments = $act.Arguments + ' --example-flag value'
Set-ScheduledTask -TaskName rclone-vps-mount -Action $act
Stop-ScheduledTask rclone-vps-mount; Start-ScheduledTask rclone-vps-mount
```

## Performance Results
---

Client-side tests were run from the workstation over Tailscale. The VPS page cache was dropped before each test (`sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches'`), and each test used a different archive.

```powershell
tailscale ping 100.64.0.10

New-Item -ItemType Directory D:\rclone-test -Force | Out-Null

$f = 'backup-A.tar.gz'
$t = Measure-Command { rclone copy "vps:/srv/backup/$f" D:\rclone-test\ --multi-thread-streams 4 }
"rclone copy: {0:N1} MiB/s" -f ((Get-Item "D:\rclone-test\$f").Length / 1MB / $t.TotalSeconds)

$f = 'backup-B.tar.gz'
$t = Measure-Command { Copy-Item "X:\$f" D:\rclone-test\ }
"X: drive copy: {0:N1} MiB/s" -f ((Get-Item "D:\rclone-test\$f").Length / 1MB / $t.TotalSeconds)
```

| Test | Result | Approx. line rate |
|------|--------|-------------------|
| Tailscale path | Direct (not DERP-relayed), 11 ms | n/a |
| `rclone copy`, 4 streams, 3.1 GB archive | 59.1 MiB/s | ~496 Mbit/s |
| `Copy-Item` through X:, 4.6 GB archive | 31.7 MiB/s | ~266 Mbit/s |
| `Copy-Item` through X: with `--vfs-read-chunk-streams 16 --vfs-read-chunk-size 4M` | 29.8 MiB/s | ~250 Mbit/s |

PowerShell's `1MB` constant is 1 MiB, so these figures are MiB/s.

- **The volume is no longer the limit.** With read-ahead applied, it delivers 114 MB/s for a single stream and 234 MiB/s in parallel. The remaining limit for `rclone copy` is the network path (the home line, Tailscale on Windows, or SSH encryption). Inferred from the numbers; not isolated with a separate test.
- **`rclone copy` is about twice as fast as copying through X:.** Through the mount, a copy is a single stream, and with `--vfs-cache-mode full` every byte is also written to the local cache before reaching its destination.
- **The parallel-read flags made no difference.** Older rclone mount documentation states that chunked reading only works with cache modes below `full`, which is consistent with the result.

Before re-testing through X:, stop the mount and clear `%LOCALAPPDATA%\rclone\vfs` and `vfsMeta`. Otherwise the file is served from the local cache and the figure is meaningless.

### Further Tuning Not Applied
---

| Option | Status | Notes |
|--------|--------|-------|
| `--buffer-size 64M --vfs-read-ahead 512M` with `--vfs-cache-mode full` | Untested | Read-ahead control for full cache mode. The candidate for speeding up X: |
| `--vfs-cache-mode writes` with `--vfs-read-chunk-streams 16 --vfs-read-chunk-size 4M` | Untested | Reads stream directly from the remote, so the parallel-read flags apply. The trade-off is no local read cache |
| BBR congestion control on the VPS | Not applied | VPS default is `cubic`, and the path is direct at 11 ms |
| Raw SSH throughput test | Not run | Separates the line speed from SSH overhead (command below) |

```powershell
$t = Measure-Command { cmd /c "ssh -p 2222 -i %USERPROFILE%\.ssh\id_ed25519_rclone vpsadmin@100.64.0.10 ""dd if=/dev/zero bs=1M count=1000 2>/dev/null"" > NUL" }
"raw SSH: {0:N1} MiB/s" -f (1000 / $t.TotalSeconds)
```

## Day-to-Day Usage
---

Use X: for browsing and opening individual files, and `rclone copy` for anything large.

```powershell
# Download a file or folder, splitting large files into 4 streams
rclone copy vps:/srv/backup/<file-or-folder> D:\Restore --multi-thread-streams 4 -P

# Upload a folder, 4 files at a time
rclone copy D:\Source vps:/srv/backup/<dest> --transfers 4 -P

# Confirm a copy matches the source
rclone check D:\Source vps:/srv/backup/<dest>

# Space and usage
rclone about vps:/srv/backup
rclone ncdu vps:/srv/backup
```

Writes through X: land in the local cache first and are uploaded in the background. After copying something large to X:, wait for the upload to finish before signing out or stopping the task.

## Maintenance
---

| Task | Command |
|------|---------|
| Is it mounted? | `Get-PSDrive X; Get-Process rclone` |
| Task status | `Get-ScheduledTaskInfo rclone-vps-mount` |
| Read the log | `Get-Content $env:LOCALAPPDATA\rclone\mount.log -Tail 50` |
| Stop the mount | `Stop-ScheduledTask rclone-vps-mount` (the watchdog restarts it within 5 minutes unless the task is disabled) |
| Restart the mount | `Stop-ScheduledTask rclone-vps-mount; Start-ScheduledTask rclone-vps-mount` |
| Pause auto-mount | `Disable-ScheduledTask rclone-vps-mount`, then `Stop-ScheduledTask rclone-vps-mount` |
| Resume auto-mount | `Enable-ScheduledTask rclone-vps-mount; Start-ScheduledTask rclone-vps-mount` |
| Remove auto-mount | `Unregister-ScheduledTask rclone-vps-mount -Confirm:$false` |
| Update rclone | `winget upgrade Rclone.Rclone`, then restart the mount |
| Show or locate config | `rclone config show vps`; `rclone config file` |
| Clear the VFS cache | Pause auto-mount, delete `%LOCALAPPDATA%\rclone\vfs` and `vfsMeta`, resume |
| VPS IP or port changed | `rclone config update vps host=<ip> port=<port>`, then rebuild `known_hosts_rclone` (Step 4) |
| VPS host keys changed | `ssh-keygen -R "[100.64.0.10]:2222"`, reconnect once with ssh to accept the new key, then rebuild `known_hosts_rclone` |
| Read-ahead still applied (VPS) | `cat /sys/block/sd?/queue/read_ahead_kb` should show `16384` |


## Powershell Profile Function 
> simple function to enable or to disable the RClone mount. 
---

```powershell

function Register-RcloneMount {
    <#
    .SYNOPSIS
        Register an always-on rclone mount as a scheduled task (rclone-mount-<letter>).
    .EXAMPLE
        Register-RcloneMount -Remote 'vps:/Data2' -Drive S: -VolName Data2
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Remote,
        [Parameter(Mandatory)][string]$Drive,
        [string]$VolName = 'rclone',
        [ValidateSet('off', 'minimal', 'writes', 'full')]
        [string]$CacheMode = 'full',
        [string]$Extra = ''
    )
    $letter = $Drive.TrimEnd(':', '\')
    $Drive  = $letter + ':'
    $rclone = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links\rclone.exe'
    if (-not (Test-Path $rclone)) { $rclone = (Get-Command rclone).Source }
    $log = Join-Path $env:LOCALAPPDATA "rclone\mount-$letter.log"
    New-Item -ItemType Directory (Split-Path $log) -Force | Out-Null

    $rcArgs = "mount $Remote $Drive --network-mode --volname $VolName --vfs-cache-mode $CacheMode " +
              "--vfs-cache-max-size 20G --dir-cache-time 5m --no-console " +
              "--log-file `"$log`" --log-level NOTICE $Extra"

    $trigger = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
    $trigger.Delay = 'PT30S'
    $trigger.Repetition = (New-ScheduledTaskTrigger -Once -At (Get-Date) `
        -RepetitionInterval (New-TimeSpan -Minutes 5)).Repetition
    $settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::Zero) `
        -MultipleInstances IgnoreNew -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

    Register-ScheduledTask -TaskName "rclone-mount-$letter" `
        -Action (New-ScheduledTaskAction -Execute $rclone -Argument $rcArgs) `
        -Trigger $trigger -Settings $settings -Description "rclone mount $Remote on $Drive" -Force | Out-Null
    Start-ScheduledTask "rclone-mount-$letter"
    Write-Host "Task rclone-mount-$letter registered and started" -ForegroundColor Green
}

function Unregister-RcloneMount {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Drive)
    $letter = $Drive.TrimEnd(':', '\')
    Stop-ScheduledTask "rclone-mount-$letter" -ErrorAction SilentlyContinue
    Unregister-ScheduledTask "rclone-mount-$letter" -Confirm:$false
    Write-Host "Task rclone-mount-$letter removed" -ForegroundColor Green
}

```

## Troubleshooting
---

| Symptom | Cause | Fix |
|---------|-------|-----|
| `failed to mount FUSE fs: mountpoint path already exists: X:` | An earlier rclone process still holds X: | `Get-Process rclone`, then stop it with Ctrl+C in its window or `Stop-Process -Id <id>` |
| `knownhosts: key mismatch` | rclone was offered a host key type not stored in its `known_hosts` file | Build `known_hosts_rclone` with all host keys (Step 4) |
| `ssh-keyscan` exits after 5 seconds with an empty file | Keyscan timed out on Windows; cause not investigated | Fetch the keys over a verified SSH session (Step 4) |
| `ssh-keygen -lf` reports "not a public key file" | The file is empty or UTF-16 encoded | Rebuild it with `Out-File -Encoding ascii` |
| Explorer still shows the old `\\sshfs.kr\...` label | Explorer's cached label under `MountPoints2` | Remove the `*sshfs*` entries and restart Explorer |
| `ERROR : symlinks not supported without the --links flag: /` | Logged at mount start by rclone v1.76.0 | Harmless if `find <path> -type l` on the VPS finds no symlinks |
| X: works in the terminal but not in Explorer | The mount was started from an elevated window | Mount from a normal window, or use the scheduled task |
| `rclone` is not recognised after install | The terminal predates the PATH change | Open a new terminal |
| `hostname contains invalid characters` | A `<placeholder>` was typed literally | Substitute the real host |
| `sysctl: command not found` (VPS) | `/usr/sbin` is not in a normal user's PATH on Debian | Use `/usr/sbin/sysctl` or `sudo` |
| `rclone help flags` does not list `--vfs-*` flags | VFS flags belong to `rclone mount`, not the global flags | `rclone mount --help \| Select-String vfs` |
| X: disappears after about 3 days | The task's default 72-hour execution time limit | Set `-ExecutionTimeLimit ([TimeSpan]::Zero)` |

## Security Notes
---

- **Encryption.** Traffic is encrypted twice, by SSH and by Tailscale's WireGuard tunnel.
- **Unprotected key.** `id_ed25519_rclone` has no passphrase, so anyone who can read it can log in as the VPS user. Keep it in the user's profile, where the default NTFS permissions limit access.
- **Optional key restriction.** The key can be limited on the VPS with `authorized_keys` options, for example `restrict,from="<workstation-tailscale-ip>",command="/usr/lib/openssh/sftp-server"`. That allows SFTP only. If you do this, also set `shell_type=none` in rclone, which then cannot run checksum commands on the VPS and compares files by size and modification time instead. This was not applied here.
- **Password authentication.** `PasswordAuthentication yes` was observed in the VPS `sshd` configuration. Once every login uses keys, set it to `no`, keeping a working session open while you change it.
- **Config contents.** `rclone.conf` holds only the key path for this remote, not the key itself.

## References
---

- rclone mount documentation: https://rclone.org/commands/rclone_mount/
- rclone SFTP backend documentation: https://rclone.org/sftp/
- rclone forum, autostart rclone mount on Windows (`--no-console`): https://forum.rclone.org/t/autostart-rclone-mount-on-windows/31875
- rclone mount documentation, chunked reading and cache modes (v1.55 mirror): https://git.frostfs.info/KurlesHS/rclone/src/commit/31a1cc46b7d06e6e0d7c03af77ff0ae4bcb072f8/docs/content/commands/rclone_mount.md
- WinFsp releases: https://winfsp.dev/rel/
- SSHFS-Win releases: https://github.com/winfsp/sshfs-win/releases
- SSHFS-Win call for maintainers: https://www.github.com/winfsp/sshfs-win/issues/347
- Linux kernel, queue sysfs files (`read_ahead_kb`): https://www.kernel.org/doc/Documentation/block/queue-sysfs.rst
- fio documentation: https://fio.readthedocs.io/en/latest/fio_doc.html
- Microsoft, TaskSettings.ExecutionTimeLimit: https://learn.microsoft.com/en-us/windows/win32/taskschd/tasksettings-executiontimelimit
- Microsoft, Task Scheduler settingsType schema (`MultipleInstancesPolicy`): https://learn.microsoft.com/en-us/windows/win32/taskschd/taskschedulerschema-settingstype-complextype
- Microsoft, New-ScheduledTaskSettingsSet: https://learn.microsoft.com/en-us/powershell/module/scheduledtasks/new-scheduledtasksettingsset
- Microsoft, Register-ScheduledTask: https://learn.microsoft.com/en-us/powershell/module/scheduledtasks/register-scheduledtask
- OpenBSD, sshd(8) authorized_keys file format: https://man.openbsd.org/sshd#AUTHORIZED_KEYS_FILE_FORMAT
- NAS performance, NFS vs SMB vs SSHFS (summary): https://segmentfault.com/p/1210000047069281
- Admin Magazine, Shared Storage with NFS and SSHFS: https://www.admin-magazine.com/Archive/2018/47/Shared-Storage-with-NFS-and-SSHFS/(offset)/3
- iXsystems community, single initiator per non-cluster filesystem: https://www.ixsystems.com/community/goto/post?id=58646