#!/usr/bin/env bats
# Unit tests for agents/audit/audit.sh
# Origin: T-924

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
AUDIT="$FRAMEWORK_ROOT/agents/audit/audit.sh"

# T-3328: audit.sh exit codes are three different answers, not one scale:
#   0/1 = ran, clean/warnings (green); 2 = ran, found FAILs (a real red);
#   75  = COULD NOT run — another audit holds the lock (T-2930).
# Asserting [ "$status" -le 1 ] conflated 2 with 75: under any concurrency
# (this suite's own earlier tests, a pre-push gate, the daily cron) 9 tests
# here went RED for a reason unrelated to the code under test (observed live
# 2026-08-25, T-3129: 9/14 unit-suite failures were lock contention).
# Contention is not a verdict either way — it reports as a skip, with reason.
#
# Reads the $status/$output globals `run` sets; an explicit $1 overrides the
# status for the hermetic control tests below (skip inside `run`'s subshell
# cannot skip the calling test, which is what makes those tests possible —
# they assert the marker line the contention branch prints before skipping).
_assert_audit_ran() {
    local st="${1-$status}"
    if [ "$st" -eq 75 ]; then
        echo "audit lock contention (exit 75, T-2930/T-3297) — could not run, not a verdict"
        skip "audit lock contention (exit 75) — could not run, not a verdict"
    fi
    # T-4372: these tests run the audit against the LIVE repo, so exit 2 is a
    # verdict on the corpus, not on audit.sh (mutable-corpus anchor, T-3326).
    # Treating it as red made one live FAIL self-sustaining: the red test is
    # itself a NEW red in the next unit-suite report, which the structure
    # section FAILs on. Exit 2 with a complete report means the audit RAN;
    # exit 2 with a truncated one (a crash) still fails.
    if [ "$st" -eq 2 ] && [[ "${output-}" == *"=== SUMMARY ==="* ]] \
        && [[ "${output-}" == *"=== END AUDIT ==="* ]]; then
        return 0
    fi
    if [ "$st" -gt 1 ]; then
        echo "audit exited $st — crashed or stopped before its summary. Output:"
        echo "$output"
        return 1
    fi
    return 0
}

# --- Help ---

@test "audit --help shows usage" {
    run "$AUDIT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage"* ]]
    [[ "$output" == *"--section"* ]]
    [[ "$output" == *"--quiet"* ]]
}

# --- Section filtering: a fixture project with a private lock (T-4401) ---
# These tests used to run audit.sh against the LIVE repo. audit.sh takes the
# repo-wide flock $CONTEXT_DIR/locks/audit.lock for every sectioned run
# (audit.sh:614-631) and exits 75 when it is held, so under any cron audit,
# pre-push gate or sibling worker they skipped (ok, nothing measured: 8/8 on
# 2026-10-19), and when they won the lock they paid the whole live structure
# section (336-690 s) each. A fixture PROJECT_ROOT gets its own lock, timing
# ledger and dated YAML under the fixture root, so these always run, in seconds.
# tools/audit-live-repo-lint.py keeps new tests from going back to the live repo.

_section_project() {
    local root="$1"
    mkdir -p "$root/.context" "$root/.tasks/active" "$root/.tasks/completed"
    git -C "$root" init -q
    printf 'hello\n' > "$root/README.md"
    git -C "$root" add README.md
    git -C "$root" -c user.email=t@example.invalid -c user.name=t commit -qm "T-001: init"
}

# Runs audit.sh on a fixture root; same env hygiene as _audit_synthetic below.
_audit_fixture() {
    local root="$1"; shift
    env -u TASKS_DIR -u CONTEXT_DIR -u _FW_PATHS_DERIVED_BY \
        NTFY_ENABLED=false PROJECT_ROOT="$root" "$AUDIT" "$@"
}

# A fixture audit has nothing to contend with, so 75 is a fault here, not a
# skip; and its corpus is fixed, so 0/1 (pass or warnings) is the only verdict.
_assert_fixture_ran() {
    if [ "$status" -eq 75 ]; then
        echo "exit 75 on a fixture project: its lock is not private"
        return 1
    fi
    if [ "$status" -gt 1 ]; then
        echo "audit exited $status on the fixture project. Output:"
        echo "$output"
        return 1
    fi
}

# One structure run serves the structure and YAML tests below (the section
# costs ~15 s even on a fixture; running it per test would only repeat it).
setup_file() {
    local root="$BATS_FILE_TMPDIR/section-project"
    _section_project "$root"
    mkdir -p "$BATS_FILE_TMPDIR/yaml-out"
    local st=0
    _audit_fixture "$root" --section structure --output "$BATS_FILE_TMPDIR/yaml-out" \
        > "$BATS_FILE_TMPDIR/structure.out" 2>&1 || st=$?
    echo "$st" > "$BATS_FILE_TMPDIR/structure.status"
}

