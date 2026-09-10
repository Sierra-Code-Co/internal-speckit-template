#!/usr/bin/env bash
# Assert that every functional requirement in every spec cites an ID from the
# requirements register, and repair the checklist filename collision that makes
# the register ungreppable.
#
# Why this is a script and not a convention. One project in this fleet carried
# "every FR cites a register ID" as a constitution principle, ELEVATED, written
# the same week — and the very first spec authored under it shipped two FRs
# citing constitution principles instead of register IDs, with the spec-quality
# checklist's traceability box ticked. A vendor review round found it, not the
# author and not the checklist. A rule whose only enforcement is someone
# remembering to look is a rule with a known failure rate.
#
# Two checks, reported separately because they fail for unrelated reasons:
#
#   collision  — `specs/*/checklists/requirements.md` is spec-kit's built-in
#                spec-QUALITY checklist. With the register at docs/requirements.md,
#                grepping a repo for `requirements.md` returns the wrong file, and
#                a coding agent reads a quality checklist as the scope of the
#                project. This check RENAMES it to spec-quality.md and rewrites
#                references within the feature directory.
#
#   traceability — every `FR-NNN` in every specs/*/spec.md must cite at least one
#                ID that the register actually defines.
#
# The collision check repairs rather than merely failing, and that is deliberate.
# `/speckit-specify` is vendored from upstream and recreates the file on every new
# feature, so failing would hand back a per-feature chore, and a gate whose remedy
# is a manual rename every time is a gate that gets skipped. It fails loudly on
# anything it cannot repair, and it names every file it touches — a run is never
# silent about having changed the tree.
#
# The traceability check does NOT repair. There is no safe automatic fix: an FR
# that cites nothing is either mis-cited (a human must pick the right ID) or has
# no register row at all (a human must go ask), and inventing a citation would
# turn a real gap into a passing build. This is the one asymmetry between the two
# checks and it is the point.
#
# Exit codes, deliberately NOT one code for everything:
#   0  clean. Repairs may have happened and are named on stdout.
#   1  actionable findings. Untraceable FRs, or a collision it could not repair.
#   2  tool error, or it could not look. Never confuse with 0.
#
# The 0/1/2 split exists because "found problems" and "could not run" must not
# print the same status. A caller gating on a single non-zero cannot tell a spec
# that violates traceability from a script that never read a file.

set -uo pipefail

PROG=$(basename "$0")

# ---------------------------------------------------------------------------
# Locate the repository. A positional argument wins, matching the sibling
# assert-skill-invocation.sh so setup.sh calls both the same way; then REPO_ROOT,
# so the suite can aim this at a fixture without cd-ing; then the enclosing repo.
# ---------------------------------------------------------------------------
if [ -n "${1:-}" ]; then
  root=$1
elif [ -n "${REPO_ROOT:-}" ]; then
  root=$REPO_ROOT
else
  root=$(git rev-parse --show-toplevel 2>/dev/null) || {
    printf '%s: not a git repository, and neither an argument nor REPO_ROOT was given\n' "$PROG" >&2
    exit 2
  }
fi

[ -d "$root" ] || { printf '%s: not a directory: %s\n' "$PROG" "$root" >&2; exit 2; }

REGISTER=${REGISTER:-docs/requirements.md}
register_path="$root/$REGISTER"

findings=0
repairs=0

note()    { printf '%s\n' "$*"; }
finding() { printf 'FINDING: %s\n' "$*" >&2; findings=$((findings + 1)); }

