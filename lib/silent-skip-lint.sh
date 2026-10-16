#!/usr/bin/env bash
# T-4219: the Silent-Skip lint step of `fw test lint` (T-3217).
#
# fw_silent_skip_lint <framework_root>
#   Scans <framework_root>/tests/ for bats tests that skip silently.
#   rc 0 — clean, or NOT APPLICABLE: a vendored copy (.agentic-framework/) ships
#          no tests/, so there is nothing of the framework's to scan. Before
#          T-4219 that case read as "the scan examined nothing" and failed
#          `fw test lint` in every consumer.
#   rc 1 — silent skips found, or the scan examined nothing although tests/
#          exists (the linter's own exit 2): not a pass.
#   Prints its own section header and result line.

fw_silent_skip_lint() {
    local root="${1:?fw_silent_skip_lint: framework root required}"
    local linter="$root/tools/bats-silent-skip-lint.py"
    [ -f "$linter" ] || return 0
    echo ""
    echo "=== Silent-Skip Lint ==="
    if [ ! -d "$root/tests" ]; then
        echo "  NOT APPLICABLE  no tests/ in this framework copy (vendored) — nothing of the framework's to scan"
        return 0
    fi
    if python3 "$linter" "$root/tests/"; then
        echo "  OK  no silent skips"
        return 0
    fi
    # exit 2 means the scan examined nothing — a different failure from
    # "found silent skips", and not a pass.
    return 1
}
