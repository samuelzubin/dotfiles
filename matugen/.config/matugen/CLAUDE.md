# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

This is a personal config directory for [matugen](https://github.com/InioX/matugen), a Material You
color-scheme generator for Linux. It is not an application codebase — there is no build, lint, or test
tooling here. `matugen` (an external binary, installed separately) reads `config.toml`, generates a
Material You color palette from a wallpaper or seed color, and renders each configured template through
its own minijinja-based template engine, writing the result to the configured output path and then running
an optional post-hook shell command.

## Running matugen

- Regenerate all configured outputs from a wallpaper: `matugen image /path/to/wallpaper.jpg`
- Regenerate from a hex color: `matugen color hex '#RRGGBB'`
- There is no local test suite; verifying a template change means running the command above and checking
  that the rendered output file (and any post-hook side effect, e.g. restarting waybar) looks correct.

## Structure

- `config.toml` — declares each `[templates.<name>]` block: `input_path` (template source in
  `templates/`), `output_path` (where the rendered file is written, e.g. into `~/.config/<app>/`), and an
  optional `post_hook` shell command run after rendering (used to reload the consuming app: `swaync-client
  -rs`, `pkill -SIGUSR2 waybar`, `systemctl --user restart swayosd-server.service`).
- `templates/` — one template source file per consuming app (waybar, swaync, niri, rofi, swayosd; a
  fastfetch template is referenced from `~/.config/fastfetch/` outside this directory). Each file is in the
  native config format/syntax of its target app (CSS, KDL, RASI), with matugen's `{{ }}` placeholders and
  `<* *>` control blocks substituted in.

## Template syntax

Templates use minijinja syntax with two color-access patterns:

- Iterate over the whole generated palette: `<* for name, value in colors *> ... {{ name }} ...
  {{ value.default.hex }} ... <* endfor *>` (used by waybar and swaync to emit a `@define-color` line per
  color role).
- Reference a specific color role directly: `{{ colors.<role>.default.hex }}`, e.g.
  `colors.primary.default.hex`, `colors.on_surface.default.hex`, `colors.background.default.hex` (used when
  a template needs only specific roles, e.g. niri's focus-ring color or swayosd's accent color).

When adding a new template:
1. Add the source file under `templates/`.
2. Add a matching `[templates.<name>]` block to `config.toml` pointing at it, with the real output path for
   the target app and a `post_hook` if that app needs to be reloaded/restarted to pick up the new colors.
