---
id: T-2805
name: "Fresh install: partial vendor makes fw unrecoverable in its own directory"
description: >
  Fresh install: partial vendor makes fw unrecoverable in its own directory

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [bin/fw, bin/fw-router, lib/init.sh, lib/validate-init.sh, tests/unit/fw_init_atomic.bats, tests/unit/fw_vendor_completeness.bats]
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
created: 2026-08-05T06:37:26Z
last_update: 2026-08-05T06:53:31Z
date_finished: 2026-08-05T06:53:31Z
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
  - ts: '2026-08-05T06:45:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-05T06:45:11Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 3
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=3 (body:component-discoverability); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2805: Fresh install: partial vendor makes fw unrecoverable in its own directory

## Context

A directory holding a partially-vendored `.agentic-framework/` cannot be repaired
by the tool that made it. `fw init` there dies "Cannot find framework
installation" and advises *"Run 'fw init' in your project directory"* — the
command that just failed. Only `rm -rf` recovered it.

Reproduced live 2026-08-05 in a scratch HOME, from the operator's field report of
`/opt/2345-test-install`. T-2801 addressed the same class with a
`.fw-init-incomplete` marker, but a marker only protects vendors created *after*
it shipped, and its absence is not evidence of completeness — pre-existing debris
and any crash before the marker write are still fatal.

The observable defect: **the router uses a weaker routability predicate than the
CLI it routes to.** `bin/fw-router:57` accepts `-x .agentic-framework/bin/fw`;
`bin/fw` itself resolves FRAMEWORK_ROOT by `FRAMEWORK.md` (`bin/fw:96,128,155`),
as does install.sh's consumer scan (`install.sh:210`). Bisected: with
`FRAMEWORK.md` absent every `fw` call fails regardless of `VERSION`; adding
`FRAMEWORK.md` alone fixes it. Two implementations of one predicate, disagreeing
— same class as the T-2735/T-2737 fabric-denominator trio.

Compounding it, `do_vendor`'s `includes` array (`bin/fw:332-356`) is copied in
order with `bin` **first** and `FRAMEWORK.md` **eighth of twelve**, so the window
in which a directory looks routable but is not spans essentially the whole vendor.

## Acceptance Criteria

### Agent
- [x] Router requires `FRAMEWORK.md` alongside `-x bin/fw` before routing into a
      vendored `.agentic-framework/`, matching the predicate `bin/fw` and
      `install.sh` already use. An incomplete vendor takes the existing
      `_incomplete_at` path (global fallback), not the exec path.
- [x] `FRAMEWORK.md` is copied **last** in `do_vendor` — after VERSION,
      `.fw-not-a-project`, `.gitignore`, `.upstream` and the `chmod +x` — so its
      presence means every other vendor write finished. It is out of `includes[]`
      entirely rather than reordered within it.
- [x] `fw init` run from **inside** a directory with a partial vendor and no
      marker repairs that directory instead of failing (the operator's exact
      case; live-verified, not asserted from unit tests).
- [x] Non-vacuity: a *complete* vendor still routes to its own CLI
      (`Mode: vendored`), and the framework repo itself still routes to `bin/fw`
      (`Mode: framework-repo`) — the fix does not degrade into "always global".
- [x] Regression test pins all behaviours, is globbed by `bats tests/unit/`
      (`bin/fw:7784`), and was mutation-checked: tests 1/2/5 go red against the
      pre-fix predicate, 3/4/6 stay green (L-526 — a suite that cannot go red
      reports success by silence).
- [x] Fourth defect found during verification and fixed: `do_init` skipped
      re-vendoring on the same marker-only test, and `fw validate-init` had no
      check on the vendored copy at all — so a repair run printed
      "Validation passed: 42/43" over a directory with no FRAMEWORK.md and no
      VERSION. Added `func-vendor`; confirmed it goes red when the sentinel is
      removed and green when restored.

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

