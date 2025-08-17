#!/usr/bin/env bash
latest_old=$(find "$HOME/Pictures/screenshots" -type f -printf '%T@ %p\n' | sort -nr | head -n1 | cut -d' ' -f1)

niri msg action screenshot
while true; do
    latest_new=$(find "$HOME/Pictures/screenshots" -type f -printf '%T@ %p\n' | sort -nr | head -n1 | cut -d' ' -f1)
    [[ "$latest_new" != "$latest_old" ]] && break
    sleep 0.1
done
latest_file=$(find "$HOME/Pictures/screenshots" -type f -printf '%T@ %p\n' | sort -nr | head -n1 | cut -d' ' -f2-)
wl-copy < "$latest_file"
satty -f "$latest_file"
