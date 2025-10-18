#!/usr/bin/env bash
# Glam NixOS rebuild helper (flake) with gum — full output, commit & optional push.
# - Streams full nixos-rebuild output (and logs it)
# - Pretty gum headers
# - Color diff
# - Confirm commit -> optional custom message -> optional push

set -Eeuo pipefail

# --- CONFIG -------------------------------------------------------------------
REPO_DIR="$HOME/nixdots"
FLAKE_ATTR="nixos"                         # nixos-rebuild --flake "$REPO_DIR#$FLAKE_ATTR"
LOG_FILE="$REPO_DIR/nixos-switch.log"
DEFAULT_MSG_PREFIX="Rebuild OK"
# ------------------------------------------------------------------------------

# --- Flags --------------------------------------------------------------------
AUTO_YES=false   # -y to auto-confirm commit (still asks to push)
while [[ $# -gt 0 ]]; do
  case "$1" in
    -y|--yes)   AUTO_YES=true; shift ;;
    -h|--help)
      cat <<EOF
Usage: $(basename "$0") [options]

Options:
  -y, --yes     Auto-confirm commit (no interactive commit confirm)
  -h, --help    Show this help
EOF
      exit 0
      ;;
    *) echo "Unknown option: $1" ; exit 1 ;;
  esac
done
# ------------------------------------------------------------------------------

# --- Helpers ------------------------------------------------------------------
have() { command -v "$1" >/dev/null 2>&1; }
gum_style() {
  if have gum; then gum style --border normal --margin "1 0" --padding "0 1" --bold "$@"
  else printf "\n== %s ==\n" "$*"; fi
}
gum_title() {
  if have gum; then gum style --border double --margin "1 0" --padding "0 2" --bold "$@"
  else printf "\n## %s ##\n" "$*"; fi
}
gum_info()  { if have gum; then gum log --level info "$@";  else printf "[INFO] %s\n" "$*";  fi; }
gum_warn()  { if have gum; then gum log --level warn "$@";  else printf "[WARN] %s\n" "$*";  fi; }
gum_error() { if have gum; then gum log --level error "$@"; else printf "[ERR ] %s\n" "$*";  fi; }
gum_ok()    { if have gum; then gum log --level info --prefix "✅" "$@"; else printf "[ OK ] %s\n" "$*"; fi; }

cleanup() {
  [[ "${PWD}" != "${REPO_DIR}" ]] || popd >/dev/null || true
}
trap cleanup EXIT
# ------------------------------------------------------------------------------

pushd "$REPO_DIR" >/dev/null

gum_title "NixOS Rebuild (flake) — $(date '+%Y-%m-%d %H:%M:%S')"

# Detect relevant changes
CHANGES_PRESENT="$(git status --porcelain -- '*.nix' 'flake.nix' 'flake.lock' || true)"
if [[ -z "$CHANGES_PRESENT" ]]; then
  gum_info "No *.nix / flake changes detected. Nothing to do."
  exit 0
fi

# Show file summary
gum_style "Changed files"
git status --porcelain -- '*.nix' 'flake.nix' 'flake.lock' || true
echo

# Show diff
gum_style "Diff (.nix / flake)"
git --no-pager -c color.ui=always diff -U0 -- '*.nix' 'flake.nix' 'flake.lock' || true
echo

# Rebuild — stream EVERYTHING, also log
gum_style "nixos-rebuild switch --flake \"$REPO_DIR#$FLAKE_ATTR\""
: >"$LOG_FILE"
set +e
sudo nixos-rebuild switch --flake "$REPO_DIR#$FLAKE_ATTR" 2>&1 | tee -a "$LOG_FILE"
status=${PIPESTATUS[0]}
set -e
echo

if (( status != 0 )); then
  gum_error "Rebuild failed (exit $status). Quick error scan:"
  (grep -inE "error" "$LOG_FILE" && echo) || gum_warn "No lines containing 'error' in log."
  gum_warn "Full log saved at: $LOG_FILE"
  exit "$status"
fi

gum_ok "Rebuild succeeded."

# Build default commit message from current generation if available
current_gen="$(nixos-rebuild list-generations | grep -E 'current\s*\*$' || true)"
default_msg="${current_gen:-"$DEFAULT_MSG_PREFIX $(date -Is)"}"

# Stage changes (including new modules)
git add -A
if git diff --cached --quiet; then
  gum_info "Nothing staged after rebuild. No commit made."
  gum_info "Log: $LOG_FILE"
  exit 0
fi

# Confirm commit
CONFIRMED=false
if $AUTO_YES; then
  CONFIRMED=true
else
  if have gum; then
    gum_style "Commit Preview (default message)"
    echo "$default_msg"
    echo
    gum confirm "Commit staged changes?" && CONFIRMED=true || CONFIRMED=false
  else
    read -r -p "Commit staged changes? [y/N] " ans; [[ "${ans,,}" == "y" ]] && CONFIRMED=true || CONFIRMED=false
  fi
fi

if [[ "$CONFIRMED" == true ]]; then
  # Ask for optional custom message
  user_msg=""
  if have gum; then
    user_msg="$(gum input --placeholder "Optional commit message (leave blank for default)")"
  else
    read -r -p "Optional commit message (blank = default): " user_msg || true
  fi
  commit_msg="${user_msg:-$default_msg}"

  git commit -m "$commit_msg"
  gum_ok "Committed: $commit_msg"

  # Ask to push
  DO_PUSH=false
  if have gum; then
    gum confirm "Push now?" && DO_PUSH=true || DO_PUSH=false
  else
    read -r -p "Push now? [y/N] " ans; [[ "${ans,,}" == "y" ]] && DO_PUSH=true || DO_PUSH=false
  fi

  if [[ "$DO_PUSH" == true ]]; then
    branch="$(git rev-parse --abbrev-ref HEAD)"
    if upstream="$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null)"; then
      gum_info "Pushing to $upstream…"
      if ! git push; then gum_error "Push failed."; exit 1; fi
    else
      gum_warn "No upstream set for branch '$branch'. Setting upstream to origin/$branch…"
      if ! git push -u origin "$branch"; then gum_error "Push failed."; exit 1; fi
    fi
    gum_ok "Push complete."
  else
    gum_info "Push skipped."
  fi
else
  gum_warn "Commit skipped. (Rebuild applied; changes remain staged.)"
fi

gum_info "Log: $LOG_FILE"

# Optional desktop ping
command -v notify-send >/dev/null && \
  notify-send -e "NixOS Rebuilt OK!" --icon=software-update-available || true
