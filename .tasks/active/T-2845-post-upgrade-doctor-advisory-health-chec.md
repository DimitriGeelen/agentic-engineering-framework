---
id: T-2845
name: "post-upgrade doctor advisory health-checks the upstream temp clone, not the
  consumer"
description: >
  post-upgrade doctor advisory health-checks the upstream temp clone, not the consumer

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
created: 2026-08-06T23:13:07Z
last_update: '2026-08-06T23:15:10Z'
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
  - ts: '2026-08-06T23:15:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-06T23:15:10Z'
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

# T-2845: post-upgrade doctor advisory health-checks the upstream temp clone, not the consumer

## Context

`fw upgrade` ends with a post-upgrade health check (T-2094 F10,
`lib/upgrade.sh:_t2094_emit_doctor_advisory`). It runs:

```bash
_doctor_out=$(PROJECT_ROOT="$target_dir" "$FRAMEWORK_ROOT/bin/fw" doctor 2>&1)
```

During `fw upgrade`, `FRAMEWORK_ROOT` is the **temporary upstream clone**
(`/tmp/fw-upstream-XXXXXX/fw`), not the consumer's vendored copy. So the check
that exists to answer *"is this consumer healthy after upgrading?"* runs the
upstream's fw and evaluates the consumer through it. The just-upgraded
`.agentic-framework/` — the thing the operator will actually run tomorrow — is
never exercised.

Doctor states the problem in its own output and it has been read as a consumer
fault rather than a harness one. Live, from a real `fw upgrade`:

```
Post-upgrade health check (advisory):
  WARN  [host] Active mode: global (/tmp/fw-upstream-9eTIsn/fw) — vendored copy
        exists at <project>/.agentic-framework but was not selected
```

`Active mode: global` is the tell. A vendored consumer must report
`Active mode: vendored`; the advisory has never once reported that for a vendored
project, because it cannot.

Consequences beyond the misleading WARN: mode-dependent checks (vendored-path
resolution, the shim-vs-real-CLI check, framework-path reconciliation) are all
evaluated against the wrong root, so a genuinely broken vendored copy would pass
the advisory. The advisory's PASS carries less information than it appears to.

Same family as T-2843/T-2844 (day-zero WARNs that were artefacts of the checker,
not the project) but a distinct failure: this one is **wrong-object** — the check
is correct and runs against something other than its subject.

Found while verifying T-2839 live on a consumer with a local-path upstream.

## Acceptance Criteria

### Agent
- [x] The advisory invokes the consumer's own `.agentic-framework/bin/fw` when that exists
- [x] `FRAMEWORK_ROOT` is scoped to match the chosen binary (added mid-task — see Decisions)
- [x] Advisory output for a vendored consumer reports `Active mode: vendored`
- [x] Advisory output no longer contains "vendored copy exists … but was not selected"
- [x] Falls back to `$FRAMEWORK_ROOT/bin/fw` when the consumer has no vendored copy (shared-tooling / global consumers keep working)
- [x] Regression test committed covering both the vendored and no-vendored-copy cases, green

**Live evidence** — real `fw upgrade` on a consumer with a local-path upstream:

Before:
```
  WARN  [host] Active mode: global (/tmp/fw-upstream-r73EGA/fw) — vendored copy
        exists at <project>/.agentic-framework but was not selected
```
After:
```
  OK  Active mode: vendored (<project>/.agentic-framework)
  Advisory: doctor PASS (exit 0).
```

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

out=$(bats tests/unit/t2845_upgrade_doctor_advisory_target.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'

## RCA

**Symptom:** Every `fw upgrade` of a vendored consumer ended with
`WARN [host] Active mode: global (/tmp/fw-upstream-XXXXXX/fw) — vendored copy
exists at <project>/.agentic-framework but was not selected`.

**Root cause:** `_t2094_emit_doctor_advisory` invoked `$FRAMEWORK_ROOT/bin/fw`,
and during upgrade `FRAMEWORK_ROOT` is the temporary upstream clone. The health
check ran the upstream's fw pointed at the consumer's directory, so the vendored
copy the operator actually runs was never exercised.

**Second root cause, found only by live verification:** switching the binary was
not sufficient. `fw` honours an inherited `FRAMEWORK_ROOT` over its own location,
and T-2099's fork-bomb fix exports it scoped to the clone. Invoking the
consumer's binary under that export put it straight back into global mode against
the clone — live output byte-identical to no fix at all, while the unit tests
stayed green because the stubs ignored the environment. **Which binary runs** and
**which framework it believes it is** are two independent channels; changing one
without the other changes nothing observable.

**Why structurally allowed:** doctor reported the anomaly in plain language in
every upgrade's output. It read as a finding *about the consumer* rather than
about the harness that produced it, because that is the only voice doctor has —
it cannot say "I am being run wrong". The advisory was added (T-2094 F10) as a
convenience at the end of a long command where output is skimmed, and its verdict
line (`Advisory: doctor PASS`) was accurate about the run it actually performed.

**Prevention:** `tests/unit/t2845_upgrade_doctor_advisory_target.bats` makes the
two candidate binaries distinguishable by marker and asserts both which one ran
and which `FRAMEWORK_ROOT` it received. Negative control performed: tests go red
against the pre-fix line. The env-parity test exists specifically because the
first fix passed the binary-only tests while changing nothing live.

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

### 2026-08-07 — the first fix was incomplete and its tests could not tell

- **Chose:** Scope `FRAMEWORK_ROOT` to the chosen binary, and make the test stubs
  echo the `FRAMEWORK_ROOT` they receive.
- **Why:** The first commit switched only which `fw` was invoked. All four tests
  passed, the negative control went red on the old line, and live behaviour was
  completely unchanged — because `fw` prefers an inherited `FRAMEWORK_ROOT` to its
  own location, and T-2099's fork-bomb scoping had it exported at the temp clone.
  The tests could not detect this because the stubs printed a fixed marker and
  ignored the environment, so they answered "which binary ran?" when the live
  behaviour depended on "which binary ran, **and** what did it think it was".
- **Rejected — unset FRAMEWORK_ROOT and let fw derive it:** would work for the
  vendored case but silently changes resolution for global/shared-tooling
  consumers, where the export is load-bearing. Setting it explicitly keeps both
  paths deliberate.
- **Rejected — asserting on doctor's own output instead of stub markers:** would
  couple the test to doctor's wording and, worse, would have passed against either
  binary in the fallback case. The marker approach asserts the thing that is
  actually wrong.
- **Kept on the record:** the intermediate commit is in history rather than
  squashed. A fix that passes its tests and changes nothing live is the exact
  shape worth being able to point at later.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-08-06T23:13:07Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2845-post-upgrade-doctor-advisory-health-chec.md
- **Context:** Initial task creation
