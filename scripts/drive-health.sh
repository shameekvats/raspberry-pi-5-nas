#!/bin/bash
# drive-health.sh
#
# Prints a health summary for all SATA drives.
# Highlights temperature and wear-level warnings.
#
# Usage:
#   sudo /usr/local/scripts/drive-health.sh
#
# Schedule weekly via cron or OMV Scheduled Tasks for regular monitoring.

WARN_TEMP=55      # °C — warn above this temperature
WARN_LIFE=80      # % — warn if SSD life remaining drops below this

DRIVES=(/dev/sda /dev/sdb /dev/sdc /dev/sdd)

echo "============================================"
echo " Drive Health Check — $(date)"
echo "============================================"
echo ""

for DRIVE in "${DRIVES[@]}"; do
    if [ ! -e "$DRIVE" ]; then
        continue
    fi

    echo "--- $DRIVE ---"
    SMART=$(sudo smartctl -A "$DRIVE" 2>/dev/null)
    INFO=$(sudo smartctl -i "$DRIVE" 2>/dev/null)

    # Model and serial
    MODEL=$(echo "$INFO" | grep "Device Model" | awk -F: '{print $2}' | xargs)
    echo "Model:         $MODEL"

    # Power-on hours
    HOURS=$(echo "$SMART" | grep "Power_On_Hours" | awk '{print $10}')
    if [ -n "$HOURS" ]; then
        echo "Power-on hrs:  $HOURS h ($(( HOURS / 24 )) days)"
    fi

    # Temperature
    TEMP=$(echo "$SMART" | grep -i "Temperature_Celsius\|Airflow_Temperature" | head -1 | awk '{print $10}')
    if [ -n "$TEMP" ]; then
        if [ "$TEMP" -gt "$WARN_TEMP" ]; then
            echo "Temperature:   ${TEMP}°C  ⚠️  ABOVE ${WARN_TEMP}°C"
        else
            echo "Temperature:   ${TEMP}°C  ✅"
        fi
    fi

    # SSD life remaining (consumer SSDs)
    LIFE=$(echo "$SMART" | grep -i "SSD_Life_Left\|Wear_Leveling_Count\|Percent_Lifetime_Remain" | head -1 | awk '{print $4}')
    if [ -n "$LIFE" ]; then
        if [ "$LIFE" -lt "$WARN_LIFE" ]; then
            echo "Life remaining: ${LIFE}%  ⚠️  BELOW ${WARN_LIFE}%"
        else
            echo "Life remaining: ${LIFE}%  ✅"
        fi
    fi

    # Reallocated sectors — should always be 0
    REALLOC=$(echo "$SMART" | grep "Reallocated_Sector_Ct" | awk '{print $10}')
    if [ -n "$REALLOC" ] && [ "$REALLOC" -gt 0 ]; then
        echo "Reallocated:   $REALLOC  ⚠️  SECTORS REALLOCATED — monitor closely"
    elif [ -n "$REALLOC" ]; then
        echo "Reallocated:   $REALLOC  ✅"
    fi

    # Pending sectors
    PENDING=$(echo "$SMART" | grep "Current_Pending_Sector" | awk '{print $10}')
    if [ -n "$PENDING" ] && [ "$PENDING" -gt 0 ]; then
        echo "Pending:       $PENDING  ⚠️  PENDING SECTORS"
    fi

    echo ""
done

echo "============================================"
echo " Check complete — $(date)"
echo "============================================"
