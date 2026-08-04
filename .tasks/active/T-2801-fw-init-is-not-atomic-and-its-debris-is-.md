---
id: T-2801
name: "fw init is not atomic and its debris is not fw-recoverable. do_init vendors
  .agentic-framework/ BEFORE writing .framework.yaml, so any interruption (timeout,
  Ctrl-C, error) leaves a directory with .agentic-framework/ present and .framework.yaml
  absent. In that state every fw verb fails 'Cannot find framework installation' --
  including fw init itself -- so the tool cannot repair or re-init what it created;
  only manual rm. Hit live 2026-08-04 in /opt/2345-test-install (via the T-2798 --help
  auto-init bug) and reproduced here exactly by killing a run at 12s. Fix direction:
  write .framework.yaml first (or a .fw-init-incomplete sentinel), and make fw init
  tolerate/clean a partial vendor. Sibling of T-2726/T-2727 init-ordering family (validation
  ran 114 lines BEFORE seeding what it validates)."
description: >
  Promoted from observation OBS-157

status: started-work
workflow_type: build
owner: human
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
created: 2026-08-04T20:54:04Z
last_update: 2026-08-04T21:44:33Z
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
  - ts: '2026-08-04T21:00:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 7
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-04T21:00:14Z'
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

# T-2801: fw init is not atomic and its debris is not fw-recoverable. do_init vendors .agentic-framework/ BEFORE writing .framework.yaml, so any interruption (timeout, Ctrl-C, error) leaves a directory with .agentic-framework/ present and .framework.yaml absent. In that state every fw verb fails 'Cannot find framework installation' -- including fw init itself -- so the tool cannot repair or re-init what it created; only manual rm. Hit live 2026-08-04 in /opt/2345-test-install (via the T-2798 --help auto-init bug) and reproduced here exactly by killing a run at 12s. Fix direction: write .framework.yaml first (or a .fw-init-incomplete sentinel), and make fw init tolerate/clean a partial vendor. Sibling of T-2726/T-2727 init-ordering family (validation ran 114 lines BEFORE seeding what it validates).

## Context

`do_init` vendors `.agentic-framework/` at `lib/init.sh:129-135` and writes
`.framework.yaml` at `:251` — ~120 lines and one ~90 MB copy apart. Interrupt
anywhere between and the directory is left with a partial vendor and no project
config. Hit live 2026-08-04 in `/opt/2345-test-install` via the T-2798 `--help`
auto-init bug, and reproduced here by killing a run at 12s (OBS-157).

The state is not just broken, it is **self-sealing**:

- `bin/fw-router:56` routes on `[ -x "$_d/.agentic-framework/bin/fw" ]` alone. A
  partial vendor that got as far as `bin/fw` captures the router.
- The captured CLI resolves `FRAMEWORK_ROOT` relative to its own location — the
  incomplete vendor — and fails `Cannot find framework installation` (`bin/fw:706`).
- `fw init` is therefore unavailable *in the directory `fw init` created*, and
  `lib/init.sh:133` would `SKIP  .agentic-framework/ already exists` even if it ran.

Only `rm -rf` recovers it, which a new user has no reason to know.

Also a **prerequisite for the T-2800 build slice**, which states atomicity as a
requirement: an interruption must leave either nothing or a working project.
Sibling of the T-2726/T-2727 init-ordering family.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `fw init` marks the target incomplete **before** it writes anything, and
      clears the mark only after its last step — so the mark's presence is exactly
      "an init started here and did not finish"
- [x] Re-running `fw init` on interrupted debris **recovers** it (re-vendors and
      completes) instead of `SKIP  .agentic-framework/ already exists`
- [x] The router refuses to route into a vendor marked incomplete, and says what
      the state is and how to recover — rather than exec'ing a broken CLI
- [x] A regression test reproduces the interrupted state and asserts recovery
      end-to-end (not just that the sentinel file exists)
- [x] Non-vacuity: `fw init` on a clean directory still succeeds and leaves **no**
      sentinel behind

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

out=$(bats tests/unit/fw_init_atomic.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# The router change touches the resolution order every fw call goes through.
out=$(bats tests/unit/fw_router.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
out=$(bats tests/unit/lib_init.bats tests/unit/init_validation_ordering.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
bash -n lib/init.sh && bash -n bin/fw-router
# Self-vendor parity: both changed files ship to consumers.
out=$(bin/fw doctor 2>&1); ! echo "$out" | grep -q 'self-vendor drift'

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

## RCA

**Symptom.** An `fw init` interrupted mid-run leaves a directory that every `fw`
verb refuses — `Cannot find framework installation` — including `fw init` itself.
The tool cannot repair what it created; only `rm -rf` recovers. Hit live
2026-08-04 in `/opt/2345-test-install`, and reproduced here by killing a run at
1.2s (marker present, `.framework.yaml` absent, `.agentic-framework/bin/fw`
executable).

**Root cause.** Two independent decisions that are each locally reasonable and
jointly produce a trap:

1. `do_vendor`'s include list (`bin/fw:332`) copies **`bin` first** — sensible,
   it is the smallest and most important directory — so the vendored CLI appears
   within about a second and the rest of the framework arrives over the following
   seconds.
2. `bin/fw-router:56` treated `[ -x <dir>/.agentic-framework/bin/fw ]` as
   sufficient evidence of a vendored project — sensible, that file *is* the thing
   it needs to exec.

Together: for essentially the whole duration of an init, the directory satisfies
the router's predicate while not satisfying the CLI's own `resolve_framework`.
The router hands over to a CLI that cannot find itself.

**Why structurally allowed.** Nothing distinguished *in progress* from *finished*.
`.framework.yaml` is the completion marker in practice, but it is written ~120
lines after the vendor call, and its absence is indistinguishable from "this was
never a project" — which is why the error message says "cannot find" rather than
"did not finish". The failure had no vocabulary for the state it was in, so it
reported a different state, and the reported state's remedy (install the
framework) was one the user had already performed.

This is the T-2726/T-2727 init-ordering family again — there, validation ran 114
lines before the artifact it validated existed. Same shape: a step that reads
state assumes an ordering the writer never guaranteed.

**Prevention.** An explicit marker (`.fw-init-incomplete`) written before the
first mutation and removed after the last, so partial states are *nameable*
regardless of where the interruption lands — not inferred from the absence of
some file that happens to be written late. The router refuses to route into a
marked vendor and says which state it is in; `do_init` treats the marker as
authorisation to re-vendor over the partial copy rather than `SKIP`.

Pinned by `tests/unit/fw_init_atomic.bats`, whose fourth test kills a real init
and recovers it end-to-end. Tests 2 and 5 are the non-vacuity pair — a router
that refused everything, or an init that never wrote the marker, would otherwise
both read as green.

**Residual.** The marker is a file, so `rm -rf` on the project root during init
still leaves nothing to recover from — which is the correct outcome. A crash
between `mkdir .agentic-framework` and the marker write is not possible: the
marker is written first.

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

### 2026-08-04T20:54:04Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2801-fw-init-is-not-atomic-and-its-debris-is-.md
- **Context:** Initial task creation

### 2026-08-04T21:44:33Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
