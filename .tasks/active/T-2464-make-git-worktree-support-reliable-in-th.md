---
id: T-2464
name: "Make git-worktree support reliable in the framework — systemic root-resolution + parallel-work/merge-back lifecycle"
description: >
  Inception: Make git-worktree support reliable in the framework — systemic root-resolution + parallel-work/merge-back lifecycle

status: captured
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-06-23T11:13:13Z
last_update: 2026-06-23T11:13:13Z
date_finished: null
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
---

# T-2464: Make git-worktree support reliable in the framework — systemic root-resolution + parallel-work/merge-back lifecycle

## Problem Statement

Git-worktree-based parallel work is already in use in this framework (arc-011 dispatch,
livefire demos, this session). But the substrate underneath it is **not reliable**, in two
independent ways:

1. **Root-resolution defect** — framework hooks are wired by main's absolute path, so when a
   hook fires in a worktree/spawned session it resolves `PROJECT_ROOT` from the hook process
   cwd / inherited env instead of the per-call session context, reading the *wrong* project's
   state. This has been patched per-surface 7+ times (T-2463/T-2446/T-2389/T-2392/T-2289/
   T-2054/T-2462) — whack-a-mole, never centralized.
2. **Parallel-work / merge-back lifecycle** — the framework has *no* support for creating,
   tracking, or reconciling worktrees. Hit live this session: master locked in another
   worktree, main dir on a session branch (so "merge to master" ≠ "live"), FF ambiguity,
   vendored `+x` loss.

**For whom:** every agent/operator doing isolated parallel work. **Why now:** the operator
explicitly asked whether we're systemically fixing this or just patching symptoms — and the
evidence says symptoms. Full RCA: `docs/reports/T-2464-worktree-reliability-rca.md`.

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->
- Centralizing root-resolution in one shared per-call resolver removes the recurring bug
  class without regressing non-worktree sessions (T-2463 proves the re-anchor is safe as a
  no-op when cwd==root).
- A `fw worktree` lifecycle is worth building (the manual dance is error-prone but
  low-frequency — sequencing it after the resolver is acceptable).

## Open Questions

- **IW-1: Should root-resolution be fixed centrally (one shared resolver all hooks call) or
  left as per-hook re-anchors?**
  confidence: 2
  disposition: answered
  rationale: 7+ per-hook patches with identical logic = textbook centralization candidate;
  RCA §"Systemic fix shape". Per-hook leaves the join untested (L-399).

- **IW-2: Does the lifecycle half (`fw worktree`) belong in the same decision, or split?**
  confidence: 2
  disposition: answered
  rationale: Same domain, shares the "is it live" semantics; recommended as Candidate C
  (both, sequenced) — resolver first. RCA §"Candidate decompositions".

- **IW-3: Will the T-2054/T-2462 safe-list exemptions still be needed once resolution is
  correct?**
  confidence: 1
  disposition: deferred
  rationale: Plausibly removable, but verifying requires the central resolver to land first;
  revisit during the resolution build slice.

## Exploration Plan

<!-- How will we validate assumptions? Spikes, prototypes, research? Time-box each. -->
RCA is complete (this artifact). On GO, decompose into build slices:
1. **Resolution slice** — shared per-call resolver in `lib/paths.sh` (or a hook preamble) +
   generalize T-2463's re-anchor + suite-level worktree-invocation test.
2. **Lifecycle slice** — `fw worktree create|status|merge-back` + doctor coverage.
3. **Cleanup slice** — vendored `+x` preservation; reassess safe-list exemptions (IW-3).

## Technical Constraints

<!-- What platform, browser, network, or hardware constraints apply?
     For web apps: HTTPS requirements, browser API restrictions, CORS, device support.
     For hardware APIs (mic, camera, GPS, Bluetooth): access requirements, permissions model.
     For infrastructure: network topology, firewall rules, latency bounds.
     Fill this BEFORE building. Discovering constraints after implementation wastes sessions. -->

## Scope Fence

**IN:** systemic root-resolution for framework hooks in worktree/spawned sessions; a
`fw worktree` create/status/merge-back lifecycle; doctor coverage; vendored `+x` preservation.
**OUT:** TermLink's machine-wide model (deliberate inverse, unchanged); non-git isolation
mechanisms; redesigning the dispatch substrate itself (arc-011 consumes worktrees, doesn't
define them).

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [ ] Problem statement validated
<!-- @auto-tick-on-decide -->
- [ ] Assumptions tested
<!-- @auto-tick-on-decide -->
- [ ] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision
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

**Rationale:**

7+ point-fixes (T-2463/T-2446/T-2389/T-2392/T-2289/T-2054/T-2462) share one root: hooks wired by main's absolute path resolve PROJECT_ROOT from process cwd/inherited env, not per-call session context. Whack-a-mole confirmed. Merge-back/parallel-work half has zero framework support (hit live this session: master-locked-in-worktree, main-on-session-branch, FF ambiguity, vendored +x loss). Systematize via shared per-call resolver + fw worktree lifecycle.

**Evidence:**

- Full RCA: `docs/reports/T-2464-worktree-reliability-rca.md` (mechanism + evidence table + fix shapes).
- Recurring root, 7+ tasks: T-2463 (active-task gate), T-2446 (CLAUDE_PROJECT_DIR trust),
  T-2389/T-2390 (spawned→/root budget blind), T-2392/T-2400 (budget freeze), T-2289
  (paths.sh re-derive OBS-053), T-2054/T-2462 (safe-list exemptions).
- Prototype of the central fix already proven: T-2463 re-anchors from stdin `cwd`, 5/5 new
  bats + 47/47 hook suite green, no-op for non-worktree sessions.
- Lifecycle gap hit live this session: master locked in `livefire-t2389` worktree; main dir
  on `t2417-fw-sessions` (so merge-to-master ≠ live here); FF path needed manual checking;
  vendored `.agentic-framework/agents/context/*.sh` lost `+x`.
- Existing primitive to build on: `fw_is_linked_worktree` (`lib/paths.sh:144`).

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
