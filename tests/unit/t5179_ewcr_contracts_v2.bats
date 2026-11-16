#!/usr/bin/env bats
# T-5179 — EWCR contracts v2 = v1 plus the acceptance scenarios N-1 and N-2
# (accepted by the operator 2026-11-16; source T-5135 rows DS-1 and MS-3).
#
# Pins three things:
#   1. contracts/v1 is untouched (git, and its own frozen hashes);
#   2. contracts/v2 passes both fences, and each fence goes red on a tampered copy;
#   3. N-1 and N-2 are present in the agreed form, traced, and N-2's refusal
#      record names the excess.
#
# Every green assertion has a control leg (L-668): a check that cannot fail is
# not a check.

load ../test_helper

TOOL="$FRAMEWORK_ROOT/tools/ewcr-contracts-check.py"
TRACE="$FRAMEWORK_ROOT/tools/ewcr-trace-check.py"
REL="docs/research/executable-workflow/contracts"
BASE="$FRAMEWORK_ROOT/$REL"
V1="$BASE/v1"
V2="$BASE/v2"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    cp -r "$V1" "$TEST_TEMP_DIR/v1"
    cp -r "$V2" "$TEST_TEMP_DIR/v2"
    COPY="$TEST_TEMP_DIR/v2"
    MATRIX_COPY="$TEST_TEMP_DIR/traceability.yaml"
    cp "$V2/traceability.yaml" "$MATRIX_COPY"
}

