#!/usr/bin/env bash

sleep 1.5
info=$(niri msg focused-window)
notify-send -t 15000 "Focused window info: " "$info"
