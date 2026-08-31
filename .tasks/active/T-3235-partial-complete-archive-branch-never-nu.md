---
id: T-3235
name: "partial-complete archive branch never nulls horizon (peer 832 T-654 BUG 1)"
description: >
  partial-complete archive branch never nulls horizon (peer 832 T-654 BUG 1)

status: started-work
workflow_type: build
owner: agent
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
created: 2026-08-31T19:04:00Z
last_update: '2026-08-31T19:15:18Z'
date_finished:
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
  - ts: '2026-08-31T19:15:10Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=165,acs=11)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-31T19:15:18Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 4
      D3: 2
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=1 (body:fix-without-learning); D2=4 (body:fw-audit-or-doctor);
      D3=2 (body:default-change); D4=0 (no-signal); F-RECALL=0 (no-signal); 
      F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3235: partial-complete archive branch never nulls horizon (peer 832 T-654 BUG 1)

## Context

Reported upstream by peer **832-Workflow-designer** (their T-654 BUG 1, chat-arc
offset 879), framed as "a property enforced at SITES rather than asserted at the
INVARIANT". Confirmed in-tree against this repo's `update-task.sh` before
anything was changed.

Two branches move a task file into `.tasks/completed/`, and their entry
conditions are **exact complements**:

| branch | entry condition | horizon |
|---|---|---|
| ordinary completion | `OLD_STATUS != work-completed` | nulled (T-2163, widened T-2300) |
| partial-complete recheck | `OLD_STATUS == NEW_STATUS == work-completed`, file still in `active/` | untouched |

Because they are complements, **no widening of the first can ever reach the
second**. T-2300 already widened it once — after eight CTL-030 instances
(T-2168/T-2180/T-2182/T-2196/T-2201/T-2203/T-2204/T-2248) — and still missed
this, because the fix was aimed at the site where the symptom showed rather than
at the property being enforced.

The sharp end is `fw task archive-eligible`, which re-invokes
`--status work-completed` on tasks already at work-completed in `active/`
(`['task','update',task_id,'--status','work-completed','--switch-focus']`) and
therefore drives **exclusively** through the branch that was unfixed. The sweep
`fw audit` recommends for stuck partial-completes would manufacture the CTL-030
failures the same audit then reports.

**Zero instances in this corpus** at the time of the fix — `grep -l '^horizon:
now$' .tasks/completed/*.md` returns nothing. This is a latent fault that
generates no evidence until the sweep is used, which makes now the cheapest
moment rather than a reason to defer.

The fix is a post-condition keyed on **final location**, asserted once at the end
of the script: a file under `completed/` carries `horizon: null`. Never keyed on
status — a partial-complete that stays in `active/` must KEEP its stored horizon
(it renders from it while the human owns it), and that is precisely the case a
status-keyed check would break. The old site is removed rather than duplicated,
so there is one writer, not two.

**Method, carried over from 832's note on their own first prober.** Their rig went
green against the wrong branch: the obvious fixture — tick the human AC and re-run
— leaves `status: started-work`, which is an ordinary transition that never enters
the recheck branch at all. Every leg here asserts WHICH branch ran, by the line
only that branch prints, before asserting the outcome. Their second note also
applies: a mutant copy of `update-task.sh` cannot live in a bare temp dir (it
derives `FRAMEWORK_ROOT` from its own location and dies on the first `source`, and
a dead subject reads exactly like a regressed one), so the mutation control builds
a symlink farm.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] The property is asserted ONCE, as a post-condition on where `TASK_FILE`
      actually ended up, rather than added as a second copy at the second move
      site. "A file under `.tasks/completed/` carries `horizon: null`" is an
      invariant of archival; today it is a line inside one branch, which is why
      the complementary branch could never inherit it.
- [x] A task archived through the **partial-complete recheck** branch
      (`OLD_STATUS == NEW_STATUS == work-completed`, file still in `active/`)
      lands in `completed/` with `horizon: null`.
