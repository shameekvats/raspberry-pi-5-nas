#!/bin/bash
# backup-vault.sh
#
# Daily rsync backup of the Vault folder (critical files) from the
# mergerfs storage pool to the secondary SSD.
#
# Schedule via OMV: System → Scheduled Tasks
#   User: root | Command: /usr/local/scripts/backup-vault.sh | Daily at 02:00
#
# SETUP: Replace <PARITY-DRIVE-UUID> with your secondary SSD's UUID.
# Find it with: lsblk -f   or   sudo blkid

SOURCE="/srv/mergerfs/storage-pool/Documents/Vault/"
DEST="/srv/dev-disk-by-uuid-<PARITY-DRIVE-UUID>/Backups/Vault/"
LOGFILE="/var/log/backup-vault.log"

# ---------------------------------------------------------------------------

echo "========================================" >> "$LOGFILE"
echo "Backup started: $(date)" >> "$LOGFILE"
echo "Source:      $SOURCE" >> "$LOGFILE"
echo "Destination: $DEST" >> "$LOGFILE"

# Create destination directory if it doesn't exist
mkdir -p "$DEST"

# Run rsync
# -a  archive mode: preserves permissions, timestamps, symlinks, owner, group
# -v  verbose: log each file transferred
# --delete  mirror source — removes files from dest that no longer exist in source
rsync -av --delete "$SOURCE" "$DEST" >> "$LOGFILE" 2>&1
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo "Backup completed successfully: $(date)" >> "$LOGFILE"
else
    echo "Backup FAILED (exit code $EXIT_CODE): $(date)" >> "$LOGFILE"
fi

echo "========================================" >> "$LOGFILE"

exit $EXIT_CODE
