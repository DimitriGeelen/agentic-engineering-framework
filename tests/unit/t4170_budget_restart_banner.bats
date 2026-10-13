#!/usr/bin/env bats
# T-4170 (dimitri-mint-dev P-008) — a budget restart must not look like a crash:
# a banner before the terminator ends claude, and the reason on relaunch.

setup() {
    FRAMEWORK_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    CFW="$FRAMEWORK_ROOT/bin/claude-fw"
    T="$(mktemp -d)"
    ROOT="$T/proj"
    mkdir -p "$ROOT/.context/handovers" "$ROOT/.context/working"
    printf -- '---\nsession_id: S-2026-1013-0001\n---\n' > "$ROOT/.context/handovers/LATEST.md"
}

teardown() { rm -rf "$T"; }

@test "T-4170: _budget_end_banner names reason, handover id and countdown" {
    eval "$(awk '/^_handover_id\(\) \{/,/^}/' "$CFW")"
    eval "$(awk '/^_budget_end_banner\(\) \{/,/^}/' "$CFW")"
    run bash -c "$(declare -f _handover_id _budget_end_banner); _budget_end_banner '$ROOT' 7 2>&1"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "CONTEXT BUDGET CRITICAL"
    echo "$output" | grep -q "NOT a crash"
    echo "$output" | grep -q "S-2026-1013-0001"
    echo "$output" | grep -q "Ending in 7s"
}

@test "T-4170: the terminator prints the banner before it kills and honours the countdown" {
    grep -q '_budget_end_banner "\$root" "\$banner"' "$CFW"
    # the banner call sits before the first kill -TERM of the terminator
    b=$(grep -n '_budget_end_banner "\$root" "\$banner"' "$CFW" | head -1 | cut -d: -f1)
    k=$(awk -v b="$b" 'NR>b && /kill -TERM "\$p"/ {print NR; exit}' "$CFW")
    [ -n "$k" ] && [ "$k" -gt "$b" ]
    sed -n "${b},${k}p" "$CFW" | grep -q 'sleep "\$banner"'
}

@test "T-4170: the relaunch output states the reason and the handover id" {
    grep -q 'previous session was ended on purpose, not a crash' "$CFW"
    grep -q 'Handover: \$(_handover_id ' "$CFW"
}
