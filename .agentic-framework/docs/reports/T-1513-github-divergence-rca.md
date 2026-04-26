# T-1513 — github/master vs local+onedev divergence RCA

**Status:** investigation complete, awaiting human go/no-go on remediation
**Date:** 2026-04-26
**Trigger:** session-end push attempt; `fw handover` reported "github push rejected (non-fast-forward)"

## TL;DR

Two parallel framework dev sessions are running today on different machines, both pushing to `master` of their respective remotes:
- **Session A (this one):** machine `dev-mint`, remotes `onedev` + (broken) `github`. Today's commits: T-1493 → T-1499 mediation, T-1494 fix, T-1493 FD-leak fix, T-1495/T-1496/T-1498/T-1512 closures.
- **Session B (parallel):** unknown machine, pushes to `github`. Today's commits: T-1486 → T-1492, T-1487-T-1492, T-1346, T-1500-T-1511 (visible only as github commits we haven't pulled).

Both sides have legitimate, orthogonal framework improvements. **Force-pushing either side would destroy real work.** The right fix is a merge with manual conflict resolution on ~7 files of substantive overlap, plus mechanical resolution on auto-generated state.

## Numbers

| Metric | Value |
|---|---|
| github/master commits not on local | 2,490 |
| local/master commits not on github | 6 (this session) |
| Common ancestor | `a4100c214 T-348` (2026-03-08) |
| Files actually content-different (`--no-renames`) | **126** |
| Substantive code files (lib/) different | 5 |
| Task body files different | 26 |
| Auto-generated state files different | ~95 (.context, .fabric, .tasks/episodic) |

The 5,956 figure git first showed was rename-detection inflation. The real semantic divergence is 126 files.

## What's on github but not local (substantive)

### lib/inception.sh — T-974 / T-1497 hardening + T-1503 preflight AC check
- Replaces inline `grep -v '^<!--'` Recommendation gate with `audit_inception_recommendation` helper that handles multi-line HTML comments correctly. The old check was fooled by the Recommendation template's commented placeholder.
- Adds preflight Agent AC tick + count BEFORE writing the Decision block. Prevents "decision recorded but status stuck at started-work" bug where the task body was mutated with Decision/Updates entries before the P-010 gate ran and rejected.
- Both fixes have task IDs in github commits: T-1497, T-1503.

### lib/task-audit.sh — +51 lines
Likely the parallel of our T-1510 widened regex but with different specific changes. Needs file-level review.

### lib/review.sh — +6 -2
Probably T-1492 (review.sh emit_review pipefail fix) — that task ID exists on both sides identically, so the lib change should be the same. Needs verification.

### lib/pickup.sh, lib/keylock.sh — divergent on both sides
- **github:** unknown changes (need to inspect)
- **local:** T-1494 `--session` arg + T-1493 `keylock_subshell_close_cmd` helper

These are the highest-risk merges — both sides made independent changes to the same files in the same session.

### Task closures only on github
Visible in github log, not yet pulled:
- T-1486 / T-1487: Watchtower /reviewer/audit page
- T-1488: CTL-013 RCA + Heisenbug-defer learning + L-281
- T-1489: Fabric enrich (17 cards 29 edges)
- T-1490: D13 audit check (limbo state) — this was OBS-025, also tracked locally as T-1511 D15 — possible overlap
- T-1491: do_inception_decide silent failure RCA + L-282
- T-1492: review.sh pipefail fix (already exists locally identically)
- T-1500-T-1511: tier-0 idempotency, hook-enable RBAC etc.

## What's on local but not github

This session's six commits:
- T-1499 reopen + mediate via TermLink (relay-back to 003-NTB-ATC-Plugin)
- T-1494 fix fw pickup send --remote signature mismatch
- T-1493 close keylock FDs in verification subshells
- T-1496 close (already fixed in T-1262)
- T-1495/T-1498 close (already addressed)
- T-1512 NO-GO recommendation (phantom self-loop)
- T-012 housekeeping

## Why this happened

Hypothesis (cannot verify without machine inventory):
1. The user works on multiple machines (e.g., `dev-mint` Linux + a Mac dev box).
2. At some point — likely on or near 2026-03-08 — a force-push from one machine to github created a parallel ancestry. Local stayed in sync with onedev; github became the parallel timeline.
3. Both sides have continued to receive new commits since, with the same author email but on different ancestries.
4. The handover hook says `Skipping github (mirrored from origin via PushRepository)`, suggesting github was supposed to auto-mirror from onedev — but it doesn't, or the mirror direction is wrong, or it stopped working.
5. Today (2026-04-26) the parallel session on the github-side was active 09:27→13:06; this session was active 11:13→19:50. Overlap window 11:13→13:06 had both sides pushing to their respective remotes simultaneously.

