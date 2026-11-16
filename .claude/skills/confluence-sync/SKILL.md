---
name: confluence-sync
description: Two-way sync between local Markdown documents and their mapped Confluence pages, creation of new child pages from local documents, and fetching a page into a new local file. Detects content changes on either side since the last sync, then pushes local changes, pulls Confluence changes, or merges both, with a content check after every write. Flags open Confluence comments without blocking. Runs through a REST script (page content never enters the model) or through the Atlassian MCP only. Run manually with /confluence-sync.
argument-hint: "[@source-file] [page-url | page-id] [push | pull | compare | new | replace | fetch] [api | mcp] [\"New page title\"] — any order"
disable-model-invocation: true
context: fork
agent: general-purpose
model: sonnet
background: false
allowed-tools: Read Write Edit Bash(bash .claude/skills/confluence-sync/content-diff.sh *) Bash(bash .claude/skills/confluence-sync/confluence-api.sh *) Bash(cmp *) Bash(grep *) Bash(cp *) Bash(date *) Bash(mkdir *) Bash(mv *) mcp__claude_ai_Atlassian_Rovo
metadata:
  version: "2.2.0"
  author: "Illia Shapoval"
---

# Confluence sync

Keep each Markdown source file listed in `.confluence-sync/manifest.yaml` and its Confluence page in sync. Work from **content diffs**: find what changed on each side since the last sync and carry only those changes to the other side. Never summarize, rewrite, or reformat content. Formatting differences between local Markdown and Confluence (list indentation, table style, escapes, line wrapping) are not changes.

## Inputs

Arguments: `$ARGUMENTS`

**Your task: run the procedure in this file now, for the arguments above.** This file is your instructions, not a document to review or summarise. Do not ask the user what they want, and do not offer options. Resolve the arguments to one of the forms below and carry it out. If they cannot be resolved, return the report with status `error` and the reason.

### Parse the arguments

The arguments are free-form. Tokens can come in any order and can be mixed with plain words. First take out any text in double quotes as one token. Split the rest on whitespace, and classify each token:

| Token looks like | Meaning |
|---|---|
| A path, with or without a leading `@` (e.g. `@docs/spec.md`, `docs/overview.md`, an absolute path) | **Source file.** Remove the leading `@` and any surrounding quotes or angle brackets. Make an absolute path relative to the project root. |
| A URL containing `/wiki/` (e.g. `https://<site>/wiki/spaces/<KEY>/pages/<number>/...` or `https://<site>/wiki/x/<code>`) | **Page URL.** Remove surrounding quotes or angle brackets. |
| A number with 5 or more digits | **Page ID.** |
| Text in double quotes (e.g. `"Going live checklist"`) | **Title** for a new page. Only used with `new`. |
| `push`, `pull`, `compare`, `api`, `mcp`, `init`, `new`, `create`, `replace`, `fetch` (any capitalisation) | **Flag.** `init` means the same as `push`. `create` means the same as `new`. |
| `child`, `children`, `subpage`, `sub-page`, `under`, `beneath`, `below`, `parent` | **Create intent.** Fine together with `new`. Without `new`: status `error`, detail "this looks like a request to create a child page: add `new`, and the URL is then the parent page". Stop. |
| `delete`, `remove`, `move`, `rename`, `copy`, `duplicate`, `archive` | **Unsupported.** Status `error`, detail "unsupported request: <word>. confluence-sync only syncs, and creates child pages with `new`". Stop. |
| Anything else (e.g. "sync", "to", "from", "page", "please", "publish") | Ignore. |

Never guess an intent the flags do not state. A request the table cannot express is an `error`, never a sync of whatever tokens remain.

If the arguments are empty, look in the invoking message for a file mention (`@path`) and a Confluence URL, and use those.

Then pick the form:

