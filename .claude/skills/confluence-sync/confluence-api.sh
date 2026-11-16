#!/bin/bash
# Confluence REST helper for the confluence-sync skill ("api" mode).
# Page bodies move file <-> Confluence directly, so they never pass through the model.
#
# Usage (run from the project root):
#   confluence-api.sh auth                                   check credentials and site
#   confluence-api.sh info     <pageId>                      print version=, title=, spaceId= and slug=
#   confluence-api.sh get      <pageId> <out.md>             page body -> Markdown file
#   confluence-api.sh put      <pageId> <in.md> <message> [title]   Markdown file -> page body
#   confluence-api.sh create   <parentId> <title>            new empty child page; prints pageId=
#   confluence-api.sh comments <pageId>                      open inline comments
#   confluence-api.sh raw      <pageId> <out.html>           page body as storage XML (debugging)
#   confluence-api.sh lint     <in.md>                       warn about forced line breaks (no API call)
#   confluence-api.sh log      <pageId> <summary>            append a line to ./log.md if it exists (no API call)
#   confluence-api.sh to-md    <in.html> <out.md> <store>    convert only (testing)
#   confluence-api.sh to-html  <in.md> <out.html> <store>    convert only (testing)
#
# Confluence-only elements are kept across get/put through placeholders and the
# element store .confluence-sync/<pageId>.elements.json (see confluence-convert.py).
#
# Credentials: macOS Keychain generic password with service "confluence-sync"
# (account = Atlassian email, password = API token), or env vars
# CONFLUENCE_EMAIL + CONFLUENCE_API_TOKEN. The token is never printed and is
# passed to curl on stdin, not on the command line.
# Site: `cloudId` from .confluence-sync/manifest.yaml, or env CONFLUENCE_SITE.
#
# Exit codes: 0 ok, 1 API/HTTP error, 2 usage or setup error.

set -uo pipefail
SERVICE=confluence-sync
MANIFEST=.confluence-sync/manifest.yaml

fail()  { echo "error: $1" >&2; exit 1; }
setup() { echo "error: $1" >&2; exit 2; }

need() { command -v "$1" >/dev/null || setup "$1 not installed${2:+ ($2)}"; }

# --- conversion -------------------------------------------------------------

# Conversion lives in confluence-convert.py. Confluence-only elements (macros,
# page links, images, ...) become placeholder comments in Markdown; their
# storage XML is kept in the page's element store and restored on push.
CONVERT="$(dirname "$0")/confluence-convert.py"
store() { echo ".confluence-sync/$1.elements.json"; }
to_md()   { need pandoc "brew install pandoc"; python3 "$CONVERT" to-md   "$1" "$2" "$3"; }
to_html() { need pandoc "brew install pandoc"; python3 "$CONVERT" to-html "$1" "$2" "$3"; }

# --- API --------------------------------------------------------------------

site() {
  local s=${CONFLUENCE_SITE:-}
  [[ -z "$s" && -f "$MANIFEST" ]] && s=$(awk '/^cloudId:/ {print $2; exit}' "$MANIFEST" | tr -d '"')
  [[ -n "$s" ]] || setup "site unknown: set cloudId in $MANIFEST or CONFLUENCE_SITE"
  echo "$s"
}

creds() {
  EMAIL=${CONFLUENCE_EMAIL:-}
  TOKEN=${CONFLUENCE_API_TOKEN:-}
  if [[ -z "$TOKEN" ]]; then
    TOKEN=$(security find-generic-password -s "$SERVICE" -w 2>/dev/null) ||
      setup "no API token: add a Keychain item with service '$SERVICE' (see SKILL.md, API mode setup)"
    EMAIL=$(security find-generic-password -s "$SERVICE" 2>/dev/null |
      sed -n 's/^ *"acct"<blob>="\(.*\)"$/\1/p')
  fi
  [[ -n "$EMAIL" ]] || setup "no Atlassian email: set the Keychain item's account, or CONFLUENCE_EMAIL"
}

