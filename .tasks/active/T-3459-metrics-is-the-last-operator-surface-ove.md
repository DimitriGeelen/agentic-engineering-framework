---
id: T-3459
name: "/metrics is the last operator surface over the smoke probe 5s bar at 4.68s
  — the YAML loader fix moved it from 6.25s but its hotspot is elsewhere"
description: >
  /metrics is the last operator surface over the smoke probe 5s bar at 4.68s — the
  YAML loader fix moved it from 6.25s but its hotspot is elsewhere

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
created: 2026-09-25T07:54:50Z
last_update: 2026-09-25T08:32:24Z
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
  - ts: '2026-09-25T08:00:14Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=285,acs=8)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-25T08:00:39Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3459: /metrics is the last operator surface over the smoke probe 5s bar at 4.68s — the YAML loader fix moved it from 6.25s but its hotspot is elsewhere

## Context

**UNPARKED and fixed.** The parking note below is kept verbatim as the record of where this stood; the resolution is in `## Resolution` at the end.

~~PARKED on its stated goal, with a real fix banked on the way.~~ `/metrics` is not
under the 5 s bar. AC 2 said park rather than sprawl if the cost was not one fixable
call, and that is what happened — so this is the AC firing as designed, not a shortfall
slipped past it.

### What /metrics actually pays for (AC 1)

Self-time profile, cross-checked against an unprofiled warm request (3.55-4.01 s) so the
T-3458 profiler-distortion trap is not re-entered:

```
ncalls  tottime  cumtime  function
  3929    1.555    6.193  yaml/constructor.py:get_single_data
414301    0.906    2.242  yaml/constructor.py:construct_object
414301    0.701    1.147  yaml/resolver.py:resolve
```

**3929 YAML documents parsed per request.** Source: `web/blueprints/metrics.py:48`,
`for f in d.glob("T-*.md")` — it parses the frontmatter of every task file in the corpus,
active and completed, on every hit, with its own uncached loop.

Note where the time sits: `constructor.py`, which is **Python even under `CSafeLoader`**
(the C loader accelerates the scanner/parser, not the constructor). T-3458's 12× already
did everything it can do here. The remaining cost is structural — parsing 3929 documents
per request — and no parser choice fixes that.

### Why it is parked rather than fixed

The fix is to stop re-parsing and read `get_all_task_metadata()`, which already maintains
a 30 s cache of exactly this data. That is not a one-line change: `/metrics` computes its
own aggregates from its own loop, so re-pointing it risks the numbers on the page moving.
AC 4 forbids exactly that, and "the metrics page now reports different metrics" is a worse
outcome than a slow metrics page. It needs a careful, per-aggregate comparison, which is
its own task.

**What it would take:** map each aggregate `metrics.py` computes from its loop onto the
cached metadata, prove equality per aggregate against the live corpus, then swap. Bounded,
but not safely doable inside this task's box.

### What was found and fixed on the way (a real bug, kept)

`get_episodic_tags()` shared one timestamp with `get_all_task_metadata()`, and that single
`ts` was wrong in **both** directions at once:

- `get_episodic_tags()` stored its result but **never stamped** `ts` — so unless the other
  function happened to have run inside the TTL, the freshness check failed and the whole
  `.context/episodic/` corpus was re-parsed on the very next request. A cache that is
  populated and still never reads as valid.
- and when `get_all_task_metadata()` **did** stamp `ts`, a `tags` computed arbitrarily long
  ago began reading as fresh, with nothing to recompute it. Stale data served for as long
  as the other function kept being called.

One timestamp for two independently-populated entries cannot be right: stamped by both,
each makes the other look fresh; stamped by one, the other never caches. Both halves were
live. Fixed by giving the entry its own `tags_ts`, with 7 tests pinning both directions —
including the leg that serves a sentinel dict and asserts it is NOT returned after the
sibling stamp is refreshed.

This did not measurably move `/metrics` (3.7-4.3 s before and after) because `/metrics`
never called `get_episodic_tags()` — it was the dashboard path that benefited. Stated
plainly rather than claimed as this task's win.

### Live numbers, for the record

| endpoint | before this run | now |
|---|---|---|
| `/` | 9.45 s / 18.45 s | **0.54-0.84 s** (T-3458) |
| `/metrics` | 6.25 s | 3.7-4.3 s — **still over the bar** |

