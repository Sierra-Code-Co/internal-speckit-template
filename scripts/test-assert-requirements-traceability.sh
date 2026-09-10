#!/usr/bin/env bash
# Suite for assert-requirements-traceability.sh.
#
# What this suite is built to catch, taken from the fleet's own defect logs:
# nearly every gate defect in them had a test that should have caught it and
# could not, and in every case the vacuity was OUTSIDE the assertion's logic —
# in the fixture, the harness, or the assertion's anchor. So:
#
#   - Every fixture is a real git repository with real files. A fixture that
#     mocks the tree cannot exhibit a rename that half-succeeds.
#   - The clean case is asserted to exit 0 AND to have checked a non-zero number
#     of FRs. "Passed" and "examined nothing" are the pair this whole script
#     exists to separate, so the suite must not accept them as the same.
#   - The undefined-but-well-formed citation case (`R9.9`) exists because an ID
#     is validated against the register's list, not against the shape of an ID,
#     and a test that only ever cites real IDs never runs that difference.
#   - The wrapped-FR case exists because the repo lints at 100 columns, so a
#     citation on a continuation line is the normal case, not the edge one.
#   - The both-files-exist case asserts NO clobber, because a repair that
#     destroys the file it could not reconcile is worse than the collision.
#
# Run: bash scripts/test-assert-requirements-traceability.sh

set -uo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
SUT="$HERE/assert-requirements-traceability.sh"
[ -x "$SUT" ] || { printf 'FATAL: %s is not executable\n' "$SUT" >&2; exit 2; }

pass=0
fail=0

ok()   { printf '  ok   %s\n' "$1"; pass=$((pass + 1)); }
bad()  { printf '  FAIL %s\n' "$1"; printf '       %s\n' "$2"; fail=$((fail + 1)); }

# A fixture is a real repo, because the thing under test renames tracked files.
make_repo() {
  local d
  d=$(mktemp -d) || return 1
  git -C "$d" init -q
  git -C "$d" config user.email t@example.invalid
  git -C "$d" config user.name Test
  mkdir -p "$d/docs" "$d/specs"
  printf '%s' "$d"
}

register_with_ids() {
  cat > "$1/docs/requirements.md" <<'EOF'
# Requirements Register

| Sub | Requirement | Status | Source |
|-----|-------------|--------|--------|
| R1.1 | A thing. | Confirmed | `notes.md:1` |
| R1.2 | Another thing. | Asked | `notes.md:2` |

| ID | Constraint | Status | Source |
|----|-----------|--------|--------|
| C1 | A constraint. | Confirmed | `notes.md:3` |
EOF
}

spec_at() {
  mkdir -p "$1/specs/$2"
  cat > "$1/specs/$2/spec.md"
}

run() {  # run <repo> ; sets $out and $status
  out=$(cd "$1" && bash "$SUT" 2>&1)
  status=$?
}

# ---------------------------------------------------------------------------
printf 'assert-requirements-traceability.sh\n'

# 1. Clean: every FR cites a defined ID.
t=$(make_repo); register_with_ids "$t"
spec_at "$t" 001-a <<'EOF'
# Spec
- **FR-001** (R1.1): The system does a thing.
- **FR-002** (C1): The system respects a constraint.
EOF
run "$t"
if [ "$status" -eq 0 ]; then ok 'clean spec exits 0'; else bad 'clean spec exits 0' "status=$status: $out"; fi
# Exit 0 is only half the claim. A run that checked nothing also exits 0.
if printf '%s' "$out" | grep -q 'checked 2 FR(s) across 1 spec(s)'; then
  ok 'clean run reports how much it checked'
else
  bad 'clean run reports how much it checked' "$out"
fi
rm -rf "$t"

# 2. An FR citing a constitution principle instead of a register ID. This is the
#    exact defect that shipped in a real repo with its checklist box ticked.
t=$(make_repo); register_with_ids "$t"
spec_at "$t" 001-a <<'EOF'
# Spec
- **FR-001** (R1.1): Fine.
- **FR-002** (Constitution Principle V): Idempotent on replay.
EOF
run "$t"
if [ "$status" -eq 1 ] && printf '%s' "$out" | grep -q 'FR-002 cites no ID'; then
  ok 'FR citing a constitution principle is a finding'
