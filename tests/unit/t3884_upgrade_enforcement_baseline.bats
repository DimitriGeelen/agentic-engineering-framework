#!/usr/bin/env bats
# T-3884: fw upgrade step [10/10] said "Enforcement baseline exists" after step 5
# had rewritten .claude/settings.json, and the next `fw doctor` FAILed
# "Enforcement baseline CHANGED" (ring20-manager, 1.8.0 -> 1.8.2). The baseline
# guards against hook tampering, so the fix must not launder a drift that
# existed BEFORE the upgrade: refresh only when it matched before.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    FWROOT="${BATS_TEST_DIRNAME}/../.."
    # the three helpers are top-level functions in lib/upgrade.sh
    eval "$(awk '/^_ef_hooks_hash\(\) \{/{p=1} p{print} /^_ef_step10_action\(\) \{/{q=1} q&&/^\}/{exit}' "$FWROOT/lib/upgrade.sh")"
    P="$TEST_TEMP_DIR/p"
    mkdir -p "$P/.claude" "$P/.context/project"
    # a real project: without .framework.yaml bin/fw would auto-init it first
    printf 'project_name: p\n' > "$P/.framework.yaml"
    printf '%s' '{"hooks":{"Stop":[{"matcher":"","hooks":[{"type":"command","command":"a"}]}]}}' > "$P/.claude/settings.json"
}

_baseline_now() { _ef_hooks_hash "$P/.claude/settings.json" > "$P/.context/project/enforcement-baseline.sha256"; }
_rewrite_hooks() { printf '%s' '{"hooks":{"Stop":[{"matcher":"","hooks":[{"type":"command","command":"b"}]}]}}' > "$P/.claude/settings.json"; }

@test "t3884: the hash matches what 'fw enforcement baseline' writes" {
    run bash -c "cd '$P' && PROJECT_ROOT='$P' timeout 60 '$FWROOT/bin/fw' enforcement baseline >/dev/null </dev/null && cat .context/project/enforcement-baseline.sha256"
    [ "$output" = "$(_ef_hooks_hash "$P/.claude/settings.json")" ]
}

@test "t3884: states — missing, match, changed, nosettings" {
    run _ef_baseline_state "$P";  [ "$output" = missing ]
    _baseline_now
    run _ef_baseline_state "$P";  [ "$output" = match ]
    _rewrite_hooks
    run _ef_baseline_state "$P";  [ "$output" = changed ]
    rm "$P/.claude/settings.json"
    run _ef_baseline_state "$P";  [ "$output" = nosettings ]
}

@test "t3884: THE FIELD CASE — matched before, upgrade rewrote hooks → refresh" {
    _baseline_now; pre=$(_ef_baseline_state "$P"); _rewrite_hooks
    run _ef_step10_action "$pre" "$(_ef_baseline_state "$P")"
    [ "$output" = refresh ]
}

@test "t3884: already CHANGED before the upgrade → warn-drift, never refresh (no laundering)" {
    _baseline_now; _rewrite_hooks; pre=$(_ef_baseline_state "$P")
    run _ef_step10_action "$pre" "$(_ef_baseline_state "$P")"
    [ "$output" = warn-drift ]
}

@test "t3884: unchanged → ok; missing → create; no settings → skip" {
    _baseline_now
    run _ef_step10_action match match;        [ "$output" = ok ]
    run _ef_step10_action missing missing;    [ "$output" = create ]
    run _ef_step10_action nosettings nosettings; [ "$output" = skip ]
}

@test "t3884: step 10 no longer reports bare existence as OK" {
    run grep -c 'Enforcement baseline exists' "$FWROOT/lib/upgrade.sh"
    [ "$output" = "0" ]
    grep -q '_ef_pre_state=$(_ef_baseline_state "$target_dir")' "$FWROOT/lib/upgrade.sh"
}
