# Storage — mergerfs Pool, SnapRAID & SMB Shares

## Overview

This project uses two storage layers:

| Layer | Technology | Drives |
|---|---|---|
| Primary data pool | mergerfs | 3× NAS-grade SSDs |
| Secondary / Docker | Single volume | 1× consumer SSD |
| Parity protection | SnapRAID | Uses secondary SSD as parity target |

**mergerfs** presents multiple drives as a single unified mount point. It is not RAID — if a drive fails, data on that drive is lost unless protected by SnapRAID or backed up elsewhere.

**SnapRAID** calculates and stores parity data, allowing recovery from a single drive failure. Parity is written during a scheduled nightly sync, not in real time.

---

## Drive Notes

### NAS-grade SSDs (primary pool)

Use drives explicitly rated for 24/7 NAS operation:
- WD Red SA500
- Seagate IronWolf 125 SSD
- Samsung 870 EVO (widely used in homelab — 600TB TBW, 5yr warranty)

### Consumer SSDs (secondary / Docker)

Consumer drives (e.g. Kingston A400) are **not** rated for continuous NAS operation. They have lower write endurance and no power-loss protection. Acceptable uses:
- Docker volumes and container images (easy to rebuild)
- Daily backup destination (moderate writes)
- SnapRAID parity drive (read-heavy, writes only during nightly sync)

**Do not** store irreplaceable data on a consumer SSD in a 24/7 NAS role. Monitor with `smartctl` weekly.

---

## Step 1 — Install OMV-Extras and mergerfs Plugin

From the OMV web interface:

1. **System → Plugins** — search for `mergerfs`
2. Install `openmediavault-mergerfs`
3. Click Apply when prompted
4. Refresh the browser — **Storage → mergerfs** should now appear

---

## Step 2 — Wipe and Format Drives

> ⚠️ This erases all data on the selected drives.

**For each drive that will be part of the pool:**

1. **Storage → Disks** — select a drive
2. Click **Wipe → Quick** — this clears the partition table
3. Apply, then repeat for each drive

**Create filesystems:**

1. **Storage → File Systems → + Create**
2. For each NAS drive:
   - Device: select the drive (e.g. `/dev/sda`)
   - Type: **EXT4**
   - Label: `NAS-1`, `NAS-2`, `NAS-3`
   - Save → Apply → wait for creation
3. For the secondary SSD:
   - Label: `Secondary`

**Mount all filesystems:**

For each newly created filesystem:
1. Select it in the list
2. Click **Mount**
3. Confirm status shows **Mounted**

---

## Step 3 — Create the mergerfs Pool

1. **Storage → mergerfs → + Create**
2. Configure:
   - Name: `storage-pool`
   - Branches: select all NAS drives (NAS-1, NAS-2, NAS-3)
   - Policy: `epmfs` (existing path, most free space — files stay on the drive where the folder already exists)
   - Minimum free space: `10G`
3. Save → Apply

The pool is now mounted at `/srv/mergerfs/storage-pool/` and presents the combined capacity of all member drives.

**Verify:**

```bash
df -h | grep mergerfs
# Should show the combined pool size
```

---

## Step 4 — Create Shared Folders

**Storage → Shared Folders → + Create**

Create the following folders, all on the `storage-pool` device:

| Name | Relative path | Purpose |
|---|---|---|
| `Documents` | `Documents/` | Nextcloud file storage |
| `Photos` | `Photos/` | Immich photo library |
| `Media` | `Media/` | Jellyfin content |
| `Backups` | `Backups/` | System backups |
| `Docker` | `Docker/` | Compose files and app configs |
| `Downloads` | `Downloads/` | Temporary downloads |

Create one more on the **Secondary** device (not the pool):

| Name | Relative path | Purpose |
|---|---|---|
| `DockerVolumes` | `docker/` | Docker engine root (images + volumes) |

Save and Apply after each, or batch them and Apply once at the end.

---

## Step 5 — Enable SMB/CIFS File Sharing

### Enable the service

1. **Services → SMB/CIFS → Settings**
2. Enable: Yes
3. Workgroup: `WORKGROUP`
4. Save → Apply

### Create shares

**Services → SMB/CIFS → Shares → + Add** for each folder to share:

| Shared folder | Public | Read only | Browseable |
|---|---|---|---|
| Documents | No | No | Yes |
| Photos | No | No | Yes |
| Media | No | No | Yes |

Leave Docker, Backups, and DockerVolumes unshared — they're managed via SSH and Portainer.

Save → Apply

### Test from a client

**macOS:**
```
Finder → Go → Connect to Server
smb://pi5-nas.local
```

**Windows:**
```
Open File Explorer → address bar
\\pi5-nas
```

Enter the NAS user credentials when prompted.

---

## Step 6 — Configure SMB Write Permissions

If files written over SMB show permission errors, the Samba user needs to be in the same group as the web server / OMV files:

```bash
# Add the NAS user to www-data group
sudo usermod -aG www-data <YOUR_USERNAME>

# Set correct permissions on the pool
sudo chmod -R 775 /srv/mergerfs/storage-pool/
sudo chown -R <YOUR_USERNAME>:www-data /srv/mergerfs/storage-pool/

# Restart Samba to pick up changes
sudo systemctl restart smbd
```

Disconnect and remount the share from your client after making these changes.

---

## Step 7 — Auto-Mount SMB on macOS

To have the NAS shares mount automatically on login, create a LaunchAgent:

```bash
# On your Mac (not the Pi)
mkdir -p ~/mnt/Documents ~/mnt/Photos ~/mnt/Media
```

Create `~/Library/LaunchAgents/com.user.mount-nas.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.mount-nas</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/sh</string>
        <string>-c</string>
        <string>
            mount_smbfs //YOUR_USERNAME@pi5-nas.local/Documents ~/mnt/Documents;
            mount_smbfs //YOUR_USERNAME@pi5-nas.local/Photos ~/mnt/Photos;
            mount_smbfs //YOUR_USERNAME@pi5-nas.local/Media ~/mnt/Media
        </string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
```

Replace `YOUR_USERNAME` with your NAS username. Save the NAS password in macOS Keychain when prompted on first mount so future mounts are passwordless.

Load the agent:
```bash
launchctl load ~/Library/LaunchAgents/com.user.mount-nas.plist
```

---

## Step 8 — SnapRAID Configuration

SnapRAID provides parity protection. It calculates parity from your data drives and writes it to a separate parity drive. In a single-drive failure, the lost data can be reconstructed.

> In this setup, the consumer SSD serves as the parity drive. If the parity drive fails, your data is still intact on the NAS drives — only the parity is lost (and can be recalculated).

### Install SnapRAID

```bash
sudo apt update
sudo apt install snapraid -y
snapraid --version
```

### Find Drive UUIDs

```bash
lsblk -f
# or
sudo blkid
```

Note the UUID for each partition:
- NAS drive 1: `<NAS1-UUID>`
- NAS drive 2: `<NAS2-UUID>`
- NAS drive 3: `<NAS3-UUID>`
- Secondary / parity drive: `<PARITY-UUID>`

### Create the Configuration File

```bash
sudo nano /etc/snapraid.conf
```

Paste and edit with your actual UUIDs — see [configs/snapraid.conf.example](../configs/snapraid.conf.example) for a ready-to-edit template.

```
# Parity file — on the consumer SSD
parity /srv/dev-disk-by-uuid-<PARITY-UUID>/snapraid/snapraid.parity

# Content files — metadata, keep copies on multiple drives
content /var/snapraid/snapraid.content
content /srv/dev-disk-by-uuid-<NAS1-UUID>/snapraid.content
content /srv/dev-disk-by-uuid-<NAS2-UUID>/snapraid.content

# Data disks
data d1 /srv/dev-disk-by-uuid-<NAS1-UUID>/
data d2 /srv/dev-disk-by-uuid-<NAS2-UUID>/
data d3 /srv/dev-disk-by-uuid-<NAS3-UUID>/

# Exclusions
exclude *.unrecoverable
exclude /tmp/
exclude /lost+found/
exclude *.!sync
exclude .DS_Store
exclude .Thumbs.db

block_size 256
autosave 500
```

### Create Required Directories

```bash
sudo mkdir -p /var/snapraid
sudo mkdir -p /srv/dev-disk-by-uuid-<PARITY-UUID>/snapraid
```

### Run First Sync

The first sync scans all data and creates the parity file. It takes 30–90 minutes depending on how much data exists.

```bash
sudo snapraid sync
```

### Check Status

```bash
sudo snapraid status
# Shows: drives, data protected, any issues
```

### Schedule Daily Sync

Use the script in [scripts/snapraid-sync.sh](../scripts/snapraid-sync.sh), then add it to OMV's scheduler:

1. **System → Scheduled Tasks → + Add**
2. Enabled: Yes
3. User: `root`
4. Command: `/usr/local/scripts/snapraid-sync.sh`
5. Schedule: daily at 2:30 AM (after the backup vault runs at 2:00 AM)
6. Save → Apply

---

## Storage Layout Reference

```
/srv/mergerfs/storage-pool/          ← mergerfs pool (combined NAS drives)
├── Documents/
├── Photos/
├── Media/
│   ├── Movies/
│   ├── TV-Shows/
│   └── Music/
├── Backups/
├── Docker/
│   └── Compose/
└── Downloads/

/srv/dev-disk-by-uuid-<PARITY-UUID>/ ← Secondary SSD
├── docker/                           ← Docker engine root
├── Backups/
│   └── Vault/                        ← Daily rsync destination
└── snapraid/
    └── snapraid.parity
```

---

**Next step:** [Docker & Portainer](04-DOCKER.md)