`/`'s improvement is T-3458's, not this task's. One 3.54 s outlier was seen on `/` during
steady-state sampling; the unexplained variance noted in T-3458 is still unexplained.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] **The hotspot is named from a self-time profile, and the profiler's own distortion
      is accounted for.** T-3458 learned this the hard way: cProfile overstated the YAML
      parser's share roughly fivefold because its per-call overhead lands hardest on
      function-call-heavy pure-Python code. Any attribution here is cross-checked against
      an unprofiled wall-clock before it is believed.
- [x] **Hard time-box, honoured.** If the cost is not localised to one fixable call within
      this investigation, record the measurement, name what it would take, and **park**.
      This is the last endpoint over the 5 s bar, not a mandate to optimise Watchtower.
- [x] **If fixed, measured by live A/B with the same restart on both sides** — the only
      method that survived contact with reality in T-3458. In-process warm timings and
      naive before/after both lied there; page-cache state and profiler overhead each
      produced a confident wrong answer.
- [x] **Nothing the page reports changes**, shown by byte-identity or with the difference
      named explicitly.
- [x] **A regression guard if code changed**, pinning the property rather than a duration
      (T-3326). `TEST_TEMP_DIR` in setup; no bare `! grep -q`.
- [x] Vendored copies synced; `bin/fw vendor self --check` clean; if `web/` changed,
      `bin/fw watchtower restart` and `bin/fw watchtower current` (G-104).

### Human

