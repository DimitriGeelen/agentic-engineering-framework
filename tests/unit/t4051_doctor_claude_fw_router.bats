#!/usr/bin/env bats
# T-4051: `fw doctor`'s claude-fw drift check must compare an on-PATH T-2854 ROUTER
# against bin/claude-fw-router, not bin/claude-fw.
#
# Running the whole `fw doctor` takes minutes, so the test lifts the REAL drift-check
# block out of bin/fw (from `local _cfw_src=` through the SKIP branch's closing `fi`)
# and runs it in a function with a temp PATH. It exercises the shipped code, not a copy.

setup() {
    ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TMP="$(mktemp -d)"
    mkdir -p "$TMP/path" "$TMP/tools" "$TMP/fwroot/bin"
    # The host may carry its own claude-fw in /usr/bin: expose only the tools the block uses.
    for t in readlink cmp head grep cat; do ln -s "$(command -v $t)" "$TMP/tools/$t"; done
    cp "$ROOT/bin/claude-fw" "$ROOT/bin/claude-fw-router" "$TMP/fwroot/bin/"
    awk '/local _cfw_src=/{p=1} p{print} p&&/claude-fw not on PATH/{getline; print; exit}' \
        "$ROOT/bin/fw" > "$TMP/block.sh"
    {
        echo 'YELLOW=; GREEN=; CYAN=; NC=; warnings=0'
        echo "FRAMEWORK_ROOT='$TMP/fwroot'"
        echo 'check() {'
        cat "$TMP/block.sh"
        echo '}'
        echo 'check; echo "warnings=$warnings"'
    } > "$TMP/harness.sh"
}

teardown() { rm -rf "$TMP"; }

run_check() { run env PATH="$TMP/path:$TMP/tools" "$BASH" "$TMP/harness.sh"; }

@test "harness lifted the real block" {
    grep -q '_cfw_ref' "$TMP/block.sh"
    grep -q 'claude-fw not on PATH' "$TMP/block.sh"
}

@test "(a) router identical to repo router: no WARN, no cp of bin/claude-fw" {
    cp "$TMP/fwroot/bin/claude-fw-router" "$TMP/path/claude-fw"; chmod +x "$TMP/path/claude-fw"
    run_check
    [ "$status" -eq 0 ]
    [[ "$output" != *WARN* ]]
    [[ "$output" != *"cp \"$TMP/fwroot/bin/claude-fw\""* ]]
    [[ "$output" == *"matches repo source"* ]]
    [[ "$output" == *"warnings=0"* ]]
}

@test "(b) drifted router: WARN naming the router as refresh source" {
    { cat "$TMP/fwroot/bin/claude-fw-router"; echo "# local edit"; } > "$TMP/path/claude-fw"
    chmod +x "$TMP/path/claude-fw"
    run_check
    [[ "$output" == *WARN* ]]
    [[ "$output" == *"repo:    $TMP/fwroot/bin/claude-fw-router"* ]]
    [[ "$output" == *"cp \"$TMP/fwroot/bin/claude-fw-router\""* ]]
    [[ "$output" != *"cp \"$TMP/fwroot/bin/claude-fw\" "* ]]
}

@test "(c) drifted fixed copy: WARN vs bin/claude-fw, and mentions the router" {
    { cat "$TMP/fwroot/bin/claude-fw"; echo "# stale"; } > "$TMP/path/claude-fw"
    chmod +x "$TMP/path/claude-fw"
    run_check
    [[ "$output" == *WARN* ]]
    [[ "$output" == *"repo:    $TMP/fwroot/bin/claude-fw"$'\n'* ]]
    [[ "$output" == *"cp \"$TMP/fwroot/bin/claude-fw\" "* ]]
    [[ "$output" == *claude-fw-router* ]]
}

@test "(d) identical fixed copy: still OK" {
    cp "$TMP/fwroot/bin/claude-fw" "$TMP/path/claude-fw"; chmod +x "$TMP/path/claude-fw"
    run_check
    [[ "$output" != *WARN* ]]
    [[ "$output" == *"matches repo source"* ]]
}
