#!/usr/bin/env bats
# T-2922 — a fresh `fw init` project must be able to complete its first
# inception with no Watchtower running.
#
# The failure: emit_review (lib/review.sh) resolved its base URL with a bare
#
#     base_url=$(_watchtower_url "$task_id")
#
# under `set -e`. _watchtower_url fails LOUD by design — Layer 3 returns 1 with
# no stdout when nothing identifies as this project's Watchtower — so on a
# machine with no server running that assignment aborted emit_review outright.
# The abort happened BEFORE the function's final act: writing
# `.context/working/.reviewed-<id>`, which is the T-973 gate's only unblock for
# `fw inception decide`.
#
# So the greenfield path closed on itself. `fw init` never tells the user to run
# `fw serve`; the onboarding tasks include an inception; the inception cannot be
# decided without a review marker; the review that writes the marker died on a
# missing daemon nobody mentioned. Every disposition was affected — the marker
# gate sits ahead of the go/no-go/defer branch (leg 5 pins this).
#
# The fix moved the fallback into lib/watchtower.sh as
# _watchtower_base_or_placeholder, which answers in both cases and reports which
# via exit code. It did NOT go inline into lib/review.sh: T-1155's invariant
# suite makes `fw_config "PORT" 3000` in that file structurally RED, guarding
# the consumer-port bug that is the same class as this one. A first draft of
# this fix did put it inline and went red on exactly those two invariants —
# which is how the placement question got asked at all.
#
# COST: setup_file runs a real `fw init` (~90s). That is deliberate. The bug
# only exists on a project nobody has configured, so a fixture with a
# pre-populated .context/ cannot reproduce it.

setup_file() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export FRAMEWORK_ROOT

    T2922_PROJ="$(mktemp -d "${TMPDIR:-/tmp}/t2922-greenfield-XXXXXX")"
    export T2922_PROJ

    (
        cd "$T2922_PROJ" || exit 1
        git init -q .
        git config user.email 't2922@example.com'
        git config user.name 'T2922 Fixture'
        "$FRAMEWORK_ROOT/bin/fw" init . >/dev/null 2>&1
    )

    # The premise of every leg below: nothing is serving this project. If a
    # Watchtower triple exists here the fixture is not greenfield and the legs
    # would pass for the wrong reason.
    if [ -f "$T2922_PROJ/.context/working/watchtower.pid" ]; then
        echo "fixture is not greenfield — watchtower triple present" >&2
        return 1
    fi

    # One inception to review. Canonical path, so the T-2204 recommendation
    # gate is satisfied honestly rather than bypassed.
    #
    # PROJECT_ROOT is pinned to the fixture. On the first run of this suite it
    # was not, and `fw inception start` allocated its id from THIS repo's
    # sequence and filed a real T-2928 task here — a test polluting the governed
    # task space it was written to protect. The suite passed anyway, which is
    # the part worth remembering: the leak was invisible to every assertion.
    (
        cd "$T2922_PROJ" || exit 1
        PROJECT_ROOT="$T2922_PROJ" "$FRAMEWORK_ROOT/bin/fw" inception start "greenfield probe" \
            --recommendation GO --rationale "T-2922 fixture" >/dev/null 2>&1
    )

    T2922_TASK=$(cd "$T2922_PROJ" && ls .tasks/active/ 2>/dev/null | grep -i 'greenfield-probe' | head -1 | grep -oE '^T-[0-9]+')
    export T2922_TASK

    # Containment assertion: nothing this fixture creates may land outside it.
    # Refuses loudly rather than letting the legs run — a suite that pollutes
    # the repo it guards is worse than a suite that does not run.
    if [ -n "$T2922_TASK" ] && [ -e "$FRAMEWORK_ROOT/.tasks/active/$T2922_TASK-greenfield-probe.md" ]; then
        echo "fixture leaked $T2922_TASK into the framework repo — refusing to run" >&2
        rm -rf "$T2922_PROJ"
        return 1
    fi
}

teardown_file() {
    [ -n "${T2922_PROJ:-}" ] && [ -d "$T2922_PROJ" ] && rm -rf "$T2922_PROJ"
    return 0
}

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    [ -n "${T2922_TASK:-}" ] || {
        echo "fixture did not produce a task id — setup_file failed" >&2
        return 1
    }
    rm -f "$T2922_PROJ/.context/working/.reviewed-$T2922_TASK"
}

