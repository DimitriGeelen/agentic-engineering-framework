#!/usr/bin/env bats
# T-3249 — the RE-ARM relaunch must carry a prompt under --print.
#
# WHY THIS SUITE EXISTS. T-3247 found that a headless auto-restart relaunched
# `claude -p` with no prompt, so the new session died on "Input must be provided"
# before taking a turn. It fixed that — on the RESTART path (budget-critical
# signal) — and left the identical line on the RE-ARM path (clean exit, run still
# armed). A supervised run ends each session one of two ways, so half the loop's
# exit modes stayed dead for as long as the fix looked complete.
#
# It was invisible because a promptless relaunch and a relaunch with nothing to do
# produce the same outward trace: the wrapper prints "Relaunching in 5 seconds",
# the session ends immediately, the ledger records a re-arm. arc-012 E9 measured
# the correlation 1:1 — run 3 had 4 re-arms and 4 "Input must be provided", run 4
# had 1 and 1 — but only because the transcript was captured and re-read.
#
# HOW. The stub `claude` records its own argv. That is the whole assertion: the
# defect is entirely about what the wrapper passes on relaunch, so argv is the
# thing to measure, not side effects.
#
# CONTROL LEG. FW_TEST_WRAPPER points the suite at a pre-fix wrapper, and C1
# asserts it goes RED there. A suite that has never failed is not evidence that
# it can — the same discipline the T-3243 suite states, and the same reason E9's
# positive control exists.

setup() {
    REPO="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    WRAPPER="${FW_TEST_WRAPPER:-${REPO}/bin/claude-fw}"
    TDIR="$(mktemp -d)"
    mkdir -p "${TDIR}/.context/working" "${TDIR}/stubbin"

    git -C "$TDIR" init -q
    git -C "$TDIR" config user.email t@t.t
    git -C "$TDIR" config user.name t

    # Records argv per invocation, one line each, then exits clean with no
    # restart signal — which is precisely the state that drives a re-arm.
    cat > "${TDIR}/stubbin/claude" <<'STUB'
#!/bin/bash
root=$(git rev-parse --show-toplevel 2>/dev/null)
printf '%s\n' "$*" >> "${root}/.stub-argv"
exit "${STUB_EXIT_CODE:-0}"
STUB
    chmod +x "${TDIR}/stubbin/claude"

    LOG="${TDIR}/.context/working/continuous-run.jsonl"
    ARGV="${TDIR}/.stub-argv"
    DIRECTIVE="work the backlog until it is empty"
}

teardown() { rm -rf "$TDIR"; }

arm() { printf 'enabled: %s\ncurrent_iteration: 0\n' "$1" \
        > "${TDIR}/.context/working/.continuous-mode.yaml"; }

file_directive() { printf 'directive: %s\n' "$1" \
        > "${TDIR}/.context/working/.next-directive.yaml"; }

# run_headless — drive the wrapper in --print mode inside the sandbox.
run_headless() {
    cd "$TDIR" || return 1
    run env PATH="${TDIR}/stubbin:${PATH}" HOME="$TDIR" \
        FW_NO_STARTUP_BANNER=1 FW_NO_TERMINATOR=1 \
        FW_MAX_RESTARTS="${MAXR:-2}" FW_RESTART_WINDOW=3600 \
        STUB_EXIT_CODE="${EXITCODE:-0}" \
        timeout 180 bash "$WRAPPER" -p "initial prompt"
}

# relaunch_argv — argv of every invocation after the first (the relaunches).
relaunch_argv() { [ -f "$ARGV" ] && tail -n +2 "$ARGV" || true; }

count_events() {
    [ -f "$LOG" ] || { echo 0; return; }
    python3 - "$LOG" "$1" "$2" <<'PY'
import json, sys
log, ev, rs = sys.argv[1:4]
n = 0
for line in open(log, encoding="utf-8"):
    line = line.strip()
    if not line:
        continue
    try:
        d = json.loads(line)
    except Exception:
        continue
    if d.get("event") == ev and d.get("reason") == rs:
        n += 1
print(n)
PY
}

# ── D1: the defect itself ───────────────────────────────────────────────────

