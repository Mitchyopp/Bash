#!/usr/bin/env bash

text=$(wl-paste)
translated=$(trans -brief :ja "$text")

echo "$translated" | wl-copy
notify-send "Translated!" "$translated"
