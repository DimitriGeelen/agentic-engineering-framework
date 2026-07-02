---
id: T-1388
name: "Watchtower /inception/T-XXX page is one-shot — no revoke/re-decide affordance
  after decision recorded"
description: >
  Inception: Watchtower /inception/T-XXX page is one-shot — no revoke/re-decide affordance
  after decision recorded

status: work-completed
workflow_type: inception
owner: human
horizon: null
components: []
related_tasks: []
created: 2026-04-22T21:35:53Z
last_update: '2026-06-11T22:23:47Z'
date_finished:
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:47Z'
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
---

# T-1388: Watchtower /inception/T-XXX page is one-shot — no revoke/re-decide affordance after decision recorded

**Research artifact:** [docs/reports/T-1388-watchtower-inception-no-redecide.md](../../docs/reports/T-1388-watchtower-inception-no-redecide.md) — full root-cause, code evidence, assumptions, exploration plan, dialogue log.

## Problem Statement

Once `fw inception decide` records a decision on a task, Watchtower's `/inception/T-XXX` page shows only the Decision Record (read-only). The form to record a decision disappears. There is no "revoke" or "re-decide" affordance. If the initial decision is wrong or superseded by new scoping, the only recovery path today is manually editing the task markdown to strip the `## Decisions` block so the form re-renders — bypassing the inception-decide pipeline (rationale capture, timestamp, Updates log).

**Who:** human reviewers + agents recording corrected decisions.
**Why now:** hit this during G-056 work on T-1270 — had to strip `## Decisions` by hand. This is the agent-workaround-worse-than-bug pattern (G-019): the unsafe manual edit bypasses audit. Flagged as high-priority bugfix.

## Assumptions

- A1: Humans actually want to re-decide occasionally (vs. create a new follow-up task)
- A2: The current one-shot form is deliberate constraint, not oversight (commit archaeology will tell)
- A3: "Revoke" and "re-decide" are different UX (revoke → pending; re-decide → overwrite with new rationale)
- A4: Backend `record_decision` route is already idempotent — re-exposing the form may be enough

## Exploration Plan

- Spike A — Count active+completed inceptions with multiple decision entries in `## Updates` (tests A1 quantitatively)
- Spike B — `git log -p web/templates/inception_detail.html` for the decision block (tests A2)
- Spike C — Confirm `lib/inception.sh do_inception_decide` can overwrite idempotently (tests A4)
- Spike D — UX sketch: D1 (re-open button) vs D2 (new-decision form with confirm field)

## Technical Constraints

- Must preserve audit trail: each decision entry visible in `## Updates`
- Must not silently overwrite the canonical `## Decision` block without Update entry
- Agent-invocation guard (T-1259) must still block programmatic abuse: `--from-watchtower` flag is the sanctioned path for Watchtower re-decide
- CSRF token on any new POST route

## Scope Fence

**IN:**
- UI affordance to record a superseding decision
- Backend route(s) to accept revoke or re-decide with audit entry
- Invariant test: re-decided tasks have both decision entries in Updates log

**OUT:**
- Data model rewrite (single-canonical `## Decision` stays, history stays in `## Updates`)
- "Decision history" visualisation (follow-up if justified)
- Multi-user authorization flows

## Acceptance Criteria

### Agent
- [x] Problem statement validated (see `docs/reports/T-1388-watchtower-inception-no-redecide.md` §Problem statement + live reproduction screenshots)
- [x] Assumptions tested (Spikes A/B/C/D executed — see research artifact §Spike A..D)
- [x] Recommendation written with rationale (§Recommendation below, adopted by GO decision on 2026-04-22)

**Build decomposition shipped (B1-B6 closed):**
- T-1389 — B1 (backend idempotent replace) + B2 (template re-decide form) → G-057 closed
- T-1390 — B4 (rationale-hint F4 fix)
- T-1391 — B3 (dedupe Recommendation + Decision cards, F3 fix)
- T-1415 — B5 (F2 assumption counter body-fallback)
- T-1416 — B6 (F5 /approvals Decisions vs Verifications split)
- B7 — Playwright regression (TestRedecideAffordance + TestRecommendationDecisionDedupe + TestBodyAssumptionFallback + TestDecisionsVsVerificationsSplit — 16/16 pass)

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

