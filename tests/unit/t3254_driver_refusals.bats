#!/usr/bin/env bats
# T-3254 (arc-012) — the outside driver must refuse on every armed condition.
#
# WHAT IS UNDER TEST AND WHY IT IS SPLIT IN TWO. This task flips the loop's default
# from stop-on-silence to continue-unless-done, so the refusals ARE the safety
# argument. There are two units:
#
#   Part A — `fw continuous status --json`, the single evaluator. The driver does
#     not re-type the bounds; it reads this verdict. So the six armed conditions
#     are tested HERE, against the thing that actually decides.
#   Part B — `continuous-driver.sh`, for the one condition the evaluator cannot
#     reach: whether the target session is busy. TermLink has no busy state
#     (measured: `discover --json` says state="ready" for 127 of 127 registered
#     sessions, mid-work ones included), so the driver OBSERVES it instead.
#
# EVERY REFUSAL HAS A PASSING CONTROL. A test that only asserts "refused" cannot
# tell a refusal that fired for the right reason from one that fired for the wrong
# one — and in this file every fixture is one field away from a state that must be
# allowed. So each case asserts the control is ALLOWED first, then mutates exactly
# one field and asserts the refusal names that field. Without the control leg, a
# fixture that is broken in some unrelated way (a path that does not exist, an
# unparseable file) produces a green suite that has measured nothing. That is the
# E9 indistinguishability this arc keeps rediscovering.
#
# PART B ASSERTS THE EFFECT, NOT THE MESSAGE. The AC asks that busy be proven by
# observing session state, so the busy tests assert whether anything was actually
# injected — the stub records every injection to a file — rather than grepping the
# refusal prose. A message can be right while the guard does nothing.

setup() {
    REPO="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    FW="$REPO/bin/fw"
    DRIVER="$REPO/agents/context/continuous-driver.sh"
    SB="$BATS_TEST_TMPDIR/sandbox"
    mkdir -p "$SB/.context/working" "$SB/.tasks/active" "$SB/bin" "$SB/stub"
    touch "$SB/.framework.yaml"

    # Fixture assertions, not spot-checks: a sandbox that is silently the real repo
    # would make every "refused" below meaningless.
    [ "$SB" != "$REPO" ]
    [ -f "$SB/.framework.yaml" ]
    [ -x "$FW" ]
    [ -x "$DRIVER" ] || [ -f "$DRIVER" ]

    STATE_F="$SB/.context/working/.continuous-mode.yaml"
    DIR_F="$SB/.context/working/.next-directive.yaml"
    HALT_F="$SB/.context/working/.continuous-halt"
    LEDGER="$SB/.context/working/continuous-run.jsonl"

    # The consumer shape: a shim in the project, framework source elsewhere. This is
    # also the shape that caught the injector-path defect — see the regression test.
    cat > "$SB/bin/fw" <<SHIM
#!/usr/bin/env bash
exec env PROJECT_ROOT="$SB" FRAMEWORK_ROOT="$REPO" "$REPO/bin/fw" "\$@"
SHIM
    chmod +x "$SB/bin/fw"

    _armed_state
    _armed_directive
}

# ── fixtures ─────────────────────────────────────────────────────────────────
# The baseline is deliberately the ALLOWED state. Each test mutates one field.
_armed_state() {
    cat > "$STATE_F" <<'Y'
enabled: true
current_iteration: 0
tasks_completed: 0
Y
}
_armed_directive() {
    # No T-NNNN reference on purpose: a task ref would pull the ceiling join into
    # cases that are not about the ceiling.
    cat > "$DIR_F" <<'Y'
directive: Continue the backlog work.
Y
}

probe() { PROJECT_ROOT="$SB" "$FW" continuous status --json 2>/dev/null; }

may_inject() {
    probe | python3 -c 'import json,sys
try: print("1" if json.load(sys.stdin).get("may_inject") else "0")
except Exception: print("unparseable")'
}

blockers() {
    probe | python3 -c 'import json,sys
try: print(" | ".join(json.load(sys.stdin).get("blockers") or []))
except Exception: print("unparseable")'
}

# Control + refusal in one move, so neither leg can be forgotten.
assert_control_allows() {
    local m; m="$(may_inject)"
    [ "$m" = "1" ] || { echo "CONTROL FAILED — baseline should be injectable but was not."; echo "blockers: $(blockers)"; return 1; }
}
assert_refused_because() {
    local needle="$1" m b
    m="$(may_inject)"; b="$(blockers)"
    [ "$m" = "0" ] || { echo "expected refusal, got may_inject=$m"; return 1; }
    case "$b" in
        *"$needle"*) return 0 ;;
        *) echo "refused, but for the wrong reason."; echo "  wanted substring: $needle"; echo "  actual blockers:  $b"; return 1 ;;
    esac
}