_structure_result() {
    status=$(cat "$BATS_FILE_TMPDIR/structure.status")
    output=$(cat "$BATS_FILE_TMPDIR/structure.out")
}

@test "audit runs compliance section" {
    _section_project "$BATS_TEST_TMPDIR/p"
    run _audit_fixture "$BATS_TEST_TMPDIR/p" --section compliance
    _assert_fixture_ran
    [[ "$output" == *"COMPLIANCE"* ]] || [[ "$output" == *"TASK"* ]]
}

@test "audit runs traceability section" {
    _section_project "$BATS_TEST_TMPDIR/p"
    run _audit_fixture "$BATS_TEST_TMPDIR/p" --section traceability
    _assert_fixture_ran
    [[ "$output" == *"TRACEABILITY"* ]] || [[ "$output" == *"GIT"* ]]
}

# --- Output format ---

@test "audit output contains PASS/WARN/FAIL markers" {
    _structure_result
    _assert_fixture_ran
    [[ "$output" == *"[PASS]"* ]]
}

@test "audit output contains AUDIT REPORT header" {
    _structure_result
    _assert_fixture_ran
    [[ "$output" == *"AUDIT REPORT"* ]]
}

@test "audit output contains timestamp" {
    _structure_result
    _assert_fixture_ran
    [[ "$output" == *"Timestamp"* ]]
}

@test "the structure section completes with a full report" {
    _structure_result
    _assert_fixture_ran
    [[ "$output" == *"STRUCTURE"* ]]
    [[ "$output" == *"=== END AUDIT ==="* ]]
}

@test "the fixture audit took its lock under the fixture, not the repo" {
    # The property the conversion rests on: PROJECT_ROOT moves the lock.
    [ -f "$BATS_FILE_TMPDIR/section-project/.context/locks/audit.lock" ]
}

# --- Exit-code and --quiet contracts: a synthetic project (T-4383) ---
# The live repo cannot answer "does audit exit 0 when everything passes" — its
# verdict moves with the corpus (T-3326). These tests point audit.sh at a
# synthetic project in a private temp root (PROJECT_ROOT overrides the git
# toplevel in lib/paths.sh) and run the "tree" section, whose inputs are just
# a git index and a secret-scan catalogue. Every write lands under that root
# (lock, dated YAML, timing ledger), so there is no contention with live audits
# and nothing to clean up in the repo. The catalogue is private too, so a
# change to the repo's real patterns cannot move these verdicts.

_synthetic_project() {
    local root="$BATS_TEST_TMPDIR/synthetic-project"
    mkdir -p "$root/.context"
    git -C "$root" init -q
    printf '# synthetic catalogue (T-4383)\nT-4383 Seed Marker\tT4383SEED[0-9]{6}\n' \
        > "$root/.secret-scan-patterns"
    printf 'hello\n' > "$root/README.md"
    git -C "$root" add README.md .secret-scan-patterns
    git -C "$root" -c user.email=t@example.invalid -c user.name=t commit -qm init
    echo "$root"
}

# Runs audit.sh on the synthetic project. Path vars inherited from a caller
# (bin/fw exports them) are dropped so they re-derive from PROJECT_ROOT, and
# notifications are off so a seeded FAIL pushes nothing.
_audit_synthetic() {
    local root="$1"; shift
    env -u TASKS_DIR -u CONTEXT_DIR -u _FW_PATHS_DERIVED_BY \
        NTFY_ENABLED=false PROJECT_ROOT="$root" "$AUDIT" --section tree "$@"
}

@test "audit exits 0 for all-pass sections (synthetic project)" {
    local root; root=$(_synthetic_project)
    run _audit_synthetic "$root"
    echo "$output"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[PASS] Secret scan: tracked tree clean"* ]]
    [[ "$output" != *"[FAIL]"* ]]
    [[ "$output" != *"[WARN]"* ]]
}

@test "audit exits 2 on a seeded FAIL (synthetic project)" {
    local root; root=$(_synthetic_project)
    # Built from two halves so this file never contains the marker itself.
    printf 'token=%s%s\n' "T4383SEED" "123456" > "$root/leak.txt"
    git -C "$root" add leak.txt
    git -C "$root" -c user.email=t@example.invalid -c user.name=t commit -qm leak
    run _audit_synthetic "$root"
    echo "$output"
    [ "$status" -eq 2 ]
    [[ "$output" == *"[FAIL] Secret scan: 1 finding(s) in tracked tree"* ]]
    [[ "$output" == *"=== END AUDIT ==="* ]]
}

