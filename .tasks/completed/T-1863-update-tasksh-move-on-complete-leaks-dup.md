---
id: T-1863
name: "update-task.sh move-on-complete leaks duplicate active+completed orphan — add
  post-move check + pre-commit gate"
description: >
  update-task.sh move-on-complete leaks duplicate active+completed orphan — add post-move
  check + pre-commit gate

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [agents/git/lib/dup-task-scan.sh, agents/git/lib/hooks.sh, 
      agents/task-create/update-task.sh, 
      tests/unit/update_task_orphan_guard.bats]
related_tasks: [T-1859, T-1860, T-1523]
created: 2026-05-15T19:36:31Z
last_update: '2026-06-11T22:24:01Z'
date_finished: 2026-05-15T19:43:26Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:01Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 0
      D4: 0
      F-RECALL: 1
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=0
      (no-signal); D4=0 (no-signal); F-RECALL=1 (body:episodic-only); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1863: update-task.sh move-on-complete leaks duplicate active+completed orphan — add post-move check + pre-commit gate

## Context

S-2026-0515-2115 push was rejected by pre-push audit: `[FAIL] Duplicate task
IDs detected (G-052)` for `T-1859`. Both `.tasks/active/T-1859-*.md` (status:
started-work) and `.tasks/completed/T-1859-*.md` (status: work-completed)
were tracked in git. The completed-side file was added in commit `5ebb20a0`
(during T-1860 build), which staged `A completed/T-1859` but not `D active/T-1859`,
so the active-side file persisted unstaged-but-tracked.

`update-task.sh:1250-1257` performs `git mv` when tracked, falling back to plain
`mv`. T-1523 was meant to make rename atomic. Failure mode here: the move ran,
but the commit that captured the new completed/ file did NOT stage the rename
(only the destination addition). The orphan was caught 3 days later at the
S-2026-0515-2115 push-time audit — by which point both sides had been touched
by an unrelated commit.

**Resolution (already shipped):** commit b62c76b1 `git rm`'d the active orphan.

**This task:** add a structural pre-flight gate so this class can't recur.

## Acceptance Criteria

### Agent
- [x] Post-move sanity check in `update-task.sh`: after the `git mv`/`mv`
      block (~line 1250-1257) verify the source path no longer exists. If it
      does, refuse with a clear error pointing at G-052.
      *(Done — `agents/task-create/update-task.sh:856-880,1267-1285` — guards
      both T-193 partial-complete re-run and main completion paths.)*
- [x] Add a pre-commit hook (or extend the commit-msg/`check-tier0.sh` chain)
      that runs the G-052 duplicate-ID check before commit, not after audit.
      Goal: catch orphan-leakage at the commit boundary, not 3 days later.
      *(Done — new `agents/git/lib/dup-task-scan.sh` wired into
      `agents/git/lib/hooks.sh:286+`. Verified live by triggering a synthetic
      T-9999 duplicate on this repo's pre-commit — gate blocked the commit
      with the expected G-052 message.)*
- [x] Regression test in `tests/unit/`: pin both the post-move check (refuses
      when source still exists after move) and the pre-commit check (blocks
      a commit that would land duplicate IDs).
      *(Done — `tests/unit/update_task_orphan_guard.bats`, 5 tests all green:
      scan-worktree clean, scan-worktree dup, scan-staged respects index,
      scan-staged dup, unknown-mode handling.)*

## Verification

# L-387: capture-then-grep (pipefail + grep -q produces SIGPIPE exit 141).
out=$(bats tests/unit/update_task_orphan_guard.bats 2>&1); echo "$out" | grep -qE "ok [0-9]+ T-1863"
out=$(bin/fw audit --section structure 2>&1); echo "$out" | grep -q "No duplicate task IDs"

## RCA

**Symptom:** `fw audit` reported `[FAIL] Duplicate task IDs detected (G-052):
T-1859`. Both `.tasks/active/T-1859-*.md` and `.tasks/completed/T-1859-*.md`
were tracked in git. Pre-push audit blocked the S-2026-0515-2115 handover push.

**Root cause:** `update-task.sh` line 1250-1257 (`git mv` with fallback to plain
`mv`) succeeded at the filesystem level, but the subsequent commit that landed
the completed-side file (`5ebb20a0`) staged only `A completed/T-1859` — the
rename was decomposed into add-only, leaving the active-side delete unstaged.
Three days later an unrelated commit touched the active-side file (now still
present but untracked-in-effect for that path), making both versions live in
the index.

**Why structurally allowed:**
1. `update-task.sh` does not verify post-move state. If `git mv` partially
   succeeds (filesystem moves, index rename detection fails), or if the agent's
   subsequent `git add` doesn't pick up the deleted source, the orphan is born
   silently.
2. The G-052 check exists in `fw audit` (structure section) but only fires when
   an audit runs — typically pre-push, post-completion, or daily cron. There is
   no commit-time check. So an orphan can live in the index across many commits
   before being surfaced.

**Prevention:**
1. **Post-move sanity check** in `update-task.sh`: after the `git mv`/`mv`
   block, verify the source path is gone. If not, refuse with G-052 reference.
2. **Pre-commit hook**: cheap O(n) scan of `git diff --cached --name-only` to
   check if any T-NNNN appears on both sides of the move boundary. Catches
   leakage at the commit boundary, not at the next audit.
3. **Regression tests** pinning both gates so they can't silently regress.

## Evolution

<!-- REQUIRED for arc-tagged build tasks (tags include arc:*). Captures how
     understanding evolved during build — what was learned that wasn't known at
     filing, what in the original plan no longer fits, what triggered pivots
     or new sub-tasks. Mandatory at slice boundaries (when applicable) and
     before --status work-completed.

     Origin: T-1717 grill Q4 — "the understanding of what we need and want
     evolves with the process of materialisation." Structural counter to §ACD:
     spec-vs-build divergence is logged as soon as it happens, not lost as
     folklore.

     Format (one entry per slice boundary or significant insight):
       ### YYYY-MM-DD — [topic]
       - **What changed:** [what we learned that we didn't know at filing]
       - **Plan impact:** [what in the plan no longer fits]
       - **Triggered:** [new sub-task / pivot / scope cut, with task ID if filed]

     The completion gate (T-1718) blocks --status work-completed when this
     section exists but is empty/template-only. Use --skip-evolution to bypass
     (logged Tier-2). Non-arc tasks may leave this empty.
-->

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

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-15T19:36:31Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1863-update-tasksh-move-on-complete-leaks-dup.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-8ba2df97
- **Timestamp:** 2026-06-02T15:00:07Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-15T19:43:26Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
