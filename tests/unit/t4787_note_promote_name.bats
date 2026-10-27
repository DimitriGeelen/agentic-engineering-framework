#!/usr/bin/env bats
# T-4787 — `fw note promote` must give the task a short, readable name, keep the
# full observation text in description and ## Context, and write frontmatter
# that parses.
#
# Origin: promote read the text with `grep -A1 | sed 's/.*text: "//'`, which
# only understands a one-line double-quoted entry. A re-serialised inbox holds
# single-quoted, wrapped entries, so T-4786/T-4788/T-4792 were named
# `  text: 'Structural gap ...` (first physical line, prefix included), and the
# whole text, however long, went into name:. OBS-482's double quote made
# T-3442's frontmatter unparseable.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
OBSERVE="$FRAMEWORK_ROOT/agents/observe/observe.sh"

setup() {
    export TEST_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_DIR"
    mkdir -p "$TEST_DIR/.context/working" "$TEST_DIR/.tasks/active" "$TEST_DIR/.tasks/completed"
    echo 'current_task: T-001' > "$TEST_DIR/.context/working/focus.yaml"
    # OBS-701: the re-serialised shape (single-quoted, wrapped, '' escape,
    # a double quote, a colon). OBS-702: double-quoted with a backslash.
    cat > "$TEST_DIR/.context/inbox.yaml" <<'YAML'
observations:
- id: OBS-701
  text: 'Structural gap found while recovering T-2821: a worker said "done" but
    died before committing, leaving the deliverable uncommitted on disk and the task
    in completed/ with nothing to say so. Second sentence ''quoted'' here.'
  captured: 2026-10-01T00:00:00Z
  context_task: T-001
  tags: []
  status: pending
  promoted_to: null
- id: OBS-702
  text: "Regex \\d+ in a note: the \"IW\" pattern broke the reader."
  captured: 2026-10-01T00:00:00Z
  context_task: T-001
  tags: []
  status: pending
  promoted_to: null
YAML
}

teardown() { rm -rf "$TEST_DIR"; }

_front() {  # $1 obs id -> prints the created task's frontmatter as JSON
    local f
    f=$(grep -l "observation $1" "$TEST_DIR"/.tasks/active/T-*.md | head -1)
    [ -n "$f" ] || { echo "no task for $1" >&2; return 1; }
    python3 -c '
import json, sys, yaml
t = open(sys.argv[1]).read()
print(json.dumps(yaml.safe_load(t.split("---")[1]), default=str))' "$f"
}

_body() { cat "$(grep -l "observation $1" "$TEST_DIR"/.tasks/active/T-*.md | head -1)"; }

@test "T-4787: wrapped single-quoted text -> frontmatter parses, name is a short summary" {
    run "$OBSERVE" promote OBS-701
    [ "$status" -eq 0 ]
    run _front OBS-701
    [ "$status" -eq 0 ]
    name=$(echo "$output" | python3 -c 'import json,sys; print(json.load(sys.stdin)["name"])')
    [[ "$name" == "Structural gap found while recovering T-2821"* ]]
    [[ "$name" != *"text:"* ]]
    [ "${#name}" -le 121 ]
    [[ "$name" != *$'\n'* ]]
}

@test "T-4787: full observation text is in description and ## Context" {
    run "$OBSERVE" promote OBS-701
    [ "$status" -eq 0 ]
    desc=$(_front OBS-701 | python3 -c 'import json,sys; print(json.load(sys.stdin)["description"])')
    [[ "$desc" == *"Promoted from observation OBS-701"* ]]
    [[ "$desc" == *"Second sentence 'quoted' here."* ]]
    body=$(_body OBS-701)
    ctx=$(printf '%s\n' "$body" | awk '/^## Context/{f=1;next} /^## /{f=0} f')
    [[ "$ctx" == *'a worker said "done"'* ]]
    [[ "$ctx" == *"Second sentence 'quoted' here."* ]]
}

@test "T-4787: backslash and double quote in the text -> frontmatter parses" {
    run "$OBSERVE" promote OBS-702
    [ "$status" -eq 0 ]
    run _front OBS-702
    [ "$status" -eq 0 ]
    name=$(echo "$output" | python3 -c 'import json,sys; print(json.load(sys.stdin)["name"])')
    [ "$name" = 'Regex \d+ in a note: the "IW" pattern broke the reader.' ]
}

@test "T-4787: promote says the task is human-owned" {
    run "$OBSERVE" promote OBS-702
    [ "$status" -eq 0 ]
    [[ "$output" == *"owner: human"* ]]
}
