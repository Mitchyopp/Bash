#!/usr/bin/env bash

text=$(wl-paste)
trans :ja "$text" | wl-copy
notify-send "Translated to japanese." "$(wl-paste)"

