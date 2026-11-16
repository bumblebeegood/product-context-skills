# confluence-sync

A Claude Code skill that keeps local Markdown documents and their Confluence pages in sync, in both directions, and can publish a local document as a new child page. You write and review in whichever place suits you: edit locally with Claude, let stakeholders edit or comment on Confluence. `/confluence-sync` works out what changed where and carries only those changes across.

## What problems it solves

- **Copy-paste drift.** Documents drafted locally (PRDs, specs) end up edited on Confluence too. Copying whole pages back and forth silently overwrites someone's edits. This skill compares each side against the last sync and moves only real changes.
- **Formatting noise.** Confluence rewrites Markdown on every round trip: list indentation, table layout, escapes, line breaks. A naive diff reports hundreds of false changes. The skill compares **content**, not formatting.
- **Macros destroyed by pushes.** Pushing Markdown replaces the page body, which normally kills tables of contents, panels, code macros, page links, and images. The skill keeps them as placeholders locally and restores them, byte for byte, on push.
- **Expensive, error-prone LLM round trips.** Through the Atlassian MCP alone, the whole page passes through the model on every sync, and the model has to retype it. In `api` mode, page content goes straight from file to Confluence through a script. The model only ever sees diffs.
- **Review comments going unnoticed.** Every run reports open inline comments on the page, without blocking the sync.

## How it works

For each mapped page the skill keeps a baseline: the local file and the Confluence page as they were at the last sync. On each run it:

1. Reads both sides. It reports open Confluence comments.
2. Diffs each side against its baseline, content only.
3. Acts on what it finds:

   | Local changed | Confluence changed | Result |
   |---|---|---|
   | no | no | `unchanged` |
   | yes | no | **push** |
   | no | yes | **pull**: only the changed text is edited into your file, and your formatting is kept |
   | yes | yes | **merge** if the edits don't overlap, otherwise `conflict` (nothing is written) |

4. Verifies every write by reading the result back and comparing content. A failed pull restores your file from a backup.

### Two modes

| | `api` (recommended) | `mcp` |
|---|---|---|
| Transport | `confluence-api.sh`: Confluence REST API, with conversion by `pandoc` | Atlassian MCP tools only |
| Page content in the model's context | No. Only diffs. | Yes, and the model retypes it into files |
| Keeps macros and other Confluence elements on push | Yes | No. Pages with elements are compare-only in this mode (`needs-api`). |
| Needs | API token in the Keychain, `pandoc` | Atlassian MCP connector only |

The mode is picked automatically. It's `api` when the script can log in, otherwise `mcp`. You can force either with a flag, or with `mode:` in the manifest.

### Confluence elements as placeholders (api mode)

Markdown can't represent Confluence macros, page links, mentions, images, dates, or layouts. In the local file each one becomes an inline-code placeholder, and its original XML is saved in `.confluence-sync/<pageId>.elements.json`:

````markdown
`confluence:toc 1a2b3c4d`
See `confluence:link 5e6f7a8b "Onboarding guide"` for details.

`confluence:info 9c0d1e2f "Heads up"`

Panel text: edit it like normal Markdown.

`/confluence:info 9c0d1e2f`

`confluence:code 3a4b5c6d`

```text
code: editable, always a fenced block
```

`/confluence:code 3a4b5c6d`
````

- **Move** a placeholder and the element moves on the next push. **Delete** it and the element is deleted. For safety, the skill refuses to push when placeholders have disappeared, unless you add `push` (see *Editing tips*).
- Text inside panels, expand sections and code macros is editable. Text inside layouts and task lists is kept, but not editable locally.
- The quoted label is just a readable hint.

## Dependencies

| Tool | Needed for | Check |
|---|---|---|
| Claude Code, with the Atlassian (Rovo) MCP connector | Running the skill; `mcp` mode; comment author names | `/mcp` |
| `git` | The content diff (`git diff --no-index`, no repository needed) | `git --version` (on macOS: accept the Xcode license once with `sudo xcodebuild -license`) |
| `python3` (standard library only) | Markdown ↔ Confluence conversion | `python3 --version` |
| `pandoc` | Conversion (`api` mode) | `brew install pandoc` |
| `curl`, `jq` | REST calls (`api` mode) | Preinstalled on recent macOS |
| macOS Keychain (`security`) | Storing the API token (`api` mode) | Built in. On other systems, use environment variables instead. |

