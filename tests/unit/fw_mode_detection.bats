#!/usr/bin/env bats
# T-1346-B2 / T-1406: fw doctor and fw version disclose active framework mode.
# Three resolution paths covered:
#   - framework-repo: invoking bin/fw from inside the framework repo itself
#   - vendored: invoking bin/fw from a consumer project with .agentic-framework/
#   - global: invoking bin/fw from a consumer project where fw lives outside it

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
FW="$FRAMEWORK_ROOT/bin/fw"

setup() {
    TMP_PROJ=$(mktemp -d)
    cd "$TMP_PROJ"
    git init -q
    git config user.email "test@test"
    git config user.name "test"
    mkdir -p .tasks/active .tasks/completed .tasks/templates .context/working
    touch .tasks/templates/zzz-default.md
    cat > .framework.yaml <<EOF
version: "test"
framework_path: $FRAMEWORK_ROOT
EOF
    git add -A
    git commit -q -m "T-1406: baseline"
}

teardown() {
    cd /
    rm -rf "$TMP_PROJ"
}

@test "T-1406: fw version prints Mode line in framework-repo mode" {
    cd "$FRAMEWORK_ROOT"
    run "$FW" version
    [ "$status" -eq 0 ]
    [[ "$output" == *"Mode:"*"framework-repo"* ]]
}

@test "T-1406: fw doctor prints Active mode line in framework-repo mode" {
    cd "$FRAMEWORK_ROOT"
    run "$FW" doctor
    [ "$status" -le 1 ]
    [[ "$output" == *"Active mode: framework-repo"* ]]
}

@test "T-1406: fw version reports global mode for consumer project without vendored copy" {
    cd "$TMP_PROJ"
    PROJECT_ROOT="$TMP_PROJ" run "$FW" version
    [ "$status" -eq 0 ]
    [[ "$output" == *"Mode:"*"global"* ]]
}

@test "T-1406: fw version reports vendored mode when .agentic-framework/ present and selected" {
    cd "$TMP_PROJ"
    # Simulate a vendored framework copy by symlinking the real framework
    ln -s "$FRAMEWORK_ROOT" .agentic-framework
    PROJECT_ROOT="$TMP_PROJ" run "$FW" version
    [ "$status" -eq 0 ]
    [[ "$output" == *"Mode:"*"vendored"* ]]
}

@test "T-1406: fw doctor warns when global is active but vendored exists" {
    cd "$TMP_PROJ"
    mkdir -p .agentic-framework
    # Make .agentic-framework look like a framework but force resolve to global
    # by NOT copying FRAMEWORK.md (so vendored rule misses, global wins via FW path)
    PROJECT_ROOT="$TMP_PROJ" run "$FW" doctor
    [[ "$output" == *"Active mode: global"* ]]
}

@test "T-1346-B2: _detect_fw_mode returns 'unknown' when FRAMEWORK_ROOT empty" {
    # Sourced unit-level check: load the function and call it directly
    cd "$FRAMEWORK_ROOT"
    result=$(FRAMEWORK_ROOT= PROJECT_ROOT= bash -c '
        source "'"$FW"'" --help >/dev/null 2>&1 || true
        # The script exits early on --help so source it via function extraction
        eval "$(sed -n "/^_detect_fw_mode()/,/^}$/p" "'"$FW"'")"
        FRAMEWORK_ROOT="" PROJECT_ROOT="" _detect_fw_mode
    ')
    [ "$result" = "unknown" ]
}
