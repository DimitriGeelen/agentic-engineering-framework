#!/usr/bin/env bats
# T-3039 — the implicit framework write-set, and the false green it closes.
#
# `fw write-set check` is what CLAUDE.md §Execution Model tells an agent to run
# before parallelising two tasks. Before T-3039 it compared ONLY the declared
# `write_set:` frontmatter, so `disjoint` meant "your two lists do not
# intersect" while reading as "these can run concurrently".
#
# Those are not the same claim. Every framework task also writes state no task
# declares — inbox.yaml, learnings.yaml, concerns.yaml, focus.yaml,
# session.yaml — because the framework writes them on the task's behalf. Two
# tasks with genuinely disjoint declared sets still collide there, in the
# 27-site shared read-modify-write set measured by
# docs/reports/T-3041-write-site-inventory.md, where T-3042 is the live
# data-loss instance.
#
# It had never fired only because adoption is zero: 0 of 3032 tasks declare the
# field, so every real pair returned `undecidable`. The tool was safe by
# accident, one adopted field away from a confident wrong answer.
#
# --declared-only reproduces the pre-T-3039 comparison, so the false green is
# demonstrated here rather than asserted.

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export FRAMEWORK_ROOT
    WS="$FRAMEWORK_ROOT/lib/write_set.py"
    TMP_ROOT="$(mktemp -d)"
    mkdir -p "$TMP_ROOT/.tasks/active"
    export TMP_ROOT
}

teardown() {
    [ -n "$TMP_ROOT" ] && rm -rf "$TMP_ROOT"
}

# Write a synthetic task with the given id and write_set entries.
_task() {
    local id="$1"; shift
    local f="$TMP_ROOT/.tasks/active/${id}-synthetic.md"
    {
        echo "---"
        echo "id: $id"
        echo "name: \"synthetic $id\""
        echo "status: started-work"
        echo "write_set:"
        for p in "$@"; do echo "  - $p"; done
        echo "---"
        echo
        echo "# $id"
    } > "$f"
    echo "$f"
}

_check() {
    PROJECT_ROOT="$TMP_ROOT" python3 "$WS" check "$@"
}

@test "t3039: two disjoint DECLARED sets are not reported disjoint" {
    # The AC. Before T-3039 this returned `disjoint` + exit 0 — a green light
    # to parallelise two tasks that both rewrite inbox.yaml and learnings.yaml.
    _task T-9001 "lib/alpha.py" >/dev/null
    _task T-9002 "web/beta.py" >/dev/null

    run _check T-9001 T-9002
    [ "$status" -eq 1 ]
    [[ "$output" == *"converging"* ]]
    [[ "$output" != *"disjoint"* ]]
}

@test "t3039: --declared-only reproduces the false green (the regression this closes)" {
    # Documents the OLD behaviour rather than asserting the bug is gone in the
    # abstract. If someone later deletes the implicit set, the test above goes
    # red and this one still passes — which is the correct signal, because this
    # one is describing history.
    _task T-9001 "lib/alpha.py" >/dev/null
    _task T-9002 "web/beta.py" >/dev/null

    run _check T-9001 T-9002 --declared-only
    [ "$status" -eq 0 ]
    [[ "$output" == *"disjoint"* ]]
}

@test "t3039: a real declared collision still outranks framework convergence" {
    # `overlap` is the stronger finding: these tasks edit the same file and
    # should not run together at all, not merely serialise their write leg.
    # Convergence is also true here and must not mask it.
    _task T-9001 "lib/alpha.py" "lib/shared.py" >/dev/null
    _task T-9002 "web/beta.py" "lib/shared.py" >/dev/null

    run _check T-9001 T-9002
    [ "$status" -eq 1 ]
    [[ "$output" == *"overlap"* ]]
    [[ "$output" != *"converging"* ]]
}

@test "t3039: undecidable is preserved, and still exits 2" {
    # A5. Fixing the blind spot must not turn "I cannot tell" into a confident
    # answer — an undeclared task's declared-path overlap remains unknown.
    _task T-9001 "lib/alpha.py" >/dev/null
    local f="$TMP_ROOT/.tasks/active/T-9002-synthetic.md"
    printf -- '---\nid: T-9002\nname: "no declaration"\n---\n\n# T-9002\n' > "$f"

    run _check T-9001 T-9002
    [ "$status" -eq 2 ]
    [[ "$output" == *"undecidable"* ]]
}

@test "t3039: undecidable now names the convergence it CAN see" {
    # Implicit convergence follows from both operands being framework tasks, so
    # it is knowable with zero declarations. Before this, exit 2 carried no
    # information at all — which is why an agent hitting it fell back to
    # guessing, the state the tool was built to replace.
    _task T-9001 "lib/alpha.py" >/dev/null
    local f="$TMP_ROOT/.tasks/active/T-9002-synthetic.md"
    printf -- '---\nid: T-9002\nname: "no declaration"\n---\n\n# T-9002\n' > "$f"

    run _check T-9001 T-9002 --json
    [ "$status" -eq 2 ]
    [[ "$output" == *"inbox.yaml"* ]]
    [[ "$output" == *"focus.yaml"* ]]
}

@test "t3039: lock-protected and append-safe paths do not escalate the verdict" {
    # dispatches.jsonl is serialised by flock (T-3042) and decisions.yaml is a
    # single sub-PIPE_BUF append. Both are shared; neither can lose data. If
    # they escalated, every pair would converge on paths that are already safe
    # and the signal would be noise.
    run python3 -c "
import sys; sys.path.insert(0, '$FRAMEWORK_ROOT/lib')
import write_set as w
esc = set(w.implicit_paths(w.ESCALATING_HAZARDS))
assert '.context/dispatches.jsonl' not in esc, 'flock-protected path escalated'
assert '.context/project/decisions.yaml' not in esc, 'append-safe path escalated'
assert '.context/dispatches.jsonl' in set(w.implicit_paths()), 'path dropped entirely'
print('ok')
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"ok"* ]]
}

@test "t3039: every implicit entry carries provenance and a known hazard class" {
    # A1 says the set is sourced from the T-3041 inventory, not from memory.
    # An entry with an empty rationale is one someone added from intuition.
    run python3 -c "
import sys; sys.path.insert(0, '$FRAMEWORK_ROOT/lib')
import write_set as w
known = {'lost-update', 'protected', 'append-safe'}
for path, why, hazard in w.IMPLICIT_WRITE_SET:
    assert hazard in known, (path, hazard)
    assert 'inventory' in why, ('no inventory provenance', path)
    assert len(why) > 40, ('rationale too thin to be evidence', path)
print('ok', len(w.IMPLICIT_WRITE_SET))
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"ok"* ]]
}
