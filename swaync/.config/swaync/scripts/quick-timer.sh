#!/bin/bash
# Countdown timer driven from the swaync button grid.
#   click while idle     -> rofi prompt for a duration (preset, or e.g. 90s / 12m / 1h30m)
#   click while running  -> cancel
# A transient systemd user timer does the waiting. State files in
# $XDG_RUNTIME_DIR are read by button-labels.sh for the button label/highlight:
#   quick-timer-end (epoch the timer finishes)   quick-timer-input (original text)

UNIT="${QUICK_TIMER_UNIT:-quick-timer}"
RT="${QUICK_TIMER_DIR:-${XDG_RUNTIME_DIR:-/tmp}}"
END_FILE="$RT/quick-timer-end"
INPUT_FILE="$RT/quick-timer-input"
WATCHER_PID="${XDG_RUNTIME_DIR:-/tmp}/swaync-button-labels.pid"

# Tell the label watcher to refresh now instead of at its next wake-up.
poke() { kill -USR2 "$(cat "$WATCHER_PID" 2>/dev/null)" 2>/dev/null; return 0; }

running=0
if [[ -r $END_FILE ]]; then
	if (($(<"$END_FILE") > $(date +%s))); then running=1; else rm -f "$END_FILE"; fi
fi

if ((running)); then
	systemctl --user stop "$UNIT.timer" "$UNIT.service" 2>/dev/null
	rm -f "$END_FILE" "$INPUT_FILE"
	# notify-send -u low "Timer cancelled"
	poke
	exit 0
fi

# Only the prompt needs the panel out of the way; cancelling leaves it open.
swaync-client -cp
input=$(printf '1m\n5m\n10m\n15m\n25m\n30m\n1h\n' | rofi -dmenu -p "Timer (e.g. 90s, 12m, 1h30m)" -i)
[[ -z $input ]] && exit 0

# Validate with systemd's own time parser.
us=$(systemd-analyze timespan "$input" 2>/dev/null | sed -n 's/^ *μs: *//p')
if [[ -z $us || $us -le 0 ]]; then
	notify-send -u low "Timer" "Couldn't parse \"$input\""
	exit 1
fi
secs=$((us / 1000000))

echo "$input" >"$INPUT_FILE"
echo $(($(date +%s) + secs)) >"$END_FILE"
systemd-run --user --quiet --unit="$UNIT" --on-active="${secs}s" \
	--timer-property=AccuracySec=1s \
	/bin/sh -c 'rm -f "$1" "$2"; kill -USR2 "$(cat "$3" 2>/dev/null)" 2>/dev/null; notify-send -u low -i alarm-symbolic "Timer finished" "$4 elapsed"' \
	sh "$END_FILE" "$INPUT_FILE" "$WATCHER_PID" "$input"
notify-send -u low "Timer started" "$input"
poke
