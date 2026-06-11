#!/usr/bin/env bats
# T-2332 (T-2330 S2): Flask helpers + template render for the driver
# propose-queue. Endpoints that shell out to `bin/fw` (propose / approve)
# are integration-tested via live curl against the running Watchtower in
# the live smoke section at the bottom of S2 — see task closure notes.
#
# This bats covers pure Python paths that can be exercised in isolation:
# _load_proposals state-machine, _append_proposal_state_change, the
# template render (GET /bvp via Flask test client with PROJECT_ROOT
# pointing at framework root so bin/fw resolves correctly).

setup() {
    cd /opt/999-Agentic-Engineering-Framework
    # T-2332 cleanup: ensure a known proposals fixture
    SCRATCH_DIR="$(mktemp -d)"
    export SCRATCH_DIR
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

# --------------------------------------- GET /bvp renders queue section (live)

@test "T-2332: GET /bvp renders the queue section when proposals pending (live)" {
    # Test against live Watchtower — uses real PROJECT_ROOT, real proposal data.
    # Requires Watchtower to be running. Skip if not.
    url=$(bin/fw watchtower url 2>/dev/null)
    [ -n "$url" ] || skip "Watchtower not running"

    # Pre-condition: at least one pending proposal in the live store
    pending_count=$(python3 -c "
import sys, json
sys.path.insert(0, '.')
import web.blueprints.bvp as bvp_mod
print(len(bvp_mod._load_proposals()))
")
    [ "$pending_count" -gt 0 ] || skip "No pending proposals to render"

    run curl -sf "$url/bvp"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Pending driver proposals"
    echo "$output" | grep -q "bvp-driver-proposals"
}
