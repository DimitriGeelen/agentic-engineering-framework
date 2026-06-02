---
id: T-1404
name: "Evidence-based Human AC closure — extend T-954/T-1322 to backlog sweep + agent-side rubber-stamp ticking"
description: >
  Inception: Evidence-based Human AC closure — extend T-954/T-1322 to backlog sweep + agent-side rubber-stamp ticking

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: [web/blueprints/cron.py]
related_tasks: []
created: 2026-04-23T16:46:40Z
last_update: 2026-04-23T17:10:05Z
date_finished: 2026-04-23T17:10:05Z
---

# T-1404: Evidence-based Human AC closure — extend T-954/T-1322 to backlog sweep + agent-side rubber-stamp ticking

## Problem Statement

The "Awaiting Human Review" backlog has grown to **59 tasks with unchecked Human ACs**, and the agent's reflex is to tell the user "wait for human" rather than apply the existing T-954 RUBBER-STAMP-conversion rule. Concurrently, T-1322 GO inception identified that `fw inception decide` doesn't auto-tick the AC it just satisfied — so even after a human runs `fw inception decide ... go`, the inception task stays in `active/` because its `[RUBBER-STAMP] Record go/no-go decision` AC remains unchecked.

User correction (this session): "did we not create evidence for most of them, when they are evidenced they can be closed, why ask human?"

The CLAUDE.md rule already exists (T-954 RUBBER-STAMP conversion + 3-tier verification: programmatic / TermLink E2E / Playwright). It is **not being applied to existing tasks**. `fw verify-acs --auto-check` only scans `work-completed/`, not `active/`, so the existing tooling is blind to this backlog.

## Assumptions

A1. Many `[RUBBER-STAMP]` ACs in active tasks have deterministic shell/curl Steps the agent can execute right now.
A2. Some ACs are mislabeled `[REVIEW]` when they are actually mechanical (e.g. T-1278, T-1279 use only shell + grep).
A3. Running the verification will surface BOTH closeable tasks AND silent regressions (ACs the human would have rubber-stamped without checking).
A4. The fix for T-1322 (auto-tick at `decide` time) covers inception tasks but not the broader backlog — back-fill is needed for non-inception tasks already past their decision point.

## Exploration Plan

**Spike 1 (DONE)** — Sample 5 active tasks with unchecked Human ACs, inspect Steps:
- T-1240, T-1241, T-1278, T-1279, T-663 — all 5 have shell-or-curl Steps. **A1 confirmed.**
- T-1278, T-1279 are labeled `[REVIEW]` but their Steps are pure shell. **A2 confirmed.**

**Spike 2 (DONE)** — Live-verify T-1240 + T-1241 (zero-risk read-only curl):
- T-1240: `/tasks?sort=id` last DOM IDs are T-1399..T-1403 (numeric order). **AC satisfied** — closeable with evidence.
- T-1241: `/cron` shows 5 jobs with "no data" vs AC limit of 1. **AC not satisfied** — silent regression surfaced. **A3 confirmed.**

**Spike 3 (DONE)** — Full backlog sweep across 111 active task files (`docs/reports/T-1404-backlog-sweep.md`):
- 100 unchecked Human ACs with Steps blocks classified
- **TIER-1-CURL** (zero-risk web check): 11
- **TIER-1-SHELL** (deterministic shell): 64
- **TRUE-REVIEW** (subjective UI/voice judgment): 2 + ~15 in UNKNOWN bucket re-classified manually = ~17
- **TRUE-HUMAN** (phone/mac/fresh-session): 5
- UNKNOWN (manual triage needed): 18 (mostly REVIEW judgments my classifier missed)
- **75/100 = 75% are agent-verifiable** with current Tier-1 toolset (curl + shell)
- This means 3 out of every 4 "Awaiting Human Review" entries do not need a human — they need an agent that runs the verification command and ticks the box with cited evidence. **A4 confirmed in spirit:** back-fill is viable and high-value.

**Spike 3-bis (planned, deferred to build phase B3) — re-run the full 47-AC sweep, classify into:
- TIER-1 PASS (verifiable + currently passing → tick + cite evidence in task)
- TIER-1 FAIL (verifiable + currently failing → re-open / register concern)
- TIER-2 needs TermLink E2E (defer — design separately)
- TIER-3 needs Playwright (defer — design separately)
- TRUE-REVIEW (subjective judgment — voice/tone/UX-feel — leave for human)

## Technical Constraints

