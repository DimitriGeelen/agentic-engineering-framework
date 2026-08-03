---
id: T-2769
name: "fw --json contaminated by auto-init banner on stdout; read-only status query
  vendors into cwd"
description: >
  Reproduced bare: PROJECT_ROOT=$TD bin/fw orchestrator status --json > out.json exits
  0, and out.json begins 'Setting up agentic governance for...' / 'Vendoring framework
  into project...' before the JSON. Two defects in one reproduction, both onboarding-surface.
  (i) A read-only status query auto-initialises AND vendors the framework into cwd
  as a side effect — the query created a project. (ii) The setup narrative is written
  to stdout (emitter lib/init.sh:93), so any 'fw <cmd> --json' consumer on a fresh
  root gets unparseable stdout while rc stays 0 — a false green at the JSON layer,
  invisible to exit-code checks. Found via T-2766: T-1805's verification fallback
  widened its population to 'pytest -k outcome' across the whole suite, which caught
  tests/unit/test_orchestrator_status_outcomes.py::test_outcomes_json_exposes_aggregation
  and ::test_default_json_does_not_have_outcomes_key failing on json.loads(stdout).
  Those two tests have been red and unattributed because nothing owned that population.

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
created: 2026-08-03T16:43:57Z
last_update: 2026-08-03T16:51:46Z
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
  - ts: '2026-08-03T16:45:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 7
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-03T16:45:10Z'
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

# T-2769: fw --json contaminated by auto-init banner on stdout; read-only status query vendors into cwd

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `fw <cmd> --json` from a non-project directory emits **parseable JSON on stdout**:
      `PROJECT_ROOT=$TD bin/fw orchestrator status --json` in a fresh temp dir pipes
      cleanly into `json.loads` — asserted by reproducing the original failure, not by
      reading the diff
- [x] The auto-init side effect stays **visible on stderr** rather than being silenced —
      writing a project into the caller's cwd must not become invisible while fixing the
      stream (the fix must not trade one blindness for another)
- [x] The two tests the defect was breaking pass:
      `tests/unit/test_orchestrator_status_outcomes.py::test_outcomes_json_exposes_aggregation`
      and `::test_default_json_does_not_have_outcomes_key`
- [x] A regression test pins the contract — stdout of a `--json` command on an
      uninitialised root parses, and the banner appears on stderr — so the next edit to
      the auto-init block cannot silently re-contaminate stdout
- [x] The regression test **fails against the pre-fix code** (mutation-checked), so it is
      known to test the thing rather than to pass vacuously
- [x] The separate design question (should a read-only query auto-init and vendor at all?)
      is filed as its own task rather than decided inside this fix
- [x] The init path change keeps `tests/unit/upgrade_fresh_machine_simulation.bats` green
      (CLAUDE.md §Consumer-Facing Command Hygiene — this edit is on the `fw init` path)

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

# The contract, asserted in both directions plus an anti-vacuity guard.
timeout 300 python3 -m pytest tests/unit/test_fw_json_stdout_purity.py -q

# The two tests the defect was breaking, which had no owner until T-2766.
timeout 300 python3 -m pytest tests/unit/test_orchestrator_status_outcomes.py -q

# The redirect targets the stream the output is actually on, and the form that
# suppressed the wrong one is gone. Structural, because the behavioural tests above
# would also pass if a future edit reached clean stdout by discarding the narration.
grep -q 'do_init "$PWD" --provider claude >&2' bin/fw
! grep -q 'do_init "$PWD" --provider claude 2>/dev/null' bin/fw

# CLAUDE.md §Consumer-Facing Command Hygiene: this edit is on the `fw init` path.
timeout 300 bats tests/unit/upgrade_fresh_machine_simulation.bats

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

**Symptom:** `fw <cmd> --json` run from a directory that is not yet a framework project
returned setup prose ahead of its JSON and exited **0**. Downstream `json.loads` failed at
character 0 while every exit-code check reported success.

**Root cause:** `bin/fw`'s non-TTY auto-init branch ran `do_init … 2>/dev/null` under a
comment reading "silently use defaults". `do_init` writes its progress narrative to
**stdout**. The suppression was applied to the stream the output was not on, so the branch
never achieved the silence it claimed and dumped a multi-line banner into the data
channel. One character of redirect, and the code's own stated contract was the thing that
disagreed with it.

**Why structurally allowed:** three gaps compose.
1. **stdout/stderr discipline is unenforced.** Nothing distinguishes fw's data channel
   from its narration channel; each site decides ad hoc, so a wrong choice is invisible
   until something parses the output.
2. **The failure mode is rc=0.** A contaminated `--json` is indistinguishable from a
   healthy one to any caller that checks exit status — the false-green shape (L-534). Only
   a parse catches it, and the two tests that did parse were themselves unowned.
3. **The only thing running those tests was an unscoped fallback.**
   `test_orchestrator_status_outcomes.py` was red, but the sole executor reaching it was
   T-1805's `|| pytest -k outcome` arm, whose population nobody had scoped. The failures
   were attributed to T-1805, which had not touched that component. A test can be red *and*
   run *and* still have no owner.

**Prevention:** distinct from the fix.
- `tests/unit/test_fw_json_stdout_purity.py` pins the contract in **both** directions —
  banner present on stderr *and* absent from stdout — because either assertion alone is
  also satisfied by discarding the narration, which would clean stdout by making a
  cwd-mutating side effect invisible. A third test asserts auto-init actually fires, so
  the pair cannot pass vacuously if the branch is later removed.
- Two structural lines in `## Verification` pin the redirect form itself, since a future
  edit could reach clean stdout the wrong way and still satisfy the behavioural tests.
- **Not built, and the real generalisation:** nothing stops the next `--json` route from
  printing prose to stdout. A rail that runs each `--json`-capable verb on a scratch root
  and parses stdout would cover the class rather than this instance. Recording it here as
  an open gap rather than implying the class is closed — this fix covers one site.

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

### 2026-08-03T16:43:57Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2769-fw---json-contaminated-by-auto-init-bann.md
- **Context:** Initial task creation

### 2026-08-03T16:48:56Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
