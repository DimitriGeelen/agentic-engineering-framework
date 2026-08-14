# T-100200 — Session-on-master enforcement: inception

**Type:** inception · **Status:** explored · **Recommendation:** GO — scoped to mech C (WARN→FAIL escalation) + file vector-#5 as its own task; hold mech B as conditional follow-up
**Question:** Should the session-on-master invariant be enforced by a *blocking* gate — and if so, what mechanism closes the drift without breaking the worktree parallelism flow?

## Why this is an inception, not a build

Three independent signals (recorded before exploration, so they can be checked):

1. **The naive gate breaks parallelism.** "Block governance commits onto a non-master branch" fires inside *every* worktree — worktree branches are non-master and commit task files during a build. First-draft enforcement breaks the flow it's meant to protect.
2. **The discriminator is non-obvious.** "Persistent session branch" vs "worktree branch" — both non-master. The likely real rule is "the *main checkout* must be on master," but the edge cases (mid-migration, consumers, `claude-fw`, detached HEAD) need walking before they're baked into a hook.
3. **The root-cause claim is unvalidated.** T-100194/199 named the persistent-session branch as THE root of drift. That has not been proven *complete*. If other drift vectors exist, session-on-master is scoped wrong — and we'd want to know before writing a gate.

## What already shipped (the mitigation this inception decides whether to harden)

- **Decision:** session-on-master (T-100196, option c). Mitigation, not enforcement.
- **`fw worktree gc`** — content-verified reclaim (tested).
- **`fw sync`** — trunk reconcile (smoke-tested only).
- **CLAUDE.md §Trunk-Based Session Flow** — the invariant as a *documented practice*.
- **diverged-fork detector** (T-100195) — WARNs, does not block.

Current state = **mitigation + detection**, explicitly NOT a structural guarantee. This inception decides whether to close that gap.

## Open Questions (mirror of task IW-N)

- **IW-1** — Is the persistent-session branch the COMPLETE root of drift, or are there other vectors session-on-master doesn't close? (Spike 1)
- **IW-2** — Is there a discriminator that blocks session-branch drift WITHOUT breaking worktree parallelism? (Spike 2)
- **IW-3** — Which mechanism (A/B/C/D) has the right risk-benefit? (Spike 3)

## Exploration plan

### Spike 1 — Enumerate ALL drift vectors (validate the root-cause claim) — **DONE 2026-07-05**
Is the persistent-session branch the *complete* root, or are there other ways the working state diverges from origin/master?

#### Findings — the drift-vector table

Every way the persistent session's working state can diverge from `origin/master`, each
marked for whether **session-on-master (option c)** closes it:

| # | Drift vector | Closed by session-on-master? | Residual control |
|---|--------------|------------------------------|------------------|
| 1 | **Persistent-session named branch** accumulates governance commits (handovers, task-sync, context memory) that never merge back — the chronic, systemic form. | **YES** — the mechanism eliminates the session branch. No branch → nothing to accumulate. This is the vector option-c targets. | n/a (closed by construction) |
| 2 | **Manual non-master checkout in the MAIN checkout** — agent/operator runs `git checkout -b foo` in main and commits. The *acute, general* form of #1. | **NO** — option-c is a *practice*; nothing structurally prevents a manual non-master checkout in the main checkout. | **This is the enforcement target** (IW-3 mech A/B). `diverged-fork` WARN (T-100195) *detects* it today. |
| 3 | **Background/cron writers** commit to whatever branch the main checkout is on — amplifier that deepens divergence if main is off-master. | **YES (conditionally)** — if main is on master (the practice holds), crons commit to master. Neutralised as long as #2 doesn't occur. | Inherits #2's enforcement. |
| 4 | **Interrupted `fw integrate`** — self-removal hang. If the push completed first, code IS on master (worktree is litter); if it didn't, genuine unlanded work on the worktree branch. Seen 3× this session. | **NO** — worktree integrate mechanics are independent of session location. | `fw worktree gc` content-verify (landed→reclaim, unlanded→keep+surface). Prevention (integrate not self-removing cwd) is a separate fix. |
| 5 | **Go-live `git reset --hard origin/master` against a STALE remote-tracking ref** — resets working tree to an OLD tip because `origin/master` was never fetched. **Hit live this session** (reverted landed work in the working copy; recoverable from real origin). | **NO** — orthogonal. Even a session *on* master, reset without a prior `git fetch`, lands on the stale ref. | **NEW independent vector** — needs `git fetch` before any go-live reset. Deserves its own task regardless of this inception's outcome. |
| 6 | **Abandoned worktree branch** — build started in a worktree, context ran out, never integrated. Unlanded commits on a linked branch. | **NO** — worktree lifecycle, not session location. | `fw worktree gc` surfaces it (keep). Detection, not prevention. |
| 7 | **Consumer-side vendored `.agentic-framework/` re-derivation drift** — a *different repo's* drift. | **N/A** — out of scope (gap-homing: belongs in the consumer). | Consumer's own `fw upgrade` discipline. |

