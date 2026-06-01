---
id: T-1538
name: "Pickup: Add canonical-doc approval surface to Watchtower /approvals page (4th category alongside Tier-0 / inception / human-AC) (from 003-NTB-ATC-Plugin)"
description: >
  Auto-created from pickup envelope. Source: 003-NTB-ATC-Plugin, task T-210. Type: feature-proposal.

status: work-completed
workflow_type: inception
owner: agent
horizon: null
tags: [pickup, feature-proposal]
components: [bin/fw, lib/review.sh, web/blueprints/cockpit.py, web/templates/_approvals_content.html, web/templates/cockpit.html]
related_tasks: []
created: 2026-04-27T11:36:01Z
last_update: 2026-04-28T11:56:18Z
date_finished: 2026-04-28T11:56:18Z
source_task_id_in_origin: T-210
source_project_in_origin: "003-NTB-ATC-Plugin"
---

# T-1538: Pickup: Add canonical-doc approval surface to Watchtower /approvals page (4th category alongside Tier-0 / inception / human-AC) (from 003-NTB-ATC-Plugin)

## Problem Statement

The canonical-doc edit gate (`.claude/hooks/check-canonical-doc.sh`, T-156/T-157) blocks Write/Edit on Marc-facing source documents until a matching `.context/proposals/<slug>.approved` marker exists. Today, creating that marker requires a shell `touch` command — there is no Watchtower UI surface. The /approvals page already aggregates Tier-0, inception GO/NO-GO, and human-AC sign-offs but its three loaders do not include canonical-doc proposals.

