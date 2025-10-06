#!/usr/bin/env bash
# Wayland + PipeWire startup (quiet & reliable)
set -euo pipefail

# ---------- config ----------
BT_MAC="00:A4:1C:40:CA:57"
TARGET_VOL="0.60"      # 60%
MAX_WAIT=15            # seconds
DOTFILES_SCRIPT="$HOME/Scripts/dotfiles.sh"
SEND_NOTIFS=true       # set false to go fully quiet
# ----------------------------

# --- helpers ---------------------------------------------------------------
have() { command -v "$1" >/dev/null 2>&1; }

notify() {
  $SEND_NOTIFS || return 0
  have notify-send || return 0
  # Replace previous toast instead of spamming
  notify-send -a "Startup" \
    --hint=string:x-canonical-private-synchronous:startup \
    "$@"
}

log() { printf '[%(%H:%M:%S)T] %s\n' -1 "$*"; }
banner() { log "$*"; notify "$*"; }

retry() { # retry <tries> <sleep_s> <command...>
  local tries="$1"; shift
  local sleep_s="$1"; shift
  local i
  for ((i=1;i<=tries;i++)); do
    if "$@"; then return 0; fi
    sleep "$sleep_s"
  done
  return 1
}

# --- start ---------------------------------------------------------------
banner "Welcome back ミッチー 🌸"

# Wait for PipeWire to be usable (non-fatal if it isn't)
if have wpctl; then
  retry "$MAX_WAIT" 1 wpctl status >/dev/null 2>&1 || \
    log "wpctl not ready yet; proceeding without it."
fi

# --- Bluetooth: non-blocking connect + fast verify -------------------------
if have bluetoothctl; then
  # Ensure controller powered
  bluetoothctl show | grep -q "Powered: yes" || bluetoothctl power on >/dev/null 2>&1 || true

  # Trust/pair are idempotent, won't error if already set
  bluetoothctl trust "$BT_MAC"  >/dev/null 2>&1 || true
  bluetoothctl pair  "$BT_MAC"  >/dev/null 2>&1 || true

  # If not connected, kick off connect in background (no --timeout blocking)
  if ! bluetoothctl info "$BT_MAC" | grep -q 'Connected: yes'; then
    ( bluetoothctl connect "$BT_MAC" >/dev/null 2>&1 || true ) & disown
  fi

  # Poll up to MAX_WAITs; succeed early if it connects
  if retry "$MAX_WAIT" 1 bash -lc "bluetoothctl info '$BT_MAC' | grep -q 'Connected: yes'"; then
    banner "🎧 Headphones connected."
  else
    # One last nudge then re-check briefly
    ( bluetoothctl connect "$BT_MAC" >/dev/null 2>&1 || true ) & disown
    if retry 5 1 bash -lc "bluetoothctl info '$BT_MAC' | grep -q 'Connected: yes'"; then
      banner "🎧 Headphones connected (late)."
    else
      banner "⚠️  Headphones not connected."
    fi
  fi
else
  log "bluetoothctl not found; skipping BT."
fi

# --- Audio: set BT as default + volume (robust sink finder) ----------------
if have wpctl; then
  MAC_UNDERSCORED="${BT_MAC//:/_}"

  # Only look inside the "Sinks:" subsection to avoid grabbing a '0.' line.
  find_bt_sink() {
    wpctl status | awk -v mac="bluez_output."$MAC_UNDERSCORED '
      BEGIN{ in_audio=0; in_sinks=0 }
      /^Audio/      { in_audio=1; next }
      in_audio && /^Sinks:/   { in_sinks=1; next }
      in_audio && /^Sources:/ { in_sinks=0 }
      in_sinks && index($0, mac) {
        if (match($0, /^[[:space:]]*([0-9]+)\./, m)) { print m[1]; exit }
      }'
  }

  # Prefer the exact a2dp node name if present; fall back to ID search
  SINK_NAME_A2DP="bluez_output.${MAC_UNDERSCORED}.a2dp-sink"
  HAVE_NAME=$(wpctl status | grep -Fq "$SINK_NAME_A2DP" && echo yes || echo no)

  SINK_ID=""
  if [[ "$HAVE_NAME" == yes ]]; then
    # We can pass the node name directly to wpctl
    SINK_ID="$SINK_NAME_A2DP"
  else
    # Poll for numeric ID within Sinks: block
    if retry "$MAX_WAIT" 1 wpctl status >/dev/null 2>&1; then
      for _ in $(seq 1 "$MAX_WAIT"); do
        SINK_ID="$(find_bt_sink || true)"
        [[ -n "${SINK_ID:-}" && "$SINK_ID" != 0 ]] && break
        SINK_ID=""
        sleep 1
      done
    fi
  fi

  if [[ -n "${SINK_ID:-}" ]]; then
    wpctl set-default "$SINK_ID" || true
    wpctl set-volume  "$SINK_ID" "$TARGET_VOL" --limit 1.0 || true
    # Pretty print the id or name in the log
    PRETTY_ID="${SINK_ID##*.}"; [[ "$SINK_ID" =~ ^[0-9]+$ ]] && PRETTY_ID="#$SINK_ID"
    banner "🔊 Default sink → BT (${PRETTY_ID}), volume → $(awk -v v="$TARGET_VOL" 'BEGIN{printf "%.0f%%", v*100}')"
  else
    log "BT sink not visible in PipeWire yet; leaving defaults."
  fi
else
  log "wpctl not found; skipping audio setup."
fi

# --- Clipboard history watcher ---------------------------------------------
if have wl-paste && have cliphist; then
  pkill -f "wl-paste.*cliphist store" >/dev/null 2>&1 || true
  wl-paste --type text  --watch cliphist store & disown
  wl-paste --type image --watch cliphist store & disown
  log "cliphist watcher started."
else
  log "wl-paste/cliphist missing; skipping cliphist."
fi

# --- Dotfiles sync ----------------------------------------------------------
if [[ -x "$DOTFILES_SCRIPT" ]]; then
  if "$DOTFILES_SCRIPT"; then
    log "dotfiles sync complete."
  else
    banner "⚠️  dotfiles script exited non-zero."
  fi
else
  log "dotfiles script not found/executable at: $DOTFILES_SCRIPT"
fi

# --- done -------------------------------------------------------------------
banner "Startup complete ✅"
