#!/usr/bin/env bats
# T-4523: the unit-suite runner must notice when the tests change the checkout
# they run in. ring20's clean-room run left ~146 tracked files modified or
# deleted in its clone, and the runner graded only the tests, never the tree.
# Also: the runner must not hand the caller's PROJECT_ROOT to the tests (a run
# in a clone wrote handovers and arcs into the live repo through it).
#
# HERMETIC BY CONSTRUCTION: the runner is pointed at a fixture corpus inside a
# fixture git repo in $BATS_TEST_TMPDIR. The real tests/unit corpus is never run.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    RUNNER="$REPO_ROOT/agents/audit/unit-suite.sh"
    WORK="$BATS_TEST_TMPDIR/t4523"
    FIX="$WORK/repo"
    mkdir -p "$FIX/suite" "$WORK/env"
    echo "tracked" > "$FIX/data.txt"
    echo "tracked" > "$FIX/other.txt"
    # T-4521: fixture tests are spelled @@test and restored by sed, so bats <1.11
    # does not count them as tests of this file.
    sed 's/^@@test/@test/' > "$FIX/suite/clean.bats" <<'EOF'
@@test "writes only to its temp dir" { echo x > "$BATS_TEST_TMPDIR/scratch"; env > "$T4523_ENV_DIR/bats.env"; }
EOF
    sed 's/^@@test/@test/' > "$FIX/suite/leak.bats" <<'EOF'
@@test "writes into the checkout" { echo leaked > "$BATS_TEST_DIRNAME/../data.txt"; }
EOF
    sed 's/^@@test/@test/' > "$FIX/suite/leak2.bats" <<'EOF'
@@test "deletes a tracked file" { rm -f "$BATS_TEST_DIRNAME/../other.txt"; }
EOF
    git -C "$FIX" init -q .
    git -C "$FIX" add -A
    git -C "$FIX" -c user.email=t@t.invalid -c user.name=t4523 -c core.hooksPath=/dev/null \
        commit -qm "fixture"
}

# _run_tier <tier> <files...> — run one tier of the fixture corpus. Reports go
# INSIDE the fixture repo: the runner's own writes must not count as a leak.
_run_tier() {
    local tier="$1"; shift
    { echo "schema: unit-tier-manifest-v1"
      for t in fast slow perf; do
          if [ "$t" = "$tier" ]; then echo "$t:"; printf '  - %s\n' "$@"; else echo "$t: []"; fi
      done; } > "$FIX/suite/tiers.yaml"
    git -C "$FIX" add suite/tiers.yaml && git -C "$FIX" -c user.email=t@t.invalid -c user.name=t4523 \
        -c core.hooksPath=/dev/null commit -qm tiers
    T4523_ENV_DIR="$WORK/env" FW_UNIT_SUITE_TIER="$tier" FW_UNIT_SUITE_JOBS=1 \
    FW_UNIT_SUITE_DIR="$FIX/suite" FW_UNIT_SUITE_REPORT_DIR="$FIX/reports" \
    FW_UNIT_SUITE_LOCK="$WORK/unit-suite.lock" \
        bash "$RUNNER"
}

_guard() { python3 -c 'import sys,yaml; print(yaml.safe_load(open(sys.argv[1]))["tree_guard"][sys.argv[2]])' "$@"; }

@test "control: a run that writes nothing into a clean checkout stays green" {
    run _run_tier fast clean.bats
    [ "$status" -eq 0 ]
    [ "$(_guard "$FIX/reports/LATEST.yaml" start)" = clean ]
    [ "$(_guard "$FIX/reports/LATEST.yaml" changed_count)" = 0 ]
    [ "$(_guard "$FIX/reports/LATEST.yaml" leaked)" = False ]
}

@test "a passing test that modifies a tracked file turns a clean-start run red and names the path" {
    run _run_tier fast leak.bats
    [ "$status" -eq 1 ]
    [[ "$output" == *"changed 1 path(s) in the checkout"* ]]
    [[ "$output" == *" M data.txt"* ]]
    [ "$(_guard "$FIX/reports/LATEST.yaml" leaked)" = True ]
    grep -q " M data.txt" "$FIX/reports/LATEST.yaml"
    grep -q "TREE-LEAK changed=1" "$FIX/reports/runs.log"
}

@test "a deleted tracked file is a leak too" {
    run _run_tier fast leak2.bats
    [ "$status" -eq 1 ]
    grep -q " D other.txt" "$FIX/reports/LATEST.yaml"
}

