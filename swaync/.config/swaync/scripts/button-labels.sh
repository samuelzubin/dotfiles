#!/bin/bash
# Keeps the Wi-Fi / Timer / Bluetooth button labels in config.json in sync with
# live state. swaync button labels are static, so a change means rewriting
# config.json and reloading swaync (which also makes the mpris widget redraw).
# To keep that to the moments it is actually visible, and the script near-idle:
#
#  - It sleeps (one `sleep` per wake-up, interrupted by signals via `wait`) and
#    wakes only when something can have changed:
#      * SIGUSR1 / SIGWINCH, sent by a `swaync-client -s` subscription when the
#        control center opens / closes;
#      * SIGUSR2, sent by quick-timer.sh when a timer starts / is cancelled / ends;
#      * when a timer's label is due to change (once a minute);
#      * every NET_INTERVAL seconds as a slow Wi-Fi / Bluetooth check.
#  - Countdown: whole minutes remaining, rounded down so a 30m timer reads "29m"
#    from the first second (29:59 left): "29m", "1h05m", and "<1m" in the last
#    minute. That is one config reload a minute (the mpris widget redraws on each).
#  - A Wi-Fi/Bluetooth change found by the background check is not applied while
#    the control center is open; one found at open time, or a timer update, is.
#
# Toggle buttons' "active" flag is written too, since a reload would reset it.

CONFIG=~/.config/swaync/config.json
RT="${XDG_RUNTIME_DIR:-/tmp}"
TIMER_FILE="$RT/quick-timer-end"
PID_FILE="$RT/swaync-button-labels.pid"
MAXLEN=10
NET_INTERVAL=120

# Single instance (a stale pid file whose pid is gone or reused is ignored).
if [[ -r $PID_FILE ]]; then
	old=$(<"$PID_FILE")
	if [[ -n $old ]] && grep -aq 'button-labels' "/proc/$old/cmdline" 2>/dev/null; then exit 0; fi
fi
echo $$ >"$PID_FILE"


# Event source: swaync-client -s prints a JSON line whenever swaync's state
# changes, including "visible". Turn open into SIGUSR1 and close into SIGWINCH.
# Restarts if swaync does.
PARENT=$$
(
	while true; do
		swaync-client -sw -s 2>/dev/null | while read -r line; do
			case $line in
			*'"visible": true'*) kill -USR1 "$PARENT" 2>/dev/null ;;
			*'"visible": false'*) kill -WINCH "$PARENT" 2>/dev/null ;;
			esac
		done
		sleep 5
	done
) &
sub=$!
# Clean up on TERM/INT/HUP. (Not an EXIT trap: bash also fires that in the
# command-substitution/background subshells this script spawns.)
cleanup() {
	[[ $(<"$PID_FILE") == "$$" ]] && rm -f "$PID_FILE"
	pkill -P "$sub" 2>/dev/null
	kill "$sub" 2>/dev/null
	exit 0
}
trap cleanup TERM INT HUP
opened=0 kick=0 cc_open=0
trap 'kick=1' USR2                       # timer state changed; interrupts the nap
trap 'kick=1 opened=1 cc_open=1' USR1    # control center opened
trap 'kick=1 cc_open=0' WINCH            # control center closed
nap() {
	sleep "$1" &
	local pid=$!
	((kick)) || wait "$pid" # re-check right before waiting: a signal may have just landed
	kill "$pid" 2>/dev/null
}

