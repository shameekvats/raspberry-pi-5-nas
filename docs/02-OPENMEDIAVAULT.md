# OpenMediaVault Installation & Configuration

## Step 1 — Flash Pi OS to SD Card

1. Download [Raspberry Pi Imager](https://www.raspberrypi.com/software/)
2. Select device: **Raspberry Pi 5**
3. Select OS: **Raspberry Pi OS Lite (64-bit)** — no desktop needed for a headless NAS
4. Select your SD card
5. Click the **settings (gear) icon** before writing and configure:

**General tab:**
- Hostname: `pi5-nas`
- Username and password: choose a strong password
- Configure WiFi (optional — wired Ethernet is strongly preferred)
- Set locale and timezone

**Services tab:**
- Enable SSH: ✅
- Authentication: password (switch to key-based after first login)

6. Write the image and wait for verification
7. Insert the SD card into the Pi and power on

---

## Step 2 — First SSH Connection

After ~90 seconds, the Pi should be reachable on the local network:

```bash
ssh <YOUR_USERNAME>@pi5-nas.local
# Or by IP if mDNS isn't working:
ssh <YOUR_USERNAME>@<YOUR_NAS_IP>
```

First connection will ask you to confirm the host fingerprint — type `yes`.

---

## Step 3 — System Update

```bash
sudo apt update
sudo apt upgrade -y
sudo apt install -y smartmontools htop curl wget git rsync
sudo reboot
```

Wait ~60 seconds, then reconnect via SSH.

---

## Step 4 — Verify Drives

```bash
lsblk
# Confirm all expected drives appear as sda, sdb, sdc, sdd...

sudo smartctl -i /dev/sda
# Repeat for each drive — note model and serial number
```

---

## Step 5 — Install OpenMediaVault

```bash
wget -O - https://github.com/OpenMediaVault-Plugin-Developers/installScript/raw/master/install | sudo bash
```

This takes 15–30 minutes and **reboots automatically** when complete. Do not interrupt it.

After reboot, wait 2–3 minutes for all services to start.

---

## Step 6 — Access OMV Web Interface

Open a browser and go to:

```
http://pi5-nas.local
```

Or use the Pi's IP address directly.

**Default credentials:**
- Username: `admin`
- Password: `openmediavault`

**Change the admin password immediately:**
Click your username (top right) → Change Password

---

## Step 7 — Initial OMV Configuration

### Date & Time
- System → Date & Time
- Enable NTP: Yes
- Set your timezone
- Save and Apply

### Update OMV
- System → Update Management
- Install any available updates

---

## Step 8 — Install OMV-Extras

OMV-Extras adds the mergerfs plugin, Docker integration, and other important features.

```bash
# SSH into the Pi
wget -O - https://github.com/OpenMediaVault-Plugin-Developers/packages/raw/master/install | sudo bash
```

After installation, refresh the OMV web page. A new **System → omv-extras** menu item should appear.

---

## ⚠️ Pi 5 Network Interface Name

> **This is the most important Pi 5 gotcha when running OMV.**

The Raspberry Pi 5's Ethernet interface is named **`end0`**, not the conventional `eth0` used by most documentation and expected by OMV's default configuration.

If OMV stores `eth0` in its config and you run a salt deploy or full reconfiguration, it will regenerate the network config file using `eth0` — a non-existent interface on the Pi 5. The Pi will get no IP address and become completely unreachable.

### How to check your interface name

```bash
ip link show
# Look for an entry that is NOT 'lo' — on Pi 5 it will be 'end0'
```

### How to ensure OMV uses the correct name

After OMV installation, verify that OMV knows about `end0`:

1. **System → Network → Interfaces** in the OMV dashboard
2. The interface listed should be `end0`
3. If it shows `eth0`, click the interface, change the name to `end0`, and save

If you ever need to recover from a broken network config, SSH into the Pi, edit `/etc/network/interfaces` or restore the OMV config backup, then run `sudo omv-salt deploy run network`.

---

## Step 9 — Configure SMART Monitoring

Enable drive health monitoring early so you have a baseline:

1. **Storage → S.M.A.R.T. → Settings**
   - Enable: Yes
   - Check interval: 1800 seconds (30 min)
   - Temperature info threshold: 45°C
   - Temperature critical threshold: 60°C
   - Save and Apply

2. **Storage → S.M.A.R.T. → Devices**
   - Enable monitoring for each drive
   - Save and Apply

3. **Storage → S.M.A.R.T. → Scheduled Tests**
   - Add: Short self-test, daily at 2 AM, all drives
   - Add: Long self-test, weekly on Sunday at 3 AM
   - Save and Apply

---

## Step 10 — Configure Email Notifications (Optional)

**System → Notification → Settings**

For Gmail with an App Password:
- SMTP server: `smtp.gmail.com`
- Port: `587`
- TLS: Yes
- Username: your Gmail address
- Password: Gmail App Password (not your account password — generate at Google Account → Security → App Passwords)
- Recipient: your email address

Click "Send test email" to verify.

---

## OMV Quick Reference

| URL | Service |
|---|---|
| `http://pi5-nas.local` | OMV dashboard |
| `http://pi5-nas.local:9000` | Portainer (after Docker setup) |
| `http://pi5-nas.local:8080` | Nextcloud |
| `http://pi5-nas.local:2283` | Immich |
| `http://pi5-nas.local:8123` | Home Assistant |

---

**Next step:** [Storage — mergerfs pool and SnapRAID](03-STORAGE.md)