## Options

### Option 1 — Merge, resolve manually, push to both (recommended)
- `git fetch github` then `git merge github/master` (do NOT rebase — would be 2,490 commits to replay)
- Resolve ~7 substantive conflicts (5 lib/ + a few task body files where both sides wrote)
- Auto-generated state: take ours for `.context/working/.session-metrics.yaml`, episodic memory; take theirs where they have additions
- Commit the merge; push to both onedev and github
- **Cost:** 30-60 min focused conflict resolution, careful manual review of lib/ merges
- **Benefit:** zero work lost; histories converge

### Option 2 — Cherry-pick critical github fixes onto local, force-push (DESTRUCTIVE)
- Inspect github commits, cherry-pick only the lib/ improvements (T-1497, T-1503) and any other substantive fixes
- Force-push local to github
- **Cost:** loses all parallel session B's task closures, learnings, episodic memory, fabric edits
- **Risk:** Tier 0 destructive operation; not recommended

### Option 3 — Accept the split, mark github as a divergent branch
- Don't try to merge. Treat github as a separate branch (`github-master`).
- Both timelines continue to advance independently.
- **Cost:** indefinite double-bookkeeping, future commits keep diverging, nothing reusable from the other side
- **Risk:** silent data loss as parallel work accumulates

### Option 4 — Rebase local onto github, push to both
- `git rebase github/master` — replay our 6 local commits on top of github's 2,490
- Resolve same conflicts as Option 1 but with cleaner linear history
- Force-push to onedev (since onedev had the old ancestry)
- **Cost:** rewrites local SHAs (any external references to old SHAs break)
- **Benefit:** clean linear master; both remotes converge

## Recommendation

**Option 1 (merge) — clean, no force pushes, no work lost.**

**Rationale:**
- All four constitutional directives prefer merge over rebase here:
  - Antifragility: merge preserves both timelines as evidence; rebase erases parallel session B's commit ancestry
  - Reliability: no force push, no rewriting; the merge commit is auditable
  - Usability: ~7 manual resolutions vs. 2,490 cherry-picks
  - Portability: standard git workflow; no remote-specific magic
- Substantive conflicts are bounded (5 lib/ files, ~5 task bodies) and the changes are orthogonal in 4 of 5 lib/ files — keepable side-by-side.
- The only real intellectual work is reconciling the two parallel sessions' edits to `lib/pickup.sh` and `lib/keylock.sh` where both made changes today.

**Before merging — open question for the human:**
1. Is github's parallel session SUPPOSED to be canonical? (i.e., is the dev-mint side the second-class clone?) If yes, we should rebase local onto github, not merge.
2. Where is session B running? Knowing the machine helps prevent recurrence (need to fix the mirror).
3. Was the original force-push intentional, or an accident from March 8?

## Next steps (pending human decision)

If GO on Option 1:
1. `git fetch github`
2. `git merge github/master --no-commit --no-ff` to surface conflicts
3. Manual resolve in priority order: lib/ first (substantive code), then task bodies, then state
4. Commit with detailed message
5. Push to onedev and github
6. Investigate the mirror failure as a follow-up gap

If GO on Option 4 (rebase):
1. `git rebase github/master` and resolve as we go
2. Force-push to onedev (Tier 0)
3. Push to github (fast-forward after rebase)

If GO on Option 3 (accept split):
1. Create `github-master` branch tracking github/master
2. Document the split in a learning + concern register entry
3. Plan future strategy

## Dialogue log

- **2026-04-26 17:50** — agent initial misdiagnosis: framed as "8 commit divergence, just rebase"
- **2026-04-26 17:52** — agent corrected after user requested investigation: 2,490 commit divergence, two parallel timelines
- **2026-04-26 17:55** — agent investigated `.tasks/` first per user direction, found T-1492 byte-identical on both sides → realized most divergence is SHA-only, not content
- **2026-04-26 17:58** — final picture: 126 actual content diffs, 5 substantive lib/ files with real conflicts
- **Pending:** user decision on Option 1/2/3/4
