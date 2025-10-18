#!/usr/bin/env bash
# ocr-clipboard.sh
# OCR image on Wayland clipboard -> copy text to clipboard + notify
# Usage: LANGS=eng ./ocr-clipboard.sh    # default eng; set LANGS="eng+jpn" etc.

set -euo pipefail
LANGS="${LANGS:-eng}"

# Find an image MIME on the clipboard
MIME=$(wl-paste -l | tr ' ' '\n' | grep -E -m1 '^image/(png|jpeg|jpg)$' || true)
if [[ -z "${MIME}" ]]; then
  notify-send -u low "OCR" "No image detected on clipboard."
  exit 1
fi

# OCR -> copy -> capture a short preview
PREVIEW=$(
  wl-paste -t "$MIME" \
  | tesseract - - -l "$LANGS" --psm 6 2>/dev/null \
  | tee >(wl-copy) \
  | head -c 280
)

[[ -t 1 && -n "$(command -v gum || true)" ]] && \
  echo "${PREVIEW:-<no text found>}" \
  | gum style --border normal --margin "1 2" --padding "1 2" --bold

notify-send -u low "OCR (clipboard → text)" "${PREVIEW:-<no text found>}"
