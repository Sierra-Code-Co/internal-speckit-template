#!/usr/bin/env bash
# setup.sh — Bootstrap a new project from this template
#
# Usage:
#   1. Create a new repo from this template (GitHub "Use this template" or manual copy)
#   2. Run: ./setup.sh
#
# This script:
#   - Installs/upgrades the specify CLI (via uv)
#   - Re-initializes spec-kit to pull latest upstream scripts, templates, and commands
#   - Preserves your custom skills (/feature, /review-plan) and scripts

set -eo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$REPO_ROOT"

echo "=== Claude Code Template Setup ==="
echo ""

# Check for uv
if ! command -v uv &>/dev/null; then
  echo "ERROR: uv is required but not installed."
  echo "Install it: curl -LsSf https://astral.sh/uv/install.sh | sh"
  exit 1
fi

# Install the specify CLI, pinned to a known release so every machine vendors
# the same payload. Unpinned installs track the default branch and ship
# x.y.z.dev0 builds — that's how a "0.5.0" template ended up alongside a
# 0.14.x CLI. Bump this ONE variable to upgrade, then review the diff.
SPECKIT_VERSION="v1.0.1"
echo "Installing specify CLI ${SPECKIT_VERSION}..."
uv tool install --force specify-cli --from "git+https://github.com/github/spec-kit.git@${SPECKIT_VERSION}"

echo ""

# Check for git
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  echo "Initializing git repository..."
  git init
fi

# Back up custom files that specify init might overwrite. cp -a preserves
# permissions (scripts must keep their exec bits through a restore).
BACKUP_DIR=$(mktemp -d)
echo "Backing up custom skills and scripts..."
# A missing source is fine (skill not installed); a FAILED copy is not — with
# set -e it aborts setup here, before specify init has touched anything, rather
# than continuing without a backup and potentially clobbering the skill.
backup_dir() { [ -d "$1" ] || return 0; cp -a "$1" "$2"; }
backup_dir "$REPO_ROOT/.claude/skills/feature" "$BACKUP_DIR/feature"
backup_dir "$REPO_ROOT/.claude/skills/review-plan" "$BACKUP_DIR/review-plan"
backup_dir "$REPO_ROOT/.claude/skills/review-plan-v2" "$BACKUP_DIR/review-plan-v2"
backup_dir "$REPO_ROOT/.claude/skills/ship" "$BACKUP_DIR/ship"
backup_dir "$REPO_ROOT/scripts" "$BACKUP_DIR/scripts"

# If specify init dies mid-run, set -e would otherwise skip the restore and
# leave the tree half-overwritten with the backups stranded in a tmpdir.
restore_all() {
  [ -d "$BACKUP_DIR" ] || return 0
  local any_failed=0
  for pair in "feature:.claude/skills/feature" \
              "review-plan:.claude/skills/review-plan" \
              "review-plan-v2:.claude/skills/review-plan-v2" \
              "ship:.claude/skills/ship" \
              "scripts:scripts"; do
    src="$BACKUP_DIR/${pair%%:*}"; dest="$REPO_ROOT/${pair#*:}"
    [ -d "$src" ] || continue
    # Stage-then-swap: never delete the destination until the copy succeeded,
    # and never delete the backup unless every restore succeeded.
    stage="${dest}.restore.$$"
    if cp -a "$src" "$stage" 2>/dev/null && rm -rf "$dest" && mv "$stage" "$dest"; then
      :
    else
      rm -rf "$stage"
      echo "Warning: failed to restore $dest from backup" >&2
      any_failed=1
    fi
  done
  if [ "$any_failed" -ne 0 ]; then
    echo "ERROR: backups preserved at $BACKUP_DIR — restore by hand" >&2
  else
    rm -rf "$BACKUP_DIR"
  fi
}
trap restore_all EXIT

# Run specify init to pull latest spec-kit
echo "Running specify init (pulling latest spec-kit)..."
specify init --here --integration claude --force

# Restore custom files.
# Remove the destination first so `cp -r` replaces it instead of nesting a copy
# inside an existing dir (e.g. .claude/skills/feature/feature). Current spec-kit
# leaves these custom files in place, so the dest dir exists at restore time.
echo "Restoring custom skills and scripts..."
# Stage-then-swap: the destination is only replaced after the staged copy
# succeeds, so a failed cp leaves both the destination and the backup intact.
restore_failed=0
restore_dir() {
  local src="$1" dest="$2" label="$3" stage
  [ -d "$src" ] || return 0
  stage="${dest}.restore.$$"
  if cp -a "$src" "$stage" 2>/dev/null && rm -rf "$dest" && mv "$stage" "$dest"; then
    return 0
  fi
  rm -rf "$stage"
  echo "Warning: failed to restore $label from backup" >&2
  restore_failed=1
}
restore_dir "$BACKUP_DIR/feature" "$REPO_ROOT/.claude/skills/feature" "/feature skill"
restore_dir "$BACKUP_DIR/review-plan" "$REPO_ROOT/.claude/skills/review-plan" "/review-plan skill"
restore_dir "$BACKUP_DIR/review-plan-v2" "$REPO_ROOT/.claude/skills/review-plan-v2" "/review-plan-v2 skill"
restore_dir "$BACKUP_DIR/ship" "$REPO_ROOT/.claude/skills/ship" "/ship skill"
restore_dir "$BACKUP_DIR/scripts" "$REPO_ROOT/scripts" "scripts/"
if [ "$restore_failed" -ne 0 ]; then
  echo "ERROR: restoration failed for one or more customs — backups preserved at $BACKUP_DIR" >&2
  trap - EXIT
  exit 1
fi
rm -rf "$BACKUP_DIR"

