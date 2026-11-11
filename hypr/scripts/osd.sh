#!/usr/bin/env bash
# On-screen display for volume / mic / brightness. Changes the value, then
# asks the Quickshell bar to show its OSD (~/.config/quickshell/Osd.qml).
# The OSD reads volume/mic live from PipeWire; brightness is passed along.
#
# Usage: osd.sh vol-up | vol-down | vol-mute | mic-mute | bright-up | bright-down
# Bound to the XF86 media keys in hyprland.lua.

set -uo pipefail

STEP=5

osd() { qs ipc call osd "$@" >/dev/null 2>&1; }

brightness_pct() { # brightnessctl -m: device,class,current,percent%,max
	brightnessctl -m | awk -F, '{ gsub("%", "", $4); print $4; exit }'
}

case "${1:-}" in
vol-up)
	wpctl set-mute @DEFAULT_AUDIO_SINK@ 0
	wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ "${STEP}%+"
	osd volume
	;;
vol-down)
	wpctl set-volume @DEFAULT_AUDIO_SINK@ "${STEP}%-"
	osd volume
	;;
vol-mute)
	wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
	osd volume
	;;
mic-mute)
	wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
	osd mic
	;;
bright-up)
	brightnessctl -e4 -n2 set "${STEP}%+" >/dev/null
	osd brightness "$(brightness_pct)"
	;;
bright-down)
	brightnessctl -e4 -n2 set "${STEP}%-" >/dev/null
	osd brightness "$(brightness_pct)"
	;;
*)
	echo "usage: $0 vol-up|vol-down|vol-mute|mic-mute|bright-up|bright-down" >&2
	exit 2
	;;
esac
