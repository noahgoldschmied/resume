#!/usr/bin/env bash
# Compile main.tex and replace the tracked resume PDF.
#
# Builds into a temp directory so .aux/.log/.out never land in the repo, and
# only overwrites the PDF once the build succeeds -- a broken edit can't
# clobber a good copy.
#
# Usage: ./build.sh

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

SRC="main.tex"
OUT="Noah Goldschmied Resume.pdf"

BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT

# Two passes so hyperref links and bookmarks resolve.
for pass in 1 2; do
  if ! pdflatex -interaction=nonstopmode -halt-on-error \
        -output-directory="$BUILD" "$SRC" >/dev/null 2>&1; then
    echo "Build failed on pass $pass:" >&2
    echo >&2
    grep -A3 -E '^!' "$BUILD/main.log" >&2 || tail -20 "$BUILD/main.log" >&2
    echo >&2
    echo "\"$OUT\" left untouched." >&2
    exit 1
  fi
done

cp "$BUILD/main.pdf" "$OUT"

# pdflatex hard-wraps log lines at ~79 chars, which can split "(1 page)" across
# a newline, so flatten the log before matching.
pages="$(tr -d '\n' < "$BUILD/main.log" | grep -oE '\([0-9]+ pages?' | tail -1 | tr -d '(' || true)"
warnings="$(grep -cE '^(Over|Under)full' "$BUILD/main.log" || true)"

echo "Wrote \"$OUT\" -- ${pages:-unknown length}, ${warnings:-0} layout warning(s)"

# Layout warnings mean text is spilling past the margins. Worth a look.
if [ "${warnings:-0}" -gt 0 ]; then
  echo
  echo "Layout warnings:" >&2
  grep -E '^(Over|Under)full' "$BUILD/main.log" >&2 || true
fi
