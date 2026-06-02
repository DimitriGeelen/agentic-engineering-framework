---
id: T-1337
name: "G-048 Watchtower /api/* CSRF coverage — inventory, classify, decide enforcement approach"
description: >
  Inception: G-048 Watchtower /api/* CSRF coverage — inventory, classify, decide enforcement approach

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-19T16:01:59Z
last_update: 2026-04-19T23:46:17Z
date_finished: 2026-04-19T23:46:17Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
---

# T-1337: G-048 Watchtower /api/* CSRF coverage — inventory, classify, decide enforcement approach

## Problem Statement

Watchtower's CSRF middleware (web/app.py:92-107) blanket-skips every request whose path starts with `/api/`. 25 state-mutating POST/DELETE endpoints live under `/api/*` — task creation, status changes, cron job pause/resume/run, healing triggers, scan approve/apply, session init, audit run, tests run. A forged POST from any same-origin context (malicious iframe, redirect, stored-HTML injection) succeeds without a token. Same-origin + SameSite=Lax provides incidental defense but is not a design guarantee.

Full inventory + classification: `docs/reports/T-1337-api-csrf-inventory.md`.

## Assumptions

1. Flask middleware already accepts `X-CSRF-Token` header (verified: web/app.py:104)
2. Current fetch() callers in Watchtower JS do not send the token header (UNTESTED — grep needed)
3. A single shared JS helper can wrap fetch() for all state-mutating calls (LIKELY TRUE — convention-over-config)
4. Playwright regression can parameterize across endpoints (LIKELY TRUE — one test per blueprint sampling one endpoint each)

## Exploration Plan

Completed (see research artifact):
- **A** — Inventory: grep `@bp.route.*POST|DELETE` under `/api/*` (25 state-mutating endpoints catalogued)
- **B** — Classify by impact (all 25 have meaningful side-effects; none read-only)
- **C** — Compare remediation options (A: full coverage, B: accept, C: namespace split)
- **D** — Recommendation writeup with decomposition path

## Technical Constraints

- Watchtower uses Flask sessions (secret_key-signed cookies) and already emits a CSRF token (app.py:86-90). Middleware already validates `X-CSRF-Token` header — only the `/api/*` early-return blocks this path.
- Browser fetch() calls from templates need one helper to inject the header (Watchtower JS is uniform — no framework like React).
- Dev LXC `.170` is on a routable VLAN; prod Watchtower is `watchtower.docker.ring20.geelenandcompany.com`. Not strictly loopback-only.

## Scope Fence

**IN:** decide whether to flip middleware to positive-allowlist + update JS callers + add playwright regression.
**OUT:** implementing the fix (that's follow-on build task B1+B2+B3 if GO); broader auth/identity redesign; `/api/v2/` namespace migration.

## Acceptance Criteria

### Agent
- [x] Problem statement validated (inventory confirms 25 state-mutating endpoints)
- [x] Assumptions tested (middleware accepts header verified; fetch() call audit deferred to build B2)
- [x] Recommendation written with rationale (GO Option A with B1/B2/B3 staging)

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

**Recommendation:** GO — Option A (remove blanket `/api/*` exemption, require `X-CSRF-Token` on state-mutating endpoints)

**Rationale:** CSRF exemption by path prefix is an anti-pattern inherited from the pre-JSON era of Watchtower. 25 state-mutating endpoints currently accept unauthenticated POSTs — including task creation, status changes, cron pause/resume/run, scan approve/apply, and session init. Same-origin + SameSite=Lax is incidental defense, not design. The middleware already accepts `X-CSRF-Token` header (app.py:104); the only blocker is the early-return at app.py:97. A positive-allowlist middleware is structurally self-defending — future state-mutating endpoints land under CSRF by default (addresses G-019: fix detection, not just symptom).

**Evidence:**
- 25 state-mutating POST/DELETE `/api/*` endpoints inventoried and catalogued — see `docs/reports/T-1337-api-csrf-inventory.md`
- Middleware already validates `X-CSRF-Token` header (web/app.py:104) — no new validation code needed
- All fetch() updates are uniform (wrap in one helper) — grep`fetch\(` and apply
- Options B (accept) and C (namespace split) both lose on detection and cost respectively
- Proposed decomposition: B1 middleware flip + B2 JS helper update (same commit) + B3 playwright regression (separate commit)

**Go/No-Go criteria:** both met — root cause identified (path-prefix exemption), fix bounded (25 endpoints, one middleware change, reversible).

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

**Rationale**: Recommendation: GO — Option A (remove blanket `/api/` exemption, require `X-CSRF-Token` on state-mutating endpoints)

Rationale: CSRF exemption by path prefix is an anti-pattern inherited from the pre-JSON era of Watchtower. 25 state-mutating endpoints currently accept unauthenticated POSTs — including task creation, status changes, cron pause/resume/run, scan approve/apply, and session init. Same-origin + SameSite=Lax is incidental defense, not design. The middleware already accepts `X-CSRF-Token` header (app.py:104); the only blocker is the early-return at app.py:97. A positive-allowlist middleware is structurally self-defending — future state-mutating endpoints land under CSRF by default (addresses G-019: fix detection, not just symptom).

Evidence:
- 25 state-mutating POST/DELETE `/api/` endpoints inventoried and catalogued — see `docs/reports/T-1337-api-csrf-inventory.md`
- Middleware already validates `X-CSRF-Token` header (web/app.py:104) — no new validation code needed
- All fetch() updates are uniform (wrap in one helper) — grep`fetch\(` and apply
- Options B (accept) and C (namespace split) both lose on detection and cost respectively
- Proposed decomposition: B1 middleware flip + B2 JS helper update (same commit) + B3 playwright regression (separate commit)

Go/No-Go criteria: both met — root cause identified (path-prefix exemption), fix bounded (25 endpoints, one middleware change, reversible).

**Date**: 2026-04-19T23:46:17Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-19T16:03:55Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-19T23:46:17Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO — Option A (remove blanket `/api/` exemption, require `X-CSRF-Token` on state-mutating endpoints)

Rationale: CSRF exemption by path prefix is an anti-pattern inherited from the pre-JSON era of Watchtower. 25 state-mutating endpoints currently accept unauthenticated POSTs — including task creation, status changes, cron pause/resume/run, scan approve/apply, and session init. Same-origin + SameSite=Lax is incidental defense, not design. The middleware already accepts `X-CSRF-Token` header (app.py:104); the only blocker is the early-return at app.py:97. A positive-allowlist middleware is structurally self-defending — future state-mutating endpoints land under CSRF by default (addresses G-019: fix detection, not just symptom).

Evidence:
- 25 state-mutating POST/DELETE `/api/` endpoints inventoried and catalogued — see `docs/reports/T-1337-api-csrf-inventory.md`
- Middleware already validates `X-CSRF-Token` header (web/app.py:104) — no new validation code needed
- All fetch() updates are uniform (wrap in one helper) — grep`fetch\(` and apply
- Options B (accept) and C (namespace split) both lose on detection and cost respectively
- Proposed decomposition: B1 middleware flip + B2 JS helper update (same commit) + B3 playwright regression (separate commit)

Go/No-Go criteria: both met — root cause identified (path-prefix exemption), fix bounded (25 endpoints, one middleware change, reversible).

### 2026-04-19T23:46:17Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

## Reviewer Verdict (v1.5)

- **Scan ID:** R-546535e7
- **Timestamp:** 2026-06-02T14:56:47Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