| Resolved tokens | Behaviour |
|---|---|
| Nothing | Sync every page in the manifest. |
| One source file | Sync that page only. |
| One source file + a page URL or page ID | Register the page (step 0), then sync it. |
| `new` + one source file + a page URL or page ID | Create a new child page **under** that page (step 0N), then push the file to it. The URL names the **parent**, which is never written to. |
| `fetch` + a page URL or page ID, with or without one source file | Download the page into a **new** local file and link them (step 0F). The source file, when given, is the path to create. An existing file is never overwritten. |
| `fetch` without a page URL or ID | Status `error`, detail "fetch needs the page URL". Stop. |
| `new` without a page URL or ID, or together with `pull` or `compare` | Status `error`, detail "new needs one source file and the parent page URL, and cannot be combined with pull or compare". Stop. |
| `replace` | Confirms that a first push may replace a page that already has content (see step 2). Implies `push`. |
| `push` | Local wins: push local content, and overwrite any Confluence changes. |
| `pull` | Confluence wins: pull page content, and overwrite any local changes. |
| `compare` | Report the changes on both sides and the open comments. Write nothing, on either side. |
| `api` / `mcp` | Choose the transport (see Modes). |
| A source file under `Archive/` or `.Archive/` | Status `error`, detail "files in Archive/ are read-only and never synced". Stop. Nothing is registered or created. |
| A page URL or ID with no source file (without `fetch`), or more than one source file or page | Status `error`, detail "cannot match source file to page". Stop. |
| More than one of `push`, `pull`, `compare` (`replace` and `new` count as `push`, so they combine freely with `push` and with each other; `fetch` counts as `pull`), or both `api` and `mcp` | Status `error`, detail "conflicting flags". Stop. |

## Modes

The procedure is the same in both modes. Only the transport differs.

- **`api`**: the script `confluence-api.sh` calls the Confluence REST API and converts with `confluence-convert.py` (pandoc). Page bodies go straight between files and Confluence, and **never enter your context**. You only see script status lines and `content-diff.sh` output. **Keeps Confluence macros and other Confluence-only elements on push** (see Confluence elements).
- **`mcp`**: Atlassian MCP tools only. Page bodies pass through your context. No credentials or local tools needed beyond this skill. **Cannot keep macros:** an MCP push replaces the page with plain Markdown.

Choose the mode, first match wins:
1. The `api` or `mcp` flag.
2. `mode:` in the manifest.
3. Run `bash .claude/skills/confluence-sync/confluence-api.sh auth`. Exit `0`: `api`. Otherwise: `mcp`, and put the script's error line in the report as a note.

If a script call fails in `api` mode with exit `2` (setup problem), switch to `mcp` for the rest of the run and note it. Exit `1` (API error): retry once, then status `error`.

**Pages with Confluence elements need `api` mode.** A page has elements when `.confluence-sync/<id>.elements.json` exists and is not `{}`, or the source file contains `confluence:` placeholders. For such a page in `mcp` mode (by flag, manifest, or fallback): run `compare` only and give status `needs-api`, detail "page has Confluence macros; api mode is required to keep them". Never push or pull it through MCP.

### Confluence elements

Markdown cannot hold Confluence macros (table of contents, panels, expand, code, status), page links, mentions, images, dates, or layouts. In `api` mode each one becomes a placeholder, written as an inline code span. WYSIWYG Markdown editors display code spans and keep them on save; HTML comments were silently dropped. The element's original storage XML is kept in `.confluence-sync/<id>.elements.json` and put back on push, unchanged:

````
`confluence:toc 1a2b3c4d`                           whole element, not editable here
See `confluence:link 02b17a49 "pricing rules"` for details.        inline element
`confluence:info aaaa1111 "Heads up"`
Panel text, editable like any other Markdown.
`/confluence:info aaaa1111`                         macro with an editable body
`confluence:code 3a4b5c6d`
```text
code, editable; always a fenced block
```
`/confluence:code 3a4b5c6d`
````

- Write new placeholders only in the code-span form, and keep code-macro bodies as fenced blocks.
- Placeholders are content. Diffs show them, and pulls and merges move, add, or remove them in the source file like any other text. Copy them exactly, including the ID. Never invent, edit, or renumber an ID.
- Removing a placeholder locally removes the element from Confluence on the next push. Moving it moves the element.
- The quoted label is only a hint for the reader and is ignored on push. The diff helper ignores IDs and compares element type and label.
- The Fetch prints `info:` lines naming the elements, including elements whose text cannot be edited locally (layouts, task lists). Put them in the report.
- If a push fails with "unknown Confluence placeholder", the element store is missing or stale: run Fetch for the page (to any file), then retry the push once.

### Transport operations

`A` = `bash .claude/skills/confluence-sync/confluence-api.sh`. `S` = `.confluence-sync`. Paths are relative to the project root.

