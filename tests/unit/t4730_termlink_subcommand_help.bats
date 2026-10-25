#!/usr/bin/env bats
# T-4730 — every `fw termlink` subcommand that parses options answers --help/-h with
# usage naming every option its parser accepts, and exits 0. Origin: the dispatch gate
# (check-agent-dispatch.sh) names `fw termlink dispatch --task --name --prompt`, but
# `fw termlink dispatch --help` died with "Unknown option: --help" (TermLink T-2981 2b).
#
# The subcommand list and each option list are read from termlink.sh itself, so a new
# subcommand parser, or a new flag without a usage line, fails here.

setup() {
    SCRIPT="${BATS_TEST_DIRNAME}/../../agents/termlink/termlink.sh"
    # Usage must not need the termlink binary: drop every PATH dir that holds one.
    local d p=""
    IFS=: read -ra _dirs <<< "$PATH"
    for d in "${_dirs[@]}"; do
        [ -x "$d/termlink" ] && continue
        p="${p:+$p:}$d"
    done
    NOTL_PATH="$p"
}

# Routed subcommand -> function, from the main routing case ("  dispatch) cmd_dispatch ...").
routes() {
    sed -n 's/^        \([a-z][a-z-]*\))[[:space:]]*\(cmd_[a-z_]*\) "\$@".*/\1 \2/p' "$SCRIPT"
}

# Options a function's `case "$1" in ... esac` parser accepts, one per line.
parser_opts() {
    sed -n "/^$1() {/,/^}/p" "$SCRIPT" \
        | sed -n '/case "\$1" in/,/esac/p' \
        | sed -n 's/^[[:space:]]*\(-[-a-z|]*\)).*/\1/p' \
        | tr '|' '\n'
}

# Subcommands whose parser has an option arm (these must all answer --help).
option_subcommands() {
    local sub fn
    while read -r sub fn; do
        [ -n "$(parser_opts "$fn")" ] && echo "$sub $fn"
    done < <(routes)
}

@test "routing table and parsers are found (guards the extraction itself)" {
    run routes
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '^dispatch cmd_dispatch$'
    run parser_opts cmd_dispatch
    echo "$output" | grep -qx -- '--prompt-file'
    echo "$output" | grep -qx -- '--review-seat'
    [ "$(option_subcommands | wc -l)" -ge 5 ]
}

@test "dispatch --help exits 0 without termlink on PATH and names the gate's hint flags" {
    run env PATH="$NOTL_PATH" bash "$SCRIPT" dispatch --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage: fw termlink dispatch"* ]]
    for f in --task --name --prompt; do
        echo "$output" | grep -q -- "$f "
    done
    ! echo "$output" | grep -q "Unknown option" || false
}

@test "every option-parsing subcommand answers --help and -h with exit 0" {
    local sub fn flag
    while read -r sub fn; do
        for flag in --help -h; do
            run env PATH="$NOTL_PATH" bash "$SCRIPT" "$sub" "$flag"
            if [ "$status" -ne 0 ] || [[ "$output" != *Usage:* ]]; then
                echo "fw termlink $sub $flag -> rc=$status: $output"
                return 1
            fi
        done
    done < <(option_subcommands)
}

@test "each subcommand's usage names every option its parser accepts" {
    local sub fn opt missing=""
    while read -r sub fn; do
        out=$(env PATH="$NOTL_PATH" bash "$SCRIPT" "$sub" --help 2>&1)
        while read -r opt; do
            grep -q -- "$opt" <<< "$out" || missing="$missing $sub:$opt"
        done < <(parser_opts "$fn")
    done < <(option_subcommands)
    [ -z "$missing" ] || { echo "options without a usage line:$missing"; return 1; }
}

@test "an unknown option still fails and points at --help" {
    run env PATH="$NOTL_PATH" bash "$SCRIPT" dispatch --no-such-flag
    [ "$status" -ne 0 ]
    [[ "$output" == *"Unknown option: --no-such-flag"* ]]
    [[ "$output" == *"--help"* ]]
}
