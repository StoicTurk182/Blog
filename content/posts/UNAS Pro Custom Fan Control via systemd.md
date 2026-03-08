---
title: "UNAS Pro Custom Fan Control via systemd"
date: 2026-03-08
lastmod: 2026-03-08
draft: false
author: "Andrew Jones"
description: "Deploying a PWM-based fan control script on the UNAS Pro NAS using a community systemd service, with custom temperature targets tuned for Seagate IronWolf drives."
categories: ["Homelab", "Linux"]
tags: ["UNAS Pro", "NAS", "Linux", "systemd", "Fan Control", "PWM", "Homelab", "IronWolf"]
featuredImage: "/images/posts/hiclipart.com.png"
toc: true
---

# UNAS Pro Custom Fan Control via systemd

The UNAS Pro's stock fan control tends to run fans aggressively or inconsistently under modest loads. This documents replacing stock fan behaviour with a community-maintained PWM script that runs as a persistent systemd service, with temperature targets tuned for Seagate IronWolf drives.

Script source: [hoxxep/UNAS-Pro-fan-control](https://github.com/hoxxep/UNAS-Pro-fan-control)

I have also included a section on manual control, for cases where you are not filling all drive bays 
and want to set a static fan speed. Personally I use this method as the device sits in a normal room 
rather than a climate-controlled rack, and I am only running 2x HDD — it works well under those conditions.

This would not be advisable if you are putting the UNAS under heavy load, particularly the CPU.

---

## Background

The UNAS Pro exposes fan PWM channels through the Linux `hwmon` subsystem at `/sys/class/hwmon/hwmon0/`. Each PWM channel has an `_enable` control knob that determines who owns fan speed authority:

| Value | Mode | Meaning |
|-------|------|---------|
| 0 | Full speed | No control applied, fans run at maximum |
| 1 | Manual | PWM duty cycle set directly by software |
| 2 | Automatic | OS/kernel takes control based on temperature input |

The hoxxep script requires `pwm*_enable` to be set before it can assert control. Without releasing the channels first, writes to the PWM registers may be silently ignored by the firmware.

Reference: [Linux kernel hwmon sysfs interface documentation](https://www.kernel.org/doc/Documentation/hwmon/sysfs-interface)

---

## Configuration Values Applied

The following values were injected into the downloaded script via `sed` in-place substitution. Targets are tuned for Seagate IronWolf NAS drives, which Seagate specifies with an operating range of 0-70C and recommends keeping below 60C during sustained operation.

| Variable | Value Applied | Rationale |
|----------|--------------|-----------|
| `MIN_FAN` | `30` | Minimum PWM duty cycle (~1800 RPM equivalent); prevents fan stall at idle while keeping noise low |
| `HDD_TGT` | `55` | HDD temperature target in Celsius; fan curve begins ramping toward this point |
| `HDD_MAX` | `62` | HDD temperature at which fans reach maximum; 8C below Seagate's rated ceiling |
| `CPU_TGT` | `75` | CPU temperature target in Celsius |
| `CPU_MAX` | `88` | CPU temperature at which fans run at maximum |

Seagate IronWolf operating temperature specification: 0-70C (Seagate IronWolf datasheet DS1904-3-2006US).

---

## Deployment

### Step 1: Release PWM Channels to OS Control

```bash
echo 2 | tee /sys/class/hwmon/hwmon0/pwm1_enable /sys/class/hwmon/hwmon0/pwm2_enable
```

Sets both fan PWM channels to automatic/OS-controlled mode. `tee` writes the value to both paths in a single command. This must run before the script is started, otherwise firmware retains authority and the script's PWM writes have no effect.

### Step 2: Download Script and Service Unit

```bash
wget -O /root/fan_control.sh https://raw.githubusercontent.com/hoxxep/UNAS-Pro-fan-control/refs/heads/main/fan_control.sh
wget -O /etc/systemd/system/fan_control.service https://raw.githubusercontent.com/hoxxep/UNAS-Pro-fan-control/refs/heads/main/fan_control.service
```

| File | Destination |
|------|-------------|
| `fan_control.sh` | `/root/fan_control.sh` |
| `fan_control.service` | `/etc/systemd/system/fan_control.service` |

### Step 3: Make the Script Executable

```bash
chmod +x /root/fan_control.sh
```

Required before systemd can execute the script as a service.

### Step 4: Apply Custom Temperature Targets

```bash
sed -i 's/^MIN_FAN=.*/MIN_FAN=30/' /root/fan_control.sh
sed -i 's/^HDD_TGT=.*/HDD_TGT=55/' /root/fan_control.sh
sed -i 's/^HDD_MAX=.*/HDD_MAX=62/' /root/fan_control.sh
sed -i 's/^CPU_TGT=.*/CPU_TGT=75/' /root/fan_control.sh
sed -i 's/^CPU_MAX=.*/CPU_MAX=88/' /root/fan_control.sh
```

Each `sed -i` command performs an in-place substitution, replacing the entire line beginning with the variable name. The `^` anchor ensures only top-level variable declarations are matched and not comment lines or occurrences within the script body.

### Step 5: Enable and Start the Service

```bash
systemctl daemon-reload
systemctl enable fan_control.service
systemctl restart fan_control.service
```

| Command | Effect |
|---------|--------|
| `daemon-reload` | Instructs systemd to re-read unit files from disk; required after placing a new `.service` file |
| `enable` | Creates the symlink so the service starts automatically on reboot |
| `restart` | Starts the service immediately without requiring a reboot |

---

## Full Deployment Block

All steps combined for clean execution:

```bash
# 1. Return fan control to the OS so the script can take over cleanly
echo 2 | tee /sys/class/hwmon/hwmon0/pwm1_enable /sys/class/hwmon/hwmon0/pwm2_enable

# 2. Download the fan control script and the system service file
wget -O /root/fan_control.sh https://raw.githubusercontent.com/hoxxep/UNAS-Pro-fan-control/refs/heads/main/fan_control.sh
wget -O /etc/systemd/system/fan_control.service https://raw.githubusercontent.com/hoxxep/UNAS-Pro-fan-control/refs/heads/main/fan_control.service

# 3. Make the script executable
chmod +x /root/fan_control.sh

# 4. Inject custom temperature targets
sed -i 's/^MIN_FAN=.*/MIN_FAN=30/' /root/fan_control.sh
sed -i 's/^HDD_TGT=.*/HDD_TGT=55/' /root/fan_control.sh
sed -i 's/^HDD_MAX=.*/HDD_MAX=62/' /root/fan_control.sh
sed -i 's/^CPU_TGT=.*/CPU_TGT=75/' /root/fan_control.sh
sed -i 's/^CPU_MAX=.*/CPU_MAX=88/' /root/fan_control.sh

# 5. Reload systemd, enable on boot, start immediately
systemctl daemon-reload
systemctl enable fan_control.service
systemctl restart fan_control.service
```

---

## Manual Fan Control (Override Mode)

The commands below allow direct PWM control without the script running. Useful for testing fan behaviour, diagnosing noise issues, or forcing a fixed speed during maintenance. This does not require the systemd service to be active.

### Enter Manual Mode and Set a Fixed Speed

```bash
# 1. Disable automatic fan control and switch to manual mode
echo 1 | tee /sys/class/hwmon/hwmon0/pwm1_enable /sys/class/hwmon/hwmon0/pwm2_enable

# 2. Set fans to a specific raw PWM value (0 = off, 255 = full speed)
echo 75 | tee /sys/class/hwmon/hwmon0/pwm1 /sys/class/hwmon/hwmon0/pwm2

# 3. Verify fan RPMs and check temperatures
sensors
```

The raw PWM value `75` is an approximate starting point for ~1800 RPM, but the exact value that hits your target RPM will vary depending on the specific fans fitted. Identify your precise value by incrementing the number and checking `sensors` output until the reported RPM matches your target. Document the confirmed value here once found.

| PWM Value | Duty Cycle | Approximate Speed |
|-----------|------------|-------------------|
| 0 | 0% | Off (do not use in production) |
| 75 | ~29% | ~1800 RPM (verify with `sensors`) |
| 128 | ~50% | Mid speed |
| 255 | 100% | Full speed |

Note: `pwm*_enable=1` (manual mode) persists only until reboot. If the system restarts while the service is enabled, systemd will bring the service back up and restore automatic control.

### Return to Automatic Mode

Run this single command to hand control back to the OS or to the custom script:

```bash
# Return fan control to automatic mode
echo 2 | tee /sys/class/hwmon/hwmon0/pwm1_enable /sys/class/hwmon/hwmon0/pwm2_enable
```

This is the same command used in Step 1 of the deployment. After running it, restart the service if it is not already running:

```bash
systemctl restart fan_control.service
```

---

## Verification

### Check Service Status

```bash
systemctl status fan_control.service
```

Expected output includes `Active: active (running)`.

### View Live Logs

```bash
journalctl -u fan_control.service -f
```

The `-f` flag follows log output in real time, useful for confirming the script is reading temperatures and adjusting PWM values as expected.

### Read Current PWM Values

```bash
cat /sys/class/hwmon/hwmon0/pwm1
cat /sys/class/hwmon/hwmon0/pwm2
```

Values range from `0` (off) to `255` (full speed). At idle with drives around 40C, a `MIN_FAN=30` setting corresponds to a duty cycle of approximately 30/255 (~12%), which is in the 1800 RPM range on typical fans.

### Read Current Temperatures

```bash
cat /sys/class/hwmon/hwmon0/temp1_input
```

Values are reported in millidegrees Celsius. For example, `42000` = 42C.

---

## Persistence After Reboot

`systemctl enable` creates a symlink in the appropriate `wants` directory so the service starts during the boot sequence. Confirm this with:

```bash
systemctl is-enabled fan_control.service
```

Expected output: `enabled`

The `pwm*_enable` values written in Step 1 are not persistent across reboots by default. The `fan_control.service` unit from the hoxxep repository includes a pre-start step that re-applies those values before the script runs. Confirm this is present in the service file if behaviour after reboot is unexpected:

```bash
cat /etc/systemd/system/fan_control.service
```

Look for an `ExecStartPre` line writing to the `pwm*_enable` sysfs paths. If absent, add the following to the `[Service]` block:

```ini
ExecStartPre=/bin/sh -c 'echo 2 | tee /sys/class/hwmon/hwmon0/pwm1_enable /sys/class/hwmon/hwmon0/pwm2_enable'
```

Then reload and restart:

```bash
systemctl daemon-reload
systemctl restart fan_control.service
```

---

## References

- hoxxep/UNAS-Pro-fan-control (GitHub): https://github.com/hoxxep/UNAS-Pro-fan-control
- Linux kernel hwmon sysfs interface: https://www.kernel.org/doc/Documentation/hwmon/sysfs-interface
- systemd.service man page: https://www.freedesktop.org/software/systemd/man/systemd.service.html
- Seagate IronWolf datasheet (DS1904-3-2006US): https://www.seagate.com/files/www-content/datasheets/pdfs/ironwolf-12tb-DS1904-3-2006US-en_US.pdf