else
  bad 'FR citing a constitution principle is a finding' "status=$status: $out"
fi
rm -rf "$t"

# 3. A citation that is shaped like an ID but is not in the register. Without
#    this case, validating against a REGEX instead of the register's list passes
#    the whole suite.
t=$(make_repo); register_with_ids "$t"
spec_at "$t" 001-a <<'EOF'
# Spec
- **FR-001** (R9.9): Cites an ID that does not exist.
EOF
run "$t"
if [ "$status" -eq 1 ] && printf '%s' "$out" | grep -q 'FR-001 cites no ID'; then
  ok 'well-formed but undefined ID is a finding'
else
  bad 'well-formed but undefined ID is a finding' "status=$status: $out"
fi
rm -rf "$t"

# 4. Wrapped FR with the citation on a continuation line.
t=$(make_repo); register_with_ids "$t"
spec_at "$t" 001-a <<'EOF'
# Spec
- **FR-001**: A requirement long enough to wrap at the column limit, whose
  register citation lands on the continuation line (R1.2) rather than the first.
EOF
run "$t"
if [ "$status" -eq 0 ]; then
  ok 'citation on a continuation line counts'
else
  bad 'citation on a continuation line counts' "status=$status: $out"
fi
rm -rf "$t"

# 4b. Prose that MENTIONS an FR is not a definition of it. Found by running an
#     earlier version against a real repo: rationale prose referring to its own
#     FRs made one spec report FR-010 four times and turned 76 requirements into
#     113. Asserted on the count, not just the exit code, because duplicate
#     findings still exit 1 and would look identical to a correct run here.
t=$(make_repo); register_with_ids "$t"
spec_at "$t" 001-a <<'EOF'
# Spec
- **FR-001** (R1.1): The one and only requirement.

## Rationale
The reason FR-001 exists is historical. FR-001 was almost dropped. Note that
FR-001 and FR-001 are the same requirement mentioned repeatedly on purpose.
EOF
run "$t"
if [ "$status" -eq 0 ] && printf '%s' "$out" | grep -q 'checked 1 FR(s)'; then
  ok 'prose mentions of an FR are not counted as definitions'
else
  bad 'prose mentions of an FR are not counted as definitions' "status=$status: $out"
fi
rm -rf "$t"

# 4c. A wrapped paragraph whose line break lands just before an FR ID opens a
#     line with a bare ID. That is prose, not a definition. Found the same way,
#     and it is the worse direction to be wrong in: this produced a false finding
#     against a spec where every FR was correctly cited, and a gate that cries
#     wolf on a clean spec is a gate that gets bypassed.
t=$(make_repo); register_with_ids "$t"
spec_at "$t" 001-a <<'EOF'
# Spec
- **FR-001** (R1.1): The one and only requirement.

## Notes
Two of them were miscited and the review round caught it. IDs are stable, so
FR-001 was appended rather than renumbered into position.
EOF
run "$t"
if [ "$status" -eq 0 ] && printf '%s' "$out" | grep -q 'checked 1 FR(s)'; then
  ok 'a prose line beginning with a bare FR ID is not a definition'
else
  bad 'a prose line beginning with a bare FR ID is not a definition' "status=$status: $out"
fi
rm -rf "$t"

# 4d. `FR-010a` is a distinct requirement from `FR-010`. Truncating the suffix
#     merges two requirements into one and hides whichever is uncited.
t=$(make_repo); register_with_ids "$t"
spec_at "$t" 001-a <<'EOF'
# Spec
- **FR-010** (R1.1): A requirement.
- **FR-010a**: A sub-requirement that cites nothing.
EOF
run "$t"
if [ "$status" -eq 1 ] && printf '%s' "$out" | grep -q 'FR-010a cites no ID'; then
  ok 'a lettered sub-requirement is tracked separately'
else
  bad 'a lettered sub-requirement is tracked separately' "status=$status: $out"
fi
if ! printf '%s' "$out" | grep -q 'FR-010 cites no ID'; then
  ok 'the lettered sibling does not drag down FR-010'
