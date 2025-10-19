#!/usr/bin/env bash
set -Eeuo pipefail

# deps: gpu-screen-recorder, gum (and slurp if you want region on Wayland)
OUT_DIR="${OUT_DIR:-$HOME/Media/videos/}"
REPLAYS_DIR="${REPLAYS_DIR:-$HOME/Media/videos/replays/}"
mkdir -p "$OUT_DIR" "$REPLAYS_DIR"

have() { command -v "$1" &>/dev/null; }
for d in gpu-screen-recorder gum; do have "$d" || { echo "Missing dep: $d"; exit 1; }; done

title() { gum style --border rounded --margin "1 0" --padding "0 1" --border-foreground 212 "$@"; }

# --- Source selection -------------------------------------------------------
title "🎥 Select capture source"
sources_raw="$(gpu-screen-recorder --list-capture-options || true)"

# Build list: common choices first
mapfile -t base <<<"$(printf "%s\n" portal screen focused)"
mapfile -t mons <<<"$(printf "%s\n" "$sources_raw" | awk -F'|' '/\|/ {print $1}')"
choices=("${base[@]}" "${mons[@]}")

SRC="$(printf "%s\n" "${choices[@]}" \
  | gum choose --no-limit=false --header "Pick one" --cursor "🌸 " --height 12)"

# region mode (optional)
REGION_ARGS=()
if [[ "${SRC}" == "region" ]]; then
  if have slurp; then
    sel="$(slurp -f "%wx%h+%x+%y")"
    REGION_ARGS=(-region "$sel")
  else
    echo "region selected but 'slurp' not found. Install slurp or pick another source."
    exit 1
  fi
fi

# --- Recording mode ---------------------------------------------------------
title "⏺  Mode"
MODE="$(printf "Regular\nReplay\n" | gum choose --header "Choose mode")"

FPS="$(gum input --placeholder "60" --value "60" --prompt "FPS > " || true)"
FPS="${FPS:-60}"

# bit-rate/quality mode (leave auto/qp alone; mkv container is sensible)
CONTAINER="$(printf "mkv\nmp4\nwebm\n" | gum choose --header "Container (mkv recommended)")"

# --- Audio selection --------------------------------------------------------
title "🔊 Audio tracks"
printf "Default: speakers + mic will be included.\n\n"
EXTRA_AUDIO=()
if gum confirm "Add extra audio devices or per-app audio?"; then
  devs="$(gpu-screen-recorder --list-audio-devices || true)"
  apps="$(gpu-screen-recorder --list-application-audio || true)"
  list=""
  [[ -n "$devs" ]] && list+=$(printf "%s\n" "$devs" | sed 's/|.*$//')$'\n'
  [[ -n "$apps" ]] && list+=$(printf "%s\n" "$apps" | sed 's/^/app:/')
  if [[ -n "$list" ]]; then
    mapfile -t pick <<<"$(printf "%s\n" "$list" | gum choose --no-limit --header "Select any (Esc to skip)" --height 12 || true)"
    # join picks with | into one extra track
    if ((${#pick[@]})); then
      EXTRA_AUDIO=(-a "$(IFS='|'; echo "${pick[*]}")")
    fi
  fi
fi

# --- Filename (only for Regular mode) --------------------------------------
ts="$(date +'%Y-%m-%d_%H-%M-%S')"
DEF_NAME="rec_${ts}.${CONTAINER}"
if [[ "$MODE" == "Regular" ]]; then
  title "💾 Output filename"
  NAME="$(gum input --placeholder "$DEF_NAME" --value "$DEF_NAME" --prompt "File > " || true)"
  NAME="${NAME:-$DEF_NAME}"
  OUT_PATH="$OUT_DIR/$NAME"
else
  OUT_PATH="$REPLAYS_DIR" # in replay mode, -o and -ro must be directories
fi

# --- Build base command -----------------------------------------------------
cmd=(gpu-screen-recorder
  -w "$SRC"
  "${REGION_ARGS[@]}"
  -f "$FPS"
  -a "default_output|default_input"
  "${EXTRA_AUDIO[@]}"
  -c "$CONTAINER"
)

# Wayland portal “remember last pick”
if [[ "$SRC" == "portal" ]]; then
  cmd+=(-restore-portal-session yes)
fi

# Mode-specific flags
if [[ "$MODE" == "Regular" ]]; then
  cmd+=(-o "$OUT_PATH")
else
  # Replay
  title "⏱  Replay buffer seconds"
  RSECS="$(gum input --placeholder "120" --value "120" --prompt "Seconds > " || true)"
  RSECS="${RSECS:-120}"
  cmd+=(-r "$RSECS" -ro "$REPLAYS_DIR" -o "$REPLAYS_DIR")
fi

# --- Confirm & run ----------------------------------------------------------
title "Command preview"
printf "%q " "${cmd[@]}"; echo
echo
gum confirm "Start recording?" || { echo "Aborted."; exit 0; }

echo "Starting…"
"${cmd[@]}"
