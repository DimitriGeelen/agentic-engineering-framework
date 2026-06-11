---
id: T-2078
name: "deep review fw upgrade reliability for field deployment"
description: >
  Inception: deep review fw upgrade reliability for field deployment

status: work-completed
workflow_type: inception
owner: human
horizon:
tags: []
components: []
related_tasks: [T-2092, T-2093, T-2094, T-2095]  # V1-a/b/c/d slices filed retroactively per Recommendation's "filed on GO" line (origin: T-2091 sweep)
created: 2026-05-28T19:57:46Z
last_update: '2026-06-11T22:24:07Z'
date_finished: 2026-05-28T20:08:42Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
bvp_scores_proposed:
  - ts: '2026-05-28T19:58:48Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 2
    rationale: D1=2 (body:learning-ref); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:24:07Z'
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
cost_estimate_proposed:
  - ts: '2026-05-28T20:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 4
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=4 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
---

# T-2078: deep review fw upgrade reliability for field deployment

## Problem Statement

`fw upgrade` is the canonical mechanism for syncing framework improvements to consumer projects in the field. It has accumulated six layered guards (T-1217, T-1278, T-1542, T-1839, T-1912, T-1109) over five months, each closing a specific incident. The flow is now 1265 lines, 10 named steps with side-band `4b`, `4c`, `8b`, and a fresh-machine simulation that only exercises the dry-run announcement path. User asks: deep review for reliability and deployment success in the field.

Full findings written to **`docs/reports/T-2078-fw-upgrade-reliability-review.md`** — 15 numbered findings (F1-F15) + 4 cross-cutting observations (O1-O4), severity-ranked. Recommendation = GO with 4-slice V1 + 4-slice V2.

## Assumptions

- A1: "field deployment" = consumers run `fw upgrade` from their vendored `.agentic-framework/` against the framework's upstream URL (the auto-clone path lib/upgrade.sh:222-314). Not the developer-local two-checkout case.
- A2: the human wants both behavioural fixes AND structural refactors, but in safe order (correctness/observability first; refactor under test net).

## Exploration Plan

(Executed in this turn.)
1. Read lib/upgrade.sh (1265 lines, all 10 steps) ✓
2. Read the simulation bats (tests/unit/upgrade_fresh_machine_simulation.bats) ✓
3. Read T-1633 and T-1830 incident reports ✓
4. Enumerate findings by severity ✓ (15 found)
5. Propose V1/V2 build slice sequence ✓

## Technical Constraints

- The framework targets multiple host platforms (Debian-based LXC, macOS Homebrew, Alpine). Pre-flight tooling check (F8) must scope correctly.
- Live upgrade is ~8 minutes (~65MB vendor rsync). Release-blocking docker simulation needs a sensible runtime budget (≤5 min target, marked tag:slow).
- Bash 3.2 compatibility per the framework's stated portability directive (D4) — fixes must avoid Bash 4-only features (associative arrays without fallback, `${var,,}` lowercase, etc.).

## Scope Fence

**IN scope (this inception decides on these):**
- Reliability defects in lib/upgrade.sh's flow control (F4, F5, F6).
- Observability gaps (F7, F10, O3).
- Test coverage gap (F3 — the load-bearing fresh-machine guard).
- Pre-flight + post-flight envelope (F8, F10).
- Refactor candidates (F1, F9, F13, F15) — agreed in principle, sequenced after V1 ships green.

**OUT of scope (separate inceptions if pursued):**
- Upstream signature verification / supply-chain (F11 long-form).
- Multi-version migration support.
- Cross-platform parity matrix.
- The `fw init` and `fw vendor` flows (touched by F2 only).

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

**GO if:**
- ≥1 High-severity finding has a bounded, testable fix path → V1 ships it under a regression-net before any V2 refactor
- The fresh-machine simulation gap (F3) is closeable inside a docker-based bats variant with ≤5 min runtime budget
- V1 slices are independently shippable (each closes one specific finding without depending on V2 refactor)

