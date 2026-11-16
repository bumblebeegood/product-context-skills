---
name: draft-spec
description: 'Draft a ticket, user story, or feature spec from the existing Product Context. Produces a fully structured ticket .md file in OUTPUT/Draft/. Use when writing a ticket, drafting a user story, creating a feature request, specifying acceptance criteria, defining user flows, or describing system behavior.'
argument-hint: 'Describe the feature or behavior to ticket (e.g. "user uploads a document")'
metadata:
  version: "2.0.0"
  author: "Illia Shapoval"
---

# Draft

Produces a structured ticket `.md` file in `OUTPUT/Draft/`, using the Product Context as input. Every ticket follows the same 8-section structure.

## When to Use

- "Draft a ticket for …"
- "Write a user story about …"
- "Create a feature spec for …"
- "Specify acceptance criteria for …"

Use **after** the Product Context has the relevant entries. If context is missing, run `context-management` first or ask the user to provide context.

---

## Procedure

### Step 0 — Clarify

Only proceed once the task is clarified.

1. Read `_master-index.md`.
2. Read `OUTPUT/ticket-backlog.md`. Match the request against existing rows by title similarity or subject.
  - If matched: tell the user and use the row's Notes and Dependency as additional context.
  - If the matched row's `Dependency` is non-empty: state the open decision and ask whether it is resolved or should be treated as a known open item.
  - If the matched row's `Draft Created` is non-empty: surface the existing draft URL and ask whether to overwrite, create a new draft alongside it, or abort.
3. **Ask for Figma links.** If the user's request does not contain a Figma URL, ask: *"Are there Figma frames relevant to this draft? If yes, paste the links; if no, confirm to proceed without design context."* Wait for the response.
  - If links are provided **and** the Figma MCP is available, use it to pull frame context (see **Figma MCP** below).
  - If links are provided **and** the Figma MCP is not available, ask the user to paste relevant frame names / descriptions / screenshots instead.
  - If the user confirms no design context: proceed and note the absence in `Inferred Suggestions` if design details remain ambiguous.
4. Look up relevant Workflows, JTBDs, Data Examples, Business Rules, and Business Processes by reading the matching files in the Product Context.
5. Break down the request:
  - **Actors** — who is involved.
  - **Goal** — scope and purpose; related Workflow / JTBD if any.
  - **Steps** — consult the relevant Workflow.
  - **Test approach** — how acceptance can be verified.
  - **Edge cases** — suggested from context.
  - **Out of scope** — only if the user explicitly mentions; do not infer.
6. **Surface terminology conflicts.** If the user introduces new or inconsistent terms vs the Product Context, ask before drafting.

### Step 1 — Compose the ticket

Build the file using the **Ticket Template** below. All 8 sections are produced in order. If a section has no input data (besides Out of Scope, which is dropped when nothing applies), write `TBD` rather than skipping the heading.

### Step 2 — Place the draft

1. Write to `OUTPUT/Draft/<title>.md`. File name = the ticket title.
2. Do not wait for confirmation before placing the file — the user reviews after it is written.
3. If the request matched a backlog row in Step 0: **update that row's `Draft Created` cell** with the absolute git URL pointing at the new draft. Use the **Absolute Repo URL helper** from `.claude/skills/backlog/SKILL.md` (current branch, falls back to asking the user once per session). Do **not** remove the row. The `backlog` skill owns the file format; updating a single cell here is mechanical.

### Step 3 — Log

Append one line to `log.md`:

```
YYYY-MM-DD | prompt | Drafted "<title>" in OUTPUT/Draft/<title>.md[ — backlog row "<title>" updated with Draft Created link].
```

### Step 4 — Suggest next steps

After placing the draft, suggest additions to the Product Context that the ticket implies:

