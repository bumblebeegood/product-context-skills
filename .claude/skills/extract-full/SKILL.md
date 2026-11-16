---
name: extract-full
description: 'Bootstrap a clean-slate Product Context workspace from INPUTS/ documents or a pasted product description. Runs in one of two modes: --grill interviews the user file by file and writes only confirmed facts; --assume fills every gap with plausible, logged assumptions and writes without stopping. Produces the Product Description, Users + JTBDs, Data Examples, Business Rules, Workflows and Business Processes. Self-contained: all file structures are inlined. Use only when the workspace is empty or essential context (product description, at least one user with a JTBD, at least one data example) is missing.'
argument-hint: '--grill | --assume, plus the input (e.g. "--assume INPUTS/brief.md"). "grill me" means --grill.'
metadata:
  version: "2.0.0"
  author: "Illia Shapoval"
---

# Extract (Full)

Initial Product Context setup. Reads the input, works out which context files the product needs, gets the missing facts — from the user (`--grill`) or by assuming them (`--assume`) — then scaffolds the workspace and writes the files.

## Modes

Exactly one mode flag is required.

| | `--grill` | `--assume` |
|---|---|---|
| Who supplies missing facts | The user, through an interview | The skill, by assuming domain-typical values |
| Stops for the user | After every question group, and once before writing | Never, unless there is no usable input |
| Content not covered | `TBD` | Filled in, and recorded in `OUTPUT/extract-assumptions.md` |
| Depth | As deep as the answers go | Every section of every file filled |
| Best for | Real projects with a product owner at hand | Fast bootstrap from a brief, first drafts for review |

Flag resolution:

- `--grill`, or the user says "grill me", "interview me", "question me" → `--grill`.
- `--assume`, or the user says "assume", "fill the gaps", "don't ask me" → `--assume`.
- No flag and no such phrase, or both flags → ask one question: *"Interview you first (`--grill`) or fill the gaps with assumptions (`--assume`)?"* Do nothing else until answered.

## Essentials

Four things must exist before any file is written, in both modes:

1. A high-level **Product Description**.
2. At least **one User**.
3. At least **one JTBD** for that user.
4. At least **one Data Example**.

## When to Use

- The workspace is empty or freshly scaffolded.
- The user says "grill me", "set up context", "extract context from this brief", "process INPUTS/ as initial context", or similar.
- The user pastes a product overview and asks to structure it.

Do **not** use this skill on a workspace that already has content. Use `context-management` to add or update entries instead.

---

## Procedure

### Step 0 — Orient

1. Resolve the mode (see **Modes**).
2. Check whether the workspace is scaffolded: `_master-index.md` and the content folders listed in `AGENTS.md` → **Project Setup**.
   - If missing, do **not** scaffold yet. Note it and continue. Scaffolding happens in Step 6.
   - If any content folder holds a file other than `_index.md`, or `Business-rules.md` holds more than its H1, the workspace already has content: stop and direct the user to `context-management`.
3. Identify the input source:
   - File(s) in `INPUTS/` named by the user. If none is named and `INPUTS/` holds files, use all of them and say which.
   - Or content pasted in the prompt.
4. If there is no input, ask the user to paste a product description or point to an input file. Do not proceed without input, in either mode.

### Step 1 — Read the input and map coverage

Read the input fully. Work out the **target files** — the context files this product needs:

| Concept | Target file | Derived from |
|---|---|---|
| Product Description | `product-context/<product>.md` | The product the input describes |
| User + JTBDs + RBAC | `users/<group>.md`, one per group | Roles, personas, ICPs, actors in use cases |
| Data Example | `domain-entities/<entity>.md`, one per entity | Nouns passing the entity test (Step 4) |
| Business Rules | `Business-rules.md` | Constraints, limits, eligibility, state rules, regulations |
| Workflow | `workflows/<operation>.md`, one per operation | Single-role operations in use cases |
| Business Process | `business-processes/<process>.md` | Flows that cross roles end to end |

For each target file, note what the input **states**, what it **implies**, and what is **missing**. This coverage map drives Step 2. It is working material: do not write it to a file.

Then run **Step 2G** (`--grill`) or **Step 2A** (`--assume`).

### Step 2G — Grill (`--grill` only)

Interview the user to collect only the facts the target files need.

**Open with the plan.** List the target files from Step 1 in the order below, in one short message, and start the first question group in the same message.

**Order:** Product Description → Users (one group at a time) → Data Examples (entity list first, then one entity at a time) → Business Rules → Workflows → Business Processes.

**Interview rules:**

