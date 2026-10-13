#!/usr/bin/env bats
# T-4153: capability-card schema on fabric subsystems + lint

setup() {
    ROOT="$BATS_TEST_DIRNAME/../.."
    F="$BATS_TEST_TMPDIR/subsystems.yaml"
}

lint() { python3 -I "$ROOT/agents/fabric/lib/cardlint.py" "$F" "$@"; }

good_card='    capability_card:
      capabilities: ["Dispatch work to isolated workers", "Observe workers remotely"]
      problem_solved: "My agent session runs out of context when I hand it big jobs"
      tags: [dispatch, workers]
      entry_points: ["fw termlink dispatch"]
      status: live
      owner: "framework (agent-contact)"
      limits: "Max 5 concurrent workers"'

@test "valid card passes (exit 0)" {
    printf 'subsystems:\n  - id: a\n    name: A\n%s\n' "$good_card" > "$F"
    run lint
    [ "$status" -eq 0 ]
    [[ "$output" == *"1 card"* ]]
}

@test "missing problem_solved is refused" {
    printf 'subsystems:\n  - id: a\n    name: A\n%s\n' "$(echo "$good_card" | grep -v problem_solved)" > "$F"
    run lint
    [ "$status" -eq 1 ]
    [[ "$output" == *"a"*"problem_solved"* ]]
}

@test "empty tags is refused" {
    printf 'subsystems:\n  - id: a\n    name: A\n%s\n' "$(echo "$good_card" | sed 's/tags: \[dispatch, workers\]/tags: []/')" > "$F"
    run lint
    [ "$status" -eq 1 ]
    [[ "$output" == *"tags"* ]]
}

@test "placeholder text is refused" {
    printf 'subsystems:\n  - id: a\n    name: A\n%s\n' "$(echo "$good_card" | sed 's/My agent session runs out of context when I hand it big jobs/TODO/')" > "$F"
    run lint
    [ "$status" -eq 1 ]
    [[ "$output" == *"placeholder"* ]]
}

@test "bad status is refused" {
    printf 'subsystems:\n  - id: a\n    name: A\n%s\n' "$(echo "$good_card" | sed 's/status: live/status: maybe/')" > "$F"
    run lint
    [ "$status" -eq 1 ]
    [[ "$output" == *"status"* ]]
}

@test "subsystem without a card is listed but not a failure" {
    printf 'subsystems:\n  - id: a\n    name: A\n%s\n  - id: bare\n    name: Bare\n' "$good_card" > "$F"
    run lint
    [ "$status" -eq 0 ]
    [[ "$output" == *"without a card"*"bare"* ]]
}

@test "--strict fails on uncarded subsystems" {
    printf 'subsystems:\n  - id: bare\n    name: Bare\n' > "$F"
    run lint --strict
    [ "$status" -eq 1 ]
}

@test "fw fabric lint is routed" {
    run "$ROOT/bin/fw" fabric help
    [[ "$output" == *"lint"* ]]
}
