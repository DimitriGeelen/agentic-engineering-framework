#!/bin/bash
# T-856 — teeth for the operator-ruled BVP auto-approval switch.
#
# WHAT IT DEFENDS. The operator ruled on 2026-09-25 that BVP scoring happens
# without approval. The implementation opens exactly ONE of the five verbs
# acd_gate guards. The failure mode to defend against is not "the switch does not
# work" — that is obvious on first use — it is "the switch opened more than it was
# asked to". A blanket CLAUDECODE bypass would satisfy every happy-path check and
# would silently hand an agent policy-edit authority over the value model.
#
# ON MUTATION MODE. The usual pattern here strips the feature from a COPY of the
# subject and requires the dependent cases to go red. lib/bvp.sh is SOURCED by
# bin/fw, so substituting a copy means repointing FRAMEWORK_ROOT, which changes
# far more than the thing under test and would produce reds for the wrong reason
# — the exact trap measured in T-849. So the treatment/control comparison here is
# the SWITCH STATE (FW_BVP_AUTO_CONFIRM=1 vs =0) against the same source, plus the
# four still-gated verbs as the control set. That is a weaker mutation than a
# source strip and is labelled as such rather than dressed up as one.

set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || { echo "REFUSING: cannot cd to $ROOT"; exit 2; }
# the framework repo itself (FRAMEWORK.md at root), else a vendored consumer
if [ -f FRAMEWORK.md ]; then FW="bin/fw"; else FW=".agentic-framework/bin/fw"; fi
# The suite writes telemetry to a THROWAWAY path, never to the ledger the operator
# analyses. The first run of this suite did contaminate the real ledger with
# T-9990 fixture rows; an append-only ledger cannot be cleaned afterwards, so the
# contaminant is documented in .context/telemetry/README.md instead, and this
# redirect is why it cannot happen again.
WORK="$(mktemp -d "${TMPDIR:-/tmp}/t856.XXXXXX")"
TEL="$WORK/bvp-auto-approval.jsonl"
export FW_BVP_TELEMETRY_PATH="$TEL"
FIXTURE_ID="T-9990"
FIXTURE=".tasks/active/${FIXTURE_ID}-t856-auto-approval-fixture.md"

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  PASS  %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL  %s\n       %s\n' "$1" "$2"; }

cleanup() { rm -f "$FIXTURE"; rm -rf "$WORK"; }
trap cleanup EXIT

# A fixture task carrying a PROPOSAL, so the promote path is exercised with real
# proposed values rather than only with --override.
write_fixture() {
    cat > "$FIXTURE" <<'FIXEOF'
---
id: T-9990
name: "T-856 auto-approval fixture — safe to delete"
description: >
  Throwaway fixture created and removed by tools/_t856-auto-approval-teeth.sh.
status: captured
workflow_type: build
owner: agent
horizon: later
tags: []
created: 2026-09-25T00:00:00Z
last_update: 2026-09-25T00:00:00Z
date_finished: null
bvp_scores_proposed:
  - at: 2026-09-25T00:00:00Z
    scores: {D1: 3, D2: 2, D3: 1, D4: 1}
---

# T-9990: fixture

## Acceptance Criteria
### Agent
- [ ] fixture, not real work
FIXEOF
}

tel_rows() { [ -f "$TEL" ] && wc -l < "$TEL" | tr -d ' ' || echo 0; }

echo "=== T-856 auto-approval teeth ==="
echo

# ── TREATMENT: the switch ON permits the one verb it names ─────────────────────
write_fixture
before=$(tel_rows)
# T-1005 retarget (1.7.740): upstream T-3487 replaced our switch -- the confirm gate is
# opt-in via FW_REQUIRE_BVP_CONFIRM_APPROVAL=1, so the default (unset) is the "on" state.
out=$(CLAUDECODE=1 env -u FW_REQUIRE_BVP_CONFIRM_APPROVAL "$FW" bvp confirm "$FIXTURE_ID" 2>&1); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'via: agent'; then ok switch_on_permits_confirm
else bad switch_on_permits_confirm "rc=$rc out=$(printf '%s' "$out" | tail -2 | tr '\n' ' ')"; fi

# The promote path: the PROPOSED values must land as confirmed, unchanged.
if grep -q 'D1: 3' "$FIXTURE" && grep -q 'bvp_scores:' "$FIXTURE"; then ok proposed_promoted_to_confirmed
else bad proposed_promoted_to_confirmed "confirmed scores do not carry the proposed D1=3"; fi

