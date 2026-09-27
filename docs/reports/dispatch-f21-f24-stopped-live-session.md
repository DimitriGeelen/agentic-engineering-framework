# Dispatch F-21/F-24 — STOPPED, live persistent session detected

Worker report for a dispatched, one-turn fix against findings F-21 and F-24
reported by a consuming project. **No fix work was performed.** The dispatch
contract's STOP CONDITION fired before any editing began: this checkout has a
live persistent session attached to it right now, and the contract is
explicit that creating a branch (or otherwise acting) in that circumstance is
what caused the prior incident (OBS-534, see below) — a refused dispatch is
the correct outcome here, not a corrected one.

## What was checked, and what it found

```
$ ps aux | grep 999-Agentic
root  3691822  pts/318  S+  Sep24  /bin/bash /opt/999-Agentic-Engineering-Framework/bin/claude-fw -c
root  3692323  pts/318  S+  Sep24  /bin/bash /opt/999-Agentic-Engineering-Framework/bin/claude-fw -c
root  3692337  pts/318  Sl+ Sep24  38:39  claude -c
```

`claude -c` (PID 3692337) has been running continuously since Sep24 against
this exact repository path, has accumulated 38+ minutes of CPU time (i.e. it
is doing work, not idle), and is attached to a real terminal (`pts/318`).

```
$ cat .context/working/focus.yaml
current_task: T-3426
focus_session: S-2026-0920-1506
```

`focus.yaml` names an active task and a live focus session, consistent with
the running process above — this is not a stale artifact from a session that
already ended.

`git status` at inspection time matched the git-status snapshot already
present at the start of this conversation (same modified-file set, same
counts), which is itself typical of this repo's own hooks/cron writing
`.context/working/*` continuously — not evidence either way on its own, but
consistent with an actively-operating checkout rather than an abandoned one.

## Why this stops the dispatch outright

The worker contract names the exact failure mode this guards against, and it
already happened once: `docs/reports/T-3466-dispatch-f15-f17-safe-commands-and-git-commit-fix.md`
(Anomaly #3) documents a prior dispatch (from `/opt/055-agentic-fleet-cockpit`)
that ran `git checkout -b` in this same shared checkout, switched the live
session's HEAD out from under it, and had its own staged work silently
absorbed into that session's next commit — provenance split across two
commits, unreconstructable from git log after the fact. That session filed
`OBS-534` about it. The contract for *this* dispatch was written with that
incident in hand and instructs: check for a live session first, and if found,
report instead of working.

The check above found exactly that condition. Repeating the prior mistake to
fix F-21/F-24 would trade a known, well-understood governance-log defect
(F-21) and a wording/measurement mismatch (F-24) — neither urgent enough to
justify the risk — for a second occurrence of a data-provenance incident this
same repository's own audit trail already flags as unresolved at the root
cause ("a worker dispatched into a project's live, persistent-session
checkout ... can switch that session's branch and absorb its uncommitted
staged work. ... nothing in this repo's gates would have caught it before the
fact").

## What was NOT done

- No branch was created.
- No file under agent/lib/policy/task source was read for the purpose of
  editing (F-21 and F-24 were not re-derived against current source, per the
  contract's own note that re-deriving happens *before* editing — since no
  editing will happen, re-deriving was skipped rather than spending the
  live session's shared checkout on read-only exploration that still risks
  colliding with concurrent writes to the same working tree).
- No task was locked, no ACs written, no `fw work-on` / `fw task create` was
  run.
- No git command that mutates state (`add`, `commit`, `checkout -b`, `stash`)
  was run. Only read-only inspection: `ps aux`, `cat`, `git status`, `git log
  -1`, `git branch --show-current`, `ls`.

## Gates that refused me, and what I did instead

None fired, because no gated action was attempted — the STOP CONDITION in the
worker contract itself, not a framework hook, is what halted this dispatch.
That is a deliberate design point worth naming for the operator: this is a
class of hazard (shared, live checkout) that this repo's own structural gates
do not yet cover automatically (per the T-3466 report's closing note, `fw
doctor`'s T-3187 branch-identity guard would have surfaced the wrong-branch
symptom, but only in output nobody was polling in real time). The prevention
that actually worked here was the dispatch contract's own written STOP
CONDITION, checked explicitly, by hand, before any action — not a mechanical
gate.

## Branch and push state

- No branch created. Current branch remains `bleeding-edge`, HEAD unchanged
  (`1a78bc107`), exactly as found.
- Nothing staged, nothing committed, nothing pushed.
- This report file itself is a new, untracked file (`docs/reports/dispatch-f21-f24-stopped-live-session.md`).
  It was not `git add`ed or committed by this worker, to avoid touching the
  shared index the live session may be using. Whether/how it gets committed
  is left to the operator or to the live session's own next commit.

## Recommendation to the operator

Re-dispatch F-21 and F-24 once the live session on `pts/318` (task T-3426,
focus session S-2026-0920-1506) has ended or handed over, or dispatch into an
isolated worktree instead of this shared checkout (note: the framework's own
worktree policy is opt-in-only per operator directive, so that would need an
explicit instruction, not a default). Nothing about F-21 or F-24 themselves
is time-critical enough to justify acting into a live checkout — F-21 is a
config/schema mismatch that only manifests on first bypass-log write (not
imminent data loss), and F-24 is a wording/measurement mismatch in an audit
PASS line (cosmetic-but-important, not urgent).

## Anything that contradicts either finding

Not evaluated — re-deriving F-21/F-24 against current source was skipped
entirely per the STOP CONDITION (see "What was NOT done" above). No claim is
made here about whether either finding still reproduces in this repo's
current state.
