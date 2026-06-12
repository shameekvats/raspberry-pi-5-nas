# Troubleshooting

---

## Network Recovery — Pi 5 `end0` vs `eth0`

**Symptom:** After running `sudo omv-salt deploy run compose` (or any full OMV configuration redeploy), the Pi is completely unreachable. No response to ping, SSH, Tailscale, or mDNS. Ethernet LEDs on both the Pi and the router are lit, but the Pi has no IP address.

**Root cause:** The Raspberry Pi 5 names its Ethernet interface `end0`, not the conventional `eth0` expected by most Linux network tooling. OMV stores the interface name in its configuration database. If `eth0` is saved there, every salt deploy regenerates the netplan config file using `eth0` — an interface that doesn't exist on the Pi 5. The Pi boots, the network stack starts, but `end0` never receives a DHCP lease.

**How to confirm from a separate Linux machine:**

Remove the SD card from the Pi, insert it in another Linux computer, mount the root partition, and read the journal from the last boot:

```bash
lsblk                          # Find the SD card — two partitions (small FAT32 + large ext4)
sudo mount /dev/sdX2 /mnt      # Mount the ext4 root partition (adjust sdX2 as needed)

# Read what happened during the last boot
sudo journalctl --directory=/mnt/var/log/journal --no-pager -b -1 -u systemd-networkd | tail -30
# Look for lines mentioning 'end0' — confirms the real interface name
```

**Fix — patch both files:**

```bash
# Fix the regenerated netplan config
sudo sed -i 's/eth0/end0/g' /mnt/etc/netplan/20-openmediavault-eth0.yaml

# Fix OMV's source-of-truth so the next salt deploy doesn't overwrite with eth0 again
sudo sed -i 's/<devicename>eth0<\/devicename>/<devicename>end0<\/devicename>/g' \
  /mnt/etc/openmediavault/config.xml

# Unmount cleanly
sudo umount /mnt
```

Reinsert the SD card into the Pi and power on. All services should come back on the original IP.

> **Important:** Patching only the netplan file is not sufficient. OMV regenerates it from `config.xml` on every deploy. Both files must be corrected.

---

## Drive Not Appearing in `lsblk`

**Possible causes and fixes:**

**1. Loose FFC cable**
The flat flex cable connecting the Top Board to the Penta HAT is the most common culprit. Power off, reseat the cable at both ends (press connectors until they click), and power on.

**2. Insufficient power**
The 12V supply must be at least 5A for the HAT + three drives. Below that, drives may fail to spin up or disconnect randomly. Check with a multimeter or try a higher-rated supply.

**3. Drive not fully seated**
Power off, press the drive firmly into the SATA connector until it bottoms out.

```bash
# Check kernel messages for SATA errors
dmesg | grep -i "sata\|scsi\|ata"

# Rescan for new SATA devices without rebooting
sudo sh -c 'echo "- - -" > /sys/class/scsi_host/host0/scan'
```

---

## SMB Share Not Accessible

```bash
# Check if Samba is running
sudo systemctl status smbd nmbd

# Test the SMB configuration
testparm

# Restart Samba
sudo systemctl restart smbd nmbd
```

If the share is visible but you get "Permission denied" when writing:

```bash
# Check the share path permissions
ls -la /srv/mergerfs/storage-pool/

# Add the Samba user to the correct group
sudo usermod -aG www-data <YOUR_USERNAME>

# Set write permissions on the folder
sudo chmod -R 775 /srv/mergerfs/storage-pool/Documents/

# Restart Samba
sudo systemctl restart smbd
```

Disconnect and reconnect the share from your client after making changes.

---

## Docker Container Won't Start

```bash
# Check what's wrong
docker logs <container-name>

# Check if the port is already in use
sudo ss -tlnp | grep <port-number>

# Check if the volume path exists
ls -la /srv/mergerfs/storage-pool/Docker/

# Restart just one container
docker restart <container-name>

# Full redeploy via compose
cd /path/to/compose/folder
docker compose down
docker compose up -d
```

---

## Nextcloud — "Access through untrusted domain"

Add the address you're accessing from to Nextcloud's trusted domains:

```bash
docker exec -it nextcloud bash
php occ config:system:set trusted_domains 2 --value="<YOUR_NAS_IP>"
php occ config:system:set trusted_domains 3 --value="<TAILSCALE_IP>"
exit
```

---

## Nextcloud — Files Added via SMB Not Showing

Nextcloud's file index doesn't update automatically when files are added outside the Nextcloud interface (e.g. via SMB or SSH):

```bash
docker exec -it nextcloud php occ files:scan --all
```

Schedule this to run periodically via OMV Scheduled Tasks if you use SMB heavily.

---

## Immich — Not Starting After Update

Immich sometimes requires database migration on update. Check logs:

```bash
cd /srv/mergerfs/storage-pool/Docker/Compose/immich
docker compose logs -f immich_server
```

If you see migration errors:
```bash
docker compose down
docker compose pull
docker compose up -d
```

Wait a few minutes — migrations run automatically on startup.

---

## SnapRAID — Sync Errors

```bash
# Check current status
sudo snapraid status

# Run a data integrity check (read-only, no changes)
sudo snapraid check

# View sync log
sudo tail -50 /var/log/snapraid-sync.log
```

If `snapraid status` reports a missing or changed parity file:
```bash
# Recalculate parity from scratch (safe — reads all data drives)
sudo snapraid sync --force-full
```

If a drive is reported as failed:
1. Do **not** run sync until you have replaced or recovered the drive
2. Use `snapraid fix` to attempt data recovery

---

## SD Card Corruption / Boot Failure

The SD card is the most fragile component for long-term reliability. To protect it:

**Reduce writes:**
```bash
# Install the OMV flashmemory plugin
# System → Plugins → search "flashmemory" → install
# This moves logs and temp files to RAM
```

**Boot from USB SSD instead (advanced):**
This is a future upgrade — boot the Pi from a USB-attached SSD instead of the SD card, eliminating the single point of failure.

**Back up regularly:**
```bash
# On your Mac — create an image of the SD card
sudo dd if=/dev/diskN of=~/pi5-nas-sdcard-backup.img bs=4m
# Replace /dev/diskN with your SD card device (check with diskutil list)
```

---

## Tailscale Not Connecting

```bash
# Check status
tailscale status

# Re-authenticate
sudo tailscale down
sudo tailscale up

# Restart the service
sudo systemctl restart tailscaled
sudo systemctl status tailscaled
```

If the Pi is on Tailscale but you can't reach services by Tailscale IP, verify:
1. The service is actually running (`docker ps`)
2. The Tailscale IP is in Nextcloud's trusted_domains
3. No firewall is blocking the port (`sudo ufw status`)

---

## General Diagnostics

```bash
# System resource usage
htop

# Disk usage
df -h

# Find what's eating disk space
du -sh /srv/mergerfs/storage-pool/*

# Check all drive health at once
sudo /usr/local/scripts/drive-health.sh

# View recent system logs
sudo journalctl -xe --no-pager | tail -50

# Check all running services
sudo systemctl list-units --state=failed
```
