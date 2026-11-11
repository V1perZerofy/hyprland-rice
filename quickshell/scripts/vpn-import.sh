#!/usr/bin/env bash
# Import an .ovpn file into NetworkManager as a persistent profile
# (autoconnect off). If the config uses auth-user-pass and an auth file is
# given (line 1: user, line 2: password — like ~/auth.txt), the credentials are
# stored in the profile so connecting doesn't prompt. NetworkManager keeps them
# in /etc/NetworkManager/system-connections/ (root-only).
#
# usage: vpn-import.sh <file.ovpn> [auth file]
# Undo:  nmcli connection delete <name>
set -euo pipefail

file=$1
auth=${2:-}

out=$(nmcli connection import type openvpn file "$file")
uuid=$(grep -oE '[0-9a-f]{8}-[0-9a-f-]{27}' <<<"$out")
nmcli connection modify "$uuid" connection.autoconnect no

if [[ -n $auth && -r $auth ]] && grep -qE '^[[:space:]]*auth-user-pass' "$file"; then
	{ IFS= read -r user; IFS= read -r pass; } <"$auth"
	nmcli connection modify "$uuid" vpn.user-name "$user" +vpn.data password-flags=0 vpn.secrets "password=$pass"
fi

echo "$out"
