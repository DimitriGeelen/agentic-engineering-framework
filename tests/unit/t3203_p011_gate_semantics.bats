#!/usr/bin/env bats
# T-3203: what P-011 actually does to a verification line, pinned rather than described.
#
# The gate at agents/task-create/update-task.sh:1215 is:
#
#     if (unset …; cd "$PROJECT_ROOT" && eval "$cmd") > /tmp/verify-$$.out 2>&1; then
#
# — a subshell that IS the condition of an `if`, inside a script running
# `set -euo pipefail`. POSIX suppresses errexit for a compound command in an `if`
# condition, and that suppression reaches through the subshell. So:
#
#     pipefail  LIVE      (a failing pipeline element is the verdict)
#     errexit   SUPPRESSED (in `cmd1; cmd2`, only cmd2 is the verdict)
#
# The task template prescribed `bash -c 'set -eo pipefail; <line>'` as the way to
# rehearse a line before the gate sees it. That wrapper adds an errexit the gate
# does not have, so it FAILS lines the gate PASSES. This file pins both the gate's
# real semantics and the corrected rehearsal.
#
# ── on negations ──────────────────────────────────────────────────────────────
# `! cmd` at statement position is INERT in bats. Uses `if cmd; then false; fi`.
# Origin T-3199.

# The gate's shape, reproduced structurally rather than described. Not a copy of
# its TEXT — a copy of its SHAPE: subshell as if-condition under set -euo pipefail.
gate() {
    set -euo pipefail
    if ( eval "$1" ) >/dev/null 2>&1; then echo PASS; else echo FAIL; fi
}
# What the template used to prescribe.
rehearse_old() {
    if bash -c "set -eo pipefail; $1" >/dev/null 2>&1; then echo PASS; else echo FAIL; fi
}
# What it prescribes now.
rehearse_new() {
    if bash -c "set -o pipefail; $1" >/dev/null 2>&1; then echo PASS; else echo FAIL; fi
}

# ── the gate's actual semantics ──────────────────────────────────────────────

@test "CONTROL: a bare failing command still fails, a bare passing one passes" {
    # Without this the file cannot distinguish "the gate is lenient" from
    # "the harness never reports failure at all".
    [ "$(gate 'false')" = "FAIL" ]
    [ "$(gate 'true')" = "PASS" ]
}

@test "pipefail is LIVE: a failing first pipeline element is the verdict" {
    [ "$(gate 'false | true')" = "FAIL" ]
    [ "$(gate 'true | true')" = "PASS" ]
}

@test "errexit is SUPPRESSED: in cmd1; cmd2 only cmd2 is the verdict" {
    [ "$(gate 'false; true')" = "PASS" ]
    [ "$(gate 'true; false')" = "FAIL" ]
}

@test "the false green this causes: a failed cd is invisible" {
    # The shape that matters in practice — setup fails, assertion never really runs,
    # line reports success.
    [ "$(gate 'cd /nonexistent-xyz-t3203; echo ok')" = "PASS" ]
}

@test "&& is NOT affected — the chain's own status is the verdict" {
    # Why the safe shape works: `&&` makes the sequence one compound command
    # whose status already reflects every element.
    [ "$(gate 'false && true')" = "FAIL" ]
    [ "$(gate 'true && false')" = "FAIL" ]
    [ "$(gate 'true && true')" = "PASS" ]
}

# ── the rehearsal contract ───────────────────────────────────────────────────

@test "the OLD prescribed rehearsal diverges from the gate on ;-sequences" {
    # Pinned as a defect, not as behaviour: if someone restores `set -eo` to the
    # template, this documents exactly what they have reintroduced.
    for line in 'false; true' 'cd /nonexistent-xyz-t3203; echo ok' 'grep -q ZZZNOPE_T3203 "$0"; true'; do
        [ "$(gate "$line")" = "PASS" ]
        [ "$(rehearse_old "$line")" = "FAIL" ]
    done
}

@test "the CORRECTED rehearsal agrees with the gate on every case above" {
    for line in 'true' 'false' 'false; true' 'true; false' 'false | true' 'true | grep -q ZZZNOPE_T3203' 'false && true' 'cd /nonexistent-xyz-t3203; echo ok'; do
        [ "$(rehearse_new "$line")" = "$(gate "$line")" ]
    done
}

@test "the divergence is one-directional: old never PASSES what the gate FAILS" {
    # This is why the old wrapper produced false REDS and never false greens —
    # and why it was survivable for so long without being harmless.
    for line in 'true' 'false' 'false; true' 'false | true' 'false && true' 'cd /nonexistent-xyz-t3203; echo ok'; do
        if [ "$(rehearse_old "$line")" = "PASS" ] && [ "$(gate "$line")" = "FAIL" ]; then
            echo "old rehearsal passed a line the gate fails: $line" >&2
            false
        fi
    done
}

# ── the template must not re-acquire the wrong claim ─────────────────────────

@test "the template prescribes the corrected rehearsal, not the old one" {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    T="$REPO_ROOT/.tasks/templates/default.md"
    grep -q "bash -c 'set -o pipefail; <your verification line>'" "$T"
    if grep -q "bash -c 'set -eo pipefail; <your verification line>'" "$T"; then
        echo "template restored the rehearsal wrapper that diverges from the gate" >&2
        false
    fi
}

@test "the template still records that errexit is suppressed in a ;-sequence" {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    grep -q 'JUDGED ONLY ON cmd2' "$REPO_ROOT/.tasks/templates/default.md"
}

@test "the gate really is an if-condition subshell — the premise of this file" {
    # If update-task.sh stops running the line as an if-condition, every semantic
    # pinned above is void. Assert the shape at its source so this file cannot
    # keep passing against a gate that no longer works this way.
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    grep -q 'if (unset TASKS_DIR CONTEXT_DIR _FW_PATHS_LOADED;.*eval "\$cmd")' \
        "$REPO_ROOT/agents/task-create/update-task.sh"
}
