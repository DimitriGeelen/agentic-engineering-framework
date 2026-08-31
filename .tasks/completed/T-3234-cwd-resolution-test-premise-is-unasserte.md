---
id: T-3234
name: "cwd-resolution test premise is unasserted, so host pollution reads as a code
  regression"
description: >
  cwd-resolution test premise is unasserted, so host pollution reads as a code regression

status: work-completed
workflow_type: build
owner: agent
horizon: null
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
created: 2026-08-31T18:36:45Z
last_update: 2026-08-31T18:56:50Z
date_finished: 2026-08-31T18:56:50Z
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
  - ts: '2026-08-31T18:45:10Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=280,acs=9)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-31T18:45:21Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3234: cwd-resolution test premise is unasserted, so host pollution reads as a code regression

## Context

`fw task update T-3222 --status work-completed` was refused at the P-011 gate on
one leg of its adjacent-suite sweep: `check_active_task_cwd_resolution.bats`
"T-2463: cwd outside any project". The failure output was
`[ "$status" -eq 0 ]' failed` and nothing else, which reads as a regression in
the hook.

It was not. A full `fw init` had run with cwd=/tmp on this host at
2026-08-31T13:04:49Z — `/tmp/.framework.yaml`, `/tmp/.tasks` with six seed tasks,
`/tmp/.context`, `/tmp/.agentic-framework` (VERSION 1.6.354, not this repo's
1.6.138), `/tmp/.claude/settings.json` with hooks pointing into `/tmp` — with a
`git init` behind it a minute later. `lib/paths.sh:fw_reanchor_from_cwd` walks up
for those markers and stops before `/`, so /tmp had been correctly "outside any
project" until that moment. Afterwards every fixture under `BATS_TEST_TMPDIR`
re-anchored to /tmp and read its null focus.

The red leg is the mild direction. The dangerous one is the opposite: a suite
whose fixture has no markers of its own, or one asserting a block, can be
satisfied by the ambient project and go **green for a reason unrelated to the
code it names**. That is the same false-green family the gate suites exist to
catch, one level down — in the environment rather than in the command string.

So the fix is not in the leg that noticed. It is a corpus-level invariant, because
the ambient project is an undeclared input to *every* hook suite that builds a
fixture under the bats temp base. The leg that noticed gets a comment pointing at
it, nothing more.

Registered as OBS-358 (urgent). The stray `/tmp` artefacts were moved aside — not
deleted; `/tmp/.git` was owned by another user — into this session's scratchpad.
Two things this task deliberately does NOT do: find what ran that `fw init` (that
is its own bug, and its own task), and touch `/.framework.yaml` and `/.tasks`,
which exist on this host from June and August but are out of the resolver's reach
because its walk stops before `/`.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] A corpus-level invariant exists under `tests/lint/` that walks from the bats
      temp base (`BATS_TMPDIR`, default `/tmp`) up to `/` and fails when any
      directory on that path carries `.framework.yaml` or `.tasks/`. It is at
      corpus level, not inside the one suite that noticed, because the ambient
      project is an undeclared input to every hook suite that builds a fixture
      under `BATS_TEST_TMPDIR`.
- [x] Its failure output names the offending directory, the marker file, and
      states that this is host state rather than a code regression — the whole
      point is that the original symptom (`[ "$status" -eq 0 ]' failed`) read
      like a bug in our code.
- [x] The walk mirrors `lib/paths.sh:fw_reanchor_from_cwd` exactly, INCLUDING its
      stop-before-`/` condition, and a leg greps the resolver for that condition
      so the mirror cannot silently drift out of agreement with the code.
- [x] A second mirror leg pins the marker set (`.framework.yaml` / `.tasks`) against
      the resolver, so a resolver that gains a third marker cannot leave this guard
      measuring two of three and still reporting green.
- [x] The guard is RED against the polluted state and GREEN against the clean one,
      demonstrated by running it both ways — not merely by observing that it passes
      today. `BATS_TMPDIR` is NOT the lever: bats overwrites it at startup from
      `TMPDIR` (`libexec/bats-core/bats`), so the red direction is driven by pointing
      `TMPDIR` at a directory whose ancestry carries a marker. The file records that,
      so the next person can reproduce the red in one command.
