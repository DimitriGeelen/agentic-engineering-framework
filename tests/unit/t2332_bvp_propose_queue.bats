#!/usr/bin/env bats
# T-2332 (T-2330 S2): Flask helpers + template render for the driver
# propose-queue. Endpoints that shell out to `bin/fw` (propose / approve)
# are not covered here.
#
# This bats covers pure Python paths that can be exercised in isolation:
# _load_proposals state-machine, _append_proposal_state_change, and the
# template render (GET /bvp via the Flask test client).
#
# T-4384: hermetic. Every python process runs with PROJECT_ROOT pointing at
# a temp project root, so nothing reads or writes the live .context/ and no
# running Watchtower (ours or another project's) is contacted.

setup() {
    cd "$BATS_TEST_DIRNAME/../.."
    SCRATCH_DIR="$(mktemp -d)"
    export SCRATCH_DIR
    mkdir -p "$SCRATCH_DIR/.context/working" "$SCRATCH_DIR/.tasks/active" "$SCRATCH_DIR/.tasks/completed" "$SCRATCH_DIR/policy"
    # /bvp renders the proposal queue only inside its weights block, so the
    # temp project needs a minimal driver policy.
    cat > "$SCRATCH_DIR/policy/value-drivers.yaml" <<'EOF'
protected_drivers:
  - {id: D1, name: Antifragility, weight: 4}
free_drivers: []
EOF
    export PROJECT_ROOT="$SCRATCH_DIR"
}

teardown() {
    [ -d "${SCRATCH_DIR:-}" ] && rm -rf "$SCRATCH_DIR"
}

# ----------------------------------------------- _load_proposals state machine

@test "T-2332: _load_proposals returns empty list when file missing" {
    run python3 -c "
import sys
sys.path.insert(0, '.')
from web.blueprints.bvp import _load_proposals, PROPOSALS_PATH
import os
# Use the scratch dir so we don't read the live file
os.environ['_T2332_SCRATCH'] = '$SCRATCH_DIR'
# _load_proposals reads PROPOSALS_PATH (set at module load). For this isolated
# test, we point it at a non-existent file via direct attribute override.
import web.blueprints.bvp as bvp_mod
from pathlib import Path
bvp_mod.PROPOSALS_PATH = Path('$SCRATCH_DIR/does-not-exist.jsonl')
result = _load_proposals()
assert result == [], result
print('PASS')
"
    echo "$output" | grep -q "PASS"
}

@test "T-2332: _load_proposals returns pending rows by default" {
    fixture="$SCRATCH_DIR/proposals.jsonl"
    cat > "$fixture" <<'EOF'
{"id":"P-001","ts":"2026-06-11T00:00:00Z","state":"pending","name":"V_A","weight":5,"rationale":"Pending A row","author":"agent:test"}
{"id":"P-002","ts":"2026-06-11T00:01:00Z","state":"pending","name":"V_B","weight":3,"rationale":"Pending B row","author":"agent:test"}
EOF
    run python3 -c "
import sys
sys.path.insert(0, '.')
import web.blueprints.bvp as bvp_mod
from pathlib import Path
bvp_mod.PROPOSALS_PATH = Path('$fixture')
result = bvp_mod._load_proposals()
assert len(result)==2, result
assert {r['id'] for r in result}=={'P-001','P-002'}, result
print('PASS')
"
    echo "$output" | grep -q "PASS"
}

@test "T-2332: _load_proposals applies state-machine — approved row hides original from pending" {
    fixture="$SCRATCH_DIR/proposals.jsonl"
    cat > "$fixture" <<'EOF'
{"id":"P-A","ts":"2026-06-11T00:00:00Z","state":"pending","name":"V_X","weight":5,"rationale":"original","author":"agent:test"}
{"id":"P-B","ts":"2026-06-11T00:01:00Z","state":"pending","name":"V_Y","weight":3,"rationale":"survives","author":"agent:test"}
{"id":"P-A","ts":"2026-06-11T00:02:00Z","state":"approved","actor":"operator-watchtower"}
EOF
    run python3 -c "
import sys
sys.path.insert(0, '.')
import web.blueprints.bvp as bvp_mod
from pathlib import Path
bvp_mod.PROPOSALS_PATH = Path('$fixture')
pending = bvp_mod._load_proposals()
assert [r['id'] for r in pending]==['P-B'], pending
# Full history shows both with correct end states
full = bvp_mod._load_proposals(state_filter=None)
states = {r['id']: r['state'] for r in full}
assert states=={'P-A':'approved','P-B':'pending'}, states
print('PASS')
"
    echo "$output" | grep -q "PASS"
}

