#!/usr/bin/env bats
# T-3948 — an upgraded consumer's older inceptions must not deadlock on the T-2188 gate.
#
# Field report 2026-10-06: after `fw upgrade`, an agent's first edit to an inception created
# before T-2188 was refused ("INCEPTION SCHEMA — required frontmatter fields missing"), and so
# was the edit that would add the fields, because the gate judged the file BEFORE the edit.
# AEF had backfilled only its own corpus (T-2193). Legs: the gate judges the post-edit file;
# a backfill adds the fields; `fw upgrade` and `--type inception` run it.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export NO_COLOR=1
    unset FW_ALLOW_INCEPTION_SCHEMA_DRIFT
    mkdir -p "$TEST_TEMP_DIR/.tasks/active" "$TEST_TEMP_DIR/.tasks/completed" "$TEST_TEMP_DIR/.context/working"
    HOOK="$FRAMEWORK_ROOT/agents/context/check-inception-schema.py"
    BACKFILL="$FRAMEWORK_ROOT/lib/inception_schema_backfill.py"
    OLD="$TEST_TEMP_DIR/.tasks/active/T-9100-old-inception.md"
    printf -- '---\nid: T-9100\nname: "old"\nworkflow_type: inception\nstatus: captured\n---\n\n## Problem Statement\n\nold text\n' > "$OLD"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_edit_json() {   # file old new
    python3 -c 'import json,sys; print(json.dumps({"tool_input":{"file_path":sys.argv[1],"old_string":sys.argv[2],"new_string":sys.argv[3]}}))' "$1" "$2" "$3"
}

@test "T-3948: an edit that ADDS the missing fields passes the gate" {
    run bash -c "$(printf '%q ' printf '%s' "$(_edit_json "$OLD" 'workflow_type: inception' $'workflow_type: inception\ntarget_blast_radius: 3\nvoi_score: 0.5')") | python3 \"$HOOK\""
    [ "$status" -eq 0 ]
}

@test "T-3948/control: an edit that leaves the fields missing is still refused" {
    run bash -c "$(printf '%q ' printf '%s' "$(_edit_json "$OLD" 'old text' 'new text')") | python3 \"$HOOK\""
    [ "$status" -eq 2 ]
    [[ "$output" == *"target_blast_radius missing"* ]]
}

@test "T-3948: a Write whose content carries the fields passes the gate" {
    json=$(python3 -c 'import json,sys; print(json.dumps({"tool_input":{"file_path":sys.argv[1],"content":"---\nid: T-9100\nworkflow_type: inception\ntarget_blast_radius: 2\nvoi_score: 0.4\n---\nx\n"}}))' "$OLD")
    run bash -c "printf '%s' '$json' | python3 \"$HOOK\""
    [ "$status" -eq 0 ]
}

@test "T-3948: backfill adds both fields after workflow_type, once; second run is a no-op" {
    run python3 "$BACKFILL" "$TEST_TEMP_DIR/.tasks"
    [ "$status" -eq 0 ]
    [[ "$output" == *"BACKFILLED"*"T-9100"* ]]
    grep -A2 '^workflow_type: inception' "$OLD" | grep -q '^target_blast_radius: 3$'
    grep -q '^voi_score: 0.5$' "$OLD"
    [ "$(grep -c '^voi_score:' "$OLD")" -eq 1 ]
    run python3 "$BACKFILL" "$TEST_TEMP_DIR/.tasks"
    [[ "$output" == *"0 file(s) changed"* ]]
    # and the gate now passes an ordinary edit
    run bash -c "$(printf '%q ' printf '%s' "$(_edit_json "$OLD" 'old text' 'new text')") | python3 \"$HOOK\""
    [ "$status" -eq 0 ]
}

@test "T-3948: backfill --dry-run lists and changes nothing; non-inceptions are untouched" {
    printf -- '---\nid: T-9101\nworkflow_type: build\n---\nx\n' > "$TEST_TEMP_DIR/.tasks/active/T-9101-b.md"
    run python3 "$BACKFILL" --dry-run "$TEST_TEMP_DIR/.tasks"
    [[ "$output" == *"WOULD BACKFILL"*"T-9100"* ]]
    [[ "$output" != *"T-9101"* ]]
    ! grep -q '^voi_score:' "$OLD" || false
}

@test "T-3948: an existing complete inception is never rewritten" {
    printf -- '---\nid: T-9102\nworkflow_type: inception\ntarget_blast_radius: 7\nvoi_score: 0.9\n---\nx\n' > "$TEST_TEMP_DIR/.tasks/active/T-9102-c.md"
    before=$(cat "$TEST_TEMP_DIR/.tasks/active/T-9102-c.md")
    python3 "$BACKFILL" "$TEST_TEMP_DIR/.tasks" >/dev/null
    [ "$(cat "$TEST_TEMP_DIR/.tasks/active/T-9102-c.md")" = "$before" ]
}

@test "T-3948: fw upgrade of an initialised consumer backfills its old inception" {
    C="$TEST_TEMP_DIR/consumer"
    mkdir -p "$C" && cd "$C" && git init -q && git config user.email t@t && git config user.name t
    "$FRAMEWORK_ROOT/bin/fw" init . >/dev/null 2>&1 || true
    [ -d "$C/.tasks/active" ] || skip "fw init did not create .tasks in this environment"
    printf -- '---\nid: T-0042\nname: "old"\nworkflow_type: inception\nstatus: captured\n---\nold\n' \
        > "$C/.tasks/active/T-0042-old.md"
    run env PROJECT_ROOT="$C" timeout 600 "$FRAMEWORK_ROOT/bin/fw" upgrade "$C"
    [[ "$output" == *"BACKFILLED"*"inception schema fields"* ]]
    grep -q '^target_blast_radius: 3$' "$C/.tasks/active/T-0042-old.md"
    grep -q '^voi_score: 0.5$' "$C/.tasks/active/T-0042-old.md"
}

@test "T-3948: fw upgrade and update-task are wired to the backfill" {
    grep -q 'inception_schema_backfill.py' "$FRAMEWORK_ROOT/lib/upgrade.sh"
    grep -q 'inception_schema_backfill.py' "$FRAMEWORK_ROOT/agents/task-create/update-task.sh"
}