# ---------------------------------------------------------------------------
# Check 1: the checklist filename collision.
#
# Repair is a rename plus a reference rewrite scoped to the feature directory.
# Scoped, because a reference to `checklists/requirements.md` OUTSIDE a feature
# dir may well be prose about spec-kit's own built-in name (this script's header
# is such a reference), and rewriting those would be editing documentation to
# satisfy a check.
# ---------------------------------------------------------------------------
collision_check() {
  local specs_dir="$root/specs" old new feature
  [ -d "$specs_dir" ] || { note 'collision: no specs/ directory, nothing to check'; return 0; }

  local found=0
  while IFS= read -r old; do
    [ -n "$old" ] || continue
    found=$((found + 1))
    new="${old%/requirements.md}/spec-quality.md"
    feature=$(dirname "$(dirname "$old")")

    if [ -e "$new" ]; then
      finding "collision: both $(relpath "$old") and $(relpath "$new") exist. Cannot repair — two files, and only a human knows which is current. Merge them by hand."
      continue
    fi

    if git -C "$root" ls-files --error-unmatch "$(relpath "$old")" >/dev/null 2>&1; then
      git -C "$root" mv "$(relpath "$old")" "$(relpath "$new")" || {
        finding "collision: git mv failed for $(relpath "$old")"
        continue
      }
    else
      mv "$old" "$new" || { finding "collision: mv failed for $(relpath "$old")"; continue; }
    fi

    # Verify the end state rather than trusting the command's exit code.
    if [ -e "$old" ] || [ ! -e "$new" ]; then
      finding "collision: rename of $(relpath "$old") did not take"
      continue
    fi

    note "renamed: $(relpath "$old") -> $(relpath "$new")"
    repairs=$((repairs + 1))

    # Rewrite references, inside this feature directory only.
    local ref rewrote=0
    while IFS= read -r ref; do
      [ -n "$ref" ] || continue
      local tmp="$ref.assert-tmp.$$"
      if sed 's|checklists/requirements\.md|checklists/spec-quality.md|g' "$ref" > "$tmp" \
         && ! cmp -s "$ref" "$tmp"; then
        mv "$tmp" "$ref" && { note "rewrote reference: $(relpath "$ref")"; rewrote=$((rewrote + 1)); }
      fi
      rm -f "$tmp"
    done < <(grep -rl 'checklists/requirements\.md' "$feature" 2>/dev/null || true)

    # A rename with surviving references is a half-repair, and a half-repair that
    # exits 0 is the failure class this whole script is about.
    if grep -rq 'checklists/requirements\.md' "$feature" 2>/dev/null; then
      finding "collision: references to the old name survive under $(relpath "$feature") after rewriting $rewrote file(s)"
    fi
  done < <(find "$specs_dir" -type f -path '*/checklists/requirements.md' 2>/dev/null | sort)

  [ "$found" -eq 0 ] && note 'collision: none found'
  return 0
}

relpath() { printf '%s' "${1#"$root"/}"; }

# ---------------------------------------------------------------------------
# Check 2: FR traceability.
# ---------------------------------------------------------------------------

# Register IDs come from three places, and missing any one of them makes a real
# citation read as no citation:
#
#   - the first cell of a table row      | R1.2 | ... |   -> R1.2
#   - a requirement-group heading        ### R1 — Name    -> R1
#   - the parent of any dotted sub-ID    R1.2 exists      -> R1 is citable
#
# The heading and parent forms are not decoration. A register that states a group
# in prose and only tables its sub-requirements still has citable groups, and an
# FR that cites the group is citing something real. Extracting table cells alone
# was the first version of this function and it reported 8 false findings against
# a real 41-row register on the first run.
#
# Markdown emphasis is stripped because a register may bold an ID it wants to
# stand out, and `**R4.4**` is the same ID as `R4.4`.
register_ids() {
  sed -e 's/[*_`]//g' "$register_path" \
    | awk -F'|' '
        /^[[:space:]]*\|/ {
          cell = $2
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", cell)
          if (cell ~ /^[RCQ][0-9]+(\.[0-9]+)?$/) { print cell; emit_parent(cell) }
          next
        }
        /^[[:space:]]*#+[[:space:]]/ {
          h = $0
          sub(/^[[:space:]]*#+[[:space:]]+/, "", h)
          if (match(h, /^[RCQ][0-9]+/)) print substr(h, RSTART, RLENGTH)
        }
        function emit_parent(id) {
          if (match(id, /^[RCQ][0-9]+\./)) print substr(id, 1, RLENGTH - 1)
        }' \
    | sort -u
}

