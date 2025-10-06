#!/usr/bin/env bash
set -Eeuo pipefail

# --- config ---------------------------------------------------------------
FLAKE="${1:-$HOME/nixdots#nixos}"              # ./rebuild.sh ~/nixdots#host
DOTFILES="${DOTFILES:-/home/Mitchy/Scripts/dotfiles.sh}"

# Flags:
#   -m|--message "msg"   Commit message for the flake repo before build
#   --push               Also push after committing
#   --no-dotfiles        Skip dotfiles sync step
#   --no-diff            Skip nvd diff even if installed
COMMIT_MSG=""
DO_PUSH=false
RUN_DOTFILES=true
RUN_DIFF=true

shift $(( $# >= 1 ? 1 : 0 )) || true
while (($#)); do
  case "$1" in
    -m|--message) COMMIT_MSG="${2:-}"; shift 2;;
    --push)       DO_PUSH=true; shift;;
    --no-dotfiles)RUN_DOTFILES=false; shift;;
    --no-diff)    RUN_DIFF=false; shift;;
    --) shift; break;;
    *) echo "Unknown arg: $1" >&2; exit 2;;
  esac
done

# --- logging (mirror EVERYTHING to log + stdout) --------------------------
LOG_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/rebuild"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/$(date -Iseconds)-rebuild.log"
# From here on, all stdout+stderr goes to both terminal and log.
exec > >(tee -a "$LOG_FILE") 2>&1

notify() {
  # $1: body, $2: urgency (low|normal|critical), $3: title override
  local body="${1:-}"
  local urg="${2:-normal}"
  local title="${3:-NixOS Rebuild}"
  command -v notify-send >/dev/null 2>&1 && notify-send --urgency="$urg" "$title" "$body" || true
}

section() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }

die() { notify "❌ $*" critical; echo "ERROR: $*" >&2; exit 1; }

# Pre-flight
sudo -v || die "sudo auth failed"

section "Starting build for $FLAKE"
notify "📦 Building system…\n$FLAKE" normal "NixOS Rebuild"
START="$(date +%s)"

# --- optional commit/push of the flake repo ------------------------------
# If FLAKE looks like /path#host, grab /path and commit there.
FLAKE_DIR="${FLAKE%%#*}"
if [[ -n "${COMMIT_MSG}" && -d "$FLAKE_DIR/.git" ]]; then
  section "Committing flake repo: $FLAKE_DIR"
  git -C "$FLAKE_DIR" add -A
  if git -C "$FLAKE_DIR" commit -m "$COMMIT_MSG"; then
    echo "Committed: $COMMIT_MSG"
    if $DO_PUSH; then
      git -C "$FLAKE_DIR" push
      echo "Pushed to remote."
    fi
  else
    echo "Nothing to commit."
  fi
fi

# --- build (no activation) ------------------------------------------------
# Keeps ./result symlink on success.
if ! nixos-rebuild build --flake "$FLAKE" --keep-going --show-trace; then
  notify "❌ Build failed. See log:\n$LOG_FILE" critical
  exit 1
fi

NEW_PATH="$(readlink -f ./result)"
CURRENT="/run/current-system"
section "Build completed: $NEW_PATH"

# --- diff (optional) ------------------------------------------------------
if $RUN_DIFF && command -v nvd >/dev/null 2>&1; then
  section "Diff (current vs new)"
  if ! nvd diff "$CURRENT" "$NEW_PATH"; then
    echo "nvd diff failed (non-fatal)"
  fi
else
  [[ $RUN_DIFF == true ]] && echo "(tip) Install 'nvd' for diffs: nix run nixpkgs#nvd -- …"
fi

# --- short-circuit if nothing changed ------------------------------------
if [[ "$CURRENT" == "$NEW_PATH" ]]; then
  section "No changes detected; skipping switch"
  notify "✅ Up to date. No activation needed." normal
  echo "Log saved to: $LOG_FILE"
  exit 0
fi

# --- rollback trap --------------------------------------------------------
rollback() {
  local code=$?
  if (( code != 0 )); then
    section "Activation failed (exit $code). Rolling back…"
    notify "⚠️ Activation failed. Rolling back…" critical
    sudo nix-env -p /nix/var/nix/profiles/system --set "$CURRENT"
    sudo "$CURRENT"/bin/switch-to-configuration switch || true
    notify "↩️ Rolled back to previous system." critical
  fi
  exit $code
}
trap rollback ERR

# --- switch ---------------------------------------------------------------
section "Switching profile to built system"
sudo nix-env -p /nix/var/nix/profiles/system --set "$NEW_PATH"

section "Running switch-to-configuration"
sudo "$NEW_PATH"/bin/switch-to-configuration switch

# Success — clear trap
trap - ERR

DUR=$(( $(date +%s) - START ))
section "Activation complete in ${DUR}s"

# --- post steps -----------------------------------------------------------
if $RUN_DOTFILES && [[ -x "$DOTFILES" ]]; then
  section "Syncing dotfiles: $DOTFILES"
  if "$DOTFILES"; then
    notify "✅ Rebuild + dotfiles synced in ${DUR}s" normal
  else
    notify "✅ Rebuild OK, but dotfiles sync failed. Check $LOG_FILE" critical
  fi
else
  notify "✅ Rebuild OK in ${DUR}s\n(dotfiles step skipped or not executable)" normal
fi

echo "Log saved to: $LOG_FILE"
