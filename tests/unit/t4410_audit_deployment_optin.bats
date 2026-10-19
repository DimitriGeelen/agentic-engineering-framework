#!/usr/bin/env bats
# T-4410: the deployment section is opt-in (agents/audit/audit.sh, T-275 guard
# `[ -n "$SECTIONS" ] && should_run_section "deployment"`), so the help must not
# say the --section default is plain "all". Reported by 832 (their T-758).
#
# The default-run test points audit.sh at a synthetic project in a private temp
# root (PROJECT_ROOT override, same pattern as tests/unit/audit.bats T-4383), so
# it never reads the live repo or takes the live audit lock.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
AUDIT="$FRAMEWORK_ROOT/agents/audit/audit.sh"

_synthetic_project() {
    local root="$BATS_TEST_TMPDIR/synthetic-project"
    mkdir -p "$root/.context"
    git -C "$root" init -q
    printf 'hello\n' > "$root/README.md"
    git -C "$root" add README.md
    git -C "$root" -c user.email=t@example.invalid -c user.name=t commit -qm init
    echo "$root"
}

_audit_synthetic() {
    local root="$1"; shift
    env -u TASKS_DIR -u CONTEXT_DIR -u _FW_PATHS_DERIVED_BY \
        NTFY_ENABLED=false PROJECT_ROOT="$root" "$AUDIT" "$@"
}

@test "help names deployment as the exception to the --section default" {
    run "$AUDIT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"(default: all except deployment)"* ]]
    [[ "$output" != *"(default: all)"* ]]
}

@test "a run without --section does not run the deployment section (synthetic project)" {
    local root; root=$(_synthetic_project)
    run _audit_synthetic "$root"
    # Exit 2 is fine: an empty synthetic project FAILs real checks. The run
    # must have completed, or the absent marker would prove nothing.
    [ "$status" -le 2 ]
    [[ "$output" == *"=== END AUDIT ==="* ]]
    [[ "$output" != *"=== DEPLOYMENT CHECKS ==="* ]]
}

@test "control: --section deployment does run it (synthetic project)" {
    local root; root=$(_synthetic_project)
    run _audit_synthetic "$root" --section deployment
    echo "$output"
    [ "$status" -le 2 ]
    [[ "$output" == *"=== DEPLOYMENT CHECKS ==="* ]]
}
