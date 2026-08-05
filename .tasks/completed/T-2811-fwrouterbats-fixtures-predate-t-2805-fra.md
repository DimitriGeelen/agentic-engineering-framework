---
id: T-2811
name: "fw_router.bats fixtures predate T-2805 FRAMEWORK.md requirement — 7 of 12 tests red"
description: >
  fw_router.bats fixtures predate T-2805 FRAMEWORK.md requirement — 7 of 12 tests red

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
created: 2026-08-05T14:21:42Z
last_update: 2026-08-05T14:25:33Z
date_finished: 2026-08-05T14:25:33Z
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

# T-2811: fw_router.bats fixtures predate T-2805 FRAMEWORK.md requirement — 7 of 12 tests red

## Context

Found while closing T-2810: `tests/unit/fw_router.bats` was 7/12 red, and had been
through the entire T-2793 → T-2809 router rework. `bin/fw-router` is now the **only
machine-wide artifact** in the post-T-2800 architecture — every `fw` call on the host
routes through it — so this is the highest-leverage untested surface in the
onboarding path.

Not a router bug. T-2805 made `.agentic-framework/FRAMEWORK.md` load-bearing
(`bin/fw-router:96`): a vendored copy with an executable `bin/fw` but no
`FRAMEWORK.md` is an interrupted init, and refusing it with 127 is the correct
behaviour that task shipped. The fixtures predate that and build a project shape
that cannot exist, so seven tests were asserting routing outcomes against a refusal.

Two construction sites, one cause — `_stub_cli` (used by 5 of the failures) and two
tests that build their stub inline (routing-loop, exit-code propagation).

**The structural finding is bigger than the fix.** `fw test unit` *does* run this
suite (`bin/fw:7801` — it is not orphaned like the T-2696 `tests/lint/` case), but
the last full run was **189 red of 3764**, and nothing gates on the result: no
pre-push hook, no cron entry, no audit check. Seven reds inside 189 is
indistinguishable from background. Filed as OBS-168; this is the T-2743 "guard red
28 days in a 25-red suite" pattern at 7.5× scale.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `tests/unit/fw_router.bats` is 12/12 green.
- [x] The fix is to the **fixtures**, not to `bin/fw-router`. T-2805 made `.agentic-framework/FRAMEWORK.md` load-bearing (bin/fw-router:96) and refusing an incomplete vendor is correct behaviour; the fixtures build a project shape that cannot exist. `git diff --stat bin/fw-router` is empty at close.
- [x] `_stub_cli` produces a *complete* framework copy — the FRAMEWORK.md it writes sits where the router looks for it, for both layouts the helper is used with (`<proj>/.agentic-framework/bin/fw` and `<repo>/bin/fw`). Verified by both layouts still passing, not by reading the path arithmetic.
- [x] The routing-loop test (test 9) reaches the 126 branch rather than dying at 127 on the incompleteness check — i.e. it tests what its name says.
- [x] T-2805's contract is not silently erased by the fixture change: an incomplete vendored copy still refuses, still pinned by a test. Pinned by `tests/unit/router_refusal_names_one_step_install.bats` test 3 ("incomplete-copy refusal names the one-step installer with the project dir"), which builds the no-FRAMEWORK.md shape deliberately and asserts the 127 refusal.
- [x] Determine whether any runner (`fw test unit`, cron, pre-push) actually executes this suite, and record the answer. ANSWER: it does — `bin/fw:7801` runs bats over tests/unit/. Nothing gates on the exit code, and the last full run was 189 red of 3764. Filed as OBS-168. If nothing runs it, that is the reason 7 red tests survived and it gets its own observation or task — a green fixture in an unrun suite fixes nothing.
- [x] Each repaired test is shown to be non-vacuous: it goes red when the router's routing decision is broken, not merely when the fixture is malformed.

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

out=$(bats tests/unit/fw_router.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
out=$(bats tests/unit/router_refusal_names_one_step_install.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
test -z "$(git diff --name-only bin/fw-router)"

## RCA

**Symptom:** `tests/unit/fw_router.bats` 7/12 red, persisting across every router
change from T-2793 to T-2809.

**Root cause:** T-2805 added a completeness predicate to the router — a vendored
`.agentic-framework` must carry `FRAMEWORK.md`, not just an executable `bin/fw`, or
it is treated as an interrupted init and refused with 127. The fixtures create only
the executable. Every test whose subject was "which CLI gets exec'd" was therefore
answered by a refusal instead.

**Why structurally allowed:** two independent gaps compose.

1. T-2805 changed what counts as a valid project *shape*. Nothing connects a change
   in a predicate to the fixtures that manufacture instances of it. The fixture is
   not a caller of the predicate in any way a dependency tool can see — it is a
   `mkdir` and a `chmod` that happen to produce a shape the predicate used to accept.

2. The redness carried no signal. `fw test unit` runs the suite but nothing gates on
   its exit code, and the last full run was 189 red of 3764. A newly-red suite and a
   long-red suite look identical in that output, so the seven never surfaced as an
   event. This is the load-bearing half: gap 1 makes a break easy, gap 2 makes it
   permanent.

**Prevention:** the fixture fix is only the symptom. The prevention is a rail on gap
2 — OBS-168 proposes a red-count ratchet that fails when reds increase against a
committed baseline, which tolerates the existing 189 while making the 190th an
event. That is deliberately not done here (one bug, one task) but it is the reason
this task exists rather than a silent fixture patch.

Non-vacuity was proven rather than assumed: mutating `bin/fw-router` to be blind to
vendored copies (`if false && [ -x … ]`) turns exactly these 7 tests red and nothing
else. They test routing now, not fixture shape.

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

### 2026-08-05T14:21:42Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2811-fwrouterbats-fixtures-predate-t-2805-fra.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-7f540310
- **Timestamp:** 2026-08-05T14:25:36Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-05T14:25:33Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
