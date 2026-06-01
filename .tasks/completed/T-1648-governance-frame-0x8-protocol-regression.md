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

status: work-completed
workflow_type: test
owner: agent
horizon: null
tags: [from-T-1641, t-1061-followup, drift-defense, protocol, contract, t-1066]
components: [tests/fixtures/termlink-protocol-frame-types.json, tests/unit/test_termlink_governance_frame_contract.py]
related_tasks: [T-1641, T-1644, T-1066, T-1651, T-1652]
arc_id: orchestrator-rethink
created: 2026-05-01T12:20:27Z
last_update: 2026-05-01T18:58:37Z
date_finished: 2026-05-01T13:05:31Z
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

## RCA

**Symptom:** T-1066 wired a data plane Governance frame (FrameType = 0x8) and a subscriber that consumes it. T-1641 reconsideration found zero non-test emit callers. Net effect: the protocol surface is dormant — no production code path exercises it, so any rename or renumber would land silently.

**Root cause:** No framework-side contract test pinning the wire format. Termlink's own tests cover the roundtrip but say nothing to the framework that depends on the byte assignment via cross-repo fabric cards (T-1652) and W10 documentation (T-1641).

**Why structurally allowed:** Cross-repo dependencies were invisible until T-1652. Even with T-1652 cards in place, those are documentation, not assertions — they do not fail loud on rename.

**Prevention:** This task. tests/unit/test_termlink_governance_frame_contract.py specifically pins FrameType::Governance = 0x8 and the GovernanceEvent field set. A rename in /opt/termlink fails this test on the framework's next CI / pre-push run.

## Decisions

### 2026-05-01 — Pin via source-parse, not behaviour-test

- **Chose:** Parse the Rust source files (data.rs, governance.rs) from a Python regex-based scan to pin the byte values and field set. No need to compile or link against termlink crates.
- **Why:** Framework runs in Python; spinning up a Rust toolchain just to compile a single struct is overkill. Source-parse catches the only failure modes that matter (rename, renumber).
- **Rejected:** (a) Compile termlink-protocol in CI — over-engineered. (b) Behaviour test that emits a real frame — requires termlink running and would be flaky.

## Updates

### 2026-05-01T15:20:00Z — promoted-and-scoped [agent]
- **Action:** Promoted horizon later→now. Continuing Arc C (T-1644) drift defenses per autonomous-mode directive.

## Reviewer Verdict (v1.4)

- **Scan ID:** R-bba718a6
- **Timestamp:** 2026-05-01T13:05:32Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Per-AC findings:**

- **AC#3 (Agent)** — Test parses /opt/termlink/crates/termlink-protocol/src/data.rs and asserts FrameType::Governance = 0x8
  - **AC-verify-mismatch** (narrow, heuristic) — `path=opt/termlink/crates/termlink-protocol/src/data.rs in: Test parses /opt/termlink/crates/termlink-protocol/src/data.rs and asserts FrameType::Governance = 0x8`
- **AC#4 (Agent)** — Test parses /opt/termlink/crates/termlink-protocol/src/governance.rs and asserts GovernanceEvent struct contains all expected fields (pattern_name, match_text, timestamp, channel_id)
  - **AC-verify-mismatch** (narrow, heuristic) — `path=opt/termlink/crates/termlink-protocol/src/governance.rs in: Test parses /opt/termlink/crates/termlink-protocol/src/governance.rs and asserts GovernanceEvent struct contains all expected fields (pattern_name, ma`

### 2026-05-01T13:05:31Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-05-01T18:58:37Z — status-update [task-update-agent]
- **Change:** tags: +arc:orchestrator-rethink
