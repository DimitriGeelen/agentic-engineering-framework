#!/usr/bin/env bats
# T-1766 — render-surface Human-AC gate (P-013).
#
# Build/refactor/test tasks touching web render surfaces (templates,
# blueprints, CSS/JS, web/shared.py, web/app.py) must carry at least one
# [REVIEW] Human AC before --status work-completed is allowed.
#
# Origin: T-1763, T-1764, T-1765 shipped render-surface fixes with zero
# Human ACs — user caught the omission and asked for RCA + structural fix.

load ../test_helper

# ---- Source-level invariants ----

@test "T-1766: lib/render_surface.sh exists and exports RENDER_SURFACE_PATTERNS" {
    [ -f "$FRAMEWORK_ROOT/lib/render_surface.sh" ]
    grep -q "RENDER_SURFACE_PATTERNS=" "$FRAMEWORK_ROOT/lib/render_surface.sh"
    grep -qF '"web/templates/*.html"' "$FRAMEWORK_ROOT/lib/render_surface.sh"
    grep -qF '"web/blueprints/*.py"' "$FRAMEWORK_ROOT/lib/render_surface.sh"
    grep -qF '"web/shared.py"' "$FRAMEWORK_ROOT/lib/render_surface.sh"
}

@test "T-1766: update-task.sh sources render_surface.sh" {
    grep -q "lib/render_surface.sh" "$FRAMEWORK_ROOT/agents/task-create/update-task.sh"
}

@test "T-1766: update-task.sh defines check_render_surface_human_ac and wires it into work-completed sequence" {
    grep -q "^check_render_surface_human_ac()" "$FRAMEWORK_ROOT/agents/task-create/update-task.sh"
    # Function is called somewhere in the gate dispatch
    grep -c "check_render_surface_human_ac" "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" | awk '{exit !($1 >= 2)}'
}

@test "T-1766: --skip-render-review flag is parsed and surfaced in help" {
    grep -q "\-\-skip-render-review" "$FRAMEWORK_ROOT/agents/task-create/update-task.sh"
    grep -q "SKIP_RENDER_REVIEW" "$FRAMEWORK_ROOT/agents/task-create/update-task.sh"
}

# ---- Behavioural — predicate ----

@test "T-1766/predicate: task with web/templates path in components returns 0 (touches)" {
    source "$FRAMEWORK_ROOT/lib/render_surface.sh"
    local tf="$TEST_TEMP_DIR/render-task.md"
    cat > "$tf" <<'EOF'
---
id: T-PRED-1
components: ["web/templates/tasks.html"]
---

body
EOF
    run task_touches_render_surface "$tf"
    [ "$status" -eq 0 ]
}

@test "T-1766/predicate: task with lib/ path only returns 1 (does not touch)" {
    source "$FRAMEWORK_ROOT/lib/render_surface.sh"
    local tf="$TEST_TEMP_DIR/nonrender-task.md"
    cat > "$tf" <<'EOF'
---
id: T-PRED-2
components: ["lib/render_surface.sh"]
---

body mentions agents/task-create/update-task.sh too.
EOF
    run task_touches_render_surface "$tf"
    [ "$status" -ne 0 ]
}

@test "T-1766/predicate: task with web/blueprints/*.py in body verification block returns 0" {
    source "$FRAMEWORK_ROOT/lib/render_surface.sh"
    local tf="$TEST_TEMP_DIR/body-render-task.md"
    cat > "$tf" <<'EOF'
---
id: T-PRED-3
---

## Verification

curl -sf $(bin/fw watchtower url)/tasks/T-1 > /tmp/out
grep -q "expected" web/blueprints/tasks.py
EOF
    run task_touches_render_surface "$tf"
    [ "$status" -eq 0 ]
}

# ---- T-2061: git-evidence-preferred over body-text path tokens (L-435 fix) ----
#
# When the task has commits in git history (`git log --grep TASK_ID`),
# those commits are authoritative for what was actually modified. Body-text
# mentions are ignored — they cannot distinguish "this task modifies X"
# from "this task discusses X". When the task has NO commits (first-close,
# test fixtures), the body+components scan is used as fallback.

@test "T-2061/predicate: body mentions render path but commits touched only lib/ → returns 1 (false-positive fixed)" {
    source "$FRAMEWORK_ROOT/lib/render_surface.sh"
    # Set up a tiny git tree with a commit that touches ONLY a non-render file
    # while a synthetic task body discusses a render path. Use numeric task
    # ID (T-NNNN) — that's the real-world shape `_render_surface_extract_task_id`
    # matches; non-numeric synthetic ids (T-FP-1 etc) fail the regex and fall
    # back to body scan, which would re-introduce the false-positive in the
    # test itself.
    local proj="$TEST_TEMP_DIR/t2061-fp"
    mkdir -p "$proj"
    pushd "$proj" >/dev/null
    git init -q >/dev/null 2>&1
    git config user.email "t@t.t" && git config user.name "t"
    mkdir -p lib tests
    echo "stub" > lib/foo.sh
    git add lib/foo.sh && git commit -qm "T-90061: edit lib/foo.sh (no render touch)"
    local tf="$proj/T-90061.md"
    cat > "$tf" <<'EOF'
---
id: T-90061
---
The whole point of this task is that web/blueprints/settings.py and
web/templates/approvals.html are intentionally UNTOUCHED. settings.py
remains as-is. We did NOT modify any template.
EOF
    run task_touches_render_surface "$tf"
    popd >/dev/null
    [ "$status" -ne 0 ]
}

