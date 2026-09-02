#!/usr/bin/env bats
# T-3247 — the budget-critical RESTART relaunch must carry a prompt under --print.
#
# WHY THIS SUITE EXISTS. `bin/claude-fw` sets CLAUDE_ARGS=() on every budget
# restart (T-3166, fresh session not -c) so the resumed session frees context
# instead of restoring the transcript that tripped critical in the first place.
# That is correct for an interactive terminal — SessionStart injects the
# directive and the operator's own turn picks it up. Under `claude --print` a
# promptless relaunch has no turn to take: it dies on "Input must be provided
# either through stdin or as a prompt argument when using --print" before any
# injected context matters, and the loop spends its whole restart budget on
# sessions that could never have worked regardless of what was queued for them.
# Observed 1:1 in arc-012 E5, E7, E8 and E9 and misread every time as a
# successful restart, because the wrapper's own banner said so one line above
# the error.
#
# HOW. The stub `claude` records its own argv — the defect is entirely about
# what the wrapper passes on relaunch, so argv is the thing to measure. The
# restart signal (.context/working/.restart-requested) is written directly by
# the test, mirroring what checkpoint.sh writes at critical budget, rather than
# waiting for a real budget trip.
#
# CONTROL LEG. FW_TEST_WRAPPER points the suite at a pre-fix wrapper
# reconstructed from the live one, and C1 asserts D1 goes RED there — the same
# discipline T-3243's and T-3249's suites use.

setup() {
    REPO="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    WRAPPER="${FW_TEST_WRAPPER:-${REPO}/bin/claude-fw}"
    TDIR="$(mktemp -d)"
    mkdir -p "${TDIR}/.context/working" "${TDIR}/stubbin"

    git -C "$TDIR" init -q
    git -C "$TDIR" config user.email t@t.t
    git -C "$TDIR" config user.name t

    # Records argv per invocation, one line each, then exits clean — the
    # restart signal is already on disk by the time this runs, mirroring a
    # checkpoint.sh write that landed mid-session before claude exited.
    cat > "${TDIR}/stubbin/claude" <<'STUB'
#!/bin/bash
root=$(git rev-parse --show-toplevel 2>/dev/null)
printf '%s\n' "$*" >> "${root}/.stub-argv"
exit "${STUB_EXIT_CODE:-0}"
STUB
    chmod +x "${TDIR}/stubbin/claude"

    LOG="${TDIR}/.context/working/continuous-run.jsonl"
    SIGNAL="${TDIR}/.context/working/.restart-requested"
    ARGV="${TDIR}/.stub-argv"
    DIRECTIVE="work the backlog until it is empty"
}

teardown() { rm -rf "$TDIR"; }

# write_signal [directive] — the restart signal checkpoint.sh writes at
# critical budget (agents/context/checkpoint.sh:180). Omit the arg to
# reproduce the no-directive case.
write_signal() {
    local directive_json=""
    if [ -n "${1:-}" ]; then
        directive_json=",\"directive\":$(python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$1")"
    fi
    cat > "$SIGNAL" <<EOF
{"timestamp":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","session_id":"s1","reason":"critical_budget_auto_handover","tokens":300000${directive_json}}
EOF
}

# run_headless — drive the wrapper in --print mode inside the sandbox.
run_headless() {
    cd "$TDIR" || return 1
    run env PATH="${TDIR}/stubbin:${PATH}" HOME="$TDIR" \
        FW_NO_STARTUP_BANNER=1 FW_NO_TERMINATOR=1 \
        FW_MAX_RESTARTS="${MAXR:-2}" FW_RESTART_WINDOW=3600 \
        STUB_EXIT_CODE="${EXITCODE:-0}" \
        timeout 180 bash "$WRAPPER" -p "initial prompt"
}

