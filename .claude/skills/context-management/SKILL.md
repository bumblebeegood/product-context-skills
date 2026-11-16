---
name: context-management
description: 'Interpret raw user inputs and turn them into structured Product Context files. Use when the user asks to process inputs, read a file from INPUTS/, add to the context, or update an existing context entry. Classifies content into Business Rule / JTBD / Workflow / Data Example / Business Process / Product Description and writes the matching file in the right folder.'
argument-hint: 'Point to the input (e.g. "process INPUTS/auth-notes.md") or paste content to be structured'
metadata:
  version: "2.0.0"
  author: "Illia Shapoval"
---

# Context Management

Turns user input into structured Product Context files.

## When to Use

- "Process `INPUTS/<file>`" or "read this and update the context."
- "Add the following to the context: …"
- "Update the workflow for `<operation>`" / "extend the `<entity>` data example."

---

## Procedure

### Step 1 — Orient

1. Read `_master-index.md`.
2. Identify the input: file(s) named by the user in `INPUTS/`, or content pasted in the prompt.
3. If the workspace is missing core files, follow **Project Setup** in `AGENTS.md` first.

### Step 2 — Classify

Split the input into pieces. For each piece, choose its concept type using these tests:

| Test                                                  | Concept                 | Target file                                   |
| ----------------------------------------------------- | ----------------------- | --------------------------------------------- |
| `If [criteria], then [outcome]` — domain logic, no UI | **Business Rule**       | `Business-rules.md`                           |
| A user goal / outcome, no steps, no UI                | **JTBD**                | `users/<group>.md` (JTBDs section) |
| Step-by-step user operation in the system, one role   | **Workflow**            | `workflows/<operation>.md`                    |
| Attributes / fields of a domain entity                | **Data Example**        | `domain-entities/<entity>.md`                   |
| End-to-end process across roles                       | **Business Process**    | `business-processes/<process>.md`             |
| Product purpose, user groups, roadmap                 | **Product Description** | `product-context/<product>.md`    |
| User group description, RBAC                          | **User Information**    | `users/<group>.md` (RBAC section)  |

If a piece matches **none** or **more than one** test → ask the user before writing.

### Step 3 — Review against existing context

Before writing, surface:

- duplicates,
- conflicts,
- new or inconsistent terminology.

Wait for the user to resolve before writing.

### Step 4 — Apply the file structure

Use the matching structure from the section **File Structures** below. Never invent content; if a mandatory field has no source data, write `TBD`.

### Step 5 — Update indexes

Same turn as the content change:

- Update the folder `_index.md`.
- Update the root `_master-index.md`.

### Step 6 — Summarize and wait

Present a table to the user:

| File                           | Action  | Concept  |
| ------------------------------ | ------- | -------- |
| `workflows/import-document.md` | Created | Workflow |
| `_master-index.md`             | Updated | —        |

Wait for explicit confirmation.

### Step 7 — Archive and log

After confirmation:

1. Move `INPUTS/` source files to `Archive/`. (Skip if input came from the prompt.)
2. Append one line to `log.md`:
  ```
   YYYY-MM-DD | <source file or "prompt"> | <one-sentence summary>
  ```

---

## File Structures

### Business Rule — `Business-rules.md`

A single root-level file with all rules, grouped by topic under H2 headings.

```markdown
# Business Rules

## <Topic Group>

**BR-<CODE>**: If <criteria>, then <outcome>.
**BR-<CODE>**: If <criteria>, then <outcome>.
```

Rules:

- One file for all BRs. Group by topic noun (e.g. `Authentication`, `Pricing`).
- Codes are unique, uppercase, sequenced within their group (e.g. `AUTH-01`, `AUTH-02`).
- Application-independent: no UI references, no implementation details.
- Append new rules at the end of their group. Do not reuse codes.

---

### JTBD + User Information — `users/<group>.md`

One file per user group / team.

```markdown
# <User Group>

## JTBDs
1. <First distinct outcome the user needs to achieve>
2. <Second distinct outcome>

## RBAC

| Capability | <Role A> | <Role B> | <Role C> |
|---|---|---|---|
| <Capability> | <access> | <access> | <access> |
```

Rules:

- H1 = group name, identical to file name (without extension).
- JTBD = single line stating the **outcome**, from the user's perspective. No steps, no UI.
- Number JTBDs sequentially. Append new ones; do not reorder.
- RBAC cells use a consistent vocabulary (`Yes`/`No`, or `Read`/`Read+Write`/`Full`/`None`). Pick one and stick to it.

---

### Workflow — `workflows/<operation>.md`

One file per granular user operation.

```markdown
# <Workflow Name>

## Context
<Which business process or step this workflow belongs to.>

## Role
<Who performs this workflow.>

## Prerequisites
- <What must be true before starting.>

## Steps
1. <Detailed user action and system response.>
2. …

## Expected Result
<What the user has or sees on success.>
```

Rules:

- One operation per file. One role per workflow. If multiple roles participate, it's a Business Process instead.
- Steps are sequential and concrete: what the user does + what the system shows or changes.
- UI references are allowed — workflows describe in-system behavior.
- Do not duplicate Business Rules. Reference by BR code.

---

### Data Example — `domain-entities/<entity>.md`

One file per domain entity.

```markdown
# <Entity Name>

| attribute name | type | mandatory | description | limitations/validations | error messages | examples |
|---|---|---|---|---|---|---|
| <attr> | <type> | <Y/N/TBD> | <what it represents> | <restrictions or —> | "<message>" or — | <1–3 values> |
```

Rules:

- Do not include IDs as attributes.
- `type`: plain language (`String`, `Integer`, `Date`, `Boolean`, `String (enum)`, `String (list)`).
- `limitations/validations`: format, length, allowed values, decimal precision. Use `—` if none.
- `error messages`: exact user-facing copy in quotes. `—` if none. `TBD` if unknown.
- `examples`: 1–3 realistic values.
- Append new attributes; do not reorder existing rows.

---

### Business Process — `business-processes/<process>.md`

One file per named process.

```markdown
# <Process Name>

## Purpose
<One sentence describing what this process achieves.>

## Trigger
<The event, schedule, or action that initiates the process.>

## Roles Involved
- <Role> — <how they participate>

## Process Steps
1. <Step> — [<Role>]
2. …

## Outputs
<What is produced or changed.>

## Notes / Exceptions
<Edge cases, deviations.>
```

Rules:

- Typically spans multiple roles. If only one role end-to-end, it's a Workflow.
- Each step names a responsible role in brackets, using names from `users/`.
- Reference Workflows by file name where steps map to one — don't restate.

---

### Product Description — `product-context/<product>.md`

One file per product / system.

```markdown
# General Description
<What the product is, in 1–3 sentences.>

# What Problems It Addresses
<User / business problems the product solves.>

# Benefits
<What value users / the business get.>

# High-Level Functionality
<Major capability areas at stakeholder level.>

# User Groups / Stakeholders
<Named user groups; cross-reference users/ files.>

# Future Roadmap / Expansion
<Planned but not in scope.>
```

Rules:

- All six H1 sections are present. Empty sections keep their heading.
- Update in place — never replace wholesale.
- Cross-reference rather than duplicate user groups, workflows, or business rules.

---

## Constraints

- One concept type per file, except `users/<group>.md` which holds JTBDs **and** RBAC for that group.
- Do not move content between sections without explicit instruction.
- Do not modify `Archive/` or `AGENTS.md`.
- If a file would duplicate an existing one, ask whether to merge or create a new entry — do not auto-merge.
