#!/bin/bash
# Compare two Markdown bodies by content only.
# Usage: content-diff.sh <lines|words> <file-a> <file-b>
#   lines — line diff, one normalized line per paragraph/list item/table row
#   words — word diff: changed words shown inline as [-old-]{+new+}
# Exit code: 0 = same content, 1 = content differs, 2 = error.
# Diffs are produced by `git diff --no-index`; no repository is needed.
#
# Normalization removes differences Confluence introduces on round-trip:
# YAML frontmatter, blank lines, indentation, trailing spaces, list markers,
# blockquote markers, table separator rows, table cell padding, horizontal rules, backslash escapes,
# code fence lines, and Confluence element placeholders reduced to type + label
# (`confluence:toc 1a2b3c4d` and the older <!-- confluence:toc 1a2b3c4d --> compare equal).

set -u
mode=${1:-}; a=${2:-}; b=${3:-}
if [[ "$mode" != lines && "$mode" != words ]] || [[ ! -f "$a" || ! -f "$b" ]]; then
  echo "usage: content-diff.sh <lines|words> <file-a> <file-b>" >&2
  exit 2
fi

normalize() {
  awk 'NR==1 && /^---[[:space:]]*$/ {fm=1; next}
       fm && /^---[[:space:]]*$/ {fm=0; next}
       !fm' "$1" |
  sed -E \
    -e 's/[[:space:]]+$//' \
    -e 's/\\$//' \
    -e 's/^[[:space:]]+//' \
    -e '/^(-{3,}|\*{3,}|_{3,})$/d' \
    -e '/^\|[-:| ]+\|$/d' \
    -e 's/^(>[[:space:]]?)+//' \
    -e 's/^[-*+][[:space:]]+//' \
    -e 's/\\([][\\`*_{}()#+.!|~<>$&-])/\1/g' \
    -e 's/<!--[[:space:]]*(\/?confluence:[^[:space:]]+)[[:space:]]+[0-9a-f]{8}[[:space:]]*("[^"]*")?[[:space:]]*-->/[\1 \2]/g' \
    -e 's/`[[:space:]]*(\/?confluence:[^[:space:]`]+)[[:space:]]+[0-9a-f]{8}[[:space:]]*("[^"]*")?[[:space:]]*`/[\1 \2]/g' \
    -e '/^\|/ s/[[:space:]]*\|[[:space:]]*/ | /g' \
    -e '/^ \| / s/^ //' \
    -e '/^(```|~~~)[^`]*$/d' \
    -e 's/[[:space:]]+/ /g' \
    -e 's/ $//' \
    -e '/^$/d'
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/a" "$tmp/b"
normalize "$a" > "$tmp/a/content.md"
normalize "$b" > "$tmp/b/content.md"

opts=(--no-index --no-color -U0)
if [[ "$mode" == words ]]; then
  # Decide on the word sequence only, so text re-wrapped across lines is not a change.
  tr ' ' '\n' < "$tmp/a/content.md" > "$tmp/a.words"
  tr ' ' '\n' < "$tmp/b/content.md" > "$tmp/b.words"
  cmp -s "$tmp/a.words" "$tmp/b.words" && exit 0
  opts+=(--word-diff=plain --word-diff-regex='[^[:space:]]+')
fi
out=$(cd "$tmp" && git diff "${opts[@]}" a/content.md b/content.md)
rc=$?
(( rc > 1 )) && exit 2
(( rc == 0 )) && exit 0
# Replace git's header (temp paths) with the real file names.
printf -- '--- %s\n+++ %s\n' "$a" "$b"
if [[ "$mode" == words ]]; then
  # Keep only hunks that change words (drop pure line-wrapping hunks).
  printf '%s\n' "$out" | sed -n '/^@@/,$p' |
    awk '/^@@/ {h=$0; next} /\[-|\{\+/ {if (h) {print h; h=""} print}'
else
  printf '%s\n' "$out" | sed -n '/^@@/,$p'
fi
exit 1
