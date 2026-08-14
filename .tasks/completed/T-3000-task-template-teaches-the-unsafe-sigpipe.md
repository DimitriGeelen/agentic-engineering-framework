---
id: T-3000
name: "task template teaches the unsafe SIGPIPE shape first, corrects it 20 lines
  later"
description: >
  task template teaches the unsafe SIGPIPE shape first, corrects it 20 lines later

status: work-completed
workflow_type: refactor
owner: agent
horizon: null
tags: []
components: [tests/lint/template-sigpipe-hint-ordering.bats]
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
created: 2026-08-14T20:27:45Z
last_update: 2026-08-14T20:33:08Z
date_finished: 2026-08-14T20:33:08Z
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
  - ts: '2026-08-14T20:30:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 3
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=3 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-14T20:30:13Z'
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

# T-3000: task template teaches the unsafe SIGPIPE shape first, corrects it 20 lines later

## Context

`.tasks/templates/default.md` ships a SIGPIPE hint block into the `## Verification`
section of **every** generated task file. It has accreted chronologically — each task
appended its correction below the previous one — so it now reads as a sequence of
"here is the rule / actually that is wrong / actually that is wrong too":

| Line | Says | Task |
|------|------|------|
| 96 | **"Safe pattern: capture first, grep the capture"** → `out=$(cmd); echo "$out" \| grep -q PAT` | L-387 |
| 102 | that form is fine, just drop intermediate stages | T-2090 |
| 108-110 | that same form **"is NOT SIGPIPE-free"** above the 65536-byte pipe buffer | T-2743 |
| 116-122 | the file-redirect form is **"the better default even when size is not a concern"** | T-2743 |

The form an agent copies is the one at line 96: it comes first, it is the only one
labelled *Safe pattern*, and it carries an explicit origin citation (`L-387, captured
4×`). The correction that inverts it sits 20 lines further down, after a hint about a
different thing, and is introduced by a sentence fragment (`AND ONLY WHILE THE CAPTURE
IS SMALL`) that does not read as a retraction of the labelled rule above it.

**This is not hypothetical — it is the T-2996 origin.** My first repair to the seed
assertion adopted the line-96 form verbatim. P-011 refused it with rc=141 against this
repo's 608KB log. The template taught the shape and the gate caught it one layer later;
in a consumer with a shorter history it would not have been caught at all, which is the
same goes-red-later shape as the defect being repaired.

Reported by the 001-CashWeb consumer session, which noted precisely that the earlier
hint "is the one with L-387's authority attached."

**Scope fence:** reorder and re-anchor the existing prose in one file. No new gate, no
detector, no behaviour change to P-011. Every rule currently in the block stays in the
block — this task changes which one leads and where each caveat sits, not what is true.

## Acceptance Criteria

### Agent
- [x] The hint block leads with the file-redirect form (`cmd > /tmp/.out 2>&1 && grep -q PAT /tmp/.out`) as the stated default — the form that is safe at any capture size AND preserves the producing command's exit code
- [x] The capture-then-grep form is retained but demoted to a size-bounded exception, with its 65536-byte caveat adjacent to it rather than 20 lines below
- [x] The phrase "Safe pattern" no longer labels the capture-then-grep form (no label in the block asserts unconditional safety for a conditionally-safe shape)
- [x] Every rule presently in the block still appears: L-387 mechanism, T-2090 no-intermediate-stages, T-2743 pipe-buffer inversion, T-2743 rehearsal-under-pipefail, T-2738 test-runner exit-code guard
- [x] All origin citations (L-387, T-2090, T-2743, T-2738) survive, each attached to the rule it originated
- [x] A test pins the ordering property, so the block cannot re-accrete into "unsafe form first" the next time a correction is appended
- [x] The test is proven non-vacuous: revert the template and watch it go red

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
# Pipefail/SIGPIPE hint (L-387): P-011 runs each command under `set -eo pipefail`.
# `cmd | grep -q PATTERN` exits 141 (SIGPIPE) when grep matches and closes stdin
# while the upstream is still writing — verification then "fails" even though
# the pattern was present. Safe pattern: capture first, grep the capture:
#     out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"
# Or:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
# Origin: L-387, captured 4× (T-1716, T-1838, T-1862, T-1863) before this hint.
#
# Single pipe only — no intermediate tail/awk/sed stages between capture and grep
# (T-2090): `echo "$out" | tail -3 | grep -q PAT` re-introduces the SIGPIPE risk
# the capture step closed off — the middle stage is what `grep -q` slams its
# stdin on. grep scans the whole captured string anyway, so the tail-3 was
# cosmetic. Drop it: `echo "$out" | grep -q PAT`.
#
# AND ONLY WHILE THE CAPTURE IS SMALL (T-2743). The two hints above are correct
# for the captures they were written about, and both invert above the pipe
# buffer. `echo "$out" | grep -q PAT` is NOT SIGPIPE-free — it is SIGPIPE-free
# only while "$out" fits in the 65536-byte pipe buffer. Above that, with an
# early match: echo blocks on the full pipe, grep -q exits, echo takes SIGPIPE,
# pipeline exits 141 under pipefail — the exact failure L-387 exists to prevent.
# Measured: a Watchtower page is 146,366 bytes, rc=141 on 3/3 runs, deterministic
# not racy. Any line that curls a rendered page is exposed (routes run 50-200KB).
# For anything that might be large, redirect to a file:
#     cmd -o /tmp/.out && grep -q "PATTERN" /tmp/.out
#     curl -sf "$(bin/fw watchtower url)/page" -o /tmp/.out && grep -q "PAT" /tmp/.out
# This is the better default even when size is not a concern: `&&` keeps the
# PRODUCING command's exit code in the verdict, where `out=$(cmd)` discards it —
# the T-2738 problem one layer down. A 404 from curl fails the line instead of
# silently producing an empty capture for grep to not-match.
#
# REHEARSING A LINE BY HAND DOES NOT REHEARSE THE GATE (T-2743). Your interactive
# shell has no `set -eo pipefail`. The line above returned 0 when run by hand and
# 141 under P-011, from the same directory, the same second. To rehearse for real:
#     bash -c 'set -eo pipefail; <your verification line>'
#
# BUT NOT for a test runner (T-2738): the capture above discards the command's
# exit code, and `set -e` is suppressed inside the `if` condition the gate runs
# each line in — so in `cmd1; cmd2` only cmd2 is the verdict. For pytest/bats
# that exit code WAS the verdict, and the pass marker you grep instead survives
# a partial failure: a suite printing "3 failed, 9 passed" satisfies
# `grep -q "9 passed"`. Generalising to `grep -qE "[0-9]+ passed"` matches the
# same output. Either keep the exit code:
#     python3 -m pytest <file> -q > /tmp/.out 2>&1 && grep -q passed /tmp/.out
# or add the guard the exit code used to supply:
#     out=$(python3 -m pytest <file> -q 2>&1); echo "$out" | grep -q passed && ! echo "$out" | grep -q failed
#     out=$(bats <file> 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# The close gate refuses the unguarded form. Bypass: FW_ALLOW_UNJUDGED_TEST_RUN=1.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

