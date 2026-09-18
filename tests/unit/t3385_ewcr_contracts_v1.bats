#!/usr/bin/env bats
# T-3385 — EWCR contracts v1 are FROZEN: seven draft 2020-12 schemas, one worked
# example each, sha256 manifest. tools/ewcr-contracts-check.py is the fence.
#
# Every green assertion here has a control leg showing the same fence red on a
# tampered copy (L-668) — a check that cannot fail is not a check.

load ../test_helper

TOOL="$FRAMEWORK_ROOT/tools/ewcr-contracts-check.py"
SRC="$FRAMEWORK_ROOT/docs/research/executable-workflow/contracts/v1"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    COPY="$TEST_TEMP_DIR/v1"
    cp -r "$SRC" "$COPY"
}

teardown() {
    [ -n "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
    return 0
}

_check() { run python3 "$TOOL" --contracts "$COPY" "$@"; }

# ── the committed contract set ─────────────────────────────────────────────

@test "the committed contracts/v1 passes the fence: 7 schemas, 7 examples, manifest matches" {
    run python3 "$TOOL"
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK: 7 schemas valid"* ]]
    [[ "$output" == *"7 examples validate"* ]]
}

@test "exactly the seven frozen schema files exist, each draft 2020-12 with version 1 and a closed root" {
    for n in procedure instance transition-envelope attempt evidence-reference refusal deadline-event; do
        f="$SRC/$n.schema.json"
        [ -f "$f" ]
        python3 - "$f" <<'PY'
import json, sys
s = json.load(open(sys.argv[1]))
assert s["$schema"] == "https://json-schema.org/draft/2020-12/schema", s["$schema"]
assert s["version"] == 1
assert s["additionalProperties"] is False
assert s["$id"].endswith(sys.argv[1].rsplit("/", 1)[1])
assert "architecture-c9070637.md" in s["description"]
PY
    done
    [ "$(ls "$SRC"/*.schema.json | wc -l)" -eq 7 ]
}

@test "no runtime code: the task ships only under docs/…/contracts, tools/ and tests/" {
    # The commit that lands this test must not touch lib/ agents/ bin/ web/.
    # Pinned by the task's Verification (git diff on the landing SHA); here we
    # pin the weaker invariant that the fence itself imports no framework lib.
    run grep -E '^(from|import) (lib|agents|web)' "$TOOL"
    [ "$status" -ne 0 ]
}

# ── control legs: the fence is live ─────────────────────────────────────────

@test "control: a byte change to a schema is DRIFT — the fence goes red" {
    python3 - "$COPY/refusal.schema.json" <<'PY'
import json, sys
p = sys.argv[1]; s = json.load(open(p))
s["properties"]["detail"]["maxLength"] = 2000
json.dump(s, open(p, "w"), indent=2)
PY
    _check
    [ "$status" -eq 1 ]
    [[ "$output" == *"refusal.schema.json DRIFT"* ]]
}

@test "control: opening a root (additionalProperties true) is refused as un-frozen" {
    python3 - "$COPY/attempt.schema.json" <<'PY'
import json, sys
p = sys.argv[1]; s = json.load(open(p)); s["additionalProperties"] = True
json.dump(s, open(p, "w"), indent=2)
PY
    _check
    [ "$status" -eq 1 ]
    [[ "$output" == *"attempt.schema.json: root 'additionalProperties' is True"* ]]
}

@test "control: a schema that drops its architecture trace is refused" {
    python3 - "$COPY/instance.schema.json" <<'PY'
import json, sys
p = sys.argv[1]; s = json.load(open(p)); s["description"] = "an instance"
json.dump(s, open(p, "w"), indent=2)
PY
    _check
    [ "$status" -eq 1 ]
    [[ "$output" == *"instance.schema.json: description does not name architecture-c9070637.md"* ]]
}

@test "control: an eighth schema (or a missing one) breaks the frozen set" {
    cp "$COPY/refusal.schema.json" "$COPY/extra.schema.json"
    _check
    [ "$status" -eq 1 ]
    [[ "$output" == *"schema set is"* ]]
}

@test "control: re-blessing an existing manifest without --force is refused" {
    _check --write
    [ "$status" -eq 1 ]
    [[ "$output" == *"refusing to re-bless without --force"* ]]
    # and the manifest is untouched
    diff -q "$SRC/MANIFEST.yaml" "$COPY/MANIFEST.yaml"
}

# ── the contracts say what the architecture says ───────────────────────────

@test "refusal: side_effect true is INVALID — a refusal is by definition before side effect (§7.4)" {
    python3 - "$COPY/examples/refusal.json" <<'PY'
import json, sys
p = sys.argv[1]; e = json.load(open(p)); e["side_effect"] = True
json.dump(e, open(p, "w"), indent=2)
PY
    _check
    [ "$status" -eq 1 ]
    [[ "$output" == *"examples/refusal.json @ side_effect"* ]]
}

@test "refusal: an unknown reason_code is invalid — codes map 1:1 onto §13 scenarios" {
    python3 - "$COPY/examples/refusal.json" <<'PY'
import json, sys
p = sys.argv[1]; e = json.load(open(p)); e["reason_code"] = "agent_felt_like_it"
json.dump(e, open(p, "w"), indent=2)
PY
    _check
    [ "$status" -eq 1 ]
    [[ "$output" == *"examples/refusal.json @ reason_code"* ]]
}

@test "attempt: exit_outcome refused REQUIRES refusal_id and a null output_ref (no execution happened)" {
    python3 - "$COPY/examples/attempt.json" <<'PY'
import json, sys
p = sys.argv[1]; e = json.load(open(p))
e["exit_outcome"] = "refused"   # but output_ref still set, no refusal_id
json.dump(e, open(p, "w"), indent=2)
PY
    _check
    [ "$status" -eq 1 ]
    [[ "$output" == *"examples/attempt.json"* ]]
    [[ "$output" == *"refusal_id"* ]]
}

@test "procedure: a ratified procedure without a ratification record is invalid (§7.1)" {
    python3 - "$COPY/examples/procedure.json" <<'PY'
import json, sys
p = sys.argv[1]; e = json.load(open(p)); del e["ratification"]
json.dump(e, open(p, "w"), indent=2)
PY
    _check
    [ "$status" -eq 1 ]
    [[ "$output" == *"examples/procedure.json"* ]]
    [[ "$output" == *"ratification"* ]]
}

@test "procedure: a human_gate node without a decision map cannot exist (§6.2 — cannot auto-advance)" {
    python3 - "$COPY/examples/procedure.json" <<'PY'
import json, sys
p = sys.argv[1]; e = json.load(open(p))
del e["nodes"][0]["human_decision_map"]
json.dump(e, open(p, "w"), indent=2)
PY
    _check
    [ "$status" -eq 1 ]
    [[ "$output" == *"human_decision_map"* ]]
}

@test "procedure: a script node's action_ref is an opaque catalogue ref — a shell string is over-length/rejected shape" {
    python3 - "$COPY/examples/procedure.json" <<'PY'
import json, sys
p = sys.argv[1]; e = json.load(open(p))
e["nodes"][1]["action_ref"] = "bash -c 'rm -rf $OUT && " + "x" * 200 + "'"
json.dump(e, open(p, "w"), indent=2)
PY
    _check
    [ "$status" -eq 1 ]
    [[ "$output" == *"nodes/1/action_ref"* ]]
}

@test "transition-envelope: an admitted envelope must carry position and runner identity" {
    python3 - "$COPY/examples/transition-envelope.json" <<'PY'
import json, sys
p = sys.argv[1]; e = json.load(open(p)); del e["admission"]["runner_identity"]
json.dump(e, open(p, "w"), indent=2)
PY
    _check
    [ "$status" -eq 1 ]
    [[ "$output" == *"runner_identity"* ]]
}

@test "deadline-event: a fired deadline must name the envelope it fired in (ledger, not log)" {
    python3 - "$COPY/examples/deadline-event.json" <<'PY'
import json, sys
p = sys.argv[1]; e = json.load(open(p)); e["status"] = "fired"; e["fired_at"] = "2026-09-18T15:32:02Z"
json.dump(e, open(p, "w"), indent=2)
PY
    _check
    [ "$status" -eq 1 ]
    [[ "$output" == *"fired_in_envelope"* ]]
}

@test "evidence-reference: accepted evidence must carry accepted_at and validation_refs (hash before validate, then accept)" {
    python3 - "$COPY/examples/evidence-reference.json" <<'PY'
import json, sys
p = sys.argv[1]; e = json.load(open(p)); del e["validation_refs"]
json.dump(e, open(p, "w"), indent=2)
PY
    _check
    [ "$status" -eq 1 ]
    [[ "$output" == *"validation_refs"* ]]
}

@test "instance: state paused REQUIRES a pause record (§7.6)" {
    python3 - "$COPY/examples/instance.json" <<'PY'
import json, sys
p = sys.argv[1]; e = json.load(open(p)); e["state"] = "paused"   # pause is null
json.dump(e, open(p, "w"), indent=2)
PY
    _check
    [ "$status" -eq 1 ]
    [[ "$output" == *"examples/instance.json"* ]]
}
