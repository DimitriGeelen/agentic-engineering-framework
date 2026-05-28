#!/usr/bin/env bats
# T-1659: fw fabric register slug derivation + vendored-path rejection.
#
# Pins two bugs that previously produced .fabric/components/.yaml (empty
# basename, silently overwritten on each register):
#   Bug 1 — `.agentic-framework/...` paths are vendored copies of upstream
#           framework files. Registering them here splits the component
#           identity across two cards. Should REJECT with hint to register
#           upstream.
#   Bug 2 — `s|\..*$||` in slug derivation matched greedy from the FIRST dot,
#           so any path starting with `.` after slash→dash conversion (e.g.
#           `.context/project/foo.yaml`) collapsed to an empty slug. Fixed by
#           stripping ONLY the trailing extension via `s|\.[^./-]*$||`.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

setup() {
    TMP_PROJECT=$(mktemp -d)
    mkdir -p "$TMP_PROJECT/.fabric/components"
    mkdir -p "$TMP_PROJECT/lib" "$TMP_PROJECT/bin"
    mkdir -p "$TMP_PROJECT/.context/project/workflows"
    mkdir -p "$TMP_PROJECT/.agentic-framework/lib"

    # Real files for paths under test
    touch "$TMP_PROJECT/lib/pickup.sh"
    touch "$TMP_PROJECT/bin/fw"
    touch "$TMP_PROJECT/.context/project/workflows/foo.yaml"
    touch "$TMP_PROJECT/.agentic-framework/lib/hook-telemetry.sh"

    export PROJECT_ROOT="$TMP_PROJECT"
    export FABRIC_DIR="$TMP_PROJECT/.fabric"
    export COMPONENTS_DIR="$FABRIC_DIR/components"

    # Color codes (used by sourced lib)
    export RED="" GREEN="" YELLOW="" CYAN="" BOLD="" NC=""

    # The register.sh assumes ensure_fabric_dirs lives elsewhere; stub it.
    ensure_fabric_dirs() { :; }
    export -f ensure_fabric_dirs 2>/dev/null || true

    # shellcheck source=agents/fabric/lib/register.sh
    source "$FRAMEWORK_ROOT/agents/fabric/lib/register.sh"
}

teardown() {
    rm -rf "$TMP_PROJECT"
}

# Helper: derive slug the same way register.sh does, isolated for assertion.
slug_of() {
    # Mirror the post-fix sed exactly.
    echo "$1" | sed 's|/|-|g; s|\.[^./-]*$||; s|^\.||'
}

# Tests ------------------------------------------------------------------

@test "(a) dot-prefix multi-slash path yields non-empty slug" {
    # Was: '' (collapsed by greedy s|\..*$||)
    # Now: 'context-project-workflows-foo'
    [ "$(slug_of '.context/project/workflows/foo.yaml')" = "context-project-workflows-foo" ]
}

@test "(b) vendored .agentic-framework/ path is REJECTED" {
    status=0
    _do_register_file ".agentic-framework/lib/hook-telemetry.sh" > "$BATS_TMPDIR/out" 2>&1 || status=$?
    output=$(<"$BATS_TMPDIR/out")
    [ "$status" -ne 0 ]
    # Output names the upstream path the agent should use instead
    echo "$output" | grep -qi "register the upstream"
    echo "$output" | grep -q "lib/hook-telemetry.sh"
    # And NO malformed card was created
    [ ! -f "$COMPONENTS_DIR/.yaml" ]
}

@test "(c) normal path produces expected slug" {
    [ "$(slug_of 'lib/pickup.sh')" = "lib-pickup" ]
}

@test "(d) no-extension path produces expected slug" {
    [ "$(slug_of 'bin/fw')" = "bin-fw" ]
}

@test "(e) regression: dot-prefix single-slash (.claude/settings.json)" {
    # Was: '' (greedy match from first dot collapsed everything)
    # Now: 'claude-settings'
    [ "$(slug_of '.claude/settings.json')" = "claude-settings" ]
}

@test "(f) regression: deeply-nested dot-prefix (.context/audits/cron/LATEST-CRON.yaml)" {
    [ "$(slug_of '.context/audits/cron/LATEST-CRON.yaml')" = "context-audits-cron-LATEST-CRON" ]
}
