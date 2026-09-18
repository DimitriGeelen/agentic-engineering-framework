#!/usr/bin/env bats
# T-3388 — the worked human-gate → registered-script → human-gate fixture
# validates against the FROZEN v1 schemas (T-3385) and carries no path, shell
# string or secret — only opaque catalogue refs (arch §6.2.1, cadence §5).
# The Designer-side round-trip (Q-10) is peer-owned and NOT asserted here.

load ../test_helper

V1="$FRAMEWORK_ROOT/docs/research/executable-workflow/contracts/v1"
PROC="$V1/examples/procedure-human-script-human.json"
INST="$V1/examples/instance-human-script-human.json"

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

@test "the procedure fixture validates against the frozen procedure schema" {
    run _validate "$V1/procedure.schema.json" "$PROC"
    [ "$status" -eq 0 ]
}

@test "the fixture is exactly human_gate → script → human_gate (plus one terminal gateway)" {
    run python3 -c "import json,sys; n=[x['kind'] for x in json.load(open(sys.argv[1]))['nodes']]; print(n); sys.exit(0 if n==['human_gate','script','human_gate','gateway'] else 1)" "$PROC"
    [ "$status" -eq 0 ]
}

@test "the script step names only opaque refs — no path, no shell, no secret shape" {
    run python3 -c "
import json,sys,re
n=[x for x in json.load(open(sys.argv[1]))['nodes'] if x['kind']=='script'][0]
for k in ('action_ref','execution_profile_ref','capability_profile_ref'):
    v=n[k]; assert re.fullmatch(r'[a-z][a-z0-9.-]*', v), (k,v); assert '/' not in v and ' ' not in v
assert 'command' not in n and 'path' not in n
" "$PROC"
    [ "$status" -eq 0 ]
}

@test "the mid-flight instance validates and sits at run_script with the first gate approved" {
    run _validate "$V1/instance.schema.json" "$INST"
    [ "$status" -eq 0 ]
    run python3 -c "import json,sys; i=json.load(open(sys.argv[1])); sys.exit(0 if i['current_node']=='run_script' and i['state']=='ready' and i['approvals'][0]['node']=='gate_in' and i['attempt_ids']==[] else 1)" "$INST"
    [ "$status" -eq 0 ]
}

@test "control: the fixture is bound to the frozen schema — a script step with an inline command is rejected" {
    tmp="$(mktemp)"
    python3 -c "
import json,sys; p=json.load(open(sys.argv[1])); s=[x for x in p['nodes'] if x['kind']=='script'][0]; s['command']='bash -c ls'; json.dump(p,open(sys.argv[2],'w'))" "$PROC" "$tmp"
    run _validate "$V1/procedure.schema.json" "$tmp"
    [ "$status" -ne 0 ]
    [[ "$output" == *"command"* ]]
    rm -f "$tmp"
}

@test "the frozen fence still passes with the fixture present (examples/ may grow; schemas may not)" {
    run python3 "$FRAMEWORK_ROOT/tools/ewcr-contracts-check.py"
    [ "$status" -eq 0 ]
}