| Operation | `api` mode | `mcp` mode |
|---|---|---|
| **Version** | `A info <id>` prints `version=<n>` | Not available. Always fetch. |
| **Fetch** into `S/<id>.theirs.md` | `A get <id> S/<id>.theirs.md`. It prints `version=<n>`, updates the element store, and may print `info:` or `warning:` lines. | `getConfluencePage` with `contentFormat: markdown`. Write the body unchanged to `S/<id>.theirs.md`. |
| **Comments** | `A comments <id>` prints `count=<n>`, then one entry per comment | `getConfluencePageInlineComments` with `resolutionStatus: open`, `contentFormat: markdown`, `includeReplies: false` |
| **Push** `S/<id>.local.md` | `A put <id> S/<id>.local.md "<message>" [<title>]`. It prints `version=<n>`. | `updateConfluencePage` with `cloudId`, `pageId`, `title` (omit when the manifest has none), `contentFormat: markdown`, `versionMessage: <message>`, `body` = exact content of `S/<id>.local.md` |
| **Read back** into `S/<id>.returned.md` | `A get <id> S/<id>.returned.md` | `getConfluencePage` with `contentFormat: markdown`. Write the body unchanged to `S/<id>.returned.md`. |

`<message>` is `sync from <source> at <current time>`.

In `api` mode, never `Read` the files in `.confluence-sync/`. Work from script and diff output only. `Read` the source file only when you must `Edit` it (steps 4 and 5).

### API mode setup (one time, done by the user)

1. Create a classic API token at https://id.atlassian.com/manage-profile/security/api-tokens ("Create API token", not the scoped variant).
2. In Terminal, store it in the Keychain. Pre-authorizing `/usr/bin/security` avoids a Keychain pop-up on every run:
   ```
   security add-generic-password -s confluence-sync -a <atlassian-email> -T /usr/bin/security -w
   ```
   (It prompts for the token. Paste it, press Enter, and confirm.)
3. `brew install pandoc` if missing.
4. Check: `bash .claude/skills/confluence-sync/confluence-api.sh auth` prints `ok site=… user=…`.

Alternative: env vars `CONFLUENCE_EMAIL` and `CONFLUENCE_API_TOKEN`. The script never prints the token.

Only the script reads credentials. Never read, print, or look for the token yourself: do not query the Keychain, echo the env vars, or pass the token on a command line. If `auth` fails, report its error line and the setup steps above, and do not investigate further.

## Manifest

`.confluence-sync/manifest.yaml` (the folder also holds the state files):

```yaml
cloudId: example.atlassian.net
mode: api                               # optional: api | mcp; omitted = auto
pages:
  - source: docs/overview.md
    pageId: "123456"
    title: Overview                     # optional; omitted = keep the page's current title
    lastSyncedAt: "2026-09-25 22:07"    # empty until the first sync
    version: 7                          # Confluence version at the last sync (api mode)
```

Optional top-level key: `fetchDir: docs/` — the folder where `fetch` puts new files (default: `INPUTS/` when it exists, else the project root).

### 0F. Fetch a page into a new file

Run only with the `fetch` flag. It replaces step 0.

1. Page ID: from the URL or number, as in step 0.1. Manifest missing: create it, as in step 0.2.
2. Page already in the manifest: status `error`, detail "page <pageId> is already linked to <source>: run /confluence-sync @<source> pull to refresh it". Stop.
3. Title and file name:
   - `api` mode: `A info <pageId>` prints `title=` and `slug=`.
   - `mcp` mode: `getConfluencePage` (`contentFormat: markdown`) for the title. Make the slug yourself: lowercase, every run of characters other than `a-z` and `0-9` replaced by one `-`, no `-` at either end.
   - Empty slug: use `page-<pageId>`.
4. Source file, first match wins:
   1. The source file from the arguments.
   2. `<fetchDir>/<slug>.md`, where `fetchDir` is the manifest's `fetchDir`, else `INPUTS/` when that folder exists, else the project root.
5. Source file already exists, or already in the manifest: status `error`, detail "<source> already exists: pass another path, or run /confluence-sync @<source> <page-url> pull to replace its content with the page". Stop. Nothing was written.
6. Create the folder with `mkdir -p` if needed. Append a manifest entry with `source`, `pageId`, and an empty `lastSyncedAt`. Leave `title` out.
7. Continue with step 1, as a first sync with `pull` (step 1.1 creates the empty file). Use status `fetched` instead of `pulled`.

### 0N. Create a child page

Run only with the `new` flag. It replaces step 0.

