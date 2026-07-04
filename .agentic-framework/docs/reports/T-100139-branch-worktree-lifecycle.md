# T-100139: Branch/Worktree Lifecycle Policy — Research Artifact

**Date:** 2026-07-04
**Trigger:** Operator: "critically review our branching / worktree process, i get the
impression we are polluting our repo with a lot of outstanding branches / worktrees"
**Status:** evidence complete; recommendation GO

## Findings (measured 2026-07-04, pre-cleanup)

### F1 — Merged debris dominated the branch list
29 of 36 local branches were `ahead:0` vs origin/master — fully merged, never deleted.
Age profile: Feb/Mar fix-branches (4), June-13..16 task/close/handover branches (23),
duplicate pairs (`livefire-demo-2389`/`-2390` identical sha; `origin-*` accident
branches named after remote refs). **Cleaned by T-100138** (28 local + 4 remote
deleted, arc012 worktree torn down). Zero information loss — verified per-branch
`ahead:0` before every deletion.

### F2 — Divergent strands: the dangerous half (STILL OPEN)
| Branch | Ahead | Behind master | Note |
|---|---|---|---|
| t2416-fw-safe-mode-hook-timing | 139 | 248 | current session trunk; name refers to a task closed days ago |
| t2417-fw-sessions | 58 | 215 | +10 unpushed to its own origin ref |
| worktree-rca-worktree-push-strand | 37 | 215 | live worktree, 5 dirty files |
| t2353-audit-emit-tasks | 22 | 248 | stale since 06-27 |
| audit-remediation-t2416 | 1 | — | single stranded commit |
| learning/precompact-cleanup | 1 | — | stranded since March |
| origin/fix/T-002, origin/fix/T-003 | 1 each | — | remote-only, unmerged |
| origin/main | 1 | — | stale branch named like a default; carries one May commit (T-1451 cherry) — naming hazard |

All strands touch the same core files (audit.sh, bin/fw, lib/) → compounding merge
conflict debt. The longer they live, the scarier the merge-back, so it defers — a
vicious circle. Same class as T-2494 (deploy whack-a-mole) and G-083 (MAIN↔worktree
divergence blindness).

### F3 — Worktrees outlive their purpose
arc012-continuous-run-s4s5's branch was fully merged, yet the worktree persisted with
40 dirty files. Triage found 4 handover records + T-2401 completion metadata that had
never landed in MAIN (now rescued), buried in 35 files of state noise. A stale
TermLink session (`t2461-bats-runner`) from another worktree was still registered
weeks after its task closed.

### F4 — Zero observability
Neither `fw doctor` nor `fw audit` counts: merged-but-undeleted branches, branch↔master
divergence, worktrees whose branch is merged, dirty-worktree age, or stranded remote
refs. The pollution was invisible until the operator's intuition flagged it. The
framework should have flagged it first (Reliability directive: no silent failures).

## Root causes

1. **No branch lifecycle** — branches are created per task/session but nothing deletes
   on merge; `fw integrate run` lands merges and leaves the source branch.
2. **Session branches become accidental trunks** — branch-per-task naming + multi-day
   autonomous sessions + handover auto-commit-to-current-branch = branches whose names
   stopped describing content 100+ commits ago.
3. **No master-sync cadence** — long-lived branches never merge master in; divergence
   compounds silently (248 behind).
4. **No teardown step in worktree flow** — nothing removes a worktree when its branch
   lands; unlanded context artifacts (handovers, task metadata) rot in dirty files.

## Candidates

- **C1: integrate-deletes-on-landing.** `fw integrate run` deletes the source branch
  (local + remote) after a verified landing; `--keep-branch` opt-out. Closes the
  debris tap at source. Effort: S.
- **C2: doctor/audit branch-hygiene section.** WARNs for: merged-but-undeleted
  branches; branches > N behind master (default 50); worktree whose branch is merged;
  worktree dirty files older than N days; remote refs ahead:0. Closes F4. Effort: M.
- **C3: handover divergence surfacing.** Session-end handover prints current branch
  ahead/behind vs origin/master; > threshold adds a "merge-back overdue" line to
  Suggested First Action. Makes strand-growth visible every session. Effort: S.
- **C4: strand merge-back schedule.** One task per strand, smallest first: t2353(22) →
  rca-strand(37) → t2417(58) → t2416(139); plus dispositions for the 1-commit strands
  (audit-remediation-t2416, learning/precompact-cleanup, origin/fix/T-002/T-003,
  origin/main). Not policy — scheduled work enabled by it.
- **C5 (rejected): branch-freeze / direct-to-master only.** Conflicts with worktree
  isolation needs (arc-011 parallel dispatch) and the deliberate branch-per-arc
  experiments; too blunt.

## Recommendation

**GO** — ship C1+C2+C3 as three build slices; C4 filed as follow-up tasks once C1/C2
exist (the guards make the merge-backs safe to sequence). C5 rejected.

## Dialogue Log

- **Operator:** critically review branching/worktree process; impression of pollution.
- **Agent:** measured 36 local / 17 remote branches, 3 worktrees; found the 29:7
  merged-debris:live split; identified divergence as the deeper problem (all live
  strands 215-248 behind master); root-caused to missing lifecycle + observability.
- **Operator:** "proceed as seen fit … follow framework governance" → mechanical
  cleanup executed immediately under T-100138 (provably information-free); policy
  half filed as this inception per inception discipline (structural change needs a
  go/no-go, not autonomous action).
- **Course corrections:** none yet; decision pending human review.
