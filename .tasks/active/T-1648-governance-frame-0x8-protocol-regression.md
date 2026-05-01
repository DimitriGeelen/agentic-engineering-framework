---
id: T-1648
name: "Governance frame 0x8 protocol regression test (T-1066 wire format pin)"
description: >
  W10 #3 — T-1066's data plane Governance frame (FrameType::Governance = 0x8) has zero
  non-test emit callers; if its byte value or payload schema changes, no production
  caller will fail loud — only the dormant subscriber's tests. This task adds a
  framework-side regression test that parses /opt/termlink/crates/termlink-protocol/src/
  data.rs and governance.rs to pin (a) frame-type → byte mapping and (b) GovernanceEvent
  payload JSON field set. Skips gracefully when /opt/termlink is not on this host.
  Origin: docs/reports/T-1641-worker-10-defenses.md item #3.

status: started-work
workflow_type: test
owner: agent
horizon: now
tags: [from-T-1641, t-1061-followup, drift-defense, protocol, contract, t-1066]
components: []
related_tasks: [T-1641, T-1644, T-1066, T-1651, T-1652]
created: 2026-05-01T12:20:27Z
last_update: 2026-05-01T15:20:00Z
date_finished: null
---

# T-1648: Governance frame 0x8 protocol regression test

## Context

T-1066 wired a data plane governance subscriber that emits Governance frames
(FrameType::Governance = 0x8) when output patterns match. T-1641 reconsideration
found: zero non-test callers. The code path exists but is unused.

That makes the wire format invisible to production failure modes. If somebody
renumbers FrameType::Governance to 0x9, only the subscriber's own tests fail —
no alarm rings in the framework that depends on this protocol.

This task pins the contract from the framework side. If termlink renames or
renumbers, this test fails — making the structural change loud.

## Acceptance Criteria

### Agent
- [x] `tests/fixtures/termlink-protocol-frame-types.json` exists, listing all frame types and their assigned byte values
- [x] `tests/unit/test_termlink_governance_frame_contract.py` exists
- [x] Test parses /opt/termlink/crates/termlink-protocol/src/data.rs and asserts FrameType::Governance = 0x8
- [x] Test parses /opt/termlink/crates/termlink-protocol/src/governance.rs and asserts GovernanceEvent struct contains all expected fields (pattern_name, match_text, timestamp, channel_id)
- [x] Test skips gracefully (pytest.skip) when /opt/termlink is not present on the host
- [x] Test passes against current upstream HEAD

## Verification

test -f tests/fixtures/termlink-protocol-frame-types.json
python3 -c "import json; d=json.load(open('tests/fixtures/termlink-protocol-frame-types.json')); assert d['frame_types']['Governance']==8"
test -f tests/unit/test_termlink_governance_frame_contract.py
python3 -m pytest tests/unit/test_termlink_governance_frame_contract.py -v --tb=short

## Decisions

### 2026-05-01 — Pin via source-parse, not behaviour-test

- **Chose:** Parse the Rust source files (data.rs, governance.rs) from a Python regex-based scan to pin the byte values and field set. No need to compile or link against termlink crates.
- **Why:** Framework runs in Python; spinning up a Rust toolchain just to compile a single struct is overkill. Source-parse catches the only failure modes that matter (rename, renumber).
- **Rejected:** (a) Compile termlink-protocol in CI — over-engineered. (b) Behaviour test that emits a real frame — requires termlink running and would be flaky.

## Updates

### 2026-05-01T15:20:00Z — promoted-and-scoped [agent]
- **Action:** Promoted horizon later→now. Continuing Arc C (T-1644) drift defenses per autonomous-mode directive.