- **File by file.** Each message holds one group of questions for one target file (at most 5 questions). Wait for the answers before the next group.
- **Ask about facts, not documents.** Ask who the actor is, what the entity's attributes and limits are, which rule decides the outcome, what the steps are. Never ask "what should the Workflow section say?"
- **Confirm instead of re-asking.** Where the input already answers a question, state your reading and ask the user to confirm or correct it: *"I read the brief as: an order belongs to exactly one customer. Correct?"* Group these confirmations together.
- **Stay inside the product.** Do not ask about parts of the product the input and answers never touch (e.g. billing when nothing mentions payments). Do not open new scope.
- **Turn answers into structure yourself.** Rephrase actions as JTBD outcomes, conditions as `If …, then …` rules, operations as numbered steps. Show the result in the next message only where it changed the user's meaning.
- **Answer handling:**
  - "Skip" / "don't know" → the item becomes `TBD`.
  - "You decide" / "assume" → assume a value as in Step 2A and record it in the assumptions register (Step 6).
  - "Looks good" / "confirmed" → accept and move on immediately.
- **Max 3 rounds per target file.** If still uncertain after 3 rounds, record the current state (`TBD` where open) and move on.
- **Workflows and Business Processes are optional.** If the input has no operational detail, ask once whether the user wants to describe any now. If not, skip them.

**Guiding questions per file** (use only those the coverage map leaves open):

- **Product Description** — What does the system do (2–3 sentences)? What problems does it solve? Which domain? Which regulations apply (e.g. HIPAA, PCI-DSS, GDPR)? What is planned but out of scope?
- **Users** — Who is it built for? Who uses the system? What roles or permission levels exist? Per group: what outcomes must they achieve across the lifecycle — creation, lookup, updating, status transitions, assignment / linking? What may each role read, change, or not see?
- **Data Examples** — First confirm the entity list (Step 4). Then per entity: which attributes does the business keep? For each: type, mandatory or not, allowed values / format / length / range, the exact message a user sees when it is wrong, 1–3 realistic examples.
- **Business Rules** — Which conditions trigger specific outcomes? Which limits, thresholds, or windows apply? Which eligibility, approval, or validation criteria? Which state transitions are blocked? What do the named regulations require?
- **Workflows** — For each operation: which single role performs it? What must be true first? What does the user do, step by step, and what does the system show or change? What does success look like?
- **Business Processes** — What triggers it? Which roles take part, in what order? What does it produce? Which exceptions occur?

When all target files are covered, go to Step 3.

### Step 2A — Assume (`--assume` only)

Do not ask questions. Fill every gap in the coverage map with the most plausible value and write the files.

**Where values come from, in priority order:**

1. What the input states. Never contradict it.
2. What the input directly implies (a lifecycle implies a status attribute; "public access" implies read-only RBAC for anonymous roles).
3. Domain convention: how products in this domain usually work, and what any named regulation requires.
4. A generic, sensible default (common length limits, ISO formats, clear error copy).

**Limits on assuming:**

- **Deepen, don't widen.** Assumptions complete what the input describes: attribute details, validations, error messages, workflow steps, process steps, rules implied by stated constraints, answers to the input's open questions. Do not add user groups, entities, or capabilities the input gives no hint of. Do not add anything the input lists as out of scope.
- **Keep the input's terminology.** Entity, attribute, role and enum names come from the input.
- **Record every assumption.** For each item not stated in the input, note the file, the item, the assumed value, and one line of reasoning. Stated facts are not assumptions. The list becomes `OUTPUT/extract-assumptions.md` in Step 6.

**What to produce per file:**

- **Product Description** — all six sections filled. The roadmap draws on the input's out-of-scope items and open questions.
- **Users** — one file per group. JTBDs across the lifecycle that fit the role (creation, lookup, updating, status transitions, assignment / linking). A full RBAC table with the `Read` / `Read+Write` / `Full` / `None` vocabulary.
- **Data Examples** — every attribute the input lists, plus the attributes its use cases and rules need. Every column filled: type, mandatory, validations (length, format, range, allowed values), exact error message, 1–3 examples. No IDs.
- **Business Rules** — the stated rules, plus rules implied by relations, lifecycles, enums, limits, and the answers to open questions. All in `If …, then …` form.
- **Workflows** — one per single-role operation in the use cases. Every section filled; steps cite BR codes instead of restating rules.
- **Business Processes** — one per flow that crosses roles (e.g. the lifecycle of the main entity from creation to retirement). Every section filled; steps reference workflows by file name.

**Consistency check before writing:**

