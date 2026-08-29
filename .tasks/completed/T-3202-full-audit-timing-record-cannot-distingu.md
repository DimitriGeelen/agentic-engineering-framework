---
id: T-3202
name: "full-audit timing record cannot distinguish an external kill from exhausting
  its own ceiling"
description: >
  The prior record in .context/audits/full-audit-timing.yaml read total_seconds: 900,
  ceiling_seconds: 3000, timed_out: true. Those three cannot all describe one internal
  timeout — a 900s run does not exhaust a 3000s ceiling. Likely an external 'timeout
  900' wrapper killing the run while _audit_write_timing_yaml recorded the CONFIGURED
  AUDIT_TIMEOUT. Consequence: T-3127 AC4 claims a timed-out section is unambiguous
  in the record, but the record is ambiguous about WHICH ceiling killed it, and the
  FAIL message it drives ('TIMED OUT mid-section X at 900s / 3000s ceiling') sends
  a reader to raise a limit that was never the binding constraint. First step is to
  REPRODUCE — the originating command was not captured, so the cause above is inferred,
  not diagnosed. Found while measuring T-3127 AC1 (that run completed cleanly at 1895s/3000s,
  timed_out: false).

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: [T-3127, T-3070]
arc_id: continuous-run
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
created: 2026-08-27T20:13:21Z
last_update: 2026-08-29T09:49:30Z
date_finished: 2026-08-29T09:49:30Z
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
  - ts: '2026-08-27T20:15:09Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=202,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-27T20:15:16Z'
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

# T-3202: full-audit timing record cannot distinguish an external kill from exhausting its own ceiling

## Context

`_audit_write_timing_yaml` wrote `ceiling_seconds: $AUDIT_TIMEOUT` — the *configured*
ceiling — on every timeout kill, and the TERM trap that calls it fires on ANY SIGTERM,
not just the one its own watchdog sends. So a run killed from outside serialised as a
run that exhausted its own budget, and `fw doctor` sent the reader to raise a limit
that was never the binding constraint.

Reproduced before any fix, both arms, real `audit.sh` and real SIGTERM (AC1):

| arm | total_seconds | ceiling_seconds | timed_out | exit |
|-----|---------------|-----------------|-----------|------|
| external `timeout 45`, ceiling 3000 | 45 | 3000 | true | 124 |
| internal watchdog, ceiling 45 | 50 | 45 | true | 124 |

Arm 1 is the originating record's shape (900/3000/true). Arm 2 is the control, and it
supplies the discriminator: the watchdog sleeps `AUDIT_TIMEOUT` before sending TERM and
the trap runs only after the in-flight command returns, so an internal kill records
`total >= ceiling` **always** — it overshot to 50 here. `total < ceiling` therefore
*proves* an external killer. That is a proof, not the "materially below" threshold AC2
anticipated, and it means the obvious `total == ceiling` test would have been wrong.

Both arms also exited **124**, so the exit code cannot separate them either — `timeout`
returns 124 on kill and the internal trap explicitly `exit 124`s.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] AC1 — REPRODUCE FIRST. The cause below is inferred, not diagnosed: the originating
      command was never captured. Run a full audit under an external `timeout N` where
      N < the configured ceiling, and confirm the record lands as
      `total_seconds: ~N / ceiling_seconds: 3000 / timed_out: true`. If it does not
      reproduce, this task is wrong and closes as such — do not proceed to AC2 on the
      strength of the inference.
- [x] AC2 — The record distinguishes the two kills. An externally-killed run and a run
      that genuinely exhausted `AUDIT_TIMEOUT` must not serialise identically. Whatever
      the field is called, `total_seconds` materially below `ceiling_seconds` while
      `timed_out: true` must be self-evidently an external kill in the file itself.
- [x] AC3 — The FAIL message stops misdirecting. `bin/fw` currently renders
      "TIMED OUT mid-section '<s>' at <total>s / <ceiling>s ceiling" and tells the reader
      to raise `FW_AUDIT_FULL_TIMEOUT`. For an external kill that advice is wrong — the
      configured ceiling was never the binding constraint. The message must name the
      constraint that actually fired.
- [x] AC4 — Regression fixture, not the live file (L-599): synthetic records for
      (a) internal timeout, (b) external kill, (c) clean completion, each classified
      distinctly by `lib/audit_timing.py`. The external-kill case is the one that
      currently has no test.
- [x] AC5 — Mutation-tested: collapsing the external-kill branch back into the internal
      one reddens a named test. Without that, AC2 and AC4 could both ship inert.

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