**Recommendation:** GO (S-broad scope per user selection).

**Rationale:** The observed friction is not a single missing button — it's a decision page that fights its own data model. 60 inceptions in this repo have multiple decision entries in `## Updates` (T-837 has 9; T-435/T-485/T-489 have 5 each) — proving re-decide is routine, not theoretical. The UI one-shot lock forces unsafe `sed`-editing of task markdown to work around something the backend cheerfully supports. Add F3 (duplicate Recommendation vs Decision Record), F4 (garbled "Rationale: Recommendation: GO" double-prefix), F5 (97 Human ACs burying 4 strategic decisions on /approvals), and the page fails three of four directives (antifragility, reliability, usability).

**Evidence:**
- **Spike A** — 60 inceptions have multi-decision entries in `## Updates`. Max: T-837 (9 decisions). See `docs/reports/T-1388-watchtower-inception-no-redecide.md` §Spike A.
- **Spike B** — git archaeology (T-085 → T-089 → T-090 → T-1177) shows no "deliberate one-shot" commit — incidental oversight.
- **Spike C** — Backend `do_inception_decide` is near-idempotent; replace-vs-append fix suffices.
- **F1-F5 live-reproduced:** screenshots in `docs/screenshots/T-1388-evidence-{1,2,3}-*.png`, accessibility snapshot in `docs/reports/T-1388-approvals-snapshot.md`.
- **Dead-end map** (5 paths tested; all fail except unsafe `sed`): UI form decided → DOM missing; direct POST → 403 CSRF; CLI from Claude → Tier 0 block; `sed` → bypasses audit.
- **Backend-UI data-model mismatch:** `## Updates` log supports multi-decision natively; UI hides the form after first.

**Build decomposition (after GO):** B1 backend idempotent-replace, B2 template "Record Superseding Decision" form, B3 dedupe Recommendation+Decision cards, B4 fix F4 rationale-extraction, B5 wire Assumptions counter to task body (F2), B6 split /approvals into Decisions vs Verifications (F5), B7 Playwright regression. Each <1 session. B1+B2 alone resolve F1 (reported bug); B3-B6 address "disjointed" feel.

**Reversibility:** Every B-unit is small isolated template/handler edit. Can ship B1+B2 first and stop if B3-B6 prove controversial.

**Alternative (NO-GO):** S-narrow (F1 only) still fixes the reported bug; S-medium is intermediate. User has selected S-broad but human is free to downscope at decision time.

See: `docs/reports/T-1388-watchtower-inception-no-redecide.md` for full analysis, dialogue log, and all screenshots.

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

**Rationale**: Recommendation: GO (S-broad scope per user selection).

Rationale: The observed friction is not a single missing button — it's a decision page that fights its own data model. 60 inceptions in this repo have multiple decision entries in `## Updates` (T-837 has 9; T-435/T-485/T-489 have 5 each) — proving re-decide is routine, not theoretical. The UI one-shot lock forces unsafe `sed`-editing of task markdown to work around something the backend cheerfully supports. Add F3 (duplicate Recommendation vs Decision Record), F4 (garbled "Rationale: Recommendation: GO" double-prefix), F5 (97 Human ACs burying 4 strategic decisions on /approvals), and the page fails three of four directives (antifragility, reliability, usability).

