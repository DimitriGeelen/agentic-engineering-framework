#!/usr/bin/env bats
# T-4042 (GitHub #89): fw upgrade step 7b must not re-create the messaging
# toolkit (9 slash commands + 12 scripts) in a project that does not want it.
# Opt-in via MESSAGING_TOOLKIT in .framework.yaml; derived once from existing files.
#
# Runs the framework under test (FRAMEWORK_ROOT, working tree) against a synthetic
# consumer in a scrubbed env, like upgrade_fresh_machine_simulation.bats. The consumer
# has no vendored .agentic-framework/, so upgrade runs from FRAMEWORK_ROOT directly
# (a file:// upstream would clone committed HEAD and not see uncommitted fixes).

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d -t fw-t4042-XXXXXX)"
    export FRAMEWORK_ROOT
    PROJ="$TEST_TEMP_DIR/proj"
    mkdir -p "$PROJ" "$TEST_TEMP_DIR/home"
    git init -q "$PROJ"
    printf 'project_name: proj\nversion: 1.0.0\nprovider: claude\n' > "$PROJ/.framework.yaml"
    N_SK=$(ls "$FRAMEWORK_ROOT"/lib/templates/skills/*.md | wc -l)
    N_SC=$(ls "$FRAMEWORK_ROOT"/lib/templates/scripts/*.sh | wc -l)
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

up() {
    (cd "$PROJ" && env -i PATH="/usr/local/bin:/usr/bin:/bin" HOME="$TEST_TEMP_DIR/home" \
        "$FRAMEWORK_ROOT/bin/fw" upgrade "$PROJ" --no-self-vendor "$@" 2>&1)
}

toolkit_count() {
    local n=0 f
    for f in "$FRAMEWORK_ROOT"/lib/templates/skills/*.md; do [ -e "$PROJ/.claude/commands/$(basename "$f")" ] && n=$((n+1)); done
    for f in "$FRAMEWORK_ROOT"/lib/templates/scripts/*.sh; do [ -e "$PROJ/scripts/$(basename "$f")" ] && n=$((n+1)); done
    echo "$n"
}

key() { grep "^MESSAGING_TOOLKIT:" "$PROJ/.framework.yaml" | sed 's/^MESSAGING_TOOLKIT:[[:space:]]*//'; }

@test "T-4042 (a): fresh consumer, key unset, no toolkit files -> none created, key 0" {
    run up
    [ "$status" -eq 0 ] || { echo "$output"; false; }
    [ "$(toolkit_count)" -eq 0 ]
    [ "$(key)" = "0" ]
    [[ "$output" == *"--with-messaging"* ]]
}

@test "T-4042 (b): key 0, second upgrade -> still none after files were absent" {
    up >/dev/null
    rm -rf "$PROJ/scripts" "$PROJ/.claude/commands/agent-handoff.md"
    run up
    [ "$status" -eq 0 ] || { echo "$output"; false; }
    [ "$(toolkit_count)" -eq 0 ]
    [ "$(key)" = "0" ]
}

@test "T-4042 (c): toolkit present, key unset -> kept/updated, key 1" {
    mkdir -p "$PROJ/scripts" "$PROJ/.claude/commands"
    cp "$FRAMEWORK_ROOT/lib/templates/scripts/agent-send.sh" "$PROJ/scripts/"
    run up
    [ "$status" -eq 0 ] || { echo "$output"; false; }
    [ "$(key)" = "1" ]
    [ "$(toolkit_count)" -eq $((N_SK + N_SC)) ]
}

@test "T-4042 (d): --with-messaging on a fresh consumer -> full toolkit, key 1" {
    run up --with-messaging
    [ "$status" -eq 0 ] || { echo "$output"; false; }
    [ "$(toolkit_count)" -eq $((N_SK + N_SC)) ]
    [ "$(key)" = "1" ]
    [ -x "$PROJ/scripts/agent-send.sh" ]
}

@test "T-4042 (e): --without-messaging on an installed toolkit -> files untouched and listed, key 0" {
    up --with-messaging >/dev/null
    run up --without-messaging
    [ "$status" -eq 0 ] || { echo "$output"; false; }
    [ "$(toolkit_count)" -eq $((N_SK + N_SC)) ]
    [ "$(key)" = "0" ]
    [[ "$output" == *"scripts/agent-send.sh"* ]]
}

@test "T-4042: help names both flags and derives counts from the template dirs" {
    run bash -c "env -i PATH=/usr/local/bin:/usr/bin:/bin HOME=$TEST_TEMP_DIR/home '$FRAMEWORK_ROOT/bin/fw' upgrade --help"
    [ "$status" -eq 0 ]
    [[ "$output" == *"--with-messaging"* ]]
    [[ "$output" == *"--without-messaging"* ]]
    [[ "$output" == *"$N_SK slash commands"* ]]
    [[ "$output" == *"$N_SC scripts"* ]]
}
