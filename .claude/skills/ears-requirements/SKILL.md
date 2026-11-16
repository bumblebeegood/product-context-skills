---
name: ears-requirements
description: Rewrite requirements into EARS (Easy Approach to Requirements Syntax) form. Use when the user asks to make a requirement EARS-compliant, apply the EARS standard, improve or tighten a requirement, or turn a feature description, or ticket into structured requirements. Reads project context first to ground the system name, actors, and entities, then writes a numbered EARS list to outputs/.
metadata:
  version: "2.0.0"
  author: "Illia Shapoval"
---

# EARS Requirements

Convert loose requirement text into EARS syntax: one atomic, testable statement per line, each using one of the six EARS patterns.

## When to invoke

- "make this EARS compliant"
- "apply the EARS standard"
- "improve / tighten / clean up this requirement"
- Any request to structure requirements where EARS is the house style.

## Step 1 — Read the project context before writing anything

You need three things before a requirement can be written well:

1. **What is being built** — the context of the product or system
2. **Who the users are** — roles, actors, external systems that interact with it.
3. **What users create or act on** — the domain entities (order, patient record, invoice, spec, session).

Look for these in the working directory, in this order, stopping when you have enough:

- `README.md`, `CLAUDE.md`, `AGENTS.md` at the repo root.
- `docs/`, `specs/`, `product/`, `requirements/`, `context/` — PRDs, briefs, architecture notes, glossaries, users, entities.
- Existing requirement files, so new statements match the established system name and vocabulary.
- Code-level signals when prose is thin: data models, schema files, API route names, `package.json` name/description. These give entity names, not intent — never infer *why* a feature exists from code.

Record which files you actually used. They go in the output.

## Step 2 — Decide whether to ask

**Do not ask questions you can answer.** If the prompt or the context files establish the system, the users, and the entities — even loosely — proceed and state what you assumed.

Stop and ask only when a missing answer would change the requirements themselves. In that case, say plainly what is missing and either ask the user to point you at the relevant file, or ask the smallest set of these:

- What are we building?
- Who are the users?
- What do users create or work with?

Ask once, in a single message. Do not produce a half-grounded requirement list as a hedge.

## Step 3 — Convert

For each requirement in the input:

1. **Classify** it against the pattern table below.
2. **Split compound statements.** "The system shall validate the file and email the user" is two requirements. Every `and`, `or`, and comma-list is a split candidate.
3. **Write one sentence per requirement**, using `shall` — never `should`, `may`, `will`, or `must`.
4. **Name the system the same way every time**, using the name found in context.
5. **Replace unverifiable words.** "Fast", "user-friendly", "robust", "seamless", "appropriate", "as needed" either get a measurable value from context, or get flagged as a gap. Do not invent a threshold and present it as a requirement.
6. **Do not add behaviour the input does not imply.** Missing error handling is a gap to flag, not a requirement to invent.

Give particular attention to unwanted behaviour (`If … then …`). For every event-driven requirement, ask what happens when the trigger fires and the system cannot comply.

If the input is already valid EARS, say so and limit yourself to real defects (atomicity, naming drift, unverifiable terms).

## Step 4 — Write the output

One file per invocation, at `outputs/<slug>.md`, where `<slug>` is kebab-case derived from the prompt or the original requirement — `checkout-payment-retry.md`, `patient-vitals-alerting.md`. If the file exists, append a short numeric suffix rather than overwriting.

```
# Source

<the original requirement text, verbatim and unedited>

Context files used: `README.md`, `docs/product-brief.md`

# EARS-compliant list

1. The <system> shall <response>.
2. When <trigger>, the <system> shall <response>.
3. If <trigger>, then the <system> shall <response>.

# Assumptions

- <what you inferred, and where it came from>

# Gaps and open questions

- <what the author needs to decide before these are implementable>
```

Keep the original text verbatim — it is the traceability link back to the requester. If the input was spoken or messy, preserve it as-is and put the cleanup in the EARS list.

`Assumptions` and `Gaps and open questions` may be omitted only when genuinely empty, which is rare. Repeat the headline assumptions and gaps in your chat reply so the user sees them without opening the file.

## Pattern reference

| Type                  | Keyword(s)         | Template                                           |
| --------------------- | ------------------ | -------------------------------------------------- |
| **Ubiquitous**        | *(none)*           | `The <system> shall <response>`                    |
| **Event-Driven**      | **When**           | `When <trigger>, the <system> shall <response>`    |
| **Unwanted Behavior** | **If…Then**        | `If <trigger>, then the <system> shall <response>` |
| **State-Driven**      | **While**/**During** | `While <state>, the <system> shall <response>`   |
| **Optional Feature**  | **Where**          | `Where <feature>, the <system> shall <response>`   |
| **Complex**           | *(combinations)*   | Combine patterns as needed                         |

Choosing between them:

- **Ubiquitous** — always true, no trigger, no precondition. Encryption, compliance, invariants.
- **Event-Driven** — a discrete trigger occurs and the system responds. `When` describes the happy path.
- **Unwanted Behavior** — failures, timeouts, invalid input, denied permissions. `If` signals something went wrong.
- **State-Driven** — true for the duration of a mode or state, not at a single instant. Test the word `while` literally.
- **Optional Feature** — behaviour that exists only in some configurations, tiers, or deployments.
- **Complex** — stack the qualifiers in order: `While <state>, when <trigger>, the <system> shall <response>`.

Order the list by pattern: ubiquitous first, then state-driven, then event-driven, then unwanted behaviour, then optional. It reads as a system description rather than a pile of statements.

Numbering is a plain `1. 2. 3.` list. Do not invent identifier schemes (`REQ-001`, `FR-3.2.1`) unless the project's existing requirement files already use one, in which case match it.

## Examples

> The payment system shall comply with PCI-DSS standards.

> When a customer completes checkout, the system shall send a confirmation email.

> If payment authorization fails, then the system shall display the error message and preserve cart contents.

> While a flash sale is active, the system shall display the discounted price on product pages.

> Where the customer has enrolled in the loyalty program, the system shall apply earned points at checkout.