- [ ] [REVIEW] The metrics page still shows the same numbers, and now arrives quickly

  This cached an existing computation rather than changing it, and I checked that
  mechanically: the rendered page before and after differs by **exactly one line**, the
  per-request CSRF token. Every metric, count, commit row and stale-task entry is
  byte-identical. What a diff cannot tell you is whether the numbers were right in the
  first place, or whether a page that can now be up to 30 seconds stale bothers you.

  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && bin/fw watchtower url` — open the URL
     it prints, then `/metrics` (currently http://192.168.10.107:3002/metrics).
  2. Look at the four headline figures — task counts, traceability %, description
     quality %, AC coverage % — and the stale-task list.
  3. Reload once and note how long the second load takes.

  **Expected:** the same figures you would have seen before, and the second load arriving
  in well under a second. The *first* load after a Watchtower restart still takes ~3.8 s
  — the cache starts empty — so a slow first hit is expected, not a failure.

  **If not:** a figure that reads 0 or is obviously wrong is the signal that matters. Say
  which one. The change is a cache around an untouched function, so a wrong number would
  mean the caching is serving something it should not, and it gets reverted rather than
  tuned.

  **The one judgement I cannot make for you:** the page can now lag reality by up to 30 s
  (the same window `shared.py` already applies to task metadata). For a dashboard that
  seemed clearly right. If you use `/metrics` to confirm something you just did landed,
  say so and the TTL should come down or gain an explicit refresh.

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
# ── Mutable-corpus anchor (T-3326) ────────────────────────────────────────────
# Do NOT anchor a verification line (or a unit test it runs) to MUTABLE corpus
# state — an exact live count, or a grep of live `fw audit`/`fw doctor` output
# for a specific corpus entity (a named arc, a task count, a census number).
# The corpus moves under the check, and the line rots: it goes red (or vanishes
# its pattern) for reasons unrelated to the code under test, blocking closes.
# Pin the INVARIANT (categories sum, count > 0, property holds) or run the code
# against a COMMITTED FIXTURE — never the live count or a live-audit line.
# Origin: T-2969 line grepping live audit for one arc's status; T-2871's census
# test pinning exact live counts (56→74 files) — both blocked closes (OBS-377).
#
# ── Pipefail/SIGPIPE: grepping a command's output (L-387, T-2090, T-2743, T-2738) ──
#
# THE DEFAULT — redirect to a file, then grep the file:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
#     curl -sf "$(bin/fw watchtower url)/page" -o /tmp/.out && grep -q "PAT" /tmp/.out
# Correct at any output size, and `&&` keeps the PRODUCING command's exit code in
# the verdict. Reach for this first; the alternative below is the special case.
#
# Why not `cmd | grep -q PAT` (L-387): P-011 runs each line with PIPEFAIL LIVE
# (errexit is not — see below). When grep matches it exits and closes stdin while cmd is still
# writing, cmd takes SIGPIPE, the pipeline exits 141 — verification "fails" with
# the pattern present. Captured 4× (T-1716, T-1838, T-1862, T-1863).
#
# THE EXCEPTION — capture first, grep the capture:
#     out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"
# Valid ONLY while "$out" fits the 65536-byte pipe buffer, and it is on you to
# know that it does. Above that the form inverts and becomes the very failure
# L-387 describes: echo blocks on the full pipe, grep -q exits, echo takes
# SIGPIPE, rc=141 (T-2743 — measured on a 146,366-byte Watchtower page, 3/3 runs,
# deterministic not racy; rendered routes run 50-200KB, so anything that curls a
# page is over the line). It also discards cmd's exit code, so a 404 yields an
# empty capture that grep merely fails to match rather than a failed line.
# If you do use it: single pipe only, no intermediate tail/awk/sed stage between
# capture and grep (T-2090) — the middle stage is what `grep -q` slams its stdin
# on, and grep scans the whole captured string anyway, so the `tail -3` was
# cosmetic. `echo "$out" | grep -q PAT`, nothing between.
#
# TEST RUNNERS need a guard either way (T-2738). `set -e` is suppressed inside the
# `if` condition the gate runs each line in, so in `cmd1; cmd2` only cmd2 is the
# verdict — and the pass marker you grep for survives a partial failure: a suite
# printing "3 failed, 9 passed" satisfies `grep -q "9 passed"`, and generalising
# to `grep -qE "[0-9]+ passed"` matches the same output. Keep the exit code:
#     python3 -m pytest <file> -q > /tmp/.out 2>&1 && grep -q passed /tmp/.out
# or add the guard the exit code used to supply:
#     out=$(python3 -m pytest <file> -q 2>&1); echo "$out" | grep -q passed && ! echo "$out" | grep -q failed
#     out=$(bats <file> 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# The close gate refuses the unguarded form. Bypass: FW_ALLOW_UNJUDGED_TEST_RUN=1.
#
# ── A SKIPPED BATS TEST REPORTS `ok` (T-3217) ─────────────────────────────────
#
# `! grep -q "^not ok"` does NOT mean the suite ran. Bats emits a skip as
#     ok 6 <name> # skip <reason>
# which is not a `not ok`, so the gate passes and the report says ok while the
# thing the test covers was measured NOWHERE. Origin: T-3213 guarded a test with
# `[ "$(id -u)" -eq 0 ] && skip` — the suite runs as root here and in CI, so it
# skipped on every run that mattered, for as long as it existed.
#
# Add a skip clause to any bats verification line. `# skip` is the marker bats
# writes; counting it is the whole check:
#     timeout 300 bats <file> > /tmp/.out 2>&1 && ! grep -q "^not ok" /tmp/.out
#     test "$(grep -c '# skip' /tmp/.out)" -eq 0
# Two lines, because they answer different questions — "did anything fail" and
# "did everything run". If some skips are legitimate on your host (an optional
# dependency is genuinely absent), assert the COUNT you expect rather than zero,
# and say in the task why that number is right.
#
# Corpus-wide, the same check runs from `bin/fw test lint`
# (tools/bats-silent-skip-lint.py): static mode flags guards that are fixed for
# a deployment rather than probing an optional dependency, and `--tap FILE`
# reports the skips a real run actually fired.
#
# REHEARSING A LINE BY HAND DOES NOT REHEARSE THE GATE (T-2743). Your interactive
# shell has no pipefail. A line has returned 0 by hand and 141 under P-011, from
# the same directory, the same second. To rehearse for real:
#     bash -c 'set -o pipefail; <your verification line>'
#
# NOTE THE MISSING `-e` — it is not a typo (T-3203). This file used to prescribe
# `set -eo pipefail` here, which is NOT the gate: it adds errexit the gate does
# not have, so it FAILS lines the gate PASSES. Measured, 10 lines, 3 diverged:
#     line                            gate    set -eo (old)   set -o (this)
#     false; true                     PASS    FAIL  wrong     PASS  ok
#     cd /nonexistent; echo ok        PASS    FAIL  wrong     PASS  ok
#     grep -q MISS file; true         PASS    FAIL  wrong     PASS  ok
# The divergence is one-directional and that is the trap: the old rehearsal only
# ever fails lines the gate accepts, so it produces false REDS, and an author
# who "fixes" a line to satisfy it is fixing something that was never broken —
# while the line that actually is broken (`cmd1; cmd2` where cmd1 fails) passes
# both. Re-derive rather than trust this table — it is pinned, not asserted:
#     bats tests/unit/t3203_p011_gate_semantics.bats
#
# ── `cmd1; cmd2` IS JUDGED ONLY ON cmd2 (T-3203) ──────────────────────────────
#
# The gate runs each line as the CONDITION of an `if` (update-task.sh:1215), and
# POSIX suppresses errexit for a compound command in an `if` condition — through
# the subshell. So pipefail applies and `set -e` does not, and in a sequence only
# the LAST command's status reaches the verdict. `cd /nonexistent; echo ok` passes.
# 2,644 of 10,997 verification lines in this corpus contain `;` (re-derive with
# the query in docs/reports/T-3203-p011-gate-semantics.md).
#
# SAFE SHAPES — both verified biting, each against a passing control:
#   A. one command whose own status is the verdict (prefer this):
#        out=$(cmd 2>&1); echo "$out" | grep -q PAT && ! echo "$out" | grep -q BAD
#      the leading assignments are setup; the trailing `&&` chain is the verdict.
#   B. an explicit sub-shell, whose errexit the outer `if` cannot reach into:
#        bash -c 'set -eo pipefail; cmd1; cmd2'
#      use when you genuinely need every command in the sequence to count.
#
# The rule of thumb: put the assertion LAST, and make sure it is an assertion.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.
#
# No durations pinned (T-3326): 2.883s and 4.5x are this host's numbers and
# would rot. Both suites guard the PROPERTY — that each cache stamps its own
# timestamp and that the cached value equals a freshly computed one. web/
# changed, so `watchtower current` is here per G-104.

