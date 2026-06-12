#!/bin/bash
# snapraid-sync.sh
#
# Runs SnapRAID sync and appends a status summary to the log.
# Designed to run nightly via OMV Scheduled Tasks (after backup-vault.sh).
#
# Schedule: System → Scheduled Tasks | root | daily at 02:30
# Log: /var/log/snapraid-sync.log

LOGFILE="/var/log/snapraid-sync.log"

echo "============================================" >> "$LOGFILE"
echo "SnapRAID sync started: $(date)" >> "$LOGFILE"

# Run sync — calculates parity for any new or changed files
snapraid sync >> "$LOGFILE" 2>&1
SYNC_EXIT=$?

if [ $SYNC_EXIT -eq 0 ]; then
    echo "Sync completed successfully: $(date)" >> "$LOGFILE"
else
    echo "Sync FAILED (exit code $SYNC_EXIT): $(date)" >> "$LOGFILE"
fi

# Append a concise status summary
echo "" >> "$LOGFILE"
echo "--- Status ---" >> "$LOGFILE"
snapraid status >> "$LOGFILE" 2>&1

echo "============================================" >> "$LOGFILE"

exit $SYNC_EXIT
