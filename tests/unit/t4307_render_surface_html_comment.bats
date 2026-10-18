#!/usr/bin/env bats
# T-4307 — P-013 render-surface predicate must not read HTML-comment template
# guidance as a render-touching change.
#
# Origin: greenfield consumer run (dimitri-mint-dev T-126). The task template's
# HTML comment names web/app.py; the body-fallback scan in
# lib/render_surface.sh matched it and refused a non-web close.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    source "$FRAMEWORK_ROOT/lib/render_surface.sh"
    TEMPLATE="$FRAMEWORK_ROOT/.tasks/templates/default.md"
    REPO="$TEST_TEMP_DIR/repo"
    mkdir -p "$REPO/lib" "$REPO/web"
    git -C "$REPO" init -q
    echo "x" > "$REPO/lib/x.sh"
    echo "y" > "$REPO/web/app.py"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# commit <subject> <file>... — commit the named files in $REPO
commit() {
    local subject="$1"; shift
    git -C "$REPO" add -- "$@"
    git -C "$REPO" -c user.email=t@t -c user.name=t commit -q -m "$subject"
}

# Build a task file from the real template, with the given id.
template_task() {
    local tid="$1" out="$2"
    sed "s/^id: .*/id: $tid/" "$TEMPLATE" > "$out"
}

@test "T-4307: template comment naming web/app.py does not make a non-web task render-touching (no commits)" {
    grep -q "web/app.py" "$TEMPLATE"
    local tf="$TEST_TEMP_DIR/consumer-task.md"
    template_task T-9401 "$tf"
    commit "T-9400: lib change" lib/x.sh
    cd "$REPO"
    run task_touches_render_surface "$tf"
    [ "$status" -ne 0 ]
}

@test "T-4307: consumer task with a non-web commit is not render-touching (commit evidence path)" {
    local tf="$TEST_TEMP_DIR/consumer-task.md"
    template_task T-9403 "$tf"
    commit "T-9403: lib change" lib/x.sh
    cd "$REPO"
    run task_touches_render_surface "$tf"
    [ "$status" -ne 0 ]
}

@test "T-4307: task whose commit changes web/app.py IS render-touching (commit evidence path)" {
    local tf="$TEST_TEMP_DIR/web-task.md"
    template_task T-9402 "$tf"
    commit "T-9402: change web/app.py" web/app.py
    cd "$REPO"
    run task_touches_render_surface "$tf"
    [ "$status" -eq 0 ]
}

@test "T-4307: body prose naming web/app.py outside a comment IS render-touching (fallback still works)" {
    local tf="$TEST_TEMP_DIR/prose-task.md"
    cat > "$tf" <<'EOF'
---
id: T-9404
---

# T-9404

Fix the header layout in web/app.py so the review page renders.
EOF
    cd "$REPO"
    run task_touches_render_surface "$tf"
    [ "$status" -eq 0 ]
}

@test "T-4307: the same path inside an HTML comment is ignored by the fallback" {
    local tf="$TEST_TEMP_DIR/comment-task.md"
    cat > "$tf" <<'EOF'
---
id: T-9405
---

# T-9405

<!-- Render-touching tasks (web/app.py) add a Visual Verification section. -->
Edit lib/x.sh only.
EOF
    cd "$REPO"
    run task_touches_render_surface "$tf"
    [ "$status" -ne 0 ]
}
