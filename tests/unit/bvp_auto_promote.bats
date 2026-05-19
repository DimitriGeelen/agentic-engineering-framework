#!/usr/bin/env bats
# T-1931 — `fw bvp auto-promote` (M5 thresholds + R4 detection)
#
# Verifies:
#   - OFF default: enabled=false → no-op + clear message + no log writes
#   - max_concurrent ceiling: respected with no-headroom branch
#   - Confirmation-required: only tasks with bvp_scores: (confirmed) promote,
#     tasks with only bvp_scores_proposed: are skipped (M3 sovereignty boundary)
#   - --dry-run: lists candidates without promotion or log writes
#   - R4 metadata: every promotion logs task_id + bvp_norm + cost +
#     3 cost components + live thresholds + ts + mechanism

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-/opt/999-Agentic-Engineering-Framework}"
    [ -f "$FRAMEWORK_ROOT/bin/fw" ] || skip "bin/fw not found"
    cd "$FRAMEWORK_ROOT"

    # Snapshot policy + log so each test can mutate freely and revert.
    POLICY="policy/value-drivers.yaml"
    LOG=".context/bvp-auto-promote-log.yaml"
    POLICY_BAK="$(mktemp)"
    LOG_BAK="$(mktemp)"
    cp "$POLICY" "$POLICY_BAK"
    cp "$LOG" "$LOG_BAK" 2>/dev/null || echo "entries: []" > "$LOG_BAK"

    PROBE_ID="T-99970"
    PROBE_FILE=".tasks/active/${PROBE_ID}-bvp-autopromote-probe.md"
}

teardown() {
    cp "$POLICY_BAK" "$POLICY"
    cp "$LOG_BAK" "$LOG"
    rm -f "$POLICY_BAK" "$LOG_BAK"
    rm -f "$PROBE_FILE"
    rm -f ".tasks/completed/${PROBE_ID}-bvp-autopromote-probe.md"
}

@test "OFF default: enabled=false produces no-op + clear message" {
    run bin/fw bvp auto-promote
    [ "$status" -eq 0 ]
    [[ "$output" == *"Auto-promote disabled"* ]]
    [[ "$output" == *"auto_promote.enabled=false"* ]]
}

@test "OFF default: no log writes occur" {
    bin/fw bvp auto-promote >/dev/null 2>&1
    # Log file unchanged versus baseline (entries still empty).
    run python3 -c "import yaml; d=yaml.safe_load(open('$LOG')); print(len(d.get('entries') or []))"
    [ "$output" = "0" ]
}

@test "--dry-run with enabled=true lists candidates without promotion" {
    # Build probe task: high BVP (norm=1.0), low cost (0.1).
    cat > "$PROBE_FILE" <<'EOF'
---
id: T-99970
name: "bvp auto-promote probe (will be removed)"
description: "probe"
status: captured
workflow_type: build
owner: agent
horizon: now
tags: [probe]
created: 2026-05-19T00:00:00Z
last_update: 2026-05-19T00:00:00Z
date_finished: null
bvp_scores: {D1: 5, D2: 5, D3: 5, D4: 5}
cost_estimate: {blast_radius: 0, tier: 0, effort: 1}
---

# probe

## Acceptance Criteria
- [ ] probe

## Verification
true
EOF

    # Enable auto-promote with large max_concurrent.
    python3 - <<PY
from ruamel.yaml import YAML
y = YAML(); y.preserve_quotes = True; y.indent(mapping=2, sequence=4, offset=2)
src = y.load(open('$POLICY'))
src['auto_promote']['enabled'] = True
src['auto_promote']['max_concurrent'] = 999
open('$POLICY', 'w').close()
y.dump(src, open('$POLICY', 'w'))
PY

    run bin/fw bvp auto-promote --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"$PROBE_ID"* ]]
    [[ "$output" == *"dry_run=True"* ]]

    # Probe still captured (no promotion).
    grep -q "^status: captured" "$PROBE_FILE"
    # Log still has no entries.
    run python3 -c "import yaml; print(len(yaml.safe_load(open('$LOG')).get('entries') or []))"
    [ "$output" = "0" ]
}