@test "T-2061/predicate: body mentions render path AND commits touched it → returns 0 (true-positive preserved)" {
    source "$FRAMEWORK_ROOT/lib/render_surface.sh"
    local proj="$TEST_TEMP_DIR/t2061-tp"
    mkdir -p "$proj"
    pushd "$proj" >/dev/null
    git init -q >/dev/null 2>&1
    git config user.email "t@t.t" && git config user.name "t"
    mkdir -p web/templates
    echo "<html/>" > web/templates/foo.html
    git add web/templates/foo.html && git commit -qm "T-90062: edit web/templates/foo.html"
    local tf="$proj/T-90062.md"
    cat > "$tf" <<'EOF'
---
id: T-90062
---
Modified web/templates/foo.html to fix something.
EOF
    run task_touches_render_surface "$tf"
    popd >/dev/null
    [ "$status" -eq 0 ]
}

@test "T-2061/files: render_surface_files_in returns committed paths only when git history exists" {
    source "$FRAMEWORK_ROOT/lib/render_surface.sh"
    local proj="$TEST_TEMP_DIR/t2061-files"
    mkdir -p "$proj"
    pushd "$proj" >/dev/null
    git init -q >/dev/null 2>&1
    git config user.email "t@t.t" && git config user.name "t"
    mkdir -p web/blueprints lib
    echo "stub" > lib/foo.sh
    echo "blueprint" > web/blueprints/tasks.py
    git add lib/foo.sh web/blueprints/tasks.py
    git commit -qm "T-90063: touch lib/foo.sh and web/blueprints/tasks.py"
    local tf="$proj/T-90063.md"
    cat > "$tf" <<'EOF'
---
id: T-90063
---
Body also mentions web/templates/never-touched.html for context only.
EOF
    run render_surface_files_in "$tf"
    popd >/dev/null
    # render_surface_files_in must report the committed blueprint, not the
    # body-only-mentioned template
    [[ "$output" == *"web/blueprints/tasks.py"* ]]
    [[ "$output" != *"web/templates/never-touched.html"* ]]
}

# ---- Behavioural — gate firing ----
# These are smoke-shape tests using a stub helper. They run the gate
# function in isolation by sourcing it with NEW_STATUS / TASK_FILE / SKIP_*
# preset, mimicking the call-site contract.

_run_gate_in_isolation() {
    local task_file="$1"
    local new_status="${2:-work-completed}"
    local skip_flag="${3:-false}"
    local skip_reason="${4:-}"

    # Stub the colors (the function uses ${RED} etc.) and log_gate_bypass.
    bash -c "
        set +e
        export TASK_ID='T-RS-FIXTURE'
        export TASK_FILE='$task_file'
        export NEW_STATUS='$new_status'
        export SKIP_RENDER_REVIEW='$skip_flag'
        export SKIP_RENDER_REVIEW_REASON='$skip_reason'
        export PROJECT_ROOT='$TEST_TEMP_DIR'
        export RED='' GREEN='' YELLOW='' NC=''
        mkdir -p \"\$PROJECT_ROOT/.context/working\"
        source '$FRAMEWORK_ROOT/lib/render_surface.sh'
        log_gate_bypass() { echo 'BYPASS LOGGED: \$1'; }
        # Inline the function from update-task.sh
        \$(sed -n '/^check_render_surface_human_ac()/,/^}/p' '$FRAMEWORK_ROOT/agents/task-create/update-task.sh')
        # ^ that's awkward — instead source the file and call.
    " 2>&1 || true
}

# Simpler: write a fixture and invoke update-task.sh end-to-end at the
# work-completed entry point. We bypass the AC + RCA gates by passing
# `--skip-acceptance-criteria --skip-verification --skip-rca` so the
# render-surface gate is the one we are testing.