## Setup

### 1. Store an Atlassian API token (for `api` mode)

1. Create a **classic** token at <https://id.atlassian.com/manage-profile/security/api-tokens> ("Create API token"). Scoped tokens also work, through Atlassian's API gateway, if they have the Confluence page and comment read/write scopes.
2. Store it in the Keychain **from your own Terminal**:
   ```sh
   security add-generic-password -s confluence-sync -a <your-atlassian-email> -T /usr/bin/security -w
   ```
   The command prompts for the token. `-T /usr/bin/security` stops macOS asking for Keychain access on every run. Create the item this way, not in Keychain Access or the Passwords app: the script can't find items created there.
3. Check it:
   ```sh
   bash .claude/skills/confluence-sync/confluence-api.sh auth
   # ok site=<site>.atlassian.net via=site user=<email>
   ```

The script reads the token itself and passes it to `curl` on stdin. The token never appears in output, on the command line, or in Claude's context. Instead of the Keychain you can set `CONFLUENCE_EMAIL` and `CONFLUENCE_API_TOKEN`.

### 2. Link a document to a page

Run the skill with the file and the page URL, in any order:

```
/confluence-sync @docs/spec.md https://<site>.atlassian.net/wiki/spaces/<KEY>/pages/<pageId>/<Title> push
```

This registers the page in `.confluence-sync/manifest.yaml`. The first sync needs a direction: `push` (local → Confluence) or `pull` (Confluence → local). If the page already has content, a first `push` stops with `needs-confirm`; add `replace` to overwrite it. To publish the document as a **new** page instead, use `new` with the parent page's URL (example 2 below).

## Usage

```
/confluence-sync                              sync every mapped page
/confluence-sync @docs/spec.md                sync one page
/confluence-sync compare @docs/spec.md        show changes on both sides, write nothing
/confluence-sync pull @docs/spec.md           Confluence wins (overwrites local changes)
/confluence-sync push @docs/spec.md           local wins (overwrites Confluence changes)
/confluence-sync mcp @docs/spec.md            force MCP mode
/confluence-sync new @docs/spec.md <parent-url>   create a child page and publish to it
/confluence-sync fetch <page-url>             download a page into a new local file
```

### Arguments

| Argument | Form | Effect |
|---|---|---|
| Source file | `@docs/spec.md`, `docs/spec.md`, or an absolute path | The local Markdown file to sync. Omit it to sync every page in the manifest. |
| Page | A page URL (`https://<site>.atlassian.net/wiki/spaces/<KEY>/pages/<pageId>/...` or `/wiki/x/<code>`) or a bare page ID | Links the file to that page (registration). Only needed the first time. |
| `push` | flag | Local wins. Also the direction for a first sync. |
| `new` (or `create`) | flag | Create a new child page under the given page, then push the file to it. The URL is the **parent**, which is never written to. |
| `"Page title"` | text in double quotes | Title for a page made with `new`. Default: the file's first `# ` heading, then the file name. |
| `replace` | flag | Allow a first push to overwrite a page that already has content. Implies `push`. |
| `fetch` | flag | Download the page into a new local file and link them. Named from the page title (`INPUTS/<title-slug>.md`), or give a path. Never overwrites an existing file. |
| `pull` | flag | Confluence wins. Also the direction for a first sync, and creates the local file if it doesn't exist. |
| `compare` | flag | Report the changes on both sides and the open comments. Writes nothing. |
| `api` / `mcp` | flag | Force the transport. The default is automatic. |

Arguments are free-form and can come in any order, mixed with plain words: `/confluence-sync pull the latest review edits into @docs/spec.md` works. Words that ask for something the flags can't express stop the run with `error` rather than being ignored: `child` or `under` without `new`, and `delete`, `move`, `rename`, `copy`, `duplicate` or `archive`. The skill only runs when invoked as `/confluence-sync`. Asking in plain language ("sync my spec to Confluence") won't start it.

### Example prompts

**1. Publish a local document to an existing Confluence page.** Create an empty page in Confluence, copy its URL, then run:

