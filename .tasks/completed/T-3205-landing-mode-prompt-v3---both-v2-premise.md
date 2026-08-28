---
id: T-3205
name: "landing-mode prompt v3 - both v2 premises re-measured, one now false"
description: >
  landing-mode prompt v3 - both v2 premises re-measured, one now false

status: work-completed
workflow_type: refactor
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
created: 2026-08-28T12:55:14Z
last_update: 2026-08-28T12:59:40Z
date_finished: 2026-08-28T12:59:40Z
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
---

# T-3205: landing-mode prompt v3 - both v2 premises re-measured, one now false

## Context

`policy/prompts/landing-mode.md` (v2, T-3201) carries a section titled
*"Two premises in the directive that do not currently hold"*, with the standing
instruction: *"If either premise changes, this section is what should be deleted
first."* Both were re-measured at the start of the third landing-mode run,
2026-08-28. One holds; one is now decisively false and has been misleading the
run that reads it.

| v2 premise | re-measured 2026-08-28 | verdict |
|---|---|---|
| `fw bvp --quadrant hv-hc` / `hv-lc` return nothing | both still return *"No tasks have `bvp_scores:` set yet"* | **holds** |
| *"There is nobody to talk to"* on the chat arc | 7 unread; offset 689 is a substantive, addressed, three-part message from 832-Workflow-designer that produced a real finding this run | **false** |

The second premise is not merely stale, it is **actively costly**: it instructs
the agent to *"report the absence rather than manufacturing chatter"*, which reads
as licence to skip the inbox. The v3 run found a peer's generalised defect class
waiting at offset 689 (*a guard that reimplements the code it guards cannot detect
that code being fixed*), and that finding directly shaped T-3204's mutation step.
An agent that had trusted the premise would have skipped it.

The v2 file also predates two things worth carrying forward: the filing-budget
rule was never tested against a run that filed **zero** tasks, and nothing in the
prompt tells the agent what to do when a task's own premise collapses mid-flight —
which is what happened to T-3204 this run.

## Acceptance Criteria

### Agent
- [x] Both premises re-measured and the results written into the file, with the
      command and date, not summarised from memory. A premise section that
      asserts a state nobody re-checked is the failure mode this task is fixing.
- [x] The false premise is removed as the file itself instructs, and replaced by
      what is now true — including the fact that the inbox produced a finding, so
      a future reader knows why the instruction changed.
- [x] The surviving premise (dead BVP quadrants) is kept, with its re-measurement
      date, so it is visibly checked rather than merely inherited.
- [x] §The Prompt gains a rule for the premise-collapse case: a task whose own
      framing fails under checking is narrowed and the retraction recorded, not
      quietly re-scoped or pushed through. T-3204 is the worked example.
- [x] The v1→v2→v3 provenance stays legible: a reader can see what each revision
      learned and from which run, rather than finding a file that has always
      said what it currently says.
- [x] Verified by re-reading the rendered file end to end — the prompt is
      **pasted by a human**, so a broken §The Prompt block is a live defect, not
      a formatting nit.

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

test -f policy/prompts/landing-mode.md
grep -q 'prompt (v3)' policy/prompts/landing-mode.md
grep -q 'Premises — re-measured 2026-08-28' policy/prompts/landing-mode.md
grep -q 'DELETED — this was false' policy/prompts/landing-mode.md
grep -q 'STILL DEAD' policy/prompts/landing-mode.md
grep -q 'If a task.s own premise collapses' policy/prompts/landing-mode.md
grep -q 'A mutation that reddens nothing is itself' policy/prompts/landing-mode.md
awk '/^## The Prompt/{f=1;next} /^---$/{if(f)exit 0} f&&NF&&!/^>/{exit 1}' policy/prompts/landing-mode.md
grep -c '^> ' policy/prompts/landing-mode.md > /tmp/.t3205a && test "$(cat /tmp/.t3205a)" -ge 30
if grep -q 'nobody to talk to\*\*' policy/prompts/landing-mode.md; then exit 1; fi

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

### 2026-08-28 — delete the false premise rather than soften it

- **Chose:** remove the "nobody to talk to" premise outright, strike it through in
  place, and say what replaced it and why.
- **Why:** the file's own instruction was *"if either premise changes, this section
  is what should be deleted first"*. Softening it to "there may be little traffic"
  would preserve the reading that licensed skipping the inbox, which is the actual
  cost — the run that checked found a peer finding at offset 689 that shaped the
  other task landed this session.
- **Rejected:** deleting the premise section wholesale. The surviving premise (dead
  BVP quadrants) is still true and still needs stating; a reader who finds no
  premise section will re-derive the quadrant dead-end from scratch every run.

### 2026-08-28 — the blockquote check was inert, caught by mutation not review

- **Chose:** drop `END{exit 0}` from the awk that verifies every line of §The Prompt
  is blockquoted.
- **Why:** in awk, `exit 1` transfers to the `END` block, and `END{exit 0}` then
  overwrites the status. Mutation M1 — inject an unquoted line into §The Prompt —
  left the check green. It was inert for precisely the case it existed to catch,
  on a block whose whole purpose is to be pasted verbatim by a human.
- **Rejected:** trusting the check because it passed on the clean file. "Passes on
  good input" and "asserts nothing" are indistinguishable without the paired
  broken-input run — the same shape as T-3199's inert `!` assertions and T-3204's
  M3/M4. Third and fourth instance this session, three different mechanisms.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-08-28T12:55:14Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3205-landing-mode-prompt-v3---both-v2-premise.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d9724fe6
- **Timestamp:** 2026-08-28T12:59:43Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-28T12:59:40Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