- New JTBDs surfaced by the request.
- New or updated Workflows.
- New Data Example entries (entities or attributes that appeared but aren't yet documented).
- New Business Rules implied by acceptance criteria.
- New backlog candidates implied by the Out of Scope section.

For each, name the target file and the skill that would handle it (`context-management` for context entries, `backlog` for backlog additions). Do not act on suggestions without explicit user instruction.

---

## Figma MCP (optional)

Invoked from Step 0 when the user provides one or more Figma URLs.

### Preflight

Check whether Figma MCP tools (prefix `mcp__figma__*`) are in the tool list.

- **Available** → use the MCP path.
- **Not available** → use the manual fallback.
- **Uncertain** → ask the user once per session whether to use the manual paste-back path.

Never abort the draft because Figma context is missing.

### MCP path

For each Figma URL:

1. Parse the URL to extract the file key and node ID (encoded as `?node-id=…` and `/file/<key>/…` or `/design/<key>/…`).
2. Call the appropriate MCP tool to fetch the target node (frame / page / file).
3. Capture node name, type, child frame names, and any attached annotations.

Surface a short summary of what was retrieved to the user **before composing**, e.g.:

```
Pulled from Figma:
- File: "Checkout Redesign" — node "Step 2 / Address Entry"
- Child frames: Address Entry, Validation Error, Empty State
```

Use the retrieved frame structure to inform:

- **Flow & System Behavior** — frame names typically map to UI states / steps.
- **Entity Attributes** — visible field labels suggest attributes to document.
- **Edge Cases** — empty-state / error-state frames suggest scenarios to cover.

Ignore pixel measurements, exact colours, layer internals, and anything outside the scope of the URL the user provided.

### Manual fallback

Tell the user once that the Figma MCP isn't installed. Ask for any of:

- Frame names / hierarchy from the relevant pages.
- Short descriptions of what each frame shows.
- Screenshots pasted into the prompt.

Proceed with whatever context the user provides. If nothing usable comes back, note the gap in `Inferred Suggestions` (e.g. *"Design context not retrieved from the Figma link(s); flow may need revision once the design is reviewed."*).

### Caching

Cache parsed URL → retrieved frame data for the session. Reuse on a re-draft unless the user says the Figma source changed.

---

## Ticket Template

The file has no frontmatter. The first line of the body is the H1 = the title.

### 1. Title

```
# [user] [action] [entity] [context]
```

Rules:

- **One action verb only.** "Create and update" is two tickets — split and surface to the user.
- `[user]` is a role from `users/`.
- `[action]` is a single present-tense verb (e.g. *uploads*, *approves*, *replaces*, *views*).
- `[entity]` matches a `domain-entities/` file when applicable.
- `[context]` is optional, used only for disambiguation.

Title is also the file name (`OUTPUT/Draft/<title>.md`).

---

### 2. Scope / Goal

One sentence, or 3–5 bullets if a single action requires multiple conditions.

```markdown
## Scope / Goal

The system shall [action or expected outcome] [context or conditions].
```

Or:

```markdown
## Scope / Goal

The system shall allow [user] to [action] when:
- <condition 1>
- <condition 2>
```

Rules:

- Use "The system shall …" phrasing.
- State the goal, not steps or validations.

---

### 3. Expected Result & Acceptance Criteria

```markdown
## Expected Result & Acceptance Criteria

1. <Standalone testable statement>
2. <Standalone testable statement>
```

Rules:

- Each criterion is independently testable.
- State the outcome, not the procedure.
- Reference Business Rules by code where applicable (`BR-PRICING-02 is satisfied: …`).
- Include entity creation and status transitions explicitly.

---

### 4. Entity Attributes & Validations

One H3 sub-section per entity touched.

```markdown
## Entity Attributes & Validations

### <Entity>

| attribute name | type | mandatory | description | limitations/validations | error messages | examples |
|---|---|---|---|---|---|---|
| <attr> | <type> | <Y/N> | <what it represents> | <restrictions> | "<message>" | <1–3 values> |
```

Rules:

- Only attributes the ticket touches — not every attribute of the entity.
- Do not include IDs.
- List enum values explicitly. Specify decimal precision for currency / numeric fields.
- Mark immutability for system-generated fields.
- Error messages in quotes, friendly, actionable.

---

### 5. Error / Edge Cases

```markdown
## Error / Edge Cases

| Scenario | System Behavior | Message Example | Suggested Exit Flow |
|---|---|---|---|
| <what goes wrong> | <how the system handles it> | "<exact user-facing copy>" | <how the user recovers> |
```

Cover the categories that apply:

- Validation errors (missing fields, invalid formats).
- Empty states (no data available).
- System errors (calculation failures, network issues, downstream unavailable).
- Timeouts and session expiry.
- Unexpected exits (browser close, mid-flow navigation).
- Mid-flow data changes (referenced data becomes stale or unavailable).
- Duplicate data.
- Boundary conditions (zero, maximum).
- Concurrent access by multiple users.
- Permissions.

Skip categories that genuinely don't apply.

---

### 6. Out of Scope

```markdown
## Out of Scope

- <Item explicitly excluded by the user>
- <Item explicitly excluded by the user>
```

Rules:

- **Only items the user mentioned explicitly.** Do not infer exclusions.
- **Omit the entire section if there is nothing to list** — this is the only section in the 8 that may be silently dropped.
- Each item is a future-ticket candidate; surface to the user as input to the `backlog` skill after the draft is placed.

---

### 7. Inferred Suggestions

```markdown
## Inferred Suggestions

> The following items are inferred or proposed — they are **not** stated in the source context. Confirm or revise before acceptance.

| Item | Reasoning |
|---|---|
| <inferred item or open question> | <why it is needed or why it was inferred> |
```

Rules:

- The disclaimer line is mandatory.
- Every row has reasoning.
- Phrase as proposals or questions, not statements.
- This is the **only** section where inference is allowed in the draft. Never present an inference as a fact in any other section.

Categories to consider:

- Missing entity attributes (Status, audit fields, version).
- Unstated business rules.
- Default values, time periods, retention windows.
- Format conventions (date, currency, locale).
- UX timing (session timeouts, autosave, auto-refresh).
- Integration points.
- Permission gaps.
- Notifications.
- Localization.

---

## Cross-Section Rules

To avoid duplication:

| Concern                               | Section                         |
| ------------------------------------- | ------------------------------- |
| What data exists and its rules        | Entity Attributes & Validations |
| What if something goes wrong          | Error / Edge Cases              |
| What the system shall do (high level) | Scope / Goal                    |
| What proves the ticket is done        | Acceptance Criteria             |
| What is explicitly excluded           | Out of Scope                    |
| What is inferred or open              | Inferred Suggestions            |

If two sections would say the same thing, the higher-up section wins; the lower one references or omits.

AVOID uncertain language in acceptance criteria or scope statements: 'or', 'optional', 'maybe' - spcify condition instead. Dangerous to infer a condition? - ask user.

| Ambiguity (avoid!)                                   | Clarity (do!)                                                                                                   |
| ---------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| At least, at a minimum, maximize, minimize, optimize | Specify the minimum and maxinum acceptable values                                                               |
| Between X and Y                                      | Including X and / or Y? >,<, =, <=...                                                                           |
| Efficent, fast, quick, rapid                         | Qualify with: min acceptable response time; min acceptable number of requests per second                        |
| Flexible, versatile                                  | Describe specific conditions and how the system must respond to those conditions                                |
| i.e., e.g.                                           | People often confuse i.e. (meaning that is) and e.g. (meaning “for example"). Avoid Latin abbreviations         |
| Improved, better, faster, superior                   | Quantify: how much? Qualify: what is better?                                                                    |
| Shouldn't, wont                                      | State requirements as positives, describing what the system shall do                                            |
| Optionally                                           | Clarify whether this means a developer choice, a system choice, or a user choice. What does this choice entail? |

---

## Constraints

- Use only entities, roles, and rules defined in the Product Context. Do not invent.
- All inferences live in the Inferred Suggestions section and are clearly labelled.
- One action verb per ticket.
- Do not modify Product Context files (workflows, data examples, etc.) — that's `context-management`'s job.
- **Do not remove backlog rows.** The only backlog write permitted from this skill is updating the `Draft Created` cell of a matched row.
- Do not modify `Archive/`, `AGENTS.md`, or anything outside `OUTPUT/Draft/` and the `Draft Created` cell in `OUTPUT/ticket-backlog.md`.
- If the Figma MCP is not available, follow the fallback path rather than aborting.
