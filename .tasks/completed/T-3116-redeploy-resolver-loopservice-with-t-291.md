---
id: T-3116
name: "redeploy resolver-loop.service with T-2914 stall-after fix (OBS-280 deploy
  drift)"
description: >
  redeploy resolver-loop.service with T-2914 stall-after fix (OBS-280 deploy drift)

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
created: 2026-08-22T15:38:38Z
last_update: 2026-08-25T12:06:47Z
date_finished: 2026-08-25T12:06:47Z
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
  - ts: '2026-08-22T15:45:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 7
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=7 (lines=199,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-22T15:45:13Z'
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

# T-3116: redeploy resolver-loop.service with T-2914 stall-after fix (OBS-280 deploy drift)

## Context

OBS-280 (2026-08-16, T-3030) already diagnosed this: `deploy/resolver-loop.service`
carries the T-2914 fix (`--stall-after 5`, which excludes a task from re-dispatch
once N consecutive dispatches show no advancement), but `/etc/systemd/system/
resolver-loop.service` on this host was never updated — it still runs
`--cooldown-min 30`, which the repo's own comment says "had already expired by
the time the next tick fired ... so it never actually suppressed anything"
(origin: T-2862, 57 dispatches / 0 outcomes over 2 days).

Live measured consequence, found while re-verifying T-1719 (the eleventh
re-dispatch of that task in ~6 days for the same already-resolved AC, A6b): the
`Recent Dispatches` envelope for T-1719 showed five dispatches exactly 30
minutes apart (13:00, 13:30, 14:00, 14:30, 15:00), matching the timer's
`OnUnitActiveSec` exactly, all `outcome=success` despite zero AC advancement
since the ninth dispatch. `diff /etc/systemd/system/resolver-loop.service
deploy/resolver-loop.service` confirms the live unit is the pre-T-2914 version.
`--stall-after 5` would have excluded T-1719 after its fifth non-advancing
re-dispatch; it has had at least six.

This is a pure deploy-drift fix — copy the file, reload, restart — not a code
change. `deploy/resolver-loop.service` is the source of truth (T-2494 template).

## Acceptance Criteria

### Agent
- [x] **A1** `/etc/systemd/system/resolver-loop.service` matches
  `deploy/resolver-loop.service` byte-for-byte (diff empty).
- [x] **A2** `systemctl daemon-reload` run; `systemctl cat resolver-loop.service`
  shows `ExecStart=... --stall-after 5` (not `--cooldown-min`).
- [x] **A3** `fw resolver stalled --json` runs cleanly against the live unit
  (confirms the new flag is understood by the installed `fw` binary this
  systemd unit invokes — no stale-vendoring mismatch).
- [x] **A4** Timer still enabled/active after reload (`systemctl is-active
  resolver-loop.timer` — or equivalent — unchanged from pre-edit state).

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).
#
# ── Pipefail/SIGPIPE: grepping a command's output (L-387, T-2090, T-2743, T-2738) ──
#
# THE DEFAULT — redirect to a file, then grep the file:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
#     curl -sf "$(bin/fw watchtower url)/page" -o /tmp/.out && grep -q "PAT" /tmp/.out
# Correct at any output size, and `&&` keeps the PRODUCING command's exit code in
# the verdict. Reach for this first; the alternative below is the special case.
#
# Why not `cmd | grep -q PAT` (L-387): P-011 runs each line under `set -eo
# pipefail`. When grep matches it exits and closes stdin while cmd is still
# writing, cmd takes SIGPIPE, the pipeline exits 141 — verification "fails" with
# the pattern present. Captured 4× (T-1716, T-1838, T-1862, T-1863).
#
# THE EXCEPTION — capture first, grep the capture:
#     out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"
# Valid ONLY while "$out" fits the 65536-byte pipe buffer, and it is on you to
# know that it does. Above that the form inverts and becomes the very failure
# L-387 describes: echo blocks on the full pipe, grep -q exits, echo takes
# SIGPIPE, rc=141 (T-2743 — measured on a 146,366-byte Watchtower page, 3/3 runs,
# deterministic not racy; rendered routes run 50-200KB, so anything that curls a
# page is over the line). It also discards cmd's exit code, so a 404 yields an
# empty capture that grep merely fails to match rather than a failed line.
# If you do use it: single pipe only, no intermediate tail/awk/sed stage between
# capture and grep (T-2090) — the middle stage is what `grep -q` slams its stdin
# on, and grep scans the whole captured string anyway, so the `tail -3` was
# cosmetic. `echo "$out" | grep -q PAT`, nothing between.
#
# TEST RUNNERS need a guard either way (T-2738). `set -e` is suppressed inside the
# `if` condition the gate runs each line in, so in `cmd1; cmd2` only cmd2 is the
# verdict — and the pass marker you grep for survives a partial failure: a suite
# printing "3 failed, 9 passed" satisfies `grep -q "9 passed"`, and generalising
# to `grep -qE "[0-9]+ passed"` matches the same output. Keep the exit code:
#     python3 -m pytest <file> -q > /tmp/.out 2>&1 && grep -q passed /tmp/.out
# or add the guard the exit code used to supply:
#     out=$(python3 -m pytest <file> -q 2>&1); echo "$out" | grep -q passed && ! echo "$out" | grep -q failed
#     out=$(bats <file> 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# The close gate refuses the unguarded form. Bypass: FW_ALLOW_UNJUDGED_TEST_RUN=1.
#
# REHEARSING A LINE BY HAND DOES NOT REHEARSE THE GATE (T-2743). Your interactive
# shell has no `set -eo pipefail`. A line has returned 0 by hand and 141 under
# P-011, from the same directory, the same second. To rehearse for real:
#     bash -c 'set -eo pipefail; <your verification line>'
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.
diff /etc/systemd/system/resolver-loop.service deploy/resolver-loop.service
out=$(systemctl cat resolver-loop.service 2>&1); echo "$out" | grep -- "^ExecStart=" > /tmp/.t3116-execstart; grep -q -- "--stall-after 5" /tmp/.t3116-execstart && ! grep -q -- "--cooldown-min" /tmp/.t3116-execstart
systemctl is-active resolver-loop.timer

