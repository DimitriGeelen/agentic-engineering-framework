#!/usr/bin/env bats
# T-4424: the bare-from-consumer handoff replay (T-4405) kept '-*' words and dropped
# every other word as the positional target, so a value-taking flag added later
# would reach upstream without its value, and the value would be swallowed as the
# target. The flag grammar is now declared once in lib/upgrade.sh
# (_FW_UPGRADE_VALUE_FLAGS / _FW_UPGRADE_SWITCH_FLAGS); the parser and the replay
# both read it, and the replay refuses an undeclared flag.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    export FW_VERSION="1.5.0"
    export NO_COLOR=1
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/upgrade.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Print "LABEL ARITY" for each flag label of do_upgrade's argument parser, where
# ARITY is 2 when the branch shifts twice (takes a separate value), else 1.
_parser_labels() {
    awk '
        /^do_upgrade\(\) \{/ { in_fn = 1 }
        in_fn && /^        case \$1 in/ { in_case = 1; next }
        in_case && /^            -\*\)/ { exit }
        in_case && /^            -[^ ]*\)/ {
            line = $0; sub(/^ +/, "", line); lab = line; sub(/\).*/, "", lab)
            body = line
            if (line !~ /;;/) { getline nxt; body = body " " nxt }   # multi-line branch
            ar = (body ~ /shift 2/) ? 2 : 1
            n = split(lab, parts, "|")
            for (i = 1; i <= n; i++) print parts[i], ar
        }
    ' "$FRAMEWORK_ROOT/lib/upgrade.sh"
}

@test "T-4424: every parser flag is declared in exactly one list, with matching arity" {
    _parser_labels > "$TEST_TEMP_DIR/labels"
    [ "$(wc -l < "$TEST_TEMP_DIR/labels")" -ge 10 ]   # the extractor found the parser
    local lab ar base bad=""
    while read -r lab ar; do
        base="${lab%%=*}"
        if [[ "$lab" == *=\* ]]; then
            _upgrade_flag_in "$base" "${_FW_UPGRADE_VALUE_FLAGS[@]}" || bad+=" $lab(=* form, not a value flag)"
            continue
        fi
        if [ "$ar" = 2 ]; then
            _upgrade_flag_in "$lab" "${_FW_UPGRADE_VALUE_FLAGS[@]}" || bad+=" $lab(takes a value, undeclared)"
            ! _upgrade_flag_in "$lab" "${_FW_UPGRADE_SWITCH_FLAGS[@]}" || bad+=" $lab(declared as switch)"
        else
            _upgrade_flag_in "$lab" "${_FW_UPGRADE_SWITCH_FLAGS[@]}" || bad+=" $lab(switch, undeclared)"
            ! _upgrade_flag_in "$lab" "${_FW_UPGRADE_VALUE_FLAGS[@]}" || bad+=" $lab(declared as value)"
        fi
    done < "$TEST_TEMP_DIR/labels"
    [ -z "$bad" ] || { echo "parser/declaration mismatch:$bad"; false; }
}

@test "T-4424: a declared value flag keeps its value and the value is never taken as the target" {
    _FW_UPGRADE_VALUE_FLAGS+=(--future-value)
    _upgrade_build_replay /abs/target --strict --future-value some-word rel-target --future-value=x --force
    printf '%s\n' upgrade /abs/target --strict --future-value some-word --future-value=x --force > "$TEST_TEMP_DIR/want"
    printf '%s\n' "${_UPGRADE_REPLAY_ARGS[@]}" > "$TEST_TEMP_DIR/got"
    diff "$TEST_TEMP_DIR/want" "$TEST_TEMP_DIR/got"
}

@test "T-4424: --from-upstream and its value are dropped, both spellings" {
    _upgrade_build_replay /t --from-upstream /some/url --dry-run --from-upstream=/u2 tgt
    printf '%s\n' upgrade /t --dry-run > "$TEST_TEMP_DIR/want"
    printf '%s\n' "${_UPGRADE_REPLAY_ARGS[@]}" > "$TEST_TEMP_DIR/got"
    diff "$TEST_TEMP_DIR/want" "$TEST_TEMP_DIR/got"
}

@test "T-4424: an undeclared flag fails loudly instead of being split from its value" {
    run _upgrade_build_replay /t --strict --undeclared-thing value
    [ "$status" -ne 0 ]
    [[ "$output" == *"--undeclared-thing"* ]]
    [[ "$output" == *"_FW_UPGRADE_VALUE_FLAGS"* ]]
    run _upgrade_build_replay /t --undeclared=v
    [ "$status" -ne 0 ]
    [[ "$output" == *"--undeclared"* ]]
}

@test "T-4424: a value flag with no value fails fast in the parser (no infinite loop)" {
    run timeout 10 bash -c 'source "$1/lib/colors.sh"; source "$1/lib/upgrade.sh"; do_upgrade --dry-run --from-upstream' _ "$FRAMEWORK_ROOT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"--from-upstream needs a value"* ]]
}
