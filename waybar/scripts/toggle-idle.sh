#!/bin/bash

# Matching pattern for the inhibit process
PATTERN="systemd-inhibit.*Waybar idle inhibitor"

# Lock / Timestamp file to track remaining time
EXPIRE_FILE="/tmp/idle-inhibitor-expire"

# Duration in seconds (2 hours = 7200 seconds)
DURATION=7200

# Toggle logic
if [ "$1" = "toggle" ]; then
  if pgrep -f "$PATTERN" >/dev/null; then
    # Inhibitor is ON -> Turn it OFF
    pkill -f "$PATTERN"
    rm -f "$EXPIRE_FILE"
  else
    # Calculate target expiration timestamp (current Unix time + duration)
    EXPIRATION=$(($(date +%s) + DURATION))
    echo "$EXPIRATION" >"$EXPIRE_FILE"

    # Inhibitor is OFF -> Turn it ON with timeout
    nohup systemd-inhibit \
      --what=idle:sleep:handle-lid-switch \
      --why="Waybar idle inhibitor" \
      bash -c "sleep $DURATION; rm -f '$EXPIRE_FILE'; pkill -RTMIN+5 waybar" >/dev/null 2>&1 &
  fi

  # Refresh waybar immediately on click
  sleep 0.1
  pkill -RTMIN+5 waybar
  exit 0
fi

# Check current state
if pgrep -f "$PATTERN" >/dev/null && [ -f "$EXPIRE_FILE" ]; then
  ENABLED=true
  EXPIRATION=$(cat "$EXPIRE_FILE")
  NOW=$(date +%s)
  REMAINING=$((EXPIRATION - NOW))

  if [ "$REMAINING" -gt 0 ]; then
    HOURS=$((REMAINING / 3600))
    MINS=$(((REMAINING % 3600) / 60))

    if [ "$HOURS" -gt 0 ]; then
      TIME_LEFT="${HOURS}h ${MINS}m left"
    elif [ "$MINS" -gt 0 ]; then
      TIME_LEFT="${MINS}m left"
    else
      TIME_LEFT="<1m left"
    fi
  else
    TIME_LEFT="expiring..."
  fi
else
  ENABLED=false
  rm -f "$EXPIRE_FILE" 2>/dev/null
fi

# Output JSON for Waybar
if $ENABLED; then
  ICON="󰌵"
  LABEL="Idle Inhibitor: ON ($TIME_LEFT)"
  CLASS="enabled"
else
  ICON="󰌶"
  LABEL="Idle Inhibitor: OFF"
  CLASS="disabled"
fi

echo "{\"text\":\"$ICON \",\"tooltip\":\"$LABEL\",\"class\":\"$CLASS\"}"
