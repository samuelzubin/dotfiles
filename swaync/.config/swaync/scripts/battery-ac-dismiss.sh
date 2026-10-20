#!/bin/bash
# Dismisses battery notifications when plugged in

AC_DEVICE=/org/freedesktop/UPower/devices/line_power_AC0
IDS_FILE="$XDG_RUNTIME_DIR/swaync-battery-ids"

ac_online() {
	upower -i "$AC_DEVICE" 2>/dev/null | grep -oP 'online:\s*\K\w+'
}

was_online=$(ac_online)

upower --monitor | while read -r _; do
	now_online=$(ac_online)
	if [[ "$now_online" == yes && "$was_online" != yes && -s "$IDS_FILE" ]]; then
		while read -r id; do
			[[ -n "$id" ]] && gdbus call --session \
				--dest org.erikreider.swaync.cc \
				--object-path /org/erikreider/swaync/cc \
				--method org.erikreider.swaync.cc.CloseNotification "$id" \
				>/dev/null 2>&1
		done <"$IDS_FILE"
		: >"$IDS_FILE"
	fi
	was_online="$now_online"
done
