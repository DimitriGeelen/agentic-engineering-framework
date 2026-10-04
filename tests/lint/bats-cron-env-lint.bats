#!/usr/bin/env bats
#
# T-3791 — runs tools/bats-cron-env-lint.py (T-3790), which nothing invoked
# before: a .bats file that runs `schedule install` / `cron install` without
# FW_CRON_INSTALL_DIR writes real files into /etc/cron.d (26 leaked files,
# each running `fw docs --all` daily). The first test is the gate on the live
# corpus; the rest pin the lint against fixtures in BATS_TEST_TMPDIR so a
# lint that never fires cannot pass as green.
#
# `! cmd` at statement position is INERT in bats (L-628) — use explicit status checks.

setup() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    LINT="$ROOT/tools/bats-cron-env-lint.py"
    FIX="$BATS_TEST_TMPDIR/fixtures"
    mkdir -p "$FIX"
}

@test "corpus: every tests/unit .bats that runs a cron install sets FW_CRON_INSTALL_DIR" {
    run python3 "$LINT"
    echo "$output"
    [ "$status" -eq 0 ]
    [[ "$output" == PASS* ]]
}

@test "fixture: cron install without FW_CRON_INSTALL_DIR is a violation (exit 1, file named)" {
    cat > "$FIX/leaky.bats" <<'EOF'
@test "x" {
    run "$FRAMEWORK_ROOT/agents/audit/audit.sh" schedule install
}
EOF
    run python3 "$LINT" "$FIX"
    [ "$status" -eq 1 ]
    [[ "$output" == *"leaky.bats"* ]]
}

@test "fixture: same file with FW_CRON_INSTALL_DIR exported passes" {
    cat > "$FIX/safe.bats" <<'EOF'
setup() { export FW_CRON_INSTALL_DIR="$BATS_TEST_TMPDIR/cron.d"; }
@test "x" {
    run "$FRAMEWORK_ROOT/bin/fw" cron install
}
EOF
    run python3 "$LINT" "$FIX"
    [ "$status" -eq 0 ]
}

@test "fixture: a file that never runs a cron install is not flagged" {
    cat > "$FIX/unrelated.bats" <<'EOF'
@test "x" { run echo hello; }
EOF
    run python3 "$LINT" "$FIX"
    [ "$status" -eq 0 ]
}