timeout 600 bats tests/unit/t3459_episodic_tag_cache.bats > /tmp/.t3459-v1.out 2>&1 && grep -q "^ok 1 " /tmp/.t3459-v1.out
timeout 900 bats tests/unit/t3459_metrics_quality_cache.bats > /tmp/.t3459-v2.out 2>&1 && grep -q "^ok 1 " /tmp/.t3459-v2.out
bin/fw watchtower current
bin/fw vendor self --check

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

## Recommendation

<!-- T-2945: same shape as inception.md's block — the gate that reads it
     (audit_inception_recommendation, lib/task-audit.sh:117) is shared, so the
     shape is copied rather than reinvented.

     REQUIRED once this task reaches partial-complete: Agent ACs done, at least
     one `### Human` AC still unticked. `lib/review.sh:205-211` (T-2421) BLOCKS
     `fw task review` emission for build/refactor/test/decommission tasks in that
     state with no substantive block here — the operator would otherwise open
     /review/<id> to a blank Recommendation card and be asked to approve a form.

     Not required while every Human AC is ticked or the task has none: the gate
     only fires on the partial-complete transition. It is here from the start so
     you write it while you still have the evidence, not when the gate refuses.

     Format (the parser wants the `**Recommendation:**` line at the start of a
     line; a leading `-` or `*` bullet is also accepted):
     **Recommendation:** GO / NO-GO / DEFER
     **Rationale:** Why (cite evidence — what shipped, what was proven, what remains)
     **Evidence:**
     - Finding 1
     - Finding 2

     DEFER is for evidence gaps, not confidence gaps (CLAUDE.md §Presenting Work
     for Human Review). If the artefact is complete and you still don't want to
     commit, that is a calibration failure — recommend GO or NO-GO.
-->

**Recommendation:** GO

**Rationale:** `/metrics` goes from ~4 s to ~0.8 s on warm requests, closing the last of
the six endpoints T-3453 surfaced as over the smoke probe's 5 s bar. The correctness
argument is unusually strong for a performance change because nothing was recomputed a
different way — the function is byte-for-byte unchanged and only its repetition was
removed, so "do the numbers still match" is true by construction rather than by
comparison. The live diff confirms it anyway: one line, the CSRF token.

I deliberately did **not** do what this task's own parking note proposed. That plan was
to read `shared.get_all_task_metadata()`, and it was the wrong plan: one of the two
aggregates is a body regex with no equivalent in that metadata, so following it would
have meant reimplementing an aggregate against a different data source and then arguing
the numbers matched. Smaller and safer won.

