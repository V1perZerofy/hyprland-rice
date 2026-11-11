#!/usr/bin/env bash
cordX=$((1 + RANDOM % 100))
cordY=$((1 + RANDOM % 100))

IMG="$1"

if [[ -z "$IMG" ]]; then
  notify-send "No image provided"
  exit 1
fi

awww img --transition-type outer --transition-pos 0.${cordX},0.${cordY} --transition-step 90 --transition-fps 120 $1
sleep 0.5
# colorz gives up on near-greyscale images; fall back to wal's default backend
wal --backend colorz -i "$IMG" || wal -i "$IMG"
pywalfox update
# Quickshell recolours itself from ~/.cache/wal/colors.json (no reload needed)
# Re-read the freshly generated ~/.cache/wal/colors into Hyprland so window
# borders pick up the new palette (hyprland.lua reads that file on reload).
hyprctl reload
"$HOME/.config/scripts/getwall.sh" &
