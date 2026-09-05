#!/usr/bin/env bats
# T-3281: orphaned cron.d entries — deployed jobs whose declared PROJECT_ROOT is gone.
#
# The control that matters is C2. A scan that reports every entry it sees would
# pass C1 and look like working detection; only the clean-host leg separates
# "detects orphans" from "always says orphan". Same shape as the negative control
# in tests/unit/t3275_delivery_confirmation.bats — a fixture that cannot fail is
# the failure mode this file exists to avoid.

setup() {
    FW_ROOT="${BATS_TEST_DIRNAME}/../.."
    source "$FW_ROOT/lib/cron-orphans.sh"

    CRON_DIR="$BATS_TEST_TMPDIR/cron.d"
    LIVE_ROOT="$BATS_TEST_TMPDIR/live-project"
    DEAD_ROOT="$BATS_TEST_TMPDIR/dead-project"
    FW_BIN="$FW_ROOT/bin/fw"

    mkdir -p "$CRON_DIR" "$LIVE_ROOT"
    # DEAD_ROOT is deliberately never created.
}

_entry() {
    # _entry <name> <project_root> [fw_path]
    local name="$1" root="$2" fw="${3:-$FW_BIN}"
    cat > "$CRON_DIR/$name" <<EOF
*/30 * * * * root PROJECT_ROOT="$root" "$fw" audit --section structure --cron 2>/dev/null
EOF
}

@test "C1: an entry whose PROJECT_ROOT is gone is reported as an orphan" {
    _entry "agentic-audit-dead" "$DEAD_ROOT"

    run cron_orphan_scan "$CRON_DIR" "$FW_BIN"
    [ "$status" -eq 0 ]
    [[ "$output" == *"agentic-audit-dead"* ]]
    [[ "$output" == *"$DEAD_ROOT"* ]]
}

@test "C2 (control): a host whose entries all resolve reports nothing" {
    _entry "agentic-audit-live" "$LIVE_ROOT"

    run cron_orphan_scan "$CRON_DIR" "$FW_BIN"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "C3: an entry declaring no PROJECT_ROOT is not an orphan" {
    # Legacy install format — resolves by cwd, so the absent variable says
    # nothing about whether the project still exists. 14 live on the origin host.
    cat > "$CRON_DIR/agentic-audit-legacy" <<EOF
*/30 * * * * root "$FW_BIN" audit --section structure --cron 2>/dev/null
EOF

    run cron_orphan_scan "$CRON_DIR" "$FW_BIN"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "C4: an orphan invoking a DIFFERENT bin/fw is not reported for this one" {
    # It falls through to that framework's root, not ours — someone else's problem.
    _entry "agentic-audit-other" "$DEAD_ROOT" "/some/other/install/bin/fw"

    run cron_orphan_scan "$CRON_DIR" "$FW_BIN"
    [ "$status" -eq 0 ]
    [ -z "$output" ]

    # ...and with no fw filter, the same entry IS reported — proving C4's silence
    # comes from the filter and not from the scan failing to see the file at all.
    run cron_orphan_scan "$CRON_DIR" ""
    [ "$status" -eq 0 ]
    [[ "$output" == *"agentic-audit-other"* ]]
}

@test "C5: live and dead entries on one host — only the dead one is reported" {
    _entry "agentic-audit-live" "$LIVE_ROOT"
    _entry "agentic-audit-dead" "$DEAD_ROOT"

    run cron_orphan_scan "$CRON_DIR" "$FW_BIN"
    [ "$status" -eq 0 ]
    [[ "$output" == *"agentic-audit-dead"* ]]
    [[ "$output" != *"agentic-audit-live"* ]]
    [ "$(printf '%s\n' "$output" | wc -l)" -eq 1 ]
}

@test "C6: output is TAB-separated file<TAB>root so callers can split it" {
    _entry "agentic-audit-dead" "$DEAD_ROOT"

    run cron_orphan_scan "$CRON_DIR" "$FW_BIN"
    [ "$status" -eq 0 ]

    local field_count
    field_count=$(printf '%s\n' "$output" | head -1 | awk -F'\t' '{print NF}')
    [ "$field_count" -eq 2 ]
}

@test "C7: a non-existent cron directory is clean, not an error" {
    run cron_orphan_scan "$BATS_TEST_TMPDIR/no-such-dir" "$FW_BIN"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "C8: fw doctor surfaces the orphan and prints a removal command" {
    _entry "agentic-audit-dead" "$DEAD_ROOT"

    # --quick to keep the suite fast. The orphan block sits OUTSIDE any
    # _doctor_quick_skip guard, so quick mode exercises it in full; if that ever
    # changes, this test goes red rather than quietly covering nothing.
    run env FW_CRON_INSTALL_DIR="$CRON_DIR" "$FW_BIN" doctor --quick
    [[ "$output" == *"Orphaned cron entries"* ]]
    [[ "$output" == *"agentic-audit-dead"* ]]
    [[ "$output" == *"sudo rm -f"* ]]
    # §Copy-Pasteable Commands: the removal line is cd-prefixed and single-line.
    printf '%s\n' "$output" | grep -q "^ *Remove: cd .* && sudo rm -f "
}

@test "C9 (control): fw doctor stays silent about orphans on a clean host" {
    _entry "agentic-audit-live" "$LIVE_ROOT"

    run env FW_CRON_INSTALL_DIR="$CRON_DIR" "$FW_BIN" doctor --quick
    [[ "$output" != *"Orphaned cron entries"* ]]
}