else
  bad 'the lettered sibling does not drag down FR-010' "$out"
fi
rm -rf "$t"

# 4e. A register that states groups as headings and tables only sub-requirements
#     still has citable groups. Extracting table cells alone reported 8 false
#     findings against a real 41-row register.
t=$(make_repo)
cat > "$t/docs/requirements.md" <<'EOF'
# Requirements Register

### R1 — A requirement group stated only as a heading

Prose describing it. No table.

### R4 — A group whose sub-requirements are tabled

| Sub | Requirement | Status | Source |
|-----|-------------|--------|--------|
| R4.2 | A thing. | Confirmed | `notes.md:1` |
EOF
spec_at "$t" 001-a <<'EOF'
# Spec
- **FR-001** (R1): Cites a heading-only group.
- **FR-002** (R4): Cites a group whose subs are tabled.
- **FR-003** (R4.2): Cites the sub directly.
EOF
run "$t"
if [ "$status" -eq 0 ]; then
  ok 'heading-only and parent group IDs are citable'
else
  bad 'heading-only and parent group IDs are citable' "status=$status: $out"
fi
rm -rf "$t"

# 5. A spec with no FRs at all is not a pass.
t=$(make_repo); register_with_ids "$t"
spec_at "$t" 001-a <<'EOF'
# Spec
Prose only. No numbered requirements.
EOF
run "$t"
if [ "$status" -eq 1 ] && printf '%s' "$out" | grep -q 'contains no FR-NNN'; then
  ok 'spec with zero FRs is a finding'
else
  bad 'spec with zero FRs is a finding' "status=$status: $out"
fi
rm -rf "$t"

# 6. Missing register: every FR is untraceable by construction, and the message
#    must say that rather than emitting one finding per FR.
t=$(make_repo)
spec_at "$t" 001-a <<'EOF'
# Spec
- **FR-001** (R1.1): A thing.
EOF
run "$t"
if [ "$status" -eq 1 ] && printf '%s' "$out" | grep -q 'register not found'; then
  ok 'missing register is a finding'
else
  bad 'missing register is a finding' "status=$status: $out"
fi
if [ "$(printf '%s' "$out" | grep -c 'FINDING')" -eq 1 ]; then
  ok 'missing register reports once, not once per FR'
else
  bad 'missing register reports once, not once per FR' "$out"
fi
rm -rf "$t"

# 7. Register present but defining no IDs.
t=$(make_repo)
printf '# Requirements Register\n\nNothing yet.\n' > "$t/docs/requirements.md"
spec_at "$t" 001-a <<'EOF'
# Spec
- **FR-001** (R1.1): A thing.
EOF
run "$t"
if [ "$status" -eq 1 ] && printf '%s' "$out" | grep -q 'defines no IDs'; then
  ok 'register with no IDs is a finding'
else
  bad 'register with no IDs is a finding' "status=$status: $out"
fi
rm -rf "$t"

# 8. No specs at all. Legitimate on a fresh project, but the run must not claim
#    to have verified anything.
t=$(make_repo); register_with_ids "$t"
run "$t"
if [ "$status" -eq 0 ] && printf '%s' "$out" | grep -q 'this is not a pass'; then
  ok 'no specs exits 0 but declines to claim a pass'
else
  bad 'no specs exits 0 but declines to claim a pass' "status=$status: $out"
fi
rm -rf "$t"

# 9. The checklist collision is repaired, and the repair is named.
t=$(make_repo); register_with_ids "$t"
spec_at "$t" 001-a <<'EOF'
# Spec
- **FR-001** (R1.1): A thing.
EOF
mkdir -p "$t/specs/001-a/checklists"
printf '# Spec Quality Checklist\n\n- [x] A box\n' > "$t/specs/001-a/checklists/requirements.md"
printf 'See checklists/requirements.md for quality.\n' > "$t/specs/001-a/plan.md"
git -C "$t" add -A >/dev/null 2>&1
git -C "$t" commit -qm init >/dev/null 2>&1
run "$t"
if [ "$status" -eq 0 ] \
   && [ -f "$t/specs/001-a/checklists/spec-quality.md" ] \
   && [ ! -e "$t/specs/001-a/checklists/requirements.md" ]; then
  ok 'collision is repaired by rename'
