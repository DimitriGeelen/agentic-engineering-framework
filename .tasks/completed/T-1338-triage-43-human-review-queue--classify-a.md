---
id: T-1338
name: "Triage 43 human review queue — classify automatable (programmatic/TermLink E2E/Playwright) vs genuine-human, recommend build tasks"
description: >
  Inception: Triage 43 human review queue — classify automatable (programmatic/TermLink E2E/Playwright) vs genuine-human, recommend build tasks

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-19T16:26:30Z
last_update: 2026-04-19T23:47:01Z
date_finished: 2026-04-19T23:47:01Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
---

# T-1338: Triage 43 human review queue — classify automatable (programmatic/TermLink E2E/Playwright) vs genuine-human, recommend build tasks

## Problem Statement

Watchtower review queue has 43 unchecked Human ACs across 41 tasks. Most are either (a) subjective judgment that cannot be automated, or (b) mechanical checks the human does by hand because no harness exists. We don't know today which bucket each AC is in. Question: which of the 43 can be moved to an automated tier (programmatic / TermLink E2E / Playwright) without shifting decision authority away from the human?

Full analysis: `docs/reports/T-1338-review-queue-automation-triage.md`.

## Assumptions

1. `fw verify-acs` already distinguishes `[RUBBER-STAMP]` vs `[REVIEW]` — VERIFIED
2. Tier 1 ACs can be auto-ticked via `fw verify-acs --execute` — VERIFIED (T-840 infra exists)
3. Playwright harness (`tests/playwright/`) and TermLink dispatch infra are ready — VERIFIED (fw test playwright command exists; `fw termlink dispatch` exists)
4. Framework authority model forbids automating strategic go/no-go — VERIFIED (CLAUDE.md "Agent proposes, human decides")

## Exploration Plan

Completed (see research artifact):
- **A** — Dump all 43 ACs via `fw verify-acs -v`
- **B** — Sample representative ACs for Steps/Expected text to confirm automatability
- **C** — Classify each: Tier 1 (shell) / Tier 2 (TermLink) / Tier 3 (Playwright) / Tier H (genuine human)
- **D** — Bundle automatable ACs into bounded build tasks

## Technical Constraints

- Tier 2 ACs requiring macOS need a reachable Mac host via TermLink (ring20-management .122 or 050 is available)
- Playwright tests run via `fw test playwright` (pytest + playwright already installed)
- Some Tier 2 ACs (T-1277) require pushing context budget — can stub via `FW_CONTEXT_WINDOW` override

## Scope Fence

