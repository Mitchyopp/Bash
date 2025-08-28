#!/usr/bin/env bash
shots="$HOME/Pictures/screenshots"
mkdir -p "$shots"
niri msg action screenshot
latest_file=$(find "$shots" -type f -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n1 | cut -d' ' -f2-)
echo "Latest: $latest_file"
out="$shots/satty_$(date +'%Y-%m-%d_%H-%M-%S').png"
echo "Output: $out"
satty -f "$latest_file" -o "$out"