**NO-GO if:**
- All findings are cosmetic (none are — F3, F4, F5, F10 are High severity in the report)
- Live-upgrade docker simulation cannot be built without external infra the framework doesn't control
- V1 + V2 sequence would force the step-driver refactor before the safety net is in place (inverted — the recommendation explicitly avoids this)

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

**Rationale:**

15 reliability defects + 4 cross-cutting observations identified in `docs/reports/T-2078-fw-upgrade-reliability-review.md`. The load-bearing test gap (F3 — fresh-machine simulation only exercises the dry-run path, never the live mutation path) is the single highest-leverage fix and explicitly the gap T-1633 elevated to *"the load-bearing piece"*. Four V1 slices each close one or more High/Medium severity findings under a regression-net; four V2 slices follow with the structural refactor once V1's safety net is green.

Antifragility framing (D1): every prior incident layered a guard onto upgrade.sh. The result is 1265 lines that absorb individual incidents but did not strengthen the SHAPE of the flow. V1 stops the bleeding (correctness + observability); V2 restructures under the test net V1 establishes.

**Evidence:**

- `docs/reports/T-2078-fw-upgrade-reliability-review.md` — 15 numbered findings F1-F15 + 4 observations O1-O4, all with concrete line citations against `lib/upgrade.sh` at commit `ce010034`
- T-1633 §3 "THE LOAD-BEARING PIECE" — the fresh-machine simulation gate's scope; F3 demonstrates the slim-slice ship missed the live path
- T-1830 "boundary observability" meta-RCA — same antifragility frame applied to upgrade flow (O3)
- T-2072 just shipped (this session): L-441 asymmetry closure pattern — F4 and F5 are L-441 instances on upgrade; same fix shape
- `tests/unit/upgrade_fresh_machine_simulation.bats:112-117` — the commented-out gap (the bats file says it itself)

**V1 build slices (filed on GO):**
1. **V1-a** — Docker-based live-upgrade simulation gate (closes F3). Release-blocking.
2. **V1-b** — Strict exit-code discipline + rollback on mid-upgrade failure (closes F4, F5, F6).
3. **V1-c** — Pre-flight tooling check + post-upgrade `fw doctor` advisory (closes F8, F10).
4. **V1-d** — Self-vendor extraction into a separate verb (closes F2).

**V2 build slices (after V1 green):**
1. **V2-a** — Step-driver refactor (closes F1, F13, F15)
2. **V2-b** — Inline-python extraction → `lib/upgrade/*.py` with unit tests (closes F9)
3. **V2-c** — Field telemetry: upgrade outcome → `fw bus post` envelope (closes O3, F11)
4. **V2-d** — `--only <subsystems>` selective refresh (closes F14)

**Open question for human decision (before GO):**
- Q1 in the report: `--from-upstream URL` accepting `file:///` paths in production. Recommendation: WARN outside `/tmp` paths; refuse without `--force` unless dry-run. Decide before V1 ships.

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

Rationale:

15 reliability defects + 4 cross-cutting observations identified in `docs/reports/T-2078-fw-upgrade-reliability-review.md`. The load-bearing test gap (F3 — fresh-machine simulation only exercises the dry-run path, never the live mutation path) is the single highest-leverage fix and explicitly the gap T-1633 elevated to "the load-bearing piece". Four V1 slices each close one or more High/Medium severity findings under a regression-net; four V2 slices follow with the structural refactor once V1's safety net is green.

Antifragility framing (D1): every prior incident layered a guard onto upgrade.sh. The result is 1265 lines that absorb individual incidents but did not strengthen the SHAPE of the flow. V1 stops the bleeding (correctness + observability); V2 restructures under the test net V1 establishes.

Evidence:

- `docs/reports/T-2078-fw-upgrade-reliability-review.md` — 15 numbered findings F1-F15 + 4 observations O1-O4, all with concrete line citations against `lib/upgrade.sh` at commit `ce010034`
- T-1633 §3 "THE LOAD-BEARING PIECE" — the fresh-machine simulation gate's scope; F3 demonstrates the slim-slice ship missed the live path
- T-1830 "boundary observability" meta-RCA — same antifragility frame applied to upgrade flow (O3)
- T-2072 just shipped (this session): L-441 asymmetry closure pattern — F4 and F5 are L-441 instances on upgrade; same fix shape
- `tests/unit/upgrade_fresh_machine_simulation.bats:112-117` — the commented-out gap (the bats file says it itself)

