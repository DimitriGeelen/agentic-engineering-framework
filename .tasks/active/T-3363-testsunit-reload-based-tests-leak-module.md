---
id: T-3363
name: "tests/unit: reload-based tests leak module globals — 16 failures that pass
  in isolation"
description: >
  Reload-based tests leave web.shared.PROJECT_ROOT and sibling module globals pointing
  at deleted tmp dirs, so 16 tests across 6 files fail in the full suite and pass
  alone. T-1995 diagnosed this and fixed it with a per-test autouse re-pin fixture
  applied to only 2 files; the 6 affected files never got it. Correlation is total.
  Reproduced in 10s. Four independent contaminators bisected. See docs/reports/T-3362-pytest-triage.md
  group B.

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
created: 2026-09-15T16:56:09Z
last_update: 2026-09-15T17:10:00Z
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
  - ts: '2026-09-15T17:00:13Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=269,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-15T17:00:27Z'
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

# T-3363: tests/unit: reload-based tests leak module globals — 16 failures that pass in isolation

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [ ] The polluted module global(s) are identified **by measurement, per victim file**,
      not assumed to be `PROJECT_ROOT` everywhere
- [x] The fix is **suite-level, applied once** — a `tests/unit/conftest.py` autouse
      fixture, not T-1995's per-file fixture copied six more times. A test file added
      tomorrow must be protected without anyone editing it
- [ ] All 16 previously-contaminated tests pass in the contaminator-first ordering
      that reproduced the failure
- [x] **Control leg:** with the fixture neutralised, that same ordering fails again.
      Without this, a fixture that does nothing is indistinguishable from one that works
- [ ] **Anti-masking leg:** the 6 genuine reds from T-3362 (groups C/D/E/F) are still
      red after the fix — an isolation fixture must not paper over real failures
- [x] `conftest.py` carries a comment naming L-421 and stating why the fix is
      victim-side-at-scale rather than polluter-side

## Measurements

**Polluter, located precisely.** `tests/unit/test_decide_commit.py:55-59`:

```python
monkeypatch.setenv("PROJECT_ROOT", str(tmp))
importlib.reload(web.shared)      # recomputes the global from the temp env
importlib.reload(inc)
```

`monkeypatch` restores the *environment variable* at teardown and knows nothing
about the module global the reload recomputed from it. L-421 cause (1), verbatim.

**Before** (`test_decide_commit` first, then the victim files):

```
5 failed, 79 passed, 2 skipped
```

**After** the conftest fixture, same ordering:

```
86 passed
```

**Control** (`pytest --noconftest`, same ordering — fixture neutralised):

```
5 failed, 79 passed, 2 skipped
```

The 5 return. The fixture is load-bearing, not decorative.

**A second symptom worth recording:** 2 tests that *skipped* under pollution now
run and pass (86 passed, 0 skipped vs 79 passed, 2 skipped). A dangling
`PROJECT_ROOT` made a path-existence skip-guard fire, so the contamination was not
only failing tests — it was silently removing others from the run while the report
still said `ok`. That is the T-3217 class (a skipped bats test reports `ok`)
arriving through a different door.

### Pre-registered prediction (written before the confirming run reported)

Recorded ahead of the result so the anti-masking leg can actually fail. A
prediction written after the fact only ever confirms itself.

The full-suite run with the fixture in place should report **exactly 6 failures**,
and they should be exactly these — the four standing causes from T-3362 that have
nothing to do with contamination:

| # | Node id | T-3362 group | Owner |
|---|---------|--------------|-------|
| 1 | `test_corpus_lint.py::test_live_corpus_all_versions_census` | E | T-3326 |
| 2 | `test_file_route_extensions.py::test_is_viewable_path_rejects_unknown_dir` | C | T-3364 |
| 3 | `test_render_page_guard.py::test_guard_skipped_on_htmx_request` | D | T-3365 |
| 4 | `test_inception_decide_warning_widen.py::test_side_effect_warning_truncation_widened_to_1500` | F | T-2219 |
| 5 | `test_inception_decide_warning_widen.py::test_side_effect_warning_html_escaped` | F | T-2219 |
| 6 | `test_inception_decide_warning_widen.py::test_side_effect_warning_uses_pre_wrap_style` | F | T-2219 |

Three ways this prediction can be wrong, and what each would mean:

