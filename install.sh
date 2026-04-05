#!/usr/bin/env bash
# let-it-burn installer — sets up a cron job to burn tokens 10 minutes before your reset
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BURN_SCRIPT="$SCRIPT_DIR/burn.sh"

if [[ ! -x "$BURN_SCRIPT" ]]; then
  echo "Error: burn.sh not found or not executable at $BURN_SCRIPT"
  exit 1
fi

echo "🚬 let-it-burn installer"
echo ""
echo "What day of the week does your Claude plan reset?"
echo ""
echo "  0) Sunday"
echo "  1) Monday"
echo "  2) Tuesday"
echo "  3) Wednesday"
echo "  4) Thursday"
echo "  5) Friday"
echo "  6) Saturday"
echo ""
read -rp "Day [0-6]: " day_num

if [[ ! "$day_num" =~ ^[0-6]$ ]]; then
  echo "Invalid day. Enter 0-6."
  exit 1
fi

days=(Sunday Monday Tuesday Wednesday Thursday Friday Saturday)
day_name="${days[$day_num]}"

echo ""
echo "What hour does it reset? (24-hour format, in your local timezone)"
echo "  e.g. 20 for 8:00 PM, 9 for 9:00 AM"
echo ""
read -rp "Hour [0-23]: " reset_hour

if [[ ! "$reset_hour" =~ ^([0-9]|1[0-9]|2[0-3])$ ]]; then
  echo "Invalid hour. Enter 0-23."
  exit 1
fi

# Calculate 10 minutes before reset
if [[ "$reset_hour" -eq 0 ]]; then
  cron_hour=23
  # Previous day
  if [[ "$day_num" -eq 0 ]]; then
    cron_day=6
  else
    cron_day=$((day_num - 1))
  fi
else
  cron_hour=$((reset_hour - 1))
  cron_day=$day_num
fi
cron_minute=50

cron_day_name="${days[$cron_day]}"

echo ""
echo "Your reset: ${day_name} at $(printf '%02d' "$reset_hour"):00"
echo "Burn starts: ${cron_day_name} at $(printf '%02d' "$cron_hour"):${cron_minute} (10 min before)"
echo ""
read -rp "Install cron job? [y/N]: " confirm

if [[ ! "$confirm" =~ ^[yY]$ ]]; then
  echo "Aborted."
  exit 0
fi

CRON_LINE="$cron_minute $cron_hour * * $cron_day $BURN_SCRIPT >> /tmp/let-it-burn-cron.log 2>&1"

# Remove any existing let-it-burn cron entry, then add the new one
(crontab -l 2>/dev/null | grep -v "let-it-burn"; echo "$CRON_LINE") | crontab -

echo ""
echo "🔥 Installed! Cron entry:"
echo "   $CRON_LINE"
echo ""
echo "To remove: crontab -e and delete the let-it-burn line"
echo "To test now: ./burn.sh"