@test "D1: a headless re-arm relaunches WITH the armed directive as the prompt" {
    arm true
    file_directive "$DIRECTIVE"
    run_headless

    # At least one relaunch happened at all — otherwise D1 passes vacuously.
    [ "$(relaunch_argv | wc -l)" -ge 1 ]

    # Every relaunch carries the directive. This is the assertion the pre-fix
    # wrapper cannot satisfy: it passed no prompt at all.
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        [[ "$line" == *"-p"* ]]
        [[ "$line" == *"$DIRECTIVE"* ]]
    done < <(relaunch_argv)
}

@test "D2: no relaunch is promptless — the empty-argv signature never appears" {
    arm true
    file_directive "$DIRECTIVE"
    run_headless

    # The pre-fix wrapper's fingerprint is a relaunch whose argv is exactly
    # "-p" (from the user's own flag) or empty. Neither may occur.
    run bash -c "grep -cxE ' *(-p)? *' '$ARGV' || true"
    [ "$output" = "0" ]
}

# ── D3: refusal when there is nothing to relaunch with ──────────────────────

@test "D3: headless re-arm with no directive REFUSES rather than burning budget" {
    arm true
    # deliberately no .next-directive.yaml
    run_headless

    [ "$status" -eq 1 ]
    [ "$(count_events exit no-directive-headless-rearm)" -eq 1 ]
    # It refused instead of relaunching, so no relaunch was attempted.
    [ "$(relaunch_argv | wc -l)" -eq 0 ]
}

@test "D4: the refusal is distinct from max-restarts in the ledger" {
    arm true
    run_headless
    # Distinguishable reasons matter: "max-restarts" reads as a healthy
    # termination and would hide this.
    [ "$(count_events exit no-directive-headless-rearm)" -eq 1 ]
    [ "$(count_events exit max-restarts)" -eq 0 ]
}

# ── D5: scope — the fix must not change interactive behaviour ───────────────

@test "D5: a NON-headless re-arm still relaunches with no prompt" {
    arm true
    file_directive "$DIRECTIVE"
    cd "$TDIR" || return 1
    run env PATH="${TDIR}/stubbin:${PATH}" HOME="$TDIR" \
        FW_NO_STARTUP_BANNER=1 FW_NO_TERMINATOR=1 \
        FW_MAX_RESTARTS=2 FW_RESTART_WINDOW=3600 STUB_EXIT_CODE=0 \
        timeout 180 bash "$WRAPPER"

    # Interactive relaunch takes the user's terminal, not a prompt. Passing a
    # directive here would be a behaviour change, not a fix.
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        [[ "$line" != *"$DIRECTIVE"* ]]
    done < <(relaunch_argv)
}

# ── C1: the control leg ─────────────────────────────────────────────────────

@test "C1: against the PRE-FIX wrapper, D1 goes red (the suite can fail)" {
    pre="${TDIR}/claude-fw.prefix"
    # Reconstruct the pre-fix re-arm branch: the two-way form with no HEADLESS
    # case, which is exactly what T-3247 replaced on the restart path.
    python3 - "$REPO/bin/claude-fw" "$pre" <<'PY'
import sys
src, dst = sys.argv[1], sys.argv[2]
s = open(src, encoding="utf-8").read()
# Excise the HEADLESS arm of the re-arm branch, leaving the two-way form that
# T-3247 replaced on the restart path. Anchored on the _armed_directive call so
# it can only ever match the RE-ARM branch, never the restart one.
i = s.index('rearm_directive=$(_armed_directive)')
start = s.rindex('            elif [ "$HEADLESS" = "1" ]; then\n', 0, i)
end = s.index('            else\n                CLAUDE_ARGS=()\n', i)
open(dst, "w", encoding="utf-8").write(s[:start] + s[end:])
PY
    # The excision must actually have removed the fix, or C1 proves nothing.
    # Assert the CALL is gone — the helper definition and its comments may
    # survive harmlessly, so counting the name would not be evidence.
    run bash -c "grep -c 'rearm_directive=\$(_armed_directive)' '$pre' || true"
    [ "$output" = "0" ]
    # If the reconstruction does not parse, the control proves nothing.
    run bash -n "$pre"
    [ "$status" -eq 0 ]

    chmod +x "$pre"
    arm true
    file_directive "$DIRECTIVE"
    WRAPPER="$pre" run_headless

    # The pre-fix wrapper must NOT pass the directive. If this ever passes the
    # directive, the reconstruction is wrong and C1 is not a control.
    got_directive=0
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        [[ "$line" == *"$DIRECTIVE"* ]] && got_directive=1
    done < <(relaunch_argv)
    [ "$got_directive" -eq 0 ]
}
