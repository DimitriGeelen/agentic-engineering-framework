---
id: T-2158
name: "continuous-run arc — agent-driven compact→resume loop with bounded-autonomy
  ceiling"
description: >
  Inception: continuous-run arc — agent-driven compact→resume loop with bounded-autonomy
  ceiling

status: work-completed
workflow_type: inception
owner: human
horizon:
tags: [priority, arc-003, orchestrator, autonomy, continuous-run]
components: [agents/termlink/bvp-estimator/estimator.py, 
      tests/unit/test_bvp_estimator.py]
related_tasks: []
created: 2026-06-01T09:39:33Z
last_update: 2026-06-13T08:43:48Z
date_finished: 2026-06-13T08:43:48Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
bvp_scores_proposed: []
cost_estimate_proposed:
  - ts: '2026-06-01T09:45:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 4
      effort: 7
    rationale: blast_radius=0 (no-signal); tier=4 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-05T18:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 7
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed: []
confirmed_by: unknown
confirmed_at: '2026-06-25T14:23:02Z'
---

# T-2158: continuous-run arc — agent-driven compact→resume loop with bounded-autonomy ceiling

## Problem Statement

Human-filed arc inception draft (`continuous-run`). Today, continuous operation is **operator-gated**: a human runs `/compact` and `fw handover` when the context budget fills, then resumes. This caps how far the agent can run unattended and re-injects a human relay at every budget boundary. The capability gap is the agent **autonomously crossing those boundaries** — self-compacting and self-resuming — **while remaining bounded** by tier/blast-radius ceiling, run-length cap, and a discard-manifest audit trail.

**Critical reframe from prior-art read:** T-111 (completed 2026-02-17) already shipped the *data-preservation* half of this loop (PreCompact + SessionStart:compact hooks; `fw handover --emergency`; auto-restart wrapper). What remains is the **self-triggering + bounded-autonomy machinery + discard audit** — incremental on T-111, not greenfield.

**Research artifact:** `docs/reports/T-2158-continuous-run.md` — proposed arc YAML verbatim, T-111 reframe, 6 assumptions, 10 critical questions, 6 spikes (~125 min).

## Assumptions

- **A1:** T-111's PreCompact + SessionStart:compact hooks remain functional and are the right substrate to extend (vs. clean rebuild). Validate via end-to-end trace of this session's compact event.
- **A2:** The 90% context-budget gate (criterion 28, `budget-gate.sh`) is the clean trigger surface; self-compaction can hang off it without disabling it.
- **A3:** Tier 0 + blast-radius primitives (`check-tier0.sh`, `fw fabric blast-radius`) are invocable from the post-resume path. The Sovereignty surface narrows but doesn't disappear.
- **A4:** A discard manifest can be produced at *category-level* fidelity (not token-level) during emergency handover. The model performs the compaction; the agent enumerates categories.
- **A5:** Run-length cap is a simple counter in `.context/working/` — same pattern as `.tool-counter`. No new persistence layer.
- **A6:** F7 Sovereignty is preservable: the human still gates Tier 0 *post-resume*; just doesn't gate compaction *itself*.

## Exploration Plan

| Spike | Time-box | Output |
|-------|----------|--------|
| S1: T-111 substrate trace | 25 min | End-to-end map of this session's compact: PreCompact firing, `--emergency` handover contents, SessionStart:compact injection. Concrete file:line refs in artifact. |
| S2: Self-trigger surface walk | 20 min | Read `budget-gate.sh`, `checkpoint.sh`, `claude-fw` wrapper, T-179 auto-restart. Map "compact now" decision points. Answer Q1 + Q2. |
| S3: Bounded-autonomy primitives audit | 20 min | Read `check-tier0.sh`, `fw fabric blast-radius`, `policy/value-drivers.yaml` (`auto_promote:` block as precedent). Document Sovereignty surface narrowing. |
| S4: Scoped-driver critique | 15 min | Apply CLAUDE.md "new meaning, not louder D1-D4" criterion to Loop closure / Bounded-safety integrity / Discard fidelity. Refine or refute. |
| S5: Arc-field validation + orchestrator-rethink delta | 15 min | Walk `lib/arc.sh` field shapes (Q7). Read `.context/arcs/orchestrator-rethink.yaml`. Decide child/sibling/merge (Q8). |
| S6: Answer open questions 1-10 | 30 min | Each Q resolved with evidence cited. Flip Recommendation. |

Total: ~125 min read-only research. No source edits, no `fw arc create`, no hook changes until GO recorded.

## Technical Constraints

- **F7 Sovereignty (load-bearing):** continuous self-resume is the strongest test of operator-bypass tension. The mechanic must be **bounded**, not unbounded. Constraints from the user's draft are inviolable:
  - Hard stop at Tier 0 / irreversible / high-blast-radius actions
  - Run-length / iteration cap as second backstop
  - Discard manifest recording WHAT was dropped (post-hoc operator review)
  - Respects the 90% context-budget gate as trigger AND safety boundary
