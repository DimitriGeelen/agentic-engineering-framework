#!/usr/bin/env bats
# T-1946 — Structural lint: bin/fw must contain ZERO heredoc-in-cmd-substitution
# patterns. Third layer of L-332 / L-408 prevention (after the learnings and the
# T-1945 PreToolUse edit-time WARN).
#
# This is the strongest layer because it fails in CI/pre-push regardless of
# whether the agent saw / heeded the WARN. A future edit reintroducing the
# pattern cannot ship while this test is green.

setup() {
    FRAMEWORK_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    BIN_FW="$FRAMEWORK_ROOT/bin/fw"
    [ -f "$BIN_FW" ] || skip "bin/fw not found"
}

# Regex contract:
#   `\$\(`          opening of a command substitution
#   `[^)]*`         any chars not closing that cmd-sub on the same line
#   `<<['"]?[A-Z_]` start of a heredoc marker (uppercase tag)
#
# Hits only ACTUAL code (comment lines starting with `#` are excluded by the
# `grep -v '^\s*#'` filter so descriptive prose in headers doesn't false-positive).

@test "T-1946: bin/fw contains zero heredoc-in-command-substitution patterns" {
    matches=$(grep -nE "\\\$\\([^)]*<<['\"]?[A-Z_]" "$BIN_FW" | grep -v "^[^:]*:[[:space:]]*#" || true)
    if [ -n "$matches" ]; then
        echo "FAIL: bin/fw still contains heredoc-in-cmd-sub (L-332/L-408 violations):"
        echo "$matches"
        return 1
    fi
}

@test "T-1946: lint actually catches violations (synthetic positive test)" {
    # Create a temp file mimicking the L-332/L-408 anti-pattern, then run the
    # same regex against it. Must hit. Otherwise the bin/fw test above is
    # passing trivially and gives a false sense of safety.
    tmp=$(mktemp)
    cat > "$tmp" <<'SYNTHETIC'
#!/bin/bash
# normal line
foo=$(python3 - <<PY
print(1)
PY
)
SYNTHETIC
    matches=$(grep -nE "\\\$\\([^)]*<<['\"]?[A-Z_]" "$tmp" | grep -v "^[^:]*:[[:space:]]*#" || true)
    rm -f "$tmp"
    [ -n "$matches" ]
}

@test "T-1946: lint ignores comment-only references to the anti-pattern" {
    tmp=$(mktemp)
    cat > "$tmp" <<'CMT'
# This script used to have $( python3 - <<PY ... PY ) but no longer.
plain_code=true
CMT
    matches=$(grep -nE "\\\$\\([^)]*<<['\"]?[A-Z_]" "$tmp" | grep -v "^[^:]*:[[:space:]]*#" || true)
    rm -f "$tmp"
    [ -z "$matches" ]
}
