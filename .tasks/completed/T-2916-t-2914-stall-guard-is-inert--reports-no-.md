---
id: T-2916
name: "T-2914 stall guard is inert — reports 'no tasks stalled' while T-2862 sits
  at 60 dispatches / 0 outcomes"
description: >
  T-2914 stall guard is inert — reports 'no tasks stalled' while T-2862 sits at 60
  dispatches / 0 outcomes

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
created: 2026-08-11T11:10:42Z
last_update: 2026-08-11T13:33:25Z
date_finished: 2026-08-11T13:33:25Z
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
  - ts: '2026-08-11T11:15:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-11T11:15:13Z'
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

# T-2916: T-2914 stall guard is inert — reports 'no tasks stalled' while T-2862 sits at 60 dispatches / 0 outcomes

## Context

T-2914 shipped `--stall-after` (default 5) to bound the non-convergence it documented:
T-2420 dispatched 127×, T-2353 94×, T-2862 60× with **zero** rows in
`dispatch-outcomes.jsonl`. T-2914 closed `work-completed` with 6/6 Agent ACs ticked.

Measured 2026-08-11T11:00Z, against the live tree:

```
$ bin/fw resolver stalled
resolver stalled: no tasks stalled at threshold 5
```

T-2862 is `started-work`, `last_update: 2026-08-08T20:30:08Z` (unmoved for 3 days),
**60 dispatches**, **0 outcomes**. It is the exact task the guard was built for, and the
guard says nothing is stalled.

**Why:** `_stalled_task_ids()` (`lib/resolver.py:554`) requires `task_snapshot` on each
dispatch row and *skips rows that lack it* — documented as deliberate fail-open for
pre-T-2914 history. Only rows written after T-2914 shipped (`387a1465b`,
2026-08-11T00:05:07+02:00) carry a snapshot. Exactly **one** T-2862 row postdates it
(00:27:13Z). `len(rows) < stall_after` → 1 < 5 → the task is skipped entirely.

So the guard needs five post-fix dispatches per task before it can evaluate anything — and
it cannot accumulate them, because T-2915's in-flight latch has stopped the loop dispatching
at all. **The guard has never evaluated a single task and currently cannot.**