bash -n agents/audit/audit.sh
bash -n bin/fw
python3 -c "import ast; ast.parse(open('lib/audit_timing.py').read())"
bats tests/unit/t3202_audit_kill_source.bats > /tmp/.t3202v.out 2>&1 && [ "$(grep -c '^ok ' /tmp/.t3202v.out)" -eq 18 ] && ! grep -q '^not ok' /tmp/.t3202v.out
bats tests/unit/t3127_audit_timing_headroom.bats > /tmp/.t3127v.out 2>&1 && [ "$(grep -c '^ok ' /tmp/.t3127v.out)" -eq 12 ] && ! grep -q '^not ok' /tmp/.t3127v.out
# The two kills must not classify identically — the whole point of the task.
printf 'last_run:\n  total_seconds: 900\n  ceiling_seconds: 3000\n  timed_out: true\n  killed_in_section: "x"\n' > /tmp/.t3202ext.yaml && python3 lib/audit_timing.py /tmp/.t3202ext.yaml 0.70 > /tmp/.t3202ext.out && grep -q '^KILLED_EXTERNAL|900|3000|x|derived$' /tmp/.t3202ext.out
printf 'last_run:\n  total_seconds: 3000\n  ceiling_seconds: 3000\n  timed_out: true\n  killed_in_section: "x"\n' > /tmp/.t3202int.yaml && python3 lib/audit_timing.py /tmp/.t3202int.yaml 0.70 > /tmp/.t3202int.out && grep -q '^TIMED_OUT|3000|3000|x$' /tmp/.t3202int.out
# The misdirecting advice must be gone from the external arm and kept on the internal one.
grep -q 'will NOT help' bin/fw
grep -q 'kill_source: external' agents/audit/audit.sh

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

**Symptom:** `.context/audits/full-audit-timing.yaml` read `total_seconds: 900 /
ceiling_seconds: 3000 / timed_out: true`, and `fw doctor` rendered it as
"Last full audit TIMED OUT mid-section 'X' at 900s / 3000s ceiling" with the advice
"Raise FW_AUDIT_FULL_TIMEOUT". A 900s run cannot exhaust a 3000s ceiling, and raising
that ceiling could not have changed the outcome.

**Root cause:** the TERM trap is signal-source-blind. It fires on ANY SIGTERM — its own
watchdog, an external `timeout N`, a supervisor, an operator interrupt — and calls
`_audit_write_timing_yaml`, which wrote `ceiling_seconds: $AUDIT_TIMEOUT` unconditionally.
That field named the *configured* ceiling rather than the constraint that actually fired,
so two structurally different events serialised to one identical record. The exit code
did not help either: `timeout` returns 124 on kill and the trap explicitly `exit 124`s.

**Why structurally allowed:** T-3127 AC4 asked that a killed section be *unambiguous in
the record*, and it was satisfied — literally and narrowly. `killed_in_section` answers
**where** the run died; nobody asked **which ceiling** killed it. The regression test
written for that AC used `total_seconds: 600 / ceiling_seconds: 600` — the internal case
only. With just one of the two cases represented in any fixture, no test could reveal
that the two were indistinguishable: the missing case was not failing, it was absent.
Same family as T-3209 (a diagnostic that stated a cause it had not established) — a check
that answers the question *next to* the one the reader is asking, and reads as if it
answered theirs.

**Prevention:** the writer now records `kill_source: internal|external` at the point the
fact is known, so no reader has to re-derive it. `lib/audit_timing.py` emits
`killed_external` as its own status and flags `derived` when it had to infer the value
for a pre-T-3202 record. `fw doctor` gives different advice per arm and explicitly says
raising the timeout will not help on an external kill. 18 tests pin it, including a real
externally-killed `audit.sh` run and a CONTROL asserting the internal arm still *does*
recommend raising the ceiling — that control is what separates "the new arm fires" from
"the advice was deleted everywhere". Five mutations each redden a named set (M1→8,16;
M2→1,5,6; M3→5,6; M4→12,14; M5→5,6).

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

### 2026-08-29 — the discriminator is a proof, not a threshold

- **What changed:** AC2 was written expecting a judgement call — "`total_seconds`
  materially below `ceiling_seconds`". The control arm removed the vagueness. The
  watchdog sleeps `AUDIT_TIMEOUT` before sending TERM and the trap runs only after the
  in-flight command returns, so an internal kill records `total >= ceiling` **always**.
  Measured: ceiling 45 produced total **50**, a 5s overshoot. So `total < ceiling`
  *proves* an external killer, and the intuitive `total == ceiling` test would have been
  wrong on the real data.
- **Plan impact:** no threshold, no warn-fraction, no "materially" anywhere. The writer
  states the fact outright; inference exists only as a fallback for legacy records and is
  labelled `derived` so a reader can tell a stated fact from a reconstructed one.
- **Also learned:** both kills exit **124**, so the exit code is not available as a
  discriminator and nobody should later reach for it. Recorded here because it is the
  obvious next idea and it does not work.
- **Triggered:** nothing filed. The defect was small enough to fix in this task.

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

### 2026-08-27T20:13:21Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3202-full-audit-timing-record-cannot-distingu.md
- **Context:** Initial task creation

### 2026-08-27T20:21:10Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-24a94620
- **Timestamp:** 2026-08-29T09:50:00Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-29T09:49:30Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
