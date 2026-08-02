#!/bin/bash
# lib/verification-port.sh — hard-coded Watchtower port detection (T-2732)
#
# Single definition of the predicate. Sourced by:
#   - agents/task-create/update-task.sh  (the P-011 close gate)
#   - tests/unit/verification_port_hardcode.bats
#
# It lives here rather than inline in the gate because the regression suite has
# to run the REAL predicate over the real corpus. A test that re-types the
# producer's expression into a local helper can only ever check the sites its
# author already knew about (L-533, from the T-2729/T-2730/T-2731 escape family).
#
# Usage: source "$FRAMEWORK_ROOT/lib/verification-port.sh"
#        find_port_literals "$text"   # prints offending lines, one per line

[[ -n "${_FW_VERIFICATION_PORT_LOADED:-}" ]] && return 0
_FW_VERIFICATION_PORT_LOADED=1

# Print every line of $1 that reaches for a literal port-3000 URL without
# resolving the port on the same line. Prints nothing when clean. Always exits 0
# (pipefail-safe, L-302) — callers decide what a non-empty result means.
#
# The discriminator is NOT "mentions 3000". CLAUDE.md §Watchtower Port explicitly
# sanctions the defensive fallback
#     WT_URL=$(bin/fw watchtower url 2>/dev/null || echo "http://localhost:3000")
# because it asks where the port actually is first and only then falls back. What
# is banned is reaching for 3000 without asking. So a line is an offender when it
# contains a port-3000 URL literal AND no port-resolution idiom.
#
# Fixed on 3000 by design. Resolving "the port that happens to be live" and
# flagging that instead would make the verdict depend on host state at run time —
# the same defect class the gate exists to catch.
find_port_literals() {
    printf '%s\n' "$1" \
        | grep -E 'https?://(localhost|127\.0\.0\.1|0\.0\.0\.0):3000' \
        | grep -vE 'fw[[:space:]]+watchtower[[:space:]]+(url|port)|watchtower\.(url|port)|fw[[:space:]]+config[[:space:]]+get[[:space:]]+PORT|\$\{?(WT_URL|WURL|WT_PORT)' \
        || true
}

# Extract the ## Verification block of a task file, stripped of comments, blank
# lines and fences — the same shape update-task.sh executes.
extract_verification_block() {
    local file="$1"
    sed -n '/^## Verification/,/^## /p' "$file" 2>/dev/null \
        | sed '$d' | tail -n +2 \
        | grep -vE '^\s*$|^\s*#|^\s*```' || true
}
