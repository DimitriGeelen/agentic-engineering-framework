#!/usr/bin/env bats
# Unit tests for lib/prompt.sh — reusable agent-prompt register (T-1283 B1).

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export PROJECT_ROOT="$TEST_TEMP_DIR"

    # shellcheck source=/dev/null
    source "${BATS_TEST_DIRNAME}/../../lib/prompt.sh"
}

teardown() {
    [ -n "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "create writes a prompt file with frontmatter and body" {
    run do_prompt_create \
        --name "Upgrade and test" \
        --kind agent \
        --description "Upgrade fw and run tests" \
        --tags "fleet,upgrade" \
        --body "Run .agentic-framework/bin/fw upgrade on {{host}} then {{command}}."
    [ "$status" = 0 ]

    local file="$PROJECT_ROOT/prompts/upgrade-and-test.md"
    [ -f "$file" ]

    grep -q '^id: upgrade-and-test$' "$file"
    grep -q '^kind: agent$' "$file"
    grep -q '^tags: \[fleet,upgrade\]$' "$file"
    # Variables auto-extracted
    grep -q '^variables: \[command,host\]$' "$file"
    grep -q 'Run .agentic-framework/bin/fw upgrade on {{host}}' "$file"
}

@test "create rejects missing --name" {
    run do_prompt_create --kind agent --body "hi"
    [ "$status" != 0 ]
    [[ "$output" == *"--name is required"* ]]
}

@test "create rejects invalid --kind" {
    run do_prompt_create --name "x" --kind bogus --body "hi"
    [ "$status" != 0 ]
    [[ "$output" == *"--kind must be"* ]]
}

@test "create refuses to overwrite existing prompt" {
    do_prompt_create --name "dup" --body "first"
    run do_prompt_create --name "dup" --body "second"
    [ "$status" != 0 ]
    [[ "$output" == *"already exists"* ]]
}

@test "list prints one line per prompt" {
    do_prompt_create --name "First prompt" --kind agent --body "a"
    do_prompt_create --name "Second" --kind system --body "b"

    run do_prompt_list
    [ "$status" = 0 ]
    [[ "$output" == *"first-prompt"* ]]
    [[ "$output" == *"second"* ]]
    [[ "$output" == *"agent"* ]]
    [[ "$output" == *"system"* ]]
}

@test "list on empty dir prints placeholder" {
    run do_prompt_list
    [ "$status" = 0 ]
    [[ "$output" == *"no prompts yet"* || "$output" == *"No prompts directory"* ]]
}

@test "show prints body without frontmatter" {
    do_prompt_create --name "Hello" --body $'line one\nline two'
    run do_prompt_show "hello"
    [ "$status" = 0 ]
    [[ "$output" == *"line one"* ]]
    [[ "$output" == *"line two"* ]]
    [[ "$output" != *"---"* ]]
    [[ "$output" != *"id: hello"* ]]
}

@test "show fails on unknown id" {
    run do_prompt_show "nonexistent"
    [ "$status" != 0 ]
    [[ "$output" == *"not found"* ]]
}

@test "copy substitutes {{var}} placeholders" {
    do_prompt_create --name "Greet" --body "Hello {{name}} from {{host}}."
    run do_prompt_copy "greet" --var "name=world" --var "host=.107"
    [ "$status" = 0 ]
    [[ "$output" == *"Hello world from .107."* ]]
    [[ "$output" != *"{{name}}"* ]]
    [[ "$output" != *"{{host}}"* ]]
}

@test "copy leaves unsubstituted vars intact" {
    do_prompt_create --name "Partial" --body "Hi {{a}} and {{b}}"
    run do_prompt_copy "partial" --var "a=one"
    [ "$status" = 0 ]
    [[ "$output" == *"Hi one and {{b}}"* ]]
}

@test "copy --raw skips substitution" {
    do_prompt_create --name "Raw" --body "Hi {{a}}"
    run do_prompt_copy "raw" --raw --var "a=x"
    [ "$status" = 0 ]
    [[ "$output" == *"Hi {{a}}"* ]]
}

@test "copy rejects malformed --var" {
    do_prompt_create --name "V" --body "x"
    run do_prompt_copy "v" --var "no-equals-sign"
    [ "$status" != 0 ]
    [[ "$output" == *"KEY=VALUE"* ]]
}
