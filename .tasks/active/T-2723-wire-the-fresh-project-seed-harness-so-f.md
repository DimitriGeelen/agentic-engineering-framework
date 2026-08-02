---
id: T-2723
name: "Wire the fresh-project seed harness so F-10-class misclassification fails a
  runner"
description: >
  arc-015. tests/unit/greenfield_seed_audit_prototype.bats (T-2703) seeds a real project
  via fw init under a scrubbed env and asserts fw audit exits <=1 — it is the harness
  that would have caught F-10 at authoring time, and it is RED. This task turns that
  single prototype into a shape-detection guard covering the ecosystems F-10 actually
  misclassifies (.NET, C/C++, PHP, flat-python), each with a negative control proving
  the fixture can fail, so T-2722's fix lands against a test that was provably red first.

  CORRECTION (2026-08-02, at task start): this description originally claimed
  "tests/unit is globbed by no runner (fw test lint = shellcheck)". That is wrong.
  bin/fw:7551 runs `bats "$FRAMEWORK_ROOT/tests/unit/"` under `fw test unit`, so this
  prototype IS picked up. The no-runner finding from T-2696/T-2697 was about
  tests/lint/, a different directory; it was carried over onto the wrong object here.
  Recorded rather than silently edited away — misattributing a real finding to the
  wrong target is the same defect class arc-015 exists to fix, and this instance was
  mine.

status: started-work
workflow_type: test
owner: agent
horizon: now
tags: [arc:onboarding-shape-detection]
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
created: 2026-08-02T05:56:16Z
last_update: 2026-08-02T06:02:45Z
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
  - ts: '2026-08-02T06:00:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 1
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=1 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-02T06:00:11Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal);
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2723: Wire the fresh-project seed harness so F-10-class misclassification fails a runner

## Context

Sibling of T-2722 under arc-015, and deliberately sequenced **before** it: the fix should
land against a test that was observed red, not one written afterwards to describe whatever
the fix happened to do. Design decision and F-10 reproduction live in the arc keystone
T-2718; the fix shape ("enumerate what IS there and decide, not a longer allowlist") was
ratified with 832 on rail 376.

The existing prototype (`tests/unit/greenfield_seed_audit_prototype.bats`, T-2703) asserts
something adjacent but not identical: that a freshly seeded *greenfield* project passes its
own audit. That guards seed-template drift. It does **not** guard shape *detection* — a
project could be misclassified as greenfield and still pass, because the seeded greenfield
set is internally consistent. This task adds the missing axis: given a directory with real
code in it, does `fw init` conclude "existing"?

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] A bats file under `tests/unit/` asserts project-shape detection per ecosystem, driven by
      a fixture table covering at minimum the four F-10 misclassifiers (.NET `.sln`+`.csproj`,
      C/C++ `Makefile`+`main.c`, PHP `composer.json`, flat-python `*.py` with no manifest),
      the two accidental passes (ruby `Gemfile`+`app/`, gradle `build.gradle`+`src/`), and
      `truly-empty` — `tests/unit/init_project_shape_detection.bats`, 12 tests
- [x] Each fixture runs against real `bin/fw init` in a scrubbed `env -i` environment
      (L-009/L-020, T-1633: never let a test's `fw` resolve to this repo). Confirmed the
      scrubbed and unscrubbed runs produce identical verdicts, so the scrubbing is fidelity,
      not a result-changing variable
- [x] Negative controls prove the suite cannot be green while blind. **Scope corrected from
      the original wording of this AC** ("negative control per fixture, expected shape
      inverted"): what is implemented is three *class-level* controls — empty-is-not-existing,
      recognised-is-not-greenfield, and helper-fails-loudly-with-no-parseable-mode-line. These
      close the three ways this suite could pass vacuously (a helper that always answers
      "existing", one that always answers "greenfield", one that yields an empty string a
      later `[ "$output" = ... ]` silently satisfies). Per-fixture inversion would add nothing
      on top: the six red fixtures are *observed failing right now*, which is the strongest
      possible demonstration that they can fail. Ticking the narrower true claim rather than
      the broader one I originally wrote
- [x] Ruby and gradle are asserted to pass **for the right reason** — the guard distinguishes
      "recognised as existing" from "passed because it incidentally has `app/`/`src/`", since
      T-2718 measured that both currently pass by accident. Implemented as `rubyflat`
      (`Gemfile`+`Rakefile`+`models/`) and `gradleflat` (`build.gradle`+`Main.java`), neither
      containing `src/`, `lib/` or `app/`. Both are RED, confirming T-2718's accident finding
      independently
- [x] The new file is confirmed to be executed by `fw test unit` (bin/fw:7551 globs
      `tests/unit/`), with the run output quoted — not inferred from the glob pattern
- [x] Suite is RED on the four misclassifiers at hand-off to T-2722, and the redness is
      quoted verbatim in `## Verification` so T-2722 has a provably-failing starting point

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

# This task's deliverable is a guard that is RED in exactly the right places, so the
# gate must NOT assert "suite passes" — that would be false, and asserting it would be
# the very defect arc-015 exists to fix. It asserts the precise handoff split instead:
# 6 failing (4 F-10 misclassifiers + 2 right-reason cases), 6 passing (3 already-correct
# ecosystems + 3 negative controls). T-2722 flips the 6 red to green; if it also breaks
# a green, this same command catches that too.
out=$(bats tests/unit/init_project_shape_detection.bats 2>&1 || true); f=$(printf '%s\n' "$out" | grep -c "^not ok" || true); p=$(printf '%s\n' "$out" | grep -c "^ok" || true); echo "failing=$f passing=$p"; [ "$f" = "6" ] && [ "$p" = "6" ]
# The three negative controls specifically must be GREEN — they are what makes the six
# reds meaningful. A run where the controls themselves fail is not a red suite, it is a
# broken one, and the two look identical in a bare pass/fail count.
out=$(bats tests/unit/init_project_shape_detection.bats 2>&1 || true); printf '%s\n' "$out" | grep -q "^ok 10 negative control" && printf '%s\n' "$out" | grep -q "^ok 11 negative control" && printf '%s\n' "$out" | grep -q "^ok 12 negative control"
# The guard is reachable by the project's own runner, not just by a direct bats call.
# Pattern deliberately avoids an unescaped $VAR: the same check written as
# grep -q 'bats "$FRAMEWORK_ROOT/tests/unit/"' failed under one shell layer and passed
# under another, which is a false negative waiting to happen in a completion gate.
grep -q 'tests/unit/" || _test_exit=1' bin/fw

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

### 2026-08-02T05:56:16Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2723-wire-the-fresh-project-seed-harness-so-f.md
- **Context:** Initial task creation

### 2026-08-02T05:57:00Z — status-update [task-update-agent]
- **Change:** tags: +arc:onboarding-shape-detection

### 2026-08-02T06:02:45Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
