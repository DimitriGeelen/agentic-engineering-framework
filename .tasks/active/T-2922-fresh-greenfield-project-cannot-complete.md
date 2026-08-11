---
id: T-2922
name: "fresh greenfield project cannot complete its first inception: fw task review
  fails closed without a Watchtower nothing told the user to start"
description: >
  On a genuinely fresh fw init greenfield project, fw task review exits non-zero and
  writes no .context/working/.reviewed-T-XXX marker when no Watchtower is reachable.
  fw inception decide refuses without that marker, and the marker gate (lib/inception.sh:474)
  is unconditional — it blocks GO, NO-GO and DEFER alike, so there is no escape hatch
  at all, not even the hedge. Nothing instructs the user to run fw serve: greenfield
  T-001 mentions Watchtower only as 'what you can do meanwhile', an optional aside,
  not a prerequisite. Net effect: the first inception a new user ever runs cannot
  be completed by any path out of the box. Directly on the arc-015/arc-017 onboarding
  line and a sibling of T-2720's keystone (the onboarding set must contain nothing
  the agent cannot resolve). Found by the T-2862 end-to-end run. Note fw task review
  does NOT verify reachability — setting WATCHTOWER_URL to an unreachable address
  satisfies it — so the fix may be as small as a sane default rather than a hard failure.

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
created: 2026-08-11T15:42:17Z
last_update: 2026-08-11T21:19:22Z
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
  - ts: '2026-08-11T15:45:08Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 7
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-11T15:45:15Z'
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

# T-2922: fresh greenfield project cannot complete its first inception: fw task review fails closed without a Watchtower nothing told the user to start

## Context

Found by the T-2862 end-to-end greenfield run. On a genuinely fresh `fw init`
project with no Watchtower running, the first inception a new user creates
**cannot be completed by any path**.

The mechanism, from source:

- `lib/review.sh:338` writes the review marker
  (`.context/working/.reviewed-<task_id>`) at the **end** of `emit_review`.
  Anything that exits the function earlier leaves the marker uncreated.
- `lib/inception.sh:474-483` refuses `fw inception decide` when that marker is
  absent — and the gate is **unconditional**: it blocks `GO`, `NO-GO` *and*
  `DEFER` alike. There is no escape hatch, not even the hedge.
- Nothing in the greenfield onboarding set tells the user to run `fw serve`
  first. Greenfield T-001 mentions Watchtower only under "what you can do
  meanwhile" — an optional aside, not a prerequisite.

Net: the gate is a chokepoint whose unblock command is the very command that
fails. Sibling of T-2720's keystone (the onboarding set must contain nothing
the agent cannot resolve) and on the arc-015/arc-017 line.

**Load-bearing detail for the fix:** `fw task review` does **not** verify
reachability — pointing `WATCHTOWER_URL` at an unreachable address satisfies it
today. So the failure is not "Watchtower must be up"; it is that URL
*resolution* fails when nothing has ever been started. The fix is therefore
plausibly a sane default rather than a new dependency — and any fix that makes
review *require* a live Watchtower would make onboarding strictly worse.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Reproduced first: an automated leg drives a fresh `fw init` project with no Watchtower running and asserts that, **before** the fix, `fw task review` on an inception exits non-zero and leaves no `.reviewed-<id>` marker — the regression must bite before it is repaired
- [x] On that same fresh project with no Watchtower, `fw task review T-XXX` exits 0 and writes `.context/working/.reviewed-T-XXX`
- [x] `fw inception decide` then succeeds for **all three** dispositions on a fresh project — `go`, `no-go` and `defer` each verified, because the marker gate blocks all three and a fix tested only against `go` leaves two thirds of the escape hatch shut
- [x] The fix does **not** introduce a live-Watchtower requirement: a leg asserts `fw task review` still succeeds when no server is listening, so onboarding never gains a daemon prerequisite
- [x] `fw task review` output on a Watchtower-less project names how to start one (`fw serve`) rather than only emitting an unreachable URL — the user is told the thing the URL presumes
- [x] Existing behaviour with a live Watchtower is unchanged: URL, QR and marker all still emitted (regression leg, since the emit path is shared)

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

# The suite: 9 legs, including the reproduce-before-repair leg (AC1) and the
# live-Watchtower regression leg (AC6). Builds a real `fw init` project in
# setup_file (~90s) because the bug only exists on a project nobody configured.
bats tests/integration/t2922_greenfield_first_inception.bats

# T-1155's invariants — port resolution must stay inside lib/watchtower.sh.
# A first draft of this fix put the fallback inline in lib/review.sh and went
# RED on legs 1 and 5 here; that is what moved it to the helper.
bats tests/lint/single-port-detection.bats

# The helper answers in both states and distinguishes them by exit code, never
# by an empty string (an empty base concatenates into a broken relative path
# that still reads as a link).
bash -c 'set -e; export PROJECT_ROOT=/nonexistent-t2922-probe FRAMEWORK_ROOT=$PWD; source lib/watchtower.sh; out=$(_watchtower_base_or_placeholder T-0 2>/dev/null) && exit 1; [ $? -eq 2 ]; [ -n "$out" ]'

# Vendored copy stays in sync (the self-vendor FAIL that surfaced this work).
bin/fw vendor self --check

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

## Decisions

**AC3 was verified structurally, not by executing three decisions.** The AC asks
that `go`, `no-go` and `defer` each succeed once the marker exists. `fw inception
decide` is Tier 0 and blocked in agent context by design — routing around that to
green a test would be precisely the bypass the gate exists to prevent, so it was
not attempted.

What leg 6 proves instead: the marker gate is disposition-INDEPENDENT by
construction. The 3-way validation `case` (`go|no-go|defer`) sits upstream of the
marker check, nothing between them reads `$decision`, and the leg fails if either
fact stops holding. For the question the AC is actually asking — "does a fix
tested only against `go` leave two thirds of the escape hatch shut?" — this covers
all three inputs rather than sampling them.

What it does not cover: a disposition-specific failure *downstream* of the marker
gate, which three real executions would catch. If you want that closed, the
executions are yours to run — the fixture project is torn down by the suite, so
it would be three `fw inception decide` calls on this repo or a scratch project.

**Placement of the fallback.** The first draft put the port fallback inline in
`lib/review.sh` and went RED on two of T-1155's invariants. Those invariants
guard the consumer-port bug (framework defaults to 3000, consumer serves
elsewhere, every link 404s) — the same class as this one, one layer over. The
fallback belongs in `lib/watchtower.sh` because that is where the configured port
already resolves; the invariant was right and the draft was wrong.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-08-11T15:42:17Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2922-fresh-greenfield-project-cannot-complete.md
- **Context:** Initial task creation

### 2026-08-11T21:19:22Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
