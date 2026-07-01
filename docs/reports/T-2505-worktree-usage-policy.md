# T-2505 — Worktree usage policy: refine the per-task default

**Status:** inception (exploration) — Recommendation: DEFER (pending exploration)
**Opened:** 2026-07-01
**Trigger:** operator observation mid-session — *"seems the worktrees give us a lot of difficulties right now"* + *"did we not re-evaluate worktree separation, refining not to use worktrees for every task?"*

## Problem Statement

The framework has tooling to **create** worktrees reliably (T-2464 inception → T-2465/2466/2469: centralized root-resolution, `fw worktree create|status`, merge-back plumbing) but **no codified *usage* / *lifecycle* policy**. Worktrees are created ad-hoc and become long-lived, shared, multi-task catch-alls. This produces two recurring, structurally-linked difficulties (both observed live this session):

1. **All-or-nothing landing.** A long-lived worktree branch accumulates many unrelated tasks' commits. FF merge-back is all-or-nothing, so landing one task's fix necessarily carries every commit beneath it.
2. **Stranded divergence.** The MAIN checkout and the worktree drift apart, with real uncommitted work stranded on the wrong side — blocking clean go-live/merge.

## Evidence gathered so far (this session)

- **9-commit bundled land (difficulty #1):** landing T-2502 (2 commits) via `fw integrate run --push` carried 9 commits — T-2504, two Watchtower GO decisions (T-2324, T-2453), and 3 session-handover commits. Cause: `inception-gov-payload-mediation` is a long-lived, multi-session worktree holding 6+ distinct task IDs.
- **Stranded MAIN divergence (difficulty #2):** MAIN checkout (`t2417-fw-sessions`) has **267 uncommitted changes**; of the 6 real source files, `agents/audit/audit.sh` carries a large uncommitted change belonging to **T-2353** (audit `--emit-tasks`), plus an AC-structure checker (untracked files) and a BVP-estimator change. This work is **committed nowhere** (working-tree only) and blocks taking the host live for T-2502 (audit.sh conflict).
- **No prohibiting policy exists (VERIFIED):** the only worktree usage decision is **D-026** (2026-04-25, T-1483) — *"WorktreePool … one worktree per audit run, checkout per task"* — audit-specific. There is **no decision** refining general usage to "not per-task." The refinement the operator recalls was discussed-adjacent (during T-2464 reliability work) but never codified. This is the gap.

## Candidate policies to evaluate (IW-mapped, not yet assessed)

- **C1 (IW-1) — No worktree for small/mechanical tasks.** Default: work directly on the session branch; land via normal push. Reserve worktrees for genuine parallel isolation. (Matches operator intuition.)
- **C2 (IW-2) — One-task-per-worktree + land-and-prune lifecycle.** Keep worktrees but forbid long-lived shared ones; a worktree is created for a task, landed on completion, and pruned. Add lifecycle tooling/gate.
- **C3 (IW-3) — Worktree-usage gate / advisory.** A check (doctor/audit) that flags long-lived worktrees holding >N tasks or >D days, and MAIN/worktree divergence with stranded uncommitted source.
- **C4 — Combination** (e.g. C1 default + C3 guardrail).

## Open questions (mirror of task-file IW-N)

- **IW-1** — C1 as default? (confidence 1, deferred)
- **IW-2** — C2 lifecycle discipline shape? (confidence 1, deferred)
- **IW-3** — C3 doctor/audit advisory? (confidence 1, deferred)
- Cost/frequency: mine episodic for how many sessions hit worktree difficulties + volume of stranded work.
- Harness interaction: the background-job "isolate via worktree unless already in one" default — this session *inherited* a long-lived worktree rather than creating a fresh one. Does C1 conflict with that default?
- MAIN stranded-work reconciliation (T-2353 et al.) is a **separate task**, but its shape informs the lifecycle design.

## Dialogue Log

### 2026-07-01 — trigger & framing
- **Operator:** "seems the worktrees give us a lot of difficulties right now" and asked whether we'd re-evaluated worktree separation, "refining not to use worktrees for every task."
- **Agent finding:** worktree *reliability* was re-evaluated and hardened (T-2464+), but the *usage* refinement was never codified — genuine gap. Operator authorized filing this inception.
- **Course correction captured:** the goal is a *usage/lifecycle* policy, distinct from the *reliability* fixes already shipped.

## Recommendation

**DEFER** — exploration just opened; candidates C1–C4 not yet evaluated against episodic evidence and the four directives. Recommendation (GO on a specific candidate / NO-GO) follows the exploration dialogue.