else
  bad 'collision is repaired by rename' "status=$status: $out"
fi
if printf '%s' "$out" | grep -q 'renamed: specs/001-a/checklists/requirements.md'; then
  ok 'rename is named on stdout'
else
  bad 'rename is named on stdout' "$out"
fi
if grep -q 'checklists/spec-quality.md' "$t/specs/001-a/plan.md"; then
  ok 'references inside the feature dir are rewritten'
else
  bad 'references inside the feature dir are rewritten' "$(cat "$t/specs/001-a/plan.md")"
fi
rm -rf "$t"

# 10. Both names present: refuse, and do not destroy either file.
t=$(make_repo); register_with_ids "$t"
spec_at "$t" 001-a <<'EOF'
# Spec
- **FR-001** (R1.1): A thing.
EOF
mkdir -p "$t/specs/001-a/checklists"
printf 'old\n' > "$t/specs/001-a/checklists/requirements.md"
printf 'new\n' > "$t/specs/001-a/checklists/spec-quality.md"
run "$t"
if [ "$status" -eq 1 ] && printf '%s' "$out" | grep -q 'Cannot repair'; then
  ok 'both names present refuses to repair'
else
  bad 'both names present refuses to repair' "status=$status: $out"
fi
if [ "$(cat "$t/specs/001-a/checklists/requirements.md")" = 'old' ] \
   && [ "$(cat "$t/specs/001-a/checklists/spec-quality.md")" = 'new' ]; then
  ok 'both names present clobbers neither file'
else
  bad 'both names present clobbers neither file' 'a file was modified'
fi
rm -rf "$t"

# 11. Not a git repo and REPO_ROOT unset is a TOOL ERROR, not a pass and not a
#     finding. Three outcomes, three codes.
t=$(mktemp -d)
out=$(cd "$t" && env -u REPO_ROOT GIT_CEILING_DIRECTORIES="$t" bash "$SUT" 2>&1)
status=$?
if [ "$status" -eq 2 ]; then
  ok 'no repo and no REPO_ROOT exits 2'
else
  bad 'no repo and no REPO_ROOT exits 2' "status=$status: $out"
fi
rm -rf "$t"

# 11b. The positional form, which is how setup.sh calls it. Run from a DIFFERENT
#      directory, because a test that cd's into the target first would pass even
#      if the argument were ignored entirely — the enclosing-repo fallback would
#      silently supply the same answer.
t=$(make_repo); register_with_ids "$t"
spec_at "$t" 001-a <<'EOF'
# Spec
- **FR-001** (R1.1): A thing.
EOF
out=$(cd / && env -u REPO_ROOT bash "$SUT" "$t" 2>&1)
status=$?
if [ "$status" -eq 0 ] && printf '%s' "$out" | grep -q "repo $t"; then
  ok 'positional repo argument is honoured from outside the repo'
else
  bad 'positional repo argument is honoured from outside the repo' "status=$status: $out"
fi
rm -rf "$t"

# 12. The shipped starter register warns that its IDs are examples. Without this,
#     a project that never replaced the template passes while tracing nothing.
t=$(make_repo)
# shellcheck disable=SC2016  # the backticks are markdown, not command substitution
{ printf '# Requirements Register\n\n'
  printf '<!-- This file ships with the template as a starter. -->\n\n'
  printf '| Sub | Requirement | Status | Source |\n|--|--|--|--|\n'
  printf '| R1.1 | A thing. | Confirmed | `x:1` |\n'; } > "$t/docs/requirements.md"
spec_at "$t" 001-a <<'EOF'
# Spec
- **FR-001** (R1.1): A thing.
EOF
run "$t"
if [ "$status" -eq 0 ] && printf '%s' "$out" | grep -q 'still the shipped template starter'; then
  ok 'unreplaced starter register warns'
else
  bad 'unreplaced starter register warns' "status=$status: $out"
fi
rm -rf "$t"

# ---------------------------------------------------------------------------
printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
