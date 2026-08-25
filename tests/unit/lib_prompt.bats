#!/usr/bin/env bats
# Unit tests for lib/prompt.sh — reusable agent-prompt register (T-1283 B1).

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root

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

# ---- B2: cross-agent ID namespacing ----

@test "B2: FW_AGENT_ID env overrides agent-id resolution" {
    FW_AGENT_ID=xyz run _prompt_resolve_agent_id
    [ "$status" = 0 ]
    [ "$output" = "xyz" ]
}

@test "B2: counter allocates sequentially and monotonically" {
    local a b c
    a="$(_prompt_next_counter)"
    b="$(_prompt_next_counter)"
    c="$(_prompt_next_counter)"
    [ "$a" = 1 ]
    [ "$b" = 2 ]
    [ "$c" = 3 ]
}

@test "B2: create writes qid, agent_id, and counter to frontmatter" {
    FW_AGENT_ID=testhost do_prompt_create --name "With qid" --body "hi"
    local file="$PROJECT_ROOT/prompts/with-qid.md"
    [ -f "$file" ]
    grep -q '^agent_id: testhost$' "$file"
    grep -q '^counter: 1$' "$file"
    grep -q '^qid: testhost/P-001$' "$file"
}

@test "B2: qid zero-pads counter to 3 digits" {
    FW_AGENT_ID=th do_prompt_create --name "first" --body "a"
    FW_AGENT_ID=th do_prompt_create --name "second" --body "b"
    local f2="$PROJECT_ROOT/prompts/second.md"
    grep -q '^qid: th/P-002$' "$f2"
}

@test "B2: show accepts FQID as well as slug" {
    FW_AGENT_ID=h1 do_prompt_create --name "Hello two" --body "hello body"
    # slug lookup works
    run do_prompt_show "hello-two"
    [ "$status" = 0 ]
    [[ "$output" == *"hello body"* ]]
    # qid lookup works
    run do_prompt_show "h1/P-001"
    [ "$status" = 0 ]
    [[ "$output" == *"hello body"* ]]
}

@test "B2: copy accepts FQID and applies substitutions" {
    FW_AGENT_ID=h2 do_prompt_create --name "Greeting" --body "Hello {{name}}"
    run do_prompt_copy "h2/P-001" --var "name=fleet"
    [ "$status" = 0 ]
    [[ "$output" == *"Hello fleet"* ]]
}

@test "B2: list shows qid column" {
    FW_AGENT_ID=h3 do_prompt_create --name "One listed" --body "x"
    run do_prompt_list
    [ "$status" = 0 ]
    [[ "$output" == *"h3/P-001"* ]]
}

@test "B2: show on nonexistent qid fails cleanly" {
    run do_prompt_show "missing/P-999"
    [ "$status" != 0 ]
    [[ "$output" == *"not found"* ]]
}

# ---- T-1301: CRUD completion (edit, delete, backfill) ----

@test "edit --body replaces body and re-extracts variables" {
    do_prompt_create --name "Edit Target" --body "old text no vars"
    run do_prompt_edit "edit-target" --body "new text with {{foo}} and {{bar}}"
    [ "$status" = 0 ]
    local file="$PROJECT_ROOT/prompts/edit-target.md"
    grep -q "new text with" "$file"
    if grep -q "old text no vars" "$file"; then false; fi
    grep -q '^variables: \[bar,foo\]$' "$file"
}

@test "edit --tags replaces tag list" {
    do_prompt_create --name "Tag Target" --tags "old,tags" --body "x"
    do_prompt_edit "tag-target" --tags "new,shiny,tags"
    local file="$PROJECT_ROOT/prompts/tag-target.md"
    grep -q '^tags: \[new,shiny,tags\]$' "$file"
    ! grep -q 'tags: \[old,tags\]' "$file"
}

@test "edit --description updates description only" {
    do_prompt_create --name "Desc Target" --description "original" --body "x"
    do_prompt_edit "desc-target" --description "rewritten"
    local file="$PROJECT_ROOT/prompts/desc-target.md"
    grep -q '^description: "rewritten"$' "$file"
}

@test "edit preserves qid/agent_id/counter across edits" {
    FW_AGENT_ID=stable do_prompt_create --name "Preserve QID" --body "a"
    local file="$PROJECT_ROOT/prompts/preserve-qid.md"
    local before_qid; before_qid=$(grep '^qid:' "$file")
    do_prompt_edit "preserve-qid" --body "b"
    local after_qid; after_qid=$(grep '^qid:' "$file")
    [ "$before_qid" = "$after_qid" ]
}

@test "edit fails with helpful message when no fields supplied" {
    do_prompt_create --name "No Edit" --body "x"
    run do_prompt_edit "no-edit"
    [ "$status" != 0 ]
    [[ "$output" == *"No changes specified"* ]]
}

@test "delete --force removes the file" {
    do_prompt_create --name "Delete me" --body "x"
    local file="$PROJECT_ROOT/prompts/delete-me.md"
    [ -f "$file" ]
    run do_prompt_delete "delete-me" --force
    [ "$status" = 0 ]
    [ ! -f "$file" ]
}

@test "delete on unknown id fails" {
    run do_prompt_delete "does-not-exist" --force
    [ "$status" != 0 ]
    [[ "$output" == *"not found"* ]]
}

@test "backfill assigns qid to prompts missing one" {
    # Create a prompt via the file system directly (no qid, simulating a
    # pre-B2 file).
    mkdir -p "$PROJECT_ROOT/prompts"
    cat > "$PROJECT_ROOT/prompts/legacy.md" <<'EOF'
---
id: legacy
name: "Legacy prompt"
description: ""
kind: agent
tags: []
variables: []
created: 2026-04-17T00:00:00Z
updated: 2026-04-17T00:00:00Z
---

Legacy body.
EOF
    FW_AGENT_ID=bf run do_prompt_backfill
    [ "$status" = 0 ]
    grep -q '^qid: bf/P-001$' "$PROJECT_ROOT/prompts/legacy.md"
    grep -q '^agent_id: bf$' "$PROJECT_ROOT/prompts/legacy.md"
    grep -q '^counter: 1$' "$PROJECT_ROOT/prompts/legacy.md"
}

@test "backfill is idempotent for prompts that already have qid" {
    FW_AGENT_ID=bf2 do_prompt_create --name "Has qid" --body "x"
    local file="$PROJECT_ROOT/prompts/has-qid.md"
    local original; original=$(cat "$file")
    do_prompt_backfill
    local after; after=$(cat "$file")
    [ "$original" = "$after" ]
}
