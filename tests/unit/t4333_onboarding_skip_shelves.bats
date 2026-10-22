#!/usr/bin/env bats
# T-4333: `fw onboarding skip` disabled the T-532 gate but left the seeded
# onboarding tasks (T-001..T-005) in active/ at horizon: now, so a fresh
# project's task lists and handover kept offering work the operator had just
# declined. Skip now shelves the unfinished ones to horizon: later (captured).
# They stay in active/ so `fw onboarding reset` and "complete them later" still
# hold; completed and non-onboarding tasks are untouched.

setup() {
    FRAMEWORK_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    ROOT="$(mktemp -d)"
    mkdir -p "$ROOT/.context/working" "$ROOT/.tasks/active" "$ROOT/.tasks/completed"
    echo "project_name: t4333" > "$ROOT/.framework.yaml"
    mk T-001 started-work agent "[onboarding]"
    mk T-002 captured human "[onboarding, inception]"
    mk T-003 work-completed agent "[onboarding]"
    mk T-010 started-work agent "[arc:onboarding-curriculum]"
}

teardown() {
    rm -rf "$ROOT"
}

mk() {  # $1=id $2=status $3=owner $4=tags
    cat > "$ROOT/.tasks/active/$1-x.md" <<MD
---
id: $1
name: "task $1"
status: $2
workflow_type: build
owner: $3
horizon: now
tags: $4
---
# $1
MD
}

field() {  # $1=id $2=field
    grep "^$2:" "$ROOT/.tasks/active/$1-x.md" | head -1 | sed "s/^$2:[[:space:]]*//"
}

skip_onboarding() {
    run env PROJECT_ROOT="$ROOT" "$FRAMEWORK_ROOT/bin/fw" onboarding skip
    [ "$status" -eq 0 ]
}

@test "skip shelves unfinished onboarding tasks to horizon later" {
    skip_onboarding
    [ "$(field T-001 horizon)" = "later" ]
    [ "$(field T-002 horizon)" = "later" ]
}

@test "skip demotes a started-work onboarding task to captured (T-1068 invariant)" {
    skip_onboarding
    [ "$(field T-001 status)" = "captured" ]
    [ "$(field T-002 status)" = "captured" ]
}

@test "skip leaves completed onboarding and non-onboarding tasks untouched" {
    skip_onboarding
    [ "$(field T-003 horizon)" = "now" ]
    [ "$(field T-003 status)" = "work-completed" ]
    [ "$(field T-010 horizon)" = "now" ]
    [ "$(field T-010 status)" = "started-work" ]
}

@test "skip keeps the tasks in active/ and writes the marker" {
    skip_onboarding
    [ -f "$ROOT/.tasks/active/T-001-x.md" ]
    [ -f "$ROOT/.tasks/active/T-002-x.md" ]
    [ -z "$(ls -A "$ROOT/.tasks/completed")" ]
    [ -f "$ROOT/.context/working/.onboarding-complete" ]
}

@test "skip names the shelved tasks in its output" {
    skip_onboarding
    [[ "$output" == *"T-001"* ]]
    [[ "$output" == *"T-002"* ]]
    [[ "$output" != *"T-010"* ]]
}