# Both lines use the file-redirect form this task promotes to the default —
# the block should be able to survive its own advice.
bats tests/lint/template-sigpipe-hint-ordering.bats > /tmp/.t3000.out 2>&1 && grep -q "^ok 5" /tmp/.t3000.out
# The label that made the wrong form authoritative must be gone from the template.
! grep -q "Safe pattern" .tasks/templates/default.md

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

**Symptom:** T-2996's first repair to the onboarding seed assertion used
`out=$(git log --format=%s); echo "$out" | grep -q "T-003"`. P-011 refused the task
with rc=141 against this repo's 608KB log. The line had been copied from the task
template's own hint block, where it is labelled *Safe pattern*.

**Root cause:** the hint block accreted chronologically. L-387 established the
capture-then-grep form and labelled it safe. T-2090 refined it. T-2743 then
discovered the form inverts above the 65536-byte pipe buffer and appended that
finding — 20 lines below the label it retracts, behind an unrelated hint, opening
with a sentence fragment (`AND ONLY WHILE THE CAPTURE IS SMALL`) that reads as a
new hint rather than a retraction. Each edit was individually correct and left the
block collectively misleading, because nobody re-read it top-down afterwards.

**Why structurally allowed:** nothing checks a documentation block for internal
consistency, and the correction pattern the framework rewards — append your finding
with its citation — is exactly the pattern that produced this. The gate that would
have caught it (P-011) fires *after* an agent has already written and shipped the
wrong line, and only where output happens to exceed the buffer. This repo has a
608KB log so it fired; a young consumer would have gone green, and the line would
have flipped red months later with no change to the code it guards. That is the same
goes-red-later shape as the seed defect T-2996 was repairing — the template
reproduced its own bug class one level up.

**Prevention:** `tests/lint/template-sigpipe-hint-ordering.bats` pins the *ordering
and labelling*, not the content: the file-redirect form must precede the bounded
form, no label may assert unconditional safety, and the size bound must sit within
12 lines of the form it qualifies. Appending a future correction to the bottom stays
legal; re-promoting the bounded form or re-labelling it as unconditionally safe goes
red. Two of the five tests instead guard the restructure itself — every rule and
every citation must survive — so compression cannot quietly drop a hard-won finding.
Verified non-vacuous: reverting the template turns tests 1, 2 and 3 red.

**The generalisable point,** and the reason this is filed as a defect rather than
tidying: in a document that agents copy from, *order is semantics*. An appended
correction does not correct anything for a reader who stops at the first labelled
answer. The sibling rule from T-2999 was "a positive control is not a control until
you have watched it fail"; this one is its documentation counterpart — a correction
is not a correction until the thing it corrects stops being the first thing read.

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

### 2026-08-14T20:27:45Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3000-task-template-teaches-the-unsafe-sigpipe.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-2fd6a4cf
- **Timestamp:** 2026-08-14T20:33:10Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-14T20:33:08Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
