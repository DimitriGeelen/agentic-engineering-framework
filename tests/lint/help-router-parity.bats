#!/usr/bin/env bats
# T-1185: Invariant test — show_help() must list every top-level router command
# Prevents G-043 class bugs: new commands added to the case block but forgotten in help.

setup() {
    FW="$BATS_TEST_DIRNAME/../../bin/fw"
}

@test "every top-level router command appears in show_help" {
    # Extract top-level case entries (indented exactly 4 spaces before the closing paren)
    router_cmds=$(awk '/^case "\$cmd" in/,/^esac/' "$FW" \
        | grep -E '^\s{4}[a-z][-a-z0-9|]+\)' \
        | sed 's/[[:space:]]*)//' | sed 's/^[[:space:]]*//' \
        | tr '|' '\n' | grep -v '^-' | sort -u)

    # Extract commands mentioned in show_help (both GREEN and YELLOW colored)
    help_cmds=$(sed -n '/^show_help()/,/^}/p' "$FW" \
        | grep -oP '\$\{(GREEN|YELLOW)\}([a-z][-a-z0-9]+)' \
        | sed 's/\${GREEN}//;s/\${YELLOW}//' | sort -u)

    missing=""
    for cmd in $router_cmds; do
        if ! echo "$help_cmds" | grep -qx "$cmd"; then
            missing="$missing $cmd"
        fi
    done

    if [ -n "$missing" ]; then
        echo "Commands in router but NOT in show_help():$missing"
        echo ""
        echo "Add these to show_help() in bin/fw"
        false
    fi
}

@test "show_help references only existing router commands" {
    router_cmds=$(awk '/^case "\$cmd" in/,/^esac/' "$FW" \
        | grep -E '^\s{4}[a-z][-a-z0-9|]+\)' \
        | sed 's/[[:space:]]*)//' | sed 's/^[[:space:]]*//' \
        | tr '|' '\n' | grep -v '^-' | sort -u)

    # Include help and version as pseudo-commands (handled by -h/--help/-v/--version)
    router_cmds="$router_cmds
help
version"
    router_cmds=$(echo "$router_cmds" | sort -u)

    help_cmds=$(sed -n '/^show_help()/,/^}/p' "$FW" \
        | grep -oP '\$\{(GREEN|YELLOW)\}([a-z][-a-z0-9]+)' \
        | sed 's/\${GREEN}//;s/\${YELLOW}//' | sort -u)

    # Exclude subcommand-style entries that appear as "fw task list" etc.
    phantom=""
    for cmd in $help_cmds; do
        if ! echo "$router_cmds" | grep -qx "$cmd"; then
            # Check if it's a known subcommand (like "list", "show", "status")
            # These appear in help as "fw task list" but aren't top-level
            case "$cmd" in
                list|show|status|predict|bump|check|sync|baseline|semantic|hybrid|pending|report) continue ;;
            esac
            phantom="$phantom $cmd"
        fi
    done

    if [ -n "$phantom" ]; then
        echo "Commands in show_help() but NOT in router:$phantom"
        echo ""
        echo "Either add to router or remove from help"
        false
    fi
}