# ═══ PART A — the six armed conditions, on the evaluator ══════════════════════

@test "A1 enabled: false refuses; enabled: true is the control" {
    assert_control_allows
    printf 'enabled: false\ncurrent_iteration: 0\n' > "$STATE_F"
    assert_refused_because "not armed"
}

@test "A2 a recorded termination refuses; no recorded termination is the control" {
    assert_control_allows
    printf 'enabled: true\ncurrent_iteration: 0\nlast_terminated_reason: human gate hit at 12:00\n' > "$STATE_F"
    assert_refused_because "recorded termination"
}

@test "A3 max_iterations reached refuses; one under is the control" {
    printf 'enabled: true\ncurrent_iteration: 2\nmax_iterations: 5\n' > "$STATE_F"
    assert_control_allows
    printf 'enabled: true\ncurrent_iteration: 5\nmax_iterations: 5\n' > "$STATE_F"
    assert_refused_because "max_iterations reached"
}

@test "A4 max_tasks reached refuses; one under is the control" {
    printf 'enabled: true\ncurrent_iteration: 0\ntasks_completed: 2\nmax_tasks: 3\n' > "$STATE_F"
    assert_control_allows
    printf 'enabled: true\ncurrent_iteration: 0\ntasks_completed: 3\nmax_tasks: 3\n' > "$STATE_F"
    assert_refused_because "max_tasks reached"
}

@test "A5 a lapsed expires_at refuses; a future one is the control" {
    printf 'directive: Continue the backlog work.\nexpires_at: 2999-01-01T00:00:00Z\n' > "$DIR_F"
    assert_control_allows
    printf 'directive: Continue the backlog work.\nexpires_at: 2020-01-01T00:00:00Z\n' > "$DIR_F"
    assert_refused_because "lapsed"
}

@test "A6 a blast-radius over the ceiling refuses; under the ceiling is the control" {
    # The ceiling join is the injector's, invoked for real rather than re-typed —
    # a guard that reimplements the code it guards cannot see that code change.
    _plant_task() {
        cat > "$SB/.tasks/active/T-9001-ceiling-fixture.md" <<Y
---
id: T-9001
name: "ceiling fixture"
status: started-work
workflow_type: build
cost_estimate:
  blast_radius: $1
---
# fixture
Y
    }
    printf 'directive: Continue with T-9001.\nnext_task: T-9001\ntier_ceiling: 4\n' > "$DIR_F"

    _plant_task 2
    assert_control_allows

    _plant_task 9
    assert_refused_because "tier ceiling exceeded"
}

@test "A7 the halt file refuses; its absence is the control (Brake 1, outranks all)" {
    assert_control_allows
    : > "$HALT_F"
    assert_refused_because "halt-file present"
}

# ── regression pin for the injector-path defect ──────────────────────────────
# The ceiling join used to import the injector from PROJECT_ROOT. That path exists
# in the framework repo, where the two roots coincide, and NOWHERE ELSE — so on any
# consumer the import raised FileNotFoundError. `_emit_json` correctly refuses to
# read "could not evaluate" as a green light, so the result was may_inject=false
# forever: fail-safe and completely inert. It passed every test written inside the
# repo, because inside the repo it was never wrong.
@test "A8 the ceiling join resolves from FRAMEWORK_ROOT, so a consumer is not inert" {
    assert_control_allows
    b="$(blockers)"
    case "$b" in
        *"ceiling check unavailable"*)
            echo "the injector did not resolve from a project that is not the framework repo"
            echo "blockers: $b"; return 1 ;;
    esac
}

