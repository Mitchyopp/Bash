#!/usr/bin/env bash
# ocr-select.sh
# Select region via slurp -> grim streams PNG -> tesseract -> copy + notify
# Usage: LANGS=eng ./ocr-select.sh       # or LANGS="eng+jpn"

set -euo pipefail
LANGS="${LANGS:-eng}"

# Region select (cancels cleanly if you hit Esc)
GEOM=$(slurp -d || true)
if [[ -z "${GEOM}" ]]; then
  notify-send -u low "OCR" "Selection canceled."
  exit 0
fi

PREVIEW=$(
  grim -g "$GEOM" - \
  | tesseract - - -l "$LANGS" --psm 6 2>/dev/null \
  | tee >(wl-copy) \
  | head -c 280
)

[[ -t 1 && -n "$(command -v gum || true)" ]] && \
  echo "${PREVIEW:-<no text found>}" \
  | gum style --border normal --margin "1 2" --padding "1 2" --bold

notify-send -u low "OCR (selection → text)" "${PREVIEW:-<no text found>}"
