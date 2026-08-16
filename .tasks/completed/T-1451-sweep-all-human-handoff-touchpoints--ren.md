---
id: T-1451
name: "Sweep all human-handoff touchpoints — render clickable Watchtower URLs everywhere
  agent surfaces work for human"
description: >
  Audit every code path + agent output template where the agent hands work to the
  human (Human ACs pending, inception decision, Tier 0 approval, gap acknowledgement,
  observation triage, pickup processing, pending-update reminders, handover Suggested-First-Action).
  Each surface should render the corresponding Watchtower URL clickably (e.g. $URL/review/T-XXX,
  $URL/inception/T-XXX, $URL/approvals, $URL/reviewer/overrides). Triggered by user
  feedback 2026-04-25 — agent listed task IDs only, friction caused human to ask for
  links explicitly. Goal: zero-friction review queue.

status: work-completed
workflow_type: inception
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-25T11:29:09Z
last_update: '2026-08-16T22:24:33Z'
date_finished: 2026-04-25T14:01:37Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:48Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:33Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-AUTONOMY=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1451: Sweep all human-handoff touchpoints — render clickable Watchtower URLs everywhere agent surfaces work for human

## Problem Statement

User feedback 2026-04-25: agent listed `T-1445/46/47/48/49/50 each have one [REVIEW]` without rendering URLs — friction caused human to ask for links explicitly. Goal: zero-friction review queue. Rule already codified in agent feedback memory (feedback_human_review_links.md). This task closes the structural side: which output surfaces still surface bare task IDs?

## Audit findings (this session)

Surveyed all human-facing output paths. Surfaces that ALREADY render URLs:
- `agents/context/check-tier0.sh:372,405` — Tier 0 prompts include `${WT_URL}/approvals`
- `lib/review.sh:49,52` — `fw task review` prints `${URL}/review/T-XXX` or `/inception/T-XXX`
- `lib/verify-acs.sh:330` — prints `http://{ip}:{wt_port}/approvals`

Surfaces that DO NOT render URLs (the gap):
- **`agents/handover/handover.sh`** — three sections list bare `T-XXX` without URL:
  1. "Awaiting Human Review (N tasks)" inside Work in Progress (line 477-479, 513-515)
  2. "Awaiting Your Action (Human)" full section (line 570-578)
  3. Observation inbox listings (line 587+)
- `agents/handover/handover.sh` does not resolve the Watchtower URL at all (`grep WT_URL` returns nothing)
- "Inception Phases" section in handover output also lists task IDs only

The handover is the **highest-traffic gap** — it loads at every session start via `/resume`, and 28 Human ACs + 18 inception decisions are listed every time, all without URLs.

## Scope Fence

**IN scope (proposed):**
- Inject `WT_URL=$(...)` resolution at top of handover.sh
- Pass URL into the Python heredocs (lines 477, 513, 570) and render `[T-XXX](${URL}/review/T-XXX)` markdown links
- Inception Phases listing: render `[T-XXX](${URL}/inception/T-XXX)` for pending decisions
- Update observation listing to render `[OBS-NNN](${URL}/observations)` if such a page exists (or skip if not)

**OUT of scope:**
- Sweep of agents/audit/*, agents/healing/* — those are diagnostic outputs, less frequent
- Restructuring the handover format itself
- New Watchtower pages (e.g. /observations) — separate task

## Exploration Plan

Already executed via the audit above (one session). No further spikes needed.

## Acceptance Criteria

### Agent
- [x] Audit of all human-handoff surfaces captured (above)
- [x] Gap localized to `agents/handover/handover.sh` (3 sections + 1 missing URL resolver)
- [x] Recommendation written
- [x] [Inception decision recorded] go/no-go/defer with chosen scope (handover-only vs broader sweep) — GO recorded 2026-04-25T14:01:15Z by human

## Acceptance Criteria

### Agent
- [x] Problem statement validated
- [x] Assumptions tested
- [x] Recommendation written with rationale

### Human
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

<!-- Fill these BEFORE writing the recommendation. The placeholder detector will block review/decide if left empty. -->
**GO if:**
- Root cause identified with bounded fix path
- Fix is scoped, testable, and reversible

**NO-GO if:**
- Problem requires fundamental redesign or unbounded scope
- Fix cost exceeds benefit given current evidence

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).

## Recommendation

**Recommendation:** GO with **handover-only scope** (single build task, ~30 minutes).

**Rationale:** The audit revealed that the handover output IS the gap — every other human-facing surface (Tier 0, fw task review, verify-acs) already renders URLs. The handover is also the highest-traffic surface (loaded via `/resume` at every session start, 28+46 task references per render). Other surfaces (audit, healing, fw note list) are lower-traffic and can be addressed if/when they cause friction. Doing the handover scope alone removes ~80% of the visible friction at low risk.

**Evidence:**
- 3 named gaps in `agents/handover/handover.sh` lines 477, 513, 570 — all in Python heredocs that print bare `**T-XXX**: name`
- No existing WT_URL resolution in handover.sh — first-time addition
- Comparable pattern already exists in `lib/review.sh:42-52` for URL construction (resolve port via `bin/fw watchtower url`)
- Resolved feedback rule (feedback_human_review_links.md) already covers WHEN to render — this just covers WHERE

**Out-of-scope follow-up candidates (track separately if friction recurs):**
- `agents/audit/audit.sh` — append `${WT_URL}/inception/T-XXX` to inception-related findings
- `agents/healing/healing.sh` — already prints task IDs in diagnostics
- `bin/fw note list` output — render `${WT_URL}/inception/T-XXX` for promoted observations

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

**Decision**: GO

**Rationale**: The audit revealed that the handover output IS the gap — every other human-facing surface (Tier 0, fw task review, verify-acs) already renders URLs. The handover is also the highest-traffic surface (loaded via `/resume` at every session start, 28+46 task references per render). Other surfaces (audit, healing, fw note list) are lower-traffic and can be addressed if/when they cause friction. Doing the handover scope alone removes ~80% of the visible friction at low risk.

**Date**: 2026-04-25T14:01:15Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-25T13:09:53Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** The audit revealed that the handover output IS the gap — every other human-facing surface (Tier 0, fw task review, verify-acs) already renders URLs. The handover is also the highest-traffic surface (loaded via `/resume` at every session start, 28+46 task references per render). Other surfaces (audit, healing, fw note list) are lower-traffic and can be addressed if/when they cause friction. Doing the handover scope alone removes ~80% of the visible friction at low risk.

### 2026-04-25T14:01:15Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** The audit revealed that the handover output IS the gap — every other human-facing surface (Tier 0, fw task review, verify-acs) already renders URLs. The handover is also the highest-traffic surface (loaded via `/resume` at every session start, 28+46 task references per render). Other surfaces (audit, healing, fw note list) are lower-traffic and can be addressed if/when they cause friction. Doing the handover scope alone removes ~80% of the visible friction at low risk.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-98e83ee6
- **Timestamp:** 2026-06-02T14:57:34Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#2 (Agent)** — Gap localized to `agents/handover/handover.sh` (3 sections + 1 missing URL resolver)
  - **AC-verify-mismatch** (narrow, heuristic) — `path=agents/handover/handover.sh in: Gap localized to `agents/handover/handover.sh` (3 sections + 1 missing URL resolver)`
### 2026-04-25T14:01:37Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