# ── AC1: the regression must bite before it is repaired ──────────────────────

@test "t2922: BEFORE the fix, review on a Watchtower-less project dies with no marker" {
    # Reconstructs the pre-fix assignment against the real _watchtower_url in a
    # real greenfield project, under the same `set -e` emit_review runs with.
    # Not a re-implementation of the bug: the failing operation is the genuine
    # Layer 3 refusal, and the assertion is that control never reaches the line
    # after it — which is where the marker write lived.
    run bash -c "
        set -e
        export PROJECT_ROOT='$T2922_PROJ'
        export FRAMEWORK_ROOT='$FRAMEWORK_ROOT'
        source '$FRAMEWORK_ROOT/lib/watchtower.sh'
        base_url=\$(_watchtower_url '$T2922_TASK')   # <-- the pre-fix line
        touch '$T2922_PROJ/.context/working/.reviewed-$T2922_TASK'
        echo REACHED_MARKER_WRITE
    "
    [ "$status" -ne 0 ]
    [[ "$output" != *REACHED_MARKER_WRITE* ]]
    [ ! -f "$T2922_PROJ/.context/working/.reviewed-$T2922_TASK" ]
}

# ── AC2 + AC4: the fix, and that it adds no daemon prerequisite ──────────────

@test "t2922: fw task review exits 0 and writes the marker with no Watchtower" {
    # T-2922 follow-up: an inherited PROJECT_ROOT (env wins unconditionally per
    # T-2391) makes bin/fw resolve to whatever project the *calling* shell was
    # already rooted in instead of $T2922_PROJ — exactly the ambient state a
    # verification-gate run or an already-focused dev shell has. Pin PROJECT_ROOT
    # to the fixture explicitly, the same way setup_file does for `inception
    # start`, so this leg's outcome depends on the fix, not on caller env hygiene.
    run bash -c "cd '$T2922_PROJ' && PROJECT_ROOT='$T2922_PROJ' '$FRAMEWORK_ROOT/bin/fw' task review '$T2922_TASK'"
    [ "$status" -eq 0 ] || { echo "$output" >&2; return 1; }
    [ -f "$T2922_PROJ/.context/working/.reviewed-$T2922_TASK" ]
}

@test "t2922: onboarding gains no live-Watchtower requirement" {
    # Same assertion as above, stated as the property that matters: the run
    # above happened with nothing serving this project, and still succeeded.
    # If a future change makes emit_review require a reachable server, this
    # fails here rather than silently on somebody's fresh machine.
    [ ! -f "$T2922_PROJ/.context/working/watchtower.pid" ]
    run bash -c "cd '$T2922_PROJ' && PROJECT_ROOT='$T2922_PROJ' '$FRAMEWORK_ROOT/bin/fw' task review '$T2922_TASK'"
    [ "$status" -eq 0 ]
}

# ── AC5: name the prerequisite, don't just print a URL that presumes it ──────

@test "t2922: review output names 'fw serve' when nothing is serving" {
    run bash -c "cd '$T2922_PROJ' && PROJECT_ROOT='$T2922_PROJ' '$FRAMEWORK_ROOT/bin/fw' task review '$T2922_TASK' 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" == *"fw serve"* ]] || {
        echo "output does not tell the user how to start the server the URL presumes" >&2
        return 1
    }
}

@test "t2922: the placeholder URL carries the configured port, not a bare path" {
    # An empty base_url concatenates into "/review/T-XXX" — a broken relative
    # path that still reads as a link. The placeholder must be a real absolute
    # URL, correct the moment `fw serve` runs.
    run bash -c "cd '$T2922_PROJ' && PROJECT_ROOT='$T2922_PROJ' '$FRAMEWORK_ROOT/bin/fw' task review '$T2922_TASK' 2>&1"
    [[ "$output" == *"http://localhost:"*"/inception/$T2922_TASK"* ]] || {
        echo "no absolute placeholder URL in output" >&2
        return 1
    }
}

# ── AC3: all three dispositions, not just go ─────────────────────────────────

