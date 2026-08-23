---
id: T-3125
name: "self-vendor pre-push gate reads the working tree but its stated purpose is
  the pushed ref"
description: >
  The T-2240 pre-push gate runs 'fw vendor self --dry-run', which compares working-tree
  source against working-tree vendored copies. Its own comment states the property
  it protects: 'consumers that vendor from origin/master inherit the stale lib/ silently'.
  Consumers vendor from the PUSHED REF, not from anyone's working tree. The proxy
  and the property diverge, and the divergence is not rare: any session with uncommitted
  edits to a vendored-class file blocks every other session's push indefinitely, with
  no exit except a Tier-2 or Tier-0 bypass. Observed live 2026-08-23 — 15 commits
  held for hours by another session's uncommitted bin/fw and agents/audit/audit.sh,
  where 'git show HEAD:<src>' was byte-identical to the vendored copy for both files,
  so the ref being pushed was clean. Same family as T-1828: a gate measuring a proxy
  that drifted from the property it exists to protect.

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
created: 2026-08-23T20:52:29Z
last_update: 2026-08-23T21:24:10Z
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
  - ts: '2026-08-23T21:00:09Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=202,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-23T21:00:20Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3125: self-vendor pre-push gate reads the working tree but its stated purpose is the pushed ref

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] The gate blocks only when the vendored copies are stale **in the tree being
      pushed**. Drift that exists solely in the working tree — uncommitted edits,
      whether this session's or a concurrent one's — does not block.
- [x] Working-tree-only drift still surfaces, as a WARN naming the affected
      class(es) and saying plainly that the pushed ref is clean. It must not go
      silent: the operator has a real thing to fix, just not a push-blocking one.
- [x] The gate's original protection is intact: committing a source change without
      running `fw vendor self` still blocks the push. This is the regression that
      matters — the fix must not turn T-2240 into a no-op.
- [x] Tests cover all four states on their own fixture repo (L-599, not this
      checkout): clean; committed drift; working-tree-only drift; both at once.
      The report states how many fail against the pre-change hook.
- [x] The fix lives in `agents/git/lib/hooks.sh`. `bin/fw` is not edited — it
      carries another session's uncommitted work and must not be touched.
- [x] `.git/hooks/pre-push` is regenerated (or confirmed to source the changed
      file) so the fix is live in this checkout, not merely in source.
- [x] Scope fence: this task does **not** touch the file-class list shared by
      `fw vendor self` and the audit gate. That mismatch is T-2607 — a different
      defect on a different axis, still open, deliberately left alone.

## Result

Mechanism: `fw vendor self --dry-run` stays the cheap detector. Before blocking,
the hook compares committed blob SHAs for the source paths in each checked class
against their vendored counterparts, using the local sha from the pre-push stdin
— the tree consumers actually vendor — falling back to HEAD when stdin carries
nothing usable (manual invocation, tag-only push, deletion).

| committed | working tree | outcome |
|---|---|---|
| clean | clean | allowed, silent |
| clean | dirty | **allowed, WARN** naming the class(es), stating the pushed ref is clean |
| stale | either | BLOCK, unchanged T-2240 message plus the offending paths |

It walks **source** paths rather than the vendored tree, so a newly committed
file that was never vendored still blocks — the protection T-2240 exists for.
Test (b2) pins exactly that, because it is the way this fix could most easily
have become a no-op. VERSION is excluded as sync-only; the designer build is
pin-resolved rather than globbed, because the vendored tree prunes superseded
builds and the glob form reported 8 permanent phantoms that would have kept the
gate permanently in the blocking state.

7/7 on a synthetic repo, with the hook generated into the fixture so the suite
measures `hooks.sh` rather than whatever happens to be installed in `.git/hooks`.
**Mutation check: 4 of 7 fail against pre-change code**, with (c) working-tree-only
and (c2) the literal 2026-08-23 shape as the discriminators. 31/31 across the
neighbouring hook suites. `bin/fw git install-hooks` re-run, so the fix is live
here and not merely in source.

### Verified end to end

`git push origin HEAD:master` no longer stops at the self-vendor gate. It now
reaches the audit gate, which blocks on two findings — both from the same
concurrent session's uncommitted work, neither present in the ref being pushed.
That is the same confusion at a different surface, filed as **T-3126**: the audit
is not wrong to read the working tree, but coupling a working-tree health FAIL to
a ref-based operation reproduces exactly the class this task closed one surface of.

## Verification

bats tests/unit/t3125_prepush_self_vendor_judges_pushed_ref.bats > /tmp/.t3125a.out 2>&1 && grep -q "7 tests, 0 failures" /tmp/.t3125a.out
bash -n agents/git/lib/hooks.sh
grep -q "T-3125" .git/hooks/pre-push
diff -q agents/git/lib/hooks.sh .agentic-framework/agents/git/lib/hooks.sh
git diff --quiet HEAD -- bin/fw || git diff HEAD -- bin/fw | grep -qv 'fw cron install'
