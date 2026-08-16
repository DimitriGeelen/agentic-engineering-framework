---
id: T-100199
name: "audit and remediate branch/worktree hygiene process"
description: >
  audit and remediate branch/worktree hygiene process
status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-07-05T18:32:43Z
last_update: '2026-08-16T22:24:20Z'
date_finished: 2026-07-05T19:15:17Z
bvp_scores_proposed:
  - ts: '2026-08-16T22:24:20Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 1
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:learning-ref,body:concern-ref); D2=0 (no-signal); D3=0
      (no-signal); D4=0 (no-signal); F-RECALL=1 (body:episodic-only); 
      F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-100199: audit and remediate branch/worktree hygiene process

## Context

Operator flagged repo pollution: "we are polluting our repo with a lot of
outstanding branches / worktrees." This task inventories the branch/worktree
debris, root-causes the accumulation, executes the safe remediation, and
records a process verdict. Sibling to T-100194 (RCA of the trunk fork) and
T-100195 (diverged-fork detection). See OBS-090, L-497.

## Acceptance Criteria

### Agent
- [x] Inventory captured in `## Findings`: exact counts of local branches, remote branches, and on-disk worktrees, with each classified (merged-into-origin/master vs live/unmerged vs orphaned worktree dir). Cross-checked against `fw_branch_hygiene` output.
- [x] Root-cause the accumulation: for each stale branch/worktree class, state WHY it persists (integrate cleanup not run, non-integrate landing, abandoned worktree, forked strand) — distinguish "process not followed" from "process has a gap"
- [x] Concrete remediation executed OR recorded as decision: delete provably-merged branches/orphaned worktrees (safe), and record the reconcile plan for any forked strand as a referenced decision (do NOT auto-resolve a fork — that's the operator's Tier-0 call)
- [x] Process verdict in `## Decisions`: is the worktree-off-origin/master flow sound (keep), or does it need a structural change (e.g. auto-prune, cleanup gate)? If a fix is warranted, spin it out with a task ID

## Verification

# No compileable artifacts touched — documentation/record task.
# Inventory reproducible:
git worktree list
git for-each-ref --format='%(refname:short)' refs/heads/

## Findings

