#!/usr/bin/env bash

DIR="$HOME/Videos"
LOG="${XDG_RUNTIME_DIR:-/tmp}/screen-record.log"

# Check waybar status
if [ "$1" = "status" ]; then
  if pgrep -x wf-recorder >/dev/null; then
    echo '{"text": " ", "tooltip": "Recording in progress (Click to stop)", "class": "recording"}'
  else
    echo '{"text": " ", "tooltip": "", "class": "stopped"}'
  fi
  exit 0
fi

# Toggle recording
if pgrep -x wf-recorder >/dev/null; then
  # SIGTERM instead of SIGINT. Background processes ignore SIGINT.
  pkill -TERM -x wf-recorder

  # Wait for the process to finish saving the file (5s)
  COUNT=0
  while pgrep -x wf-recorder >/dev/null && [ "$COUNT" -lt 50 ]; do
    sleep 0.1
    COUNT=$((COUNT + 1))
  done

  notify-send -a "Screen Recording" "Recording stopped"
else
  # Start the recording
  mkdir -p "$DIR"
  FILE="$DIR/recording-$(date +%F-%H%M%S).mkv"

  # Hardware H.264 encode on an AMD GPU (VA-API via the freeworld Mesa driver),
  # with zero-copy DMA-BUF capture. Find the amdgpu render node by driver name
  # because the renderD number can change; wf-recorder needs the real node path
  # (a by-path symlink makes it disable DMA-BUF and fail).
  # With no AMD GPU, or if hardware encoding fails to start, fall back to
  # software (libopenh264).
  AMD_RENDER=""
  for node in /sys/class/drm/renderD*; do
    if [ "$(basename "$(readlink -f "$node/device/driver" 2>/dev/null)")" = amdgpu ]; then
      AMD_RENDER="/dev/dri/$(basename "$node")"
      break
    fi
  done
  [ -n "$AMD_RENDER" ] && export LIBVA_DRIVER_NAME=radeonsi

  start_recorder() {
    wf-recorder "$@" -f "$FILE" >>"$LOG" 2>&1 &
    sleep 0.5
    pgrep -x wf-recorder >/dev/null
  }

  : >"$LOG"
  if [ -c "$AMD_RENDER" ] && start_recorder \
    --codec h264_vaapi \
    --device "$AMD_RENDER" \
    -p b=12M \
    -r 60; then
    :
  else
    rm -f "$FILE"
    echo "--- hardware encode failed, falling back to libopenh264 ---" >>"$LOG"
    start_recorder \
      --codec libopenh264 \
      -p b=12M \
      -r 60
  fi

  # If neither encoder started, say so instead of failing silently
  if ! pgrep -x wf-recorder >/dev/null; then
    notify-send -u critical -a "Screen Recording" "Recording failed to start" "$(tail -n 3 "$LOG")"
  fi
fi

# Refresh waybar
# Send signal 6 to Waybar to instantly update the indicator
pkill -RTMIN+6 waybar