**IN:** classify each of the 43 unchecked Human ACs; decide whether to build B1/B2/B3 automation harnesses.
**OUT:** implementing the harnesses (that's follow-on build task if GO); promoting unchecked ACs that depend on human judgment.

## Acceptance Criteria

### Agent
- [x] Problem statement validated (43 ACs enumerated, representative samples read)
- [x] Assumptions tested (framework primitives for all three tiers confirmed)
- [x] Recommendation written with rationale (GO, B1→B2→B3 staging; 13 of 43 automatable = 30%)

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

**Recommendation:** GO — build B1 (Tier 1 extension), B2 (Playwright bundle), B3 (TermLink E2E harness) in that order.

**Rationale:** Of the 43 unchecked Human ACs, 13 (30%) can move to automated verification without shifting decision authority. The remaining 30 are either strategic go/no-go decisions (21), subjective voice/tone/quality judgments (7), or physical-device verifications (2) — all genuinely human. Framework primitives for all three automation tiers already exist (`fw verify-acs --execute`, `fw test playwright`, `fw termlink dispatch`). The blocker is harness authorship, not capability.

**Evidence:**
- Full classification table: `docs/reports/T-1338-review-queue-automation-triage.md` (Tier 1: 1, Tier 2: 8, Tier 3: 4, Tier H: 30)
- B1 is near-trivial (rewrite T-880 AC with verification command → auto-ticked by existing `fw verify-acs --execute`)
- B2 covers 4 ACs in one Playwright file (T-1240 sort, T-1241 cron data, T-1214 approvals cards, T-448.1 cron controls) — highest coverage-per-effort
- B3 groups by host: Linux TermLink set (T-594, T-612, T-663, T-1277) + macOS set via ring20-management (T-481, T-518, T-613) + PTY attach (T-530)
- Authority model preserved: every `[REVIEW]` on a go/no-go decision stays Tier H — we are automating mechanical verifications, not strategic choices
- T-971 playwright test generation rule already established the pattern; B2 is its canonical first bundle

**Structural upgrade option (separate from GO decision):** propose an `[AUTO]` AC tag to replace today's informal `[RUBBER-STAMP]` when the Steps section contains only deterministic commands. Signals to the human that no action is required — framework verifies automatically. Keep `[RUBBER-STAMP]` for mechanical actions that still need a human (publishing, physical device testing). Keep `[REVIEW]` for subjective judgment.

**Go/No-Go criteria:** both met — classification is defensible (each tier assignment cites concrete command or locator), build tasks are bounded (one file per tier), authority model preserved.

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

**Rationale**: Recommendation: GO — build B1 (Tier 1 extension), B2 (Playwright bundle), B3 (TermLink E2E harness) in that order.

Rationale: Of the 43 unchecked Human ACs, 13 (30%) can move to automated verification without shifting decision authority. The remaining 30 are either strategic go/no-go decisions (21), subjective voice/tone/quality judgments (7), or physical-device verifications (2) — all genuinely human. Framework primitives for all three automation tiers already exist (`fw verify-acs --execute`, `fw test playwright`, `fw termlink dispatch`). The blocker is harness authorship, not capability.

Evidence:
- Full classification table: `docs/reports/T-1338-review-queue-automation-triage.md` (Tier 1: 1, Tier 2: 8, Tier 3: 4, Tier H: 30)
- B1 is near-trivial (rewrite T-880 AC with verification command → auto-ticked by existing `fw verify-acs --execute`)
- B2 covers 4 ACs in one Playwright file (T-1240 sort, T-1241 cron data, T-1214 approvals cards, T-448.1 cron controls) — highest coverage-per-effort
- B3 groups by host: Linux TermLink set (T-594, T-612, T-663, T-1277) + macOS set via ring20-management (T-481, T-518, T-613) + PTY attach (T-530)
- Authority model preserved: every `[REVIEW]` on a go/no-go decision stays Tier H — we are automating mechanical verifications, not strategic choices
- T-971 playwright test generation rule already established the pattern; B2 is its canonical first bundle

Structural upgrade option (separate from GO decision): propose an `[AUTO]` AC tag to replace today's informal `[RUBBER-STAMP]` when the Steps section contains only deterministic commands. Signals to the human that no action is required — framework verifies automatically. Keep `[RUBBER-STAMP]` for mechanical actions that still need a human (publishing, physical device testing). Keep `[REVIEW]` for subjective judgment.

Go/No-Go criteria: both met — classification is defensible (each tier assignment cites concrete command or locator), build tasks are bounded (one file per tier), authority model preserved.

**Date**: 2026-04-19T23:47:01Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-19T16:27:13Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-19T23:47:01Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO — build B1 (Tier 1 extension), B2 (Playwright bundle), B3 (TermLink E2E harness) in that order.

Rationale: Of the 43 unchecked Human ACs, 13 (30%) can move to automated verification without shifting decision authority. The remaining 30 are either strategic go/no-go decisions (21), subjective voice/tone/quality judgments (7), or physical-device verifications (2) — all genuinely human. Framework primitives for all three automation tiers already exist (`fw verify-acs --execute`, `fw test playwright`, `fw termlink dispatch`). The blocker is harness authorship, not capability.

Evidence:
- Full classification table: `docs/reports/T-1338-review-queue-automation-triage.md` (Tier 1: 1, Tier 2: 8, Tier 3: 4, Tier H: 30)
- B1 is near-trivial (rewrite T-880 AC with verification command → auto-ticked by existing `fw verify-acs --execute`)
- B2 covers 4 ACs in one Playwright file (T-1240 sort, T-1241 cron data, T-1214 approvals cards, T-448.1 cron controls) — highest coverage-per-effort
- B3 groups by host: Linux TermLink set (T-594, T-612, T-663, T-1277) + macOS set via ring20-management (T-481, T-518, T-613) + PTY attach (T-530)
- Authority model preserved: every `[REVIEW]` on a go/no-go decision stays Tier H — we are automating mechanical verifications, not strategic choices
- T-971 playwright test generation rule already established the pattern; B2 is its canonical first bundle

Structural upgrade option (separate from GO decision): propose an `[AUTO]` AC tag to replace today's informal `[RUBBER-STAMP]` when the Steps section contains only deterministic commands. Signals to the human that no action is required — framework verifies automatically. Keep `[RUBBER-STAMP]` for mechanical actions that still need a human (publishing, physical device testing). Keep `[REVIEW]` for subjective judgment.

Go/No-Go criteria: both met — classification is defensible (each tier assignment cites concrete command or locator), build tasks are bounded (one file per tier), authority model preserved.

### 2026-04-19T23:47:01Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

## Reviewer Verdict (v1.5)

- **Scan ID:** R-7b471802
- **Timestamp:** 2026-06-02T14:56:48Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
