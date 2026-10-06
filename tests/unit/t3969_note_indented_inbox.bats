#!/usr/bin/env bats
# T-3969: `fw note` appended `- id:` at column 0 even when the inbox list sat
# indented under `observations:` (a hand-edited or re-serialised inbox). The file
# stopped parsing and ring20's pre-push audit blocked every push until it was
# re-indented by hand (seen on 1.8.3 and 1.8.5).

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
OBSERVE="$FRAMEWORK_ROOT/agents/observe/observe.sh"

setup() {
    export TEST_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_DIR"
    mkdir -p "$TEST_DIR/.context/working"
    echo 'current_task: T-001' > "$TEST_DIR/.context/working/focus.yaml"
    INBOX="$TEST_DIR/.context/inbox.yaml"
}

teardown() {
    rm -rf "$TEST_DIR"
}

_parses() {
    python3 -c 'import sys, yaml; d = yaml.safe_load(open(sys.argv[1])); print(len(d["observations"]))' "$INBOX"
}

@test "T-3969: note into an INDENTED list keeps the indent and the file parses" {
    cat > "$INBOX" <<'YAML'
observations:
  - id: OBS-005
    text: "existing"
    status: pending
    promoted_to: null
YAML
    run "$OBSERVE" "new observation"
    [ "$status" -eq 0 ]
    grep -q '^  - id: OBS-006$' "$INBOX"
    run _parses
    [ "$status" -eq 0 ]
    [ "$output" = "2" ]
}

@test "T-3969: note into a column-0 list (AEF's own shape) is unchanged" {
    cat > "$INBOX" <<'YAML'
observations:
- id: OBS-005
  text: "existing"
  status: pending
  promoted_to: null
YAML
    run "$OBSERVE" "new observation"
    [ "$status" -eq 0 ]
    grep -q '^- id: OBS-006$' "$INBOX"
    run _parses
    [ "$output" = "2" ]
}

@test "T-3969: an append that would break the file is undone and refused" {
    # A layout the append cannot fit: the list is a flow sequence that is not empty.
    printf 'observations: [{id: OBS-005, status: pending}]\n' > "$INBOX"
    before="$(cat "$INBOX")"
    run "$OBSERVE" "new observation"
    [ "$status" -ne 0 ]
    [[ "$output" == *"NOT captured"* ]]
    [ "$(cat "$INBOX")" = "$before" ]
}

@test "T-3969: control: the flow-sequence layout really is unparseable after a raw append" {
    printf 'observations: [{id: OBS-005, status: pending}]\n- id: OBS-006\n' > "$INBOX"
    run _parses
    [ "$status" -ne 0 ]
}

@test "T-3969: dismiss finds an observation in an indented inbox" {
    cat > "$INBOX" <<'YAML'
observations:
  - id: OBS-005
    text: "existing"
    status: pending
    promoted_to: null
  - id: OBS-006
    text: "other"
    status: pending
    promoted_to: null
YAML
    run "$OBSERVE" dismiss OBS-005 --reason "duplicate"
    [ "$status" -eq 0 ]
    python3 - "$INBOX" <<'PY'
import sys, yaml
obs = {o["id"]: o for o in yaml.safe_load(open(sys.argv[1]))["observations"]}
assert obs["OBS-005"]["status"] == "dismissed", obs
assert obs["OBS-005"]["dismissed_reason"] == "duplicate", obs
assert obs["OBS-006"]["status"] == "pending", obs
PY
}
