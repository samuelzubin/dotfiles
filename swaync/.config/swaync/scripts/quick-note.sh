#!/bin/bash
# Quick-capture a task from the swaync button grid / Mod+Shift+N.
# Appends "- [ ] <text>" to the vault's tasks.md (Obsidian checkbox format).
# Pressing the key again while the popup is open dismisses it without saving.

FILE="${QUICK_NOTE_FILE:-$HOME/Documents/main-vault/tasks.md}"
PIDFILE="${XDG_RUNTIME_DIR:-/tmp}/quick-note-rofi.pid"

# Already open? Dismiss it (the first instance then sees a non-zero exit and saves nothing).
if [[ -r $PIDFILE ]]; then
	pid=$(<"$PIDFILE")
	if [[ -n $pid && $(cat "/proc/$pid/comm" 2>/dev/null) == rofi ]]; then
		kill "$pid"
		exit 0
	fi
fi

# Compact variant of the global rofi theme, for this popup only: top-right corner
# (10px in, matching the niri gaps; rofi sits below waybar on its own), no list
# area, tight padding, small font, custom placeholder.
THEME='* { font: "JetBrainsMono NF 13"; }
window { width: 25%; padding: 8px; location: northeast; anchor: northeast; x-offset: -10px; y-offset: 10px; }
mainbox { spacing: 0px; }
inputbar { padding: 8px 12px; }
listview { enabled: false; }
entry { placeholder: "New note"; }'

out=$(mktemp)
rofi -dmenu -p "Task" -l 0 -theme-str "$THEME" </dev/null >"$out" &
rpid=$!
echo "$rpid" >"$PIDFILE"
wait "$rpid"
rc=$?
[[ $(<"$PIDFILE") == "$rpid" ]] && rm -f "$PIDFILE"
note=$(<"$out")
rm -f "$out"

# Enter exits 0; Escape (1) or a second keypress (killed) mean dismiss.
((rc == 0)) && [[ -n $note ]] || exit 0

# Make sure we start on a fresh line before appending.
[[ -s $FILE && $(tail -c1 "$FILE") != "" ]] && echo >>"$FILE"
printf -- '- [ ] %s\n' "$note" >>"$FILE"
notify-send -u low "Note saved" "$note"