out=$(bats tests/unit/fw_vendor_completeness.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
out=$(bats tests/unit/fw_init_atomic.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
out=$(bats tests/unit/upgrade_fresh_machine_simulation.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
bash -n bin/fw && bash -n bin/fw-router && bash -n lib/init.sh && bash -n lib/validate-init.sh
# The router must test the same file bin/fw resolves FRAMEWORK_ROOT by.
grep -q 'agentic-framework/FRAMEWORK.md" \]; then' bin/fw-router
# FRAMEWORK.md out of includes[] and copied after the loop (ordering invariant).
! sed -n '/local includes=(/,/^    )$/p' bin/fw | grep -qE '^[[:space:]]+FRAMEWORK\.md[[:space:]]*$'
grep -q 'cp "$vendor_source/FRAMEWORK.md" "$dest/FRAMEWORK.md"' bin/fw
# init re-vendors on the OBSERVED signal, not only the declared marker.
grep -q '_vendor_incomplete=true' lib/init.sh
# validate-init actually checks the vendored copy (the 42/43 false green).
grep -q 'func-vendor' lib/validate-init.sh

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

**Symptom:** a directory with a partially-vendored `.agentic-framework/` could
not be repaired by `fw init` run inside it. Every `fw` call there died "Cannot
find framework installation", whose own advice — *"Run 'fw init' in your project
directory"* — is the command that had just failed. `rm -rf` was the only exit.

**Root cause:** `bin/fw-router` decided routability with `[ -x
.agentic-framework/bin/fw ]`, a *weaker* predicate than the CLI it routes to.
`bin/fw` resolves FRAMEWORK_ROOT by `FRAMEWORK.md` (`:96,:128,:155`), and
`install.sh:210` scans for the same file. So the router handed control to a CLI
that was about to reject the very directory it was handed. Bisected 2026-08-05:
with `FRAMEWORK.md` absent every call fails regardless of `VERSION`; restoring it
alone is sufficient. Three implementations of one predicate, one of them wrong —
the T-2735/T-2737 fabric-denominator class.

Compounded by ordering: `do_vendor`'s `includes[]` is copied in array order with
`bin` first and `FRAMEWORK.md` eighth of twelve, so the window in which a
directory looked routable but was not spanned nearly the whole vendor.

**Why structurally allowed:** T-2801 saw this class and answered it with a
`.fw-init-incomplete` marker. A marker is a *declared* signal — it can only
describe inits that ran after it shipped, and only if the process survived long
enough to write it. Its **absence was then read as evidence of completeness**,
which it never was. That inference is the actual defect, and it was made
independently in two files: the router, and `do_init`'s re-vendor branch — whose
comment states the correct principle ("`already exists` is not evidence that it
is complete") directly above a test that only consults the marker.

**Fix:** add the *observed* signal next to the declared one. `FRAMEWORK.md` is
what the CLI already resolves by, so testing it makes the router agree with its
own target; and `do_vendor` now writes it last, after every other vendor write,
so its presence means the copy finished. Both signals are kept — the marker still
catches an interrupt after the sentinel lands.

**A fourth defect surfaced during verification, and only because the artefact was
checked instead of the success message.** After the router fix, `fw init` in the
broken directory printed *"Validation passed: 42/43"* — and had vendored nothing.
`.agentic-framework/` still had no `FRAMEWORK.md` and no `VERSION`; the only
reason `fw` ran at all was the router falling back to the global install. 43 green
checks, every one of them about files `init` itself writes, none about the ~90MB
of framework they depend on. The checks were all true and the project was broken.
Fixed in two places: `do_init` re-vendors on the observed signal, and
`validate-init.sh` gained `func-vendor`.

**Prevention:** `tests/unit/fw_vendor_completeness.bats` (6 tests, globbed by
`bats tests/unit/`), mutation-checked — 1/2/5 go red against the pre-fix
predicate while 3/4/6 hold, so the suite is known to be able to fail. Test 6 pins
the ordering invariant structurally rather than by racing a mid-copy kill.
`func-vendor` is the runtime backstop: it fails any init whose vendored copy is
missing `FRAMEWORK.md`, `VERSION`, `bin/fw`, `lib` or `agents`, and was confirmed
to go red on removal and green on restore.

**Generalisation worth carrying:** *absence of a marker is not presence of the
thing the marker describes.* A declared signal can only cover events that
happened after it shipped and completed; pair it with an observed one whenever
the cost of a false "complete" is unrecoverable state.

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

### 2026-08-05T06:37:26Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2805-fresh-install-partial-vendor-makes-fw-un.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-e3e4125c
- **Timestamp:** 2026-08-05T06:54:32Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 8
     - evidence: `! sed -n '/local includes=(/,/^    )$/p' bin/fw | grep -qE '^[[:space:]]+FRAMEWORK\.md[[:space:]]*$'`

### 2026-08-05T06:53:31Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