# Base URL for /wiki paths. Classic API tokens work on the site itself; scoped
# tokens only work through the api.atlassian.com gateway. `auth` probes both
# and caches the working one in $BASE_CACHE.
BASE_CACHE=.confluence-sync/.api-base
site_base()    { echo "https://$(site)/wiki"; }
gateway_base() {
  local id
  id=$(curl -sS "https://$(site)/_edge/tenant_info" | jq -r '.cloudId // empty') ||
    fail "cannot resolve cloud ID for $(site)"
  [[ -n "$id" ]] || fail "cannot resolve cloud ID for $(site)"
  echo "https://api.atlassian.com/ex/confluence/$id/wiki"
}
base() {
  if [[ -z "${BASE:-}" ]]; then
    BASE=$(cat "$BASE_CACHE" 2>/dev/null)
    [[ -n "$BASE" ]] || BASE=$(site_base)
  fi
  echo "$BASE"
}

# api <METHOD> <path under /wiki> [json-body-file] -> response body on stdout
api() {
  local method=$1 path=$2 data=${3:-} out code
  out=$(mktemp)
  local args=(-sS -o "$out" -w '%{http_code}' -X "$method" -H 'Accept: application/json')
  [[ -n "$data" ]] && args+=(-H 'Content-Type: application/json' --data-binary "@$data")
  code=$(printf 'user = "%s:%s"\n' "$EMAIL" "$TOKEN" | curl -K - "${args[@]}" "$(base)$path") ||
    { rm -f "$out"; fail "request failed: $method $path"; }
  if [[ "$code" != 2* ]]; then
    echo "error: HTTP $code on $method $path" >&2
    head -c 400 "$out" >&2; echo >&2
    rm -f "$out"; exit 1
  fi
  cat "$out"; rm -f "$out"
}

cmd_auth() {
  creds
  local kind err
  for kind in site gateway; do
    BASE=$("${kind}_base") || continue
    # Subshell: api() exits on HTTP errors; keep going to the next candidate.
    if err=$( (api GET "/api/v2/pages?limit=1" >/dev/null) 2>&1 ); then
      mkdir -p "$(dirname "$BASE_CACHE")" && echo "$BASE" > "$BASE_CACHE"
      echo "ok site=$(site) via=$kind user=$EMAIL"
      return 0
    fi
    echo "$kind: $(head -n 1 <<<"$err")" >&2
  done
  rm -f "$BASE_CACHE"
  fail "credentials rejected on the site and the api.atlassian.com gateway: check the token (not expired or revoked; scoped tokens need read:page, write:page and read:comment Confluence scopes) and that the Keychain account is the token owner's Atlassian email"
}

cmd_info() {
  creds
  # slug: title as a kebab-case file name (ASCII only; empty when nothing is left)
  api GET "/api/v2/pages/$1" | jq -r '"version=\(.version.number)\ntitle=\(.title)\nspaceId=\(.spaceId)",
    "slug=\(.title | ascii_downcase | gsub("[^a-z0-9]+"; "-") | ltrimstr("-") | rtrimstr("-"))"'
}

cmd_get() {
  creds
  local id=$1 out=$2 json html
  json=$(mktemp); html=$(mktemp)
  api GET "/api/v2/pages/$id?body-format=storage" > "$json" || { rm -f "$json" "$html"; exit 1; }
  jq -r '.body.storage.value' "$json" > "$html"
  to_md "$html" "$out" "$(store "$id")" || { rm -f "$json" "$html"; fail "conversion to Markdown failed"; }
  jq -r '"version=\(.version.number)\ntitle=\(.title)"' "$json"
  rm -f "$json" "$html"
}

cmd_put() {
  creds
  local id=$1 in=$2 msg=$3 title=${4:-} html cur payload ver
  [[ -f "$in" ]] || setup "file not found: $in"
  html=$(mktemp); cur=$(mktemp); payload=$(mktemp)
  trap 'rm -f "$html" "$cur" "$payload"' RETURN
  to_html "$in" "$html" "$(store "$id")" || { local rc=$?; echo "error: conversion to HTML failed, nothing pushed" >&2; exit $rc; }
  api GET "/api/v2/pages/$id" > "$cur" || exit 1
  ver=$(jq '.version.number' "$cur")
  [[ -n "$title" ]] || title=$(jq -r '.title' "$cur")
  jq -n --arg id "$id" --arg title "$title" --arg msg "$msg" \
        --argjson v "$((ver + 1))" --rawfile body "$html" \
    '{id: $id, status: "current", title: $title,
      body: {representation: "storage", value: $body},
      version: {number: $v, message: $msg}}' > "$payload"
  api PUT "/api/v2/pages/$id" "$payload" | jq -r '"version=\(.version.number)\ntitle=\(.title)"'
}