1. Parent page ID: from the URL or number, as in step 0.1.
2. Manifest missing: create it, as in step 0.2.
3. Source already in the manifest: status `error`, detail "<source> is already linked to page <pageId>; new would create a second page". Stop.
4. Source file missing: status `error`, detail "source file not found". Stop.
5. Title, first match wins:
   1. The quoted text from the arguments.
   2. The first `# ` heading in the source: `grep -m1 '^# ' <source>`, without the leading `# `.
   3. The file name without its extension, with `-` and `_` turned into spaces, first letter capitalised.
6. Create the page:
   - `api` mode: `A create <parentId> "<title>"`. It prints `pageId=<n>`.
   - `mcp` mode: `getConfluencePage` on the parent (`contentFormat: markdown`) for its `spaceId`, then `createConfluencePage` with `cloudId`, `spaceId`, `parentId` = the parent ID, `title`, `contentFormat: markdown`, `body: ""`. Take the new page ID from the result.
   - Failure (for example "a page with this title already exists"): status `error` with the API message and the hint "pass another title in double quotes". Stop. Nothing was created.
7. Append a manifest entry with `source`, `pageId` = the new page ID, `title`, and an empty `lastSyncedAt`.
8. Continue with step 1, as a first sync with `push`. Report the new page as `https://<cloudId>/wiki/pages/viewpage.action?pageId=<pageId>`, and use status `created` instead of `pushed`.

### 0. Register

Run only when the arguments contain a page URL or page ID, without `new` or `fetch`.

1. Page ID:
   - URL of the form `https://<site>/wiki/spaces/<KEY>/pages/<number>/...`: the page ID is `<number>`.
   - URL of the form `https://<site>/wiki/x/<code>`: the page ID is `<code>`.
   - A bare number: the page ID is that number.
2. Manifest missing: create `.confluence-sync/manifest.yaml` (and the folder) with `cloudId` and an empty `pages` list. Take `cloudId` from the URL host (for example `example.atlassian.net`). With a bare ID and no manifest: status `error`, detail "cloudId unknown, pass the full page URL". Stop.
3. Source already in the manifest with the same page ID: continue.
4. Source already in the manifest with a different page ID: status `error`. Stop.
5. Source not in the manifest: append an entry with `source`, `pageId`, and an empty `lastSyncedAt`. Leave `title` out.
6. Continue with step 1.

## State files

State files live in `.confluence-sync/`. Create the folder if missing. `<id>` is the pageId.

| File | Content |
|---|---|
| `<id>.base.md` | Local body at the last sync (frontmatter removed) |
| `<id>.confluence.md` | Confluence body (Markdown) at the last sync |
| `<id>.local.md` | Current local body (frontmatter removed) |
| `<id>.theirs.md` | Current Confluence body (Markdown) |
| `<id>.returned.md` | Confluence body read back after a push |
| `<id>.backup.md` | Copy of the source file before a pull or merge edits it |
| `<id>.elements.json` | Storage XML of the page's Confluence elements, keyed by placeholder ID (`api` mode). Never edit or delete it. |

`<id>.base.md` and `<id>.confluence.md` hold the same content in two formats, and together they are the common ancestor for both diffs. The helper compares them correctly even when one came from `api` mode and the other from `mcp` mode.

## Content diff

Always compare with the helper script. It normalizes both bodies and diffs them with `git diff --no-index`. Never compare Markdown bodies by eye, with plain `diff`, or with `git diff` on the raw files.

```
bash .claude/skills/confluence-sync/content-diff.sh <words|lines> <file-a> <file-b>
```

Exit code `0` = same content, `1` = content differs (the diff is printed), `2` = error.

- `words`: decides on the word sequence only, so line wrapping is ignored. Shows changes inline as `[-old-]{+new+}`. **Use it for every change check and every verification.** Use its output to find the exact words to edit.
- `lines`: plain line diff. Use it only when you need to see which whole lines or table rows were added or removed.

## Procedure per page

Run the steps in order. "Stop" ends work on the current page. Continue with the next page.

### 1. Read both sides

0. Source under `Archive/` or `.Archive/` (possible when syncing the whole manifest): status `error`, detail "files in Archive/ are read-only and never synced: remove this manifest entry". Stop.
1. Source file missing:
   - With `pull`: create an empty source file and continue. The pull will fill it.
   - Otherwise: status `error`, detail "source file not found". Stop.
2. Read the source file's body into `<id>.local.md`: copy it with `cp` when it has no YAML frontmatter; otherwise write it without the leading frontmatter block.
3. **Comments.** Run the Comments operation. When there are open comments, record them for the report's **Open comments** block. Open comments never stop the sync.
4. **Confluence side.**
   - `api` mode, not a first sync, and `A info <id>` prints the same `version` as the manifest: Confluence is unchanged. Skip the fetch.
   - Otherwise: run Fetch. Keep any `warning:` line for the report.

