---
id: T-1518
name: "Approvals page: surface deferred inception count when no pending decisions"
description: >
  Approvals page: surface deferred inception count when no pending decisions

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [web/blueprints/approvals.py, web/templates/_approvals_content.html]
related_tasks: []
created: 2026-04-26T21:12:48Z
last_update: '2026-08-16T22:24:35Z'
date_finished: 2026-04-26T21:14:53Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:50Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 1
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:learning-ref); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=1 (body:episodic-only); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:35Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 1
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:learning-ref); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=1 (body:episodic-only); 
      F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1518: Approvals page: surface deferred inception count when no pending decisions

## Context

After T-1517 fixed handover wording, /approvals correctly shows 0 pending decisions because all 10 active inceptions are DEFER'd — but /approvals gives no exit ramp to /inception?decision=defer where DEFER'd ones live. Small UX fix: when /approvals has 0 pending decisions, render a one-line hint with the deferred count linking to the inception board.

## Acceptance Criteria

### Agent
- [x] `_build_approvals_context()` returns a `deferred_count` integer counting active inceptions with `**Decision**: DEFER`
- [x] /approvals template renders a hint linking to /inception?decision=defer when (no pending Tier 0) AND (no pending GO/NO-GO) AND (deferred_count > 0)
- [x] Hint is omitted when there ARE pending decisions OR deferred_count == 0
- [x] Smoke verified: curl /approvals/content shows the hint markup; count matches active inceptions tagged DEFER

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [x] [REVIEW] Dashboard renders correctly
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

# deferred_count threaded into context
grep -q "deferred_count" web/blueprints/approvals.py
# Hint rendered in template
grep -q "decision=defer" web/templates/_approvals_content.html
# Smoke: live page contains the hint when no pending and >0 deferred
curl -sf "$(bin/fw watchtower url)/approvals/content" -o /tmp/T-1518-approvals.html
grep -qE "deferred|Deferred" /tmp/T-1518-approvals.html
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).

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

### 2026-04-26T21:12:48Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1518-approvals-page-surface-deferred-inceptio.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-3247552a
- **Timestamp:** 2026-06-02T14:58:01Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-26T21:14:53Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Hint live on /approvals; smoke verified
