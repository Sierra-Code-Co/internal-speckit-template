# Claude Code Template

A reusable project template for [Claude Code](https://claude.ai/claude-code) with [GitHub Spec Kit](https://github.com/github/spec-kit) for spec-driven development and multi-model plan review.

> **Docs live elsewhere.** This repo is the *bootstrap artifact* — the thing you clone to start a project. The architecture guides, spec-driven-development walkthrough, multi-model review docs, and the decision records behind all of it live in **[Sierra-Code-Co/claude-workflows](https://github.com/Sierra-Code-Co/claude-workflows)**. Start there if you want to understand the system; start here if you want a new project.
>
> **Personal skills live there too.** This template carries the *project* skills (the `speckit-*` chain, `/review-plan`, `/ship`, `/feature`). Skills that follow a person across every project, such as the writing check, are published from claude-workflows as a Claude Code plugin list and as Microsoft 365 Copilot upload zips: `/plugin marketplace add Sierra-Code-Co/claude-workflows`, then `/plugin install writing-check@sierra-code-co`. See its [installing-skills guide](https://github.com/Sierra-Code-Co/claude-workflows/blob/main/docs/installing-skills.md).

## What's Included

| Component | Source | Purpose |
|-----------|--------|---------|
| `CLAUDE.md` | Template | Project instructions for Claude (fill in placeholders) |
| `AGENTS.md` | Template | Agent workflow guide and read order |
| `.specify/` | Spec Kit (dependency) | Scripts, templates, and memory for spec-driven development |
| `.claude/skills/speckit-*` | Spec Kit (dependency) | Spec-driven development commands |
| `.claude/skills/feature/` | Custom | Full workflow orchestrator (orient, research, specify, plan, review, implement, ship) |
| `.claude/skills/ship/` | Custom | Shipping mechanics as a standalone skill — self-review checklist, unpiped gates, PR, batched review round, merge, per-project promote/verify. `/feature` Phase 6 delegates here; use directly for small fixes that don't need the spec ceremony. |
| `.claude/skills/review-plan/` | Custom | Multi-model peer review gate |
| `scripts/review-plan.sh` | Custom | Sends plans to OpenAI gpt-5.3-codex, Gemini 2.5 Pro for peer review |
| `scripts/install_office_skills.sh` | Custom | Installs Anthropic's official `docx` / `pptx` / `xlsx` skills so Claude Code can generate Word, PowerPoint, and Excel artifacts directly. Re-fetches from upstream (skills are non-redistributable per their LICENSE.txt). |
| `scripts/newproject.zsh-function` | Custom | Sourceable shell function for creating new repos from this template. Wraps `gh repo create --template` + runs `setup.sh` automatically. Source from your `~/.zshrc` to get a `newproject my-project` command. |
| `setup.sh` | Template | Bootstrap script — installs/upgrades spec-kit dependency, runs Office skills install, updates `.gitignore` |

## Quick Start

1. **Create your project** — pick the path that fits your workflow:

   **(a) One-off, no setup required**:

   ```bash
   curl -fsSL https://raw.githubusercontent.com/Sierra-Code-Co/internal-speckit-template/main/scripts/new-project.sh | bash -s my-project
   ```

   Clones the template, strips git history, inits a fresh repo, runs `setup.sh`. Good for trying once.

   **(b) Daily-driver shell command** (recommended if you create projects often):

   ```bash
   # One-time setup — clone the template locally and source the helper from zshrc:
   git clone https://github.com/Sierra-Code-Co/internal-speckit-template.git ~/dev/projects/claude-speckit-template
   echo '[ -f "$HOME/dev/projects/claude-speckit-template/scripts/newproject.zsh-function" ] && source "$HOME/dev/projects/claude-speckit-template/scripts/newproject.zsh-function"' >> ~/.zshrc
   source ~/.zshrc

   # Then any time:
   newproject my-project          # private GitHub repo via gh, clone, runs setup.sh, cds in
   newproject my-project --public  # or override visibility
   newproject my-project --no-setup  # skip setup.sh
   ```

   This uses `gh repo create --template`, so the new repo lands on your GitHub account immediately (private by default).

2. **Edit `CLAUDE.md`** — replace `{{PLACEHOLDERS}}` with your project details:

   ```text
   {{PROJECT_NAME}}        → Your project name
   {{PROJECT_DESCRIPTION}} → One-line description
   {{LANGUAGE}}            → e.g., Python, TypeScript, Go
   {{PACKAGE_MANAGER}}     → e.g., uv, npm, cargo
   {{INSTALL_COMMAND}}     → e.g., uv sync, npm install
   {{TEST_COMMAND}}        → e.g., uv run pytest, npm test
   {{LINT_COMMAND}}        → e.g., uv run ruff check, npm run lint
   {{BUILD_COMMAND}}       → e.g., npm run build, cargo build
   {{DEV_COMMAND}}         → e.g., npm run dev, cargo run
   ```

3. **Set up API keys** for `/review-plan`'s multi-model pre-implementation review (optional):

   ```bash
   cp .env.example .env
   # Add your API keys
   ```

   This is `/review-plan` v1 only, which still calls providers on specs and plans.
   `/review-plan-v2` is the pre-push gate and needs no key: its AI reviewer legs were
   retired on 2026-08-28 and it runs `--static-only`.

4. **Start Claude Code and run:**

   ```text
   /speckit-constitution   # Establish project principles (once)
   /feature                # Start your first feature
   ```

## Prerequisites

### Required for the spec-kit workflow

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) (or Claude Code desktop/web)
- [Git](https://git-scm.com/)
- [GitHub CLI](https://cli.github.com/) (`gh`) — needed by `newproject`
- [uv](https://docs.astral.sh/uv/) (Python package manager, for the spec-kit CLI)

### Required additionally for the Office skills (`setup.sh` checks for these)

- **Node.js + npm** — used by the `docx-js` and `pptxgenjs` libraries the skills run
- **Python 3.13** — **NOT 3.14** (see Gotchas)
- **pandoc** — used by the `docx` skill to read Word docs

### Optional (enables the visual QA loop on slides + Word docs)

- **LibreOffice** (`brew install --cask libreoffice`) — for rendering `.pptx`/`.docx` → PDF
- **poppler** (`brew install poppler`) — provides `pdftoppm` to convert the PDFs to JPEG thumbnails

Without LibreOffice + poppler, the skills still generate Office files correctly; you just lose the "render to images and visually QA" loop. Content-only QA (extract text, check fidelity) still works.

### macOS one-shot install

```bash
brew install gh node pandoc python@3.13 poppler
brew install --cask libreoffice
curl -LsSf https://astral.sh/uv/install.sh | sh
```

## Workflow

The `/feature` skill orchestrates the full development lifecycle:

```text
Phase 1: Orient     → Read context, check backlog, recommend next work
Phase 2: Research   → Online research before committing to an approach
Phase 3: Specify    → /speckit-specify — write the feature spec
Phase 4: Plan       → /speckit-plan + /speckit-tasks — architecture + task breakdown
Phase 4.5: Review   → /review-plan — multi-model peer review (GREEN/YELLOW/RED)
Phase 5: Implement  → /speckit-implement — TDD execution
Phase 6: Ship       → /ship — gates, PR, batched review, merge; promote/verify if the project defines a pipeline
```

## Updating Spec Kit

Spec Kit is installed as a dependency via `specify init`, not vendored as frozen copies. To pull the latest version:

```bash
./setup.sh
```

This upgrades the `specify` CLI and re-runs `specify init` to update scripts, templates, and commands while preserving your custom skills and project files.

## Work Tracking

This template uses **GitHub Issues as the primary tracker** — not parallel markdown files.

- Label issues with `feature`, `bug`, or `chore`
- Use milestones for release grouping
- Convert spec tasks to issues with `/speckit-taskstoissues`
- Close issues via PR references (`Closes #N`)

## Office Artifacts (Word / PowerPoint / Excel)

`setup.sh` installs Anthropic's official `docx`, `pptx`, and `xlsx` skills into `.claude/skills/`. After setup, Claude Code can generate Office files directly when asked — useful for status reports, mgmt decks, spreadsheets that summarize work.

### How to use

```text
You: "Generate a status report Word doc from the last 5 commits."
You: "Build me a 10-slide deck explaining this feature for non-technical stakeholders."
You: "Make an Excel workbook with the test-coverage numbers from the last 3 sprints."
```

The skills auto-invoke based on keywords (`Word doc`, `.docx`, `slides`, `deck`, `presentation`, `spreadsheet`, `.xlsx`, etc.).

### What the install actually does

`setup.sh` calls `scripts/install_office_skills.sh`, which:

1. **Caches the upstream skills repo** at `~/.cache/anthropic-skills` (clones first time, `git fetch` + `reset --hard origin/HEAD` on re-run).
2. **Copies the requested skills** (`docx`, `pptx`, `xlsx` by default) from the cache into `.claude/skills/` in your project.
3. **Verifies runtime tools** — `node`, `npm`, `python3.13`, `pandoc` required; `soffice` + `pdftoppm` optional (for the visual QA loop).
4. **Installs npm globals** `docx@^9` and `pptxgenjs@^4` if missing — these are the libraries the skills `require()` at runtime.
5. **Updates `.gitignore`** — adds `.claude/skills/{docx,pptx,xlsx}/` (non-redistributable, see below) plus `*.docx`, `*.pptx`, `*.xlsx`, `*.pdf`, `~$*` (generated artifacts are hand-off only).

Run it standalone at any time to refresh: `./scripts/install_office_skills.sh`. Re-runnable, idempotent.

### Why the skills aren't vendored

Anthropic's `LICENSE.txt` for each skill (you can read it at `.claude/skills/docx/LICENSE.txt` after install) explicitly prohibits:

- Extracting or retaining copies outside Anthropic Services
- Reproducing, copying, or distributing the materials
- Creating derivative works
- Sublicensing or transferring to third parties

The compliant pattern is therefore: **re-fetch from `github.com/anthropics/skills` at install time, never commit a copy**. `setup.sh` does this; `.gitignore` makes sure you can't accidentally `git add` them. Same goes for any fork of this template — don't vendor the skills.

### Gotchas (real ones we hit during validation)

- **Python 3.14 has a broken `pyexpat`** on macOS Homebrew at the time of writing — `python3.14 -c "import xml.etree.ElementTree"` fails with `Symbol not found: _XML_SetAllocTrackerActivationThreshold`. This breaks `python-pptx`, `python-docx`, `markitdown`, etc. **Use `python3.13` explicitly** (`brew install python@3.13`). The install script checks for `python3.13` specifically.
- **Node 25 module resolution**: globally-installed npm packages don't resolve from arbitrary `cwd` without `NODE_PATH`. If you write your own Node script that uses these libraries, set `NODE_PATH=$(npm root -g)` when running:

  ```bash
  NODE_PATH=$(npm root -g) node my-build-script.js
  ```

  (The skills handle this internally when invoked via Claude — only matters for hand-written scripts.)
- **`gh repo create --template --internal` requires an org**. Personal accounts only support `--public` and `--private`. The `newproject` helper defaults to `--private`.
- **macOS PEP 668 / `--break-system-packages`**: if you try `pip3 install python-pptx` directly, macOS-Python refuses by design. Use `uv` or `pipx`, or pass `--break-system-packages` knowingly. The Office skills mostly use the Node libraries, so this rarely bites unless you also want `markitdown` for content extraction.
- **LibreOffice is ~300MB**. Install is via `brew install --cask libreoffice` and takes 1–3 min on a fast connection. Worth it if you want the visual QA loop; skippable if you just want to generate files and look at them yourself in Word.
- **Skills appear mid-session**: if you `./setup.sh` while Claude Code is already running, the new skills surface in the available-skills list immediately (no restart needed). But if anything looks off, restart Claude Code to be safe.
- **`soffice` first-run** opens a couple of dialogs on macOS (Java JRE prompt, etc.). Run `soffice --headless --convert-to pdf /tmp/throwaway.pptx` once interactively before relying on it in scripts.

### Validation evidence

End-to-end validated in a real project (the [Grace Church Reno teaching workspace](https://github.com/jabelk/grace-church-reno-teaching) at sister-repo `~/dev/projects/grace-church-reno-teaching`):

1. Installed both skills (`docx` + `pptx`) into the project via this script.
2. Invoked the `pptx` skill via Claude Code's Skill tool to build a 22-slide deck.
3. Skill auto-loaded `pptxgenjs`, wrote a `build_slides.js` in the project's scratch space, ran it, produced a `.pptx`.
4. Ran the skill's full QA loop:
   - **Content QA** via raw XML extraction (`unzip` the `.pptx` → grep `<a:t>` text nodes — works on stdlib Python, no extra deps).
   - **Visual QA** via `soffice → PDF → pdftoppm → JPEG → general-purpose subagent inspection` (the skill explicitly requires "USE SUBAGENTS — even for 2-3 slides").
   - First pass found 5 layout bugs (closer lines colliding with footers on 4 slides + a mid-number wrap on a stat callout). Fix-and-verify cycle: regenerated, re-rendered, re-inspected. Second pass clean.
5. Output quality matched what claude.ai's web cowork produces — same libraries (`docx-js`, `pptxgenjs`), same skill content. The platform difference is just skill auto-loading + sandbox iteration ergonomics, not capability.

### Re-running

`scripts/install_office_skills.sh` is re-runnable; it refreshes the cached upstream clone and reinstalls. Worth running occasionally to pick up skill updates from Anthropic.

## Customization

### review-plan.sh

Edit the `SYSTEM_PROMPT` in `scripts/review-plan.sh` to add framework-specific review focus areas. For example:

```text
6. FRAMEWORK GOTCHAS: SvelteKit/Svelte 5 specific issues ($derived tracking, rune file restrictions)
```

### Adding Skills

Add new skills in `.claude/skills/<skill-name>/SKILL.md`. See existing skills for the frontmatter format.
