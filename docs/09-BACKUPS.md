# Backups

A NAS is not a backup. Backups are separate, independent copies of data. This guide covers the backup strategy used in this project.

---

## Backup Strategy Overview

| Layer | What | Where | How often |
|---|---|---|---|
| SnapRAID parity | NAS pool drives | Secondary SSD | Nightly sync |
| Vault rsync | Critical files only | Secondary SSD | Daily at 2 AM |
| OMV config | OMV settings | NAS pool Backups/ | Manual + before changes |
| Docker configs | Compose files | NAS pool Docker/ | Included in pool |
| Off-site | Critical data | Cloud or external drive | Weekly / monthly |

**SnapRAID is not a backup** — it protects against drive failure, not against accidental deletion, ransomware, or fire. It complements backups but does not replace them.

---

## The Vault Concept

Rather than backing up the entire NAS pool (which may be hundreds of gigabytes), a dedicated `Vault` folder holds only critical, irreplaceable files:

```
/srv/mergerfs/storage-pool/Documents/
├── everyday_files/         ← NOT backed up (can be recreated)
├── projects/               ← NOT backed up automatically
└── Vault/                  ← BACKED UP every night
    ├── important-docs/
    ├── contracts/
    └── certificates/
```

Files in Vault are mirrored nightly to the secondary SSD. The secondary SSD failing would lose the backup copy but not the original (on the NAS pool). A secondary SSD failure is therefore low-risk for the Vault.

---

## Step 1 — Create the Vault Folder

```bash
mkdir -p /srv/mergerfs/storage-pool/Documents/Vault
```

The Vault folder is accessible via:
- Nextcloud (NAS Documents external storage → Vault/)
- SMB (Documents share → Vault/)
- SSH / direct path

---

## Step 2 — Create the Backup Script

```bash
sudo mkdir -p /usr/local/scripts
sudo nano /usr/local/scripts/backup-vault.sh
```

Paste the following — see [scripts/backup-vault.sh](../scripts/backup-vault.sh) for the ready-to-use version:

```bash
#!/bin/bash
# Daily backup: Documents/Vault → Secondary SSD

SOURCE="/srv/mergerfs/storage-pool/Documents/Vault/"
DEST="/srv/dev-disk-by-uuid-<PARITY-UUID>/Backups/Vault/"
LOGFILE="/var/log/backup-vault.log"

echo "========================================" >> "$LOGFILE"
echo "Backup started: $(date)" >> "$LOGFILE"

# Create destination if it doesn't exist
mkdir -p "$DEST"

# Sync — mirror source to destination, delete removed files
rsync -av --delete "$SOURCE" "$DEST" >> "$LOGFILE" 2>&1

if [ $? -eq 0 ]; then
    echo "Backup completed successfully: $(date)" >> "$LOGFILE"
else
    echo "Backup FAILED: $(date)" >> "$LOGFILE"
fi

echo "========================================" >> "$LOGFILE"
```

Make it executable:

```bash
sudo chmod +x /usr/local/scripts/backup-vault.sh
```

Test it manually:

```bash
sudo /usr/local/scripts/backup-vault.sh
sudo tail -20 /var/log/backup-vault.log
```

---

## Step 3 — Schedule the Backup via OMV

1. **System → Scheduled Tasks → + Add**
2. Configure:
   - Enabled: Yes
   - User: `root`
   - Command: `/usr/local/scripts/backup-vault.sh`
   - Minute: `0`
   - Hour: `2`
   - Day/Month/Weekday: `*` (run every day)
   - Comment: `Daily Vault backup`
3. Save → Apply

To verify the cron entry was created:

```bash
sudo crontab -l
# Should show: 0 2 * * * /usr/local/scripts/backup-vault.sh
```

---

## Backing Up Docker Compose Files

Compose files are stored on the NAS pool (`/srv/mergerfs/storage-pool/Docker/Compose/`), so they are:
- Protected by SnapRAID parity
- Included in any off-site backup of the pool

To back them up to the secondary SSD as well:

```bash
sudo nano /usr/local/scripts/backup-docker-configs.sh
```

```bash
#!/bin/bash
SOURCE="/srv/mergerfs/storage-pool/Docker/Compose/"
DEST="/srv/dev-disk-by-uuid-<PARITY-UUID>/Backups/Docker-Compose/"
LOGFILE="/var/log/backup-docker.log"

echo "Docker config backup: $(date)" >> "$LOGFILE"
mkdir -p "$DEST"
rsync -av --delete "$SOURCE" "$DEST" >> "$LOGFILE" 2>&1
echo "Done: $(date)" >> "$LOGFILE"
```

```bash
sudo chmod +x /usr/local/scripts/backup-docker-configs.sh
```

Schedule at 2:30 AM via OMV Scheduled Tasks.

---

## Backing Up OMV Configuration

OMV's configuration (network, storage, services) can be exported as a backup:

**System → Backup → Backup**

Download the file and store it on your Mac or in cloud storage. Do this:
- Before making major changes to OMV
- Monthly as part of routine maintenance

To restore: **System → Backup → Restore**

---

## Monitoring Backup Logs

Check that backups are running correctly:

```bash
# View recent vault backup log
sudo tail -30 /var/log/backup-vault.log

# View SnapRAID sync log
sudo tail -30 /var/log/snapraid-sync.log

# Check backup destination size
du -sh /srv/dev-disk-by-uuid-<PARITY-UUID>/Backups/
```

---

## Off-Site Backup (Recommended)

For true 3-2-1 backup (3 copies, 2 media types, 1 off-site), consider:

- **Encrypted cloud backup** — use `rclone` with Backblaze B2 or similar to push the Vault folder to cloud storage
- **External USB drive** — plug in periodically, rsync Vault to it, unplug and store elsewhere

Example rclone command (after configuring a remote):

```bash
rclone sync /srv/mergerfs/storage-pool/Documents/Vault/ remote:your-bucket/vault/ \
  --progress \
  --log-file /var/log/rclone-backup.log
```

---

## Drive Health Monitoring

Run the drive health check script weekly to catch degradation early — see [scripts/drive-health.sh](../scripts/drive-health.sh):

```bash
sudo /usr/local/scripts/drive-health.sh
```

Key things to watch:
- `SSD_Life_Left` / `Wear_Leveling_Count` — should stay above 80% for consumer SSDs
- `Reallocated_Sector_Count` — should always be 0
- Temperature — keep below 60°C

---

**Next step:** [Troubleshooting](10-TROUBLESHOOTING.md)
