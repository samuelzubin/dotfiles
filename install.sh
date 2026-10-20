#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"
PKGS=(niri waybar rofi swaync wlogout hypr matugen kitty nvim bin systemd-user)
WALL_DIR="$HOME/Pictures/Wallpapers"

list() { sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e '/^$/d' "packages/$1"; }

# Packages and font
list copr.txt | while read -r copr; do sudo dnf copr enable -y "$copr"; done
sudo dnf install -y $(list dnf.txt)
if ! fc-list | grep -qi 'JetBrainsMono Nerd Font'; then
  mkdir -p ~/.local/share/fonts/JetBrainsMonoNerdFont
  curl -fL https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz |
    tar -xJ -C ~/.local/share/fonts/JetBrainsMonoNerdFont
  fc-cache -f
fi

# Symlink configs (stops if a real file is in the way; move it and re-run)
stow --no-folding --restow --target="$HOME" "${PKGS[@]}"

# swaync rewrites config.json at runtime, so it has to be a real file
[[ -e ~/.config/swaync/config.json ]] || cp swaync/.config/swaync/config.json.default ~/.config/swaync/config.json

# GTK settings and user services
mkdir -p ~/Pictures/Screenshots ~/Videos
dconf load /org/gnome/desktop/interface/ <dconf/interface.ini
systemctl --user daemon-reload
systemctl --user enable swayosd-server.service
systemctl --user link ~/.config/swaync/systemd/swaync-expire.service
systemctl --user enable ~/.config/swaync/systemd/swaync-expire.timer

# Wallpaper and generated colors
mkdir -p "$WALL_DIR"
cp -n wallpapers/* "$WALL_DIR/"
ln -sf "$WALL_DIR/mountain.png" ~/.config/current_wallpaper
ln -sf "$WALL_DIR/mountain.png" ~/.config/current_lockscreen
matugen image ~/.config/current_wallpaper || echo "matugen failed; run 'wallselect' from the niri session"

# Root-level: passwordless tuned-adm for waybar, brightness keys, power profiles
sed "s/@USER@/$USER/" system/sudoers.d/niri-tuned-adm.in >/tmp/niri-tuned-adm
sudo visudo -cf /tmp/niri-tuned-adm
sudo install -m 0440 -o root -g root /tmp/niri-tuned-adm /etc/sudoers.d/niri-tuned-adm
rm -f /tmp/niri-tuned-adm
sudo usermod -aG video "$USER"
sudo systemctl enable --now tuned.service
