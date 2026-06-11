---
id: T-1354
name: "fw init generates .mcp.json without mcpServers wrapper — fails MCP schema validation"
description: >
  fw init generates .mcp.json without mcpServers wrapper — fails MCP schema validation

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [bin/fw, lib/init.sh, lib/upgrade.sh]
related_tasks: []
created: 2026-04-20T07:59:39Z
last_update: '2026-06-11T22:23:46Z'
date_finished: 2026-04-20T09:23:26Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:46Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 3
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=3 (body:portability-abstraction); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1354: fw init generates .mcp.json without mcpServers wrapper — fails MCP schema validation

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] `lib/init.sh` .mcp.json template wraps server definitions under `"mcpServers": {...}`
- [x] `lib/upgrade.sh` CREATE path uses same wrapped schema
- [x] `lib/upgrade.sh` MERGE path reads and writes the `mcpServers` key (preserves existing user servers under the wrapper)
- [x] `bin/fw` doctor check reads servers from `mcpServers` key
- [x] `fw init /tmp/new-project` generates schema-valid file; `fw upgrade /tmp/new-project` is idempotent (no change) when already valid
- [x] `fw doctor` shows OK for the generated file

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.

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

### 2026-04-20T07:59:39Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1354-fw-init-generates-mcpjson-without-mcpser.md
- **Context:** Initial task creation

### 2026-04-20T09:23:26Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-6d073a0b
- **Timestamp:** 2026-06-02T14:56:54Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 3

**Per-AC findings:**

- **AC#1 (Agent)** — `lib/init.sh` .mcp.json template wraps server definitions under `"mcpServers": {...}`
  - **AC-verify-mismatch** (narrow, heuristic) — `path=lib/init.sh in: `lib/init.sh` .mcp.json template wraps server definitions under `"mcpServers": {...}``
- **AC#2 (Agent)** — `lib/upgrade.sh` CREATE path uses same wrapped schema
  - **AC-verify-mismatch** (narrow, heuristic) — `path=lib/upgrade.sh in: `lib/upgrade.sh` CREATE path uses same wrapped schema`
- **AC#3 (Agent)** — `lib/upgrade.sh` MERGE path reads and writes the `mcpServers` key (preserves existing user servers under the wrapper)
  - **AC-verify-mismatch** (narrow, heuristic) — `path=lib/upgrade.sh in: `lib/upgrade.sh` MERGE path reads and writes the `mcpServers` key (preserves existing user servers under the wrapper)`
