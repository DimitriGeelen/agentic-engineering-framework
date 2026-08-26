---
id: T-3185
name: "Master becomes a release train: rename the session branch to bleeding-edge
  and land it on release only"
description: >
  Rename t2539-staging to bleeding-edge, make it the sanctioned development branch,
  and restrict master to receiving FF landings at release. Supersedes T-100196 session-on-master;
  dissolves the T-100201 PROTECT_MASTER conflict.

status: work-completed
workflow_type: refactor
owner: human
horizon: now
tags: []
components: []
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
# demo_target: true               # T-2286: optional — marks task as reserved for an orchestrated demo
#                                 # worker (e.g. arc-010 HM-A dispatches via mcp__fw__work_on). When set,
#                                 # `fw work-on T-XXX` refuses unless --i-am-demo-orchestrator (CLI) or
#                                 # FW_I_AM_DEMO_ORCHESTRATOR=1 (env) is passed. Prevents the parent
#                                 # session from consuming the captured→started-work transition the demo
#                                 # worker expects to drive. Origin OBS-057.
created: 2026-08-26T21:34:30Z
last_update: 2026-08-26T21:46:46Z
date_finished: 2026-08-26T21:46:46Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── BVP scoring fields (T-1918, arc-006). See docs/reports/T-1915-bvp-inception.md for semantics. ──
# bvp_scores:                     # confirmed per-driver scores 0-5, set by `fw bvp confirm` (T-1924).
#                                 # Sovereignty boundary — only set after human or agent confirmation.
#                                 # Shape: {D1: <int 0-5>, D2: <int 0-5>, D3: <int 0-5>, D4: <int 0-5>, [<free-driver-id>: <int>]...}
# bvp_scores_proposed:            # estimator-proposed scores (T-1922 worker). Persists when ≥2 delta
#                                 # from bvp_scores: on any driver (M3 v2-delta). Shape: list of timestamped entries.
# cost_estimate:                  # F8 composite: 0.6×blast_radius + 0.3×tier + 0.1×effort.
#                                 # Q2 fallback: T-shirt S/M/L/XL mapped to 2/4/6/8 when blast_radius is not yet computable.
cost_estimate_proposed:
  - ts: '2026-08-26T21:45:04Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 3
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=3 
      (workflow:refactor); effort=8 (lines=142,acs=10)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-26T21:45:07Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 1
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=1 (body:episodic-only); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3185: Master becomes a release train: rename the session branch to bleeding-edge and land it on release only

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] Local branch renamed: `git branch --show-current` returns `bleeding-edge`, and `t2539-staging` no longer exists locally
- [x] `origin/bleeding-edge` exists and points at the same commit as local HEAD
- [x] CLAUDE.md §Trunk-Based Session Flow rewritten: `bleeding-edge` is the sanctioned development branch; `master` receives fast-forward landings at RELEASE only, never per-handover
- [x] The T-100196 "session runs on master" mechanism is explicitly superseded in writing, with its divergence rationale carried forward (bleeding-edge cannot fall behind master while it is master's only writer)
- [x] T-100201 recorded as DISSOLVED — the PROTECT_MASTER conflict needs no resolving, because master-as-merge-only IS the release-train policy
- [x] §Worktree Policy states that an explicitly-instructed worktree lands on `bleeding-edge`, never on `master` — a worktree landing on master would inject unreleased work into the consumer install surface
- [x] Follow-ups filed for tooling that cannot change in this task, each naming the reason: T-3186 (`fw sync` branch-nag + `fw integrate` default target) and T-3187 (doctor branch-identity guard, L-497) — both blocked tonight because T-3127 holds `bin/fw` uncommitted
- [x] This task's commit does not touch `bin/fw` (T-3127 holds it dirty; same trap as T-3182)

### Human
- [ ] [REVIEW] GitHub mirror carries `bleeding-edge`
  **Steps:**
  1. Open the OneDev project settings for `agentic-engineering-framework` → PushRepository / mirror config
  2. Confirm the mirror pushes all branches, or add `bleeding-edge` explicitly
  3. Verify: `cd /opt/999-Agentic-Engineering-Framework && git ls-remote --heads github | grep bleeding-edge`
  **Expected:** `refs/heads/bleeding-edge` is listed on the GitHub remote
  **If not:** the public mirror carries only `master`, so development is invisible outside OneDev. Adjust the PushRepository branch filter.
  *(Agent cannot reach OneDev's admin surface — operator-side config.)*

- [ ] [REVIEW] Confirm deletion of the old `origin/t2539-staging` ref
  **Steps:**
  1. Evidence first: `cd /opt/999-Agentic-Engineering-Framework && git rev-list --count origin/master..origin/t2539-staging` — expect `0`
  2. Only if that returns 0: `cd /opt/999-Agentic-Engineering-Framework && git push origin --delete t2539-staging`
  **Expected:** count is 0, so the deleted ref's content is fully contained in master
  **If not:** count > 0 means the old branch holds commits master does not — do NOT delete; land them first.

## Verification

test "$(git branch --show-current)" = "bleeding-edge"
! git show-ref --verify --quiet refs/heads/t2539-staging
git show-ref --verify --quiet refs/remotes/origin/bleeding-edge
test "$(git rev-parse HEAD)" = "$(git rev-parse origin/bleeding-edge)"
grep -q "bleeding-edge" CLAUDE.md
grep -q "T-100201" CLAUDE.md
git show --stat --format= HEAD > /tmp/.t3185-stat 2>&1 && ! grep -qE "^ +bin/fw " /tmp/.t3185-stat

## RCA

<!-- REQUIRED for bug-class tasks (workflow_type=build with bug-tag, OR title matches
     fix/bug/rca/broken/crash/error/regression/fail/hotfix).
     Non-bug-class tasks may leave this section empty or remove it.

     For bug-class, fill in:
       **Symptom:** what was observed (the user-facing manifestation).
       **Root cause:** the specific structural/logical gap — not "the code was wrong".
       **Why structurally allowed:** what in the framework/code/tooling let this go undetected.
       **Prevention:** what catches the next instance (test/lint/gate/doc/learning) — distinct from the fix itself.

     The completion gate (T-1550, G-019) blocks --status work-completed when
     bug-class AND this section is empty/template-only. Use --skip-rca to bypass (logged).
-->

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

## Recommendation

**Recommendation:** GO

**Rationale:**

The policy half is landed and verified; what remains is two operator actions I
cannot perform. The rename carried zero risk because it happened at the one moment
`bleeding-edge` was byte-identical to `master` (0 ahead / 0 behind, immediately
after tonight's fast-forward), so no history question arises. The model was checked
against the code before being written down, not assumed: consumers do install from
the GitHub mirror (`lib/consumer-recover.sh:19` calls it the *canonical public
mirror*), `fw release tag-and-release` exists to be the landing gate, and
`fw integrate run [target]` already accepts an explicit target, so the worktree
landing rule is enforceable today without touching `bin/fw`.

The reason this is GO and not DEFER: nothing is waiting on evidence. The two open
items are a OneDev admin-console setting and a remote-ref deletion — both are yours
to perform, neither changes the recommendation.

One honest limitation: the model is currently enforced by **prose only**. The two
rails that would make it structural (T-3186, T-3187) are blocked because T-3127
holds `bin/fw` uncommitted, and I deliberately kept this commit off that file
rather than ship another session's unfinished work under my change. Until T-3187
lands, a future session sitting on the wrong branch will look exactly like one
sitting on the right branch — the same blind spot that let this run 41 days. That
argues for prioritising T-3187, not for withholding the policy.

**Evidence:**

- Rename: `t2539-staging` → `bleeding-edge`, local gone, `origin/bleeding-edge` live and tracked (7/7 P-011 verification lines pass)
- Release train demonstrably running: `origin/master` = `c0790d322`, `origin/bleeding-edge` = `6a35eea9d`, master behind by 1 — the lag is the product
- Provenance measured, not guessed: branch created `2026-07-16 07:28:39`; T-2539 `date_finished: 2026-07-16T05:28:58Z` (+02:00) — 19 seconds apart; 1,943 reflog entries since
- Blind spot measured: `t2539-staging` was 0 behind master, and `fw doctor`'s `diverged-fork` guard fires only when a branch is BOTH ahead and behind — so it never had a reason to speak (filed T-3187)
- No framework code creates session branches: grep for `checkout -b` / `branch -c` / `switch -c` across `bin/fw`, `bin/claude-fw`, `lib/`, `agents/` returns nothing — this was a one-off human `git checkout -b`, never automated
- `PROTECT_MASTER: 1` confirmed live in `.framework.yaml:15` with `agents/git/lib/master-guard.sh` present — left armed and unscoped, per the dissolution
- T-100201 recorded as dissolved with `Superseded-by: T-3185`
- Commit verified clean of `bin/fw` (AC8, mechanical check in `## Verification`)

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

### 2026-08-26T21:34:30Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3185-master-becomes-a-release-train-rename-th.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-03a6fdb0
- **Timestamp:** 2026-08-26T21:46:46Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-26T21:46:46Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
