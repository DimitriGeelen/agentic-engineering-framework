#!/usr/bin/env bats
# T-1187: Invariant test — config registry parity across 3 sources
# lib/config.sh FW_CONFIG_REGISTRY is the canonical source.
# web/blueprints/config.py SETTINGS and CLAUDE.md config table must match.

setup() {
    FW_ROOT="$BATS_TEST_DIRNAME/../.."
}

@test "lib/config.sh and web/blueprints/config.py have the same config keys" {
    # Extract keys from lib/config.sh FW_CONFIG_REGISTRY
    bash_keys=$(grep -oP '^\s+"([A-Z_]+)\|' "$FW_ROOT/lib/config.sh" \
        | sed 's/.*"//;s/|//' | sort)

    # Extract keys from web/blueprints/config.py SETTINGS
    py_keys=$(grep -oP '^\s+\("([A-Z_]+)"' "$FW_ROOT/web/blueprints/config.py" \
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

@test "lib/config.sh and CLAUDE.md config table have the same config keys" {
    # Extract keys from lib/config.sh (canonical)
    bash_keys=$(grep -oP '^\s+"([A-Z_]+)\|' "$FW_ROOT/lib/config.sh" \
        | sed 's/.*"//;s/|//' | sort)

    # Extract FW_ env var names from CLAUDE.md config table
    # Table format: | Name | `FW_KEY` | `default` | description |
    claude_keys=$(grep -oP '\`FW_([A-Z_]+)\`' "$FW_ROOT/CLAUDE.md" \
        | sed 's/`FW_//;s/`//' \
        | sort -u)

    # Filter to only keys that are in the config table section (between "Configuration" and next "##")
    # For simplicity, just check that every bash key has a FW_ version in CLAUDE.md
    missing=""
    for key in $bash_keys; do
        if ! echo "$claude_keys" | grep -qx "$key"; then
            missing="$missing $key"
        fi
    done

    if [ -n "$missing" ]; then
        echo "Keys in lib/config.sh but NOT in CLAUDE.md config table:$missing"
        echo ""
        echo "Add FW_<KEY> entries to the Configuration table in CLAUDE.md"
        false
    fi
}

@test "config registry key count matches across sources" {
    bash_count=$(grep -cP '^\s+"[A-Z_]+\|' "$FW_ROOT/lib/config.sh")
    py_count=$(grep -cP '^\s+\("[A-Z_]+"' "$FW_ROOT/web/blueprints/config.py")

    if [ "$bash_count" != "$py_count" ]; then
        echo "Key count mismatch: config.sh=$bash_count config.py=$py_count"
        false
    fi
}
