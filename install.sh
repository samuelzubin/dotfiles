#!/usr/bin/env bash
# Set up niri (plus the shell components it launches), kitty and neovim on Fedora.
# Idempotent: safe to re-run. See README.md.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP="$HOME/.dotfiles-preinstall-$(date +%Y%m%d-%H%M%S)"

# Stow packages that every machine gets.
SHARED_PKGS=(niri waybar rofi swaync wlogout hypr matugen kitty nvim bin systemd-user)
NERD_FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz"
SEED_COLOR="#6750a4" # used for matugen when there is no wallpaper yet

DRY_RUN=0
DO_SYSTEM=0
HOST=""

usage() {
  cat <<EOF
Usage: $0 [options]

  --host g14|generic      Per-machine niri config (display layout, GPU env).
                          Default: detected from DMI, 'generic' if unknown.
  --system                Also do the root-level steps (sudoers, groups, services).
  --dry-run               Print what would happen; change nothing.
  -h, --help              Show this help.
EOF
}

while (($#)); do
  case $1 in
    --host) HOST=${2:?--host needs a value}; shift 2 ;;
    --system) DO_SYSTEM=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h | --help) usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

log() { printf '\n==> %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

# Print the command; run it unless --dry-run.
run() {
  printf '+ %s\n' "$*"
  ((DRY_RUN)) || "$@"
}

[[ $EUID -ne 0 ]] || die "run as your normal user, not root (sudo is used where needed)"
[[ -r /etc/os-release ]] && grep -qi '^ID=fedora' /etc/os-release || die "this script targets Fedora"

detect_host() {
  local product=""
  [[ -r /sys/class/dmi/id/product_name ]] && product=$(</sys/class/dmi/id/product_name)
  case $product in
    *GA401* | *"Zephyrus G14"*) echo g14 ;;
    *) echo generic ;;
  esac
}
[[ -n $HOST ]] || HOST=$(detect_host)
case $HOST in
  g14 | generic) ;;
  *) die "unknown --host '$HOST' (expected g14 or generic)" ;;
esac

PKGS=("${SHARED_PKGS[@]}")
[[ $HOST == generic ]] || PKGS+=("host-$HOST")

list_file() { # print non-comment, non-empty entries of a packages/*.txt file
  sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e '/^$/d' "$DOTFILES/packages/$1"
}

echo "dotfiles: $DOTFILES"
echo "host:     $HOST"
echo "packages: ${PKGS[*]}"
((DRY_RUN)) && echo "(dry run: nothing will be changed)"

# --- 1. COPRs and packages ---------------------------------------------------
log "COPR repositories"
while IFS= read -r copr; do
  run sudo dnf copr enable -y "$copr"
done < <(list_file copr.txt)

log "dnf packages"
mapfile -t DNF_PKGS < <(list_file dnf.txt)
run sudo dnf install -y "${DNF_PKGS[@]}"

# --- 2. Fonts ----------------------------------------------------------------
log "JetBrainsMono Nerd Font"
if fc-list 2>/dev/null | grep -qi 'JetBrainsMono Nerd Font'; then
  echo "already installed"
else
  FONT_DIR="$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
  run mkdir -p "$FONT_DIR"
  if ((DRY_RUN)); then
    echo "+ curl -fL $NERD_FONT_URL | tar -xJ -C $FONT_DIR"
  else
    curl -fL "$NERD_FONT_URL" | tar -xJ -C "$FONT_DIR"
  fi
  run fc-cache -f "$FONT_DIR"
fi

