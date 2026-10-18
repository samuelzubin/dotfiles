#!/bin/bash
# Closes control-center notifications older than MAX_AGE (default 24h).
# Run hourly by systemd/swaync-expire.timer; it does nothing between runs.
# Ages come from the log notification-hook.sh writes. A notification that is
# replaced (same id) counts from its latest update. Records from an earlier
# swaync process are dropped, since ids restart when swaync does.

MAX_AGE="${SWAYNC_EXPIRE_SECS:-86400}"
RT="${XDG_RUNTIME_DIR:-/tmp}"
LOG="$RT/swaync-notification-log"

pid=$(pgrep -xo swaync) || exit 0
[[ -s $LOG ]] || exit 0
printf -v now '%(%s)T' -1

{
	flock 9
	keep=$(mktemp "$RT/swaync-expire.XXXXXX")
	expired=()
	# latest timestamp per id, current swaync process only
	while read -r id t; do
		if ((now - t >= MAX_AGE)); then
			expired+=("$id")
		else
			echo "$pid $t $id" >>"$keep"
		fi
	done < <(awk -v pid="$pid" '$1 == pid { t[$3] = $2 } END { for (i in t) print i, t[i] }' "$LOG")
	mv "$keep" "$LOG"
} 9>"$LOG.lock"

for id in "${expired[@]}"; do
	gdbus call --session --dest org.erikreider.swaync.cc \
		--object-path /org/erikreider/swaync/cc \
		--method org.erikreider.swaync.cc.CloseNotification "$id" >/dev/null 2>&1
done