@test "enabled=true promotes HV/LC task + writes R4 log entry" {
    cat > "$PROBE_FILE" <<'EOF'
---
id: T-99970
name: "bvp auto-promote probe (will be removed)"
description: "probe"
status: captured
workflow_type: build
owner: agent
horizon: now
tags: [probe]
created: 2026-05-19T00:00:00Z
last_update: 2026-05-19T00:00:00Z
date_finished: null
bvp_scores: {D1: 5, D2: 5, D3: 5, D4: 5}
cost_estimate: {blast_radius: 0, tier: 0, effort: 1}
---

# probe

## Acceptance Criteria
- [ ] probe

## Verification
true
EOF

    python3 - <<PY
from ruamel.yaml import YAML
y = YAML(); y.preserve_quotes = True; y.indent(mapping=2, sequence=4, offset=2)
src = y.load(open('$POLICY'))
src['auto_promote']['enabled'] = True
src['auto_promote']['max_concurrent'] = 999
y.dump(src, open('$POLICY', 'w'))
PY

    run bin/fw bvp auto-promote
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK: promoted $PROBE_ID"* ]]

    grep -q "^status: started-work" "$PROBE_FILE"

    # R4 metadata present: task_id, bvp_norm, cost, all 3 cost components,
    # all 3 thresholds, ts, mechanism.
    run python3 - <<PY
import yaml
d = yaml.safe_load(open('$LOG'))
e = (d.get('entries') or [])[-1]
keys = set(e.keys())
required = {'task_id', 'ts', 'bvp_norm', 'cost', 'cost_components', 'thresholds_at_decision', 'mechanism'}
missing = required - keys
print('missing:', sorted(missing))
print('task_id:', e['task_id'])
print('br:', e['cost_components']['blast_radius'])
print('tier:', e['cost_components']['tier'])
print('effort:', e['cost_components']['effort'])
print('bvp_norm_min:', e['thresholds_at_decision']['bvp_norm_min'])
print('mechanism:', e['mechanism'])
PY
    [ "$status" -eq 0 ]
    [[ "$output" == *"missing: []"* ]]
    [[ "$output" == *"task_id: $PROBE_ID"* ]]
    [[ "$output" == *"mechanism: fw-bvp-auto-promote"* ]]
}

@test "max_concurrent ceiling refuses promotion when no headroom" {
    cat > "$PROBE_FILE" <<'EOF'
---
id: T-99970
name: "bvp auto-promote probe (will be removed)"
description: "probe"
status: captured
workflow_type: build
owner: agent
horizon: now
tags: [probe]
created: 2026-05-19T00:00:00Z
last_update: 2026-05-19T00:00:00Z
date_finished: null
bvp_scores: {D1: 5, D2: 5, D3: 5, D4: 5}
cost_estimate: {blast_radius: 0, tier: 0, effort: 1}
---

# probe

## Acceptance Criteria
- [ ] probe

## Verification
true
EOF

    # Enable with default max_concurrent=1 (current state has many started-work tasks).
    python3 - <<PY
from ruamel.yaml import YAML
y = YAML(); y.preserve_quotes = True; y.indent(mapping=2, sequence=4, offset=2)
src = y.load(open('$POLICY'))
src['auto_promote']['enabled'] = True
src['auto_promote']['max_concurrent'] = 1
y.dump(src, open('$POLICY', 'w'))
PY

    run bin/fw bvp auto-promote
    [ "$status" -eq 0 ]
    [[ "$output" == *"max_concurrent"* ]]
    [[ "$output" == *"No headroom"* ]]
    # Probe still captured.
    grep -q "^status: captured" "$PROBE_FILE"
}

@test "M3 sovereignty: task with only bvp_scores_proposed is NOT promoted" {
    # Probe has proposed scores but no confirmed bvp_scores — should be skipped.
    cat > "$PROBE_FILE" <<'EOF'
---
id: T-99970
name: "bvp auto-promote probe — unconfirmed (will be removed)"
description: "probe"
status: captured
workflow_type: build
owner: agent
horizon: now
tags: [probe]
created: 2026-05-19T00:00:00Z
last_update: 2026-05-19T00:00:00Z
date_finished: null
bvp_scores_proposed:
  - ts: 2026-05-19T00:00:00Z
    source: agent
    scores: {D1: 5, D2: 5, D3: 5, D4: 5}
cost_estimate: {blast_radius: 0, tier: 0, effort: 1}
---

# probe

## Acceptance Criteria
- [ ] probe

## Verification
true
EOF

    python3 - <<PY
from ruamel.yaml import YAML
y = YAML(); y.preserve_quotes = True; y.indent(mapping=2, sequence=4, offset=2)
src = y.load(open('$POLICY'))
src['auto_promote']['enabled'] = True
src['auto_promote']['max_concurrent'] = 999
y.dump(src, open('$POLICY', 'w'))
PY

    run bin/fw bvp auto-promote
    [ "$status" -eq 0 ]
    # Probe NOT in candidate list — sovereignty boundary enforced.
    [[ "$output" != *"$PROBE_ID"* ]]
    grep -q "^status: captured" "$PROBE_FILE"
}
