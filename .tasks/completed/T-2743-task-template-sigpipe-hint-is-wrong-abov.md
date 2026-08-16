---
id: T-2743
name: "task template SIGPIPE hint is wrong above the pipe buffer"
description: >
  task template SIGPIPE hint is wrong above the pipe buffer

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [tests/unit/verification_pipe_buffer.bats]
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
created: 2026-08-02T22:53:18Z
last_update: '2026-08-16T22:25:16Z'
date_finished: 2026-08-02T22:57:33Z
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
bvp_scores_proposed:
  - ts: '2026-08-16T22:25:16Z'
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

# T-2743: task template SIGPIPE hint is wrong above the pipe buffer

## Context

The task template prescribes `out=$(cmd 2>&1); echo "$out" | grep -q PATTERN` as *the*
SIGPIPE-safe form for `## Verification` (L-387), and T-2090 hardened it to single-pipe-only.
Both are right for the captures they were written about, and both are wrong above the pipe
buffer: if the capture exceeds 65,536 bytes and `grep -q` matches early, `echo` blocks on
the full pipe, `grep -q` exits, `echo` takes SIGPIPE, and the pipeline exits 141 under
`pipefail` — reintroducing precisely the failure L-387 exists to prevent.

Measured under T-2741 (OBS-137): a Watchtower page is 146,366 bytes; the line returned
rc=141 on 3/3 runs. Deterministic, not racy. Any Verification line that curls a rendered
page is exposed — Watchtower routes run 50-200KB.

Second, methodological half: the same line returned **0 by hand and 141 under the gate**,
because an interactive shell has no `set -eo pipefail`. Rehearsing a verification line by
running it in the terminal does not rehearse the gate.

## Acceptance Criteria

### Agent
- [x] `.tasks/templates/default.md` states the pipe-buffer limit next to the existing L-387 / T-2090 hints, with the file-redirect form as the remedy for large captures
- [x] T-2090's false premise is corrected at source, not just annotated below — the line asserting "`echo "$out"` is small and immediate" is the belief that makes the idiom look unconditionally safe, and it is gone
- [x] The hint says *why* the redirect form is better beyond SIGPIPE: it keeps the producing command's exit code in the verdict instead of discarding it (the T-2738 concern, one layer down)
- [x] The hint gives the rehearsal command (`bash -c 'set -eo pipefail; <line>'`) and says plainly that running the line by hand does not rehearse the gate
- [x] Checked the greenfield seed templates for a stale copy (the T-2740 two-template-sets trap). They carry **no** hint block at all — `grep -rl SIGPIPE lib/seeds/` is empty — so there is nothing stale to correct. That absence is its own onboarding gap and is filed separately rather than folded in here
- [x] A test pins the mechanism rather than the prose: a >64KB capture piped to an early-matching `grep -q` exits 141 under `pipefail`, and the file-redirect form of the same check exits 0. Synthetic payload, so it holds without a running Watchtower

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
# stdin on. `echo "$out"` is small and immediate; grep scans the whole captured
# string anyway, so the tail-3 was cosmetic. Drop it: `echo "$out" | grep -q PAT`.
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

# The mechanism test. Guarded per T-2738 (bats verdict is `ok N`; a partial
# failure must not pass on the pass-marker alone).
out=$(bats tests/unit/verification_pipe_buffer.bats 2>&1); echo "$out" | grep -q "^ok 1 " && ! echo "$out" | grep -q "^not ok"

# The template carries the correction, and no longer carries the false premise.
grep -q "65536-byte pipe buffer" .tasks/templates/default.md
grep -q "DOES NOT REHEARSE THE GATE" .tasks/templates/default.md
! grep -q "small and immediate" .tasks/templates/default.md

# The greenfield seeds still carry no stale copy of the hint (T-2740 trap).
test -z "$(grep -rl SIGPIPE lib/seeds/ 2>/dev/null)"

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

**Symptom:** a T-2741 verification line curling a Watchtower page returned 0 when run by
hand and 141 at the close gate, blocking completion. Nothing was wrong with the page, the
pattern, or the command.

**Root cause:** the line used the idiom the task template prescribes as SIGPIPE-safe.
That idiom is safe only while the capture fits the 65,536-byte pipe buffer. The page was
146,366 bytes with the match near the top, so `grep -q` exited while `echo` was still
blocked on a full pipe — SIGPIPE, 141 under `pipefail`.

**Why structurally allowed:** the framework taught it. L-387 was written about advisory
tools with small outputs and is correct there; T-2090 then reinforced it with an explicit
premise — "`echo "$out"` is small and immediate" — which is a property of the *examples*
the hint was derived from, not of the idiom. Once written as a general rule it stopped
being reexamined. This is the same shape as T-2738, where the same template taught a
verdict-discarding pattern for test runners: **a hint derived from one class of command,
stated without its precondition, becomes a defect the moment it is applied outside that
class.** Two instances now, one template.

**Prevention:** the precondition is now stated with the hint (below the buffer / above
it), the false premise is deleted rather than annotated, and
`tests/unit/verification_pipe_buffer.bats` pins the mechanism with a synthetic payload so
the threshold is asserted rather than described. The methodological half — that running a
line by hand is not a rehearsal, because an interactive shell has no `pipefail` — is in
the template and pinned by its own test, since that is what let the defect be observed
only at the gate.

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

### 2026-08-02T22:53:18Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2743-task-template-sigpipe-hint-is-wrong-abov.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-853af6d0
- **Timestamp:** 2026-08-02T22:57:35Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-02T22:57:33Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
