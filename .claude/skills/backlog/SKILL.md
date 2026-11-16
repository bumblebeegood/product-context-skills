---
name: backlog
description: 'Maintain OUTPUT/ticket-backlog.md — the single backlog of ticket candidates and their lifecycle (drafted → Jira-linked). Use when adding a backlog entry, updating notes / dependency, marking a draft created, or creating one or more Jira issues from backlog rows. Owns the backlog file format. Uses Atlassian MCP if available, with a manual fallback.'
argument-hint: 'State the operation and target row(s) (e.g. "add backlog entry: editor exports a publication", "create Jira issue for <title>", "create Jira issues for rows in group <group>")'
metadata:
  version: "1.2.0"
  author: "Illia Shapoval"
---

# Backlog

Owns `OUTPUT/ticket-backlog.md`. Adds rows, updates rows, marks drafts created, and creates Jira issues from rows. **Rows are never deleted by this skill.**

The `draft-spec` skill is allowed to update the `Draft Created` cell of a matched row directly — this is the only exception to the rule that only `backlog` writes to the file.

## When to Use

- "Add a backlog entry for …"
- "Update the backlog entry for …"
- "Mark draft created for `<title>` at `<url>`" (rare — usually done by the `draft-spec` skill).
- "Create a Jira issue for `<title>`" / "Create Jira issues for rows in group `<group>`" / "Create Jira issues for: `<a>`, `<b>`, `<c>`".

---

## File Format

`OUTPUT/ticket-backlog.md` contains a single H1 and a single table:

```markdown
# Ticket Backlog

| Title | Group | Source | Notes | Dependency | Draft Created | Jira Ref |
|---|---|---|---|---|---|---|
| <ticket title> | <topic group> | <Jira key or origin> | <context> | <open question or prerequisite> | <absolute git URL or —> | <Jira issue URL or —> |
```

| Column | Rules |
|---|---|
| `Title` | Same format as a ticket Title (`[user] [action] [entity] [context]`, one action verb). |
| `Group` | Short topic noun used to cluster related rows. Reuse existing groups; create new only when none fit. |
| `Source` | Origin: Jira key, file name, "out-of-scope of `<ticket title>`", "user prompt". |
| `Notes` | One or two sentences. Reference related Workflows / Business Rules / JTBDs by file name or code. |
| `Dependency` | Open decision, prerequisite ticket, or missing info that blocks drafting. `—` if none. |
| `Draft Created` | Absolute git URL to the produced draft in `OUTPUT/Draft/`. `—` if no draft yet. Set by the `draft-spec` skill, or by the **Mark Draft Created** operation here. |
| `Jira Ref` | URL of the Jira issue once created. `—` if no issue yet. Set only by the **Create Jira Issue(s)** operation here. |

- **Empty cells use `—` (em dash), never blank.**
- Rows of the same `Group` are kept adjacent. Append within a group.
- **Rows are never deleted.** Lifecycle: `added → drafted → Jira-linked`.

---

## Procedure

### Step 1 — Read
Read `OUTPUT/ticket-backlog.md`. Create it from the template if missing.

### Step 2 — Identify the operation
- **Add** — a new candidate.
- **Update** — an existing row's `Notes` or `Dependency` changes.
- **Mark Draft Created** — populate the `Draft Created` cell with an absolute git URL.
- **Create Jira Issue(s)** — create one or more Jira issues; populate `Jira Ref`.

If ambiguous, ask which operation applies.

### Step 3 — Apply

**Add**
1. Check for near-duplicates by Title or subject. If a duplicate exists, surface it and ask whether to merge `Notes` or skip.
2. Choose the Group: reuse if one fits, else create a new one (noun topic, e.g. `Authentication`).
3. Build the row. Initialize `Draft Created` and `Jira Ref` to `—`.
4. Insert the row at the bottom of its group.

**Update**
1. Locate the row by Title. If multiple match, ask which one.
2. Update only the cells the user specified.
3. Do not change `Source`, `Draft Created`, or `Jira Ref` from this operation — those are managed by their lifecycle steps. If the user explicitly asks to revise one, confirm before changing.

**Mark Draft Created**
1. Locate the row by Title.
2. If `Draft Created` is already populated, surface the existing URL and ask whether to overwrite, append (rare), or abort.
3. Resolve the absolute git URL using the **Absolute Repo URL helper** below.
4. Write the URL into `Draft Created`.

**Create Jira Issue(s)**
1. Resolve the target row(s):
   - Single: by Title.
   - Group: all rows whose `Group` matches.
   - Explicit list: titles supplied by the user.
2. For batches, list matching rows back and ask for confirmation before creating.
3. For each row:
   - Build the Jira payload using the **Jira Issue Format** below.
   - If `Draft Created` is `—`, ask whether to proceed (the `Draft Repo` Jira section will be `—`).
   - Follow the **Jira MCP procedure** below to create the issue.
   - On success: write the returned issue URL into `Jira Ref`.
   - On failure: leave `Jira Ref` as `—`, surface the error, ask whether to retry, skip, or abort the batch.

### Step 4 — Log
Append one line to `log.md`:

```
YYYY-MM-DD | prompt | Backlog: <added|updated|marked-draft|jira-created> row "<title>"[ in group <group>][; Jira: <ref>].
```

If multiple rows changed in one turn (e.g. a Jira batch), append **one** line summarising the batch (count, group, any failures).

---

## Jira Issue Format

Same payload whether the Atlassian MCP is available or not — only the delivery path differs.

### Summary
```
<Title from the backlog row, verbatim>
```