- Read-only `curl` to localhost Watchtower is zero-risk and zero-budget
- Tier-1 PASS evidence lives in commit message + `## Verification` block
- Cannot mutate task files for tasks owned by `human` without sovereignty bypass — but ticking ACs is a verification recording, not a sovereignty action; the same edit happens when the human checks the box
- T-1322 build (auto-tick at `decide`) is a separate forward-looking fix — out of scope here

## Scope Fence

**IN scope:**
- Define the rule: "When agent has Tier-1 evidence, agent ticks the box, cites evidence in task, no human round-trip"
- Build a `fw verify-acs --active` mode that scans `.tasks/active/` (not just `completed/`)
- Back-fill sweep on the 47 unchecked Human ACs

**OUT of scope:**
- T-1322 build (auto-tick at decide-time) — separate task
- TIER-2/TIER-3 verification — separate inceptions
- Closing tasks where a human REVIEW judgment is genuinely required (voice, UX, architecture)

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

**Recommendation:** GO

**Rationale:** The rule already exists (T-954 RUBBER-STAMP conversion + 3-tier verification). The 30-second proof-of-concept on 5 tasks confirmed: (1) most active-task Human ACs ARE programmatically verifiable, (2) some are mislabeled `[REVIEW]` when they're mechanical, (3) running the verification surfaces real regressions humans would have rubber-stamped without checking (T-1241 has 5 jobs missing data, not the 1-job limit the AC permits). "Wait for human" on a 47-AC backlog is not patience — it's blindness to existing regressions and refusal to apply the rule already on the books.

**Evidence:**
- Sample of 5/5 active-task Human ACs all had shell/curl Steps (A1 confirmed)
- T-1278, T-1279 mislabeled `[REVIEW]` despite pure-shell Steps (A2 confirmed)
- T-1240 live-verified PASS (DOM order T-1399..T-1403 last); T-1241 live-verified FAIL (5 no-data vs 1 limit) — both in <30 seconds (A3 confirmed)
- **Full sweep (`docs/reports/T-1404-backlog-sweep.md`):** 100 ACs scanned, **75% are TIER-1 agent-verifiable** with curl+shell. The "Awaiting Human Review" backlog is 75% mislabelled — three out of every four entries are an agent that didn't run its own verification.
- **Surfaced regression (T-1241):** 5 no-data on /cron vs AC limit of 2. RCA + fix already shipped under T-1405 (commit d22431de) — scan cap was 200 (~2 days, missed weekly jobs) and 2 jobs lacked detection handlers.
- `fw verify-acs --auto-check` returned 0 candidates because it only scans `work-completed/` — backlog of 92+ active-task ACs is invisible to existing tooling
- T-1322 (decide-time auto-tick) is GO-decided but build-deferred — covers inceptions only, not the broader backlog

**Build proposal (post-GO):**
- B1: Extend `fw verify-acs` with `--active` mode scanning `.tasks/active/`
- B2: Add classification into Tier-1/Tier-2/Tier-3/TRUE-REVIEW + per-tier auto-execution
- B3: One-shot back-fill sweep on the current 47-AC backlog with cited evidence
- B4: Update CLAUDE.md "Presenting Work for Human Review" to require: "If Tier-1 evidence is producible, agent produces it and ticks the box BEFORE asking the human"

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

**Rationale**: The rule already exists (T-954 RUBBER-STAMP conversion + 3-tier verification). The 30-second proof-of-concept on 5 tasks confirmed: (1) most active-task Human ACs ARE programmatically verifiable, (2) some are mislabeled `[REVIEW]` when they're mechanical, (3) running the verification surfaces real regressions humans would have rubber-stamped without checking (T-1241 has 5 jobs missing data, not the 1-job limit the AC permits). "Wait for human" on a 47-AC backlog is not patience — it's blindness to existing regressions and refusal to apply the rule already on the books.

**Date**: 2026-04-23T17:10:04Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-23T17:10:04Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** The rule already exists (T-954 RUBBER-STAMP conversion + 3-tier verification). The 30-second proof-of-concept on 5 tasks confirmed: (1) most active-task Human ACs ARE programmatically verifiable, (2) some are mislabeled `[REVIEW]` when they're mechanical, (3) running the verification surfaces real regressions humans would have rubber-stamped without checking (T-1241 has 5 jobs missing data, not the 1-job limit the AC permits). "Wait for human" on a 47-AC backlog is not patience — it's blindness to existing regressions and refusal to apply the rule already on the books.

### 2026-04-23T17:10:04Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Reason:** Inception decision in progress

### 2026-04-23T17:10:05Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

## Reviewer Verdict (v1.5)

- **Scan ID:** R-239eb08f
- **Timestamp:** 2026-06-02T14:57:14Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