Net friction: every canonical-doc edit cycle (release reports, Marc's rapport, Mermaid diagrams) requires a copy-pasteable terminal `touch` command and a context switch out of the browser. The proposal would add a 4th approval category mirroring the existing patterns.

Source: pickup envelope `.context/pickup/processed/P-040-feature-proposal-from-ntb-atc.yaml` (003-NTB-ATC-Plugin T-210). Real-world incidents that exposed the friction: T-205, T-206 (rev-1 9-row matrix), T-207 (rev-2 14 rows).

## Assumptions

- A1: Watchtower's existing 3-loader pattern (`_load_pending_approvals` / `_load_pending_go_decisions` / `_load_pending_human_acs` in `web/blueprints/approvals.py`) is the right shape to mirror for canonical-doc proposals.
- A2: `.context/proposals/*.md` × `.claude/canonical-docs.list` is sufficient to identify pending canonical-doc proposals (no separate registry needed).
- A3: Whole-file approval is sufficient; per-section approval is not required.
- A4: The existing `check-canonical-doc.sh` consumes the marker correctly post-approval; this work only adds the UI that creates it.

## Exploration Plan

- Confirm A1 by reading the 3 existing loaders + their template renders + the decision endpoints; identify the minimum delta for a 4th category.
- Confirm A2 by reading `check-canonical-doc.sh` to verify the marker-name → proposal-path mapping is unambiguous from the proposal file alone.
- Confirm A4 by tracing one full edit-blocked → approve → edit-passes cycle on a synthetic proposal in this repo.
- If all four assumptions hold, the build is mechanical (loader + render + decide endpoint + atomic marker write). Estimated 1-2h.

## Technical Constraints

- Marker write must be atomic (`touch` is, but if rejection adds a `.rejected` marker we need to ensure no race with the gate hook).
- Watchtower runs as the framework process; marker file ownership/permissions must allow the consumer-side hook to read it.
- Approval action is per-project: `.context/proposals/` is project-local, so the loader reads from `PROJECT_ROOT`, not framework root.

## Scope Fence

**IN scope:**
- `_load_pending_canonical_proposals()` in `web/blueprints/approvals.py`
- 4th render section in `web/templates/approvals.html` (or `_approvals_content.html`)
- New endpoint `POST /api/approvals/canonical-decide` (atomic marker write + audit log to `.context/working/.canonical-approval.log`)

**OUT of scope:**
- Changes to `.claude/hooks/check-canonical-doc.sh` (marker mechanism is correct)
- Changes to `canonical-docs.list` contents (project-managed)
- Per-section/per-paragraph approval (whole-file only)

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [x] Problem statement validated
<!-- @auto-tick-on-decide -->
- [x] Assumptions tested
<!-- @auto-tick-on-decide -->
- [x] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
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
#
# Toolchain hint (L-291): if a GO decision will mean editing *.vbproj/*.csproj/*.xaml,
# *.go, Cargo.toml, tsconfig.json, or pom.xml in the build task, plan to add the
# matching build command (dotnet build / go build / cargo check / tsc --noEmit /
# mvn compile) to that build task's ## Verification — P-011 only runs what you write.

## Recommendation

**Recommendation:** GO

**Rationale:** Spike (`docs/reports/T-1538-canonical-doc-approval-spike.md`) validated A1 (3-loader pattern is cleanly mirrorable — purely additive ~210 LOC delta), surfaced a structural insight on A2 (the gate hook lives in consumers, not the framework — the UI must scan defensively, which actually fits the existing /approvals model where Tier-0 approvals also originate consumer-side), confirmed A3 (whole-file approval matches the gate hook's unit), and bounded A4 (cannot validate end-to-end on this host, so the build must include a consumer-side Human AC). All findings point to a low-risk, additive, reversible build. Estimated 1.5h build + 30min review-iteration following the convergence-test pattern proven in T-1540.

**Evidence:**
- `docs/reports/T-1538-canonical-doc-approval-spike.md` — full spike with assumption-by-assumption findings, structural insight on framework-vs-consumer hook deployment, concrete delta plan, proposed build-task ACs
- Existing /approvals architecture probed at `web/blueprints/approvals.py:29-359` — 3 loaders + `_build_approvals_context()` aggregator demonstrates the integration shape
- T-1531/T-1518 demonstrate the loader pattern is actively extended (verdict, deferred-count) without regressions
- Risk surface: additive code, defensive scan, atomic marker write, audit log; revert removes the surface with no state damage

**Open question for human (non-blocker):** Should the framework also ship the canonical-doc gate hook itself as a `fw init` opt-in template (so the UI's existence implies hook availability)? Recommendation: separate follow-up inception — keep this task focused on the UI surface only.



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

**Rationale**: Recommendation: GO

Rationale: Spike (`docs/reports/T-1538-canonical-doc-approval-spike.md`) validated A1 (3-loader pattern is cleanly mirrorable — purely additive ~210 LOC delta), surfaced a structural insight on A2 (the gate hook lives in consumers, not the framework — the UI must scan defensively, which actually fits the existing /approvals model where Tier-0 approvals also originate consumer-side), confirmed A3 (whole-file approval matches the gate hook's unit), and bounded A4 (cannot validate end-to-end on this host, so the build must include a consumer-side Human AC). All findings point to a low-risk, additive, reversible build. Estimated 1.5h build + 30min review-iteration following the convergence-test pattern proven in T-1540.

Evidence:
- `docs/reports/T-1538-canonical-doc-approval-spike.md` — full spike with assumption-by-assumption findings, structural insight on framework-vs-consumer hook deployment, concrete delta plan, proposed build-task ACs
- Existing /approvals architecture probed at `web/blueprints/approvals.py:29-359` — 3 loaders + `_build_approvals_context()` aggregator demonstrates the integration shape
- T-1531/T-1518 demonstrate the loader pattern is actively extended (verdict, deferred-count) without regressions
- Risk surface: additive code, defensive scan, atomic marker write, audit log; revert removes the surface with no state damage

Open question for human (non-blocker): Should the framework also ship the canonical-doc gate hook itself as a `fw init` opt-in template (so the UI's existence implies hook availability)? Recommendation: separate follow-up inception — keep this task focused on the UI surface only.

**Date**: 2026-04-28T11:56:18Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-27T14:47:50Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now

### 2026-04-28T11:56:18Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO

Rationale: Spike (`docs/reports/T-1538-canonical-doc-approval-spike.md`) validated A1 (3-loader pattern is cleanly mirrorable — purely additive ~210 LOC delta), surfaced a structural insight on A2 (the gate hook lives in consumers, not the framework — the UI must scan defensively, which actually fits the existing /approvals model where Tier-0 approvals also originate consumer-side), confirmed A3 (whole-file approval matches the gate hook's unit), and bounded A4 (cannot validate end-to-end on this host, so the build must include a consumer-side Human AC). All findings point to a low-risk, additive, reversible build. Estimated 1.5h build + 30min review-iteration following the convergence-test pattern proven in T-1540.

Evidence:
- `docs/reports/T-1538-canonical-doc-approval-spike.md` — full spike with assumption-by-assumption findings, structural insight on framework-vs-consumer hook deployment, concrete delta plan, proposed build-task ACs
- Existing /approvals architecture probed at `web/blueprints/approvals.py:29-359` — 3 loaders + `_build_approvals_context()` aggregator demonstrates the integration shape
- T-1531/T-1518 demonstrate the loader pattern is actively extended (verdict, deferred-count) without regressions
- Risk surface: additive code, defensive scan, atomic marker write, audit log; revert removes the surface with no state damage

Open question for human (non-blocker): Should the framework also ship the canonical-doc gate hook itself as a `fw init` opt-in template (so the UI's existence implies hook availability)? Recommendation: separate follow-up inception — keep this task focused on the UI surface only.

## Reviewer Verdict (v1.4)

- **Scan ID:** R-3c64abcc
- **Timestamp:** 2026-04-28T11:56:18Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-04-28T11:56:18Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