# An FR block is the line that DEFINES an FR plus the indented, non-blank lines
# that follow it. Wrapped FRs are the normal case at a 100-column limit, so a
# citation on a continuation line is still a citation.
#
# "Defines" means the ID is STRUCTURALLY MARKED at the start of the line: behind
# a list bullet, behind a heading marker, or bolded. Two weaker rules were tried
# against a real repo first and both were wrong:
#
#   - "the line mentions the ID" — a spec's rationale prose refers to its own FRs
#     constantly, so this reported FR-010 four times and inflated 76 requirements
#     to 113. A finding you get four copies of is a finding nobody trusts.
#   - "the ID opens the line" — a wrapped paragraph whose text happens to break
#     just before `FR-029 was appended rather than renumbered` opens a line with
#     a bare ID. That produced one false finding against a spec where every FR
#     was correctly cited, which is the worse direction to be wrong in: a gate
#     that cries wolf on a clean spec is a gate that gets bypassed.
#
# So emphasis is stripped for the TEXT but the structural probe runs on the raw
# line, because the bold markers are the signal being tested. A prose line
# beginning with a bare ID is not a definition, and that distinction is the only
# thing separating the two failures above.
#
# The optional trailing letter matters: `FR-010a` is a distinct requirement from
# `FR-010`, and truncating it silently merges the two.
# Emitted as "FR-NNN<TAB>flattened text".
fr_blocks() {
  awk '
    function flush() {
      if (id != "") { gsub(/\t/, " ", buf); printf "%s\t%s\n", id, buf }
      id = ""; buf = ""
    }
    {
      line = $0
      stripped = line; gsub(/[*_`]/, "", stripped)
      if (line ~ /^[[:space:]]*([-*+][[:space:]]+|#+[[:space:]]+)?\*\*FR-[0-9]+[a-z]?\*\*/ ||
          line ~ /^[[:space:]]*([-*+]|#+)[[:space:]]+FR-[0-9]+[a-z]?[^a-zA-Z0-9]/) {
        flush()
        match(stripped, /FR-[0-9]+[a-z]?/)
        id = substr(stripped, RSTART, RLENGTH)
        buf = stripped
        next
      }
      if (id != "" && line ~ /^[[:space:]]+[^[:space:]]/) { buf = buf " " stripped; next }
      if (id != "" && line ~ /^[[:space:]]*$/) { next }
      flush()
    }
    END { flush() }
  ' "$1"
}

traceability_check() {
  local specs_dir="$root/specs"

  if [ ! -f "$register_path" ]; then
    finding "traceability: register not found at $REGISTER. Every FR is untraceable by construction; create it before writing a spec."
    return 0
  fi

  # The shipped starter still in place on a real project passes the gate while
  # tracing nothing, so it gets said out loud rather than inferred from silence.
  if grep -q 'This file ships with the template as a starter' "$register_path" 2>/dev/null; then
    note "WARNING: $REGISTER is still the shipped template starter. Its IDs are examples. Replace them before treating a pass here as traceability."
  fi

  local ids
  ids=$(register_ids) || { finding 'traceability: could not read register IDs'; return 0; }
  if [ -z "$ids" ]; then
    finding "traceability: $REGISTER defines no IDs. Nothing can cite it, so this is reported once rather than once per FR."
    return 0
  fi
  note "traceability: register defines $(printf '%s\n' "$ids" | wc -l | tr -d ' ') ID(s)"

  [ -d "$specs_dir" ] || { note 'traceability: no specs/ directory, nothing to check'; return 0; }

  local spec_count=0 fr_total=0
  local spec id text cited
  while IFS= read -r spec; do
    [ -n "$spec" ] || continue
    spec_count=$((spec_count + 1))

    local fr_here=0
    while IFS=$'\t' read -r id text; do
      [ -n "$id" ] || continue
      fr_here=$((fr_here + 1))
      fr_total=$((fr_total + 1))

      # Does the block name any ID the register actually defines? Checked
      # against the register's own list, never against the shape of an ID —
      # `(R9.9)` looks exactly like a citation and cites nothing.
      cited=$(printf '%s\n' "$text" \
        | grep -oE '\b[RCQ][0-9]+(\.[0-9]+)?\b' \
        | sort -u \
        | grep -Fxf <(printf '%s\n' "$ids") || true)

      if [ -z "$cited" ]; then
        finding "traceability: $(relpath "$spec") $id cites no ID defined in $REGISTER"
      fi
    done < <(fr_blocks "$spec")

    # A spec with zero FRs is not a pass. It is a spec that says nothing, or a
    # parse that found nothing, and those two must not look alike.
    if [ "$fr_here" -eq 0 ]; then
      finding "traceability: $(relpath "$spec") contains no FR-NNN requirements. Either it is not a spec, or this script failed to parse it; both need a human."
    fi
  done < <(find "$specs_dir" -maxdepth 2 -type f -name 'spec.md' 2>/dev/null | sort)

  if [ "$spec_count" -eq 0 ]; then
    note 'traceability: no specs/*/spec.md found. Nothing checked — this is not a pass.'
  else
    note "traceability: checked $fr_total FR(s) across $spec_count spec(s)"
  fi
  return 0
}

# ---------------------------------------------------------------------------
main() {
  note "$PROG: repo $root"
  collision_check
  traceability_check

  note ''
  note "=== Summary: $findings finding(s), $repairs repair(s)"

  if [ "$findings" -gt 0 ]; then
    note 'Untraceable FRs are not auto-fixable on purpose. Either the FR cites the'
    note 'wrong thing (pick the right register ID) or it has no register row at all'
    note '(go ask, land the row, then cite it). An FR that can cite nothing is a'
    note 'deletion candidate, not a feature.'
    exit 1
  fi
  exit 0
}

main "$@"