- **Fewer than 6** — the fixture is masking a real failure. That is the scenario
  this leg exists to catch, and it would make the fix worse than the bug: a
  contamination fixture that also suppresses genuine reds converts a loud problem
  into a silent one.
- **More than 6** — either a contaminator the `PROJECT_ROOT` snapshot does not
  cover (L-421 cause 2, the `del sys.modules` variant, is *not* addressed by this
  fixture), or a seventh standing cause the triage missed.
- **6, but not these 6** — the set matters, not the count. A different six would
  mean the correlation T-3362 reported was partly coincidence.

Note the honest open edge: `test_embed_health.py` (6) and `test_incremental_reindex.py`
(4) were never reproduced from `test_decide_commit` specifically. Their contaminator
is still unidentified; they are predicted green only because the fixture is
attribute-scoped rather than polluter-scoped. If they stay red, the fix is
incomplete rather than wrong, and the next step is to bisect *their* contaminator.


### Result of the confirming run — the prediction FAILED

`17 failed, 2687 passed, 2 skipped in 1869.02s`. Predicted exactly 6 failures;
got 17. Recording this as a failed prediction, not a partial success, because the
pre-registration above named "more than 6" as a specific diagnosis and it is the
one that fired.

Reconciliation against the pre-fix nightly (22 real failures + 1 parser artefact):

| Transition | Count | Which |
|---|---|---|
| fail -> pass | 6 | `test_task_panel` (2), `test_task_panel_edit` (2), `test_auto_link_root_and_articles` (1), `test_cockpit_activity` (1) |
| skip -> pass | 5 | contamination had been removing them from the run |
| **pass -> fail** | **1** | `test_review_markdown_render::test_parse_ac_body_renders_steps_as_html` |
| still failing | 10 | `test_embed_health` (6), `test_incremental_reindex` (4) |

Arithmetic closes exactly: 22-6+1 = 17 failed; 2677+6-1+5 = 2687 passed; 7-5 = 2
skipped. No unexplained residue.

**AC 3 is NOT met and is not being re-worded to fit.** It says all 16
contaminated tests pass. Six do. The task premise — one contaminator, sixteen
victims — was wrong, and the honest record is that the acceptance criterion
stands unsatisfied rather than that the criterion was too ambitious.

### The premise was wrong: two independent causes, not one

The 16 split by mechanism, and only the first is L-421 cause (1):

- **Cause 1 (6 victims) — FIXED here.** `importlib.reload` leaves
  `web.shared.PROJECT_ROOT` pointing at a deleted tmp dir. Restoring the
  attribute fixes it.
- **Cause 2 (10 victims) — NOT fixed here, split out.** `test_csrf_cookie_scoping`
  calls `importlib.reload(web.config)`. Reload re-executes the module *in place*,
  so `sys.modules["web.config"]` keeps its identity — which is why every
  module-level guard misses it — but `Config` is rebuilt as a **new class
  object**. `web/embeddings.py:29` did `from web.config import Config` at import
  time and still holds the old one. The victims patch the new class; the code
  under test reads the old one; the patch is invisible. Collection order does the
  rest: `csrf` < `embed_health` < `incremental_reindex`.

  This is neither L-421 cause — (1) is a stale *attribute value*, (2) is
  `del sys.modules` replacing the *module*. This is a class inside a module that
  was never deleted. Reload preserves module identity and destroys class identity,
  and nothing in the corpus said so.

### The finding that matters most: contamination caused a false GREEN

`test_parse_ac_body_renders_steps_as_html` passed under pollution and fails
without it. The dangling `PROJECT_ROOT` made a file-existence check miss, the
auto-linkifier never fired, and the assertion saw the plain href it expected.
With PROJECT_ROOT correct the path resolves and the linkifier rewrites *inside an
existing anchor's href*:

```html
<a href="./<a href="/file/.context/working/feedback-stream.yaml">...</a>">
```

A real nested-anchor defect on any task body that links a repo path, hidden for
as long as the contamination has been present. T-3362 framed this class as "16
false reds"; the true cost was 16 false reds, 5 silently dropped tests, and at
least one false green concealing a live bug. A suite that lies does not lie in
one direction.


## Decisions

### 2026-09-15 — victim-side-at-scale over polluter-side

- **Chose:** one autouse fixture in a new `tests/unit/conftest.py` that snapshots and
  restores the fragile module globals around every test.
