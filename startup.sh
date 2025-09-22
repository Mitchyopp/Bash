#!/usr/bin/env bash
# startup script

notify-send "Welcome back ミッチー 🌸"
# waypaper --restore
# notify-send "Wallpaper restored."
# wal -R
sleep 1
bluetoothctl connect 00:A4:1C:40:CA:57
notify-send "Headphones connected."

TARGET_SINK="bluez_output.00_A4_1C_40_CA_57.1"
for i in {1..15}; do
    DEFAULT_SINK=$(pactl get-default-sink)
    if [[ "$DEFAULT_SINK" == "$TARGET_SINK" ]]; then
        pactl set-sink-volume "$DEFAULT_SINK" 60%
        notify-send "Volume set to 60%"
        break
    fi
    sleep 1
done

wl-paste --watch cliphist store &
pkill mako
sleep 3
./dotfiles.sh