#### Conclusion (answers IW-1)

The persistent-session branch is the **DOMINANT** root of drift but **NOT the complete** root.
Session-on-master closes vector **1** (the dominant, chronic form) and vector **3** (an
amplifier, conditionally). **Four residual vectors remain:**

- **#2** (manual non-master checkout in main) — the true **enforcement target**. This inception's
  IW-3 mechanism question narrows to *just this vector*, because #1 is already handled by the
  practice and the WARN already detects #2.
- **#4 / #6** — worktree-lifecycle drift, already mitigated by the shipped `fw worktree gc`
  content-verify (detection, not prevention).
- **#5** — a newly-surfaced, independent vector (stale-ref go-live reset) that session-on-master
  does **not** touch and that warrants **its own task** (fetch-before-reset in the go-live path).

**So "how can you be sure it's fixed?" — honest answer: it is not *fully* fixed.** The dominant
vector is closed by practice; the enforcement decision is scoped to vector #2 alone; and #5 is a
separate defect this spike newly surfaced.

### Spike 2 — The discriminator — **DONE 2026-07-05**
Candidate rule: **"the MAIN checkout (`git worktree list` first record) must be on master/main;
linked worktrees may be on anything."** Pressure-tested against the edge cases:

| Edge case | Does the discriminator hold? | Constraint it imposes on the mechanism |
|-----------|------------------------------|----------------------------------------|
| **Mid-migration** (the go-live `git checkout -B master origin/master` flip itself) | The *checkout* must be allowed; only *committing off-master* is the harm. | A gate must fire on **commit**, not on **branch state at session start** — else it blocks the very flip that fixes drift. Favors mech B over A. |
| **Consumer projects** | Consumers legitimately work on their own feature branches; "main on master" is a *framework-repo* rule, not universal. | Gate MUST be scoped to the framework repo / an explicit `session-on-master` opt-in. A blanket ship would break every consumer's branch workflow. **Hard constraint.** |
| **`claude-fw` startup** | Main *should* be on master at launch, but a hard block at startup risks locking the operator out of their own session. | Startup-time enforcement wants to be soft (WARN), not hard. Favors C over A. |
| **Detached HEAD** (bisect, CI checkout of a SHA) | `git worktree list` shows `(detached HEAD)` — "on master" is false → false positive. | Needs an explicit detached-HEAD exemption. |
| **CI** | CI checks out a PR branch or a SHA (detached), non-interactive. | Needs a CI exemption (`$CI` / non-interactive detection). |

**IW-2 answer:** a discriminator exists, but it is **NOT safe as a blanket rule.** It is sound
only when (a) scoped to the framework repo / an explicit opt-in (consumers run their own
branches), (b) exempting detached HEAD and CI, and (c) allowing the checkout/flip operation
itself. A **commit-target gate (mech B)** satisfies all three naturally — it fires only at the
moment of the harmful action (committing governance state to a non-master main checkout). A
**session-start refusal (mech A)** fights every one of these edges.

### Spike 3 — Candidate mechanisms — **DONE 2026-07-05**

| Mech | What it does | Verdict |
|------|--------------|---------|
| **A — session-start hard refusal** | SessionStart hook BLOCKS when main is on a divergent non-master branch. | **Reject.** Highest lockout risk; false-positives on consumer / CI / detached-HEAD / mid-migration (Spike 2). Strictly dominated by B. |
| **B — commit-target gate** | PreToolUse/commit hook blocks committing *governance paths* to a non-master branch *in the main checkout*, exempting linked worktrees + CI + detached HEAD. | **Hold (conditional follow-up).** The only mechanism that *prevents* vector #2 without collateral — but Spike 1 shows #2 is a **deliberate-action** vector (someone must `git checkout -b` in main), already *detected* by the WARN. Prevention buys the detection→prevention gap for a non-accidental event. Moderate build + bypass-parity cost (T-1890). |
| **C — WARN→FAIL escalation** | doctor/audit escalates `diverged-fork` from WARN to FAIL after N days. | **Adopt now.** Detection-with-teeth. Zero lockout risk, no consumer/CI collateral, cheap. Closes the "WARN can be ignored forever" gap that D leaves open. |
| **D — do nothing (keep mitigation+detection)** | Practice + WARN + `fw worktree gc` only. | **Reject as the endpoint.** Undersells: the WARN is ignorable indefinitely (that ignorability is what let the original drift persist). C is D + teeth for near-zero cost. |

