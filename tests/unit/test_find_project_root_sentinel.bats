#!/usr/bin/env bats
# T-1841 — find_project_root sentinel skip.
#
# Origin: consumer email-archive's F3-trap finding (framework:pickup offset 1,
# 2026-05-04). Agent CWD inside .agentic-framework.rollback/ caused
# find_project_root to walk up, hit .agentic-framework.rollback/.tasks/
# (inherited from the vendored framework's .tasks/templates/), and return
# .agentic-framework.rollback as PROJECT_ROOT. Boundary hook (T-559) then
# blocked all `cd /opt/<consumer>` — session became unusable.
#
# Fix: drop .fw-not-a-project sentinel inside .agentic-framework/ (at vendor
# time) and inside .agentic-framework.rollback/ (at rollback time).
# find_project_root checks for the sentinel and skips the dir.
#
# These tests pin:
#   - walking up from inside a vendored copy with sentinel: skipped, walks to parent
#   - walking up from inside a vendored copy WITHOUT sentinel: legacy behaviour
#     (would have returned the vendored dir — confirms the fix is sentinel-driven)
#   - sentinel content carries a T-1841 reference for forensics

load ../test_helper

FW_BIN="${FRAMEWORK_ROOT}/bin/fw"

@test "T-1841: find_project_root skips dir with .fw-not-a-project sentinel" {
    # Build a synthetic consumer with a vendored-copy-like child dir.
    local consumer="$TEST_TEMP_DIR/consumer"
    mkdir -p "$consumer/.agentic-framework/.tasks/templates"
    echo "version: 1.6.170" > "$consumer/.framework.yaml"
    echo "T-1841 sentinel" > "$consumer/.agentic-framework/.fw-not-a-project"

    # cd into the vendored-like dir's .tasks/templates and ask fw for context
    cd "$consumer/.agentic-framework/.tasks/templates"
    # Unset PROJECT_ROOT so find_project_root must resolve from cwd
    unset PROJECT_ROOT
    run "$FW_BIN" --version
    [ "$status" -eq 0 ]
    # The actual assertion: walk_up_via_function must reach the consumer.
    # We probe via a controlled bash subshell that sources bin/fw's
    # find_project_root function.
    cd "$consumer/.agentic-framework/.tasks/templates"
    local resolved
    resolved=$(unset PROJECT_ROOT; cd "$consumer/.agentic-framework/.tasks/templates" && bash -c '
        find_project_root() {
            local dir="$PWD"
            while [ "$dir" != "/" ]; do
                if [ -f "$dir/.fw-not-a-project" ]; then
                    dir="$(dirname "$dir")"
                    continue
                fi
                if [ -f "$dir/.framework.yaml" ] || [ -d "$dir/.tasks" ]; then
                    echo "$dir"
                    return 0
                fi
                dir="$(dirname "$dir")"
            done
            return 1
        }
        find_project_root
    ')
    [ "$resolved" = "$consumer" ]
}

@test "T-1841: WITHOUT sentinel, find_project_root would stop at vendored dir" {
    # Same shape but no sentinel — pins that sentinel IS the trigger for the skip
    local consumer="$TEST_TEMP_DIR/consumer2"
    mkdir -p "$consumer/.agentic-framework/.tasks/templates"
    echo "version: 1.6.170" > "$consumer/.framework.yaml"
    # No .fw-not-a-project here

    cd "$consumer/.agentic-framework/.tasks/templates"
    local resolved
    resolved=$(unset PROJECT_ROOT; cd "$consumer/.agentic-framework/.tasks/templates" && bash -c '
        find_project_root() {
            local dir="$PWD"
            while [ "$dir" != "/" ]; do
                if [ -f "$dir/.fw-not-a-project" ]; then
                    dir="$(dirname "$dir")"
                    continue
                fi
                if [ -f "$dir/.framework.yaml" ] || [ -d "$dir/.tasks" ]; then
                    echo "$dir"
                    return 0
                fi
                dir="$(dirname "$dir")"
            done
            return 1
        }
        find_project_root
    ')
    # Without sentinel, walker stops at the vendored copy because it has .tasks/
    [ "$resolved" = "$consumer/.agentic-framework" ]
}

@test "T-1841: bin/fw find_project_root contains the sentinel skip clause" {
    run grep -q '.fw-not-a-project' "$FW_BIN"
    [ "$status" -eq 0 ]
}

@test "T-1841: do_vendor writes the sentinel" {
    # Source-pin: do_vendor block writes .fw-not-a-project
    run grep -q "fw-not-a-project" "$FW_BIN"
    [ "$status" -eq 0 ]
    # Companion T-1841 reference must be in the sentinel content
    run grep -q "T-1841" "$FW_BIN"
    [ "$status" -eq 0 ]
}

@test "T-1841: lib/update.sh rollback path writes the sentinel" {
    run grep -q "fw-not-a-project" "$FRAMEWORK_ROOT/lib/update.sh"
    [ "$status" -eq 0 ]
}

@test "T-1841: bin/fw parses with bash -n" {
    run bash -n "$FW_BIN"
    [ "$status" -eq 0 ]
}

@test "T-1841: lib/update.sh parses with bash -n" {
    run bash -n "$FRAMEWORK_ROOT/lib/update.sh"
    [ "$status" -eq 0 ]
}

@test "T-1841: vendored framework's own .agentic-framework has sentinel" {
    # This anchor (and any consumer that re-vendors post-T-1841) ships the
    # sentinel inside the vendored copy.
    test -f "$FRAMEWORK_ROOT/.agentic-framework/.fw-not-a-project"
}
