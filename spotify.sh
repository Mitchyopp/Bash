#!/bin/bash

status=$(playerctl --player=spotify status 2>/dev/null)

if [ "$status" = "Playing" ] || [ "$status" = "Paused" ]; then
    artist=$(playerctl --player=spotify metadata artist)
    title=$(playerctl --player=spotify metadata title)
    album=$(playerctl --player=spotify metadata album)

    notify-send -i spotify "🎵 $title" "Artist: $artist\nAlbum: $album"
fi