### Assumptions — verdicts

- **A1** (persistent-session branch is the complete/dominant root) → **PARTIALLY CONFIRMED.**
  Dominant, *not* complete. Spike 1 enumerated 4 residual vectors (#2 enforcement-target,
  #4/#6 gc-mitigated, #5 new-independent).
- **A2** ("main on master" is a safe discriminator) → **CONFIRMED WITH CONSTRAINTS.** Safe only
  when scoped to the framework repo + exempting detached-HEAD/CI + firing on commit not startup
  (Spike 2).
- **A3** (a blocking gate's lockout risk is acceptable) → **CONTEXT-DEPENDENT.** Acceptable for
  mech B *with* a clean env-var bypass (T-1890 parity) — but Spike 3 finds B's marginal value
  over C is low for a deliberate-action vector, so the lockout risk isn't worth paying *yet*.

## Recommendation (post-exploration)

**GO — scoped to mechanism C (escalate the `diverged-fork` WARN → FAIL after N days), NOT a
blocking commit-gate; and file drift-vector #5 (stale-ref go-live reset) as its own separate task.**

**Rationale (evidence, not confidence):**
- Spike 1 proved the **dominant** drift vector (#1, persistent-session branch) is **already
  closed by the shipped session-on-master practice** — so a heavy blocking gate would be
  defending a door that's already shut.
- The residual **enforcement target narrows to vector #2** (a *deliberate* `git checkout -b` in
  the main checkout), which the `diverged-fork` WARN (T-100195) **already detects**. The only gap
  is that a WARN is ignorable indefinitely — exactly what mech **C** (WARN→FAIL escalation) closes,
  at **zero lockout risk and near-zero build cost**.
- Mech **B** (commit-target gate) is the only true *prevention*, but Spike 2 shows it carries real
  consumer/CI/detached-HEAD collateral requiring careful scoping, and Spike 3 shows its marginal
  value over C is low for a non-accidental vector. **Hold B as a conditional follow-up** — build it
  only if vector-#2 incidents recur *despite* the escalated FAIL.
- **Vector #5 is independent** of the A/B/C/D axis and was newly surfaced by this spike; it needs
  its own task (`git fetch` before any go-live `git reset --hard origin/master`) regardless of the
  decision here.

This is a **GO** (not DEFER): Spikes 1–3 are complete, assumptions are adjudicated, and the
recommendation rests on the enumerated evidence — the open question was an *evidence* gap that the
spikes closed, not a confidence hedge.

## Dialogue Log

<!-- C-001 extension: record the operator's questions, course corrections, and the
     reasoning as it evolves. Seeded from the chat that triggered this inception. -->

### 2026-07-05 — Trigger
- Operator challenged two overclaims: (1) "no session branch ever forms" — wrong, worktree branches form on purpose for parallelism; corrected to "no *persistent-session* branch". (2) "the fix is live / can't recur" — overclaim; current state is mitigation+detection, not enforcement. Operator asked "how can you be sure it's fixed?" -> honest answer: I can't, the invariant isn't enforced.
- Operator asked "should we incept first?" -> yes; this artifact is the result.
- **Course correction captured:** enforcement must NOT break the worktree parallelism flow (operator's explicit reminder that branches are created on purpose).

### 2026-07-05 — Exploration (Spikes 1–3)
- **The reframe:** Spike 1's drift-vector table overturned the framing. The operator's blunt
  "how can you be sure it's fixed?" was *correct* — session-on-master is NOT a complete fix. It
  closes the **dominant** vector (#1) by practice but leaves 4 residual vectors. The honest answer
  is now written into the artifact rather than hedged.
- **The scope collapse:** once #1 is recognised as already-closed-by-practice, the enforcement
  question shrinks from "gate the whole invariant" to "gate *just vector #2* (deliberate non-master
  checkout in main)" — which the `diverged-fork` WARN already *detects*. That collapsed the
  A/B/C/D choice: the only real gap is a WARN that can be ignored forever → mech **C** (escalate to
  FAIL) is the cheap, no-lockout close. Mech B (true prevention) is held back because its marginal
  value over C is low for a *deliberate-action* vector and its consumer/CI collateral (Spike 2) is
  real.
- **New defect surfaced:** Spike 1 exposed vector **#5** (go-live `git reset --hard origin/master`
  against a stale ref — the one that bit the operator live this session) as **independent** of this
  inception's axis. Filed as its own follow-up rather than folded in — one bug, one task.
- **Recommendation is GO, not DEFER:** per feedback_defer_for_evidence_not_confidence — the spikes
  closed the *evidence* gap, so a DEFER here would be a confidence hedge, which the discipline
  forbids. The advisory is GO-scoped-to-C.