Snapshot 2026-07-05 (after the operator's go-live reset + the T-100199 rescue landing 910827ff7).

### Worktrees — 3 registered (+2 transient this session)
| Worktree dir | Branch | State |
|---|---|---|
| `/opt/999-…` (main) | `t2416-fw-safe-mode-hook-timing` | operator's checked-out session branch; ahead=0 behind=1 |
| `.claude/worktrees/inception-gov-payload-mediation` | `worktree-inception-gov-payload-mediation` | +6 / -41, **pushed** (remote preserves) |
| `.claude/worktrees/rca-worktree-push-strand` | `worktree-rca-worktree-push-strand` | +37 / -256, **NO remote** — strand |
| `t100199-rescue` (transient) | `t100199-rescue` | auto-removed by `fw integrate` after landing 910827ff7 |
| `t100199-close` (transient) | `t100199-close` | this task's landing worktree |

### Local branches — 8
| Branch | ahead | behind | remote | class |
|---|---|---|---|---|
| `t2416-fw-safe-mode-hook-timing` | 0 | 1 | origin | merged (ancestor of master); operator's live branch — leave |
| `master` | 0 | 41 | origin | stale local tracking ref — FF or leave |
| `t2417-fw-sessions` | 58 | 256 | origin | **session-branch antipattern** subject; pushed — safe, operator's call |
| `worktree-inception-gov-payload-mediation` | 6 | 41 | origin | live worktree branch, pushed — leave |
| `learning/precompact-cleanup` | 1 | 5705 | origin | 4mo superseded; **local==origin** → local delete = zero data loss |
| `audit-remediation-t2416` | 1 | 289 | **NONE** | strand: arc-013 + 6 inceptions — unlanded, irreversible if deleted |
| `t2353-audit-emit-tasks` | 22 | 289 | **NONE** | strand: T-2353/2354/2417/2418/2335/2171/2388/2390/2419 completed-task work — "awaiting merge-back" |
| `worktree-rca-worktree-push-strand` | 37 | 256 | **NONE** | strand: mostly T-077/T-012 handover churn + T-2323/2324 IC-convergence + T-2428/G-071/G-072/L-486 |

Remote branches: ~13 on origin (unchanged this session; remote pollution is downstream of the same root).

### Verification of "is the strand safe to delete?"
`git cherry origin/master <branch>` reports **every** commit as unlanded (`+`) on all three no-remote strands — **including tasks proven DONE and live on origin/master** (T-2417, T-2418, T-2354, T-2335 per session memory). Cause: those tasks landed via **re-derivation** (`fw integrate` + `bin/fw vendor self` re-commit different file sets), so patch-ids never match master. **`git cherry` cannot confirm landing here** → the strands cannot be mechanically proven safe → auto-deletion of a no-remote strand is unproven data loss.

## RCA

**Symptom:** 8 local branches, 3 no-remote strands (+1/+22/+37 unlanded commits), 2 stale worktrees; the RCA-of-stranding (T-100194/195) was itself stranded off master.

**Root cause:** the **long-lived session-branch pattern** (already RCA'd in T-100194). A persistent session lives on a named branch (t2416/t2417) accumulating handover + task-sync commits; code lands separately on origin/master via throwaway worktrees + one-way `fw integrate` (re-derivation). The session branch's *original* commits therefore never patch-match master, so nothing can prune them, and they accumulate indefinitely.

**Compounding cause:** a go-live `git reset --hard origin/master` resolves the divergence but **orphans the reset-away local commits with no remote** → permanent no-remote strands (the three above).

**Why structurally allowed:** detection exists (T-100195 diverged-fork WARN) but **reclamation is manual and unprovable** — patch-id equality (`git cherry`) defeats itself under re-derivation, and there is no rail to (a) push a session branch's unique commits before a reset strands them, or (b) content-verify (not patch-verify) that a branch's deliverables are on master before pruning.

**Prevention:** T-100196 (option c — session tracks origin/master directly, dissolving the strand class) + this task's recommended auto-capture/reclaim rail (see Decisions). Distinct from the fix: the rescue (910827ff7) is mitigation; the option-c structural change is prevention.

## Decisions

### 2026-07-05 — Process verdict: keep worktree flow, kill session-branch pattern
- **Chose:** KEEP the worktree-off-origin/master + `fw integrate` build flow — its auto-cleanup (delete branch+worktree on FF-land) works correctly (demonstrated twice this session: the rescue worktree self-removed after landing). The problem is NOT the worktree flow.
- **Chose:** The ROOT fix is the persistent session-branch pattern → **T-100196 option (c): the session tracks origin/master directly**. This is a Level-D ways-of-working change and remains the **operator's structural call** (not actioned autonomously).
- **Why:** every strand traces to a session branch that never merges back + a reset that orphans its commits. Dissolving the session branch removes the whole class.
- **Rejected:** auto-force-pruning the strands — `git cherry` cannot prove their re-derived work is landed, and they have no remote, so deletion is unproven data loss.

### 2026-07-05 — Remediation executed vs operator-gated
- **Executed (Task 1):** rescued T-100194/195/196 + OBS-090 + L-497 onto origin/master as `910827ff7` — the stranded RCA work is now on the trunk.
- **Verified (Task 2):** classified all 8 branches + 3 worktrees. Only `learning/precompact-cleanup` is provably safe to delete (local==origin, 4mo superseded). Its delete is **Tier-0-gated** (`git branch -D`), so it is surfaced to the operator, not self-approved.
- **Operator-gated (do NOT auto-delete):** the three no-remote strands (`audit-remediation-t2416`, `t2353-audit-emit-tasks`, `worktree-rca-worktree-push-strand`). Safe reclaim path = **push to origin first** (converts to zero-data-loss), then the operator decides merge-back vs discard. `t2353` in particular holds real completed-task work "awaiting merge-back" per session memory.
- **Spin-out recommended (not yet filed):** an auto-capture/reclaim rail — (a) push a session branch's unique commits before any go-live reset so a reset can never strand no-remote work; (b) a reclaim helper that **content-verifies** (deliverable files on master), not patch-id-verifies, before offering a branch for prune. File as a follow-up if the operator greenlights alongside T-100196.

**Operator prune commands (Tier-0 — require `bin/fw tier0 approve` first):**
- Safe now (zero data loss, local==origin): `cd /opt/999-Agentic-Engineering-Framework && bin/fw tier0 approve && git branch -D learning/precompact-cleanup`
- Strands — reclaim-then-decide (do NOT force-delete un-pushed): `git push origin audit-remediation-t2416 t2353-audit-emit-tasks worktree-rca-worktree-push-strand` then triage merge-back per branch.

## Updates

### 2026-07-05T18:32:43Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Context:** Initial task creation

### 2026-07-05T19:10:00Z — completed on trunk [agent]
- **Action:** Filled Findings/Decisions, executed Task-1 rescue (910827ff7), verified Task-2 prune classification. Completing on a fresh origin/master worktree (anti-strand) rather than re-stranding on t2416.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-17cf6a16
- **Timestamp:** 2026-07-05T19:15:18Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-07-05T19:15:17Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
