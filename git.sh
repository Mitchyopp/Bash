#!/usr/bin/env bash
# gitt-lite.sh — simple file picker → commit → push, with gum
set -euo pipefail

# --- deps ---
command -v git >/dev/null || { echo "git not found"; exit 1; }
command -v gum >/dev/null || { echo "need 'gum' (https://github.com/charmbracelet/gum)"; exit 1; }

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "Not in a git repo"; exit 1; }

branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'HEAD')"
gum style --border normal --border-foreground 61 --padding "0 1" "🌿 Branch: $(gum style --foreground 213 "$branch")"

# Show status (includes untracked)
gum style --foreground 45 "Changes:"
git -c color.ui=always status --short --branch | sed 's/^/  /'

# If absolutely nothing changed, exit
if [[ -z "$(git status --porcelain)" ]]; then
  gum style --foreground 244 "No changes. Nothing to do."
  exit 0
fi

# Build a clean list of paths to choose from (handles renames)
# Example porcelain lines:
#  M file.txt
# ?? newfile
# R  old -> new
# We strip the first 3 chars, then normalize "old -> new" to "new"
mapfile -t paths < <(
  git status --porcelain |
    sed -E 's/^.. //' |
    sed -E 's/^.* -> //'
)

# De-duplicate (just in case)
mapfile -t unique_paths < <(printf "%s\n" "${paths[@]}" | awk '!seen[$0]++')

# Pick files (multi-select)
selection="$(printf "%s\n" "${unique_paths[@]}" | gum choose --no-limit --cursor.foreground=212 --header "Select files to stage")" || true

if [[ -z "${selection:-}" ]]; then
  gum style --foreground 196 "Nothing selected. Aborting."
  exit 1
fi

# Stage chosen files
# Convert the newline-delimited selection to an array safely
IFS=$'\n' read -r -d '' -a files_to_add < <(printf "%s\0" $selection)
gum spin --spinner pulse --title "git add (selected files)" -- git add -- "${files_to_add[@]}"

# Preview staged diff
if git diff --cached --quiet; then
  gum style --foreground 196 "Nothing staged (unexpected). Aborting."
  exit 1
fi

gum style --foreground 45 --margin "1 0 0 0" "Staged diff (press q to exit):"
git -c color.ui=always diff --cached | less -R

# Confirm after diff (in case they changed their mind)
if ! gum confirm "Commit these changes?"; then
  gum style --foreground 244 "Unstaging selected files..."
  git reset -- "${files_to_add[@]}"
  exit 0
fi

# Commit message (single line)
msg="$(gum input --placeholder "Commit message (e.g., fix: handle null user)"))"
[[ -z "${msg// }" ]] && msg="update"

gum spin --spinner pulse --title "git commit -m \"$msg\"" -- git commit -m "$msg"

# Push?
if gum confirm "Push to remote?"; then
  if git rev-parse --abbrev-ref --symbolic-full-name "@{u}" >/dev/null 2>&1; then
    gum spin --spinner pulse --title "git push" -- git push
  else
    # No upstream set: choose remote if multiple, then set upstream
    remotes=( $(git remote) )
    if ((${#remotes[@]} == 0)); then
      gum style --foreground 196 "No git remotes configured. Skipping push."
    else
      remote="${remotes[0]}"
      if ((${#remotes[@]} > 1)); then
        remote="$(printf "%s\n" "${remotes[@]}" | gum choose --cursor.foreground=212 --header "Choose remote")"
      fi
      gum spin --spinner pulse --title "git push -u $remote $branch" -- git push -u "$remote" "$branch"
    fi
  fi
  gum style --foreground 42 "✅ Pushed $(gum style --foreground 213 "$branch")."
else
  gum style --foreground 244 "Push skipped."
fi

# Show the last commit line
gum style --border normal --border-foreground 61 --padding "1 2" \
"Last commit:
$(git --no-pager log -1 --pretty=format:'%C(213)%h%Creset %C(45)%ad%Creset %C(212)%d%Creset %s' --date=relative)"
