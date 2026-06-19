#!/usr/bin/env bats
# T-2438: ntfy approval pushes carry the class-correct Watchtower URL (one-tap review).
#
# Two surfaces:
#   1. fw_task_review_url (lib/watchtower.sh) — single source of the class-correct
#      review URL. build/refactor/test → <base>/review/<id>; inception →
#      <base>/inception/<id>; no resolvable base → empty + non-zero (caller then
#      passes no click_url rather than a broken link).
#   2. fw_notify (lib/notify.sh) 5th arg click_url — appended to the message body
#      on its own line when non-empty; 4-arg callers unchanged; disabled no-ops.
#
# The helper routing is stubbed against a fake _watchtower_url so the test needs
# no live Watchtower. fw_notify body-append is verified against a fake dispatcher
# that captures the --message it receives.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export FRAMEWORK_ROOT
    export NO_COLOR=1
    PROJECT_ROOT=$(create_test_project "$TEST_TEMP_DIR/project")
    export PROJECT_ROOT
    # A build task and an inception task to exercise both routing branches.
    cat > "$PROJECT_ROOT/.tasks/active/T-100-build.md" <<'EOF'
---
id: T-100
workflow_type: build
---
# T-100
EOF
    cat > "$PROJECT_ROOT/.tasks/active/T-200-inception.md" <<'EOF'
---
id: T-200
workflow_type: inception
---
# T-200
EOF
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# ─────────────────────────────────────────────────────────────────────────
# fw_task_review_url — class-correct routing (stubbed base)
# ─────────────────────────────────────────────────────────────────────────

@test "t2438 t1: build task routes to /review/<id>" {
    source "$FRAMEWORK_ROOT/lib/watchtower.sh"
    _watchtower_url() { echo "http://wt:3001"; return 0; }
    run fw_task_review_url "T-100"
    [ "$status" -eq 0 ]
    [ "$output" = "http://wt:3001/review/T-100" ]
}

@test "t2438 t2: inception task routes to /inception/<id>" {
    source "$FRAMEWORK_ROOT/lib/watchtower.sh"
    _watchtower_url() { echo "http://wt:3001"; return 0; }
    run fw_task_review_url "T-200"
    [ "$status" -eq 0 ]
    [ "$output" = "http://wt:3001/inception/T-200" ]
}

@test "t2438 t3: unresolvable Watchtower base → empty output + non-zero" {
    source "$FRAMEWORK_ROOT/lib/watchtower.sh"
    _watchtower_url() { return 1; }
    run fw_task_review_url "T-100"
    [ "$status" -ne 0 ]
    [ -z "$output" ]
}

@test "t2438 t4: empty task_id → non-zero (defensive)" {
    source "$FRAMEWORK_ROOT/lib/watchtower.sh"
    _watchtower_url() { echo "http://wt:3001"; return 0; }
    run fw_task_review_url ""
    [ "$status" -ne 0 ]
}

@test "t2438 t5: unknown workflow_type / no task file → defaults to /review" {
    source "$FRAMEWORK_ROOT/lib/watchtower.sh"
    _watchtower_url() { echo "http://wt:3001"; return 0; }
    run fw_task_review_url "T-999"   # no such task file → workflow_type empty
    [ "$status" -eq 0 ]
    [ "$output" = "http://wt:3001/review/T-999" ]
}

# ─────────────────────────────────────────────────────────────────────────
# fw_notify — click_url body-append (fake dispatcher captures --message)
# ─────────────────────────────────────────────────────────────────────────

_install_fake_dispatcher() {
    CAP="$TEST_TEMP_DIR/captured-message.txt"
    rm -f "$CAP"
    FAKE="$TEST_TEMP_DIR/fake_dispatcher.py"
    cat > "$FAKE" <<PYEOF
import sys
msg = ""
a = sys.argv
for i, v in enumerate(a):
    if v == "--message" and i + 1 < len(a):
        msg = a[i + 1]
with open("$CAP", "w") as f:
    f.write(msg)
PYEOF
    export SKILLS_DISPATCHER="$FAKE"
    source "$FRAMEWORK_ROOT/lib/notify.sh"
}

@test "t2438 t6: fw_notify appends click_url to the message body" {
    export NTFY_ENABLED=true
    _install_fake_dispatcher
    fw_notify "Review Needed: T-100" "Test task" "manual" "framework" "http://wt:3001/review/T-100"
    wait
    [ -f "$CAP" ]
    grep -q "Test task" "$CAP"
    grep -q "http://wt:3001/review/T-100" "$CAP"
}

@test "t2438 t7: fw_notify body unchanged when no click_url given (4-arg)" {
    export NTFY_ENABLED=true
    _install_fake_dispatcher
    fw_notify "Review Needed: T-100" "Test task" "manual" "framework"
    wait
    [ -f "$CAP" ]
    [ "$(cat "$CAP")" = "Test task" ]
}

@test "t2438 t8: fw_notify disabled → no dispatch even with click_url" {
    unset NTFY_ENABLED
    _install_fake_dispatcher
    run fw_notify "Review Needed: T-100" "Test task" "manual" "framework" "http://wt:3001/review/T-100"
    [ "$status" -eq 0 ]
    [ ! -f "$CAP" ]
}
