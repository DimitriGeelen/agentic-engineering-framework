---
id: T-1651
name: "TermLink list --json contract test — pin session-object keys consumed by framework"
description: >
  W10 #6 — WezTerm Lua plugin (T-1062), Watchtower /orchestrator (T-1647), and
  audit lint (T-1649) all consume `termlink list --json` session objects. If a
  key is renamed (e.g. 'tags' → 'labels'), all three break silently. Build a
  framework-side contract test in tests/unit/: shared JSON-schema file in
  tests/fixtures/termlink-list-schema.json; pytest validates that live
  `termlink list --json` output matches the required-key set. Skips gracefully
  when termlink is not installed. Origin: docs/reports/T-1641-worker-10-defenses.md
  item #6.

status: work-completed
workflow_type: test
owner: agent
horizon: null
components: [tests/fixtures/termlink-list-schema.json, 
      tests/unit/test_termlink_list_contract.py]
related_tasks: [T-1641, T-1644, T-1062, T-1647, T-1649]
arc_id: orchestrator-rethink
created: 2026-05-01T12:20:27Z
last_update: '2026-06-11T22:23:54Z'
date_finished: 2026-05-01T12:59:06Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:54Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 3
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=3 
      (body:portability-abstraction); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-1651: TermLink list --json contract test

## Context

Three framework consumers read `termlink list --json` session objects:

| Consumer | Keys consumed |
|----------|---------------|
| `plugins/wezterm/termlink-chrome.lua` | `roles`, `role`, `tags` |
| `web/blueprints/orchestrator.py` | `id`, `name`, `display_name`, `state`, `tags` |
| `agents/audit/orchestrator-mcp-scan.sh` (T-1649) | `display_name`, `name`, `id`, `tags` |

Any rename (`tags` → `labels`, `display_name` → `title`, etc.) silently breaks all three. This task pins the contract.

## Acceptance Criteria

### Agent
- [x] `tests/fixtures/termlink-list-schema.json` exists with the required + optional key sets
- [x] `tests/unit/test_termlink_list_contract.py` exists and uses pytest
- [x] Test calls `termlink list --json`, parses, validates each session has all required keys
- [x] Test skips gracefully (pytest.skip) when `termlink` binary is unavailable
- [x] Test passes against current live data on this host
- [x] Schema documents which framework consumer reads each key (for blame-on-break)

## Verification

test -f tests/fixtures/termlink-list-schema.json
python3 -c "import json; json.load(open('tests/fixtures/termlink-list-schema.json'))"
test -f tests/unit/test_termlink_list_contract.py
python3 -m pytest tests/unit/test_termlink_list_contract.py -v --tb=short

## Decisions

### 2026-05-01 — Schema scope

- **Chose:** Pin all session-object keys consumed by ANY framework component (WezTerm + orchestrator.py + lint), not just WezTerm.
- **Why:** The task title says "WezTerm plugin contract" but the contract surface is broader; pinning only WezTerm leaves the other two consumers exposed to silent rename.
- **Rejected:** WezTerm-only schema — narrower than actual blast radius.

## Updates

### 2026-05-01T15:00:00Z — promoted-and-scoped [agent]
- **Action:** Promoted horizon later→now; expanded scope from WezTerm-only to all framework consumers of termlink list --json.
- **Context:** Continuing Arc C (T-1644) drift defenses per autonomous-mode directive.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-42a1d23e
- **Timestamp:** 2026-06-02T14:58:53Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-01T12:59:06Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-05-01T18:58:38Z — status-update [task-update-agent]
- **Change:** tags: +arc:orchestrator-rethink
