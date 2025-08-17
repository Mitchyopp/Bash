#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  deep-scan.sh [options] -- <pattern> [pattern2 ...]
Options:
  -r, --root DIR        Root directory to scan (default: .)
  -i, --ignore-case     Case-insensitive match
      --name-only       Only search filenames
      --content-only    Only search file contents
      --trash           Use trash instead of rm (needs trash-cli)
      --no-ignore       Do not respect .gitignore (pass to rg/fd)
      --hidden          Include hidden files (pass to rg/fd)
      --dry-run         Do not delete, just select (default)
      --no-dry-run      Actually delete after confirm
  -h, --help            Show help

Examples:
  deep-scan.sh -r ~ -- "secret"
  deep-scan.sh --ignore-case -- "token" "password"
  deep-scan.sh --name-only -- "*.bak" ".DS_Store"
USAGE
}

ROOT="."
IGNORE_CASE=0
NAME_ONLY=0
CONTENT_ONLY=0
TRASH=0
NOIGNORE=0
HIDDEN=0
DRYRUN=1

ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -r|--root) ROOT="${2:-}"; shift 2 ;;
    -i|--ignore-case) IGNORE_CASE=1; shift ;;
    --name-only) NAME_ONLY=1; shift ;;
    --content-only) CONTENT_ONLY=1; shift ;;
    --trash) TRASH=1; shift ;;
    --no-ignore) NOIGNORE=1; shift ;;
    --hidden) HIDDEN=1; shift ;;
    --dry-run) DRYRUN=1; shift ;;
    --no-dry-run) DRYRUN=0; shift ;;
    -h|--help) usage; exit 0 ;;
    --) shift; ARGS+=("$@"); break ;;
    -*) echo "Unknown option: $1" >&2; usage; exit 1 ;;
    *) ARGS+=("$1"); shift ;;
  esac
done

[[ ${#ARGS[@]} -gt 0 ]] || { echo "Error: need at least one <pattern>." >&2; usage; exit 1; }

has() { command -v "$1" >/dev/null 2>&1; }

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
CAND0="$TMP_DIR/candidates.nul"     # NUL-separated absolute paths
SEL0="$TMP_DIR/selected.nul"

collect_name_matches() {
  local pat flags fd_extra rg_extra
  : >"$CAND0"
  for pat in "${ARGS[@]}"; do
    if has fd; then
      fd_extra=()
      ((NOIGNORE)) && fd_extra+=(--no-ignore)
      ((HIDDEN)) && fd_extra+=(--hidden)
      if ((IGNORE_CASE)); then
        fd --absolute-path --type f "${fd_extra[@]}" -0 -g "$pat" "$ROOT" >>"$CAND0" || true
      else
        # fd is case-insensitive by default; enforce case-sensitivity via --case-sensitive if needed
        fd --absolute-path --type f --case-sensitive "${fd_extra[@]}" -0 -g "$pat" "$ROOT" >>"$CAND0" || true
      fi
    else
      # fallback to find (glob only makes sense if pattern has * ? [])
      if ((IGNORE_CASE)); then
        find "$ROOT" -type f -iname "$pat" -print0 >>"$CAND0" 2>/dev/null || true
      else
        find "$ROOT" -type f -name "$pat"  -print0 >>"$CAND0" 2>/dev/null || true
      fi
    fi
  done
}

collect_content_matches() {
  local rg_flags grep_flags
  if has rg; then
    rg_flags=(-l -0)
    ((IGNORE_CASE)) && rg_flags+=(-i)
    ((NOIGNORE)) && rg_flags+=(--no-ignore)
    ((HIDDEN)) && rg_flags+=(--hidden)
    rg "${rg_flags[@]}" -- "${ARGS[@]}" "$ROOT" >>"$CAND0" 2>/dev/null || true
  else
    grep_flags=(-rlZ)
    ((IGNORE_CASE)) && grep_flags+=(-i)
    # grep doesn't follow .gitignore; use find to limit to files
    find "$ROOT" -type f -print0 | xargs -0 grep "${grep_flags[@]}" -- "${ARGS[@]}" 2>/dev/null >>"$CAND0" || true
  fi
}

if ((NAME_ONLY)) && ((CONTENT_ONLY)); then
  echo "Cannot use --name-only and --content-only together." >&2
  exit 1
fi

if ((NAME_ONLY)); then
  collect_name_matches
elif ((CONTENT_ONLY)); then
  collect_content_matches
else
  collect_name_matches
  collect_content_matches
fi

if [[ -s "$CAND0" ]]; then
  sort -zu "$CAND0" -o "$CAND0"
else
  echo "No matches found." >&2
  exit 0
fi

# Use --read0 to handle NULs safely. Preview first 200 lines with bat or sed.
PREVIEW='
  if command -v bat >/dev/null 2>&1; then
    bat --style=plain --color=always --line-range :200 -- "{}"
  else
    sed -n "1,200p" -- "{}"
  fi
'

python3 - "$CAND0" "$ROOT" <<'PY' >"$TMP_DIR/menu.txt"
import os, sys
cand = open(sys.argv[1],'rb').read().split(b'\x00')
root = os.path.abspath(sys.argv[2])
for p in cand:
    if not p: continue
    ap = os.path.abspath(p.decode('utf-8', 'surrogateescape'))
    try:
        rp = os.path.relpath(ap, root)
    except Exception:
        rp = ap
    # print absolute\trelative for later lookup
    print(f"{ap}\t{rp}")
PY

SEL_TXT="$TMP_DIR/selected.txt"
cut -f2 "$TMP_DIR/menu.txt" | fzf --multi --ansi --preview "$PREVIEW" --height=90% --border --prompt="select to delete > " >"$SEL_TXT" || true

if [[ ! -s "$SEL_TXT" ]]; then
  echo "Nothing selected."
  exit 0
fi

awk -F'\t' 'NR==FNR{sel[$1]=1; next} {if($2 in sel) print $1}' "$SEL_TXT" "$TMP_DIR/menu.txt" \
  | awk '!seen[$0]++' \
  | tr '\n' '\0' > "$SEL0"

COUNT=$(tr -cd '\0' < "$SEL0" | wc -c | tr -d ' ')

echo
echo "You selected $COUNT file(s)."
echo "Examples:"
head -z -n 3 "$SEL0" | tr '\0' '\n' | sed 's/^/  - /'
echo

if (( DRYRUN )); then
  echo "[DRY RUN] No files will be deleted. Re-run with --no-dry-run to delete."
  exit 0
fi

read -r -p "Type DELETE (all caps) to permanently delete $COUNT file(s): " CONFIRM
if [[ "$CONFIRM" != "DELETE" ]]; then
  echo "Aborted."
  exit 1
fi

if (( TRASH )); then
  if ! has trash-put; then
    echo "trash-cli (trash-put) not found. Install it or omit --trash." >&2
    exit 1
  fi
  echo "Sending to trash..."
  while IFS= read -r -d '' f; do
    trash-put -- "$f"
  done <"$SEL0"
else
  echo "Deleting with rm -f ..."
  while IFS= read -r -d '' f; do
    rm -f -- "$f"
  done <"$SEL0"
fi

echo "Done."