@test "T-2332: _load_proposals applies state-machine — rejected with rationale_decision" {
    fixture="$SCRATCH_DIR/proposals.jsonl"
    cat > "$fixture" <<'EOF'
{"id":"P-R","ts":"2026-06-11T00:00:00Z","state":"pending","name":"V_R","weight":4,"rationale":"original","author":"agent:test"}
{"id":"P-R","ts":"2026-06-11T00:01:00Z","state":"rejected","actor":"operator-watchtower","rationale_decision":"Operator does not see distinguishing value beyond D1-D4 in this rubric."}
EOF
    run python3 -c "
import sys
sys.path.insert(0, '.')
import web.blueprints.bvp as bvp_mod
from pathlib import Path
bvp_mod.PROPOSALS_PATH = Path('$fixture')
full = bvp_mod._load_proposals(state_filter=None)
assert len(full)==1, full
r = full[0]
assert r['state']=='rejected', r
assert r['decision_rationale'].startswith('Operator does not see'), r
print('PASS')
"
    echo "$output" | grep -q "PASS"
}

# --------------------------------------- _append_proposal_state_change writes

@test "T-2332: _append_proposal_state_change appends well-formed JSON line" {
    fixture="$SCRATCH_DIR/proposals.jsonl"
    : > "$fixture"  # empty file
    run python3 -c "
import sys, json
sys.path.insert(0, '.')
import web.blueprints.bvp as bvp_mod
from pathlib import Path
bvp_mod.PROPOSALS_PATH = Path('$fixture')
ok = bvp_mod._append_proposal_state_change('P-XYZ', 'rejected', 'Test rationale decision — at least 30 characters long.')
assert ok, 'append returned False'
row = json.loads(open('$fixture').read().strip())
assert row['id']=='P-XYZ'
assert row['state']=='rejected'
assert row['actor']=='operator-watchtower'
assert row['rationale_decision'].startswith('Test rationale decision')
assert 'ts' in row
print('PASS')
"
    echo "$output" | grep -q "PASS"
}

# ------------------------------- GET /bvp renders queue section (test client)

# Render /bvp in a fresh process against the temp project root. Prints the
# HTTP status as a STATUS= line, then the page body.
_render_bvp() {
    python3 -c "
import sys
sys.path.insert(0, '.')
from web.app import app
import web.blueprints.bvp as bvp_mod
assert str(bvp_mod.PROPOSALS_PATH).startswith('$SCRATCH_DIR'), bvp_mod.PROPOSALS_PATH
app.config['TESTING'] = True
r = app.test_client().get('/bvp')
print('STATUS=%d' % r.status_code)
print(r.get_data(as_text=True))
"
}

@test "T-2332: GET /bvp renders the queue section when proposals pending" {
    cat > "$SCRATCH_DIR/.context/bvp-driver-proposals.jsonl" <<'EOF'
{"id":"P-001","ts":"2026-06-11T00:00:00Z","state":"pending","name":"V_QUEUED","weight":5,"rationale":"Pending row","author":"agent:test"}
{"id":"P-002","ts":"2026-06-11T00:01:00Z","state":"pending","name":"V_GONE","weight":3,"rationale":"Approved later","author":"agent:test"}
{"id":"P-002","ts":"2026-06-11T00:02:00Z","state":"approved","actor":"operator-watchtower"}
EOF
    run _render_bvp
    [ "$status" -eq 0 ]
    echo "$output" | grep -qx 'STATUS=200'
    echo "$output" | grep -q 'id="bvp-driver-proposals"'
    echo "$output" | grep -q "Pending driver proposals (1)"
    echo "$output" | grep -q "V_QUEUED"
    ! echo "$output" | grep -q "V_GONE"
}

@test "T-2332: GET /bvp omits the queue section when nothing is pending" {
    cat > "$SCRATCH_DIR/.context/bvp-driver-proposals.jsonl" <<'EOF'
{"id":"P-009","ts":"2026-06-11T00:00:00Z","state":"pending","name":"V_DONE","weight":5,"rationale":"Rejected later","author":"agent:test"}
{"id":"P-009","ts":"2026-06-11T00:01:00Z","state":"rejected","actor":"operator-watchtower","rationale_decision":"No distinguishing value beyond D1-D4 here."}
EOF
    run _render_bvp
    [ "$status" -eq 0 ]
    echo "$output" | grep -qx 'STATUS=200'
    ! echo "$output" | grep -q 'id="bvp-driver-proposals"'
    ! echo "$output" | grep -q "Pending driver proposals"
}