## RCA

**Symptom:** `/etc/systemd/system/resolver-loop.service` (the live, installed
unit) still ran `--cooldown-min 30` after the T-2914 fix landed in
`deploy/resolver-loop.service` (`--stall-after 5`). Measured consequence
caught during T-1719 re-verification: five consecutive dispatches exactly 30
minutes apart, all `outcome=success`, zero AC advancement since the ninth
dispatch — the cooldown window matched the timer's `OnUnitActiveSec` exactly
and so never actually suppressed a non-advancing re-dispatch (same failure
mode as the T-2862 origin: 57 dispatches / 0 outcomes over 2 days).

**Root cause:** `deploy/resolver-loop.service` is a source-of-truth template
copied to `/etc/systemd/system/` by a manual operator step (`sudo cp ... &&
systemctl daemon-reload`, per the file's own header comment) — there is no
automated sync between a repo-tracked deploy artifact and the live systemd
unit it templates. T-2914 changed the repo file but nothing re-ran the manual
deploy step on this host, so the fix shipped in git without shipping to the
running service.

**Why structurally allowed:** deploy drift for host-installed systemd units is
invisible to normal task-close gates (P-011 verifies repo state, not live host
state) and to `fw doctor` at the time T-2914 closed — there was no check
comparing `deploy/*.service` against `/etc/systemd/system/*.service`. The gap
was only surfaced manually, via OBS-280 (2026-08-16, T-3030) noticing the
diff during unrelated verification of T-1719.

**Prevention:** this redeploy (T-3116) closes the immediate drift. The
generalisable prevention — a `fw doctor` check that diffs
`deploy/*.service`/`*.timer` against their installed
`/etc/systemd/system/` counterparts and WARNs on mismatch — is not yet built;
recommend a follow-up task if this class recurs. Immediate mitigation for this
instance: `fw resolver stalled --json` (A3) confirms the installed `fw`
binary this unit invokes understands `--stall-after`, closing the
stale-vendoring variant of this same drift class.

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

<!-- T-2945: same shape as inception.md's block — the gate that reads it
     (audit_inception_recommendation, lib/task-audit.sh:117) is shared, so the
     shape is copied rather than reinvented.

     REQUIRED once this task reaches partial-complete: Agent ACs done, at least
     one `### Human` AC still unticked. `lib/review.sh:205-211` (T-2421) BLOCKS
     `fw task review` emission for build/refactor/test/decommission tasks in that
     state with no substantive block here — the operator would otherwise open
     /review/<id> to a blank Recommendation card and be asked to approve a form.

     Not required while every Human AC is ticked or the task has none: the gate
     only fires on the partial-complete transition. It is here from the start so
     you write it while you still have the evidence, not when the gate refuses.

     Format (the parser wants the `**Recommendation:**` line at the start of a
     line; a leading `-` or `*` bullet is also accepted):
     **Recommendation:** GO / NO-GO / DEFER
     **Rationale:** Why (cite evidence — what shipped, what was proven, what remains)
     **Evidence:**
     - Finding 1
     - Finding 2

     DEFER is for evidence gaps, not confidence gaps (CLAUDE.md §Presenting Work
     for Human Review). If the artefact is complete and you still don't want to
     commit, that is a calibration failure — recommend GO or NO-GO.
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

### 2026-08-22T15:38:38Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3116-redeploy-resolver-loopservice-with-t-291.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-8e05065f
- **Timestamp:** 2026-08-25T12:06:48Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-25T12:06:47Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
