#!/usr/bin/env bats
# T-2497: the picker ranks eligible tasks by BVP quadrant (HV-LC first), then
# value-desc / cost-asc, so the live resolver loop grinds the HV/LC backlog by
# value. These tests pin: (1) BVP order overrides FIFO, (2) the env escape hatch
# falls back to pure FIFO, (3) unscored corpus stays FIFO (backward-compat),
# (4) the picker's normalised value matches the F8/bvp.sh formula (parity), and
# (5) estimator-proposed scores feed the rank when confirmed scores are absent.

load ../test_helper

setup() {
    PICKROOT="$(mktemp -d)"
    mkdir -p "$PICKROOT/.tasks/active" "$PICKROOT/.context/working" \
             "$PICKROOT/.context/project/workflows" "$PICKROOT/policy"
    cat > "$PICKROOT/.context/project/workflows/default.yaml" <<'YAML'
task_type: default
worker_kind: TermLink
model: sonnet
prompt_template: prompts/default.md
strict_mcp_config: true
YAML
    printf 'current_task: T-9000\n' > "$PICKROOT/.context/working/focus.yaml"
    # Minimal policy: D1..D4 with the canonical weights (9,7,5,3).
    cat > "$PICKROOT/policy/value-drivers.yaml" <<'YAML'
protected_drivers:
  - id: D1
    name: Antifragility
    weight: 9
  - id: D2
    name: Reliability
    weight: 7
  - id: D3
    name: Usability
    weight: 5
  - id: D4
    name: Portability
    weight: 3
free_drivers: []
YAML
}

teardown() { rm -rf "$PICKROOT"; }

# _task ID STATUS HORIZON SCORES_YAML COST_YAML
#   SCORES_YAML/COST_YAML may be empty strings (→ unscored task).
_task() {
    local id="$1" status="$2" horizon="$3" scores="$4" cost="$5"
    {
        echo "---"
        echo "id: ${id}"
        echo "name: \"fixture ${id}\""
        echo "workflow_type: build"
        echo "owner: agent"
        echo "horizon: ${horizon}"
        echo "status: ${status}"
        [ -n "$scores" ] && echo "bvp_scores: ${scores}"
        [ -n "$cost" ] && echo "cost_estimate: ${cost}"
        echo "---"
        echo
        echo "## Acceptance Criteria"
        echo
        echo "### Agent"
        echo "- [ ] do the real thing"
    } > "$PICKROOT/.tasks/active/${id}-x.md"
}

_pick_json() {
    PROJECT_ROOT="$PICKROOT" python3 "$FRAMEWORK_ROOT/lib/resolver.py" pick --json
}

@test "t2497: HV-LC task outranks a lower-id LV-HC task of equal status/horizon" {
    # T-8001 is older (FIFO would pick it) but LV-HC; T-8002 is HV-LC → must win.
    _task T-8001 started-work now "{D1: 1, D2: 1, D3: 1, D4: 1}" "{blast_radius: 8, tier: 8, effort: 8}"
    _task T-8002 started-work now "{D1: 5, D2: 5, D3: 5, D4: 5}" "{blast_radius: 1, tier: 1, effort: 1}"
    run _pick_json
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); \
assert d['pick']=='T-8002', d['pick']; \
assert d['eligible']==['T-8002','T-8001'], d['eligible']; \
assert d['bvp']['quadrant']=='hv-lc', d['bvp']; print('ok')"
}

@test "t2497: FW_RESOLVER_BVP_RANK=0 falls back to pure FIFO" {
    _task T-8001 started-work now "{D1: 1, D2: 1, D3: 1, D4: 1}" "{blast_radius: 8, tier: 8, effort: 8}"
    _task T-8002 started-work now "{D1: 5, D2: 5, D3: 5, D4: 5}" "{blast_radius: 1, tier: 1, effort: 1}"
    run env FW_RESOLVER_BVP_RANK=0 PROJECT_ROOT="$PICKROOT" \
        python3 "$FRAMEWORK_ROOT/lib/resolver.py" pick --json
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); \
assert d['pick']=='T-8001', d['pick']; \
assert d['eligible']==['T-8001','T-8002'], d['eligible']; \
assert d['bvp']['quadrant']=='-', d['bvp']; print('ok')"
}

@test "t2497: unscored corpus ranks FIFO even with policy present (backward-compat)" {
    _task T-8003 started-work now "" ""
    _task T-8001 started-work now "" ""
    _task T-8002 captured     now "" ""
    run _pick_json
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); \
assert d['eligible']==['T-8001','T-8003','T-8002'], d['eligible']; \
assert d['pick']=='T-8001'; \
assert d['bvp']['bvp_norm'] is None, d['bvp']; print('ok')"
}

@test "t2497: picker normalised value matches the F8/bvp.sh formula (parity)" {
    # D1=5,D2=5,D3=5,D4=5 → raw 5*(9+7+5+3)=120, max 120 → norm 1.0.
    # D1=3,D2=0,D3=0,D4=0 → raw 27, max 120 → norm 0.225.
    _task T-8002 started-work now "{D1: 5, D2: 5, D3: 5, D4: 5}" "{blast_radius: 1, tier: 1, effort: 1}"
    _task T-8001 started-work now "{D1: 3, D2: 0, D3: 0, D4: 0}" "{blast_radius: 8, tier: 8, effort: 8}"
    run _pick_json
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); \
b=d['bvp']; \
assert d['pick']=='T-8002', d['pick']; \
assert abs(b['bvp_norm']-1.0)<1e-9, b; \
assert abs(b['cost']-1.0)<1e-9, b; print('ok')"
}

@test "t2497: estimator-proposed scores feed the rank when confirmed are absent" {
    # T-8005 has only proposed scores (advisory fallback) — still gets a norm and
    # outranks the lower-id unscored task.
    _task T-8001 started-work now "" ""
    {
        echo "---"
        echo "id: T-8005"
        echo "name: \"fixture proposed\""
        echo "workflow_type: build"
        echo "owner: agent"
        echo "horizon: now"
        echo "status: started-work"
        echo "bvp_scores_proposed:"
        echo "  - ts: 2026-06-25T00:00:00Z"
        echo "    scores: {D1: 5, D2: 5, D3: 5, D4: 5}"
        echo "cost_estimate_proposed:"
        echo "  - ts: 2026-06-25T00:00:00Z"
        echo "    cost_estimate: {blast_radius: 1, tier: 1, effort: 1}"
        echo "---"
        echo
        echo "## Acceptance Criteria"
        echo
        echo "### Agent"
        echo "- [ ] real work"
    } > "$PICKROOT/.tasks/active/T-8005-x.md"
    run _pick_json
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); \
assert d['pick']=='T-8005', d['pick']; \
assert abs(d['bvp']['bvp_norm']-1.0)<1e-9, d['bvp']; print('ok')"
}