Evidence:
- Spike A — 60 inceptions have multi-decision entries in `## Updates`. Max: T-837 (9 decisions). See `docs/reports/T-1388-watchtower-inception-no-redecide.md` §Spike A.
- Spike B — git archaeology (T-085 → T-089 → T-090 → T-1177) shows no "deliberate one-shot" commit — incidental oversight.
- Spike C — Backend `do_inception_decide` is near-idempotent; replace-vs-append fix suffices.
- F1-F5 live-reproduced: screenshots in `docs/screenshots/T-1388-evidence-{1,2,3}-*.png`, accessibility snapshot in `docs/reports/T-1388-approvals-snapshot.md`.
- Dead-end map (5 paths tested; all fail except unsafe `sed`): UI form decided → DOM missing; direct POST → 403 CSRF; CLI from Claude → Tier 0 block; `sed` → bypasses audit.
- Backend-UI data-model mismatch: `## Updates` log supports multi-decision natively; UI hides the form after first.

Build decomposition (after GO): B1 backend idempotent-replace, B2 template "Record Superseding Decision" form, B3 dedupe Recommendation+Decision cards, B4 fix F4 rationale-extraction, B5 wire Assumptions counter to task body (F2), B6 split /approvals into Decisions vs Verifications (F5), B7 Playwright regression. Each <1 session. B1+B2 alone resolve F1 (reported bug); B3-B6 address "disjointed" feel.

Reversibility: Every B-unit is small isolated template/handler edit. Can ship B1+B2 first and stop if B3-B6 prove controversial.

Alternative (NO-GO): S-narrow (F1 only) still fixes the reported bug; S-medium is intermediate. User has selected S-broad but human is free to downscope at decision time.

See: `docs/reports/T-1388-watchtower-inception-no-redecide.md` for full analysis, dialogue log, and all screenshots.

**Date**: 2026-04-22T22:04:30Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-22T21:37:45Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-22T22:04:30Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO (S-broad scope per user selection).

Rationale: The observed friction is not a single missing button — it's a decision page that fights its own data model. 60 inceptions in this repo have multiple decision entries in `## Updates` (T-837 has 9; T-435/T-485/T-489 have 5 each) — proving re-decide is routine, not theoretical. The UI one-shot lock forces unsafe `sed`-editing of task markdown to work around something the backend cheerfully supports. Add F3 (duplicate Recommendation vs Decision Record), F4 (garbled "Rationale: Recommendation: GO" double-prefix), F5 (97 Human ACs burying 4 strategic decisions on /approvals), and the page fails three of four directives (antifragility, reliability, usability).

Evidence:
- Spike A — 60 inceptions have multi-decision entries in `## Updates`. Max: T-837 (9 decisions). See `docs/reports/T-1388-watchtower-inception-no-redecide.md` §Spike A.
- Spike B — git archaeology (T-085 → T-089 → T-090 → T-1177) shows no "deliberate one-shot" commit — incidental oversight.
- Spike C — Backend `do_inception_decide` is near-idempotent; replace-vs-append fix suffices.
- F1-F5 live-reproduced: screenshots in `docs/screenshots/T-1388-evidence-{1,2,3}-*.png`, accessibility snapshot in `docs/reports/T-1388-approvals-snapshot.md`.
- Dead-end map (5 paths tested; all fail except unsafe `sed`): UI form decided → DOM missing; direct POST → 403 CSRF; CLI from Claude → Tier 0 block; `sed` → bypasses audit.
- Backend-UI data-model mismatch: `## Updates` log supports multi-decision natively; UI hides the form after first.

Build decomposition (after GO): B1 backend idempotent-replace, B2 template "Record Superseding Decision" form, B3 dedupe Recommendation+Decision cards, B4 fix F4 rationale-extraction, B5 wire Assumptions counter to task body (F2), B6 split /approvals into Decisions vs Verifications (F5), B7 Playwright regression. Each <1 session. B1+B2 alone resolve F1 (reported bug); B3-B6 address "disjointed" feel.

Reversibility: Every B-unit is small isolated template/handler edit. Can ship B1+B2 first and stop if B3-B6 prove controversial.

Alternative (NO-GO): S-narrow (F1 only) still fixes the reported bug; S-medium is intermediate. User has selected S-broad but human is free to downscope at decision time.

See: `docs/reports/T-1388-watchtower-inception-no-redecide.md` for full analysis, dialogue log, and all screenshots.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-e81738af
- **Timestamp:** 2026-06-02T14:57:08Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