# run_interactive — same sandbox, no -p/--print (the scope-control leg).
run_interactive() {
    cd "$TDIR" || return 1
    run env PATH="${TDIR}/stubbin:${PATH}" HOME="$TDIR" \
        FW_NO_STARTUP_BANNER=1 FW_NO_TERMINATOR=1 \
        FW_MAX_RESTARTS="${MAXR:-2}" FW_RESTART_WINDOW=3600 \
        STUB_EXIT_CODE="${EXITCODE:-0}" \
        timeout 180 bash "$WRAPPER"
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

@test "D1: a headless budget restart relaunches WITH the directive as the prompt" {
    write_signal "$DIRECTIVE"
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
    write_signal "$DIRECTIVE"
    run_headless

    # The pre-fix wrapper's fingerprint is a relaunch whose argv is exactly
    # "-p" (from the user's own flag) or empty. Neither may occur.
    run bash -c "grep -cxE ' *(-p)? *' '$ARGV' || true"
    [ "$output" = "0" ]
}

# ── D3: refusal when there is nothing to relaunch with ──────────────────────

@test "D3: headless restart with no directive REFUSES rather than burning budget" {
    write_signal   # deliberately no directive
    run_headless

    [ "$status" -eq 1 ]
    [ "$(count_events exit no-directive-headless)" -eq 1 ]
    # It refused instead of relaunching, so no relaunch was attempted.
    [ "$(relaunch_argv | wc -l)" -eq 0 ]
}

@test "D4: the refusal is distinct from max-restarts in the ledger" {
    write_signal
    run_headless
    # Distinguishable reasons matter: "max-restarts" reads as a healthy
    # termination and would hide this.
    [ "$(count_events exit no-directive-headless)" -eq 1 ]
    [ "$(count_events exit max-restarts)" -eq 0 ]
}

# ── D5: FW_RESTART_MODE=continue is not re-routed by the headless fix ───────

@test "D5: FW_RESTART_MODE=continue still yields a bare -c, even headless with a directive" {
    write_signal "$DIRECTIVE"
    export FW_RESTART_MODE=continue
    run_headless

    got=$(relaunch_argv | head -1)
    [ "$got" = "-c" ]
}

# ── D6: scope — the fix must not change interactive behaviour ──────────────

@test "D6: a NON-headless restart still relaunches with an empty argv (fresh session)" {
    write_signal "$DIRECTIVE"
    run_interactive

    got=$(relaunch_argv | head -1)
    [ -z "$got" ]
}

# ── C1: the control leg ─────────────────────────────────────────────────────

@test "C1: against the PRE-FIX wrapper, D1 goes red (the suite can fail)" {
    pre="${TDIR}/claude-fw.prefix"
    # Reconstruct the pre-T-3247 restart branch: the two-way form with no
    # HEADLESS case. Anchored on the local_directive check, which is unique to
    # the RESTART branch (the sibling re-arm branch checks rearm_directive),
    # so this can only ever excise the restart-path fix.
    python3 - "$REPO/bin/claude-fw" "$pre" <<'PY'
import sys
src, dst = sys.argv[1], sys.argv[2]
s = open(src, encoding="utf-8").read()
i = s.index('if [ -n "$local_directive" ]; then\n                CLAUDE_ARGS=')
start = s.rindex('        elif [ "$HEADLESS" = "1" ]; then\n', 0, i)
end = s.index('        else\n            CLAUDE_ARGS=()\n        fi\n', i)
open(dst, "w", encoding="utf-8").write(s[:start] + s[end:])
PY
    # The excision must actually have removed the fix, or C1 proves nothing.
    # Assert the CALL is gone — `local_directive` itself is read elsewhere
    # (the pre-existing "Directive: ..." echo/export) and survives harmlessly,
    # so counting the variable name would not be evidence.
    run python3 -c "
import sys
n = open('$pre', encoding='utf-8').read().count('CLAUDE_ARGS=(\"-p\" \"\$local_directive\")')
print(n)
"
    [ "$output" = "0" ]
    # If the reconstruction does not parse, the control proves nothing.
    run bash -n "$pre"
    [ "$status" -eq 0 ]

    chmod +x "$pre"
    write_signal "$DIRECTIVE"
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