- **Non-goals (from draft):** removing/weakening Tier 0 gate; truly unbounded operation; introducing a new scoring driver (lives in `policy/value-drivers.yaml`).
- **Cross-arc coupling:** T-2157 (value-drivers v3) holds F-AUTONOMY as a *commented-out candidate* — continuous-run going GO may flip F-AUTONOMY activation in tandem. Sequencing matters.
- **Compaction is model-driven, not agent-driven:** the discard manifest can only enumerate categories ("47 tool-results compressed", "12 turns summarised"), not the literal dropped tokens. Acceptable fidelity question is open (Q4).

## Scope Fence

**IN scope:**
- All six spikes (read-only research)
- Cross-reference with T-2157 (F-AUTONOMY tandem question)
- Cross-reference with T-1643 / `orchestrator-rethink` arc
- Critique of the three proposed scoped drivers against CLAUDE.md free-driver criterion
- Recommendation flip from DEFER → GO / NO-GO / GO-with-refinements
- Hand-off to human via `fw task review T-2158` → Watchtower `/inception/T-2158`

**OUT of scope (separate tasks if GO):**
- Running `fw arc create continuous-run --headline-mechanic ...`
- Implementing self-triggering compaction (separate build slice)
- Discard manifest format design (may need its own inception)
- Run-length cap counter wiring (separate slice, small)
- Test harness for multi-cycle autonomous compact (may need its own inception per Q6)
- F-AUTONOMY activation in `policy/value-drivers.yaml` (sits under T-2157's territory)

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
- T-111 substrate is intact and extensible (no rebuild required)
- A clean trigger surface exists in `budget-gate.sh` or equivalent (Q1 has a single-best answer)
- Tier 0 + blast-radius gates are invocable from the post-resume path (A3 holds)
- All three scoped drivers survive the "new meaning, not louder D1-D4" critique (Q9), OR a refined set of ≤3 emerges
- Discard manifest can be produced at category-level fidelity (Q4)
- Relation to `orchestrator-rethink` arc is unambiguous (child/sibling/merge decided)

**NO-GO if:**
- T-111 hooks are broken or have drifted from their 2026-02 baseline
- Sovereignty pushback (Q3) reveals operator compact-checkpoint is load-bearing oversight that can't be replaced by post-hoc manifest review
- Discard-manifest fidelity is so low (Q4) that the audit trail is theatre, not substance
- Scoped drivers all collapse into D1-D4 restatements — arc adds no scoring signal globals can't see

**GO-with-refinements if:**
- Proposal is structurally sound but specific machinery needs revision (e.g. trigger surface moved, run-length cap shape adjusted)
- Driver set reduces from 3 to 1-2 (strongest survives, weakest refuted)
- Arc should ship as a *child* of `orchestrator-rethink` rather than as a sibling

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

**Recommendation:** **GO — with refinements**

**Rationale:**

Spike walk S1-S6 completed 2026-06-13 (read-only, ~30 min wall-clock with parallel dispatch). All six assumptions A1-A6 hold: T-111 substrate INTACT (S1 — proof-of-life this morning's compact at 2026-06-13T09:50:39Z); cleanest self-trigger surface is `agents/context/checkpoint.sh:176` — a single JSON-field extension to a payload that already writes successfully (S2); bounded-autonomy primitives `agents/context/check-tier0.sh` + `bin/fw fabric blast-radius` confirmed invocable from hook context (S3); sovereignty narrowing acceptable — Tier 0 stays gated, only compaction gate surrendered (S3); scoped-driver set reduces 3→1-firm-plus-1-conditional with F-AUTONOMY at global covering rejected leg (S4); continuous-run is SIBLING of orchestrator-rethink, not child (S5); F-AUTONOMY tandem activation structurally required — carved `retire_when` text in `policy/value-drivers.yaml` *names this arc by name* (S4 + S5). Full evidence walk in `docs/reports/T-2158-continuous-run.md` §Spike Findings.

**Refinements vs original draft:**
1. Scoped-driver count 1-2 not 3 (drop Bounded-safety — F-AUTONOMY L4 covers; conditional Loop closure if F-AUTONOMY tandem-activates)
2. SIBLING of orchestrator-rethink (distinct mechanism axes; child framing muddies arc-003 §ACD ledger)
3. Recover `constraints`/`non_goals`/`relation_to_existing_primitives` via anchor task body (lib/arc.sh template doesn't carry them)
4. F-AUTONOMY activation in same commit as arc create (carved → active per carved gate text)

**Build slice shape (~10-11h across 5-6 tasks):**
- S0: `fw arc create continuous-run` + anchor task body holds dropped fields + F-AUTONOMY uncarve (<1h)
- S1: directive file schema + checkpoint.sh single-line extension + claude-fw consumer (~2h)
- S2: SessionStart:resume reads directive + iteration counter increment (~2h)
- S3: run-length cap + `.continuous-mode.yaml` config (~1h)
- S4: discard manifest enhancement to `fw handover --emergency` (~2-3h)
- S5: post-resume Tier 0 + blast-radius re-check (~2h)

**Evidence:**
- T-111 substrate intact: `agents/context/pre-compact.sh:54-80` + `agents/context/post-compact-resume.sh:24-278` cited
- checkpoint.sh:176 single-line add identified for self-trigger
- check-tier0.sh + fw fabric blast-radius invocable at hook layer (S3)
- F-AUTONOMY carved gate matches arc landing trigger verbatim (`policy/value-drivers.yaml` §CANDIDATE F-AUTONOMY retire_when)
- orchestrator-rethink scope delta < 5% per arc-003 YAML headline_mechanic comparison
- All 10 open questions resolved with file:line evidence in §S6 table

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

**Rationale**: Spike walk S1-S6 completed 2026-06-13 (read-only, ~30 min wall-clock with parallel dispatch). All six assumptions A1-A6 hold: T-111 substrate INTACT (S1 — proof-of-life this morning's compact at 2026-06-13T09:50:39Z); cleanest self-trigger surface is `agents/context/checkpoint.sh:176` — a single JSON-field extension to a payload that already writes successfully (S2); bounded-autonomy primitives `agents/context/check-tier0.sh` + `bin/fw fabric blast-radius` confirmed invocable from hook context (S3); sovereignty narrowing acceptable — Tier 0 stays gated, only compaction gate surrendered (S3); scoped-driver set reduces 3→1-firm-plus-1-conditional with F-AUTONOMY at global covering rejected leg (S4); continuous-run is SIBLING of orchestrator-rethink, not child (S5); F-AUTONOMY tandem activation structurally required — carved `retire_when` text in `policy/value-drivers.yaml` *names this arc by name* (S4 + S5). Full evidence walk in `docs/reports/T-2158-continuous-run.md` §Spike Findings.

**Date**: 2026-06-13T08:43:48Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-06-01T09:42:11Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-06-01T09:45:00Z — status-update [task-update-agent]
- **Change:** tags: +priority

### 2026-06-01T09:45:08Z — status-update [task-update-agent]
- **Change:** tags: +arc-003

### 2026-06-01T09:45:08Z — status-update [task-update-agent]
- **Change:** tags: +orchestrator

### 2026-06-01T09:45:09Z — status-update [task-update-agent]
- **Change:** tags: +autonomy

### 2026-06-01T09:45:09Z — status-update [task-update-agent]
- **Change:** tags: +continuous-run

### 2026-06-05T21:12:15Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** DEFER
- **Rationale:** Recommendation: DEFER

Rationale:

Human-filed arc inception draft. Closes the compact→resume loop so a long-running agent self-compacts and self-resumes at context-budget boundaries, bounded by tier/blast-radius ceiling, run-length cap, and a discard manifest for review. Sits under T-1643 orchestrator-substrate territory. Genuine evidence gap (T-2144): need to walk existing primitives (agents/resume/, fw handover, budget-gate.sh, criterion 28+55), critique the three proposed scoped drivers (Loop closure / Bounded-safety integrity / Discard fidelity) against F-AUTONOMY (T-2157), validate the F7 Sovereignty tension framing, and scope the boundary with T-1643. Research artifact will host the proposed arc YAML verbatim plus the evidence walk.

Evidence:

### 2026-06-05T21:12:15Z — status-update [task-update-agent]
- **Change:** horizon: now → later
- **Change:** status: started-work → captured (auto-sync)
- **Reason:** Inception decision: DEFER — parking task

### 2026-06-13T08:36:56Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)

### 2026-06-13T08:43:48Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Spike walk S1-S6 completed 2026-06-13 (read-only, ~30 min wall-clock with parallel dispatch). All six assumptions A1-A6 hold: T-111 substrate INTACT (S1 — proof-of-life this morning's compact at 2026-06-13T09:50:39Z); cleanest self-trigger surface is `agents/context/checkpoint.sh:176` — a single JSON-field extension to a payload that already writes successfully (S2); bounded-autonomy primitives `agents/context/check-tier0.sh` + `bin/fw fabric blast-radius` confirmed invocable from hook context (S3); sovereignty narrowing acceptable — Tier 0 stays gated, only compaction gate surrendered (S3); scoped-driver set reduces 3→1-firm-plus-1-conditional with F-AUTONOMY at global covering rejected leg (S4); continuous-run is SIBLING of orchestrator-rethink, not child (S5); F-AUTONOMY tandem activation structurally required — carved `retire_when` text in `policy/value-drivers.yaml` *names this arc by name* (S4 + S5). Full evidence walk in `docs/reports/T-2158-continuous-run.md` §Spike Findings.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-0867d94b
- **Timestamp:** 2026-06-13T08:43:49Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-13T08:43:48Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
