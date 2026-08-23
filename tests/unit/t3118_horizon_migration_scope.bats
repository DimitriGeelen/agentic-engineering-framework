#!/usr/bin/env bats
# T-3118: the horizon migration must touch only what it claims to touch.
#
# `bin/migrate-horizon-null-completed.sh` is named in the audit's own mitigation
# line for every CTL-030 failure, described there as "idempotent, only touches
# completed/ files with non-null horizon". That description was false.
#
# Its value pattern opened with `horizon:\s*`, and `\s` includes the newline. So
# for a file that was ALREADY correct —
#
#     horizon:
#     tags: []
#
# — the match consumed the line break, took `tags: []` as horizon's value, and
# rewrote both lines as a single `horizon: null`. The following frontmatter line
# was deleted. Measured on this corpus before the fix: 2362 of 2725 completed
# tasks reported as needing a change, against 21 real CTL-030 failures. An
# operator following the audit's advice would have rewritten 87% of the corpus
# and dropped a line from each file.
#
# The bug is invisible in the happy path — `horizon: now` migrates correctly
# either way — so every test here uses an ALREADY-CORRECT file as its subject.
# That is the case the regex got wrong, and the only one that catches it.

setup() {
    _FW_ROOT="${FRAMEWORK_ROOT:-/opt/999-Agentic-Engineering-Framework}"
    SCRIPT="$_FW_ROOT/bin/migrate-horizon-null-completed.sh"
    [ -x "$SCRIPT" ] || skip "migration script not found: $SCRIPT"

    TEST_ROOT="$(mktemp -d)"
    COMPLETED="$TEST_ROOT/.tasks/completed"
    mkdir -p "$COMPLETED"
}

teardown() {
    [ -n "$TEST_ROOT" ] && rm -rf "$TEST_ROOT"
}

_run_migration() {
    PROJECT_ROOT="$TEST_ROOT" FRAMEWORK_ROOT="$_FW_ROOT" "$SCRIPT" "$@"
}

_write_task() {
    printf '%s' "$2" > "$COMPLETED/$1"
}

# An already-correct file: horizon present, value empty, a real field after it.
_EMPTY_HORIZON='---
id: T-1
status: work-completed
horizon:
tags: []
components: []
---

# body
'

@test "an empty horizon is left alone — the line after it is not swallowed" {
    _write_task "T-1-x.md" "$_EMPTY_HORIZON"
    run _run_migration
    [ "$status" -eq 0 ]
    [[ "$output" == *"0 changes"* ]]
    run cat "$COMPLETED/T-1-x.md"
    [[ "$output" == *"tags: []"* ]]
    [[ "$output" == *"components: []"* ]]
}

@test "the file is byte-identical after a run that reports no changes" {
    # Stronger than counting lines: a migration that rewrites a file it says it
    # skipped is still wrong, and mtime churn on 2700 files hides real diffs.
    _write_task "T-1-x.md" "$_EMPTY_HORIZON"
    local before after
    before=$(md5sum < "$COMPLETED/T-1-x.md")
    _run_migration >/dev/null 2>&1
    after=$(md5sum < "$COMPLETED/T-1-x.md")
    [ "$before" = "$after" ]
}

@test "a real non-null horizon is migrated, and only that line changes" {
    _write_task "T-2-x.md" '---
id: T-2
status: work-completed
horizon: now
tags: [a, b]
---

# body
'
    run _run_migration
    [ "$status" -eq 0 ]
    [[ "$output" == *"1 changes"* ]]
    run cat "$COMPLETED/T-2-x.md"
    [[ "$output" == *"horizon: null"* ]]
    [[ "$output" == *"tags: [a, b]"* ]]
    [[ "$output" != *"horizon: now"* ]]
}

@test "a trailing comment on the horizon line survives the migration" {
    _write_task "T-3-x.md" '---
id: T-3
horizon: later   # parked in June
tags: []
---
'
    run _run_migration
    [ "$status" -eq 0 ]
    run cat "$COMPLETED/T-3-x.md"
    [[ "$output" == *"horizon: null"* ]]
    [[ "$output" == *"# parked in June"* ]]
    [[ "$output" == *"tags: []"* ]]
}

@test "explicit null and ~ are recognised as already-migrated" {
    _write_task "T-4-x.md" '---
id: T-4
horizon: null
tags: []
---
'
    _write_task "T-5-x.md" '---
id: T-5
horizon: ~
tags: []
---
'
    run _run_migration
    [ "$status" -eq 0 ]
    [[ "$output" == *"0 changes"* ]]
}

@test "running twice changes nothing the second time" {
    _write_task "T-2-x.md" '---
id: T-2
horizon: now
tags: []
---
'
    _run_migration >/dev/null 2>&1
    run _run_migration
    [ "$status" -eq 0 ]
    [[ "$output" == *"0 changes"* ]]
}

@test "the value pattern never spans a newline" {
    # Guards the fix at its source. `\s` includes \n; `[^\S\n]` does not, and
    # substituting one for the other is exactly how this regressed.
    run grep -n "HORIZON_RE = " "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" != *'horizon:\s*'* ]]
    [[ "$output" == *'[^\S\n]'* ]]
}

@test "every completed task in the live corpus has a null or absent horizon" {
    # The condition CTL-030 asserts, checked directly rather than through the
    # audit — so this suite fails on drift even if the audit is not run.
    #
    # `null` and `~` are YAML's spellings of null, so they are absent as far as
    # a parser is concerned and must be excluded from the match. Grepping for
    # "any non-whitespace value" flags all 267 correctly-migrated files —
    # a check that reads as a corpus problem when it is a predicate problem.
    run bash -c "cd '$_FW_ROOT' && grep -h '^horizon:' .tasks/completed/T-*.md 2>/dev/null | grep -vE '^horizon:[[:space:]]*(null|~)?[[:space:]]*(#.*)?$' | sort -u | head -5"
    [ -z "$output" ]
}
