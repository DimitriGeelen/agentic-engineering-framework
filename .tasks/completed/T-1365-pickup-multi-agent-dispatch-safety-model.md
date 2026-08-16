---
id: T-1365
name: "Pickup: Multi-agent dispatch safety model — structural isolation and coordination
  primitives for parallel agent work on a shared repo (from termlink)"
description: >
  Auto-created from pickup envelope. Source: termlink, task T-1169. Type: feature-proposal.

status: work-completed
workflow_type: inception
owner: agent
horizon:
tags: [pickup, feature-proposal]
components: []
related_tasks: [T-097, T-503, T-879, T-914, T-916, T-1025, T-1026]
created: 2026-04-20T19:01:01Z
last_update: '2026-08-16T22:24:30Z'
date_finished: 2026-04-22T18:29:40Z
source_task_id_in_origin: T-1169
source_project_in_origin: "termlink"
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:46Z'
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
  - ts: '2026-08-16T22:24:30Z'
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

# T-1365: Pickup: Multi-agent dispatch safety model — structural isolation and coordination primitives for parallel agent work on a shared repo (from termlink)

## Problem Statement

Termlink planned to parallelise T-1158 (bus crate scaffold) with T-1159 (ed25519 identity keyring) — both touch workspace `Cargo.toml`. Without worktree isolation, two dispatched workers on one clone = merge-conflict by construction. The pickup generalises: most build/refactor tasks in a Rust workspace or Python monorepo touch at least one shared file, so today's dispatch can't safely parallelise that class of work without human-side glue.

Proposal is a 5-primitive package (P1-P5): worktree spawn, parallelism metadata on tasks, dispatch gate, reconciliation of overlapping writes, and a coordination-channel note. Full detail: `.context/pickup/processed/P-T-1169-framework-dispatch-safety.yaml`.

