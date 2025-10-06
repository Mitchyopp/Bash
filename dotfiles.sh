#!/usr/bin/env bash
set -Eeuo pipefail

# -----------------------------------------------------------------------------
# Dotfiles / nixdots autosync
# -----------------------------------------------------------------------------

# --- config ---------------------------------------------------------------
DEFAULT_REPOS=("$HOME/nixdots" "$HOME/dotfiles")
COMMIT_MSG_DEFAULT="chore(sync): auto-update $(date -Iseconds)"
LOG_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/dotsync"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/$(date -Iseconds).log"

# --- args ----------------------------------------------------------------
DRY_RUN="false"
COMMIT_MSG="$COMMIT_MSG_DEFAULT"
REPOS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN="true"; shift ;;
    --message|-m) COMMIT_MSG="${2:?Missing message}"; shift 2 ;;
    --repo) REPOS+=("${2:?Missing path}"); shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [[ ${#REPOS[@]} -eq 0 ]]; then
  REPOS=("${DEFAULT_REPOS[@]}")
fi

# --- utils ---------------------------------------------------------------
notify() {
  local body="${1:-}"; local urg="${2:-normal}"; local title="${3:-Dot Sync}"
  command -v notify-send >/dev/null 2>&1 && notify-send --urgency="$urg" "$title" "$body" || true
}
section() { printf '\n\033[1;36m==> %s\033[0m\n' "$*" | tee -a "$LOG_FILE"; }

repo_has_changes() {
  [[ -n "$(git status --porcelain=v1 2>/dev/null)" ]]
}

ensure_upstream() {
  local remote branch upstream default_branch
  remote="${1:-origin}"
  branch="$(git symbolic-ref --quiet --short HEAD || true)"

  if [[ -z "$branch" ]]; then
    branch="autosync-$(date +%Y%m%d-%H%M%S)"
    git switch -c "$branch" >/dev/null
  fi

  upstream="$(git rev-parse --abbrev-ref --symbolic-full-name "@{u}" 2>/dev/null || true)"
  if [[ -z "$upstream" ]]; then
    if git remote show -n "$remote" >/dev/null 2>&1; then
      default_branch="$(git remote show -n "$remote" | awk '/HEAD branch/ {print $NF}')"
      default_branch="${default_branch:-main}"
    else
      remote="origin"
      default_branch="main"
    fi
    if git ls-remote --exit-code "$remote" "refs/heads/$branch" >/dev/null 2>&1; then
      git branch --set-upstream-to="$remote/$branch" >/dev/null 2>&1 || true
    else
      git push -u "$remote" "$branch" >/dev/null
    fi
  fi
  echo "$remote $branch"
}

sync_one_repo() {
  local path="$1"
  [[ -d "$path/.git" ]] || { echo "Skip: $path (not a git repo)"; return 0; }

  section "Syncing $path"
  pushd "$path" >/dev/null

  git status -sb | tee -a "$LOG_FILE"

  if ! repo_has_changes; then
    echo "No changes in $path" | tee -a "$LOG_FILE"
    notify "📂 No changes in $(basename "$path") — nothing to upload." normal
  else
    echo "Staging changes…" | tee -a "$LOG_FILE"
    if [[ "$DRY_RUN" == "true" ]]; then
      git -c color.ui=always status --porcelain=v1 | tee -a "$LOG_FILE"
      echo "(dry-run) Would run: git add -A; git commit -m '$COMMIT_MSG'" | tee -a "$LOG_FILE"
    else
      git add -A
      if git diff --cached --quiet --no-ext-diff; then
        echo "Nothing to commit after add -A (likely ignored files). Skipping." | tee -a "$LOG_FILE"
      else
        git commit -m "$COMMIT_MSG" | tee -a "$LOG_FILE"
      fi
    fi
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "(dry-run) Would ensure upstream and push" | tee -a "$LOG_FILE"
  else
    read -r remote branch < <(ensure_upstream "origin")
    echo "Using remote=$remote branch=$branch" | tee -a "$LOG_FILE"

    if git rev-parse --verify "$branch" >/dev/null 2>&1; then
      git pull --rebase --autostash "$remote" "$branch" | tee -a "$LOG_FILE" || {
        notify "⚠️ Rebase failed in $(basename "$path"). Manual fix needed." critical
        popd >/dev/null
        return 1
      }
    fi

    if ! git push "$remote" "$branch" | tee -a "$LOG_FILE"; then
      notify "❌ Push failed in $(basename "$path"). Check $LOG_FILE." critical
      popd >/dev/null
      return 1
    fi
    notify "✅ $(basename "$path") pushed." normal
  fi

  popd >/dev/null
  return 0
}

START="$(date +%s)"
notify "📝 Syncing nixdots & dotfiles…" normal "Dot Sync"

FAILED=0
for repo in "${REPOS[@]}"; do
  if ! sync_one_repo "$repo"; then
    FAILED=1
  fi
done

DUR=$(( $(date +%s) - START ))
if [[ "$DRY_RUN" == "true" ]]; then
  notify "👀 Dry-run complete in ${DUR}s\nSee log: $LOG_FILE" normal
elif [[ $FAILED -eq 0 ]]; then
  notify "🚀 Sync complete in ${DUR}s\nLog: $LOG_FILE" normal
else
  notify "⚠️ Sync completed with errors. See $LOG_FILE" critical
fi

echo "Log: $LOG_FILE"