- **Why:** L-421 offers two fix shapes — re-pin globals on the victim, or use
  `importlib.reload` instead of `del sys.modules` on the polluter. Polluter-side is
  O(15 files) and protects only the victims that exist today; a 16th polluter
  reintroduces the class. A single conftest fixture is O(1), covers every test in the
  directory including ones not yet written, and needs no edit to the 15 reload-based
  files.
- **Rejected:** copying T-1995's per-file fixture into the 6 affected files. That is
  precisely the move that produced this task — a correct fix whose coverage is exactly
  the set of files someone had already seen fail.

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

# The isolation fixture exists and is suite-level (not copied per file).
test -f tests/unit/conftest.py
# The contaminator-first ordering that reproduced the failure is now green.
# pytest's own exit code is the verdict; the grep only confirms the run happened.
o=$(mktemp); timeout 900 python3 -m pytest tests/unit/test_decide_commit.py tests/unit/test_auto_link_root_and_articles.py tests/unit/test_cockpit_activity.py tests/unit/test_task_panel.py tests/unit/test_task_panel_edit.py -q -p no:cacheprovider --color=no > "$o" 2>&1 && grep -q "passed" "$o"
# CONTROL LEG — deliberately asserts a FAILURE. With the fixture neutralised the
# same ordering must go red again. If this line ever passes-as-green, the fixture
# has stopped being load-bearing and the one above proves nothing.
# `;` then grep is intentional here: grep is the verdict, not pytest's exit code.
c=$(mktemp); timeout 900 python3 -m pytest --noconftest tests/unit/test_decide_commit.py tests/unit/test_auto_link_root_and_articles.py tests/unit/test_cockpit_activity.py tests/unit/test_task_panel.py tests/unit/test_task_panel_edit.py -q -p no:cacheprovider --color=no > "$c" 2>&1; grep -q "failed" "$c"

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

## RCA

**Symptom:** 16 tests across 6 files pass when run alone and fail in the full suite.
Four consecutive nightlies reported them identically, so deterministic, not flake.

**Root cause:** `tests/unit/test_decide_commit.py:55-59` (and siblings among the 15
reload-based files) do `monkeypatch.setenv("PROJECT_ROOT", tmp)` followed by
`importlib.reload(web.shared)`. `monkeypatch` restores the environment variable at
teardown; nothing restores the module global the reload recomputed from it. Later
tests then evaluate `(PROJECT_ROOT/p).exists()` guards and template lookups against
a tmp directory pytest has already deleted, and silently take the wrong branch —
returning a full wrapped page where a fragment was expected, declining to linkify a
file that exists, or firing a skip-guard. L-421 cause (1).

**Why structurally allowed — two independent failures, and the second is the one
that matters:**

1. *The fix existed and did not scale.* T-1995 diagnosed this exact class correctly
   in May and fixed it with a per-test autouse re-pin fixture, placed in two files.
   A per-file fixture's coverage is, by construction, the set of files someone has
   already watched fail. It cannot protect a file nobody has watched fail yet, and
   it cannot protect a file written afterwards. The six victims here were never in
   that set. Nothing in the repo recorded that the remedy was partial — L-421 states
   the fix shape ("re-pin globals via autouse fixture") without stating its scope.

2. *The surface that would have reported the spread was blind.* The nightly unit
   suite starved its own pytest leg to `timeout 1` and reported `failed_count: 0`
   (T-3359). So from May to September the contamination produced no signal whatsoever
   — not a red, not a warning, a clean-looking zero. The class was not tolerated; it
   was invisible. Uncovered only once T-3359 let the leg finish.

**Prevention:**

- `tests/unit/conftest.py` — one autouse fixture, directory-wide. Coverage is now
  "every test in tests/unit", including files not yet written, rather than "the
  files we already caught". This is the part that generalises where T-1995 did not.
- A control leg in `## Verification` asserts the fixture stays load-bearing: with
  `--noconftest` the ordering must still go red. A fixture that silently stopped
  working would otherwise be indistinguishable from a fixed suite.
- T-3359 (already landed) means a regression of this class now surfaces in the next
  nightly rather than never. Prevention here is the *pair* — the fix and a working
  detector — because either alone is what produced the four-month gap.

<!-- Template guidance below retained for reference.
     REQUIRED for bug-class tasks (workflow_type=build with bug-tag, OR title matches
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

### 2026-09-15T16:56:09Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3363-testsunit-reload-based-tests-leak-module.md
- **Context:** Initial task creation

### 2026-09-15T17:10:00Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