- [x] `tests/unit/check_active_task_cwd_resolution.bats` "cwd outside any project"
      is green, and the 13-suite gate sweep is green.
- [x] That leg carries a PREMISE comment naming the host dependency and pointing at
      the new lint, so a future red is read as "check the host first" instead of
      being debugged as a code regression the way it was this time.
- [x] The new lint is collected by the runner that already globs `tests/lint/`
      (`bin/fw test`), so it inherits the daily audit's invariant-suite check
      rather than needing separate wiring.

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

# GREEN direction — the guard passes on a clean host.
timeout 300 bats tests/lint/no-project-markers-above-bats-tmpdir.bats > /tmp/.t3234a.out 2>&1 && ! grep -q "^not ok" /tmp/.t3234a.out
# All four legs ran (a suite that collects nothing also prints no "not ok").
grep -q "^1\.\.4" /tmp/.t3234a.out
# RED direction — TMPDIR is the lever, because bats overwrites BATS_TMPDIR from it
# at startup. Pointing it inside this repo puts the repo's own .framework.yaml above
# the base, so leg 1 must fail. A guard that cannot be made to fail proves nothing.
d=.context/working/.t3234-verify; mkdir -p "$d"; TMPDIR="$PWD/$d" timeout 300 bats tests/lint/no-project-markers-above-bats-tmpdir.bats > /tmp/.t3234b.out 2>&1; rm -rf "$d"; grep -q "^not ok 1 no \.framework\.yaml" /tmp/.t3234b.out
# and the red says WHICH directory and that it is host state, not our code
grep -q "HOST POLLUTED" /tmp/.t3234b.out && grep -q "host state, not a code regression" /tmp/.t3234b.out
# The mirror legs stay green in the red run too — only leg 1 is host-dependent.
grep -q "^ok 3 the resolver still stops before" /tmp/.t3234b.out
# The leg that noticed is green, and carries the premise comment pointing here.
timeout 300 bats tests/unit/check_active_task_cwd_resolution.bats > /tmp/.t3234c.out 2>&1 && ! grep -q "^not ok" /tmp/.t3234c.out
grep -q "no-project-markers-above-bats-tmpdir" tests/unit/check_active_task_cwd_resolution.bats
# Collected by the runner that already globs tests/lint/ — no separate wiring.
timeout 900 bats tests/lint/ > /tmp/.t3234d.out 2>&1; grep -q "no \.framework\.yaml / \.tasks between the bats temp base" /tmp/.t3234d.out
! grep -q "^not ok" /tmp/.t3234d.out
# The 13-suite gate sweep this originally blocked.
timeout 1500 bats tests/unit/t3221_commit_exemption_clause.bats tests/unit/fd_dup_not_chain_split.bats tests/unit/safe_commands_chain.bats tests/unit/check_active_task_cwd_resolution.bats tests/unit/check_active_task_fp_fix.bats tests/unit/check_active_task_memory_exempt.bats tests/unit/check_active_task_switch_focus.bats tests/unit/context_safe_commands.bats tests/unit/safe_commands_env_prefix.bats tests/unit/t3096_safe_commands_wrappers.bats tests/unit/t3179_partial_complete_commit.bats tests/unit/test_check_active_task_bootstrap.bats tests/unit/test_safe_commands_git_commit.bats > /tmp/.t3234sweep.out 2>&1 && ! grep -q "^not ok" /tmp/.t3234sweep.out
# No silent skips anywhere in the corpus.
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

### 2026-08-31T18:36:45Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3234-cwd-resolution-test-premise-is-unasserte.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-3153ce66
- **Timestamp:** 2026-08-31T19:02:46Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** yes
- **Findings:** none

- **Layer-1 escalations:** 1
  1. **destructive-action** (high) — Destructive operation in verification or AC
     - matched: `rm -rf`

### 2026-08-31T18:56:50Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