```
/confluence-sync @docs/spec.md https://<site>.atlassian.net/wiki/spaces/<KEY>/pages/<pageId>/<Title> push
```

The skill registers the page in the manifest and pushes the file. Later runs need only the file. If the page isn't empty, the skill stops with `needs-confirm` and lists the page's headings. Re-run with `replace` instead of `push` to overwrite it.

**2. Publish a local document as a new child page.** Copy the URL of the page it should sit under:

```
/confluence-sync @docs/spec.md new under https://<site>.atlassian.net/wiki/spaces/<KEY>/pages/<parentId>/<Parent+Title>
/confluence-sync @docs/spec.md new "Spec v2 (draft)" <parent-url>
```

The skill creates the page, titled from the file's first `# ` heading or from the quoted title, links the file to it, and pushes. Status `created`, with a link to the new page. The parent page is untouched. If the title is already taken in the space, the run stops with `error`; pass another title in quotes.

**3. Start a local copy of an existing Confluence page.**

```
/confluence-sync fetch https://<site>.atlassian.net/wiki/spaces/<KEY>/pages/<pageId>/<Title>
/confluence-sync fetch @docs/runbook.md <page-url>
```

The skill creates a new file from the page, links the two in the manifest, and turns any macros into placeholders. Status `fetched`. Without a path, the file is named after the page title: "Release Runbook" becomes `INPUTS/release-runbook.md` (or `<fetchDir>/…` when the manifest sets `fetchDir`, and the project root when there is no `INPUTS/`). The run stops with `error`, and writes nothing, if the file already exists or the page is already linked to another file. From then on, edit the file locally or on Confluence and sync both ways.

To replace an existing file with a page's content instead, use `pull` with the file: `/confluence-sync pull @docs/runbook.md <page-url>`. The file's old content is kept in `.confluence-sync/<pageId>.backup.md`.

**4. Routine sync after editing on either side.**

```
/confluence-sync @docs/spec.md
```

The skill pushes your local edits, pulls Confluence edits into your file, or merges both when they touch different passages. It also lists any open review comments. Run `/confluence-sync` with no arguments to do this for every mapped page. To avoid API setup on a page without macros, add `mcp`: `/confluence-sync mcp @docs/spec.md`.

**5. Check both sides first, then settle a conflict.**

```
/confluence-sync compare @docs/spec.md
```

This shows what changed locally and on Confluence since the last sync, plus open comments, and writes nothing. If a normal sync then reports `conflict`, because both sides edited the same passage, decide which side wins:

```
/confluence-sync push @docs/spec.md     keep the local version
/confluence-sync pull @docs/spec.md     keep the Confluence version
```

### Report

Each run returns a table (`Source | Page ID | Mode | Status | Details`), followed by:
- **⚠ Open comments:** shown whenever there are unresolved inline comments. They never block the sync.
- **Notes:** Confluence elements found, forced line breaks in the file (see Editing tips), and any mode fallback.
- **Diffs:** what moved in which direction, or both sides for `compare` and `conflict`.
- **Follow-up:** after `pulled` or `merged`, names the local file that changed, so the main session can review the pulled edits and update anything that summarises the file (indexes, for example).

| Status | Meaning |
|---|---|
| `unchanged` | Nothing to do |
| `compared` | `compare` run. Nothing written. |
| `created` | New child page created, pushed and verified |
| `fetched` | Page downloaded into a new local file and linked |
| `pushed` / `pulled` / `merged` | Done and verified |
| `needs-init` | First sync. Add `push` or `pull`. |
| `needs-confirm` | A first push would replace a page that already has content. Re-run with `replace`, or with `pull` to start from the page. |
| `needs-api` | The page has Confluence elements, and MCP mode can't keep them |
| `elements-removed` | Local placeholders disappeared. Restore them, or re-run with `push` to delete the elements. |
| `conflict` | Both sides edited the same passage. Re-run with `push` or `pull`, or fix one side by hand. |
| `verify-failed` / `pull-failed` | The write didn't verify. A failed pull restores your file. |
| `error` | Setup or API problem (details in the report) |

## Editing tips

