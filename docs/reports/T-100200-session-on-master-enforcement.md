# T-100200 — Session-on-master enforcement: inception

**Type:** inception · **Status:** exploring · **Recommendation:** DEFER (exploration pending)
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

### Spike 1 — Enumerate ALL drift vectors (validate the root-cause claim)
Is the persistent-session branch the *complete* root, or are there other ways the working state diverges from origin/master? Candidates to investigate:
- Persistent-session branch accumulating unmerged governance commits (known — T-100194).
- Interrupted `fw integrate` leaving an un-landed worktree branch (seen 3x this session — the self-removal timeout).
- Consumer-side vendored drift (`.agentic-framework/` re-derivation).
- Cron / background writers committing on whatever branch is checked out.
- Go-live `git reset --hard origin/master` against a **stale** remote-tracking ref (just hit live — reset to the old tip because main never fetched).
- **Output:** a complete drift-vector table; each marked "closed by session-on-master? Y/N".

### Spike 2 — The discriminator
Mechanically distinguish a persistent-session branch from a legitimate worktree branch. Candidate: "the MAIN checkout (`git worktree list` first record) must be on master/main; linked worktrees may be on anything." Test against: mid-migration, consumer projects, `claude-fw` startup, detached HEAD, CI.

### Spike 3 — Candidate mechanisms (to pressure-test, NOT yet chosen)
- **A - session-start refusal:** a SessionStart hook that BLOCKS (not warns) when the main checkout is on a divergent non-master branch. Risk: lockout; consumer/CI false-positives.
- **B - commit-target gate:** a PreToolUse/commit hook that blocks committing *governance paths* to a non-master branch *in the main checkout* (exempting linked worktrees). Risk: discriminator complexity.
- **C - promote the existing WARN to a periodic hard-stop:** doctor/audit escalates diverged-fork from WARN to FAIL after N days. Softer; detection-with-teeth rather than prevention.
- **D - do nothing more (keep mitigation+detection).** Valid outcome if Spike 1 shows the practice + WARN is sufficient and enforcement risk outweighs benefit.

### Assumptions to validate
- A1: the persistent-session branch is the complete (or dominant) root of drift.
- A2: "main checkout on master" is a discriminator that doesn't break worktrees/consumers/claude-fw.
- A3: a blocking gate's lockout risk is acceptable / has a clean bypass.

## Candidate recommendation (pre-exploration, to be confirmed or overturned)

Leaning **B or C over A** (A's lockout risk is highest), with **D as the honest fallback** if Spike 1 shows enforcement buys little over the shipped mitigation. **Not committing** until Spike 1 (drift-vector completeness) is done — that's the DEFER.

## Dialogue Log

<!-- C-001 extension: record the operator's questions, course corrections, and the
     reasoning as it evolves. Seeded from the chat that triggered this inception. -->

### 2026-07-05 — Trigger
- Operator challenged two overclaims: (1) "no session branch ever forms" — wrong, worktree branches form on purpose for parallelism; corrected to "no *persistent-session* branch". (2) "the fix is live / can't recur" — overclaim; current state is mitigation+detection, not enforcement. Operator asked "how can you be sure it's fixed?" -> honest answer: I can't, the invariant isn't enforced.
- Operator asked "should we incept first?" -> yes; this artifact is the result.
- **Course correction captured:** enforcement must NOT break the worktree parallelism flow (operator's explicit reminder that branches are created on purpose).
