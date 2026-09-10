# {{PROJECT_NAME}}

{{PROJECT_DESCRIPTION}}

## Tech Stack

<!-- Replace with your project's tech stack -->
- {{LANGUAGE}} (managed with {{PACKAGE_MANAGER}})

## Common Commands

<!-- Replace placeholders with your project's actual commands -->

| Action | Command |
|--------|---------|
| Install dependencies | `{{INSTALL_COMMAND}}` |
| Run tests | `{{TEST_COMMAND}}` |
| Run linter | `{{LINT_COMMAND}}` |
| Build | `{{BUILD_COMMAND}}` |
| Run dev server | `{{DEV_COMMAND}}` |

## Environment Variables

<!-- If your project uses environment variables, maintain a `.env.example` file at the repo root -->
See `.env.example` for required environment variables (if applicable).

## Branching Strategy

- **Never commit directly to `main`.**
- **Never force push.** If history needs rewriting, discuss first.
- **Always create a pull request** for every change merged to `main`.
- For each unit of work (feature, fix, refactor), create a new branch off `main`:
  - Format: `<short-description>` (e.g., `add-episode-parser`, `fix-url-handling`)
- When work is complete, create a pull request against `main` with a summary of what was done.
- Merge the PR (squash or merge commit, no rebase) to keep a clean paper trail.
- **Do not delete branches on merge.** Feature branches are kept as the paper trail
  for the PR that shipped them, and long-lived branches (`main`, `staging`) must never
  be deleted — never pass `--delete-branch` to `gh pr merge`. This line said "delete
  the feature branch after merge" until 2026-08-31, which contradicted
  `.claude/skills/ship/SKILL.md`; a repo cannot hold both rules and have either mean
  anything, and CodeRabbit flagged the pair.

## Testing & Verification

The project's testing philosophy is defined in `.specify/memory/constitution.md` (see Testing Philosophy and Quality Gates sections). In short:

- Write tests before implementation (TDD).
- All tests must pass before committing or merging.
- No secrets or credentials in code or commits.

### Post-Implementation Checklist

- [ ] All acceptance criteria from the spec are covered by tests
- [ ] Tests pass locally (`{{TEST_COMMAND}}`)
- [ ] Linter is clean (`{{LINT_COMMAND}}`)
- [ ] No secrets, API keys, or credentials in the diff
- [ ] PR description references the spec and summarizes changes

## Documentation Strategy

There are two documentation audiences. Keep them separate.

### For Agents: `.specify/` (source of truth)

All design decisions, specs, plans, and task tracking live here. This is the **primary reference for Claude and other coding agents**. Before making implementation decisions, always consult the relevant `.specify/` files.

**Directory structure:**

| Path | Purpose | When to update |
|------|---------|----------------|
| `.specify/memory/constitution.md` | Non-negotiable project principles. All work must comply. | Rarely — only when principles change. |
| `.specify/memory/project-tracker.md` | Project state overview and pointer to GitHub Issues. | When milestones or stack change. |
| `.specify/memory/lessons-learned/` | Lessons learned from implementation. | After resolving unexpected issues. |
| `specs/<feature>/spec.md` | What to build. User stories, requirements, acceptance criteria. | Created via `/speckit-specify`, updated if requirements change. |
| `specs/<feature>/plan.md` | How to build it. Tech choices, architecture, project structure. | Created via `/speckit-plan`, updated if approach changes. |
| `specs/<feature>/tasks.md` | Ordered task breakdown with dependencies and checkpoints. | Created via `/speckit-tasks`, checked off during implementation. |
| `specs/<feature>/research.md` | Phase 0 research output (dependencies, alternatives). | Created during `/speckit-plan`. |
| `specs/<feature>/data-model.md` | Entity definitions and relationships. | Created during `/speckit-plan`. |
| `specs/<feature>/contracts/` | API contracts, interfaces. | Created during `/speckit-plan`. |
| `.specify/templates/` | Templates used by spec-kit. Do not edit directly. | Never — managed by spec-kit. |
| `.specify/scripts/` | Helper scripts for spec-kit. Do not edit directly. | Never — managed by spec-kit. |

### For Humans: `docs/` and `README.md`

High-level documentation for human readers lives in `docs/` and the repo `README.md`.

- `README.md` — Project overview, how to install, how to run, quick examples.
- `docs/` — Architecture overview, design rationale, usage guides. Written in plain language for a human audience.

### Rules for Documentation Updates

1. **Do not create markdown files outside of `.specify/`, `docs/`, or `README.md`** unless explicitly asked.
2. **Do not proactively generate or rewrite docs.** Only update docs when: (a) the user asks, or (b) a spec-kit command requires it.
3. **Keep updates surgical.** When updating a `.specify/` file, edit the specific section that changed — do not regenerate the entire file.
4. **Spec files are append/edit, not rewrite.** If a plan or spec exists, update it incrementally. Do not overwrite prior decisions without discussion.

