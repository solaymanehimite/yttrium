#!/usr/bin/env bash
set -euo pipefail

wallpaper=${1:?usage: apply-wallpaper.sh <image>}

if [[ ! -f $wallpaper ]]; then
    printf 'Wallpaper does not exist: %s\n' "$wallpaper" >&2
    exit 1
fi

# Generate every application palette before the wallpaper is revealed. Matugen
# writes the files atomically enough for Alacritty's live-reload, GTK, Kvantum,
# and qt6ct to consume them without sharing a hard-coded accent colour.
matugen --config "$HOME/.config/matugen/config.toml" image "$wallpaper" \
    --mode dark \
    --source-color-index 0 \
    --quiet

awww img "$wallpaper" \
    --transition-type grow \
    --transition-pos 0.5,0.75 \
    --transition-duration 0.3

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell"
mkdir -p "$state_dir"
printf '%s\n' "$wallpaper" > "$state_dir/current-wallpaper"