@test "dirty start: the change is reported, not enforced (other writers may share the tree)" {
    echo "already dirty" > "$FIX/other.txt"
    run _run_tier fast leak.bats
    [ "$status" -eq 0 ]
    [[ "$output" == *"WARN 1 path(s) changed in the checkout"* ]]
    [ "$(_guard "$FIX/reports/LATEST.yaml" start)" = dirty ]
    [ "$(_guard "$FIX/reports/LATEST.yaml" leaked)" = False ]
    grep -q " M data.txt" "$FIX/reports/LATEST.yaml"
    # the file that was dirty before and untouched by the run is not listed
    ! grep -q "other.txt" "$FIX/reports/LATEST.yaml" || false
}

@test "untiered run: a later tier's leak is enforced against the start before any tier ran" {
    { echo "schema: unit-tier-manifest-v1"
      echo "fast:"; echo "  - leak.bats"
      echo "slow:"; echo "  - leak2.bats"
      echo "perf: []"; } > "$FIX/suite/tiers.yaml"
    git -C "$FIX" add -A && git -C "$FIX" -c user.email=t@t.invalid -c user.name=t4523 \
        -c core.hooksPath=/dev/null commit -qm tiers
    run env FW_UNIT_SUITE_JOBS=1 FW_UNIT_SUITE_DIR="$FIX/suite" \
        FW_UNIT_SUITE_REPORT_DIR="$FIX/reports" FW_UNIT_SUITE_LOCK="$WORK/unit-suite.lock" \
        bash "$RUNNER"
    [ "$status" -eq 1 ]
    # slow began on a tree fast had already dirtied; it is still graded as a leak
    [ "$(_guard "$FIX/reports/slow/LATEST.yaml" leaked)" = True ]
    grep -q " D other.txt" "$FIX/reports/slow/LATEST.yaml"
    ! grep -q "data.txt" "$FIX/reports/slow/LATEST.yaml" || false
}

@test "the caller's PROJECT_ROOT does not reach the tests" {
    PROJECT_ROOT="$WORK/elsewhere" run _run_tier fast clean.bats
    [ "$status" -eq 0 ]
    [ -f "$WORK/env/bats.env" ]
    grep -q '^T4523_ENV_DIR=' "$WORK/env/bats.env"
    ! grep -q '^PROJECT_ROOT=' "$WORK/env/bats.env" || false
}

@test "the runner turns doctor's hook exercise and verb telemetry off for the tests" {
    run _run_tier fast clean.bats
    [ "$status" -eq 0 ]
    grep -q '^FW_DOCTOR_HOOK_EXERCISE=0$' "$WORK/env/bats.env"
    grep -q '^FW_VERB_TELEMETRY=0$' "$WORK/env/bats.env"
}

# The exercise really runs every configured hook against the project: on the
# checkout that bumped .hook-counter and rewrote .loop-detect.json. A fixture hook
# that touches a marker shows whether it ran; the control leg proves it would.
@test "doctor skips the hook exercise under FW_DOCTOR_HOOK_EXERCISE=0 (control: it runs without)" {
    local proj="$WORK/proj" mark="$WORK/hook-ran"
    mkdir -p "$proj/.claude" "$proj/.context/working" "$proj/.tasks/active" \
        "$proj/.tasks/completed" "$proj/.tasks/templates"
    echo "framework_root: $REPO_ROOT" > "$proj/.framework.yaml"
    git -C "$proj" init -q
    printf '{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"touch %s"}]}]}}\n' \
        "$mark" > "$proj/.claude/settings.json"
    cd "$proj"
    run env PROJECT_ROOT="$proj" FW_DOCTOR_SMOKE=0 FW_VERB_TELEMETRY=0 FW_DOCTOR_HOOK_EXERCISE=0 \
        NO_COLOR=1 "$REPO_ROOT/bin/fw" doctor --quick
    [[ "$output" == *"SKIP"*"Hook exercise from /tmp (FW_DOCTOR_HOOK_EXERCISE=0)"* ]]
    [ ! -e "$mark" ]
    run env -u FW_DOCTOR_HOOK_EXERCISE PROJECT_ROOT="$proj" FW_DOCTOR_SMOKE=0 FW_VERB_TELEMETRY=0 \
        NO_COLOR=1 "$REPO_ROOT/bin/fw" doctor --quick
    [ -e "$mark" ]
}

@test "doctor's per-host vector-index-health state is gitignored" {
    git -C "$REPO_ROOT" check-ignore -q .context/working/vector-index-health.json
    git -C "$REPO_ROOT" check-ignore -q .context/working/vector-index-health.json.lock
}