# confirmed_by must not read as a person on the auto path.
if grep -q 'confirmed_via: agent' "$FIXTURE"; then ok confirmed_by_marks_auto
else bad confirmed_by_marks_auto "confirmed_by does not mark the auto path: $(grep confirmed_by "$FIXTURE" | head -1)"; fi

# Telemetry: exactly one new row, and it carries the proposal for comparison.
after=$(tel_rows)
if [ "$after" -eq $((before + 1)) ]; then ok telemetry_one_row_per_event
else bad telemetry_one_row_per_event "rows went $before -> $after, expected +1"; fi

last=$(tail -1 "$TEL" 2>/dev/null || echo '{}')
if printf '%s' "$last" | python3 -c "
import json,sys
r=json.load(sys.stdin)
assert r['target']=='T-9990', r.get('target')
assert r['proposal_existed'] is True, r.get('proposal_existed')
assert r['proposed']=={'D1':3,'D2':2,'D3':1,'D4':1}, r.get('proposed')
assert r['confirmed']=={'D1':3,'D2':2,'D3':1,'D4':1}, r.get('confirmed')
assert r['delta_vs_proposed']=={}, r.get('delta_vs_proposed')
assert r['proposer_exact'] is True, r.get('proposer_exact')
assert r['switch'].startswith('T-3487'), r.get('switch')
" 2>/dev/null; then ok telemetry_row_carries_proposal_and_delta
else bad telemetry_row_carries_proposal_and_delta "row shape wrong: $(printf '%s' "$last" | head -c 200)"; fi

# ── CONTROL: the switch OFF still refuses ─────────────────────────────────────
write_fixture
before=$(tel_rows)
out=$(CLAUDECODE=1 FW_REQUIRE_BVP_CONFIRM_APPROVAL=1 "$FW" bvp confirm "$FIXTURE_ID" 2>&1); rc=$?
if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'ACD'; then ok switch_off_still_refuses
else bad switch_off_still_refuses "rc=$rc — the switch is not load-bearing: $(printf '%s' "$out" | head -1)"; fi
if [ "$(tel_rows)" -eq "$before" ]; then ok no_telemetry_on_refusal
else bad no_telemetry_on_refusal "a refused action wrote a telemetry row"; fi

# ── CONTROL: telemetry is auto-path ONLY. Tested via the NON-AGENT path
# (CLAUDECODE unset), deliberately NOT via --i-am-human: passing that flag on the
# operator's behalf is prohibited, and a test is not an exemption.
write_fixture
before=$(tel_rows)
out=$(env -u CLAUDECODE FW_BVP_AUTO_CONFIRM=1 "$FW" bvp confirm "$FIXTURE_ID" 2>&1); rc=$?
if [ "$rc" -eq 0 ] && [ "$(tel_rows)" -eq "$before" ]; then ok no_telemetry_when_not_an_agent
else bad no_telemetry_when_not_an_agent "rc=$rc, rows $before -> $(tel_rows) — a non-agent run was logged as automatic"; fi
if grep -q 'confirmed_via: agent' "$FIXTURE"; then
  bad confirmed_by_not_auto_for_human "a non-agent confirm was recorded as confirmed_via: agent"
else ok confirmed_by_not_auto_for_human; fi

# ── CONTROL SET: the four verbs the ruling did NOT cover must still refuse,
# WITH the switch on. This is the whole point of the suite.
for spec in "weight|weight --set D1=9 --rationale 'teeth probe, must be refused before anything is written'" \
            "driver --add|driver --add zzz-teeth-probe --weight 1 --rationale 'teeth probe, must be refused before anything is written'" \
            "driver --remove|driver --remove F9 --rationale 'teeth probe, must be refused before anything is written'" \
            "auto-promote|auto-promote --enable"; do
    label="${spec%%|*}"; cmdargs="${spec#*|}"
    out=$(CLAUDECODE=1 FW_BVP_AUTO_CONFIRM=1 bash -c "$FW bvp $cmdargs" 2>&1); rc=$?
    if [ "$rc" -ne 0 ]; then ok "still_gated: $label"
    else bad "still_gated: $label" "EXIT 0 with BVP_AUTO_CONFIRM=1 — the switch opened a verb the ruling did not cover"; fi
done

# The policy file must be untouched by those refusals — a gate that refuses after
# writing is not a gate.
if git diff --quiet -- policy/value-drivers.yaml 2>/dev/null; then ok policy_unchanged_by_refusals
else bad policy_unchanged_by_refusals "policy/value-drivers.yaml changed while probing gated verbs"; fi

echo
echo "PASS $PASS / FAIL $FAIL"
[ "$FAIL" -eq 0 ]