## Tracking Work

- **GitHub Issues are the primary tracker.** Use labels: `feature` for new work, `bug` for defects.
- Use `/speckit-taskstoissues` to convert spec tasks into GitHub Issues.
- Close issues via PR references (e.g., `Closes #12`) — do not close manually unless no code change is needed.

## Scope lives in one file, and it is not this one

**Read [`docs/requirements.md`](docs/requirements.md) before writing or extending a spec.** It is the
requirements register: numbered IDs, a verbatim quote per requirement, a provenance reference, a
status of Confirmed / Asked / Inferred / Open, and a named owner for every open question.

Three rules, and the third is mechanical because the first two were tried as prose and failed:

1. **Every functional requirement in every `specs/*/spec.md` cites a register ID.** An FR that cannot
   cite one is a deletion candidate, not a feature.
2. **Diff the register against the constitution's scope before writing a spec.** If they disagree
   about whether something is in scope, stop and resolve it first. **The register wins; the
   constitution is what gets corrected.**
3. **`scripts/assert-requirements-traceability.sh` enforces rule 1** and runs in the pre-push gate.
   It also repairs the `checklists/requirements.md` filename collision that `/speckit-specify`
   recreates on every feature.

Why this is stated ahead of the workflow, and why rule 3 exists. One project in this fleet reached
five figures of source lines on `main` containing **zero lines of the requestor's first priority**.
Its constitution's Out of Scope section named that priority as somebody else's problem for two weeks
while the requirements record listed it as the ask, and nothing read both documents. Each spec's
`Input:` field paraphrased whoever ran the command, so no FR traced to anyone's request, and one spec
built an 8,000-line datastore for a consumer that did not exist yet.

The fix was a traceability principle in the constitution — and **the very first spec written under
that principle shipped two FRs citing constitution principles instead of register IDs, with the
spec-quality checklist's traceability box ticked**. A vendor review round caught it. That is why rule
3 is a script: a rule whose only enforcement is someone remembering to look has a known failure rate,
and this one failed on its first use.

The register is **committed to the repo that holds the code**, because requirements change the code.
What stays in a notes workspace is what would change *who to talk to or how to pitch something*:
meeting transcripts, stakeholder read-outs, anything candid about a named person. Reach that through
a gitignored symlink; never copy it in.

## Spec-Driven Development Workflow

This project uses [GitHub Spec Kit](https://github.com/github/spec-kit). The workflow is:

1. `/speckit-constitution` — Establish project principles (done once, lives in `.specify/memory/constitution.md`)
2. `/speckit-specify` — Write the specification for a feature
3. `/speckit-plan` — Create the implementation plan
4. `/speckit-tasks` — Break the plan into ordered tasks
5. `/review-plan` — Multi-model peer review (OpenAI gpt-5.3-codex, Gemini 2.5 Pro)
6. `/speckit-implement` — Execute tasks

**Use `/feature` to run the full workflow end-to-end** — it orchestrates all steps in order with research and review gates.

**Before writing any code**, check that a spec and plan exist for the work. If they don't, raise it with the user.

## Agent Behavior Guidelines

- **Always read `docs/requirements.md` before starting a new feature**, and diff it against the constitution's scope. On disagreement, stop: the register wins.
- **Always read `.specify/memory/constitution.md` before starting a new feature** to ensure compliance with project principles.
- **Always read the relevant `specs/<feature>/` files before implementing** to understand the design decisions already made.
- **Never name a checklist `requirements.md`.** That path is the requirements register. Spec-quality checklists are `specs/<feature>/checklists/spec-quality.md`.
- **Do not skip the spec-kit workflow.** If asked to build something new, suggest running through specify → plan → tasks → implement.
- **Commit after each logical unit of work**, not after every single file change.
- **When in doubt about a design decision**, check the spec and plan first, then ask the user.
- **Verify before shipping**: For any new library integration, read the actual installed source code and run a minimal working example BEFORE writing the full implementation.

## Related Documentation

| Document | Purpose |
|----------|---------|
| `docs/requirements.md` | **The requirements register — the authoritative scope.** Every spec FR cites an ID from it. |
| `.specify/memory/constitution.md` | Project principles, testing philosophy, quality gates |
| `.specify/memory/project-tracker.md` | Current project state, pointer to GitHub Issues |
| `.specify/memory/lessons-learned/` | Lessons learned index and topic files |
| `AGENTS.md` | Agent-specific workflow guide and read order |
| `specs/` | Feature specifications, plans, and tasks |

## Active Technologies
<!-- Updated automatically by spec-kit during /speckit-plan -->

## Recent Changes
<!-- Updated automatically by spec-kit during /speckit-plan -->
