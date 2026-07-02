---
id: T-1290
name: "Rewrite _watchtower_url as 3-layer discovery (T-1284 B3)"
description: >
  Rewrite _watchtower_url as 3-layer discovery (T-1284 B3)

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [lib/watchtower.sh]
related_tasks: []
created: 2026-04-17T20:27:14Z
last_update: '2026-06-11T22:23:44Z'
date_finished: 2026-04-18T08:52:14Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:44Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 1
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=1 
      (body:error-msg-improved); D4=0 (no-signal); F-RECALL=0 (no-signal); 
      F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1290: Rewrite _watchtower_url as 3-layer discovery (T-1284 B3)

## Context

B3 of T-1284 (the actual bug fix). Replace the 4-fallback port probe
in `_watchtower_url` (which picked :8080/Open WebUI when it answered
arbitrary paths) with a 3-layer discovery that is deterministic and
safe:

1. **Layer 1 — triple:** Read `.pid/.port/.url` (written by B2).
   Verify pid alive + verify pid listens on that port. Return url.
2. **Layer 2 — identity:** For configured port(s), call
   `/api/_identity` (B1). Match only if `service=="watchtower"` AND
   `project_root` equals our project root. Return matching url.
3. **Layer 3 — fail loud:** No match → stderr message + exit 1.
   No arbitrary port probing, no task-path probing.

Preserves existing public signature: stdout URL on success, exit 1
on failure. `WATCHTOWER_URL` env override still respected.

## Acceptance Criteria

### Agent
- [x] When valid triple exists + pid alive + identity matches:
      `_watchtower_url` returns the `.url` contents without probing
- [x] When triple is missing/stale: falls through to Layer 2 identity
      handshake; returns matching url only when `service==watchtower`
      AND `project_root` equals current project root
- [x] When no Watchtower reachable: writes actionable error to stderr
      ("No Watchtower reachable. Start one with: fw serve" or similar)
      and exits non-zero — does NOT return a URL to a masquerader
- [x] Existing `WATCHTOWER_URL` env var still takes precedence
      (fast path unchanged)
- [x] With Open WebUI (:8080) running + Watchtower NOT running,
      function exits non-zero (never returns :8080). This is the
      T-1284 regression test. (Verified by simulating stale PID
      + wrong config port; function returned exit 1 with no url.)

## Verification

# Static checks on lib/watchtower.sh — 3-layer discovery is present.
grep -q '_wt_identity_matches' lib/watchtower.sh
grep -q 'watchtower\.url' lib/watchtower.sh
grep -q 'No Watchtower reachable' lib/watchtower.sh
bash -n lib/watchtower.sh

# Regression: even if we point WATCHTOWER_URL at the wrong port, env wins fast-path.
WATCHTOWER_URL=http://example.invalid:9999 bash -c 'source lib/watchtower.sh; _watchtower_url' | grep -q '^http://example.invalid:9999$'

# Regression test suite (B6) locks the fix in.
bats tests/unit/lib_watchtower.bats

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

### 2026-04-17T20:27:14Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1290-rewrite-watchtowerurl-as-3-layer-discove.md
- **Context:** Initial task creation

### 2026-04-18T08:52:14Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-61320628
- **Timestamp:** 2026-06-02T14:56:28Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 8
     - evidence: `WATCHTOWER_URL=http://example.invalid:9999 bash -c 'source lib/watchtower.sh; _watchtower_url' | grep -q '^http://example.invalid:9999$'`