**Evidence:**
- Per-helper timing: `_quality_scores` 2.883 s of a ~3.1 s route; the other four helpers
  total 0.211 s. One helper was 93% of the page.
- Live A/B, same restart both sides: pre-fix 4.01 / 4.87 / 3.52 / 3.48 s; post-fix 3.78
  (cold) / 0.79 / 0.79 / 0.93 s.
- Rendered page before vs after: both 228124 bytes, line diff returns **only** the
  per-request CSRF token.
- 8/8 in `tests/unit/t3459_metrics_quality_cache.bats`, plus the 7 in
  `t3459_episodic_tag_cache.bats` from this task's earlier half.
- Web suite: identical 6-failed / 8-passed on the same control selection as before the
  change (that 6 is pre-existing; reproduced without this change earlier today).

**What this does not fix, stated plainly:** the first request after a restart still costs
the full ~3.8 s. And the unexplained variance noted in T-3458 — live `/` readings of
9.45 s and 18.45 s that a controlled A/B could only reproduce at 2.87-6.56 s — is still
unexplained and still unowned.

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

### 2026-09-25T07:54:50Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3459-metrics-is-the-last-operator-surface-ove.md
- **Context:** Initial task creation

### 2026-09-25T08:01:59Z — status-update [task-update-agent]
- **Change:** status: started-work → issues

### 2026-09-25T08:32:24Z — status-update [task-update-agent]
- **Change:** status: issues → started-work


## Resolution — /metrics is under the bar

Resumed from `issues`. The parking note said the fix was to read
`shared.get_all_task_metadata()` and prove per-aggregate equality. **I did something
smaller and safer instead**, and the reason is worth recording: that plan was a
*behaviour* change. `_quality_scores()` computes its own aggregates, and one of them — a
body regex for an acceptance-criteria heading — has **no equivalent in that metadata at
all**. Re-pointing it would have meant reimplementing the aggregate against a different
data source and arguing the numbers still matched.

Caching the existing computation achieves the same result with no such argument: same
function, same inputs, same output, only not repeated within the TTL. AC 4 is then
satisfied by construction rather than by comparison.

### Where the time was (AC 1, sharpened)

Per-helper timing on the route, rather than inferring from the request profile:

| helper | cost |
|---|---|
| **`_quality_scores`** | **2.883 s** |
| `_knowledge_counts` | 0.173 s |
| `_task_counts` | 0.016 s |
| `_traceability` | 0.015 s |
| `_recent_commits` | 0.007 s |

One helper is 93% of the route. It reads and frontmatter-parses every task file in the
corpus, active **and** completed — the ~3929 documents the earlier profile counted.

### Live A/B, same restart on both sides (AC 3)

| | run 1 | run 2 | run 3 | run 4 |
|---|---|---|---|---|
| pre-fix | 4.01 s | 4.87 s | 3.52 s | 3.48 s |
| **post-fix** | 3.78 s | **0.79 s** | **0.79 s** | **0.93 s** |

~4.5× on warm requests. **The first request after a restart still pays the full ~3.8 s** —
the cache starts empty, and that is honest to state rather than average away. Every
subsequent request inside the TTL is free.

`/metrics` is now under the smoke probe's 5 s bar on every measurement including the cold
one, which closes the last of the six endpoints T-3453 surfaced.

### Nothing the page reports changed (AC 4)

The rendered page was captured before and after, from the live server, same corpus. Both
228124 bytes. A line-level diff of the two returns **exactly one difference**:

```
<     <meta name="csrf-token" content="aa3118c4...">
>     <meta name="csrf-token" content="eefbf3e2...">
```

Per-request by design. Every metric, count, quality score, commit row and stale-task entry
is byte-identical. The sha256 of the two files differs *because of that token* — which is
why the check is a diff and not a hash comparison; a hash would have said "different" and
been useless.

### Guard (AC 5)

`tests/unit/t3459_metrics_quality_cache.bats`, 8 tests. The one that matters most pins
**stamping**, not caching — because the sibling bug this same task fixed in `shared.py`
hours earlier was a cache that stored its value and never wrote its timestamp, so it was
populated and still never read as valid. A "does it cache?" test passes against that bug.
Also pinned: the `total == 0` path stores and stamps like every other exit (the original
had a bare early `return 0, 0`), and the TTL still matches `shared.py`'s.
