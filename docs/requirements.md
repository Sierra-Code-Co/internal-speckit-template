# Requirements Register

<!-- This file ships with the template as a starter. Replace the example rows with real ones
     before the first spec is written, and delete this comment. An empty register is not a
     problem; a register that still contains the example rows below on a real project is,
     because it will pass the traceability gate while tracing nothing. -->

**This file is the authoritative scope of the project.** Every functional requirement in every
`specs/*/spec.md` MUST cite an ID from this register. An FR that cannot cite one is a deletion
candidate, not a feature.

`scripts/assert-requirements-traceability.sh` enforces that mechanically and runs in the pre-push
gate. The rule is not a convention — a convention was tried, and it was violated on the first spec
written under it.

## Why this file exists and where it lives

It is **committed to the repository that holds the code**, not kept in a notes workspace, because
requirements change the code and code-changing facts belong with the code. What stays outside is the
material that would change *who to talk to or how to pitch something*: meeting transcripts,
stakeholder read-outs, anything candid about a named person. Reach that from here through a
gitignored symlink; never copy it in.

Two failure modes this is built against, both observed rather than imagined:

- **A spec's `Input:` field paraphrasing whoever ran the command.** When every FR traces back to the
  operator's own prompt, nothing traces to a request, and the build drifts without anything
  registering that it has.
- **A constitution and a requirements list disagreeing about scope, with nothing that reads both.**
  One project's constitution listed the requestor's first priority under Out of Scope for two weeks
  while the register recorded it as the ask. Thousands of lines were written on the wrong side of
  that disagreement. The register is the reconciliation point: **where the two disagree, the register
  wins and the constitution is what gets corrected.**

## How to read a row

| Field | Meaning |
|-------|---------|
| **Status: Confirmed** | The requestor stated it and it has been read back to them, or it is visible in a source artifact we hold. Safe to build against. |
| **Status: Asked** | The requestor stated it once. Not yet read back. Build against it, but expect refinement. |
| **Status: Inferred** | Nobody asked for it. It comes from reading an artifact. **Must be confirmed before it drives a design decision.** |
| **Status: Open** | A question, not a requirement. Has a named owner. |

Every row carries a **provenance reference** — a `file:line` pointer into a source you actually hold,
or a dated artifact reference. A row whose source is "we discussed it" is a row nobody can check.
Quote the requestor **verbatim** wherever the wording carries the requirement; a paraphrase is a
requirement you have already begun designing.

**Inferred is the load-bearing status.** It is how a constraint that nobody requested gets recorded
without being laundered into a request. State the invariant in the register and let the *mechanism*
be an open question — choosing the mechanism quietly is how a check ends up passing on a case it
never covered.

---

## A. {{Area name}}

{{One paragraph: what this area is, whose priority it is, and whether it is in scope. If the
constitution disagrees, say so here and say which one was corrected.}}

### R1 — {{Requirement group}}

{{One paragraph stating the requirement in the requestor's terms, not the implementation's.}}

| Sub | Requirement | Status | Source |
|-----|-------------|--------|--------|
| R1.1 | {{The requirement, as a single testable statement.}} | Confirmed | `{{source}}:{{line}}` |
| R1.2 | {{A requirement stated once and not yet read back.}} | Asked, **see Q1** | `{{source}}:{{line}}` |
| R1.3 | {{Something read off an artifact that nobody asked for.}} | **Inferred** | `{{artifact}}` |

> R1.1, verbatim: *"{{the requestor's own words}}"*

{{Any row marked Inferred gets a sentence here saying why it is here and what confirming it would
take. This is the paragraph that stops an inference from hardening into an assumption.}}

**Source of truth for R1:** {{the artifact, precisely enough to re-open: file, sheet, header row,
record count at time of observation}}.

---

## B. Platform and handoff constraints

Constraints are requirements about *how* rather than *what*, and they are the ones most often
discovered late. Give them their own IDs so a spec can cite them.

| ID | Constraint | Status | Source |
|----|-----------|--------|--------|
| C1 | {{A constraint that comes from who maintains this after handoff.}} | Confirmed | `{{source}}:{{line}}` |
| C2 | {{A constraint that comes from what the users will not stop using.}} | Confirmed | `{{source}}:{{line}}` |
| C3 | {{A constraint that comes from the platform or the network boundary.}} | Confirmed | constitution Principle {{N}} |

> C1, verbatim: *"{{the requestor's own words}}"*

---

## C. Open questions

Each has a named owner. **An open question may not be silently resolved by choosing a default.**

A spec may proceed while a question is open, on two conditions: the question is recorded in the
spec's Assumptions with its owner, and nothing irreversible is built on the assumed answer. A
question that gates a write path is a task, not an assumption.

| ID | Question | Owner | Blocks | Raised |
|----|----------|-------|--------|--------|
| Q1 | {{The question, stated so that an answer is checkable.}} | {{Named person}}, in writing | R1.2 | {{date}} |
| Q2 | {{A question about a platform capability every write path depends on.}} | {{Named person}}, by measurement against a scratch target | {{IDs}} | {{date}} |

{{For each question that can invalidate shipped code, a paragraph naming what it would invalidate
and how much of it. A question flagged as "MUST be proven before any plan depends on it" that then
acquires thousands of dependent lines is the failure this section exists to make visible.}}

---

## D. Explicitly out of scope

An out-of-scope list with no revisit condition is a list that gets re-litigated. Give every row the
event that would reopen it.

| Item | Why | Revisit when |
|------|-----|--------------|
| {{Thing not being built}} | {{Which constraint or principle it violates.}} | {{The specific event that reopens it.}} |
| {{Thing built and parked}} | {{Built ahead of a validated consumer; see the archive tag.}} | {{The register ID that would justify it.}} |

---

## Change log

Append-only. Each entry says what changed and what caused it — a review round, a meeting, a
measurement. A register with no change log is a register nobody can date.

| Date | Change |
|------|--------|
| {{date}} | Register created. |
