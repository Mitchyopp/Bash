#!/usr/bin/env bash
set -euo pipefail

# git-status.sh — pretty git status with gum (plus plain mode & per-file diffs)

has_cmd() { command -v "$1" &>/dev/null; }

die() { echo "Error: $*" >&2; exit 1; }

usage() {
  cat <<'USAGE'
Usage:
  git-status.sh                 # Pretty status + page through ALL diffs
  git-status.sh --plain|-p      # Plain 'git status'
  git-status.sh --file <path>   # Show diffs for a specific file
  git-status.sh <path>          # Same as --file <path>
  git-status.sh --help|-h       # This help

Notes:
- Shows both STAGED (index) and UNSTAGED (working tree) diffs.
- Uses gum for tidy UI; falls back to plain output if gum is missing.
USAGE
}

ensure_repo() {
  git rev-parse --git-dir &>/dev/null || die "Not a git repo (run inside a repo)."
}

# Collect file lists by category
list_staged()   { git diff --cached --name-only; }
list_unstaged() { git diff --name-only; }
list_untracked(){ git ls-files --others --exclude-standard; }

# Build a combined diff block with headings for pager
build_diff_block() {
  local title="$1"; shift
  local diff_cmd=("$@")
  local diff_out
  if diff_out="$("${diff_cmd[@]}")" && [[ -n "$diff_out" ]]; then
    printf "\n===== %s =====\n" "$title"
    printf "%s\n" "$diff_out"
  fi
}

# Show diffs for a set of files (all categories)
show_diffs_for_files() {
  if [[ $# -eq 0 ]]; then
    # All files with changes (staged + unstaged)
    mapfile -t staged < <(list_staged || true)
    mapfile -t unstaged < <(list_unstaged || true)
    # union
    mapfile -t files < <(printf "%s\n" "${staged[@]}" "${unstaged[@]}" | awk 'NF' | sort -u)
  else
    # Use provided files
    files=("$@")
  fi

  if [[ ${#files[@]} -eq 0 ]]; then
    echo "No diffs to show."
    return 0
  fi

  # Build diffs
  out=""
  block="$(build_diff_block "STAGED CHANGES (index)" git diff --cached --patch -- "${files[@]}")"; out+="$block"
  block="$(build_diff_block "UNSTAGED CHANGES (working tree)" git diff --patch -- "${files[@]}")"; out+="$block"

  if [[ -z "$out" ]]; then
    echo "No diffs to show for the selected files."
    return 0
  fi

  if has_cmd gum; then
    printf "%s\n" "$out" | gum pager
  else
    printf "%s\n" "$out" | ${PAGER:-less -R}
  fi
}

# Pretty status header + sections
pretty_status() {
  local branch ahead behind
  branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"
  # Ahead/behind from short status
  local sb; sb="$(git status -sb 2>/dev/null || true)"
  ahead="$(grep -o '\[ahead [0-9]\+\]' <<<"$sb" | grep -o '[0-9]\+' || echo 0)"
  behind="$(grep -o '\[behind [0-9]\+\]' <<<"$sb" | grep -o '[0-9]\+' || echo 0)"

  mapfile -t staged   < <(list_staged   || true)
  mapfile -t unstaged < <(list_unstaged || true)
  mapfile -t untracked< <(list_untracked|| true)

  local header="Git Status — branch: ${branch} (↑${ahead} ↓${behind})"
  local body=$(
    {
      echo
      echo "STAGED (${#staged[@]}):"
      ((${#staged[@]}))   && printf '  • %s\n' "${staged[@]}"   || echo "  (none)"
      echo
      echo "UNSTAGED (${#unstaged[@]}):"
      ((${#unstaged[@]})) && printf '  • %s\n' "${unstaged[@]}" || echo "  (none)"
      echo
      echo "UNTRACKED (${#untracked[@]}):"
      ((${#untracked[@]}))&& printf '  • %s\n' "${untracked[@]}"|| echo "  (none)"
      echo
    } | sed 's/\x1B\[[0-9;]\+[A-Za-z]//g'
  )

  if has_cmd gum; then
    gum style --border rounded --margin "0 0" --padding "1 2" --bold "$header"
    gum style --padding "0 2" "$body"
    # Offer to view diffs or pick files
    local choice
    choice=$(printf "View all diffs\nPick files to diff\nPlain git status\nQuit\n" | gum choose --header "What next?" --cursor "👉" --selected "View all diffs")
    case "$choice" in
      "View all diffs") show_diffs_for_files ;;
      "Pick files to diff")
        # Build union list for selection
        mapfile -t union < <(printf "%s\n" "${staged[@]}" "${unstaged[@]}" | awk 'NF' | sort -u)
        if ((${#union[@]}==0)); then
          gum style --italic "No changed files to pick."
        else
          # multi-select
          pick=$(printf "%s\n" "${union[@]}" | gum choose --no-limit --header "Select files to view diffs")
          if [[ -n "${pick:-}" ]]; then
            # split lines into array
            mapfile -t picks <<<"$pick"
            show_diffs_for_files "${picks[@]}"
          fi
        fi
        ;;
      "Plain git status") git status ;;
      "Quit") : ;;
    esac
  else
    # Fallback: plain header + body + all diffs in pager
    echo "== $header =="
    echo "$body"
    echo "(gum not found; showing all diffs in $PAGER)"
    show_diffs_for_files
  fi
}

show_plain() {
  git status
}

show_file_diff() {
  local file="$1"
  [[ -e "$file" || -n "$(git ls-files -- "$file")" ]] || die "File '$file' not tracked or doesn't exist."
  show_diffs_for_files "$file"
}

# -------- main --------
ensure_repo

if [[ $# -gt 0 ]]; then
  case "${1:-}" in
    --help|-h) usage; exit 0 ;;
    --plain|-p) show_plain; exit 0 ;;
    --file)
      [[ $# -ge 2 ]] || die "--file requires a path"
      show_file_diff "$2"; exit 0
      ;;
    -*)
      usage; exit 2
      ;;
    *)
      # treat as a path
      show_file_diff "$1"; exit 0
      ;;
  esac
fi

pretty_status