@test "T-1766/gate-a: render task with no Human AC blocks work-completed" {
    local proj="$TEST_TEMP_DIR/proj"
    mkdir -p "$proj/.tasks/active" "$proj/.tasks/completed" "$proj/.context/working"
    cd "$proj"

    cat > "$proj/.tasks/active/T-RSGATE-A-fixture.md" <<'EOF'
---
id: T-RSGATE-A
name: "render task without human AC"
status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: ["web/templates/tasks.html"]
created: 2026-05-16T08:00:00Z
last_update: 2026-05-16T08:00:00Z
---

# T-RSGATE-A

## Acceptance Criteria

### Agent
- [x] something agent-verifiable

## Verification

true
EOF

    run env PROJECT_ROOT="$proj" "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" T-RSGATE-A \
        --status work-completed \
        --skip-acceptance-criteria --skip-verification --skip-recommendation --skip-rca
    [ "$status" -ne 0 ]
    echo "$output" | grep -q "render surface"
}

@test "T-1766/gate-b: render task WITH [REVIEW] Human AC passes the gate" {
    local proj="$TEST_TEMP_DIR/proj"
    mkdir -p "$proj/.tasks/active" "$proj/.tasks/completed" "$proj/.context/working"
    cd "$proj"

    cat > "$proj/.tasks/active/T-RSGATE-B-fixture.md" <<'EOF'
---
id: T-RSGATE-B
name: "render task with REVIEW human AC"
status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: ["web/templates/tasks.html"]
created: 2026-05-16T08:00:00Z
last_update: 2026-05-16T08:00:00Z
---

# T-RSGATE-B

## Acceptance Criteria

### Agent
- [x] something agent-verifiable

### Human
- [ ] [REVIEW] page renders correctly

## Verification

true
EOF

    run env PROJECT_ROOT="$proj" "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" T-RSGATE-B \
        --status work-completed \
        --skip-acceptance-criteria --skip-verification --skip-recommendation --skip-rca
    # Should NOT exit on render-surface gate (may exit on other reasons if the
    # task is partial-complete; we only care that the render-surface ERROR
    # message does not appear)
    ! echo "$output" | grep -q "ERROR: Cannot complete build task — touches render surface"
}

@test "T-1766/gate-c: non-render task does not trigger the gate" {
    local proj="$TEST_TEMP_DIR/proj"
    mkdir -p "$proj/.tasks/active" "$proj/.tasks/completed" "$proj/.context/working"
    cd "$proj"

    cat > "$proj/.tasks/active/T-RSGATE-C-fixture.md" <<'EOF'
---
id: T-RSGATE-C
name: "lib-only task"
status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: ["lib/some_helper.sh"]
created: 2026-05-16T08:00:00Z
last_update: 2026-05-16T08:00:00Z
---

# T-RSGATE-C

## Acceptance Criteria

### Agent
- [x] agent ok

## Verification

true
EOF

    run env PROJECT_ROOT="$proj" "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" T-RSGATE-C \
        --status work-completed \
        --skip-acceptance-criteria --skip-verification --skip-recommendation --skip-rca
    ! echo "$output" | grep -q "touches render surface"
}

@test "T-1766/gate-d: --skip-render-review bypass with rationale logs and allows close" {
    local proj="$TEST_TEMP_DIR/proj"
    mkdir -p "$proj/.tasks/active" "$proj/.tasks/completed" "$proj/.context/working"
    cd "$proj"

    cat > "$proj/.tasks/active/T-RSGATE-D-fixture.md" <<'EOF'
---
id: T-RSGATE-D
name: "render task with bypass"
status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: ["web/static/app.css"]
created: 2026-05-16T08:00:00Z
last_update: 2026-05-16T08:00:00Z
---

# T-RSGATE-D

## Acceptance Criteria

### Agent
- [x] css updated

## Verification

true
EOF

    run env PROJECT_ROOT="$proj" "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" T-RSGATE-D \
        --status work-completed \
        --skip-acceptance-criteria --skip-verification --skip-recommendation --skip-rca \
        --skip-render-review "tiny CSS tweak, no visual impact"
    # Gate should not block — bypass logged
    ! echo "$output" | grep -q "ERROR: Cannot complete build task — touches render surface"
}

@test "T-1766/gate-e: render task with only [RUBBER-STAMP] Human AC still blocks (rubber-stamp != review)" {
    local proj="$TEST_TEMP_DIR/proj"
    mkdir -p "$proj/.tasks/active" "$proj/.tasks/completed" "$proj/.context/working"
    cd "$proj"

    cat > "$proj/.tasks/active/T-RSGATE-E-fixture.md" <<'EOF'
---
id: T-RSGATE-E
name: "render task with only rubber-stamp"
status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: ["web/templates/index.html"]
created: 2026-05-16T08:00:00Z
last_update: 2026-05-16T08:00:00Z
---

# T-RSGATE-E

## Acceptance Criteria

### Agent
- [x] template change

### Human
- [ ] [RUBBER-STAMP] click deploy button

## Verification

true
EOF

    run env PROJECT_ROOT="$proj" "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" T-RSGATE-E \
        --status work-completed \
        --skip-acceptance-criteria --skip-verification --skip-recommendation --skip-rca
    [ "$status" -ne 0 ]
    echo "$output" | grep -q "render surface"
}
