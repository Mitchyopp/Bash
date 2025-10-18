#!/usr/bin/env bash
set -euo pipefail

# --- Guards & setup -----------------------------------------------------------
if ! command -v gum >/dev/null 2>&1; then
  echo "This demo needs 'gum' (https://github.com/charmbracelet/gum)."
  exit 1
fi

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/demo"
printf "alpha\nbeta\ngamma\ndelta\n" > "$TMPDIR/demo/list.txt"
printf "id\tname\tlang\n1\tAlice\tRust\n2\tBob\tJavaScript\n3\tChloe\tGo\n" > "$TMPDIR/demo/people.tsv"
cat > "$TMPDIR/demo/readme.txt" <<'TXT'
# Gum Showcase
This is a long-ish file to demonstrate `gum pager`. Use j/k or arrows to scroll, q to quit.
- Pretty prompts
- Spinners
- Tables
- Formatting & Styling
TXT

# --- Pretty header (style) ----------------------------------------------------
gum style --border double --margin "1 2" --padding "1 2" --bold --foreground 212 "🎀 Gum Showcase — Glam up your shell scripts"

# --- Logging (log) ------------------------------------------------------------
gum log --level info  "Starting demo…"
gum log --level warn  "This is only a demo, no system changes."
gum log --level error "Not a real error, just showing the style."
# No 'success' level in gum; emulate it with styled text:
gum style --foreground 10 "SUCCESS Demo continuing…"

# --- Version sanity (version-check) -------------------------------------------
if ! gum version-check ">=0.13.0"; then
  gum log --level warn "Your gum might be older than recommended (>=0.13.0). Some flags may differ."
fi

# --- Short input & long-form write (input, write) -----------------------------
NAME="$(gum input --placeholder "Enter your name")"
[ -z "${NAME}" ] && NAME="Anonymous"

BIO="$(gum write --placeholder "Write a one-liner bio (Ctrl+D to finish)")"

# --- Choose (single) & Choose (multi) (choose) --------------------------------
LANG="$(gum choose "Rust" "JavaScript" "Python" "Go" "Elixir" "C#")"
FRAMEWORKS="$(printf "Axum\nActix\nReact\nSvelteKit\nNext.js\nDjango\nFlask\nRocket\n" \
  | gum choose --no-limit --cursor.foreground 212 --header "Pick any frameworks you like")"
FRAMEWORKS=${FRAMEWORKS:-"(none)"}

# --- Fuzzy filter from a list (filter) ----------------------------------------
PICKED_FILTER="$(cat "$TMPDIR/demo/list.txt" | gum filter --placeholder "Type to fuzzy-filter (try 'g')")"

# --- Pick a file interactively (file) -----------------------------------------
SELECTED_FILE="$(gum file "$TMPDIR/demo" --all || true)"
SELECTED_FILE=${SELECTED_FILE:-"(none)"}

# --- Confirm before “doing work” (confirm) ------------------------------------
gum style --border normal --padding "0 1" "About to run a pretend setup for $NAME ($LANG)."
gum style --faint "Frameworks: $FRAMEWORKS"
gum style --faint "Filtered word: $PICKED_FILTER"
gum style --faint "Chosen file:  $SELECTED_FILE"

gum confirm "Proceed?" || { gum log --level warn "User cancelled."; exit 0; }

# --- Spinner while a task runs (spin) -----------------------------------------
gum spin --title "Setting things up…" --spinner line -- sleep 2

# --- Format strings with a template (format) ----------------------------------
FORMATTED="$(
  gum format '{{.greeting}}, {{.name}}! You picked {{.lang}}.'
    --greeting "Hello" \
    --name "$NAME" \
    --lang "$LANG"
)"
gum style --border rounded --padding "1 2" --margin "1 0" "$FORMATTED"

# --- Render a table (table) ---------------------------------------------------
gum style --bold "Team Table:"
gum table --separator "	" < "$TMPDIR/demo/people.tsv"

# --- Join text vertically & horizontally (join) -------------------------------
gum style --bold --margin "1 0" "Join demo:"
gum join --horizontal <(printf "Left\nA\nB\nC") <(printf "Right\n1\n2\n3") || true
printf "\n"
printf "Vertical join:\n"
gum join <(printf "Top block\n---") <(printf "Bottom block\n===") || true

# --- View a file with pager (pager) -------------------------------------------
gum style --margin "1 0" --bold "Open a pager (press q to quit):"
gum pager < "$TMPDIR/demo/readme.txt"

# --- Add some styled output (style) -------------------------------------------
gum style --border thick --padding "1 2" --foreground 10 "✅ Setup steps completed (pretend)."

# --- Multi-step spinners (spin) -----------------------------------------------
gum spin --title "Installing deps…" -- sleep 1
gum spin --title "Compiling…"       -- sleep 1
gum spin --title "Running tests…"   -- sleep 1

# --- Final summary using style + format ---------------------------------------
SUMMARY="$(gum format 'Name: {{.n}}
Bio: {{.b}}
Language: {{.l}}
Frameworks: {{.f}}
Filter pick: {{.fp}}
File: {{.file}}' \
  --n "$NAME" \
  --b "${BIO:-"(none)"}" \
  --l "$LANG" \
  --f "$FRAMEWORKS" \
  --fp "$PICKED_FILTER" \
  --file "$SELECTED_FILE")"

gum style --border double --padding "1 2" --margin "1 0" --foreground 212 "$SUMMARY"

gum style --foreground 10 "All gum widgets demonstrated. ✨"
