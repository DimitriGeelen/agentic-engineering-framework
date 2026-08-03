---
id: T-2744
name: "Triage the 25 standing-red tests in tests/unit/ (classify, do not mass-fix)"
description: >
  Triage the 25 standing-red tests in tests/unit/ (classify, do not mass-fix)

status: work-completed
workflow_type: test
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
created: 2026-08-02T23:44:26Z
last_update: 2026-08-03T00:18:10Z
date_finished: 2026-08-03T00:18:10Z
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
  - ts: '2026-08-03T00:00:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 1
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=1 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-03T00:00:12Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2744: Triage the 25 standing-red tests in tests/unit/ (classify, do not mass-fix)

## Context

`tests/unit/` is standing-red (25 failed / 2010 passed / 3 skipped, measured 2026-08-03
under T-2741). Nothing gates a push or a task close on the suite being green, so a guard
going red is indistinguishable from the background red — which is why T-2027's arcs-token
guard sat red for 28 days before T-2741 found it. OBS-136.

**This task classifies. It does not fix.** 25 red tests are not one bug, and the framework's
own sizing rule (one bug = one task) makes a mass-fix commit the wrong shape: it would
destroy per-failure causality and produce a green suite whose greenness nobody could trace
to a cause. The deliverable is a per-failure classification with evidence, plus one
follow-up task per *root cause*. Prior instance of this class: T-2696/T-2697 (orphaned
`tests/lint/` suite, 7 red, one 51 days old).

Report: `docs/reports/T-2744-unit-suite-triage.md`. Census: `docs/reports/T-2744-census.txt`.

## Acceptance Criteria

### Agent
- [x] Census is reproducible and machine-readable: the exact runner command, its measured
      counts, and one failing test nodeid per line are recorded in
      `docs/reports/T-2744-census.txt` — derived from the runner's own output, not
      transcribed from prose.
- [x] Every nodeid in the census appears in the triage report classified as exactly one of
      `genuine-bug` / `stale-test` / `env-dependent`.
- [x] Every classification carries falsifiable evidence: for `genuine-bug`, the
      user-visible defect it implies; for `stale-test`, what changed and when (commit or
      task ID); for `env-dependent`, the specific environmental dependency and what makes
      it absent here.
- [x] Follow-up tasks are filed one per *root cause*, not one per test; each classified
      failure maps to exactly one follow-up task ID, or to an explicit "no action" with a
      stated reason.
- [x] No test file and no non-test source file is modified under this task — triage only.
      Verified mechanically over this task's commits.
- [x] The reason the standing red is *invisible* (no gate consumes the suite's verdict) is
      recorded as a distinct finding with a concrete proposal, and routed to its own
      task/observation rather than fixed here.

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
#
# NOTE: this task does NOT run the unit suite as a verification line. The suite is
# red by construction — that is the subject under study, not a regression to gate on.
# Gating on it here would either force a mass-fix (explicitly out of scope) or
# require a green-washing grep. The census file IS the runner evidence.

# Census exists, is non-empty, and records the runner command it came from.
test -s docs/reports/T-2744-census.txt && grep -q "pytest" docs/reports/T-2744-census.txt

# Every census nodeid is classified in the report, on the same line as its verdict.
python3 -c "import sys,pathlib; c=[l.strip() for l in pathlib.Path('docs/reports/T-2744-census.txt').read_text().split(chr(10)) if l.strip() and '::' in l]; r=pathlib.Path('docs/reports/T-2744-unit-suite-triage.md').read_text().split(chr(10)); bad=[n for n in c if not any(n in ln and any(k in ln for k in ('genuine-bug','stale-test','env-dependent')) for ln in r)]; print('census:', len(c), 'unclassified:', bad); sys.exit(1 if (not c or bad) else 0)"

# Triage only: no test file and no source file touched by this task's commits.
git log --format=%H --grep='T-2744' > /tmp/.t2744c.txt && test -s /tmp/.t2744c.txt && git show --name-only --format= $(tr '\n' ' ' < /tmp/.t2744c.txt) > /tmp/.t2744f.txt && ! grep -Eq '^(tests/|web/|lib/|agents/|bin/|policy/)' /tmp/.t2744f.txt

## RCA

**Symptom:** 24 pytest tests under `tests/unit/` fail. OBS-136 recorded them as a
"standing red" that drowns out new failures — the diagnosis that let T-2027's token guard
sit red for 28 days.

**Root cause:** the standing-red framing was wrong. `tests/unit/` holds 383 `.bats` files
and 153 pytest files, and **every runner that targets the directory runs bats only** —
`fw test unit` (`bin/fw:7551`), `fw test all` (`bin/fw:7663`, whose pytest leg is
`web/test_app.py tests/web/`), and CI (`.github/workflows/test.yml:46`, whose only pytest
leg is `tests/playwright/`). No `pytest.ini` / `pyproject.toml` / `conftest.py` exists to
supply a `testpaths` default either. These ~2035 tests have never been executed as a suite
by any runner, gate, hook, or CI job. They are not ignored; they are **unrun**. The only
executions on record are single-file `## Verification` lines naming the author's own file.

**Why structurally allowed:** the directory is *named* by a command that *appears* to
cover it. `fw test unit` prints `=== Bats Unit Tests ===`, runs `bats tests/unit/`, and
exits honestly about what it ran — but nothing in its output states what it did **not**
run. Coverage was inferred from a matching directory name plus a green exit code. This is
the same shape as T-2696/T-2697 (`tests/lint/`, globbed by no runner, 7 red, one 51 days
old); that fix added `tests/lint/` as leg 2c of `fw test all` and never asked whether any
*other* directory had the same defect. This one is 22× larger and better camouflaged,
because `tests/lint/` had no runner naming it at all while `tests/unit/` has one that does.

Second-order: because no suite verdict exists, a test can only break from its *own*
author's change. Every failure caused by someone else's change is unobservable by
construction — which is exactly what four of the classified failures are (T-2751 pre-T-2281,
T-2752 pre-T-2009, T-2753 audit-log line, T-2754 store growth). T-2754's docstring even
carries the maintenance instruction "Update deliberately when the store grows"; the trigger
to read it never fired.

**Prevention:** T-2745 wires pytest `tests/unit/` into `fw test all` and CI — that is the
structural fix and it is deliberately *not* done here (one bug = one task; and wiring a
runner is a change to `bin/fw`, which this task's own AC forbids). The remaining nine tasks
fix the individual causes. Distinct from the fix itself: this task's report records the
generalised lesson — **a directory named by a runner is not a directory covered by it** —
and the check that would have caught it is asking, for every test-bearing directory, *which
runner collects each file extension present*. `tests/unit/` contains two extensions and one
runner.

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

### 2026-08-02T23:44:26Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2744-triage-the-25-standing-red-tests-in-test.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-86d3a3b3
- **Timestamp:** 2026-08-03T00:18:12Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-03T00:18:10Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
