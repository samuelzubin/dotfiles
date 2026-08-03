#!/bin/bash

# Get the active profile name
CURRENT=$(tuned-adm active | awk '{print $NF}')

# Handle profile toggling with wildcard matching
if [ "$1" = "toggle" ]; then
  case "$CURRENT" in
  *powersave*)
    NEXT="balanced"
    ;;
  *balanced*)
    NEXT="throughput-performance"
    ;;
  *)
    NEXT="powersave"
    ;;
  esac

  CURRENT="$NEXT"
  sudo tuned-adm profile "$NEXT"
  pkill -RTMIN+4 waybar
fi

# Map profiles to icons and labels with wildcard matching
case "$CURRENT" in
*powersave*)
  ICON="󰌪"
  LABEL="Eco"
  CLASS="powersave"
  ;;
*balanced*)
  ICON="󰗑"
  LABEL="Balanced"
  CLASS="balanced"
  ;;
*performance*)
  ICON="󰓅"
  LABEL="Performance"
  CLASS="performance"
  ;;
*)
  ICON="󰚥"
  LABEL="idk good luck"
  CLASS="unknown"
  ;;
esac

# Output JSON for Waybar
echo "{\"text\": \"$ICON \", \"tooltip\": \"$LABEL\", \"class\": \"$CLASS\"}"
