#!/usr/bin/env bats
# T-3168 (arc-012 F4) — .auto-restart-pending must not outlive its restart.
#
# The sentinel is the ONLY thing separating "the loop is continuing" from "someone
# opened a terminal". A leaked one steers a session that never asked to be steered,
# and with T-3166 that session no longer has a transcript to contradict it.

setup() {
    HOOK="${BATS_TEST_DIRNAME}/../../agents/context/post-compact-resume.sh"
    WRAPPER="${BATS_TEST_DIRNAME}/../../bin/claude-fw"
    # The gate under test is the sentinel branch, lifted from the real hook so that
    # editing the hook moves these assertions. Running the whole hook would drag in
    # handover generation, git, and the budget cache.
    ROOT="$(mktemp -d)"
    mkdir -p "$ROOT/.context/working"
    SENTINEL="$ROOT/.context/working/.auto-restart-pending"
}

teardown() {
    [ -n "${ROOT:-}" ] && rm -rf "$ROOT"
}

# Extract the `if [ "$SOURCE_TAG" = "startup" ]` block plus the TTL line above it.
extract_gate() {
    python3 - "$HOOK" <<'PY'
import sys
lines = open(sys.argv[1]).read().split('\n')
start = next(n for n, l in enumerate(lines)
             if l.startswith('RESTART_SENTINEL_TTL='))
depth = 0
for end in range(start, len(lines)):
    s = lines[end].strip()
    if s.startswith('if ') or s.startswith('if['):
        depth += 1
    elif s == 'fi':
        depth -= 1
        if depth == 0:
            break
print('\n'.join(lines[start:end + 1]))
PY
}

# Run the gate with a given source tag; echo REACHED if it fell through.
run_gate() {
    local gate
    gate="$(extract_gate)"
    bash -c "
RESTART_SENTINEL='$SENTINEL'
SOURCE_TAG='${1:-startup}'
${gate}
printf REACHED"
}

@test "the gate can be lifted from the real hook" {
    run extract_gate
    [ "$status" -eq 0 ]
    echo "$output" | grep -q 'RESTART_SENTINEL_TTL'
}

@test "a FRESH sentinel drives the continuation — the control leg" {
    # Without this, deleting the sentinel handling entirely would satisfy every
    # other test in this file.
    : > "$SENTINEL"
    run run_gate startup
    [ "$output" = "REACHED" ]
    [ ! -f "$SENTINEL" ]   # consumed
}

@test "no sentinel means cold start — the hook no-ops" {
    run run_gate startup
    [ "$output" != "REACHED" ]
}

@test "a STALE sentinel is treated as absent, not as a continuation" {
    : > "$SENTINEL"
    touch -d '2 hours ago' "$SENTINEL"
    run run_gate startup
    [ "$output" != "REACHED" ]
}

@test "a stale sentinel is removed, so it cannot mislead the NEXT start either" {
    : > "$SENTINEL"
    touch -d '2 hours ago' "$SENTINEL"
    run run_gate startup
    [ ! -f "$SENTINEL" ]
}

@test "compact and resume are unaffected by the sentinel gate" {
    : > "$SENTINEL"
    touch -d '2 hours ago' "$SENTINEL"
    run run_gate compact
    [ "$output" = "REACHED" ]
}

@test "claude-fw writes the sentinel AFTER the cancel window, not before" {
    # A cancelled countdown must leave nothing on disk. Asserted by ordering in the
    # source: the `sleep` that offers the cancel has to precede the write.
    sleep_line=$(grep -n '^        sleep 3$' "$WRAPPER" | head -1 | cut -d: -f1)
    write_line=$(grep -n 'restart_sentinel" 2>/dev/null' "$WRAPPER" | head -1 | cut -d: -f1)
    [ -n "$sleep_line" ]
    [ -n "$write_line" ]
    [ "$write_line" -gt "$sleep_line" ]
}

@test "both edited files parse" {
    bash -n "$HOOK"
    bash -n "$WRAPPER"
}