V1 build slices (filed on GO):
1. V1-a — Docker-based live-upgrade simulation gate (closes F3). Release-blocking.
2. V1-b — Strict exit-code discipline + rollback on mid-upgrade failure (closes F4, F5, F6).
3. V1-c — Pre-flight tooling check + post-upgrade `fw doctor` advisory (closes F8, F10).
4. V1-d — Self-vendor extraction into a separate verb (closes F2).

V2 build slices (after V1 green):
1. V2-a — Step-driver refactor (closes F1, F13, F15)
2. V2-b — Inline-python extraction → `lib/upgrade/.py` with unit tests (closes F9)
3. V2-c — Field telemetry: upgrade outcome → `fw bus post` envelope (closes O3, F11)
4. V2-d — `--only <subsystems>` selective refresh (closes F14)

Open question for human decision (before GO):
- Q1 in the report: `--from-upstream URL` accepting `file:///` paths in production. Recommendation: WARN outside `/tmp` paths; refuse without `--force` unless dry-run. Decide before V1 ships.

**Date**: 2026-05-28T20:08:42Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-05-28T19:58:48Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-05-28T20:08:42Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO

Rationale:

15 reliability defects + 4 cross-cutting observations identified in `docs/reports/T-2078-fw-upgrade-reliability-review.md`. The load-bearing test gap (F3 — fresh-machine simulation only exercises the dry-run path, never the live mutation path) is the single highest-leverage fix and explicitly the gap T-1633 elevated to "the load-bearing piece". Four V1 slices each close one or more High/Medium severity findings under a regression-net; four V2 slices follow with the structural refactor once V1's safety net is green.

Antifragility framing (D1): every prior incident layered a guard onto upgrade.sh. The result is 1265 lines that absorb individual incidents but did not strengthen the SHAPE of the flow. V1 stops the bleeding (correctness + observability); V2 restructures under the test net V1 establishes.

Evidence:

- `docs/reports/T-2078-fw-upgrade-reliability-review.md` — 15 numbered findings F1-F15 + 4 observations O1-O4, all with concrete line citations against `lib/upgrade.sh` at commit `ce010034`
- T-1633 §3 "THE LOAD-BEARING PIECE" — the fresh-machine simulation gate's scope; F3 demonstrates the slim-slice ship missed the live path
- T-1830 "boundary observability" meta-RCA — same antifragility frame applied to upgrade flow (O3)
- T-2072 just shipped (this session): L-441 asymmetry closure pattern — F4 and F5 are L-441 instances on upgrade; same fix shape
- `tests/unit/upgrade_fresh_machine_simulation.bats:112-117` — the commented-out gap (the bats file says it itself)

V1 build slices (filed on GO):
1. V1-a — Docker-based live-upgrade simulation gate (closes F3). Release-blocking.
2. V1-b — Strict exit-code discipline + rollback on mid-upgrade failure (closes F4, F5, F6).
3. V1-c — Pre-flight tooling check + post-upgrade `fw doctor` advisory (closes F8, F10).
4. V1-d — Self-vendor extraction into a separate verb (closes F2).

V2 build slices (after V1 green):
1. V2-a — Step-driver refactor (closes F1, F13, F15)
2. V2-b — Inline-python extraction → `lib/upgrade/.py` with unit tests (closes F9)
3. V2-c — Field telemetry: upgrade outcome → `fw bus post` envelope (closes O3, F11)
4. V2-d — `--only <subsystems>` selective refresh (closes F14)

Open question for human decision (before GO):
- Q1 in the report: `--from-upstream URL` accepting `file:///` paths in production. Recommendation: WARN outside `/tmp` paths; refuse without `--force` unless dry-run. Decide before V1 ships.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-77ce9038
- **Timestamp:** 2026-06-02T15:01:02Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-28T20:08:42Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
