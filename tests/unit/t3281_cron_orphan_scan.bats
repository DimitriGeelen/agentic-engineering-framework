#!/usr/bin/env bats
# T-3281: orphaned cron.d entries — deployed jobs whose declared PROJECT_ROOT is gone.
#
# The control that matters is C2. A scan that reports every entry it sees would
# pass C1 and look like working detection; only the clean-host leg separates
# "detects orphans" from "always says orphan". Same shape as the negative control
# in tests/unit/t3275_delivery_confirmation.bats — a fixture that cannot fail is
# the failure mode this file exists to avoid.

setup() {
    # pwd -P matters: the scan matches the fw path as a literal substring, and
    # `fw cron install` writes the canonical form. An uncanonicalised
    # `tests/unit/../../bin/fw` here would make every filtered test silently
    # match nothing — which is how C8 first went red.
    FW_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd -P)"
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

@test "C8: an odd-but-equivalent fw path still matches (canonicalisation)" {
    # The real regression: the caller passes `.../tests/unit/../../bin/fw` while
    # the cron entry names `.../bin/fw`. Same binary, different spelling.
    _entry "agentic-audit-dead" "$DEAD_ROOT" "$FW_ROOT/bin/fw"

    run cron_orphan_scan "$CRON_DIR" "$FW_ROOT/tests/unit/../../bin/fw"
    [ "$status" -eq 0 ]
    [[ "$output" == *"agentic-audit-dead"* ]]
}

@test "C9: the report renders a WARN naming each orphan and a removal command" {
    _entry "agentic-audit-dead" "$DEAD_ROOT"

    run cron_orphan_report "$CRON_DIR" "$FW_BIN" "/some/project" "/some/framework"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Orphaned cron entries"* ]]
    [[ "$output" == *"agentic-audit-dead"* ]]
    [[ "$output" == *"$DEAD_ROOT"* ]]
    [[ "$output" == *"/some/framework"* ]]
    # §Copy-Pasteable Commands: single line, cd-prefixed, chained with &&.
    printf '%s\n' "$output" | grep -q "^ *Remove: cd /some/project && sudo rm -f "
}

@test "C10 (control): the report prints nothing and returns 1 on a clean host" {
    _entry "agentic-audit-live" "$LIVE_ROOT"

    run cron_orphan_report "$CRON_DIR" "$FW_BIN" "/some/project" "/some/framework"
    [ "$status" -eq 1 ]
    [ -z "$output" ]
}

@test "C11: fw doctor is wired to the report (real end-to-end, slow)" {
    # One real doctor run, not two: each costs minutes on this host because
    # check 9 shells out to `bats --count` over 606 files (OBS-368). The
    # rendering legs are covered cheaply by C9/C10 above; what only a real run
    # can prove is that doctor calls the report at all, with the right arguments.
    # The orphan block sits OUTSIDE any _doctor_quick_skip guard, so --quick
    # exercises it in full; if that ever changes, this goes red rather than
    # quietly covering nothing.
    _entry "agentic-audit-dead" "$DEAD_ROOT"

    run env FW_CRON_INSTALL_DIR="$CRON_DIR" "$FW_BIN" doctor --quick
    [[ "$output" == *"Orphaned cron entries"* ]]
    [[ "$output" == *"agentic-audit-dead"* ]]
    printf '%s\n' "$output" | grep -q "^ *Remove: cd .* && sudo rm -f "
}