- **WYSIWYG editors** (e.g. "Markdown for Humans" in VS Code) re-save the whole file. Placeholders are code spans, and code macros are fenced blocks, so they survive. Still, glance at the placeholder lines after editing. If any go missing, the skill stops with `elements-removed` instead of deleting the elements on Confluence.
- **Resolve comments before pushing** if you can. A push replaces the page body, so comment highlights on the page may come loose. The comments themselves remain.
- **Lists, not line breaks.** A line ending in two spaces or `\` is a line break inside one paragraph. On Confluence the whole group becomes one paragraph, and the list button then bullets it as a single item. Write line groups as real lists (`- item`), or separate them with blank lines. Every push checks for this and lists the lines in Notes. It never blocks.
- **Don't edit files in `.confluence-sync/`.** They are the sync baseline and the element store.

## Files

```
.claude/skills/confluence-sync/
  SKILL.md                 the procedure Claude follows
  confluence-api.sh        REST client: auth, info, get, put, create, comments, raw;
                           local helpers: lint (forced line breaks), log (append to log.md)
  confluence-convert.py    Markdown ↔ Confluence storage conversion, placeholders
  content-diff.sh          content-only diff (git), used for every comparison
.confluence-sync/
  manifest.yaml            site, mode, and page mappings (source, pageId, version, lastSyncedAt)
  <pageId>.base.md         local body at the last sync
  <pageId>.confluence.md   Confluence body at the last sync
  <pageId>.elements.json   stored XML for placeholders
  .api-base                which API endpoint worked (site or gateway)
```

Manifest example:

```yaml
cloudId: example.atlassian.net
mode: api                     # optional: api | mcp; omitted = auto
fetchDir: docs/               # optional: where fetch puts new files; default INPUTS/, else the root
pages:
  - source: docs/spec.md
    pageId: "123456"
    title: Product Spec           # optional; omitted = keep the page's current title
    lastSyncedAt: "2026-01-15 10:30"
    version: 12
```

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `auth`: "no API token" | No Keychain item with service `confluence-sync`. Create it with the `security add-generic-password` command above. |
| `auth`: HTTP 403 "caller cannot access Confluence", or 404 on your own page | The token wasn't accepted, so Confluence treats the request as anonymous. 1. The token may have been cut off when pasted, or be expired or revoked. Pasting of the token in terminal as password may cut it, verify / edit the entry in keychain app |
| `git` or `python3` fails with an Xcode license message | Run `sudo xcodebuild -license` once. |
| Push: "unknown Confluence placeholder" | The element store is missing or stale. Run a `compare` or `pull` first to refresh it. |
| A stray word such as `none` appears in fetched text | A macro setting leaked through conversion. Report it: the converter should drop macro parameters. |

## Workspace integration

The skill runs in a forked agent. It sees only `SKILL.md` and your arguments, not the workspace's `CLAUDE.md` or `AGENTS.md`. So the workspace rules that concern the sync itself are built into the skill:

- **`Archive/` and `.Archive/` are read-only.** A source file there is refused with `error`, and nothing is registered or created.
- **`log.md`:** if the project root has one, every run that writes (`created`, `pushed`, `pulled`, `merged`) appends `YYYY-MM-DD | confluence <pageId> | <summary>`. Without `log.md`, nothing is logged, and the skill never creates it.
- **Credentials:** only `confluence-api.sh` reads the token. The agent never looks for it.
- **Everything else** (reviewing pulled edits, updating indexes) is left to the main session, prompted by the report's Follow-up block. For the main session to follow the workspace rules, Claude Code must load them: it reads `CLAUDE.md`, not `AGENTS.md`, so keep a `CLAUDE.md` containing `@AGENTS.md`.

## Limitations

- Comment highlights are not re-attached after a push. Only the comments survive.
- Layouts and task lists are kept, but their text isn't editable locally.
- Very rich Confluence content (e.g. merged table cells) may simplify on conversion. Check the diff before pushing such pages.
- The skill runs on one model for both modes: Sonnet (`model: sonnet` in `SKILL.md`). Haiku was cheaper, but it didn't reliably run the procedure: it sometimes answered with a question instead.
- `new` creates pages only as children of an existing page, not at the top level of a space.
