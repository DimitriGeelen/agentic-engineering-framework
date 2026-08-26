---
id: T-3170
name: "arc-012 S4: wire session-end.sh and add SessionEnd to hook-enable VALID_EVENTS"
description: >
  arc-012 S4: wire session-end.sh and add SessionEnd to hook-enable VALID_EVENTS

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [arc:continuous-run]
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
created: 2026-08-26T14:49:39Z
last_update: 2026-08-26T15:08:42Z
date_finished: 2026-08-26T15:08:42Z
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
  - ts: '2026-08-26T15:00:09Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=260,acs=7)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-26T15:00:19Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 1
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=1 (body:episodic-only); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3170: arc-012 S4: wire session-end.sh and add SessionEnd to hook-enable VALID_EVENTS

## Context

T-3159 §15.4 row 4 reads "wire `session-end.sh`; add `SessionEnd` to `hook-enable.sh`
`VALID_EVENTS`". Those are two changes, and only one of them is ours to make.

**The half that is not.** `session-end.sh` is marked REFERENCE ONLY in its own header,
pointing at T-1459 — an inception that reached **GO on Option D, reference-only**, with
a stated precondition for ever re-enabling it: read the G-016 RCA first. G-016 was a
handover **commit storm**, and the last action on this script cluster was *defensive
capping*, not decommissioning. Registering it here would silently reverse a recorded
operator decision and re-introduce the hazard that decision parked. §15.4 was written
without that history in view.

**The half that is.** `bin/hook-enable.sh` lists seven events in `VALID_EVENTS` and
`SessionEnd` is not among them, so the framework's own tool refuses to enable an event
Claude Code fires — regardless of what anyone decides about our handler. That is a
capability gap in the tool, not a policy question, and it is independent of the
registration decision above.

Slice 4 of T-3159 §15.4 (arc-012), landed as its safe half. The registration decision
is the operator's and stays open.

## Acceptance Criteria

### Agent
- [x] `SessionEnd` is accepted by `bin/hook-enable.sh` — present in `VALID_EVENTS` and
      in the `--event` help text, so the tool can enable every event Claude Code fires.
- [x] `session-end.sh` is NOT registered in `.claude/settings.json`; its REFERENCE ONLY
      header stays and now names the precondition (read the G-016 RCA) rather than only
      a task number, so the next reader learns why without chasing T-1459.
- [x] `tests/unit/hook_enable_events.bats` pins both: `SessionEnd` accepted, and no
      `SessionEnd` entry in `.claude/settings.json`. The second assertion is the one
      that matters — it turns a recorded decision into something that fails loudly if
      a later session quietly reverses it.
- [x] The enforcement baseline is unchanged, because `.claude/settings.json` is not
      touched (L-398: a hook edit without a baseline refresh leaves `fw doctor` FAILing
      silently — here the point is that there is no hook edit at all).
- [x] T-3159 §15.4 records row 4 as half-landed, naming the part deferred to the
      operator and why.

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

bash -n bin/hook-enable.sh
out=$(bats tests/unit/hook_enable_events.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
grep -q 'SessionEnd' bin/hook-enable.sh
grep -q 'G-016' agents/context/session-end.sh
bin/fw doctor > /tmp/.t3170doc 2>&1; ! grep -q "Enforcement baseline CHANGED" /tmp/.t3170doc

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

### 2026-08-26 — the baseline was already RED from last session, and I refreshed it by accident

- **What changed:** the verification leg asserting "no `Enforcement baseline CHANGED`"
  failed, and not because of this task — `.claude/settings.json` is untouched here.
  T-3164 registered the `Stop` hook last session and never refreshed the baseline,
  which is L-398 exactly: a legitimate hook edit leaves `fw doctor` FAILing until
  someone bumps the hash, and the FAIL then accumulates silently across sessions.
- **What actually happened:** I ran `fw enforcement baseline --check` expecting a
  dry-run. That flag does not exist, the argument was ignored, and the command
  performed the refresh. The refresh was the correct remedy and the resulting state is
  the intended one — the `Stop` hook is registered, reviewed, and shipped disarmed —
  but it was triggered by a wrong assumption about the interface rather than by a
  decision, and the AC that caught it was one I had written for a different reason.
- **Plan impact:** none to the slice. `.context/project/enforcement-baseline.sha256`
  is part of this commit, attributed to T-3164's registration rather than to anything
  T-3170 changed.
- **Triggered:** `fw enforcement baseline` has no dry-run. A command whose only mode
  is "commit the change" invites exactly this. Not filed as a task — noted here so the
  next person reaching for `--check` finds out from the record instead of from the
  side effect.

### 2026-08-26 — half of this slice was a recorded decision the work list did not know about

- **What changed:** the slice as filed in §15.4 said "wire `session-end.sh`". Reading
  the handler's header before touching it turned up T-1459, an inception that had
  already answered this question — **GO on Option D, reference-only** — with a named
  precondition for reversal: read the G-016 RCA first. G-016 was a handover **commit
  storm**, and the last change to this script cluster was defensive capping, not
  decommissioning. Wiring it would have quietly reversed an operator decision.
- **Plan impact:** the slice split. The `VALID_EVENTS` gap is a defect in our tool —
  it refused an event Claude Code fires, independent of what anyone decides to put on
  it — and shipped. The registration is a decision, stays open, and is now named as
  the operator's in the work list rather than sitting as an unqualified "open".
- **What was learned:** a decision recorded only in a task file and a header comment
  is one edit away from being undone by someone who never reads either. The absence
  is now asserted in `hook_enable_events.bats`, so reversing it fails a test rather
  than passing silently — verified by making the reversal and watching test 5 go red.
- **Triggered:** nothing new. The §15.4 row was written from the substrate outward and
  did not consult the register; that is the same shape as the arc-membership gap found
  at the start of this run, where five tasks were doing arc-012's work from outside it.

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

### 2026-08-26T14:49:39Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3170-arc-012-s4-wire-session-endsh-and-add-se.md
- **Context:** Initial task creation

### 2026-08-26T14:50:24Z — status-update [task-update-agent]
- **Change:** tags: +arc:continuous-run

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d9c0c73c
- **Timestamp:** 2026-08-26T15:12:44Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Per-AC findings:**

- **AC#2 (Agent)** — `session-end.sh` is NOT registered in `.claude/settings.json`; its REFERENCE ONLY
  - **AC-verify-mismatch** (narrow, heuristic) — `path=claude/settings.json in: `session-end.sh` is NOT registered in `.claude/settings.json`; its REFERENCE ONLY`
- **AC#4 (Agent)** — The enforcement baseline is unchanged, because `.claude/settings.json` is not
  - **AC-verify-mismatch** (narrow, heuristic) — `path=claude/settings.json in: The enforcement baseline is unchanged, because `.claude/settings.json` is not`

### 2026-08-26T15:08:42Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