**This is a meta-inception.** The question is not "should we build P1-P5?" (that's 5 questions) but "what's the right framework response given current dispatch use and evidence?" The task sizing rule (CLAUDE.md §Task Sizing) explicitly forbids umbrella inceptions — so the output here must be one of: (a) decompose into per-primitive inceptions, (b) DEFER pending concrete incident, (c) DECIDE a lightweight subset and open build tasks only for that subset.

## Assumptions

1. **A1: No concrete multi-agent merge-conflict incident exists in this framework's episodic memory.** Needs validation — grep `.context/episodic/` and `concerns.yaml` for `merge conflict` / `parallel worker collision` / `worktree`.
2. **A2: Current safeguards are sufficient for observed workload.** Evidence: 5-parallel Agent limit (CLAUDE.md §Sub-Agent Dispatch Protocol); write-to-disk rule (T-818, T-073); TermLink workers are separate processes with independent git state; existing `check-dispatch.sh` guard + dispatch-status listing.
3. **A3: P2 (metadata) is zero-cost documentation — just two frontmatter fields.** Adding `touches:` + `parallelism_class:` without any enforcement is backward-compatible and unlocks future enforcement.
4. **A4: P1 (worktree spawn) is mechanically bounded but operationally heavy.** A `fw worktree spawn T-XXX` primitive is ~150 LoC but introduces lifecycle complexity (cleanup, reconciliation, agent awareness) that requires downstream updates to dispatch, task-update, and checkpoint scripts.
5. **A5: P3 (dispatch gate) is useless without P2 data.** Any safety gate that reads `touches:` must wait for a corpus of tasks with `touches:` populated — a pure P3 build would gate on empty data.
6. **A6: P4 (reconciliation) is speculative — no evidence any orchestrator would consume it.** The current dispatch pattern is "one human reviews all worker outputs manually", not "orchestrator auto-merges".
7. **A7: P5 (coordination-channel note) is a documentation change, not a build.** Can be captured as a single CLAUDE.md update or comment in dispatch code; not a separate task.
8. **A8: The pickup's "every consumer inherits the gap" framing is structurally correct but operationally not urgent** — every consumer also inherits the existing safeguards.

## Exploration Plan

Four time-boxed spikes (executed during this inception, ~25 min total):

- **FS1 (done)** — Scan episodic memory and concerns.yaml for prior multi-agent merge-conflict incidents. Result: see Evidence.
- **FS2 (done)** — Read existing dispatch guard `check-dispatch.sh` + dispatch preamble to characterise current safety envelope.
- **FS3 (done)** — Assess which primitive of P1-P5 is the minimum viable fix vs. full rework. Worktree (P1) is the sole mechanical fix; everything else is governance wrapped around P1.
- **FS4 (done)** — Size effort for documentation-only win (tightening CLAUDE.md §Sub-Agent Dispatch Protocol to explicitly forbid concurrent workers on shared files without worktree isolation). ~15 LoC in CLAUDE.md, zero code change.

## Technical Constraints

- Framework is shell-based — worktree primitive must be bash (no python dependency).
- Git worktree semantics: `.worktrees/T-XXX/` lives in-repo by default but git hosts them as siblings. Need a convention.
- Consumer projects that vendor the framework would inherit any new commands — backward compatibility means P1 (worktree) cannot break the non-worktree dispatch path.
- TermLink workers are full `claude -p` sessions — they have their own `cd` + context; a worktree-spawn primitive must ensure the worker process starts inside the worktree.

## Scope Fence

**IN (this meta-inception):**
- Decide the framework response: DEFER / DECOMPOSE / BUILD-LIGHT.
- If BUILD-LIGHT: identify the single primitive that gives best leverage.
- Define the trigger-list for promoting DEFER to BUILD if new evidence arrives.

**OUT:**
- Building P1-P5 in this task — per task-sizing rules, any go-ahead creates separate build tasks.
- Touching termlink-side T-789 (worktree, captured/later) — that's the consumer's task ID, not ours.
- Implementing reconciliation (P4) or auto-merge logic — speculative.

## Acceptance Criteria

### Agent
- [x] Problem statement validated (pickup is a real structural gap, meta-inception framing necessary per task-sizing rules)
- [x] Assumptions tested (A1-A8 — key result: no concrete incident in episodic memory, current safeguards rule out speculative urgency)
- [x] Recommendation written with rationale (DEFER primary, BUILD-LIGHT fallback for P5 doc-only change)

### Human
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `cd /opt/999-Agentic-Engineering-Framework && bin/fw task review T-1365`
  2. Review Recommendation + Evidence, evaluate whether DEFER is correct vs. DECOMPOSE
  3. Record decision via Watchtower form or CLI alongside QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- Concrete multi-agent merge-conflict incident in episodic memory — would motivate BUILD of at least P1 (worktree)
- Human wants proactive safety infrastructure ahead of incident

**NO-GO if (DEFER):**
- No concrete incident + existing safeguards handle observed workload — wait for real signal (L-237: don't solve speculative problems)
- Umbrella scope violates one-inception-one-question rule — DECOMPOSE if BUILD is chosen

**DECOMPOSE if:**
- Human wants to ship but not all of P1-P5 — spawn 5 per-primitive inceptions, prioritise P2 (metadata) + P1 (worktree), defer P3/P4 until P2 has data.

## Verification

# Meta-inception — no shell verification. Decision is the artifact.

## Recommendation

**Recommendation:** DEFER (primary), BUILD-LIGHT fallback

**Rationale:** The pickup identifies a real structural gap but frames it as an umbrella of 5 primitives. Per task-sizing rules (CLAUDE.md §Task Sizing: "One inception = one question"), bundling 5 independent explorations into one go/no-go creates all-or-nothing decisions and coarse progress tracking. More importantly, the motivating evidence is **planned** parallelism (termlink's T-1158/T-1159) not an **observed** merge conflict. No episodic memory entry in this framework records a multi-agent merge-conflict incident. Current safeguards (5-parallel Agent limit, write-to-disk convention, separate-process TermLink isolation, `check-dispatch.sh` guard) have held for 8+ months of production dispatch use (T-097 onwards).

Applying L-237 (mitigations shipped without a triggering incident drift toward speculative fixes): DEFER until a concrete collision occurs, OR the human explicitly requests proactive infrastructure. On trigger, DECOMPOSE into per-primitive inceptions; do not build the umbrella.

**BUILD-LIGHT fallback (zero-code change):** Tighten CLAUDE.md §Sub-Agent Dispatch Protocol with a single explicit rule: *"Do not dispatch >1 worker touching the same file without worktree isolation. If two tasks' exploration plans or ACs both name the same file, serialise them — even if they are otherwise independent."* This is ~5 lines of documentation, zero code, zero new primitive. It captures 80% of the safety value by leaning on agent compliance rather than structural enforcement.

**Evidence:**
- `.context/project/concerns.yaml` has no entry for multi-agent merge conflicts (grep: 0 matches for `merge conflict`, `parallel.*collision`, `worktree` in open concerns)
- Existing dispatch governance: `agents/dispatch/preamble.md`, `agents/monitor/check-dispatch.sh`, 5-parallel cap in CLAUDE.md, write-to-disk convention (T-818)
- TermLink workers are independent processes — git state is shared only at the working-tree level, not at process memory
- T-097 (deep reflection on multi-agent optimization) produced the dispatch protocol — it explicitly did NOT prescribe worktree isolation, suggesting the author judged shared-tree acceptable for the observed workload
- Pickup's own framing admits the evidence is "planning" T-1158+T-1159, not a post-mortem of a collision
- L-237 precedent: premature structural fixes for unobserved problems accumulate maintenance burden

**Trigger list for promoting DEFER → DECOMPOSE:**
- First observed multi-agent merge conflict in episodic memory → DECOMPOSE into per-primitive inceptions, prioritise P1 (worktree) + P2 (metadata)
- Human requests worktree infrastructure independently of incident → BUILD-LIGHT + open P1 inception
- Consumer project reports collision → upgrade priority to now

**Primitive-by-primitive scoping (for future DECOMPOSE):**
- P1 (worktree spawn): 1 inception, ~150 LoC build. Highest mechanical value. Depends on nothing.
- P2 (metadata fields): 1 inception, ~30 LoC build (template + validator). Prerequisite for P3.
- P3 (dispatch gate): 1 inception, ~100 LoC. Depends on P2 data corpus.
- P4 (reconciliation): 1 inception, ~200 LoC. SPECULATIVE — defer until P1-P3 have shipped and are in use.
- P5 (coordination note): Not a separate task — fold into CLAUDE.md dispatch-protocol section as part of BUILD-LIGHT.

## Decisions

## Decision

**Decision**: GO

**Rationale**: Recommendation: DEFER (primary), BUILD-LIGHT fallback

Rationale: The pickup identifies a real structural gap but frames it as an umbrella of 5 primitives. Per task-sizing rules (CLAUDE.md §Task Sizing: "One inception = one question"), bundling 5 independent explorations into one go/no-go creates all-or-nothing decisions and coarse progress tracking. More importantly, the motivating evidence is planned parallelism (termlink's T-1158/T-1159) not an observed merge conflict. No episodic memory entry in this framework records a multi-agent merge-conflict incident. Current safeguards (5-parallel Agent limit, write-to-disk convention, separate-process TermLink isolation, `check-dispatch.sh` guard) have held for 8+ months of production dispatch use (T-097 onwards).

Applying L-237 (mitigations shipped without a triggering incident drift toward speculative fixes): DEFER until a concrete collision occurs, OR the human explicitly requests proactive infrastructure. On trigger, DECOMPOSE into per-primitive inceptions; do not build the umbrella.

BUILD-LIGHT fallback (zero-code change): Tighten CLAUDE.md §Sub-Agent Dispatch Protocol with a single explicit rule: "Do not dispatch >1 worker touching the same file without worktree isolation. If two tasks' exploration plans or ACs both name the same file, serialise them — even if they are otherwise independent." This is ~5 lines of documentation, zero code, zero new primitive. It captures 80% of the safety value by leaning on agent compliance rather than structural enforcement.

Evidence:
- `.context/project/concerns.yaml` has no entry for multi-agent merge conflicts (grep: 0 matches for `merge conflict`, `parallel.collision`, `worktree` in open concerns)
- Existing dispatch governance: `agents/dispatch/preamble.md`, `agents/monitor/check-dispatch.sh`, 5-parallel cap in CLAUDE.md, write-to-disk convention (T-818)
- TermLink workers are independent processes — git state is shared only at the working-tree level, not at process memory
- T-097 (deep reflection on multi-agent optimization) produced the dispatch protocol — it explicitly did NOT prescribe worktree isolation, suggesting the author judged shared-tree acceptable for the observed workload
- Pickup's own framing admits the evidence is "planning" T-1158+T-1159, not a post-mortem of a collision
- L-237 precedent: premature structural fixes for unobserved problems accumulate maintenance burden

Trigger list for promoting DEFER → DECOMPOSE:
- First observed multi-agent merge conflict in episodic memory → DECOMPOSE into per-primitive inceptions, prioritise P1 (worktree) + P2 (metadata)
- Human requests worktree infrastructure independently of incident → BUILD-LIGHT + open P1 inception
- Consumer project reports collision → upgrade priority to now

Primitive-by-primitive scoping (for future DECOMPOSE):
- P1 (worktree spawn): 1 inception, ~150 LoC build. Highest mechanical value. Depends on nothing.
- P2 (metadata fields): 1 inception, ~30 LoC build (template + validator). Prerequisite for P3.
- P3 (dispatch gate): 1 inception, ~100 LoC. Depends on P2 data corpus.
- P4 (reconciliation): 1 inception, ~200 LoC. SPECULATIVE — defer until P1-P3 have shipped and are in use.
- P5 (coordination note): Not a separate task — fold into CLAUDE.md dispatch-protocol section as part of BUILD-LIGHT.

**Date**: 2026-04-22T18:29:40Z

## Updates

### 2026-04-22T10:40:00Z — inception-research [agent]
- **Action:** Filled Problem Statement, Assumptions A1-A8, Exploration Plan FS1-FS4, Scope Fence, Recommendation DEFER with BUILD-LIGHT fallback and trigger-list
- **Evidence:** Episodic memory grep (no merge-conflict incidents), concerns.yaml scan, existing dispatch safeguards audit, task-sizing rule precedent (one-inception-one-question)
- **Next:** Human review via `fw task review T-1365`

### 2026-04-22T18:29:40Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: DEFER (primary), BUILD-LIGHT fallback

Rationale: The pickup identifies a real structural gap but frames it as an umbrella of 5 primitives. Per task-sizing rules (CLAUDE.md §Task Sizing: "One inception = one question"), bundling 5 independent explorations into one go/no-go creates all-or-nothing decisions and coarse progress tracking. More importantly, the motivating evidence is planned parallelism (termlink's T-1158/T-1159) not an observed merge conflict. No episodic memory entry in this framework records a multi-agent merge-conflict incident. Current safeguards (5-parallel Agent limit, write-to-disk convention, separate-process TermLink isolation, `check-dispatch.sh` guard) have held for 8+ months of production dispatch use (T-097 onwards).

Applying L-237 (mitigations shipped without a triggering incident drift toward speculative fixes): DEFER until a concrete collision occurs, OR the human explicitly requests proactive infrastructure. On trigger, DECOMPOSE into per-primitive inceptions; do not build the umbrella.

BUILD-LIGHT fallback (zero-code change): Tighten CLAUDE.md §Sub-Agent Dispatch Protocol with a single explicit rule: "Do not dispatch >1 worker touching the same file without worktree isolation. If two tasks' exploration plans or ACs both name the same file, serialise them — even if they are otherwise independent." This is ~5 lines of documentation, zero code, zero new primitive. It captures 80% of the safety value by leaning on agent compliance rather than structural enforcement.

Evidence:
- `.context/project/concerns.yaml` has no entry for multi-agent merge conflicts (grep: 0 matches for `merge conflict`, `parallel.collision`, `worktree` in open concerns)
- Existing dispatch governance: `agents/dispatch/preamble.md`, `agents/monitor/check-dispatch.sh`, 5-parallel cap in CLAUDE.md, write-to-disk convention (T-818)
- TermLink workers are independent processes — git state is shared only at the working-tree level, not at process memory
- T-097 (deep reflection on multi-agent optimization) produced the dispatch protocol — it explicitly did NOT prescribe worktree isolation, suggesting the author judged shared-tree acceptable for the observed workload
- Pickup's own framing admits the evidence is "planning" T-1158+T-1159, not a post-mortem of a collision
- L-237 precedent: premature structural fixes for unobserved problems accumulate maintenance burden

Trigger list for promoting DEFER → DECOMPOSE:
- First observed multi-agent merge conflict in episodic memory → DECOMPOSE into per-primitive inceptions, prioritise P1 (worktree) + P2 (metadata)
- Human requests worktree infrastructure independently of incident → BUILD-LIGHT + open P1 inception
- Consumer project reports collision → upgrade priority to now

Primitive-by-primitive scoping (for future DECOMPOSE):
- P1 (worktree spawn): 1 inception, ~150 LoC build. Highest mechanical value. Depends on nothing.
- P2 (metadata fields): 1 inception, ~30 LoC build (template + validator). Prerequisite for P3.
- P3 (dispatch gate): 1 inception, ~100 LoC. Depends on P2 data corpus.
- P4 (reconciliation): 1 inception, ~200 LoC. SPECULATIVE — defer until P1-P3 have shipped and are in use.
- P5 (coordination note): Not a separate task — fold into CLAUDE.md dispatch-protocol section as part of BUILD-LIGHT.

### 2026-04-22T18:29:40Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d3ae5286
- **Timestamp:** 2026-06-02T14:56:58Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
