#!/bin/bash
# swaync "scripts" hook: runs once for every incoming notification (swaync only
# runs the first matching script, so everything per-notification lives here).
#
# 1. Log "<swaync pid> <epoch> <id>" for expire-notifications.sh. The log is in
#    $XDG_RUNTIME_DIR (tmpfs), so it disappears at logout like the notifications do.
# 2. Remember battery notification ids so battery-ac-dismiss.sh can close them
#    when AC is plugged in.

RT="${XDG_RUNTIME_DIR:-/tmp}"
LOG="$RT/swaync-notification-log"

{
	flock 9
	printf '%s %s %s\n' "$(pgrep -xo swaync)" "$(date +%s)" "$SWAYNC_ID" >>"$LOG"
} 9>"$LOG.lock"

text="${SWAYNC_SUMMARY,,} ${SWAYNC_BODY,,}"
[[ $text == *batter* ]] && echo "$SWAYNC_ID" >>"$RT/swaync-battery-ids"
exit 0