@test "A9 an unevaluable ceiling is a blocker, never a green light" {
    # The inverse of A8: when the injector genuinely cannot be found, refusing is
    # correct. "No breach" and "could not check" must not collapse into each other.
    # A framework root that fw can RUN from but which has no agents/ tree. Pointing
    # FRAMEWORK_ROOT at a nonexistent path would not test this: fw resolves its own
    # libraries through the same variable and dies before the ceiling join is reached,
    # which is an empty stdout that a laxer assertion would have read as a pass.
    mkdir -p "$SB/fakefw"
    ln -sf "$REPO/lib" "$SB/fakefw/lib"
    ln -sf "$REPO/bin" "$SB/fakefw/bin"
    [ ! -e "$SB/fakefw/agents/context/inject-next-directive.py" ]

    run env PROJECT_ROOT="$SB" FRAMEWORK_ROOT="$SB/fakefw" "$FW" continuous status --json
    [ -n "$output" ]
    echo "$output" | python3 -c 'import json,sys
d = json.load(sys.stdin)
assert d["may_inject"] is False, "unevaluable ceiling was treated as injectable"
assert any("ceiling check unavailable" in b for b in d["blockers"]), d["blockers"]
assert d["ceiling_breached"] is None, d["ceiling_breached"]'
}

# ═══ PART B — busy, observed rather than read ════════════════════════════════

# A termlink stub. `pty output` reads a file the test controls, so "busy" is a
# session whose output CHANGES across the settle window and "quiet" is one whose
# output does not — which is exactly what the driver samples for.
_stub_termlink() {
    local mode="$1"
    cat > "$SB/stub/termlink" <<STUB
#!/usr/bin/env bash
verb="\$1"; shift
case "\$verb" in
  info)     exit 0 ;;
  pty)      sub="\$1"; shift
            if [ "\$sub" = "output" ]; then
                if [ "$mode" = busy ]; then
                    n=\$(cat "$SB/tick" 2>/dev/null || echo 0); echo \$((n+1)) > "$SB/tick"
                    echo "working... \$n"
                else
                    echo "idle prompt >"
                fi
                exit 0
            fi
            if [ "\$sub" = "inject" ]; then echo "\$*" >> "$SB/injected"; exit 0; fi
            exit 0 ;;
  inject)   echo "\$*" >> "$SB/injected"; exit 0 ;;
  *)        exit 0 ;;
esac
STUB
    chmod +x "$SB/stub/termlink"
}

_run_driver() {
    PATH="$SB/stub:$PATH" PROJECT_ROOT="$SB" \
        bash "$DRIVER" --project-root "$SB" --session sandbox-session --settle 1 "$@"
}

@test "B1 a busy session is not injected into" {
    _stub_termlink busy
    run _run_driver
    [ ! -f "$SB/injected" ] || { echo "injected into a BUSY session:"; cat "$SB/injected"; return 1; }
}

@test "B2 control: a quiet session IS injected into" {
    # Without this leg, B1 passes for any reason at all — a broken stub, a driver
    # that never runs, a fixture the evaluator refuses on other grounds.
    _stub_termlink quiet
    run _run_driver
    [ -f "$SB/injected" ] || { echo "quiet session was NOT injected into — B1 proves nothing."; echo "$output"; return 1; }
    grep -q "Continue the backlog work" "$SB/injected"
}

@test "B3 the bounds outrank a quiet session — disarmed means no injection" {
    _stub_termlink quiet
    printf 'enabled: false\ncurrent_iteration: 0\n' > "$STATE_F"
    run _run_driver
    [ ! -f "$SB/injected" ] || { echo "injected while disarmed"; return 1; }
}

# ═══ PART C — every decision is in the ledger ════════════════════════════════

_ledger_reasons() {
    python3 - "$LEDGER" <<'PY'
import json, sys
try:
    lines = open(sys.argv[1], encoding="utf-8").read().splitlines()
except FileNotFoundError:
    print("NO-LEDGER"); raise SystemExit(0)
for ln in lines:
    if not ln.strip(): continue
    d = json.loads(ln)                      # unparseable is a failure, not a skip
    assert d["event"] == "drive", d
    assert d["ts"] and d["reason"], d
    print(d["reason"])
PY
}

@test "C1 a refusal is recorded with its reason, reconstructable without re-running" {
    _stub_termlink busy
    _run_driver
    run _ledger_reasons
    [ "$status" -eq 0 ]
    [[ "$output" == *"refused"* ]]
    # and the detail says WHY, which is the whole point of the AC
    grep -q "BUSY" "$LEDGER"
}

@test "C2 an injection is recorded too, so both outcomes read as one history" {
    _stub_termlink quiet
    _run_driver
    run _ledger_reasons
    [ "$status" -eq 0 ]
    [[ "$output" == *"injected"* ]]
}

@test "C3 a dry run records itself and injects nothing" {
    _stub_termlink quiet
    _run_driver --dry-run
    [ ! -f "$SB/injected" ]
    run _ledger_reasons
    [ "$status" -eq 0 ]
    [[ "$output" == *"dry-run"* ]]
}