The fail-open convention is defensible in isolation ("never wrongly exclude on data this
function can't interpret"). What makes it a defect is that its output is
indistinguishable from success: `no tasks stalled at threshold 5` is the same sentence
whether the guard examined 300 tasks and cleared them, or examined none.

Sibling of T-2915 (the latch). Filed separately per §Task Sizing — independent root causes,
independent fixes, and fixing either one alone leaves the loop unguarded.

## Acceptance Criteria

### Agent
- [x] `fw resolver stalled` reports **coverage**, not just verdict — how many tasks were
      evaluated and how many were skipped for want of a snapshot. "Nothing stalled" must
      never again be printable without saying what was looked at
      → `_stall_coverage()` + a `coverage` block in `--json` and a printed line on the
        human path. Live: `evaluated 11/313 task(s) (263 below threshold, 39 not active)`
- [x] The guard evaluates history it *can* interpret rather than requiring a snapshot on
      every row: a task with N pre-snapshot dispatches and an unmoved `last_update` /
      unchanged AC-tick count is assessable, and is assessed
      → snapshot-less rows are kept; degraded path uses subject-match commits +
        `_task_touched_since()`. Results carry `evidence: snapshot|degraded`
- [x] Re-running against the current corpus surfaces T-2862 (60 dispatches, 0 outcomes,
      3 days unmoved) as stalled — the guard's own origin case
      → `T-2862 dispatches=60 outcomes=0 evidence=degraded since=2026-08-10T18:26:49Z`
- [x] Test pins BOTH directions: a genuinely-advancing task with ≥5 dispatches is NOT
      reported stalled, so the fix cannot pass by reporting everything
      → legs 2 and 8 are the negative controls (moved `last_update`; subject-claiming commit)
- [x] Test pins the coverage line specifically — it goes red if the guard silently skips
      its whole input again
      → legs 4, 5, 6 (`below_threshold` accounting, coverage present when nothing stalled,
        coverage on the human path)

**A third defect surfaced while fixing this one, and it was self-inflicted.**
`_git_commit_count_since` grepped the *whole commit message*, so any commit mentioning a
task counted as that task advancing. T-2862 was cleared from the stalled set by commits
`387a1465b` and `e7cce384b` — the T-2914 and T-2916 commits, which cite T-2862 in their
bodies **as the example of a stalled task**. Writing the RCA about the stall was enough to
make the stall undetectable. Now matched on the subject line, where P-002 has a commit
declare what it advances. Legs 7 and 8 pin both directions.

**And a fourth, one layer down:** `_task_touched_since` initially read `last_update` off
`_read_task_meta()`'s top level, where it does not exist — the flattened meta exposes only
`{id,name,status,owner,horizon,workflow_type,ac_block,fm,path}`. The lookup silently
returned `None`, failed open, and reported every task as advanced. Same shape as the
headline defect: a predicate returning "all clear" because it could not read its input.
Caught only because the origin case was checked by hand rather than trusting the verdict.

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

out=$(bats tests/unit/t2916_stall_guard_coverage.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
out=$(bats tests/unit/t2914_resolver_stall_guard.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
out=$(bats tests/unit/t2915_resolver_inflight_expiry.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
python3 -m pytest tests/unit/test_resolver.py tests/unit/test_resolver_run.py -q > /tmp/.t2916-pytest 2>&1 && grep -q passed /tmp/.t2916-pytest
# Coverage must be present in --json whether or not anything is stalled (the whole defect).
bin/fw resolver stalled --json > /tmp/.t2916-stalled 2>&1 && python3 -c "import json;d=json.load(open('/tmp/.t2916-stalled'));c=d['coverage'];assert {'tasks_seen','evaluated','below_threshold','inactive'} <= set(c), c;assert c['tasks_seen'] > 0, 'coverage denominator is zero — guard sees nothing'"
# The origin case must be reachable: a task with >= threshold dispatches and no advancement is findable.
bin/fw resolver stalled --json > /tmp/.t2916-origin 2>&1 && python3 -c "import json;d=json.load(open('/tmp/.t2916-origin'));assert d['coverage']['evaluated'] > 0, 'guard evaluated zero tasks — inert again'"

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

**Symptom:** `fw resolver stalled` reports `no tasks stalled at threshold 5` while the task
the guard was written for sits at 60 dispatches, 0 outcomes, and 3 days without moving.

**Root cause:** the guard's evidence predicate is stricter than its subject matter. It can only
reason about dispatch rows carrying `task_snapshot`, a field introduced by the same commit that
introduced the guard. On day one its evaluable history is empty, and it grows one row per
dispatch per task — so the guard is structurally inert for its first five dispatches of every
task, including every task whose runaway history motivated it.

**Why structurally allowed:** T-2914's acceptance criteria verified that the guard *exists and
runs* — the flag is parsed, the banner prints `stall-after=5`, the verb returns cleanly. None
verified that it *reaches a verdict on real data*. This is precisely the T-2912 class one layer
down: T-2912 was filed because `fw upgrade` verified its pre-write trigger instead of its
post-write effect, and T-2914's own closure repeated the shape — asserting the mechanism was
wired rather than that it fired.

Second contributor: fail-open was chosen to avoid false exclusions, which is right, but it was
implemented as *silence* rather than as *reported abstention*. A guard that abstains on 100% of
its input and prints the same line as a guard that cleared 100% of its input has no observable
difference between working and not existing.

**Prevention:** (a) make abstention visible — every "nothing stalled" carries evaluated/skipped
counts, so inertness is legible at a glance; (b) widen the predicate to interpretable history
(dispatch count + unmoved `last_update` + unchanged AC-tick count) rather than requiring a
field only the guard's own era emits; (c) at author-time, the standing lesson: an AC that
proves a guard *runs* is not an AC that proves it *judges* — pin a real verdict on real data,
in both directions.

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

### 2026-08-11T11:10:42Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2916-t-2914-stall-guard-is-inert--reports-no-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c32a83c7
- **Timestamp:** 2026-08-11T13:33:37Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-11T13:33:25Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
