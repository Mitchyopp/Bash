#!/usr/bin/env bash
set -Eeuo pipefail

# ──────────────────────────────────────────────────────────────────────────────
# Dotfiles / nixdots sync (interactive, gum-powered)
# ──────────────────────────────────────────────────────────────────────────────

# --- CONFIG: add your repos here ------------------------------------------------
REPOS=(
  "$HOME/nixdots"
  "$HOME/dotfiles"
  "$HOME/Scripts/"
  "$HOME/.config/niri/"
)

# Default commit message if you just smash Enter
DEFAULT_MSG="chore(sync): dot sync $(date -Iseconds)"

# --- Helpers -------------------------------------------------------------------
die() { echo -e "\e[31m$*\e[0m" >&2; exit 1; }
has() { command -v "$1" >/dev/null 2>&1; }

if ! has gum; then
  die "gum is required. nix-shell -p gum  # or add gum to your system/user packages."
fi
if ! has git; then
  die "git is required."
fi

style_h()   { gum style --border normal --margin "1 0" --padding "0 1" --border-foreground 212 "$@"; }
style_ok()  { gum style --foreground 120 "$@"; }
style_bad() { gum style --foreground 203 "$@"; }
style_dim() { gum style --faint "$@"; }

is_git_repo() { [[ -d "$1/.git" ]]; }

repo_short() { basename "$1"; }

repo_dirty() (
  cd "$1" || return 1
  [[ -n "$(git status --porcelain=v1 2>/dev/null)" ]]
)

status_summary() (
  cd "$1" || return 1
  # Count M, A, D, ?? from porcelain
  git status --porcelain=v1 | awk '
    $1 ~ /^M/ || $2 ~ /^M/ {m++}
    $1 ~ /^A/ || $2 ~ /^A/ {a++}
    $1 ~ /^D/ || $2 ~ /^D/ {d++}
    $1 ~ /^\?\?/ {u++}
    END {
      if (m==0 && a==0 && d==0 && u==0) print "clean"
      else printf "M:%d A:%d D:%d ?:%.0f", m+0, a+0, d+0, u+0
    }'
)

current_branch() (
  cd "$1" || return 1
  git symbolic-ref --quiet --short HEAD 2>/dev/null || true
)

ensure_upstream() (
  # Sets upstream if missing. Echoes "<remote> <branch>" on success.
  # Creates a branch if detached.
  repo="$1"; remote="${2:-origin}"
  cd "$repo" || return 1

  branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
  if [[ -z "$branch" ]]; then
    branch="sync-$(date +%Y%m%d-%H%M%S)"
    gum spin --title "Creating branch $branch" -- git switch -c "$branch" >/dev/null
  fi

  upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"
  if [[ -z "$upstream" ]]; then
    # Pick remote if there are multiple
    remotes=( $(git remote) )
    if [[ ${#remotes[@]} -eq 0 ]]; then
      die "No git remotes configured in $(repo_short "$repo")."
    fi
    if [[ ${#remotes[@]} -gt 1 ]]; then
      choice=$(printf "%s\n" "${remotes[@]}" | gum choose --header "Select remote for upstream")
      remote="$choice"
    fi
    # Push with -u if no upstream
    gum spin --title "Pushing -u $remote $branch" -- git push -u "$remote" "$branch" >/dev/null
  fi
  echo "$remote $branch"
)

view_status() (
  repo="$1"
  cd "$repo" || return 1
  style_h "Status — $(repo_short "$repo")"
  git status -sb
  echo
)

view_diff() (
  repo="$1"
  cd "$repo" || return 1
  style_h "Diff — $(repo_short "$repo")"
  git --no-pager diff
  echo
)

commit_all() (
  repo="$1"
  cd "$repo" || return 1

  if ! repo_dirty "$repo"; then
    style_ok "Nothing to commit in $(repo_short "$repo")."
    return 0
  fi

  # Show a minimal staged preview before adding
  gum style --faint "Staging all changes (tracked + untracked)…"
  git add -A

  if git diff --cached --quiet --no-ext-diff; then
    style_dim "Nothing staged after add -A (maybe .gitignore)."
    return 0
  fi

  msg=$(gum input --placeholder "$DEFAULT_MSG" --header "Commit message (Enter for default)")
  msg="${msg:-$DEFAULT_MSG}"

  if gum confirm "Commit now with message: $(style_dim "$msg")?"; then
    gum spin --title "Committing…" -- git commit -m "$msg" >/dev/null \
      && style_ok "Committed."
  else
    style_dim "Commit cancelled."
  fi
)

push_repo() (
  repo="$1"
  cd "$repo" || return 1
  read -r remote branch < <(ensure_upstream "$repo")
  gum spin --title "Pull --rebase $remote/$branch (autostash)" -- \
    git pull --rebase --autostash "$remote" "$branch" >/dev/null || {
      style_bad "Rebase failed. Fix conflicts and try again."
      return 1
    }
  gum spin --title "Pushing → $remote/$branch" -- git push "$remote" "$branch" >/dev/null \
    && style_ok "Pushed to $remote/$branch."
)

# --- Repo Picker ---------------------------------------------------------------
pick_repo() {
  # Build menu with status badges
  mapfile -t entries < <(
    for r in "${REPOS[@]}"; do
      if ! is_git_repo "$r"; then
        printf "%s  %s\n" "$(repo_short "$r")" "$(style_bad "[not a git repo]")"
        continue
      fi
      sum="$(status_summary "$r" || echo "error")"
      if [[ "$sum" == "clean" ]]; then
        printf "%s  %s\n" "$(repo_short "$r")" "$(style_dim "[clean]")"
      else
        printf "%s  %s\n" "$(repo_short "$r")" "$(style_ok "[$sum]")"
      fi
    done
  )

  [[ ${#entries[@]} -gt 0 ]] || die "No repos configured."

  choice="$(printf "%s\n" "${entries[@]}" \
    | gum choose --header "Pick a repo" --height 10)"

  [[ -n "$choice" ]] || return 1

  # Extract the name (first token, before two spaces)
  name="${choice%%  *}"
  # Resolve back to absolute path
  for r in "${REPOS[@]}"; do
    if [[ "$(repo_short "$r")" == "$name" ]]; then
      echo "$r"
      return 0
    fi
  done
  return 1
}

# --- Main loop -----------------------------------------------------------------
style_h "Dotfiles Sync"

while true; do
  repo="$(pick_repo)" || break

  if ! is_git_repo "$repo"; then
    style_bad "$(repo_short "$repo") is not a git repo."
    continue
  fi

  while true; do
    action=$(gum choose \
      "Status" "Diff" "Commit (stage all)" "Push" "Open Shell Here" "Change Repo" "Quit" \
      --header "Repo: $(repo_short "$repo")  •  $(status_summary "$repo")")
    case "$action" in
      "Status") view_status "$repo" ;;
      "Diff") view_diff "$repo" ;;
      "Commit (stage all)") commit_all "$repo" ;;
      "Push") push_repo "$repo" ;;
      "Open Shell Here") ( cd "$repo" && ${SHELL:-bash} );;
      "Change Repo") break ;;
      "Quit") exit 0 ;;
    esac
  done
done
