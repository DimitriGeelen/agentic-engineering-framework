---
id: T-681
name: "Add TermLink MCP server to fw init default MCP config"
description: >
  F-5: fw init seeds .mcp.json with context7 and playwright but not TermLink. TermLink
  MCP is the primary tool for cross-project isolation (Path C). Add termlink mcp serve
  to default MCP config during init. Discovered during T-679.

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [lib/init.sh, lib/upgrade.sh]
related_tasks: []
created: 2026-03-28T21:37:36Z
last_update: '2026-06-11T22:24:27Z'
date_finished: 2026-03-28T22:38:28Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:27Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 4
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=4 
      (body:cross-machine); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-681: Add TermLink MCP server to fw init default MCP config

## Context

`fw init` seeds `.mcp.json` with context7 and playwright but not TermLink. TermLink MCP (`termlink mcp serve`) is the primary tool for cross-project isolation (Path C). Add it to the default config in init and the upgrade reconciliation path.

## Acceptance Criteria

### Agent
- [x] `init.sh` seeds `.mcp.json` with termlink MCP entry using bare `termlink` (PATH-based)
- [x] `upgrade.sh` recommended_servers includes termlink
- [x] `upgrade.sh` defaults dict includes termlink config
- [x] `upgrade.sh` create-from-scratch MCP JSON includes termlink
- [x] Existing projects get termlink added on `fw upgrade` (reconciliation)

## Verification

# init.sh has termlink in the seed MCP JSON
grep -q "termlink" lib/init.sh
# upgrade.sh has termlink in recommended servers
grep -q "termlink" lib/upgrade.sh

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-03-28T21:37:36Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-681-add-termlink-mcp-server-to-fw-init-defau.md
- **Context:** Initial task creation

### 2026-03-28T22:36:58Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-28T22:38:28Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-6cb64a3d
- **Timestamp:** 2026-06-02T15:04:19Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