- [x] The test asserts WHICH branch archived the file, not only that the file
      moved. The obvious fixture — tick the human AC and re-run — leaves
      `status: started-work` and is an ordinary transition that never enters the
      recheck branch at all, so a rig that checks only the outcome goes green
      against the wrong path (peer 832's method note on their own first prober).
- [x] Control: the ordinary `started-work → work-completed` path still nulls the
      horizon. A guard that fixes one branch by breaking the other is not a fix.
- [x] Control: a partial-complete run that LEAVES the file in `active/` still does
      NOT null the horizon. That is deliberate (update-task.sh comment, T-2300 —
      the file renders from its stored horizon while the human still owns it), so
      the post-condition must key on final location, never on status alone.
- [x] Mutation control derived from live source: removing the post-condition
      re-opens the bug, proving the test measures the fix and not the fixture.
- [x] `fw task archive-eligible` is covered, because it re-invokes
      `--status work-completed` on tasks already at work-completed in `active/`
      (`bin/fw`, `['task','update',task_id,'--status','work-completed','--switch-focus']`)
      and therefore drives EXCLUSIVELY through the unfixed branch — the audit's
      own recommended sweep manufactures the CTL-030 failures the same audit reports.
- [x] Corpus check stays clean: no file in `.tasks/completed/` carries
      `horizon: now`. It is 0 today — this is a latent fault with no instances
      yet, and the point is to keep it that way rather than to clean up after it.
- [x] The suites that drive `update-task.sh` are run WHOLE — no file excluded —
      and their failures are pinned by exact COUNT and by name. Two were already
      red at HEAD (OBS-359, OBS-360), verified by checking out HEAD's
      `update-task.sh`, re-running, and restoring; neither is this task's to fix.
      Pinning the count rather than carving the files out means a third failure —
      an actual regression from this change — reddens the gate instead of hiding
      inside an exclusion list.
- [x] Those two pre-existing reds are registered, not absorbed: OBS-359 (an
      equality assertion where the invariant is a floor) and OBS-360, plus
      OBS-361 for why neither was reported by anything — nothing runs `tests/unit`
      on a schedule, and the audit's "Invariant suite green" line covers
      `tests/lint` only while reading like the whole corpus.

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

# The suite, and proof all six legs actually ran (a suite that collects nothing
# also prints no "not ok").
timeout 900 bats tests/unit/t3235_archived_horizon_invariant.bats > /tmp/.t3235a.out 2>&1 && ! grep -q "^not ok" /tmp/.t3235a.out
grep -q "^1\.\.6" /tmp/.t3235a.out
# The branch assertions fired — without them a green could be the wrong branch.
grep -q "^ok 1 archived through the PARTIAL-COMPLETE RECHECK branch" /tmp/.t3235a.out
grep -q "^ok 4 removing the post-condition re-opens the bug" /tmp/.t3235a.out
bash -n agents/task-create/update-task.sh
# ONE writer, not two: the invariant exists once and the old site is gone.
test "$(grep -c 'ARCHIVED-HORIZON INVARIANT' agents/task-create/update-task.sh)" -eq 1
test "$(grep -c 'horizon: null/' agents/task-create/update-task.sh)" -eq 1
# The corpus this is meant to keep clean.
test "$(grep -l '^horizon: now$' .tasks/completed/*.md 2>/dev/null | wc -l)" -eq 0
# Every suite that drives update-task.sh — run WHOLE, with no exclusions, and
# pinned to the exact set of failures that already existed. Two suites there are
# red at HEAD and are not this change's to fix (one bug, one task):
#   OBS-359  ac_counter_sed_range_one_line_comment — asserts an exact count (2)
#            of a comment-strip regex that now has 3 correct call sites.
#   OBS-360  inception_decide_emit_review_post_move — verified red against HEAD's
#            update-task.sh by checkout, re-run, restore.
# Pinning the COUNT rather than excluding the files means a third failure — a
# real regression from this change — reddens the gate instead of hiding behind a
# carve-out. Both are also symptoms of OBS-361: nothing runs tests/unit on a
# schedule, so these sat red unreported.
timeout 2400 bats $(grep -rln 'update-task.sh' tests/unit/*.bats | tr '\n' ' ') > /tmp/.t3235adj.out 2>&1; test "$(grep -c '^not ok' /tmp/.t3235adj.out)" -eq 2
grep -q "^not ok .* strips one-line comments before range strip" /tmp/.t3235adj.out
grep -q "^not ok .* do_inception_decide exits 0 when emit_review sees stale task_file" /tmp/.t3235adj.out
# and this task's own suite is inside that run, green
grep -q "^ok .* archived through the PARTIAL-COMPLETE RECHECK branch" /tmp/.t3235adj.out
python3 tools/bats-silent-skip-lint.py tests/

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

### 2026-08-31T19:04:00Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3235-partial-complete-archive-branch-never-nu.md
- **Context:** Initial task creation
