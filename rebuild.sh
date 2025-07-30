#!/usr/bin/env bash

notify-send "📦 Rebuilding NixOS..."
if sudo nixos-rebuild switch; then
    /home/Mitchy/Scripts/dotfiles.sh
else
    notify-send "❌ Rebuild failed. Dotfiles not synced."
fi
