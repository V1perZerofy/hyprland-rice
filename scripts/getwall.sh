#!/usr/bin/env bash

string=$(awww query)

IFS=':' read -ra array <<<"$string"

echo "\$wallpaper = $(echo "${array[-1]}" | xargs)" >~/.config/scripts/wal.conf
