#!/bin/bash

config="/tmp/waybar_cava_$$"
cat > "$config" <<EOF
[general]
framerate = 8
bars = 8
autosens = 1
[input]
method = pulse
source = auto
[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 7
EOF

cleanup() {
  pkill -f "cava -p $config" 2>/dev/null
  rm -f "$config"
}
trap cleanup EXIT

stdbuf -oL cava -p "$config" | awk '
BEGIN {
  bar       = "▁▂▃▄▅▆▇█"
  counter   = 0
  vol_text  = "󰖁 0%"
  song_text = "No media playing"
}
{
  # Build bar visualisation from semicolon-delimited digits 0-7
  n   = split($0, a, ";")
  vis = ""
  for (i = 1; i <= n; i++)
    if (a[i] ~ /^[0-7]$/)
      vis = vis substr(bar, a[i] + 1, 1)

  # Poll vol + song once per second (every 8 frames at 8 fps)
  if (counter % 8 == 0) {

    # Volume via PipeWire
    vcmd = "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null"
    if ((vcmd | getline vraw) > 0) {
      if (vraw ~ /MUTED/) {
        vol_text = "󰖁 Muted"
      } else {
        match(vraw, /[0-9]+\.[0-9]+/)
        v    = int(substr(vraw, RSTART, RLENGTH) * 100)
        icon = (v == 0) ? "󰖁" : (v < 25) ? "󰕿" : (v < 50) ? "󰖀" : "󰕾"
        vol_text = icon " " v "%"
      }
    }
    close(vcmd)

    # Current song via playerctl
    scmd = "playerctl metadata --format \"{{artist}} - {{title}}\" 2>/dev/null"
    if ((scmd | getline song) > 0 && song !~ /^[[:space:]]*-?[[:space:]]*$/) {
      gsub(/\\/, "\\\\", song)   # backslash first
      gsub(/"/, "\\\"",  song)   # then quotes
      song_text = song
    } else {
      song_text = "No media playing"
    }
    close(scmd)
  }

  counter++
  printf "{\"text\":\"%s  %s\",\"tooltip\":\"%s\"}\n", vol_text, vis, song_text
  fflush()
}
'
