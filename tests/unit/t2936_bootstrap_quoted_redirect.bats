#!/usr/bin/env bats
# T-2936 — the task gate refused both commands its own block message prescribes.
#
# With focus null:
#
#     bin/fw task create --name "correct OBS-231 invalid-owner count 11->10 (...)" --start
#     → BLOCKED: No active task. To unblock: 1. bin/fw task create ...
#
# `check-active-task.sh` tested write-patterns before the task-bootstrap exemption
# (T-2052, ~:198), and its own comment recorded the ordering as safe — "Reached only
# when no write pattern is present". That holds only if a write pattern means a write.
# `11->10` matches `[^2>&]>[^>&]` from INSIDE A QUOTED --name, so creating a task read
# as a file write and was blocked for having no active task.
#
# The deadlock is the point: creating the task is what would satisfy the gate, and the
# only documented exits are the two commands being refused. Proven live by changing one
# character class — the same command with ` to ` instead of `->` was allowed.
#
# Sibling of L-432 (T-2052), which covers allowlists keyed on a command's first WORD.
# This is the same class keyed on its quoted PAYLOAD.

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    HOOK="$FRAMEWORK_ROOT/agents/context/check-active-task.sh"
    PROJ="$BATS_TEST_TMPDIR/proj"
    mkdir -p "$PROJ/.context/working" "$PROJ/.tasks/active"
    printf 'current_task: null\npriorities: []\n' > "$PROJ/.context/working/focus.yaml"
    touch "$PROJ/.framework.yaml"
}

# Drives the SHIPPED hook with the real PreToolUse payload shape, against a fixture
# whose focus is null — the only state in which this gate has anything to say.
_gate() {
    printf '{"tool_name":"Bash","tool_input":{"command":%s}}' "$1" \
        | PROJECT_ROOT="$PROJ" CLAUDE_PROJECT_DIR="$PROJ" bash "$HOOK" >/dev/null 2>&1
}

# ── The deadlock, reconstructed ──────────────────────────────────────────────

@test "t2936: the quoted arrow really does trip the whole-command write check" {
    # Anti-vacuity. If this stopped matching, every leg below would pass without
    # the fix doing anything. Reconstructed inline from the predicate rather than
    # read out of `git show HEAD:` — a leg that reads pre-fix bytes goes stale the
    # moment the fix is committed (t2927 leg 9, green when written, red within the
    # hour).
    source "$FRAMEWORK_ROOT/agents/context/lib/safe-commands.sh"
    run has_bash_write_pattern 'bin/fw task create --name "count 11->10" --start'
    [ "$status" -eq 0 ]
}

@test "t2936: stripping quoted payloads is what makes the exemption reachable" {
    # The mechanism, asserted directly: same command, quotes removed, no longer a write.
    source "$FRAMEWORK_ROOT/agents/context/lib/safe-commands.sh"
    local stripped
    stripped=$(printf '%s' 'bin/fw task create --name "count 11->10" --start' \
        | sed "s/'[^']*'//g; s/\"[^\"]*\"//g")
    run has_bash_write_pattern "$stripped"
    [ "$status" -ne 0 ]
}

# ── The repair ───────────────────────────────────────────────────────────────

@test "t2936: task create with a redirect char inside a quoted name is allowed" {
    run _gate '"bin/fw task create --name \"correct count 11->10\" --start"'
    [ "$status" -eq 0 ] || { echo "gate refused the command it prescribes" >&2; return 1; }
}

@test "t2936: single-quoted payloads are stripped too" {
    run _gate "\"bin/fw task create --name 'migrate A->B' --start\""
    [ "$status" -eq 0 ]
}

@test "t2936: work-on with a quoted redirect char is allowed" {
    run _gate '"bin/fw work-on \"rename a->b\""'
    [ "$status" -eq 0 ]
}

# ── The exemption must not swallow a real redirect ───────────────────────────

@test "t2936: a bootstrap command with a REAL redirect still falls through" {
    # The whole risk of moving this check earlier. `>` outside quotes survives
    # stripping, so the command is still a write and still meets the gate.
    run _gate '"bin/fw task create --name x > /tmp/t2936-should-not-happen"'
    [ "$status" -eq 2 ] || { echo "exemption swallowed a real redirect" >&2; return 1; }
}

@test "t2936: an unbalanced quote blocks rather than exempting" {
    # The stripper cannot match an unterminated quote, so the metacharacter stays
    # and the command blocks. Both failure directions of the stripper must fail
    # toward BLOCKING; this pins the awkward one.
    run _gate '"bin/fw task create --name \"x > /tmp/t2936-unbalanced"'
    [ "$status" -eq 2 ]
}

@test "t2936: non-bootstrap commands are untouched by the reorder" {
    # Anti-vacuity for the two legs above: proves the gate still blocks generally,
    # so "blocked" above means the exemption declined, not that the gate is dead.
    run _gate '"echo x > /tmp/t2936-nope"'
    [ "$status" -eq 2 ]
}

# ── Enumerating guard (L-533) ────────────────────────────────────────────────

@test "t2936: every bootstrap verb the hook exempts is covered by the fix" {
    # Derives the verb set from the hook's own regex instead of restating it, so a
    # verb added later is covered without editing this test. An explicit list would
    # go green while a new verb sat unprotected — the exact failure L-533 names,
    # and the one that caught do_triage in t2932 one function below where I'd read.
    local verbs
    verbs=$(grep -oE '\(work-on\|task\[\[:space:\]\]\+create\|context\[\[:space:\]\]\+focus\|[a-z|[:space:]\\+_-]*\)' "$HOOK" \
        | head -1 | tr -d '()' | sed 's/\[\[:space:\]\]+/ /g' | tr '|' '\n')
    [ -n "$verbs" ] || { echo "could not derive verb set from hook" >&2; return 1; }
    local v n=0
    while read -r v; do
        [ -n "$v" ] || continue
        n=$((n + 1))
        run _gate "\"bin/fw $v \\\"payload a->b\\\"\""
        [ "$status" -eq 0 ] || {
            echo "bootstrap verb '$v' still blocked on a quoted redirect char" >&2
            return 1
        }
    done <<< "$verbs"
    [ "$n" -ge 4 ] || { echo "derived only $n verbs — regex drifted" >&2; return 1; }
}
