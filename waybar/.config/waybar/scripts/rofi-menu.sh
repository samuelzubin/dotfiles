# Shared look/helpers for the rofi menus opened from waybar blocks
# (wifi-menu, bluetooth-menu). Source it; don't run it.

# Clicking the block again closes whatever menu is open.
pkill -x rofi && exit 0

# Smaller, anchored under the right side of the bar; colors come from the
# regular rofi theme (matugen-generated).
THEME='
window { width: 420px; location: north east; anchor: north east; x-offset: -12px; y-offset: 52px; padding: 18px; }
configuration { font: "JetBrainsMono NF 13"; }
listview { lines: 9; }
element { children: [ element-text ]; }
'

# menu PROMPT [rofi args...] — reads rows on stdin, prints the chosen index.
menu() { rofi -dmenu -i -format i -p "$1" -theme-str "$THEME" "${@:2}"; }

notify() { notify-send -a "$MENU_APP" "$@"; }
