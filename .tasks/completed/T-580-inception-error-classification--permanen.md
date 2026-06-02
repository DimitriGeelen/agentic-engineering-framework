---
id: T-580
name: "Inception: Error classification — permanent vs transient separation in healing loop"
description: >
  OpenClaw classifies delivery errors as permanent (chat not found, bot blocked — move to failed/) vs transient (network, 5xx — retry with backoff). This prevents wasting retries on unrecoverable failures. Our healing agent classifies errors by type (code, dependency, environment, design, external) but has no permanent/transient separation — it suggests retry for ALL failures including ones that can never succeed. Investigate: add permanent/transient markers to patterns.yaml entries, healing agent should skip retry suggestions for permanent errors, auto-classify based on error pattern history (same error 3+ times = likely permanent). Research source: docs/reports/T-549-openclaw-value-extraction.md (P6: multi-provider failover with error classification), .context/working/round2-T-016.md on OpenClaw eval project (error classification section). OpenClaw source: src/delivery/delivery-queue.ts (permanent error detection), src/agents/auth-profiles.ts (billing/auth error classification for provider rotation). Related: T-562 (safety guardrails), agents/healing/ (our healing loop implementation).

status: work-completed
workflow_type: inception
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-03-23T21:09:57Z
last_update: 2026-03-28T09:31:57Z
date_finished: 2026-03-28T09:31:57Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
---

# T-580: Inception: Error classification — permanent vs transient separation in healing loop

## Problem Statement

Healing agent classifies errors into 5 types (code, dependency, environment, design, external) but has no permanent vs transient distinction. Suggests retry-based recovery for ALL failures — including ones that can never succeed. See `docs/reports/T-580-error-classification.md` for full analysis.

## Assumptions

1. Permanent/transient distinction would improve healing agent advice quality
2. A single YAML field addition is sufficient (no schema overhaul needed)
3. Existing 11 failure patterns can be backfilled trivially

## Exploration Plan

1. Review healing agent code (diagnose.sh, resolve.sh, patterns.yaml) — DONE
2. Review OpenClaw error classification approach — DONE
3. Assess design options (manual field vs auto-detect vs hybrid) — DONE
4. Go/No-Go decision — DONE

## Technical Constraints

None — this is a YAML schema extension and bash script modification.

## Scope Fence

**IN:** Add `permanence` field, modify diagnose/resolve suggestions, backfill patterns
**OUT:** Auto-detection heuristic (defer to future task), UI changes

## Acceptance Criteria

- [x] Problem statement validated
- [x] Assumptions tested
- [x] Go/No-Go decision made

## Go/No-Go Criteria

**GO if:**
- Clear problem with concrete symptom (retry advice for permanent errors)
- Small bounded scope (2-3 files, 1 new field, backward-compatible)

**NO-GO if:**
- Requires schema overhaul or breaks existing patterns
- No evidence that bad advice is actually being given

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
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

## Decision

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-03-25T15:18:04Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-28T09:31:57Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c8b434fe
- **Timestamp:** 2026-06-02T15:03:41Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
