---
id: T-1672
name: "Update Watchtower /arcs/<id> close-instructions block to reflect T-1668 (--demo
  required) + T-1671 (CLAUDECODE refusal + override flags)"
description: >
  Update Watchtower /arcs/<id> close-instructions block to reflect T-1668 (--demo
  required) + T-1671 (CLAUDECODE refusal + override flags)

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [web/templates/arc_detail.html]
related_tasks: []
arc_id: orchestrator-rethink
created: 2026-05-02T07:46:38Z
last_update: '2026-06-11T22:23:55Z'
date_finished: 2026-05-02T07:48:53Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:55Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1672: Update Watchtower /arcs/<id> close-instructions block to reflect T-1668 (--demo required) + T-1671 (CLAUDECODE refusal + override flags)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] `web/templates/arc_detail.html` close-instructions block shows
      `--demo <path>` argument (T-1668 gate requirement)
- [x] Block names §ACD/G-062, links T-1668 / T-1671 inline
- [x] Block lists override flags (`--i-am-human`, `--from-watchtower`)
      with their CLAUDECODE semantics
- [x] Block surfaces `arc.demo_evidence` if already populated (preserved
      from prior aborted close attempts) so the reviewer can see the
      candidate evidence without leaving the page
- [x] Existing arc-detail tests still pass:
      `pytest tests/unit/test_arcs_routes.py -q`
- [x] Live: GET /arcs/orchestrator-rethink renders the new block,
      including `--demo` and the override-flags note

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

python3 -m pytest tests/unit/test_arcs_routes.py -q
bash -c 'curl -sf http://localhost:3000/arcs/orchestrator-rethink | grep -q -- "--demo "'
bash -c 'curl -sf http://localhost:3000/arcs/orchestrator-rethink | grep -q -- "--from-watchtower"'
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).

## RCA

<!-- REQUIRED for bug-class tasks (workflow_type=build with bug-tag, OR title matches
     fix/bug/rca/broken/crash/error/regression/fail/hotfix).
     Non-bug-class tasks may leave this section empty or remove it.

     For bug-class, fill in:
       **Symptom:** what was observed (the user-facing manifestation).
       **Root cause:** the specific structural/logical gap — not "the code was wrong".
       **Why structurally allowed:** what in the framework/code/tooling let this go undetected.
       **Prevention:** what catches the next instance (test/lint/gate/doc/learning) — distinct from the fix itself.

     The completion gate (T-1550, G-019) blocks --status work-completed when
     bug-class AND this section is empty/template-only. Use --skip-rca to bypass (logged).
-->

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

### 2026-05-02T07:46:38Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1672-update-watchtower-arcsid-close-instructi.md
- **Context:** Initial task creation

### 2026-05-02T07:48:20Z — status-update [task-update-agent]
- **Change:** tags: +arc:orchestrator-rethink

## Reviewer Verdict (v1.5)

- **Scan ID:** R-be7d0163
- **Timestamp:** 2026-06-02T14:59:02Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 3

**Per-AC findings:**

- **AC#1 (Agent)** — `web/templates/arc_detail.html` close-instructions block shows
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/templates/arc_detail.html in: `web/templates/arc_detail.html` close-instructions block shows`

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `bash -c 'curl -sf http://localhost:3000/arcs/orchestrator-rethink | grep -q -- "--demo "'`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 3
     - evidence: `bash -c 'curl -sf http://localhost:3000/arcs/orchestrator-rethink | grep -q -- "--from-watchtower"'`
### 2026-05-02T07:48:53Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