# --- 3. Symlink the dotfiles with stow ---------------------------------------
# Move anything that is in the way into $BACKUP (never overwrite). --no-folding
# links individual files, so ~/.config/niri etc. stay real directories and files
# that matugen generates there never end up inside this repo.
backup_conflicts() {
  local pkg=$1 f rel target
  while IFS= read -r -d '' f; do
    rel=${f#"$DOTFILES/$pkg/"}
    target="$HOME/$rel"
    if [[ -e $target || -L $target ]]; then
      [[ $(readlink -f "$target") == "$(readlink -f "$f")" ]] && continue
      run mkdir -p "$(dirname "$BACKUP/$rel")"
      run mv "$target" "$BACKUP/$rel"
    fi
  done < <(find "$DOTFILES/$pkg" -type f -print0)
}

log "stow"
for pkg in "${PKGS[@]}"; do
  [[ -d $DOTFILES/$pkg ]] || die "missing package directory: $pkg"
  backup_conflicts "$pkg"
  run stow --no-folding --restow --dir="$DOTFILES" --target="$HOME" "$pkg"
done

# swaync's button-labels.sh rewrites config.json at runtime, so it must be a real
# file (a symlink would make it write straight into this repo).
if [[ ! -e $HOME/.config/swaync/config.json ]]; then
  run cp "$DOTFILES/swaync/.config/swaync/config.json.default" "$HOME/.config/swaync/config.json"
fi

run mkdir -p "$HOME/Pictures/Screenshots" "$HOME/Videos" "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"

# --- 4. GTK settings and user services ---------------------------------------
log "dconf and systemd user units"
if command -v dconf >/dev/null; then
  if ((DRY_RUN)); then
    echo "+ dconf load /org/gnome/desktop/interface/ < dconf/interface.ini"
  else
    dconf load /org/gnome/desktop/interface/ <"$DOTFILES/dconf/interface.ini" ||
      warn "dconf load failed (no session bus?); re-run from a desktop session"
  fi
fi
if systemctl --user show-environment >/dev/null 2>&1 || ((DRY_RUN)); then
  run systemctl --user daemon-reload
  run systemctl --user enable swayosd-server.service
  run systemctl --user link "$HOME/.config/swaync/systemd/swaync-expire.service"
  run systemctl --user enable "$HOME/.config/swaync/systemd/swaync-expire.timer"
else
  warn "no systemd user session; run these once logged in:"
  echo "  systemctl --user daemon-reload"
  echo "  systemctl --user enable swayosd-server.service"
  echo "  systemctl --user link ~/.config/swaync/systemd/swaync-expire.service"
  echo "  systemctl --user enable ~/.config/swaync/systemd/swaync-expire.timer"
fi

# --- 5. Wallpapers and generated colours -------------------------------------
WALL_DIR="$HOME/Pictures/Wallpapers"
log "wallpapers"
run mkdir -p "$WALL_DIR"
# Bundled wallpapers; never overwrites a file that is already there.
run cp -n "$DOTFILES"/wallpapers/* "$WALL_DIR/"

log "colours (matugen)"
first_image() {
  local pick=""
  [[ -d $WALL_DIR ]] || return 0
  if [[ -f $WALL_DIR/mountain.png ]]; then
    pick="$WALL_DIR/mountain.png"
  else
    pick=$(find -L "$WALL_DIR" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | sort | head -n1)
  fi
  printf '%s\n' "$pick"
}
if [[ ! -e $HOME/.config/current_wallpaper ]]; then
  WALL=$(first_image)
  if [[ -n $WALL ]]; then
    run ln -sf "$WALL" "$HOME/.config/current_wallpaper"
    run ln -sf "$WALL" "$HOME/.config/current_lockscreen"
  fi
fi
# Post-hooks reload running apps; they fail harmlessly outside a session.
if [[ -e $HOME/.config/current_wallpaper ]]; then
  run matugen image "$HOME/.config/current_wallpaper" || warn "matugen reported an error (post-hooks?)"
else
  warn "no wallpaper found in $WALL_DIR; generating colours from seed $SEED_COLOR instead"
  warn "add wallpapers there and run: wallselect"
  run matugen color hex "$SEED_COLOR" || warn "matugen reported an error (post-hooks?)"
fi

# --- 6. Optional root-level steps --------------------------------------------
if ((DO_SYSTEM)); then
  log "system (sudo)"
  # Lets waybar's power-profile script run `sudo tuned-adm` without a prompt.
  tmp_sudoers=$(mktemp)
  sed "s/@USER@/$USER/" "$DOTFILES/system/sudoers.d/niri-tuned-adm.in" >"$tmp_sudoers"
  if ((DRY_RUN)); then
    echo "+ visudo -cf $tmp_sudoers && install -m 0440 ... /etc/sudoers.d/niri-tuned-adm"
  else
    sudo visudo -cf "$tmp_sudoers"
    sudo install -m 0440 -o root -g root "$tmp_sudoers" /etc/sudoers.d/niri-tuned-adm
  fi
  rm -f "$tmp_sudoers"
  run sudo usermod -aG video "$USER" # brightnessctl
  run sudo systemctl enable --now tuned.service
fi

# --- done --------------------------------------------------------------------
log "done"
if [[ -d $BACKUP ]]; then
  echo "Files that were in the way were moved to: $BACKUP"
fi
cat <<EOF
Manual steps this script does not do:
  - restore ~/.ssh (keys are never stored in this repo)
  - log out, then pick the "niri" session at the GDM login screen
  - (re)join Wi-Fi; networks are not stored here
EOF
((DO_SYSTEM)) || echo "  - re-run with --system for the sudoers rule and the 'video' group (brightness keys)"