# Sets wifi, wifi_on, bt_type, bt_name, bt_on, net_sig.
refresh_net() {
	local ssid line mac type
	ssid=$(nmcli -t -f active,ssid dev wifi 2>/dev/null)
	if [[ $(nmcli radio wifi 2>/dev/null) == enabled ]]; then
		wifi_on=1
		ssid=$(sed -n 's/^yes://p' <<<"$ssid" | head -1)
		wifi=${ssid//\\:/:}
		wifi=${wifi:-No network}
	else
		wifi_on=0 wifi=Off
	fi

	if bluetoothctl show 2>/dev/null | grep -q 'Powered: yes'; then
		bt_on=1
		line=$(bluetoothctl devices Connected 2>/dev/null | head -1)
		if [[ -n $line ]]; then
			mac=${line#Device }
			mac=${mac%% *}
			bt_name=${line#Device $mac }
			type=$(bluetoothctl info "$mac" 2>/dev/null | sed -n 's/^[[:space:]]*Icon: //p')
			bt_type=${type:-device}
		else
			bt_type=on bt_name=On
		fi
	else
		bt_on=0 bt_type=off bt_name=Off
	fi
	net_sig="$wifi|$wifi_on|$bt_type|$bt_name|$bt_on"
}

cc_visible() {
	[[ $(gdbus call --session --dest org.erikreider.swaync.cc \
		--object-path /org/erikreider/swaync/cc \
		--method org.erikreider.swaync.cc.GetVisibility 2>/dev/null) == "(true,)" ]]
}

# Rewrites labels/active flags. Prints "changed" or "same", then the timer label as written.
# args: wifi_name wifi_on bt_type bt_name bt_on timer ("" = idle, "R:12:07", "R:1h05m")
apply() {
	python3 -I - "$CONFIG" "$MAXLEN" "$@" <<'PY'
import json, sys
path, n, wifi, wifi_on, bt_type, bt_name, bt_on, timer = sys.argv[1:9]
n = int(n)
ICONS = {
    "off": "\U000f00af", "on": "\U000f00af", "device": "\U000f00b1",
    "audio-headset": "\U000f02ce", "audio-headphones": "\U000f02cb",
    "audio-card": "\U000f04c3", "input-keyboard": "\U000f030c",
    "input-mouse": "\U000f037d", "input-gaming": "\U000f02b4",
    "phone": "\U000f011c", "computer": "\U000f0322", "video-display": "\U000f0502",
}
d = json.load(open(path, encoding="utf-8"))
# Grid order (2 per row): 0 Wi-Fi, 1 Timer, 2 Bluetooth, 3 Note
acts = d["widget-config"]["buttons-grid"]["actions"]
def short(t): return t if len(t) <= n else t[: n - 1] + "…"
label = {
    0: acts[0]["label"][0] + "  " + short(wifi),
    1: "\U000f051b  " + (timer[2:] if timer else "Timer"),
    2: ICONS.get(bt_type, ICONS["device"]) + "  " + short(bt_name),
}
active = {0: wifi_on == "1", 1: timer.startswith("R:"), 2: bt_on == "1"}
changed = False
for i, new in label.items():
    if acts[i]["label"] != new:
        acts[i]["label"] = new
        changed = True
for i, new in active.items():
    if acts[i].get("active") != new:
        acts[i]["active"] = new
        changed = True
if changed:
    json.dump(d, open(path, "w", encoding="utf-8"), indent=2, ensure_ascii=False)
    open(path, "a").write("\n")
print("changed" if changed else "same")
print(label[1])
PY
}

# Sets timer ("", "R:29m", "R:1h05m", "R:<1m") and t_wait (seconds until the label
# next changes while running; empty when idle). Minutes are rounded down:
# mins = (left - 1) / 60, so 30:00 left reads 29m.
timer_state() {
	local now left end mins
	timer="" t_wait=""
	[[ -r $TIMER_FILE ]] || return
	printf -v now '%(%s)T' -1
	end=$(<"$TIMER_FILE")
	left=$((end - now))
	if ((left > 0)); then
		mins=$(((left - 1) / 60))
		if ((mins == 0)); then
			timer="R:<1m"
		elif ((mins >= 60)); then
			printf -v timer 'R:%dh%02dm' $((mins / 60)) $((mins % 60))
		else
			timer="R:${mins}m"
		fi
		t_wait=$((left - 60 * mins))
	else
		rm -f "$TIMER_FILE"
	fi
}

# What is currently written into config.json.
a_timer="" a_sig=""
a_label=""
write_all() {
	local out
	out=$(apply "$wifi" "$wifi_on" "$bt_type" "$bt_name" "$bt_on" "$timer")
	[[ ${out%%$'\n'*} == changed ]] && swaync-client -R >/dev/null 2>&1
	a_label=${out#*$'\n'}
	a_timer=$timer a_sig=$net_sig
}

# Per-second path: only the countdown text changed, so swap it in the file with
# bash string replacement (no python / extra processes) and reload.
fast_timer_update() {
	local new content
	new="${a_label%%  *}  ${timer:2}"
	content=$(<"$CONFIG")
	[[ $content == *"$a_label"* ]] || return 1
	printf '%s\n' "${content/"$a_label"/"$new"}" >"$CONFIG"
	a_label=$new a_timer=$timer
	swaync-client -R >/dev/null 2>&1
}

cc_visible && cc_open=1
next_net=0
while true; do
	printf -v now '%(%s)T' -1
	just_opened=$opened opened=0 kick=0
	if ((just_opened || now >= next_net)); then
		refresh_net
		next_net=$((now + NET_INTERVAL))
	fi
	timer_state

	if [[ $timer != "$a_timer" ]]; then
		# Idle <-> running goes through the full writer; a changing countdown
		# only needs the label text swapped.
		if [[ -z $timer || -z $a_timer ]]; then
			write_all
		else
			fast_timer_update || write_all
		fi
	elif [[ $net_sig != "$a_sig" ]] && { ((just_opened)) || ! ((cc_open)); }; then
		write_all
	fi

	wait=$((next_net - now))
	if [[ -n $t_wait ]] && ((t_wait < wait)); then wait=$t_wait; fi
	((wait < 1)) && wait=1
	nap "$wait"
done
