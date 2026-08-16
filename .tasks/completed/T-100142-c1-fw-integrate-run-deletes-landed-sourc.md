---
id: T-100142
name: "C1: fw integrate run deletes landed source branch by default (keep-branch opt-out)"
description: >
  Post-GO slice of T-100139. fw integrate run deletes the landed source branch after
  successful merge-back; --keep-branch opts out.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [bin/fw, lib/integrate.py]
related_tasks: [T-100139]
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
created: 2026-07-04T11:49:31Z
last_update: '2026-08-16T22:24:19Z'
date_finished: 2026-07-06T12:47:46Z
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
  - ts: '2026-07-04T12:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-04T12:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F-AUTONOMY: 0
      audit_severity: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal); F-AUTONOMY=0 (no-signal); 
      audit_severity=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:19Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=0 (no-signal); F-RECALL=0 (no-signal); 
      F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-100142: C1: fw integrate run deletes landed source branch by default (keep-branch opt-out)

## Context

C1 slice of T-100139 (branch/worktree lifecycle inception, GO). Landed source
branches accumulate because nothing deletes them after a successful merge-back —
`fw integrate run` completes the merge and leaves the branch behind. This slice
makes deletion-after-successful-landing the default, with `--keep-branch` opt-out.

## Acceptance Criteria

### Agent
- [x] After a successful `fw integrate run` landing, the source branch is deleted by default (and its worktree removed first when one exists, since git refuses to delete a checked-out branch) — `_cleanup_branch` in lib/integrate.py, called as the last step of `cmd_run`
- [x] `--keep-branch` opts out: branch (and worktree) survive, output says kept
- [x] Deletion only happens on a fully successful landing — pushed landings only (`not pushed` → kept), and failed/aborted integrations return before cleanup is reached
- [x] Output names what was deleted (branch, worktree path, remote ref) under a `Branch cleanup:` block; containment in origin/<target> is re-checked with `merge-base --is-ancestor` before any deletion (the -d semantic against the landed state — unmerged work is never force-deleted)
- [x] Regression tests pin all four behaviours + dry-run plan line: `tests/unit/t100142_integrate_run_branch_cleanup.bats` (6 tests green; existing t2471/t2474 suites green, zone-2 test updated to --keep-branch)

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.

     ── Prefix routing (T-1811, T-1878): default to [REVIEWER] if Expected is grep-able ──
     If your Expected clause is grep-able / file-exists / structural (a deterministic
     shell check), prefer [REVIEWER] — that AC should be an Agent AC with the reviewer
     command in `## Verification` instead of a Human AC here. Only keep [REVIEW] if
     verification genuinely needs human taste (tone, feel, layout rhythm).
     See CLAUDE.md §AC Classification Guidance for the conversion rule.

     [REVIEW] example (genuine human judgment):
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error

     [REVIEWER] example (static-scan-verifiable — convert to Agent AC + Verification):
       - [ ] [REVIEWER] Block message names both bypass mechanisms
         **Steps:**
         1. Run `bin/fw reviewer T-XXX`
         **Expected:** Verdict: PASS; no findings on `block-message-completeness`
         **If not:** Inspect hook block-message string and add missing mechanism
       Conversion: this AC should be moved to ### Agent and
       `bin/fw reviewer T-XXX 2>&1 | grep -q "Overall:.*PASS"` added to ## Verification.
-->

## Verification

# Feature landed on origin/master (runs from any checkout, incl. MAIN on an old branch)
# L-387: write-to-file, not `git show | grep -q` — the pipe SIGPIPEs (exit 141) on large
# blobs (bin/fw) under the gate's pipefail when grep -q matches and closes stdin early.
git show origin/master:lib/integrate.py > /tmp/.t100142-integrate.py && grep -q "_cleanup_branch" /tmp/.t100142-integrate.py
grep -q "keep_branch" /tmp/.t100142-integrate.py
git show origin/master:tests/unit/t100142_integrate_run_branch_cleanup.bats > /tmp/.t100142-test.bats && grep -q "never force-deleted" /tmp/.t100142-test.bats
git show origin/master:bin/fw > /tmp/.t100142-fw && grep -q -- "--keep-branch" /tmp/.t100142-fw

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

## Decisions

### 2026-07-04 — deletion trigger: pushed landings only
- **Chose:** delete only when `--push` succeeded AND `merge-base --is-ancestor <branch> origin/<target>` confirms containment; without `--push` the branch is always kept.
- **Why:** "verified landing" (T-100139 artifact wording) means the work is provably reachable from the canonical target. A local-only merge leaves the branch as the sole holder of the merge commit — deleting it would lose work.
- **Rejected:** deleting after zone-2 local FF (local master can still diverge from origin); a `--delete-branch` opt-in (inverts the GO decision — deletion must be the default to close the debris tap).

### 2026-07-04 — branch -D after explicit containment check, not -d
- **Chose:** re-check containment ourselves, then `git -C <MAIN> branch -D`.
- **Why:** `-d` judges merged-ness against the *deleting checkout's* HEAD; MAIN is routinely on a session branch off-master, so `-d` would refuse valid deletions. The is-ancestor check against origin/<target> is the same safety, aimed at the right ref.
- **Rejected:** plain `-d` (false refusals from MAIN), plain `-D` without the check (could destroy unmerged work on a push race).

### 2026-07-04 — self-removal ordering
- **Chose:** cleanup is the last step of `cmd_run`; worktree removed before branch deletion; all post-removal git calls run with `cwd=` pinned to MAIN.
- **Why:** git refuses to delete a checked-out branch, and after our own worktree dies any subprocess inheriting the dead cwd fails ("Unable to read current working directory").
- **Rejected:** deleting from within the worktree (impossible); leaving the worktree behind (it IS the debris the GO decision targets).

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

### 2026-07-04T11:49:31Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-100142-c1-fw-integrate-run-deletes-landed-sourc.md
- **Context:** Initial task creation

### 2026-07-04T12:39:39Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f9153fe2
- **Timestamp:** 2026-07-21T06:06:13Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-07-06T12:47:46Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
