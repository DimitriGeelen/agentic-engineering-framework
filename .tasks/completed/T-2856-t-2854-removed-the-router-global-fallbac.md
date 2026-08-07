---
id: T-2856
name: "T-2854 removed the router global fallback but fw_vendor_completeness.bats still
  asserts it — 3 red"
description: >
  T-2854 removed the router global fallback but fw_vendor_completeness.bats still
  asserts it — 3 red

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [bin/fw-router, tests/unit/fw_vendor_completeness.bats]
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
created: 2026-08-07T12:37:27Z
last_update: 2026-08-07T12:59:44Z
date_finished: 2026-08-07T12:59:44Z
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
  - ts: '2026-08-07T12:45:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-07T12:45:11Z'
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

# T-2856: T-2854 removed the router global fallback but fw_vendor_completeness.bats still asserts it — 3 red

## Context

T-2854 removed the router's global-install fallback to complete D-377. Six tests across
two suites encoded the old contract *as their expected outcome* and went red on the same
commit. Found while running a neighbouring suite during T-2849, four commits later.

Scope grew once by one bug, deliberately: making the T-2801 marker test meaningful exposed
that the router's refusal describes only one of the two signals that reach it, so a
marker-triggered refusal reported *"has a bin/fw but no FRAMEWORK.md"* while FRAMEWORK.md
was present. Without fixing that, the marker test could only assert "it refused" — which
is indistinguishable from the sentinel case and therefore not a test of marker precedence
at all.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Attribution established: the failures are shown to be caused by T-2854's removal of
      the router's global fallback, not by T-2849 or by anything pre-existing —
      demonstrated by running the same suite against the pre-T-2854 router
- [x] `tests/unit/fw_vendor_completeness.bats` asserts the **current** contract: an
      incomplete vendor must not capture the router, and the router must refuse with an
      actionable message rather than hand over to a global install
- [x] The T-2805 intent each test was written to protect is preserved, not deleted — the
      partial-vendor-does-not-capture property and the T-2801 marker precedence are still
      asserted, only their expected outcome changes
- [x] `bats tests/unit/fw_vendor_completeness.bats` is green (8/8 — 6 original + 2 added
      for the marker/sentinel diagnosis split, one of which is a negative control)
- [x] `tests/unit/fw_router.bats` — same class, three further tests — asserts the current
      contract and is 13/13 green
- [x] The router's refusal names the signal that actually fired, so marker-triggered and
      sentinel-triggered refusals are distinguishable by test rather than by reading
- [x] Whatever let a committed change turn a suite red without anyone noticing is named in
      the RCA, and the specific gap is filed

**Attribution evidence — same suite, two routers:**

| test | vs pre-T-2854 router | vs current router (before this fix) |
|---|---|---|
| 1 partial vendor does not capture the router | ok | **not ok** |
| 2 refusal names the directory | ok | **not ok** |
| 4 T-2801 marker still wins | ok | **not ok** |
| 3, 5 | ok | ok |

Current router has 0 `_global` references; the pre-T-2854 router has 8.

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
bash -n bin/fw-router
out=$(bats tests/unit/fw_vendor_completeness.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
out=$(bats tests/unit/fw_router.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'

# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

## RCA

**Symptom:** six tests red across `tests/unit/fw_vendor_completeness.bats` (3 of 6) and
`tests/unit/fw_router.bats` (3 of 12), landed and pushed. Plus a second defect surfaced
while fixing them: the router's incomplete-copy refusal stated a cause that could be false.

**Root cause (the red tests):** T-2854 removed the router's global-install fallback,
completing D-377. Six tests observed the property they were protecting *through* that
fallback — "did it hand over to the global?" was the proxy for "did it decline to run the
partial vendor?". When the fallback went away, the proxy went away with it, and the tests
reported failure for a change that was correct.

**Root cause (the false diagnosis):** two distinct signals — a `.fw-init-incomplete`
marker and a missing `FRAMEWORK.md` — were collapsed into one `if` with `||`
(`bin/fw-router:100`), so the branch recorded *that* the copy was incomplete but not
*which* signal fired. The single refusal message described only the sentinel. A
marker-triggered refusal therefore told the operator `.agentic-framework/` "has a bin/fw
but no FRAMEWORK.md" with FRAMEWORK.md sitting right there — a correct refusal with a
false explanation, which sends someone looking for the wrong thing.

**Why structurally allowed:** the suites are *not* orphaned — `fw test unit` globs
`tests/unit/` (`bin/fw:7988`), so a runner exists and would have caught this. Nothing ran
it. T-2854's `## Verification` block contained neither suite, and no gate requires a task
that edits `bin/fw-router` to run the router's own tests. P-011 runs only what the author
writes, so a change can delete a contract and leave its tests asserting the old one
indefinitely; the red surfaces whenever someone next runs the runner for an unrelated
reason. Here that was four commits and one session later, and only because T-2849 touched
a neighbouring vendor suite.

The failure direction matters: a red test is loud *once someone looks*. Nothing looked.
That is the same shape as T-2849's silent excludes — the signal exists and is never read —
rather than the T-2696 shape where no runner globbed the file at all.

**Prevention:** (1) both suites now assert the current contract, each red test rewritten
to observe the property directly (refusal + exit 127) instead of through the removed
fallback; (2) the marker/sentinel split is pinned by a test *and* a negative control, so
making every refusal say "marker" fails; (3) the structural gap — no requirement that a
task touching `bin/fw-router` or `bin/fw` run `fw test unit` in `## Verification` — is
filed separately, since adding that convention plus its enforcement is its own deliverable.

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

### 2026-08-07T12:37:27Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2856-t-2854-removed-the-router-global-fallbac.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-6ade6da1
- **Timestamp:** 2026-08-07T12:59:47Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-07T12:59:44Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
