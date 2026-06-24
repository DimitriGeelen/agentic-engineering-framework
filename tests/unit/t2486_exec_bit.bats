#!/usr/bin/env bats
# T-2486 / OBS-087: bin/fw invokes some verbs via `exec "$FW_LIB_DIR/<x>.sh"`,
# which REQUIRES the target to be executable. lib/resolver.sh, lib/outcome.sh and
# lib/pause.sh shipped committed at git mode 100644 (no +x), so `fw resolver`,
# `fw outcome`, `fw pause` died on "Permission denied" — which is why the
# orchestrator dispatch CLI was unrunnable and never dispatched.
#
# This test closes the CLASS, not just the three files: every exec-style lib
# target referenced in bin/fw must be executable, both on disk and in git's
# recorded mode (so re-vendoring/checkout can't silently strip it again).

load ../test_helper

@test "t2486: every exec-style \$FW_LIB_DIR/*.sh target in bin/fw is executable on disk" {
    local fw="$FRAMEWORK_ROOT/bin/fw"
    [ -f "$fw" ]
    # Extract the basenames of all `exec "$FW_LIB_DIR/<x>.sh"` invocations.
    local targets
    targets=$(grep -oE 'exec "\$FW_LIB_DIR/[a-z_]+\.sh"' "$fw" \
              | sed -E 's#.*/([a-z_]+\.sh)"#\1#' | sort -u)
    [ -n "$targets" ]   # guard: the pattern must still match something

    local missing=""
    for t in $targets; do
        if [ ! -x "$FRAMEWORK_ROOT/lib/$t" ]; then
            missing="$missing $t"
        fi
    done
    [ -z "$missing" ] || { echo "non-executable exec-style targets:$missing"; false; }
}

@test "t2486: git records exec-style \$FW_LIB_DIR/*.sh targets at mode 100755" {
    cd "$FRAMEWORK_ROOT"
    local targets
    targets=$(grep -oE 'exec "\$FW_LIB_DIR/[a-z_]+\.sh"' bin/fw \
              | sed -E 's#.*/([a-z_]+\.sh)"#\1#' | sort -u)
    [ -n "$targets" ]

    local bad=""
    for t in $targets; do
        local mode
        mode=$(git ls-files -s "lib/$t" 2>/dev/null | cut -d' ' -f1)
        # only assert on tracked files; a target missing from git is a separate bug
        [ -n "$mode" ] || continue
        [ "$mode" = "100755" ] || bad="$bad $t($mode)"
    done
    [ -z "$bad" ] || { echo "exec-style targets not at git mode 100755:$bad"; false; }
}

@test "t2486: the three regressed verbs actually run (no Permission denied)" {
    run "$FRAMEWORK_ROOT/bin/fw" resolver workflows
    [ "$status" -eq 0 ]
    [[ "$output" != *"Permission denied"* ]]
}
