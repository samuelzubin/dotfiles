# dotfiles

Here are my dotfiles for fedora + niri.

## Try it out for yourself:

1. Clone the repo:
   ```sh
   git clone git@github.com:samuelzubin/dotfiles.git ~/dotfiles
   cd ~/dotfiles
   ```

2. If your device is not a G14 (or if you don't know what G14 means), run this first:
	```sh
	rm ~/dotfiles/niri/.config/niri/hardware.kdl
	```
	These are settings for my device.

3. Run `./install.sh`. It installs the packages and runs stow for you. Needs `git` and GNU `stow` (`sudo dnf install git stow`).

   To only symlink the configs, run this from `~/dotfiles`:
   ```sh
   stow --no-folding --restow --target="$HOME" niri waybar rofi swaync wlogout hypr matugen kitty nvim bin systemd-user
   ```

4. Log out and pick **niri** on the login screen.

If that worked, great! If not, I don't know what to tell you.

Press Mod+Shift+/ to see keybinds