# Keep upstream's `disable-model-invocation: false`, and assert it.
#
# This block did the OPPOSITE until 2026-08-28: it flipped upstream's `false` to
# `true` on every re-vendor, on the theory that a workflow-shaped skill should
# be an explicit slash command only and that auto-firing /speckit-specify
# mid-conversation is a real failure mode. The theory did not survive contact
# with the fleet. Every project spun up from this template arrived with all
# eleven skills unavailable to the model, and the operator flipped them back to
# `false` by hand in each one — one downstream project has all eleven flipped,
# another has ten of eleven. A default that is manually reverted
# in every instance is not a safety property, it is a chore, and the one file
# missed in the reverting is how the fleet drifts.
#
# The auto-fire concern was also aimed at the wrong lever. A skill Claude cannot
# reach is a skill Claude will not use when it should — /review-plan-v2 is
# exactly the one a pre-push moment ought to reach for without being summoned.
# The concern is real for a narrow class, and the fix is per-skill: /ship stays
# slash-command-only because it merges PRs, pushes branches, and runs
# promote/deploy steps, and that reason is recorded in KEEP_DISABLED in the
# assert script AND in ship/SKILL.md's own frontmatter. One exception with a
# stated reason, not a blanket rule with none.
#
# The verification half is kept and inverted, because it is the useful half: a
# no-op re-apply must fail loudly rather than silently leave the fleet in the
# state this change exists to end.
echo "Asserting disable-model-invocation: false on project skills..."
"$REPO_ROOT/scripts/assert-skill-invocation.sh" "$REPO_ROOT" || exit 1

# Repair the checklist filename collision that `specify init` reintroduces.
# `/speckit-specify` is vendored, and it writes its spec-QUALITY checklist to
# specs/*/checklists/requirements.md. With the requirements register living at
# docs/requirements.md, grepping a repo for `requirements.md` then returns the
# wrong file, and a coding agent reads a quality checklist as the scope of the
# project. One repo in this fleet did exactly that.
#
# Non-fatal here on purpose, and the exit code is the reason. This script exits 1
# for untraceable FRs too, which on a fresh template is the expected state — a
# starter register with example IDs and no specs yet. Aborting setup on that would
# make every bootstrap fail. The pre-push gate is where a non-zero must block; at
# setup time the useful half is the rename, and the traceability report is
# information for the operator.
echo ""
echo "Repairing checklist filename collisions and reporting FR traceability..."
if [ -x "$REPO_ROOT/scripts/assert-requirements-traceability.sh" ]; then
  "$REPO_ROOT/scripts/assert-requirements-traceability.sh" "$REPO_ROOT" || \
    echo "Note: traceability findings above are advisory at setup time; they block at pre-push." >&2
else
  echo "Warning: scripts/assert-requirements-traceability.sh missing or not executable." >&2
fi

# Install Anthropic's official Office skills (docx, pptx, xlsx) for generating
# Word / PowerPoint / Excel artifacts (status reports, decks for mgmt, etc.)
# directly from Claude Code. The skills are non-redistributable per their LICENSE.txt,
# so we never vendor them — install_office_skills.sh re-fetches from upstream and
# adds .claude/skills/{docx,pptx,xlsx} to .gitignore on first run.
# Non-fatal: if install fails (no network, missing deps), the rest of setup still completes.
echo ""
echo "Installing Anthropic Office skills (docx / pptx / xlsx)..."
if [ -x "$REPO_ROOT/scripts/install_office_skills.sh" ]; then
  if ! "$REPO_ROOT/scripts/install_office_skills.sh"; then
    echo "Warning: Office skills install failed. Re-run scripts/install_office_skills.sh manually when ready." >&2
  fi
else
  echo "Warning: scripts/install_office_skills.sh missing or not executable; skipping Office skills install." >&2
fi

# Ensure .gitignore excludes the non-redistributable skill content + generated Office artifacts.
GI="$REPO_ROOT/.gitignore"
touch "$GI"
add_gitignore_line() {
  local line="$1"
  grep -Fxq "$line" "$GI" || echo "$line" >> "$GI"
}
if ! grep -q "Anthropic Office skills" "$GI" 2>/dev/null; then
  printf '\n# Anthropic Office skills — non-redistributable per their LICENSE.txt.\n# Re-installed at setup time via scripts/install_office_skills.sh.\n' >> "$GI"
  add_gitignore_line ".claude/skills/docx/"
  add_gitignore_line ".claude/skills/pptx/"
  add_gitignore_line ".claude/skills/xlsx/"
  printf '\n# Generated Office artifacts — hand-off only, never commit.\n' >> "$GI"
  add_gitignore_line "*.docx"
  add_gitignore_line "*.pptx"
  add_gitignore_line "*.xlsx"
  add_gitignore_line "*.pdf"
  add_gitignore_line "~\$*"
  echo "Added Office skills + artifacts entries to .gitignore."
fi

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Next steps:"
echo "  1. Edit CLAUDE.md — replace {{PLACEHOLDERS}} with your project details"
echo "  2. Run /speckit-constitution to establish project principles"
echo "  3. Run /feature to start your first feature"
echo "  4. (Optional) Restart Claude Code so the new docx/pptx/xlsx skills appear in the skill list"
echo ""
echo "For multi-model plan review, add API keys to .env:"
echo "  OPENAI_API_KEY=..."
echo "  GEMINI_API_KEY=..."
echo ""
echo "For Office artifacts (Word / PowerPoint / Excel):"
echo "  - Ask Claude to 'create a Word doc' or 'build a slide deck' — the skills auto-invoke."
echo "  - For visual QA loop: brew install --cask libreoffice (optional; without it,"
echo "    QA falls back to content-only checks)."
