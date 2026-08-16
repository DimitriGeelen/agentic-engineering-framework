---
id: T-1539
name: "Validate review-workflow arc via blind TermLink reviewer — independent E2E
  walkthrough"
description: >
  Validate review-workflow arc via blind TermLink reviewer — independent E2E walkthrough

status: work-completed
workflow_type: test
owner: human
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-27T12:10:17Z
last_update: '2026-08-16T22:24:36Z'
date_finished: 2026-04-27T12:18:49Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:51Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 2
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 1
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=2 
      (body:telemetry-or-audit-entry); D3=0 (no-signal); D4=0 (no-signal); 
      F-RECALL=2 (body:lightly-promoted); F-ORCH=1 (body:hand-wired-dispatch); 
      F3=1 (body/components:prompt-incidental); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:36Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 2
      D3: 0
      D4: 0
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=2 
      (body:telemetry-or-audit-entry); D3=0 (no-signal); D4=0 (no-signal); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1539: Validate review-workflow arc via blind TermLink reviewer — independent E2E walkthrough

## Context

The review-workflow arc T-1530 → T-1537 surfaced agent recommendation verdicts (GO/DEFER/NO-GO/?) across 8 surfaces (handover markdown, Watchtower /approvals badges + filter buttons, landing-page pills, /approvals inception cards, fw review-queue CLI). Synthetic and Playwright tests guard the wiring. **What we have NOT done is independent E2E validation by a fresh agent that doesn't carry our session's anchoring biases.**

This task dispatches a fresh `claude -p` worker via `fw termlink dispatch` (zero-context-cost, isolated) with a read-only walkthrough prompt. The worker visits each verdict surface and writes a structured findings report to `docs/reports/T-1539-blind-reviewer-walkthrough.md`. The findings get harvested back into learnings or follow-up tasks.

This is the antifragility principle in action: false success in UX is structurally worse than acknowledged friction. A blind reviewer surfaces friction that synthetic tests cannot.

## Acceptance Criteria

### Agent
- [x] Dispatched a TermLink worker named `tl-blind-reviewer` with a self-contained prompt
- [x] Worker visits all 4 surfaces: handover markdown, /approvals page, fw review-queue CLI, /review/T-XXX page for a real recently-completed task
- [x] Worker writes findings to `docs/reports/T-1539-blind-reviewer-walkthrough.md` (NOT /tmp — T-818 rule)
- [x] Worker exits with code 0 within timeout (3 min wall)
- [x] Findings file exists (6.4KB) and contains a structured "Worked / Didn't Work / Missing" summary
- [x] At least one concrete observation, learning, or follow-up task is captured back into the framework based on findings (2 bug fixes shipped + 2 learnings captured: L-295 blind-reviewer dispatch pattern, L-296 conditional-rendering false-positive heuristic)

### Human
- [x] [REVIEW] The blind-reviewer findings reflect a credible independent walkthrough (not just template-completion)
  **Steps:**
  1. `cat docs/reports/T-1539-blind-reviewer-walkthrough.md`
  2. Verify the agent identified specifics: which task IDs it inspected, which verdicts it saw, any UX friction
  3. Cross-check 1-2 of the agent's observations against your own quick visit to /approvals
  **Expected:** Findings cite specific task IDs and verdict counts that match reality; observations are actionable, not generic
  **If not:** Re-dispatch with a more focused prompt or note where the agent went generic

## Verification

# Worker artifact exists and is non-trivial
test -s docs/reports/T-1539-blind-reviewer-walkthrough.md
test "$(wc -l < docs/reports/T-1539-blind-reviewer-walkthrough.md)" -ge 20
# Findings file mentions all 4 surfaces (lowercase grep — agent may use different headings)
grep -qi "approvals" docs/reports/T-1539-blind-reviewer-walkthrough.md
grep -qi "review-queue\|review queue" docs/reports/T-1539-blind-reviewer-walkthrough.md
grep -qi "handover" docs/reports/T-1539-blind-reviewer-walkthrough.md
grep -qi "verdict" docs/reports/T-1539-blind-reviewer-walkthrough.md
# Worker session is cleaned up (no orphan sessions tagged blind-reviewer)
! termlink list 2>/dev/null | grep -q "tl-blind-reviewer.*ready"