teardown() {
    [ -n "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
    return 0
}

_check() { run python3 "$TOOL" --contracts-version 2 --contracts "$COPY" "$@"; }
_trace() { run python3 "$TRACE" --contracts-version 2 --file "$MATRIX_COPY"; }

_validate() {  # _validate SCHEMA INSTANCE
    python3 - "$1" "$2" <<'PY'
import json, sys
from jsonschema import Draft202012Validator
s = json.load(open(sys.argv[1])); i = json.load(open(sys.argv[2]))
errs = list(Draft202012Validator(s).iter_errors(i))
for e in errs[:5]: print("/".join(map(str, e.path)) or "<root>", e.message)
sys.exit(1 if errs else 0)
PY
}

# Rewrite the N-2 example in the copy. Usage: _edit_n2 '<python statements on d>'
_edit_example() {  # _edit_example FILE 'python on d'
    python3 - "$COPY/examples/$1" "$2" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
exec(sys.argv[2])
json.dump(d, open(sys.argv[1], "w"), indent=2)
PY
}

# Rewrite one accepted-scenario field in the matrix copy.
_mutate_accepted() {  # _mutate_accepted ID 'python on r'
    python3 - "$MATRIX_COPY" "$1" "$2" <<'PY'
import sys, yaml
path, rid, code = sys.argv[1:4]
d = yaml.safe_load(open(path))
for r in d["accepted_scenarios"]:
    if r["id"] == rid:
        exec(code)
yaml.safe_dump(d, open(path, "w"), allow_unicode=True)
PY
}

# ── v1 is frozen ───────────────────────────────────────────────────────────

@test "contracts/v1 is byte-identical to HEAD: no modified, deleted or added file" {
    run git -C "$FRAMEWORK_ROOT" diff --quiet HEAD -- "$REL/v1"
    [ "$status" -eq 0 ]
    run git -C "$FRAMEWORK_ROOT" status --porcelain -- "$REL/v1"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "the v1 fence is still the default and still green: 7 schemas, 7 examples" {
    run python3 "$TOOL"
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK: 7 schemas valid"* ]]
    [[ "$output" == *"7 examples validate"* ]]
    [[ "$output" != *"contracts v2"* ]]
    run python3 "$TRACE"
    [ "$status" -eq 0 ]
    [[ "$output" == *"20 invariants traced"* ]]
    [[ "$output" != *"accepted scenario"* ]]
}

@test "v1 does not know the N-2 reason code — it is new in v2, not back-ported" {
    run _validate "$V1/refusal.schema.json" "$V2/examples/refusal-privilege-exceeds-profile.json"
    [ "$status" -ne 0 ]
    run grep -c "privilege_exceeds_profile" "$V1/refusal.schema.json"
    [ "$output" -eq 0 ]
}

# ── v2 passes the contracts fence ──────────────────────────────────────────

@test "the committed contracts/v2 passes the fence: 6 schemas carried, 1 changed, 12 examples" {
    run python3 "$TOOL" --contracts-version 2
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK: 7 schemas valid"* ]]
    [[ "$output" == *"12 examples validate"* ]]
    [[ "$output" == *"6 schemas carried from v1 unchanged, 1 changed"* ]]
    [[ "$output" == *"2 documents carried unchanged"* ]]
}

@test "an untouched copy of v2 is green (control for the tamper legs)" {
    _check
    [ "$status" -eq 0 ]
}

@test "only refusal.schema.json differs from v1; the other six schemas and both prose contracts are the same bytes" {
    for f in attempt deadline-event evidence-reference instance procedure transition-envelope; do
        cmp -s "$V1/$f.schema.json" "$V2/$f.schema.json"
    done
    cmp -s "$V1/task-lifecycle-contract.md" "$V2/task-lifecycle-contract.md"
    cmp -s "$V1/evidence-and-idempotency.md" "$V2/evidence-and-idempotency.md"
    run cmp -s "$V1/refusal.schema.json" "$V2/refusal.schema.json"
    [ "$status" -ne 0 ]
    for f in "$V1"/examples/*.json; do
        cmp -s "$f" "$V2/examples/$(basename "$f")"
    done
}

@test "control: a byte change to a carried schema is refused (it claims to be v1's and is not)" {
    printf '\n' >> "$COPY/attempt.schema.json"
    _check
    [ "$status" -eq 1 ]
    [[ "$output" == *"attempt.schema.json"* ]]
}

@test "control: the changed schema must carry version 2 and a /v2/ \$id" {
    python3 - "$COPY/refusal.schema.json" <<'PY'
import json, sys
s = json.load(open(sys.argv[1])); s["version"] = 1
json.dump(s, open(sys.argv[1], "w"), indent=2)
PY
    _check
    [ "$status" -eq 1 ]
    [[ "$output" == *"refusal.schema.json"* ]]
    [[ "$output" == *"version"* ]]
}

@test "control: a byte change to the v2 refusal schema is DRIFT against the v2 manifest" {
    sed -i 's/privilege_exceeds_profile only (N-2)/privilege_exceeds_profile only (N-2) /' "$COPY/refusal.schema.json"
    _check
    [ "$status" -eq 1 ]
    [[ "$output" == *"DRIFT"* ]]
}

@test "control: editing a document the manifest calls carried_from v1 is refused" {
    printf '\nextra line\n' >> "$COPY/task-lifecycle-contract.md"
    _check
    [ "$status" -eq 1 ]
    [[ "$output" == *"task-lifecycle-contract.md"* ]]
    [[ "$output" == *"byte-identical"* ]]
}

@test "control: the v2 fence validates the additional examples — a broken N-2 record turns it red" {
    _edit_example refusal-privilege-exceeds-profile.json 'del d["privilege_excess"]'
    _check
    [ "$status" -eq 1 ]
    [[ "$output" == *"refusal-privilege-exceeds-profile.json"* ]]
}

@test "control: checking the v2 directory as version 1 is refused" {
    run python3 "$TOOL" --contracts "$COPY"
    [ "$status" -eq 1 ]
}

# ── N-2: the reason code and the record that names the excess ──────────────

@test "N-2: the example refusal validates against the v2 schema and names the excess" {
    run _validate "$V2/refusal.schema.json" "$V2/examples/refusal-privilege-exceeds-profile.json"
    [ "$status" -eq 0 ]
    run python3 -c "
import json,sys
d=json.load(open(sys.argv[1]))
assert d['reason_code']=='privilege_exceeds_profile'
assert d['side_effect'] is False
assert d['scenario_refs']==['N-2']
x=d['privilege_excess']
assert x['excess']==['repo:write','packages:delete'], x
assert x['capability_profile_ref'] and x['binding_ref'] and x['node']
" "$V2/examples/refusal-privilege-exceeds-profile.json"
    [ "$status" -eq 0 ]
}

@test "N-2 control: privilege_exceeds_profile without privilege_excess is INVALID" {
    _edit_example refusal-privilege-exceeds-profile.json 'del d["privilege_excess"]'
    run _validate "$V2/refusal.schema.json" "$COPY/examples/refusal-privilege-exceeds-profile.json"
    [ "$status" -ne 0 ]
    [[ "$output" == *"privilege_excess"* ]]
}

@test "N-2 control: an empty excess list is INVALID — the refusal must name what exceeds" {
    _edit_example refusal-privilege-exceeds-profile.json 'd["privilege_excess"]["excess"] = []'
    run _validate "$V2/refusal.schema.json" "$COPY/examples/refusal-privilege-exceeds-profile.json"
    [ "$status" -ne 0 ]
}

@test "N-2 control: a refusal claiming a side effect is INVALID — refused before execution" {
    _edit_example refusal-privilege-exceeds-profile.json 'd["side_effect"] = True'
    run _validate "$V2/refusal.schema.json" "$COPY/examples/refusal-privilege-exceeds-profile.json"
    [ "$status" -ne 0 ]
}

@test "N-2 control: privilege_excess on any other reason code is INVALID" {
    _edit_example refusal.json 'd["privilege_excess"] = {"node": "n", "capability_profile_ref": "c", "binding_ref": "b", "excess": ["x"]}'
    run _validate "$V2/refusal.schema.json" "$COPY/examples/refusal.json"
    [ "$status" -ne 0 ]
}

# ── N-1 and the scenario references ────────────────────────────────────────

@test "N-1: the example refusal validates, keeps the instance where it was and names N-1" {
    run _validate "$V2/refusal.schema.json" "$V2/examples/refusal-task-cancelled-during-attempt.json"
    [ "$status" -eq 0 ]
    run python3 -c "
import json,sys
d=json.load(open(sys.argv[1]))
assert d['reason_code']=='cancellation_in_effect'
assert 'N-1' in d['scenario_refs'] and d['side_effect'] is False
" "$V2/examples/refusal-task-cancelled-during-attempt.json"
    [ "$status" -eq 0 ]
}

@test "scenario_refs accepts §13 numbers and the ids N-1, N-2 — nothing else" {
    cp "$V1/examples/refusal.json" "$TEST_TEMP_DIR/v1-refusal.json"
    run _validate "$V2/refusal.schema.json" "$TEST_TEMP_DIR/v1-refusal.json"
    [ "$status" -eq 0 ]
    for bad in '"N-3"' '21' '"13"'; do
        _edit_example refusal-task-cancelled-during-attempt.json "d['scenario_refs'] = [$bad]"
        run _validate "$V2/refusal.schema.json" "$COPY/examples/refusal-task-cancelled-during-attempt.json"
        [ "$status" -ne 0 ]
    done
}

# ── the scenarios are written in the agreed form ───────────────────────────

@test "accepted-scenarios.md gives N-1 and N-2 a situation, required behaviour and a pass/fail test each" {
    run python3 - "$V2/accepted-scenarios.md" <<'PY'
import re, sys
t = open(sys.argv[1], encoding="utf-8").read()
parts = re.split(r"^## ", t, flags=re.M)
for sid in ("N-1", "N-2"):
    sec = [p for p in parts if p.startswith(sid + " ")]
    assert len(sec) == 1, (sid, len(sec))
    for h in ("**Statement:**", "### Situation", "### Required behaviour", "### Pass/fail test",
              "- **Pass:**", "- **Fail:**", "- **Given**", "- **When**", "- **Then**"):
        assert h in sec[0], (sid, h)
assert "privilege_exceeds_profile" in t
PY
    [ "$status" -eq 0 ]
}

@test "v2 README and MANIFEST say what changed and why (T-5135, operator decision 2026-11-16)" {
    for f in README.md MANIFEST.yaml; do
        grep -q "T-5135" "$V2/$f"
        grep -q "2026-11-16" "$V2/$f"
        grep -q "N-1" "$V2/$f"
        grep -q "N-2" "$V2/$f"
    done
    grep -q "privilege_exceeds_profile" "$V2/README.md"
    run python3 -c "
import yaml,sys
m=yaml.safe_load(open(sys.argv[1]))
assert m['contracts_version']==2 and m['changes']['from']=='v1'
" "$V2/MANIFEST.yaml"
    [ "$status" -eq 0 ]
}

# ── traceability ───────────────────────────────────────────────────────────

@test "the v2 matrix resolves: 20 §13 rows unchanged plus 2 accepted scenarios" {
    run python3 "$TRACE" --contracts-version 2
    [ "$status" -eq 0 ]
    [[ "$output" == *"20 invariants traced"* ]]
    [[ "$output" == *"2 accepted scenario(s) traced"* ]]
    run python3 -c "
import yaml,sys
a=yaml.safe_load(open(sys.argv[1])); b=yaml.safe_load(open(sys.argv[2]))
sys.exit(0 if a['invariants']==b['invariants'] else 1)" "$V1/traceability.yaml" "$V2/traceability.yaml"
    [ "$status" -eq 0 ]
}

@test "N-1 traces to DS-1 and Arc 1 cand 3, 6, 8; N-2 traces to MS-3 and Arc 3 cand 5/6 with Arc 2" {
    run python3 - "$V2/traceability.yaml" <<'PY'
import sys, yaml
rows = {r["id"]: r for r in yaml.safe_load(open(sys.argv[1]))["accepted_scenarios"]}
assert sorted(rows) == ["N-1", "N-2"], sorted(rows)
n1, n2 = rows["N-1"], rows["N-2"]
assert n1["source_finding"] == "DS-1" and n2["source_finding"] == "MS-3"
c1 = " | ".join(n1["components"]); c2 = " | ".join(n2["components"])
for want in ("Arc 1 cand 3", "Arc 1 cand 6", "Arc 1 cand 8"):
    assert want in c1, (want, c1)
for want in ("Arc 3 cand 5/6", "Arc 2"):
    assert want in c2, (want, c2)
assert n2["reason_codes"] == ["privilege_exceeds_profile"]
assert set(n1["reason_codes"]) == {"cancellation_in_effect", "task_hash_drift"}
for r in (n1, n2):
    assert r["accepted_by"] == "operator" and r["accepted_on"] == "2026-11-16"
PY
    [ "$status" -eq 0 ]
}

@test "an untouched matrix copy is green (control for the trace tamper legs)" {
    _trace
    [ "$status" -eq 0 ]
}

@test "control: a reworded N-2 statement no longer matches the scenario document" {
    _mutate_accepted N-2 'r["statement"] = r["statement"].replace("refused before execution", "flagged")'
    _trace
    [ "$status" -eq 1 ]
    [[ "$output" == *"N-2 statement is not present verbatim"* ]]
}

@test "control: an accepted scenario naming a reason code the v2 schema lacks is refused" {
    _mutate_accepted N-2 'r["reason_codes"] = ["credential_too_wide"]'
    _trace
    [ "$status" -eq 1 ]
    [[ "$output" == *"credential_too_wide"* ]]
}

@test "control: an accepted scenario with no source finding, or one the report does not name, is refused" {
    _mutate_accepted N-1 'r["source_finding"] = "DS-9"'
    _trace
    [ "$status" -eq 1 ]
    [[ "$output" == *"DS-9"* ]]
}

@test "control: an example that does not name its scenario is refused" {
    _mutate_accepted N-1 'r["example"] = "examples/refusal.json"'
    _trace
    [ "$status" -eq 1 ]
    [[ "$output" == *"N-1"* ]]
}

@test "control: a v2 matrix with the accepted scenarios removed is refused" {
    python3 - "$MATRIX_COPY" <<'PY'
import sys, yaml
d = yaml.safe_load(open(sys.argv[1])); del d["accepted_scenarios"]
yaml.safe_dump(d, open(sys.argv[1], "w"), allow_unicode=True)
PY
    _trace
    [ "$status" -eq 1 ]
    [[ "$output" == *"accepted_scenarios"* ]]
}

@test "control: the v2 matrix is not a v1 matrix — the v1 fence refuses it" {
    run python3 "$TRACE" --file "$MATRIX_COPY"
    [ "$status" -eq 1 ]
}
