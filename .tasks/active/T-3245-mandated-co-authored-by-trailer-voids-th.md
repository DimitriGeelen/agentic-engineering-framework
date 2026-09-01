---
id: T-3245
name: "mandated Co-Authored-By trailer voids the partial-complete bare-commit allowance"
description: >
  The check-active-task gate grants a partial-complete task the right to commit its
  own
  work, on the condition the commit runs "bare" — no redirect, heredoc or write pattern.
  The Co-Authored-By trailer CLAUDE.md mandates contains an email in angle brackets,
  which
  the write-pattern matcher reads as a shell redirect. So the required trailer voids
  the
  allowance the block message tells you to use.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [bug, gate, false-positive]
components: [agents/context/lib/safe-commands.sh]
related_tasks: [T-3179, T-3236, T-3174, T-3243, T-3237, T-3238]
created: 2026-09-01T10:40:00Z
last_update: '2026-09-01T10:45:10Z'
date_finished:
bvp_scores_proposed:
  - ts: '2026-09-01T10:40:18Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 1
      F1: 1
      F2: 1
    rationale: D1=1 (body:fix-without-learning); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=1 (body/components:prompt-incidental); F1=1 
      (body/components:context-fabric-incidental); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-09-01T10:45:10Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 1
      tier: 2
      effort: 7
    rationale: blast_radius=1 (single-component); tier=2 (workflow:build); 
      effort=7 (lines=116,acs=5)
    rubric_sha: e4a00f38e801
---

# T-3245: the mandated commit trailer trips the gate that tells you to drop redirects

## Context

Reproduced live during T-3243's close, twice, before the cause was isolated.

A task at `status: work-completed` still sitting in `active/` (partial-complete, awaiting
a Human AC) is explicitly permitted to commit its own verified work. The block message
says so in its own words:

```
Note: 'git commit' IS allowed here (T-3179) — a partial-complete task
may always checkpoint its own verified work under its own ID. If you
were trying to commit, drop the redirect/heredoc from the line and
run the commit bare; write patterns void the allowance.
```

CLAUDE.md separately mandates, for every commit:

```
Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
```

Those two rules cannot both be followed. `<noreply@anthropic.com>` matches the
redirect pattern, so a commit carrying the required trailer is never "bare".

## Reproduction (measured, not reasoned)

Identical staged tree, identical task state, two commits differing only in the trailer:

```
git commit -q -m "T-3243: partial-complete …" -m "… <noreply@anthropic.com>"
  -> BLOCKED: Task T-3243 has status 'work-completed'.
     Why: it matches a file-write pattern (a redirect, rm, tee, sed -i, or a heredoc).

git commit -q -m "T-3243: partial-complete … one [REVIEW] left on the two new /config rows"
  -> succeeds
```

The second command is the first with the angle-bracketed email removed. Nothing else
changed.

## Why this is worse than an ordinary false positive

Three things compound:

1. **The gate's own remedy is the thing that fails.** The block message names exactly one
   escape — "run the commit bare" — and the mandated trailer makes that escape unreachable.
   An agent that follows both instructions loops.

2. **It is invisible until the task is partial-complete.** In `started-work` the same
   trailer commits fine, because the write-pattern check only voids the *allowance*, and
   at `started-work` no allowance is needed. So the defect appears only at the moment a
   task is being closed — the least convenient moment, and one where the agent is most
   likely to reach for `--no-verify` or `--force`.

3. **The plausible workarounds are all worse.** Dropping the trailer violates CLAUDE.md;
   `--no-verify` is a Tier-2 bypass logged against a task that did nothing wrong; writing
   the message to a file is itself a write pattern. Every exit is a governance violation,
   which is how a false positive becomes a bypass-training exercise.

This is the third member of a cluster already on the register: T-3237 (bare `wget URL` is
safe-listed though it writes cwd), T-3238 (`find` unconditionally safe-listed including
`-delete` and `-exec rm`). Those two are the matcher being too *permissive*; this is the
same matcher being too *strict* on a string that is not a shell operator at all because it
sits inside a quoted argument. The common root is that the matcher scans the raw command
text without regard for quoting.

## Acceptance Criteria

### Agent

- [ ] A `git commit` whose message contains an angle-bracketed email in a quoted `-m`
  argument is NOT treated as a write pattern, and the partial-complete bare-commit
  allowance holds. Pinned by a test that reproduces the two commands above.
- [ ] Control leg: a genuine redirect OUTSIDE quotes (`git commit -m "x" > f`) is still
  refused. Fixing the false positive must not open a false negative.
- [ ] Control leg: the existing refusals for `rm`, `tee`, `sed -i` and heredocs are
  unchanged, asserted against the current behaviour rather than assumed.
- [ ] Decide and record the scope of the fix: quote-aware scanning is the general answer
  but has blast radius across every gate that consumes `safe-commands.sh`; a narrow
  "angle-bracketed token containing @ is not a redirect" rule is cheaper and covers the
  measured case. Either is defensible — the point is that it is chosen, with the
  trade-off written down.
- [ ] CLAUDE.md's commit-trailer instruction and the block message's "run it bare" remedy
  are consistent after the fix — verified by performing the T-3243 close commit WITH the
  trailer.

## Verification

# (to be written with the fix)
bash -n agents/context/lib/safe-commands.sh

## RCA

**Symptom.** A partial-complete task cannot commit its own work while carrying the commit
trailer the project mandates, and the gate's stated remedy does not resolve it.

**Root cause.** The write-pattern matcher in `agents/context/lib/safe-commands.sh` scans
the raw command string for redirect characters without tracking quoting, so `<...>` inside
a quoted `-m` argument is indistinguishable from a real `<` redirect operator.

**Why structurally allowed.** The allowance this defeats (T-3179) and the trailer
requirement were introduced independently, and each is correct in isolation. Nothing
tests the two together, because the conflict only manifests in one narrow state
(partial-complete) that no test drives — the same reason T-3243's four supervisor defects
survived. Two rules, each verified alone, contradicting each other in a state neither
author was looking at.

**Prevention.** A test that performs a real partial-complete commit with the mandated
trailer — i.e. exercising the documented happy path end to end rather than either rule on
its own.

### 2026-09-01T10:40:18Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