- Every attribute a rule or workflow mentions exists in a Data Example.
- Enum values are identical in every file that lists them.
- Every role in RBAC tables, workflows and processes has a `users/` file.
- Every BR code cited in a workflow or process exists in `Business-rules.md`.

Then go to Step 3. In `--assume`, Steps 3–5 run without stopping.

### Step 3 — Essentials gate

| Essential | Source |
|---|---|
| Product Description | Product Description covered |
| At least one User | ≥1 user group |
| At least one JTBD on that user | ≥1 JTBD on ≥1 user |
| At least one Data Example | ≥1 entity (Step 4) |

- `--grill`: if an essential is missing, keep asking until at least one of each is captured. Do not write files until the gate passes.
- `--assume`: the gate fails only when the input describes no product, no user, or no entity at all. Then stop and ask for a fuller input. Do not invent a product.

### Step 4 — Derive Data Examples

Identify nouns in the input and the gathered content that meet **2 or more** of these criteria:

| # | Criterion | Test question |
|---|---|---|
| 1 | Multiple instances | Will there be many of these? |
| 2 | Has attributes | Does the business need to remember facts about it? |
| 3 | Has lifecycle | Does it change status over time? |
| 4 | Has relationships | Is it referenced by other things? |
| 5 | Queryable | Would someone ask "show me all the ___"? |

**Exclude:** actions / verbs (processes, not entities), attributes (properties of an entity), incidental nouns (mentioned but not tracked).

- `--grill`: present the entity list as `**<Entity>** — <one-line description>. Core attributes: <attributes, no IDs>` and ask the user to confirm, remove, or add. Then interview attribute details one entity at a time.
- `--assume`: use the list directly. An entity the input names explicitly is never dropped.

### Step 5 — Summarize before writing

Build the table of files to create:

| File | Concept | Notes |
|---|---|---|
| `product-context/<product>.md` | Product Description | — |
| `users/<group>.md` | User Information + JTBDs | <n> JTBDs |
| `domain-entities/<entity>.md` | Data Example | <n> attributes |
| `workflows/<operation>.md` | Workflow | Role |
| `business-processes/<process>.md` | Business Process | Roles |
| `Business-rules.md` | Business Rules | <n> rules in <n> topics |
| `OUTPUT/extract-assumptions.md` | Assumptions register | <n> assumptions (when any) |

- `--grill`: present it and wait for explicit confirmation. If the user rejects, return to the relevant file's question group.
- `--assume`: do not wait. The table goes into the hand-off (Step 8).

### Step 6 — Scaffold the workspace (if needed) and write files

1. **Scaffold** if Step 0 found it missing. Follow `AGENTS.md` → **Project Setup** exactly. Do not seed example content.
2. **Write the content** using the **File Structures** below.
3. **Write the assumptions register** `OUTPUT/extract-assumptions.md` when any assumption was made (always in `--assume`; in `--grill` only for "you decide" answers):

   ```markdown
   # Extract Assumptions

   Source: <input file(s) or "prompt"> · Mode: <--assume | --grill> · Date: YYYY-MM-DD

   Every item below was not stated in the input and was assumed to complete the Product Context. Confirm, correct, or remove each one via `context-management`.

   | File | Item | Assumed | Reasoning |
   |---|---|---|---|
   | `domain-entities/<entity>.md` | <attribute> — <column> | <value> | <why> |
   ```

   One row per assumption, grouped by file in the order of the Step 5 table.
4. **Update indexes** in the same turn:
   - The folder `_index.md` of every folder that received a file (one line per file, short summary).
   - The root `_master-index.md`: populate each section with the new entries.

### Step 7 — Archive and log

1. If the input came from `INPUTS/`, move the source file(s) to `Archive/`. Skip if the input was pasted in the prompt.
2. Append one line to `log.md`:

   ```
   YYYY-MM-DD | <source file or "prompt"> | Initial context extracted (<--grill | --assume>): <n> users, <n> JTBDs, <n> data examples, <n> workflows, <n> processes, <n> business rules[, <n> assumptions in OUTPUT/extract-assumptions.md].
   ```

### Step 8 — Hand-off

- `--assume`: show the Step 5 table, then the 5–10 assumptions with the most impact (those that set scope, rules, or lifecycles, not error-message wording), and point to `OUTPUT/extract-assumptions.md` for the full list.
- `--grill`: list the files written and every `TBD` left, by file.

Then suggest next steps, naming the skill:

- Review or correct assumptions and fill `TBD`s → `context-management`.
- Draft API stories from the new context → `draft-api-story --bulk users/<group>.md`.
- Draft tickets → `draft-spec`.

