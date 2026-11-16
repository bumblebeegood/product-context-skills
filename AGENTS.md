# Product Context Workspace

This repository is a **Product Context workspace**: structured, file-based product knowledge that AI agents read to produce tickets, API design stories, and OpenAPI specs. Raw material goes into `INPUTS/`, skills turn it into context files, and other skills turn the context into deliverables in `OUTPUT/`.

## Folder Layout

| Path | Kind | Holds |
|---|---|---|
| `product-context/` | content | Product Description — one file per product |
| `users/` | content | User groups — JTBDs and RBAC, one file per group |
| `domain-entities/` | content | Data Examples — attributes, validations, error messages, one file per entity |
| `workflows/` | content | Single-role, step-by-step operations, one file per operation |
| `business-processes/` | content | End-to-end flows across roles, one file per process |
| `Business-rules.md` | content | All Business Rules, grouped by topic |
| `_master-index.md` | index | One section per content folder, one line per file |
| `<folder>/_index.md` | index | One line per file in that folder |
| `log.md` | log | One line per change to the workspace |
| `INPUTS/` | plain | Raw input documents waiting to be processed |
| `Archive/` | plain | Processed inputs. Read-only. |
| `OUTPUT/` | plain | Deliverables: `Draft/` (tickets), `Draft/api-stories/`, `api-spec/`, `ticket-backlog.md` |
| `.claude/skills/` | skills | The skills listed below |

## Project Setup

Run this when `_master-index.md` or any content folder is missing. Create only what is missing and never seed example content.

1. **Content folders**, each with an `_index.md` whose only line is an H1 equal to the folder name (e.g. `# users`):
   - `product-context/`
   - `users/`
   - `domain-entities/`
   - `workflows/`
   - `business-processes/`
2. **Plain folders**: `INPUTS/`, `Archive/`, `OUTPUT/`, `OUTPUT/Draft/`.
3. **`_master-index.md`**:

   ```markdown
   # Master Index

   ## product-context

   ## users

   ## domain-entities

   ## workflows

   ## business-processes

   ## Business Rules
   ```

4. **`log.md`** — empty.
5. **`Business-rules.md`** — H1 only: `# Business Rules`.
6. **`OUTPUT/ticket-backlog.md`**:

   ```markdown
   # Ticket Backlog

   | Title | Group | Source | Notes | Dependency | Draft Created | Jira Ref |
   |---|---|---|---|---|---|---|
   ```

## Concepts

| Concept | Test | File |
|---|---|---|
| Product Description | Product purpose, problems, benefits, user groups, roadmap | `product-context/<product>.md` |
| JTBD | One outcome a user needs to achieve — no steps, no UI | `users/<group>.md` → `## JTBDs` |
| User Information | Who the group is and what it may do | `users/<group>.md` → `## RBAC` |
| Data Example | Attributes of a domain entity, with types, validations, error messages, examples | `domain-entities/<entity>.md` |
| Business Rule | `If <criteria>, then <outcome>` — domain logic, no UI | `Business-rules.md` |
| Workflow | Step-by-step operation in the system, one role | `workflows/<operation>.md` |
| Business Process | End-to-end flow across roles | `business-processes/<process>.md` |

The exact file structures live in the `context-management` skill, which owns them. `extract-full` inlines the same structures.

## Skills

| Skill | Use it to | Reads | Writes |
|---|---|---|---|
| `extract-full` | Bootstrap an empty workspace from a brief. `--grill` interviews you; `--assume` fills gaps and logs assumptions. | `INPUTS/` or prompt | All content folders, `OUTPUT/extract-assumptions.md` |
| `context-management` | Add to or update the context from new inputs | `INPUTS/` or prompt | Content folders |
| `ears-requirements` | Rewrite requirements in EARS form | Context, prompt | `outputs/<slug>.md` |
| `draft-spec` | Draft a ticket / user story | Context, backlog | `OUTPUT/Draft/<title>.md` |
| `draft-api-story` | Draft API design stories from JTBDs, workflows or EARS requirements (`--bulk` for many) | Context, API standards | `OUTPUT/Draft/api-stories/<title>.md` |
| `design-api-story` | Draft API stories from requirement and domain files you hand over (no workspace needed) | Given files | Stories |
| `design-api-spec` | Generate an OpenAPI 3.1 spec from API stories and lint it | Stories, context, API standards | `OUTPUT/api-spec/` |
| `backlog` | Maintain the ticket backlog and create Jira issues | `OUTPUT/ticket-backlog.md` | `OUTPUT/ticket-backlog.md` |
| `confluence-sync` | Sync Markdown files with Confluence pages (manual: `/confluence-sync`) | Mapped files | Mapped files, `log.md` |

Typical flow: `extract-full` → `context-management` (as new inputs arrive) → `draft-api-story --bulk` → `design-api-spec`.

## Rules for Agents

1. **Read `_master-index.md` first** before any task that uses the context.
2. **Use the skills.** Write context files through `extract-full` or `context-management`, deliverables through the skill that owns them.
3. **Update indexes in the same turn** as any content change: the folder `_index.md` and `_master-index.md`.
4. **Log every change** with one line in `log.md`: `YYYY-MM-DD | <source file or "prompt"> | <one-sentence summary>`.
5. **Never invent context** outside an explicit `--assume` run. Missing facts are `TBD` or a question to the user.
6. **One concept per file**, except `users/<group>.md` (JTBDs + RBAC). Files and folders are lowercase kebab-case; deliverable titles in `OUTPUT/Draft/` keep their title as the file name.
7. **Do not modify `Archive/` or this file.** Processed inputs are moved from `INPUTS/` to `Archive/` and never edited.