## Decisions

### 2026-04-27 — Use fw termlink dispatch for the blind reviewer (not Task-tool sub-agent)
- **Chose:** `fw termlink dispatch --task T-1539 --name tl-blind-reviewer --prompt-file .context/working/.t1539-prompt.md --timeout 600 --model claude-sonnet-4-6` — spawns a fresh `claude -p` worker in an isolated tmux session with zero parent-context cost.
- **Why:** The blind reviewer must have NO context from this session to be useful. A Task-tool sub-agent would inherit the parent's context and bias. TermLink dispatch is the structurally-isolated alternative — independent process, observable, survives parent compaction. Per CLAUDE.md §Sub-Agent Dispatch Protocol: "If the work is heavy parallel and benefits from isolation, use TermLink dispatch." Single agent + heavy isolation justifies dispatch over Task tool.
- **Rejected:** Spawn via plain `claude -p` directly without TermLink: would lose observability + cleanup tracking. Task-tool sub-agent: would defeat the "blind" property.

### 2026-04-27 — Findings triaged: 2 real bugs fixed, 1 false positive logged
- **Real bug 1 (FIXED):** `fw review-queue` footer printed `http://localhost:{port}/approvals`. Replaced with `.context/working/watchtower.url` triple-file lookup with localhost:port fallback. CLAUDE.md §Watchtower Port anti-pattern (T-1376) — agent in T-1536 introduced exactly the violation the rule warns against, despite the rule existing.
- **Real bug 2 (FIXED):** `/review/T-XXX` recommendation block rendered amber regardless of verdict. Added `data-verdict="..."` attribute to the section + per-verdict CSS attribute selectors (green=GO, amber=DEFER, red=NO-GO). Verified live with T-1531 (verdict=GO → green styling).
- **False positive (LOGGED):** Reviewer flagged "no NO-GO filter button on /approvals" — but the button is correctly conditionally rendered on `{% if nogo_count %}` (template line 224), same pattern as GO/DEFER. No NO-GO tasks today → no button rendered. Captured as L-296 (heuristic for distinguishing absent-because-hidden from absent-because-broken in future blind-reviewer prompts).

## Recommendation

**Recommendation:** GO

**Rationale:** Blind-reviewer dispatch surfaced 2 real bugs in T-1530-T-1537 work that synthetic tests missed, both fixed inline (localhost hardcode in fw review-queue footer; uniform amber colour on /review). 1 false positive correctly classified and captured as a learning to refine future reviewer prompts. The arc is now validated end-to-end on all 4 surfaces with corrections shipped. Cost: ~3 min wall, isolated worker context (zero parent-context budget impact). High leverage validation pattern worth codifying — captured as L-295.

**Evidence:**
- `docs/reports/T-1539-blind-reviewer-walkthrough.md` (6.4KB structured findings; 4 surfaces walked; cross-check counts table)
- `bin/fw` lines 3425-3436: footer URL now reads triple-file
- `web/blueprints/review.py` lines 157-161: verdict extracted via canonical helper
- `web/templates/review.html` lines 248-263: per-verdict CSS attribute selectors
- L-295 (blind-reviewer dispatch pattern) + L-296 (conditional-rendering false-positive heuristic) captured
- All P-011 verification commands pass on retest

## Updates

### 2026-04-27T12:10:17Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1539-validate-review-workflow-arc-via-blind-t.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-71a5c466
- **Timestamp:** 2026-06-02T14:58:10Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 10
     - evidence: `! termlink list 2>/dev/null | grep -q "tl-blind-reviewer.*ready"`
### 2026-04-27T12:18:49Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