### 2. Detect changes

First sync (`lastSyncedAt` empty, or `<id>.base.md` missing):
- With `compare`: report "first sync, no baseline" and stop.
- With `pull`: go to step 4.
- With `push`, `replace`, or `new`, or when the page was just registered in step 0: run the **replace guard**, then go to step 3.
- Otherwise: status `needs-init`, detail "first sync: add push or pull". Stop.

**Replace guard.** A first push replaces the whole page. If the page already has content, `grep -q '[^[:space:]]' .confluence-sync/<id>.theirs.md` succeeds. Unless the `replace` flag was given: status `needs-confirm`, detail "page '<title>' already has content, and a first push would replace all of it: re-run with replace to confirm, or with pull to start from the page". In the report, list the page's headings (`grep -m10 '^#' .confluence-sync/<id>.theirs.md`) so the user can recognise the page. Stop. Nothing was written. A new page (`new`) or an empty page passes the guard.

Otherwise:
1. **Local changed:** `cmp -s <id>.local.md <id>.base.md` exits non-zero **and** `content-diff.sh words <id>.base.md <id>.local.md` exits `1`.
2. **Confluence changed:** it was fetched **and** `content-diff.sh words <id>.confluence.md <id>.theirs.md` exits `1`.
3. `compare` flag: status `compared`. Put both diffs in the report. Stop.
4. Choose the action:

   | Local changed | Confluence changed | Flag | Action |
   |---|---|---|---|
   | no | no | none | Status `unchanged`. Stop. |
   | yes | no | none | Push (step 3) |
   | no | yes | none | Pull (step 4) |
   | yes | yes | none | Merge (step 5) |
   | any | any | `push` | Push (step 3). Confluence changes are overwritten. In `api` mode, Fetch first if it was skipped, so that the overwritten changes can be reported. |
   | any | any | `pull` | Pull (step 4). Local changes are overwritten. Fetch first if it was skipped. |

### 3. Push

0. **Element guard.** Compare placeholder IDs: `grep -o 'confluence:[^ ]* [0-9a-f]\{8\}'` on `<id>.base.md` and on `<id>.local.md`. If any ID from the base is missing locally, the push would delete those Confluence elements. WYSIWYG Markdown editors (e.g. "Markdown for Humans") often drop HTML comments on save without the user noticing. Unless the `push` flag was given: status `elements-removed`. List the missing elements (type, ID, label) and the local text changes in the report, with the hint "restore the placeholders, or re-run with push to delete these elements". Stop.
0b. **Line-break check.** Run `A lint <source>` (works in both modes, no API call). Put each `warning:` line in the report's Notes. It never stops the push.
1. Run Push.
2. **Verify.** Run Read back, then `content-diff.sh words <id>.local.md <id>.returned.md`.
   - Exit `0`: go to 3.
   - Exit `1`: repeat 1 and 2 once. Second failure: status `verify-failed`. Put the diff in the report. Stop.
3. **Record.** `cp <id>.local.md <id>.base.md`. `mv <id>.returned.md <id>.confluence.md`. In `api` mode, write the pushed `version` to the manifest. Go to step 6. Status `pushed` (`merged` when coming from step 5).

### 4. Pull

1. `cp <source> .confluence-sync/<id>.backup.md`.
2. Get the changes: `content-diff.sh words <id>.confluence.md <id>.theirs.md`. On a first sync, or with `pull` when local also changed, the target is the whole of `<id>.theirs.md`.
3. **Apply to the source file.** The word diff hides placeholder IDs, and the text after `@@ … @@` is only git's nearest heading, not the position. For exact lines and positions, grep the fetched page for the changed text with context, e.g. `grep -n -B3 -A3 -E 'confluence:|<changed words>' .confluence-sync/<id>.theirs.md`. For each change, find the matching spot in the source file and apply the same content change with `Edit`. Keep the source file's own formatting (list markers, indentation, table style, blank lines, frontmatter). Change only the text the diff shows as changed. On a first sync, or when the changes cannot be matched, copy `<id>.theirs.md` over the body with `cp` (then restore any frontmatter with `Edit`).
4. **Verify.** Run `content-diff.sh words <source> <id>.theirs.md`.
   - Exit `0`: go to 5.
   - Exit `1`: fix the remaining differences once and re-run. Still `1`: restore the source with `cp .confluence-sync/<id>.backup.md <source>`. Status `pull-failed`. Put the diff in the report. Stop.
