#!/usr/bin/env bats
# T-1142: Invariant test — no --force in framework code calling update-task.sh
# Only the deprecated alias in update-task.sh itself is allowed.
# All other framework code must use narrow flags (--skip-sovereignty, etc.)

@test "lib/ does not pass --force to update-task.sh" {
    # Grep for lines calling update-task.sh with --force
    # Exclude comments (lines starting with #)
    violations=$(grep -rn 'update-task\.sh.*--force' lib/ 2>/dev/null | grep -v '^\s*#' || true)
    if [ -n "$violations" ]; then
        echo "Found --force in lib/ calling update-task.sh:"
        echo "$violations"
        echo ""
        echo "Use narrow flags instead: --skip-sovereignty, --skip-acceptance-criteria, --skip-verification, --skip-human-ownership"
        return 1
    fi
}

@test "agents/ does not pass --force to update-task.sh (except the deprecated alias definition)" {
    # Allow the --force|-f) case in update-task.sh itself (deprecated alias)
    # Block any other agent code from using --force with update-task.sh
    violations=$(grep -rn 'update-task\.sh.*--force' agents/ 2>/dev/null \
        | grep -v 'update-task\.sh:' \
        | grep -v '^\s*#' \
        | grep -v 'echo.*--force' \
        || true)
    if [ -n "$violations" ]; then
        echo "Found --force in agents/ calling update-task.sh:"
        echo "$violations"
        echo ""
        echo "Use narrow flags instead: --skip-sovereignty, --skip-acceptance-criteria, --skip-verification, --skip-human-ownership"
        return 1
    fi
}

@test "lib/inception.sh uses --skip-sovereignty not --force" {
    # The critical fix: inception decide must use narrow flag
    run grep 'update-task\.sh.*--force' lib/inception.sh
    [ "$status" -ne 0 ]  # grep should NOT find a match

    # And it SHOULD use --skip-sovereignty
    run grep 'update-task\.sh.*--skip-sovereignty' lib/inception.sh
    [ "$status" -eq 0 ]  # grep SHOULD find a match
}
