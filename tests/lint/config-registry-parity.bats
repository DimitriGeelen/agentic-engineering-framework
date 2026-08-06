#!/usr/bin/env bats
# T-1187: Invariant test — config registry parity across 3 sources
# lib/config.sh FW_CONFIG_REGISTRY is the canonical source.
# web/blueprints/config.py SETTINGS and CLAUDE.md config table must match.

setup() {
    FW_ROOT="$BATS_TEST_DIRNAME/../.."
}

@test "lib/config.sh and web/blueprints/config.py have the same config keys" {
    # Extract keys from lib/config.sh FW_CONFIG_REGISTRY
    bash_keys=$(grep -oP '^\s+"([A-Z0-9_]+)\|' "$FW_ROOT/lib/config.sh" \
        | sed 's/.*"//;s/|//' | sort)

    # Extract keys from web/blueprints/config.py SETTINGS
    py_keys=$(grep -oP '^\s+\("([A-Z0-9_]+)"' "$FW_ROOT/web/blueprints/config.py" \
        | sed 's/.*("//;s/"//' | sort)

    if [ "$bash_keys" != "$py_keys" ]; then
        echo "Keys differ between lib/config.sh and web/blueprints/config.py:"
        echo ""
        echo "In config.sh but not config.py:"
        comm -23 <(echo "$bash_keys") <(echo "$py_keys")
        echo ""
        echo "In config.py but not config.sh:"
        comm -13 <(echo "$bash_keys") <(echo "$py_keys")
        false
    fi
}

# T-2841: this test used to require EVERY registry key to appear in CLAUDE.md.
# That contradicted the document it tested: CLAUDE.md §Configuration states its
# table lists "Agent-relevant settings" and points at `fw config list` for the
# rest. 17 of 22 keys were absent and the test had been red for months, unread,
# because nothing ran tests/lint on a schedule until T-2837.
#
# The subset is deliberate. CLAUDE.md is loaded into every agent context on every
# session; internal tuning constants (KEYLOCK_TIMEOUT, TOKEN_CHECK_INTERVAL,
# CALL_WARN/URGENT/CRITICAL …) are a permanent context cost for a lookup that
# `fw config list` answers on demand. Nothing is undocumented — every key carries
# an inline description in lib/config.sh and appears on Watchtower /config
# (T-2838). Only the duplication is declined.
#
# So the assertion is INVERTED to the direction that catches real rot: CLAUDE.md
# must not reference an FW_ key that no longer exists. A stale doc pointing at a
# removed setting is worse than an undocumented live one, because it reads as
# authoritative. That direction was previously untested.
#
# Do not "restore" the strict form without also changing CLAUDE.md's stated
# design — they must agree about what the table is for.
@test "CLAUDE.md references no config key that lib/config.sh does not define" {
    # Canonical registry keys.
    bash_keys=$(grep -oP '^\s+"([A-Z0-9_]+)\|' "$FW_ROOT/lib/config.sh" \
        | sed 's/.*"//;s/|//' | sort -u)

    # Every `FW_<KEY>` mention anywhere in CLAUDE.md.
    # T-2841: the character class includes digits. It was [A-Z_]+ and silently
    # skipped any key containing one — found by a probe key ending in a task
    # number, which the check ignored entirely and read as a clean pass. No
    # current key has a digit, so this closes the hole before it costs anything.
    claude_keys=$(grep -oP '\`FW_([A-Z0-9_]+)\`' "$FW_ROOT/CLAUDE.md" \
        | sed 's/`FW_//;s/`//' \
        | sort -u)

    # FW_-prefixed names that are documented behaviour flags rather than entries
    # in FW_CONFIG_REGISTRY (single-use gate bypasses, trusted-caller signals).
    # They are legitimately in CLAUDE.md and legitimately not in the registry.
    # CONFIG_REGISTRY is the name of the registry array itself (FW_CONFIG_REGISTRY),
    # not a setting stored in it. Caught immediately: the CLAUDE.md paragraph
    # describing this very test mentioned the array in backticks and went red.
    allow_non_registry='^(ALLOW_|SKIP_|I_AM_|SWITCH_FOCUS$|INCEPTION_PRE_GATED$|REVIEWER_IN_DISPATCH$|DOCTOR_HOOK_EXERCISE$|INTEGRATION_IN_PROGRESS$|CONFIG_REGISTRY$)'

    phantom=""
    for key in $claude_keys; do
        echo "$key" | grep -qE "$allow_non_registry" && continue
        if ! echo "$bash_keys" | grep -qx "$key"; then
            phantom="$phantom $key"
        fi
    done

    if [ -n "$phantom" ]; then
        echo "CLAUDE.md documents FW_ key(s) that lib/config.sh does not define:$phantom"
        echo ""
        echo "Either add them to FW_CONFIG_REGISTRY in lib/config.sh, or remove the"
        echo "stale reference from CLAUDE.md. A documented setting that does not"
        echo "exist reads as authoritative and is worse than an undocumented one."
        false
    fi
}

@test "config registry key count matches across sources" {
    bash_count=$(grep -cP '^\s+"[A-Z0-9_]+\|' "$FW_ROOT/lib/config.sh")
    py_count=$(grep -cP '^\s+\("[A-Z0-9_]+"' "$FW_ROOT/web/blueprints/config.py")

    if [ "$bash_count" != "$py_count" ]; then
        echo "Key count mismatch: config.sh=$bash_count config.py=$py_count"
        false
    fi
}
