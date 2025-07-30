#!/usr/bin/env bash

set -e # Fail early on errors

if [[ -n $(git status --porcelain) ]]; then
    notify-send "📝 Syncing dotfiles to Git..."
    git add .
    git commit -m "Automatic dotfile upload on $(date '+%Y-%m-%d %H:%M:%S')"
    git push origin main
    notify-send "✅ Dotfiles uploaded successfully."
else
    notify-send "📂 No changes in dotfiles — nothing to upload."
fi
