---
name: draft-api-story
description: 'Draft one API design story from the existing Product Context: a JTBD from users/, a workflow, or an EARS requirement, grounded in domain-entities/, Business-rules.md and the API standards. Produces a structured story .md in OUTPUT/Draft/api-stories/. With --bulk, produces one file per story. Use when the user says "/draft-api-story" or asks to write API story / stories from a JTBD or EARS requirement. Does not write the OpenAPI spec (that is `design-api-spec`).'
argument-hint: 'A JTBD, workflow or EARS requirement to turn into an API story (e.g. "Rules Manager creates device type"), or --bulk <users/rules-manager.md | outputs/<ears-file>.md>'
license: MIT
metadata:
  version: "1.1.0"
  author: "Illia Shapoval"
  adapted-from: "https://github.com/paraskakis/skills/tree/main/api/design-api-stories by Emmanuel Paraskakis"
---

# Draft API Story

Produces an API design story `.md` file in `OUTPUT/Draft/api-stories/`, using the Product Context as input. A story is the bridge between a product requirement and the OpenAPI spec (Emmanuel Paraskakis's method for designing APIs with LLMs). It is written for a product manager to review: "yes, that is the right API" or "no, we are missing X". 

This skill is the workspace-aware version of `design-api-story`. Entities, users, workflows, rules and product context come from the workspace, not from files the user hands over. The clarify step and the template are shared with the `draft-spec` skill.

## Scope and Routing

- In scope: turning one requirement (or, with `--bulk`, a list of requirements) plus the Product Context plus API standards into reviewable API stories.
- Out of scope: ticket drafts (use `draft-spec`), EARS rewriting (use `ears-requirements`), generating the OpenAPI spec (use `design-api-spec`), and changing Product Context files (use `context-management`).

Use **after** the Product Context has the relevant entries. If context is missing, run `context-management` first or ask the user to provide it.

## Input: what a story is written from

One story is written from **one requirement**. The requirement is one of:

1. **A JTBD** from `users/<group>.md` (named by group and number, or quoted).
2. **An EARS requirement**, or a requirement file produced by `ears-requirements` (`outputs/<slug>.md`, or pasted lines).
3. **A plain request** from the user (e.g. "story for creating a device type"), grounded in the matching Workflow in `workflows/`.

Without `--bulk`: one story. If the source holds several requirements (a whole `users/<group>.md`, an EARS list), ask which one to use, or suggest `--bulk`.

## `--bulk`

`/draft-api-story --bulk <source>` creates multiple stories, **one file per story**. `<source>` is one of:

- A `users/<group>.md` file: every JTBD in it.
- A list of JTBDs, by number or quote.
- An `ears-requirements` output file: every line of the `EARS-compliant list`.

Bulk procedure:

1. Run **Step 0 — Clarify** once for the whole batch, not once per story.
2. Derive the stories. One story is one operation with one action verb. A JTBD or requirement that needs several operations (e.g. "have a current catalog of device types" → create, update, deactivate, list) becomes several stories. A requirement with no API operation (pure UI behaviour, a business rule that no consumer calls) is skipped with a reason.
3. **Present the plan before writing anything** and wait for one confirmation:

   | # | Story title | Source requirement | Method + Resource |
   |---|---|---|---|

   Also list the skipped requirements with the reason, and any decision that applies to the whole batch (pagination style, error format, deactivate as `PUT` or `DELETE`). Decide it once and apply it identically to every story.
4. After confirmation, run Steps 1–3 for every story in the plan. Each file is self-contained.
5. Write **one log line** for the batch (Step 3).

---

## Procedure

### Step 0 — Clarify

Only proceed once the task is clarified.

1. Read `_master-index.md`.
2. Read `OUTPUT/ticket-backlog.md`. Match the request against existing rows by title similarity or subject.
  - If matched: tell the user and use the row's Notes and Dependency as additional context.
  - If the matched row's `Dependency` is non-empty: state the open decision and ask whether it is resolved or should be treated as a known open item.
  - If the matched row's `Draft Created` is non-empty: tell the user a ticket draft exists, read it as extra context, and carry on. The backlog is **read-only** for this skill.
3. Look up the relevant Workflows, JTBDs, Domain Entities, Business Rules, and Business Processes by reading the matching files:
  - `users/<group>.md` — the JTBD and the RBAC table (which role may perform the operation).
  - `workflows/` — the steps the operation serves.
  - `domain-entities/` — attributes, types, validations and error messages of every entity the operation touches.
  - `Business-rules.md` — rules that constrain the operation (cite by code).
  - `product-context/` — scope (v1 limits such as US only, USD) and non-functional targets that affect the API.
4. **Locate the API standards.** Use, in this order:
  1. A file the user names or pastes.
  2. A file in the workspace with a `# API Standards` or `# Style Guide` heading.
  3. [references/API-standards.md](references/API-standards.md) — the default, bundled with this skill. Read it in full before composing any story.

  The bundled file is a copy of `.claude/skills/design-api-spec/references/API-standards.md`, so stories and the spec are held to the same standards. If the two differ, tell the user and use the one in `design-api-spec`, which is what the spec will be checked against.

  Tell the user which file you will use and confirm it once per session. If none exists, ask the user. Never write a story without standards: method, resource, nesting, pagination and error codes all come from them.
5. Break down the request:
  - **Actor** — the role from `users/` that performs the operation.
  - **Goal** — scope and purpose; the related JTBD / Workflow.
  - **Operation** — the single action verb and the entity it acts on; the resulting `Method` and `Resource` per the standards.
  - **Parameters** — path and query parameters, and the request-body attributes taken from the entity.
  - **Edge cases** — suggested from context: business rules, entity validations, RBAC.
  - **Out of scope** — only if the user explicitly mentions; do not infer.
6. **Surface terminology conflicts and gaps.** If the user introduces terms that differ from the Product Context, or an entity or attribute the operation needs is not in `domain-entities/`, ask before drafting. Never invent an entity.
7. User story for API must focus on the user (other system or actual user) outcomes, not simply CRUD operations. If outcomes are not clear from gathered context - clarify with the user.

### Step 1 — Compose the story

Build the file using the **Story Template** below. All sections are produced in order. If a section has no input data (besides Out of Scope, which is dropped when nothing applies), write `TBD` rather than skipping the heading.

### Step 2 — Place the story

1. Write to `OUTPUT/Draft/api-stories/<title>.md`. File name = the story title.
2. Do not wait for confirmation before placing a single story — the user reviews after it is written. (Bulk waits once, for the plan.)
3. If a file with that name exists, ask whether to overwrite, keep both with a numeric suffix, or skip. Never overwrite silently.
4. Do not write to `OUTPUT/ticket-backlog.md`.

### Step 3 — Log

Append one line to `log.md`:

```
YYYY-MM-DD | <source file or "prompt"> | Drafted API story "<title>" in OUTPUT/Draft/api-stories/<title>.md.
```

For `--bulk`:

```
YYYY-MM-DD | <source file or "prompt"> | Drafted <N> API stories in OUTPUT/Draft/api-stories/ from <source>.
```

### Step 4 — Suggest next steps

After placing the story or stories, suggest, naming the target file and the skill that handles it:

- Missing or `TBD` entity attributes, workflows, JTBDs or business rules the story implies (`context-management`).
- Backlog candidates implied by Out of Scope (`backlog`).
- Once the set of stories for an API is complete, generating the OpenAPI spec (`design-api-spec`).

Do not act on suggestions without explicit user instruction.

---

## Story Template

The file has no frontmatter. The first line of the body is the H1 = the title.

### 1. Title

```
# [action] [entity] [by user] [context]
```

Only `[action]` and `[entity]` are required. `[user]` and `[context]` are optional.

Rules:

- **One action verb only.** "Create and update" is two stories — split and surface to the user.
- `[action]` is a single imperative verb (e.g. *Create*, *Get*, *List*, *Search*, *Update*, *Deactivate*).
- `[entity]` matches a `domain-entities/` file (singular for one item, plural for a collection).
- `[by user]` is a role from `users/`. Add it when the role disambiguates the story.
- `[context]` is used only for disambiguation.

Examples: `Create device type`, `List orders by Operator`, `Update quote amount by Operator after assessment`.

Title is also the file name (`OUTPUT/Draft/api-stories/<title>.md`).

---

### 2. Scope

```markdown
## Scope

The system shall allow [user] to [action] [entity] [context or conditions].

- **Method:** `POST`
- **Resource:** `/device-types`
- **Source:** `users/rules-manager.md` JTBD 1
```

Or, when one action needs several conditions:

```markdown
## Scope

The system shall allow [user] to [action] [entity] when:
- <condition 1>
- <condition 2>

- **Method:** …
- **Resource:** …
- **Source:** …
```

Rules:

- Use "The system shall …" phrasing. State the goal, not steps or validations.
- `Method` and `Resource` MUST follow the API standards (naming, nesting, pluralization, which method for which action). Use `domain-entities/` names for the resource, in the casing the standards require.
- `Source` names the requirement the story came from: `users/<group>.md` + JTBD number, the `outputs/<slug>.md` EARS file + line number, or `prompt`. It is the traceability link.
- Nest resources per the entity relations, within the nesting limit of the standards.

---

### 3. Entity Attributes & Validations

One H3 sub-section per entity touched, plus one `Parameters` sub-section when the operation has path or query parameters that are not entity attributes.

```markdown
## Entity Attributes & Validations

### Parameters

| parameter | in | type | mandatory | description |
|---|---|---|---|---|
| <name> | path / query | <type> | <Y/N> | <what it represents> |

### <Entity>

| attribute name | type | mandatory | description | limitations/validations | error messages | examples |
|---|---|---|---|---|---|---|
| <attr> | <type> | <Y/N> | <what it represents> | <restrictions> | "<message>" | <1–3 values> |
```

Rules:

- Only attributes the operation touches: the request-body attributes for `POST` / `PUT`, the filter attributes for a list or search, the attributes returned for a `GET`. Not every attribute of the entity.
- Copy attribute names, types, validations, error messages and examples from `domain-entities/<entity>.md`. Do not reword them. Write attribute names exactly as in the entity file; the conversion to wire names happens in `design-api-spec`.
- Do not include IDs.
- List enum values explicitly. Specify decimal precision for currency / numeric fields.
- Mark immutability and system-generated fields (`Set by the system; not accepted in the request`).
- `Parameters` follow the standards exactly (e.g. pagination parameters for every collection). Mark each as `path` or `query`.
- Omit the `Parameters` sub-section when there are none.

---

### 4. Error / Edge Cases

```markdown
## Error / Edge Cases

| Scenario | System Behavior | Message Example | Suggested Exit Flow |
|---|---|---|---|
| <what goes wrong> | <how the system handles it, with the HTTP status per the standards> | "<exact error text>" | <how the API consumer recovers> |
```

Cover the categories that apply:

- Validation errors (missing mandatory attributes, invalid formats, values outside an enum).
- Duplicate data and state conflicts.
- Resource not found.
- Permissions (the role is not allowed, per the RBAC table in `users/`).
- Business-rule violations (cite the rule code).
- Boundary conditions (zero, maximum, empty collection).
- Concurrent access by multiple users.
- Mid-flow data changes (referenced data becomes stale or unavailable).

Skip categories that genuinely don't apply. Do not list generic 429 and 500 responses — `design-api-spec` adds them to every operation. Take the message text from the entity's error messages when one exists.

---

### 5. Out of Scope

```markdown
## Out of Scope

- <Item explicitly excluded by the user>
- <Item explicitly excluded by the user>
```

Rules:

- **Only items the user mentioned explicitly.** Do not infer exclusions.
- **Omit the entire section if there is nothing to list** — this is the only section that may be silently dropped.
- Each item is a future-story candidate; surface it to the user as input to the `backlog` skill after the story is placed.

---

### 6. Inferred Suggestions

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
- This is the **only** section where inference is allowed. Never present an inference as a fact in any other section.

Categories to consider:

- A `Method` or `Resource` the standards do not settle (e.g. deactivate as `PUT` of a status or as `DELETE`).
- Operations the requirement implies but does not state (the matching `GET` after a `POST`).
- Missing entity attributes or `TBD` values in `domain-entities/`.
- Unstated business rules.
- Filters, sort order, default values, retention windows.
- Format conventions (date, currency, locale).
- Idempotency and optimistic concurrency.
- Permission gaps in the RBAC table.
- Notifications triggered by the operation.

---

## Cross-Section Rules

To avoid duplication:

| Concern                               | Section                         |
| ------------------------------------- | ------------------------------- |
| What the operation is and why         | Scope                           |
| What data exists and its rules        | Entity Attributes & Validations |
| What if something goes wrong          | Error / Edge Cases              |
| What is explicitly excluded           | Out of Scope                    |
| What is inferred or open              | Inferred Suggestions            |

If two sections would say the same thing, the higher-up section wins; the lower one references or omits.

Avoid uncertain language in Scope and in validations: "or", "optional", "maybe", "at least / at a minimum", "between X and Y", "fast / quick", "flexible", "e.g.", "i.e.", "shouldn't / won't". State the exact value, the exact condition, and what the system shall do. If a condition is dangerous to infer, ask the user.

---

## Key Principles

1. **Stories are for PM review, not engineering specs.** Keep them scannable. No response schemas, headers or implementation details; `design-api-spec` adds them.
2. **One story, one operation.** One action verb, one method, one resource.
3. **Follow the standards religiously.** Method, resource, nesting, pluralization and pagination come from the API standards. The stories are the first enforcement of the standards.
4. **Use domain language exactly.** Entity and attribute names come from `domain-entities/`; roles come from `users/`; rules are cited by code from `Business-rules.md`. Do not invent a synonym.
5. **Nest resources per the domain relations**, within the standards' nesting limit.
6. **Don't invent requirements.** If the requirement does not mention delete or update, do not add them. If something looks missing, flag it in Inferred Suggestions; do not add it silently.

## References

- [references/API-standards.md](references/API-standards.md) — Emmanuel Paraskakis's API Standards (default standards file, Step 0.5). Where each part is applied:

| Standards section | Applied in |
|---|---|
| Paths, Resources, Methods, Casing (path segments, path template parameters) | Scope → `Method` and `Resource` |
| Query Parameters, Collections & Pagination | Entity Attributes & Validations → `Parameters` (filters, `offset` / `limit`, comma-separated values) |
| IDs, References | `Parameters` (UUID path IDs); reference attributes |
| Status Codes, Errors | Error / Edge Cases → the HTTP status in System Behavior (`400` vs `409`, `404` only for a missing single resource, empty collection is `200`) |
| Security | Error / Edge Cases → `401` / `403` rows only when the API requires authentication |
| Idempotency, Responses, Properties | Error / Edge Cases (duplicates, concurrency, omitted optional fields) |
| SHOULD / MAY items (`fields`, `sort` / `order`, `expand`, conditional GET, `ETag`) | Inferred Suggestions, unless the requirement asks for them |

## Example

File `OUTPUT/Draft/api-stories/Create device type.md`:

```markdown
# Create device type

## Scope

The system shall allow a Rules Manager to create a device type in the catalog.

- **Method:** `POST`
- **Resource:** `/device-types`
- **Source:** `users/rules-manager.md` JTBD 1

## Entity Attributes & Validations

### Device Type

| attribute name | type | mandatory | description | limitations/validations | error messages | examples |
|---|---|---|---|---|---|---|
| model | String | Y | Name of the type or model family | Searchable by Operators | "Enter the model name." | Pixel 8 XL |
| category | String (enum) | Y | Product category | Initial values: Android phones, iPhone | "Select a category from the list." | iPhone |
| make | String | Y | Manufacturer / brand | Searchable by Operators | "Enter the manufacturer." | Google |
| minimum manufacture year | Integer | Y | Oldest manufacture year accepted | 4-digit year | "Enter a 4-digit minimum manufacture year." | 2021 |
| status | String (enum) | Y | Lifecycle state in the catalog | Set by the system to Active; not accepted in the request | — | Active |

## Error / Edge Cases

| Scenario | System Behavior | Message Example | Suggested Exit Flow |
|---|---|---|---|
| Mandatory attribute missing or invalid | `400`; no device type is created | "Enter a 4-digit minimum manufacture year." | Consumer corrects the field and resubmits |
| Caller does not hold the Rules Manager role | `403`; no device type is created | TBD | Employee requests the role from an Admin |

## Inferred Suggestions

> The following items are inferred or proposed — they are **not** stated in the source context. Confirm or revise before acceptance.

| Item | Reasoning |
|---|---|
| Should a device type with the same model, make and category return `409`? | The entity file defines no uniqueness rule; the standards require a defined duplicate behaviour for `POST`. |
```