@test "t2922: the marker gate precedes disposition branching (all three unblocked)" {
    # AC3 asks that go, no-go AND defer each become possible once the marker
    # exists. It cannot be verified by execution here: `fw inception decide` is
    # Tier 0 and blocked in agent context by design, and routing around that to
    # green a test would be the exact bypass the gate exists to prevent.
    #
    # Verified structurally instead, which for this question is actually
    # stronger than three executions: the gate is disposition-INDEPENDENT by
    # construction. Two facts establish it —
    #   (a) the marker check sits at a lower line than any use of $decision
    #       other than the validation case, and
    #   (b) that validation case accepts go|no-go|defer on one arm, so all
    #       three reach the gate along an identical path.
    # Three passing executions would only sample the same single code path.
    local inc="$FRAMEWORK_ROOT/lib/inception.sh"

    local marker_line
    marker_line=$(grep -n 'reviewed-\$task_id' "$inc" | head -1 | cut -d: -f1)
    [ -n "$marker_line" ] || { echo "marker gate not found in lib/inception.sh" >&2; return 1; }

    local validation_line
    validation_line=$(grep -n 'go|no-go|defer)' "$inc" | head -1 | cut -d: -f1)
    [ -n "$validation_line" ] || { echo "3-way disposition validation not found" >&2; return 1; }

    # (a) validation is upstream of the marker gate
    [ "$validation_line" -lt "$marker_line" ] || {
        echo "disposition validation is not upstream of the marker gate" >&2
        return 1
    }

    # (b) nothing between them branches on the disposition value
    local between
    between=$(awk -v a="$validation_line" -v b="$marker_line" \
        'NR>a && NR<b' "$inc" | grep -vE '^[[:space:]]*#' | grep -E '\$decision' || true)
    [ -z "$between" ] || {
        echo "disposition is consulted between validation and the marker gate:" >&2
        echo "$between" >&2
        return 1
    }
}

# ── The helper's contract ────────────────────────────────────────────────────

@test "t2922: _watchtower_base_or_placeholder returns exit 2 + a URL when down" {
    run bash -c "
        export PROJECT_ROOT='$T2922_PROJ'
        export FRAMEWORK_ROOT='$FRAMEWORK_ROOT'
        source '$FRAMEWORK_ROOT/lib/watchtower.sh'
        out=\$(_watchtower_base_or_placeholder '$T2922_TASK' 2>/dev/null); rc=\$?
        echo \"rc=\$rc out=\$out\"
    "
    [ "$status" -eq 0 ]
    [[ "$output" == "rc=2 out=http://localhost:"* ]]
}

@test "t2922: it never answers empty — the down case is a code, not a blank" {
    # The whole point of exit 2 over an empty string: a caller that ignores the
    # status still gets something concatenable, and a caller that reads it gets
    # the truth. An empty answer would be indistinguishable from success at the
    # call site and would rebuild the broken-relative-path bug one layer up.
    run bash -c "
        export PROJECT_ROOT='$T2922_PROJ'
        export FRAMEWORK_ROOT='$FRAMEWORK_ROOT'
        source '$FRAMEWORK_ROOT/lib/watchtower.sh'
        _watchtower_base_or_placeholder '$T2922_TASK' 2>/dev/null
    "
    [ -n "$output" ]
}

# ── AC6: the live path is unchanged ──────────────────────────────────────────

@test "t2922: with a live Watchtower the helper returns exit 0 and that server's URL" {
    # Regression leg for the shared emit path. Uses THIS repo, which has a
    # Watchtower running; skips loudly rather than passing when it does not,
    # because a silent skip here would read as "live path verified".
    run bash -c "
        cd '$FRAMEWORK_ROOT'
        export PROJECT_ROOT='$FRAMEWORK_ROOT'
        export FRAMEWORK_ROOT='$FRAMEWORK_ROOT'
        source '$FRAMEWORK_ROOT/lib/watchtower.sh'
        _watchtower_url T-2922 >/dev/null 2>&1 || exit 3
        out=\$(_watchtower_base_or_placeholder T-2922); rc=\$?
        echo \"rc=\$rc out=\$out\"
    "
    if [ "$status" -eq 3 ]; then
        skip "no Watchtower running for the framework repo — live-path leg NOT verified"
    fi
    [ "$status" -eq 0 ]
    [[ "$output" == "rc=0 out=http"* ]]
    # and it must be the real server, not the placeholder shape
    [[ "$output" != *"rc=0 out=http://localhost:3000"* ]] || {
        echo "live path returned the placeholder default — identity check may be bypassed" >&2
        return 1
    }
}
