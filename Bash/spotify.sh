#!/bin/bash

artist=$(playerctl metadata artist)
title=$(playerctl metadata title)
album=$(playerctl metadata album)
sstatus=$(playerctl status)


notify-send "Now playing" "$artist - $title - $album - $sstatus"
