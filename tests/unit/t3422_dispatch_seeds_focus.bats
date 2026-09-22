#!/usr/bin/env bats
# T-3422 — dispatch pre-seeds the worker's session-scoped focus file.
#
# T-3038 gave each dispatched worker its own focus.<name>.yaml but never
# created it, so until the worker's first `fw work-on` the gate's deliberate
# fallback served the SHARED focus.yaml — and the worker read a foreign, real,
# unrelated task as its own (SEQ-T3411 Δ8, four rounds running).
# `fw_focus_seed <root> <task>` (lib/paths.sh) writes the scoped file at
# dispatch time with the worker's own --task, through the SAME resolver the
# reader uses (L-399 parity). Hermetic: every file here lives under a tmpdir.

load ../test_helper

PATHS_LIB="$FRAMEWORK_ROOT/lib/paths.sh"
TERMLINK="$FRAMEWORK_ROOT/agents/termlink/termlink.sh"

setup() {
    TESTROOT="$BATS_TEST_TMPDIR/proj"
    mkdir -p "$TESTROOT/.context/working"
    printf 'current_task: T-9999\nfocus_session: parent-session\n' > "$TESTROOT/.context/working/focus.yaml"
    SHARED_BEFORE="$(cat "$TESTROOT/.context/working/focus.yaml")"
}

# _seed SCOPED KEY TASK — run fw_focus_seed in a clean subshell with an explicit env.
_seed() {
    run env FW_SESSION_SCOPED_FOCUS="${1:-}" FW_FOCUS_SESSION_KEY="${2:-}" \
        bash -c "PROJECT_ROOT='$TESTROOT'; source '$PATHS_LIB' 2>/dev/null; fw_focus_seed '$TESTROOT' '${3:-}'"
}

@test "t3422: seeding writes focus.<key>.yaml with the worker's task and a null session stamp" {
    _seed 1 worker-a T-1234
    [ "$status" -eq 0 ]
    f="$TESTROOT/.context/working/focus.worker-a.yaml"
    [ -f "$f" ]
    grep -q '^current_task: T-1234$' "$f"
    grep -q '^focus_session: null$' "$f"
}

@test "t3422: the shared focus.yaml is left byte-identical" {
    _seed 1 worker-a T-1234
    [ "$status" -eq 0 ]
    [ "$(cat "$TESTROOT/.context/working/focus.yaml")" = "$SHARED_BEFORE" ]
}

@test "t3422: an existing scoped file is not clobbered (rc 1, bytes unchanged)" {
    f="$TESTROOT/.context/working/focus.worker-a.yaml"
    printf 'current_task: T-5555\nfocus_session: worker-own-session\n' > "$f"
    before="$(cat "$f")"
    _seed 1 worker-a T-1234
    [ "$status" -eq 1 ]
    [ "$(cat "$f")" = "$before" ]
}

@test "t3422: refuses (rc 2) outside scoped mode — never seeds the shared file" {
    _seed "" worker-a T-1234
    [ "$status" -eq 2 ]
    [ "$(cat "$TESTROOT/.context/working/focus.yaml")" = "$SHARED_BEFORE" ]
    [ "$(ls "$TESTROOT/.context/working" | grep -c '^focus\.')" -eq 0 ]
}

@test "t3422: refuses (rc 2) with no task — an empty seed would be worse than the fallback" {
    _seed 1 worker-a ""
    [ "$status" -eq 2 ]
    [ ! -f "$TESTROOT/.context/working/focus.worker-a.yaml" ]
}

@test "t3422: the seeded file is exactly what the reader resolves (L-399 parity)" {
    _seed 1 worker-a T-1234
    [ "$status" -eq 0 ]
    resolved=$(env FW_SESSION_SCOPED_FOCUS=1 FW_FOCUS_SESSION_KEY=worker-a \
        bash -c "PROJECT_ROOT='$TESTROOT'; source '$PATHS_LIB' 2>/dev/null; fw_focus_file '$TESTROOT'")
    [ -f "$resolved" ]
    grep -q '^current_task: T-1234$' "$resolved"
}

@test "t3422: dispatch calls the seeder after exporting the scoped-focus vars" {
    key_line=$(grep -n "export FW_FOCUS_SESSION_KEY" "$TERMLINK" | head -1 | cut -d: -f1)
    seed_line=$(grep -n 'fw_focus_seed "\$project_dir" "\$task"' "$TERMLINK" | head -1 | cut -d: -f1)
    [ -n "$key_line" ]
    [ -n "$seed_line" ]
    [ "$key_line" -lt "$seed_line" ]
}
