<!--
  Sync Impact Report
  Version change: 0.0.0 → 0.0.0 (template — not yet ratified)
  Added principles: none (placeholders)
  Added sections: Core Principles, Scope, Testing Philosophy, Quality Gates, Development Workflow, Key Decisions, Governance
  Templates requiring updates: none
  Follow-up TODOs: Run /speckit.constitution to fill in project-specific principles
-->

# [PROJECT_NAME] Constitution

## Core Principles

<!--
  Run /speckit.constitution to replace these placeholders with your project's
  non-negotiable principles. Each principle should follow the
  Statement + Constraints + Rationale format shown below.

  Example principles to consider:
  - Simplicity (YAGNI, minimal abstractions)
  - Testing philosophy (TDD, coverage, communication)
  - Idempotency / safety guarantees
  - Interface preferences (CLI, API, UI)
  - Output formats and determinism
-->

### I. [PRINCIPLE_1_NAME]

**Statement**: [PRINCIPLE_1_DESCRIPTION — declarative, using MUST/SHOULD language]

**Constraints**:
- [What this principle forbids or limits]
- [Boundaries that implementations must respect]

**Rationale**: [Why this principle exists — the cost of violating it]

### II. [PRINCIPLE_2_NAME]

**Statement**: [PRINCIPLE_2_DESCRIPTION]

**Constraints**:
- [What this principle forbids or limits]
- [Boundaries that implementations must respect]

**Rationale**: [Why this principle exists]

### III. [PRINCIPLE_3_NAME]

**Statement**: [PRINCIPLE_3_DESCRIPTION]

**Constraints**:
- [What this principle forbids or limits]
- [Boundaries that implementations must respect]

**Rationale**: [Why this principle exists]

## Scope

<!--
  THIS SECTION IS NOT THE AUTHORITY ON SCOPE. `docs/requirements.md` is.

  Keep this section as a summary, and diff it against the register whenever
  either changes. Where the two disagree, the REGISTER WINS and this section is
  what gets corrected.

  Why the instruction is this blunt: one project in this fleet carried the
  requestor's first priority under Out of Scope here for two weeks while its
  requirements record listed it as the ask. Nothing read both documents, and five
  figures of source lines were written on the wrong side of the disagreement. A
  scope list in two places with no reconciliation step is worse than one, because
  each looks authoritative on its own.
-->

### In Scope

- [PRIMARY_CAPABILITY_1] — register [ID]
- [PRIMARY_CAPABILITY_2] — register [ID]

### Out of Scope

- [EXCLUDED_CAPABILITY_1 — and why, and the register row that says so]
- [EXCLUDED_CAPABILITY_2 — and why, and the register row that says so]

## Testing Philosophy

<!--
  Default: TDD required. Tests are written before implementation.
  Adjust to match your project's needs during /speckit.constitution.
-->

- **TDD required**: Write tests before implementation code.
- Tests MUST cover all acceptance criteria from the spec.
- Tests SHOULD be independent and deterministic.
- Prefer integration tests at system boundaries; unit tests for complex logic.
- Test failures block merges — no exceptions.

## Quality Gates

| Phase | Gate | Required |
|-------|------|----------|
| **Pre-Spec** | `docs/requirements.md` diffed against the Scope section above; disagreements resolved in the register's favour | Yes |
| **Pre-Commit** | Tests pass, linter clean, no secrets in diff | Yes |
| **Pre-Push** | `scripts/assert-requirements-traceability.sh` exits 0 — every spec FR cites a register ID | Yes |
| **Pre-Merge** | All CI checks green, PR reviewed or self-reviewed against spec | Yes |
| **Release** | All acceptance criteria verified, no open `bug` issues for milestone | Yes |

The Pre-Push gate is a script rather than a review item on purpose. It was a
constitution principle first, and the first spec written under that principle
violated it while its own quality checklist recorded the box as ticked.

## Development Workflow

- All work happens on feature branches, merged to `main` via pull request.
- Follow the spec-kit workflow: specify → plan → tasks → implement.
- Commit after each logical unit of work with a descriptive message.
- Keep PRs focused — one feature or fix per PR.
- Track work with GitHub Issues: label `feature` for new work, `bug` for defects.

## Key Decisions

<!--
  Record significant architectural or design decisions here.
  Each decision should have a revisit trigger — a condition under which
  the decision should be reconsidered.
-->

| # | Decision | Date | Revisit Trigger |
|---|----------|------|-----------------|
| 1 | [DECISION_DESCRIPTION] | [DATE] | [CONDITION_THAT_WOULD_CHANGE_THIS] |

## Governance

This constitution is the highest-priority reference for all implementation decisions. If a spec
or plan conflicts with a principle here, the constitution wins. Amendments require updating this
file, incrementing the version, and noting the change in the sync impact report comment above.

### Elevated Constraints

Some principles are **non-negotiable**. Relaxing an elevated constraint requires:

1. Explicit justification documented in the relevant spec or plan.
2. Approval from the project owner.
3. A note in the Key Decisions table with a revisit trigger.

<!--
  Mark principles as elevated by adding ⚑ after the principle name, e.g.:
  ### I. Simplicity ⚑
-->

**Version**: 0.0.0 | **Ratified**: [RATIFICATION_DATE] | **Last Amended**: [LAST_AMENDED_DATE]
