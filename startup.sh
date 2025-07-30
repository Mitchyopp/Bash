#!/usr/bin/env bash
# startup script


notify-send "Welcome back ミッチー 🌸"
sleep 10
waypaper --restore
notify-send "Wallpaper restored."
sleep 10
bluetoothctl connect 00:A4:1C:40:CA:57
notify-send "Headphones connected."
sleep 5
./dotfiles.sh