cmd_create() {
  creds
  local parent=$1 title=$2 cur payload space
  cur=$(mktemp); payload=$(mktemp)
  trap 'rm -f "$cur" "$payload"' RETURN
  api GET "/api/v2/pages/$parent" > "$cur" || exit 1
  space=$(jq -r '.spaceId' "$cur")
  jq -n --arg space "$space" --arg parent "$parent" --arg title "$title" \
    '{spaceId: $space, parentId: $parent, status: "current", title: $title,
      body: {representation: "storage", value: ""}}' > "$payload"
  api POST "/api/v2/pages" "$payload" |
    jq -r '"pageId=\(.id)\nversion=\(.version.number)\ntitle=\(.title)"'
}

cmd_raw() {
  creds
  api GET "/api/v2/pages/$1?body-format=storage" | jq -r '.body.storage.value' > "$2"
}

cmd_comments() {
  creds
  api GET "/api/v2/pages/$1/inline-comments?resolution-status=open&resolution-status=reopened&body-format=storage&limit=100" |
    jq -r '"count=\(.results | length)",
           (.results[] |
             "- id=\(.id) author=\(.version.authorId // "?") on: \"\(.properties.inlineOriginalSelection // "")\"\n  \(.body.storage.value | gsub("<[^>]+>"; "") | gsub("\\s+"; " "))")'
}

# --- local helpers (no credentials) -----------------------------------------

# Lines ending in two spaces or a backslash are hard breaks inside one paragraph.
# On Confluence the whole group is one paragraph, so it cannot be made into a
# list line by line. Fenced code blocks are skipped.
cmd_lint() {
  [[ -f "$1" ]] || setup "file not found: $1"
  awk '
    function flush() { if (from) { n++; print "warning: " (from == to ? "line " from " ends" : "lines " from "-" to " end") " in a forced line break (two spaces or \\); on Confluence they become one paragraph: use a list or blank lines instead" } from = 0 }
    /^[[:space:]]*(```|~~~)/ { flush(); fence = !fence; next }
    !fence && /(  |\\)$/ { if (!from) from = NR; to = NR; next }
    { flush() }
    END { flush(); print "breaks=" n+0 }' "$1"
}

# Workspaces that keep an append-only log.md get one line per sync that wrote.
cmd_log() {
  local id=$1 summary=$2 f=log.md
  if [[ ! -f "$f" ]]; then echo "log=skipped (no log.md)"; return 0; fi
  [[ -s "$f" && -n "$(tail -c1 "$f")" ]] && echo >> "$f"
  printf '%s | confluence %s | %s\n' "$(date +%F)" "$id" "$summary" >> "$f"
  echo "log=written"
}

# --- main -------------------------------------------------------------------

need curl; need jq; need python3
cmd=${1:-}; shift || true
case "$cmd" in
  auth)     cmd_auth ;;
  info)     [[ $# -eq 1 ]] || setup "usage: info <pageId>"; cmd_info "$@" ;;
  get)      [[ $# -eq 2 ]] || setup "usage: get <pageId> <out.md>"; cmd_get "$@" ;;
  put)      [[ $# -ge 3 ]] || setup "usage: put <pageId> <in.md> <message> [title]"; cmd_put "$@" ;;
  create)   [[ $# -eq 2 && -n "$2" ]] || setup "usage: create <parentId> <title>"; cmd_create "$@" ;;
  comments) [[ $# -eq 1 ]] || setup "usage: comments <pageId>"; cmd_comments "$@" ;;
  raw)      [[ $# -eq 2 ]] || setup "usage: raw <pageId> <out.html>"; cmd_raw "$@" ;;
  lint)     [[ $# -eq 1 ]] || setup "usage: lint <in.md>"; cmd_lint "$@" ;;
  log)      [[ $# -eq 2 && -n "$2" ]] || setup "usage: log <pageId> <summary>"; cmd_log "$@" ;;
  to-md)    [[ $# -eq 3 ]] || setup "usage: to-md <in.html> <out.md> <store.json>"; to_md "$@" ;;
  to-html)  [[ $# -eq 3 ]] || setup "usage: to-html <in.md> <out.html> <store.json>"; to_html "$@" ;;
  *)        setup "usage: confluence-api.sh auth|info|get|put|create|comments|raw|lint|log|to-md|to-html ..." ;;
esac