### Description (Jira wiki markup)
```
h1. Source
<Source cell content, or — if empty>

h1. Notes
<Notes cell content, or — if empty>

h1. Dependency
<Dependency cell content, or — if empty>

h1. Draft Repo
<Draft Created cell content (absolute git URL), or — if not yet drafted>
```

### Rules

- The Title goes into the Jira **summary** field, **not** into the description.
- Use Jira **wiki markup** (`h1.`, `*bold*`, `[label|url]` for links), not standard Markdown.
- Cells whose backlog value is `—` render as `—` in the description. Do **not** silently omit a section.
- Exactly four sections in this order: `Source`, `Notes`, `Dependency`, `Draft Repo`. No extras, no preamble.

---

## Jira MCP procedure

### Preflight
Check whether Atlassian MCP tools (prefix `mcp__atlassian__*`) are in the tool list.

- **Available** → use the MCP path.
- **Not available** → use the manual fallback.
- **Uncertain** → ask the user once: *"I don't see an Atlassian MCP tool registered. Use the manual paste-back path?"* Respect the answer for the session.

Never abort because the MCP is missing. Always fall back.

### Session values
Ask each value once per session and reuse:
- **Jira project key** (e.g. `PROJ`, `WEB`). Asked on the first Create Jira Issue call.
- **Jira base URL** (e.g. `https://yourco.atlassian.net`). Needed by the fallback or when validating returned URLs.

### MCP path
Call the create-issue tool with:
- `project` = the project key from session memory
- `summary` = the row's Title
- `description` = the Jira wiki-markup body
- `issuetype` = **`Story`** by default. Override only if the user has explicitly asked for a different type this session (e.g. "create these as Tasks"); remember the override for the rest of the session.

Capture the returned issue URL and return it to **Create Jira Issue(s)** Step 3 for writing into `Jira Ref`.

On error (tool failure, permissions, validation):
- Surface the exact error.
- Ask: retry, skip this row, abort the batch, or fall back to the manual path for this row.

### Manual fallback
Render the full payload for the user to paste into Jira:

```
Project: <project key, or "(please confirm)">
Issue type: Story
Summary: <Title>

Description (paste into Jira's wiki-markup editor):

h1. Source
<Source>

h1. Notes
<Notes>

h1. Dependency
<Dependency or —>

h1. Draft Repo
<Draft Repo URL or —>
```

Ask the user to create the issue and paste the resulting URL back. Write it into `Jira Ref`.

If the user declines to paste a URL, leave `Jira Ref` as `—` and log the row as not-linked.

---

## Absolute Repo URL helper

Used by **Mark Draft Created**, by the `draft-spec` skill (Step 2), and indirectly by **Create Jira Issue(s)** for the `h1. Draft Repo` value.

### Algorithm

1. **Remote URL**: run `git remote get-url origin`. Normalize SSH to HTTPS and strip trailing `.git`:
   - `git@github.com:owner/repo.git` → `https://github.com/owner/repo`
   - `git@gitlab.com:owner/repo.git` → `https://gitlab.com/owner/repo`
   - `git@bitbucket.org:owner/repo.git` → `https://bitbucket.org/owner/repo`
   - Unknown host: keep the host as-is, strip `.git`.
2. **Branch**: run `git rev-parse --abbrev-ref HEAD`. If the result is `HEAD` (detached state), ask the user once per session for the branch to use.
3. **File path**: relative path from the repo root (`git rev-parse --show-toplevel`) to the draft file, e.g. `OUTPUT/Draft/<title>.md`.
4. **Compose** using the host template:
   - GitHub: `<remote>/blob/<branch>/<path>`
   - GitLab: `<remote>/-/blob/<branch>/<path>`
   - Bitbucket: `<remote>/src/<branch>/<path>`
   - Unknown: use the GitHub template and flag the assumption.
5. **URL-encode** spaces and special characters in `<path>`.

### Fallback

If any step fails (no git, no remote, unknown host the user wants to override):
1. Ask once per session: *"I couldn't auto-derive the repo URL. What is the base URL where draft files live? (e.g. `https://github.com/yourco/docs/blob/main`)"*
2. Append the relative path to construct subsequent URLs.

Cache `<remote>` and `<branch>` for the session.

---

## Constraints

- **Only this skill writes new rows or changes existing cells**, except: the `draft-spec` skill may update `Draft Created` mechanically.
- **Never delete rows.** Removal is not a supported operation.
- Do not infer Dependencies. Populate only when the user — or the `draft-spec` skill — explicitly flags one.
- Do not invent backlog entries. Add a row only when a candidate is explicitly identified.
- Do not reorder rows beyond keeping same-Group rows adjacent.
- Do not modify `Archive/`, `AGENTS.md`, Product Context files, or `OUTPUT/Draft/` files.
- **Never claim a Jira issue was created** without a returned URL — if uncertain, treat the operation as failed and leave `Jira Ref` as `—`.

---

## Interaction with the `draft-spec` Skill

- `draft-spec` reads this backlog first and matches the request against existing rows.
- On a match, `draft-spec` uses the row's `Notes` and `Dependency` as additional context. If `Dependency` is non-empty, `draft-spec` surfaces it before proceeding. If `Draft Created` is non-empty, `draft-spec` surfaces the existing draft URL before proceeding.
- After producing the draft, `draft-spec` writes the absolute git URL of the new draft into the row's `Draft Created` cell directly. No invocation of this skill is required for that update.
- The row stays in the backlog. The user may invoke this skill afterwards to create a Jira issue from it.
- When `draft-spec` finishes and produces an `Out of Scope` section, the user may invoke this skill to add each out-of-scope item as a new candidate. This is not automatic.
