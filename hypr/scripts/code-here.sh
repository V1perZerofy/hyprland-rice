#!/usr/bin/env bash
# Open VSCode. If the focused window is a terminal, open it in the working
# directory of the shell running inside that terminal's *focused* window.
# Otherwise just launch VSCode normally.
#
# Bound to SUPER + X in hyprland.lua.
#
# Note: kitty runs all its windows under a single process, so hyprctl's
# activewindow PID is shared and can't tell us which window is focused. We ask
# kitty directly via its remote-control socket (requires `allow_remote_control
# yes` + `listen_on unix:/tmp/kitty` in kitty.conf). Other terminals spawn one
# process per window, so the /proc process-tree walk works for them.

set -euo pipefail

# Terminal window classes we know about (lower-cased, anchored match).
TERMINAL_CLASSES="kitty|foot|alacritty|wezterm|org.wezfurlong.wezterm|com.mitchellh.ghostty|xterm|st-256color|konsole"

active="$(hyprctl activewindow -j 2>/dev/null || true)"
pid="$(printf '%s' "$active" | jq -r '.pid // empty')"
class="$(printf '%s' "$active" | jq -r '(.class // "") | ascii_downcase')"

# --- kitty: ask kitty which window is focused and use its cwd ----------------
kitty_focused_cwd() {
	local sock cwd
	for sock in /tmp/kitty /tmp/kitty-*; do
		[ -S "$sock" ] || continue
		cwd="$(kitty @ --to "unix:$sock" ls 2>/dev/null \
			| jq -r 'first(.[].tabs[].windows[] | select(.is_focused == true) | .cwd) // empty')"
		[ -n "$cwd" ] && { printf '%s' "$cwd"; return 0; }
	done
	return 1
}

# --- other terminals: walk to the deepest descendant and read its cwd --------
leaf_cwd() {
	local p="$1" child
	while true; do
		child="$(pgrep -P "$p" 2>/dev/null | tail -n1 || true)"
		[ -z "$child" ] && break
		p="$child"
	done
	readlink -f "/proc/$p/cwd" 2>/dev/null || true
}

dir=""
if [ -n "$pid" ] && printf '%s' "$class" | grep -qE "^(${TERMINAL_CLASSES})$"; then
	if [ "$class" = "kitty" ]; then
		dir="$(kitty_focused_cwd || true)"
	else
		dir="$(leaf_cwd "$pid")"
	fi
fi

if [ -n "$dir" ] && [ -d "$dir" ]; then
	exec code "$dir"
fi

exec code