5. **Record.** Refresh `<id>.local.md` from the source as in step 1.2, then `cp <id>.local.md <id>.base.md` and `cp <id>.theirs.md <id>.confluence.md`. In `api` mode, write the fetched `version` to the manifest. Go to step 6. Status `pulled` (`fetched` when coming from step 0F).

### 5. Merge (both sides changed)

1. Get both diffs with `words`:
   - Local: `content-diff.sh words <id>.base.md <id>.local.md`
   - Confluence: `content-diff.sh words <id>.confluence.md <id>.theirs.md`
2. **Overlap check.** The two sides conflict when both diffs change words in the same paragraph, list item, or table row. Conflict: status `conflict`. Put both diffs in the report, with the hint "re-run with push (keep local) or pull (keep Confluence), or edit one side by hand". Stop. Do not change either side.
3. **Apply Confluence changes locally.** `cp <source> .confluence-sync/<id>.backup.md`. Apply each Confluence change to the source file with `Edit`, exactly as in step 4.3.
4. **Verify the merge.** Refresh `<id>.local.md` from the source. Run `content-diff.sh words <id>.theirs.md <id>.local.md`. The output must contain only the local changes from 5.1. Anything else: restore the backup, status `conflict`, report both diffs. Stop.
5. Run step 3 (push).

### 6. Timestamp

Run `date '+%Y-%m-%d %H:%M'`. Write the result to `lastSyncedAt` for this page in the manifest.

### 7. Log

For status `created`, `fetched`, `pushed`, `pulled`, or `merged` only: run `A log <pageId> "<status> <source>: <what moved, as in Details> (v<version>)"`. It appends one line to `log.md` at the project root when that file exists, and does nothing otherwise. Never create `log.md` or write to it any other way. If the call fails, add a note and continue.

## Rules

- Change the source file only in steps 4 and 5, only to apply Confluence content changes, and only after writing `<id>.backup.md`.
- Never push when the status is `conflict`, `verify-failed`, or `pull-failed`.
- Never overwrite changes on either side without the `push` or `pull` flag.
- Never replace a page with existing content on a first push without the `replace` flag.
- Never write to a parent page given with `new`. Only the page created in step 0N is written.
- `fetch` never overwrites a file and never writes to Confluence.
- `compare` writes nothing: no source edits, no push, no state or manifest changes.
- Open comments are reported, never a reason to stop.
- Retry a failed MCP or script call once. A second failure gives status `error`.
- Never sync a source file under `Archive/` or `.Archive/`.
- Never touch credentials (see API mode setup).
- Outside `.confluence-sync/`, write only the source file (steps 4 and 5) and `log.md` (step 7, through the script). Leave indexes and other workspace files to the main agent: the Follow-up block tells it what changed.

## Report

Return one table, followed by the blocks below it:

| Source | Page ID | Mode | Status | Details |
|---|---|---|---|---|

Statuses: `unchanged`, `compared`, `created`, `fetched`, `pushed`, `pulled`, `merged`, `needs-init`, `needs-confirm`, `needs-api`, `elements-removed`, `conflict`, `verify-failed`, `pull-failed`, `error`.

In Details, summarise what moved in which direction (e.g. "2 paragraphs edited on Confluence, pulled").

Below the table, for each page:

1. **Open comments** (whenever any were found, whatever the status): start with the line `⚠ <n> open comment(s) on Confluence. Resolve them there.` Then list each comment's ID, author, highlighted text, and body. When this run pushed, add: "The push replaced the page body. Highlights of these comments may have been detached, but the comments themselves still exist."
2. **Notes** from Fetch (`info:` and `warning:` lines, e.g. Confluence elements kept as placeholders), plus any mode fallback note.
3. **Diffs:** none for `fetched` (give the file's line count instead); the applied diff for `created`, `pushed`, `pulled`, and `merged`; both diffs for `compared` and `conflict`; the failing diff for `verify-failed` and `pull-failed`.
4. **Follow-up** for `fetched`: `New local file from Confluence: <source>, linked to page <pageId>.` Add the step 7 log line result.
   **Follow-up** for `pulled` and `merged`, which changed the local file: `Local file changed from Confluence: <source>. Review the pulled edits against the workspace, and update indexes that summarise this file.` Add `Logged to log.md.` or `No log.md: not logged.` from the step 7 output.