@test "audit --quiet suppresses terminal output (synthetic project)" {
    local root; root=$(_synthetic_project)
    # Control: the same run without --quiet prints the report, so an empty
    # quiet run is suppression and not an audit that printed nothing anyway.
    run _audit_synthetic "$root"
    [ "$status" -eq 0 ]
    [[ "$output" == *"=== AUDIT REPORT ==="* ]]
    run _audit_synthetic "$root" --quiet
    echo "quiet output: [$output]"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "audit --quiet keeps the exit code on a seeded FAIL (synthetic project)" {
    local root; root=$(_synthetic_project)
    printf 'token=%s%s\n' "T4383SEED" "654321" > "$root/leak.txt"
    git -C "$root" add leak.txt
    git -C "$root" -c user.email=t@example.invalid -c user.name=t commit -qm leak
    run _audit_synthetic "$root" --quiet
    echo "quiet output: [$output]"
    [ "$status" -eq 2 ]
    [ -z "$output" ]
}

# --- YAML output ---

@test "audit --output writes YAML report" {
    _structure_result
    _assert_fixture_ran
    local yaml_count
    yaml_count=$(ls "$BATS_FILE_TMPDIR/yaml-out"/*.yaml 2>/dev/null | wc -l)
    [ "$yaml_count" -ge 1 ]
}

@test "audit YAML report is valid" {
    _structure_result
    _assert_fixture_ran
    local yaml_file
    yaml_file=$(ls "$BATS_FILE_TMPDIR/yaml-out"/*.yaml 2>/dev/null | head -1)
    # T-3315: assert the report exists — an `if -n` guard turned a missing
    # report into a silent pass.
    [ -n "$yaml_file" ]
    run python3 -c "import yaml, sys; yaml.safe_load(open(sys.argv[1]))" "$yaml_file"
    [ "$status" -eq 0 ]
}

# --- T-3328 control leg: helper discrimination, hermetic ---
# Stub scripts stand in for audit.sh so these tests never touch the real audit
# lock. Each stub is run through `run` so the helper reads the same $status/
# $output globals the real tests feed it. `skip` inside `run`'s command
# substitution exits that subshell only (it cannot skip the calling test) —
# so the 75 case is observable here as exit 0 plus the contention marker the
# helper prints before skipping, while a real test calling the helper
# directly (outside `run`) skips as intended.

_audit_exit_stub() {
    local code="$1" stub="$BATS_TEST_TMPDIR/stub-audit-$1.sh"
    printf '#!/bin/sh\necho "STUB AUDIT (exit %s)"\nexit %s\n' "$code" "$code" > "$stub"
    chmod +x "$stub"
    echo "$stub"
}

@test "T-3328 control: stubbed exit 75 routes to skip, not pass or fail" {
    run "$(_audit_exit_stub 75)"
    [ "$status" -eq 75 ]
    run _assert_audit_ran
    [ "$status" -eq 0 ]
    [[ "$output" == *"lock contention"* ]]
}

@test "T-3328 control: stubbed exit 2 without a complete report still fails" {
    run "$(_audit_exit_stub 2)"
    [ "$status" -eq 2 ]
    run _assert_audit_ran
    [ "$status" -eq 1 ]
    [[ "$output" == *"audit exited 2"* ]]
    [[ "$output" != *"lock contention"* ]]
}

@test "T-4372 control: stubbed exit 2 with a complete report passes (live corpus FAIL is not a test red)" {
    local stub="$BATS_TEST_TMPDIR/stub-audit-2-full.sh"
    printf '#!/bin/sh\necho "=== STRUCTURE CHECKS ==="\necho "[FAIL] something in the live corpus"\necho "=== SUMMARY ==="\necho "=== END AUDIT ==="\nexit 2\n' > "$stub"
    chmod +x "$stub"
    run "$stub"
    [ "$status" -eq 2 ]
    run _assert_audit_ran
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "T-4372 control: stubbed exit 2 with SUMMARY but no END (truncated) still fails" {
    local stub="$BATS_TEST_TMPDIR/stub-audit-2-trunc.sh"
    printf '#!/bin/sh\necho "=== SUMMARY ==="\nexit 2\n' > "$stub"
    chmod +x "$stub"
    run "$stub"
    run _assert_audit_ran
    [ "$status" -eq 1 ]
}

@test "T-3328 control: stubbed exit 1 passes (warnings stay green)" {
    run "$(_audit_exit_stub 1)"
    [ "$status" -eq 1 ]
    run _assert_audit_ran
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "T-3328 control: stubbed exit 0 passes" {
    run "$(_audit_exit_stub 0)"
    [ "$status" -eq 0 ]
    run _assert_audit_ran
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