---

## File Structures

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
- Cross-reference rather than duplicate user groups, workflows, or business rules.
- Use `TBD` under a heading that has no content (`--grill` only).

---

### User Information + JTBDs — `users/<group>.md`

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

- H1 = group name, identical to the file name (without extension).
- A JTBD is a single line stating the **outcome**, from the user's perspective. No steps, no UI. Prefer *"Have an inspected device with a recorded assessment outcome"* over *"Inspects a Device according to the Assessment Rule"* (that is a workflow).
- Number JTBDs sequentially. Append new ones; do not reorder.
- RBAC cells use one vocabulary: `Read` / `Read+Write` / `Full` / `None`.
- If RBAC is unknown (`--grill`), keep the table headers and add a single `TBD` row.

---

### Data Example — `domain-entities/<entity>.md`

One file per domain entity.

```markdown
# <Entity Name>

<One or two sentences: what the entity is and how it relates to other entities.>

| attribute name | type | mandatory | description | limitations/validations | error messages | examples |
|---|---|---|---|---|---|---|
| <attr> | <type> | <Y/N/TBD> | <what it represents> | <restrictions or —> | "<message>" or — | <1–3 values> |
```

Rules:

- Do not include IDs as attributes. References to other entities are `Reference (<Entity>)` or `Reference (<Entity>) (list)`.
- `type`: plain language (`String`, `Integer`, `Date`, `Date/time`, `Boolean`, `String (enum)`, `String (list)`, `URL`).
- `limitations/validations`: format, length, allowed values, ranges, decimal precision. `—` if none.
- `error messages`: exact user-facing copy in quotes. `—` if none. `TBD` if unknown.
- `examples`: 1–3 realistic values. `TBD` if unknown.
- Mark system-set attributes in the description (`Set by the system`).

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
1. <User action and system response.>
2. …

## Expected Result
<What the user has or sees on success.>
```

Rules:

- One operation per file, one role per workflow. If several roles take part, it is a Business Process.
- Steps are sequential and concrete: what the user does and what the system shows or changes.
- Do not duplicate Business Rules. Reference them by BR code.
- `--grill`: sections without answers are `TBD`.

---

### Business Process — `business-processes/<process>.md`

One file per named process.

```markdown
# <Process Name>

## Purpose
<One sentence describing what this process achieves.>

## Trigger
<The event, schedule, or action that starts the process.>

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

- Spans several roles. If one role does it end to end, it is a Workflow.
- Each step names the responsible role in brackets, using names from `users/`.
- Reference Workflows by file name where a step maps to one. Do not restate them.
- `--grill`: sections without answers are `TBD`.

---

### Business Rules — `Business-rules.md`

A single root-level file with all rules, grouped by topic under H2 headings.

```markdown
# Business Rules

## <Topic Group>

**BR-<CODE>**: If <criteria>, then <outcome>.
**BR-<CODE>**: If <criteria>, then <outcome>.
```

Rules:

- One file for all rules. Group by **topic noun** (e.g. `Authentication`, `Pricing`, `Inspection`).
- Codes are unique, uppercase, sequenced within their group (e.g. `AUTH-01`, `AUTH-02`), and never reused.
- Application-independent: no UI references, no implementation details.
- Each rule is one line: `**BR-<CODE>**: If <criteria>, then <outcome>.`
- If no rules were captured, leave the file with its H1 only.

---

## Constraints

- **`--grill` never invents.** Content comes from the input or the user's answers; everything else is `TBD`. The only exception is an item the user explicitly hands over ("you decide"), which is recorded as an assumption.
- **`--assume` invents only to fill gaps**, never contradicts the input, never widens scope, and records every assumption in `OUTPUT/extract-assumptions.md`.
- **The essentials gate is hard** in both modes. No file is written until Product Description, ≥1 User with ≥1 JTBD, and ≥1 Data Example exist.
- **Max 3 rounds per target file** in `--grill`. If the user is still uncertain, capture the current state and move on.
- **One concept type per file**, except `users/<group>.md`, which holds JTBDs **and** RBAC for that group.
- **No IDs as Data Example attributes.**
- **Business Rules are application-independent**, in `If <criteria>, then <outcome>` form, with unique codes that are never reused.
- **Do not modify `Archive/` or `AGENTS.md`** (moving input files into `Archive/` in Step 7 is the only write there).
- If the workspace already has content, stop and direct the user to `context-management`.
- All files and folders use **lowercase kebab-case**. One topic per file.
