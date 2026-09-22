---
id: T-3428
name: "BVP rubric-driven scoring: free and arc-scoped drivers score from a declarative
  scoring: spec in policy/value-drivers.yaml, not from a hardcoded handler table (OBS-463
  leg 2 + doctor rail)"
description: >
  BVP rubric-driven scoring: free and arc-scoped drivers score from a declarative
  scoring: spec in policy/value-drivers.yaml, not from a hardcoded handler table (OBS-463
  leg 2 + doctor rail)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [bvp, estimator, value-drivers, arc-006]
components: [agents/audit/audit.sh, agents/termlink/bvp-estimator/estimator.py, bin/fw, lib/bvp-scorability.sh, lib/bvp.sh, lib/upgrade.sh, policy/driver-scoring-example.yaml, policy/value-drivers.yaml, tests/unit/test_t3428_declarative_scoring.py]
related_tasks: [T-3427, T-3068, T-2343]
arc_id: value-prioritisation
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
created: 2026-09-22T10:38:04Z
last_update: 2026-09-22T11:56:55Z
date_finished: 2026-09-22T11:56:55Z
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
  - ts: '2026-09-22T10:40:21Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=330,acs=8)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-22T10:40:22Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3428: BVP rubric-driven scoring: free and arc-scoped drivers score from a declarative scoring: spec in policy/value-drivers.yaml, not from a hardcoded handler table (OBS-463 leg 2 + doctor rail)

## Context

OBS-463, leg 2 — the real fix. Today the BVP estimator scores a driver only
if a Python handler exists for it (`_handler_table()`); the `levels:` and
rubric text in `policy/value-drivers.yaml` are never read. T-3427 stopped
the bleeding (an unscorable driver is omitted, `--add` refuses one) but a
project or an arc still cannot define a driver that *works* without a
framework code change. The operator's ruling (2026-09-22): fix it now.

**Design — declarative scoring specs.** A driver entry (free or arc-scoped)
may carry a `scoring:` block the estimator interprets generically:

```yaml
scoring:
  kind: signals                # the one kind this slice ships
  strip_template: true         # default true — see the trap below
  levels:                      # int 1..5 -> any-of signals; highest matching level wins; none -> 0
    1:
      keywords: ["finding", "streichliste"]          # case-insensitive substrings in title+body+tags
    3:
      keywords: ["evidence", "cited"]
      paths: ["tools/*.py", "docs/reports/*.md"]     # fnmatch against components: AND paths named in ACs/Verification
    5:
      frontmatter: {workflow_type: build}            # equality on frontmatter keys (str compare)
      tags: ["audit"]                                # any tag equal
```

Rules: a level matches when ANY of its signals matches; the score is the
highest matching level; evidence lists every matched signal as
`L<level>:<kind>=<value>`; a spec with no matching level scores 0 *with*
evidence `L0: no signal` (this is a measured 0, not unscored — the driver
HAS a mechanism). `strip_template: true` removes every line that also
appears in `.tasks/templates/default.md` before keyword matching — the trap
1409-sprind measured: template guidance prose (REHEARSING, PRODUCING,
CLAUDE.md, .claude/settings.json) matched uniformly across a whole corpus.

**Dispatch order in the estimator loop:** inception VOI (unchanged) →
Python handler by id → handler by alias → **declarative spec** → unscored.
`has_scorer()` returns true when a spec exists and validates. Arc-scoped
drivers (`.context/arcs/<slug>.yaml` `scoped_drivers[]`) may carry the same
`scoring:` block and reach the loop through the existing
`_arc_scoped_drivers_for_task` path.

**Authoring surface:** `fw bvp driver --add … --scoring-file <yaml>` writes
a validated block into the new entry (replaces the need for
`--allow-unscored` when a spec is given); `fw bvp driver --validate-scoring
<yaml>` checks a spec offline; `fw bvp driver --explain <id> T-XXXX` prints
the level-by-level evidence for one task. Validation: levels ⊆ 1..5, each
level has ≥1 signal of a known kind, keywords are non-empty strings, paths
are globs, frontmatter is a flat map.

**Rail (leg 3):** `fw audit` (structure section) WARNs `BVP driver <id> has
neither a handler nor a scoring spec` for every ACTIVE free or arc-scoped
driver; `fw doctor` mirrors it.

**Follow-on, separate task (operator ruling 2026-09-22):** arc-scoped
drivers are created and added by default without the operator approval
step, with an external value-driver reviewer as the quality gate — T-3429.
That reviewer will require a `scoring:` block, which is why this task ships
first.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `agents/termlink/bvp-estimator/estimator.py`: `load_scoring_spec(driver_entry) -> spec|None`, `validate_scoring_spec(spec) -> list[str]` (errors), `score_declarative(spec, fm, body, tags) -> (int, evidence)`, template stripping via `.tasks/templates/default.md`; the loop dispatches handler → alias → spec → unscored; `has_scorer()` true for a driver with a valid spec; arc-scoped entries honoured through `_arc_scoped_drivers_for_task`
- [x] `lib/bvp.sh`: `--add … --scoring-file <yaml>` validates and writes the block (an invalid spec is refused with the errors listed; a valid one removes the T-3427 refusal); `--validate-scoring <yaml>`; `--explain <id> <T-XXXX>` prints per-level evidence
- [x] `fw audit --section structure` WARNs per active driver with neither handler nor spec, naming the id; `fw doctor` mirrors; both silent when every active driver is scorable
- [x] Tests (`tests/unit/test_t3428_declarative_scoring.py`): each signal kind matches and is reported in evidence; highest-level-wins; no-signal → 0 with `L0` evidence; template stripping removes template prose (a task whose only "match" is template text scores 0); invalid specs (level 7, empty keywords, unknown kind) refused with named errors; `has_scorer` true with spec; estimator end-to-end on a fixture task with a spec'd driver; `--add --scoring-file` writes the block and is not refused; the audit WARN fires on a fixture policy with an unscorable active driver and is silent otherwise. T-3427's suite and the estimator suite still green
- [x] `policy/value-drivers.yaml`: header comment documents the `scoring:` block (schema + the template trap); one real free driver (`F-RECALL` or a new example under a comment) carries a worked spec; `docs/reports/T-3428-declarative-scoring.md` records the design and what stays hand-written (D1–D4 handlers)
- [x] Vendored copies synced, `bin/fw vendor self --check` clean; fabric cards for new files; `bin/fw help` parity lint green if any router line changes

**Evidence (r2 verification, 2026-09-22):**
- *Estimator:* `load_scoring_spec`:2320, `validate_scoring_spec`:2353, `score_declarative`:2503, `_strip_template`:2303, `has_scorer`:2604. Dispatch at :2707-2732 is handler → alias → spec → unscored, with T-3427's `unscored (no scorer for …)` intact as the final fallback. Arc specs merge via `_arc_scoped_specs_for_task` (:2705) with `setdefault`, so global wins.
- *Verbs:* `--validate-scoring` exits 0 on the shipped example, 2 on an invalid spec, naming each error (`level out of range`, `'' is not a non-empty string`, `unknown kind 'bogus'`, `unknown signal kind`). `--explain F-RECALL T-3428 --scoring-file policy/driver-scoring-example.yaml` → score 5 with keyword, path and frontmatter signals all reported.
- *Rails:* `fw doctor` WARNs, naming all 6 live unscorable arc-scoped drivers with their source arc. `check_bvp_driver_scorability` (audit.sh:3396, called :3433) emits one WARN per driver with the same naming.
- *Template trap measured:* a keyword present in T-3429 **only** as template prose ("committed fixture") scores **0** with `strip_template: true` and **4** with it false — the stripping is doing real work, not decoration.
- *Tests:* 275 passed (58 new + 217 pre-existing across the four named suites).

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

# ── T-3428 verification (all rehearsed under `bash -c 'set -o pipefail; <line>'`) ──
python3 -m pytest tests/unit/test_t3428_declarative_scoring.py tests/unit/test_bvp_estimator.py tests/unit/test_t3427_unscored_driver.py tests/unit/test_bvp_cli_rank_proposed.py tests/unit/test_bvp_cli_arcs_rollup.py -q > /tmp/.t3428-tests.out 2>&1 && grep -q "passed" /tmp/.t3428-tests.out
python3 -c "import importlib.util as u; s=u.spec_from_file_location('e','agents/termlink/bvp-estimator/estimator.py'); m=u.module_from_spec(s); s.loader.exec_module(m); assert all(hasattr(m,f) for f in ['load_scoring_spec','validate_scoring_spec','score_declarative','has_scorer','_strip_template'])"
bin/fw bvp driver --validate-scoring policy/driver-scoring-example.yaml > /tmp/.t3428-vs.out 2>&1 && grep -q "is a valid scoring spec" /tmp/.t3428-vs.out
printf 'kind: signals\nlevels:\n  7:\n    keywords: ["x"]\n' > /tmp/.t3428-bad.yaml; bin/fw bvp driver --validate-scoring /tmp/.t3428-bad.yaml > /tmp/.t3428-bad.out 2>&1; test $? -ne 0 && grep -q "level out of range" /tmp/.t3428-bad.out
bin/fw bvp driver --explain F-RECALL T-3428 --scoring-file policy/driver-scoring-example.yaml > /tmp/.t3428-ex.out 2>&1 && grep -q "L5:frontmatter=workflow_type=build" /tmp/.t3428-ex.out && grep -q "L3:path=docs/reports" /tmp/.t3428-ex.out
bash -c 'source lib/bvp-scorability.sh; fw_bvp_unscorable_drivers "$PWD" > /dev/null'
bin/fw doctor > /tmp/.t3428-doc.out 2>&1; grep -qE "BVP driver" /tmp/.t3428-doc.out
grep -q "check_bvp_driver_scorability$" agents/audit/audit.sh && grep -q "DECLARATIVE SCORING SPECS" policy/value-drivers.yaml
bin/fw vendor self --check > /tmp/.t3428-v.out 2>&1 && grep -q "in sync" /tmp/.t3428-v.out

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

### 2026-09-22 — the rail found six real unscorable drivers on the live corpus
- **What changed:** the leg-3 rail was specced as a guard against a *future*
  authoring mistake. On first run it named six drivers that already exist and
  already score nothing: `identity-fidelity` and `provisioning-safety`
  (arc-020), `Discard fidelity` and `Loop closure (conditional)`
  (continuous-run), `unknown-input-safety` and `first-run-recoverability`
  (onboarding-shape-detection). Each carries a weight and a rubric and reads as
  a live axis while contributing nothing to any ranking.
- **Plan impact:** none to this task's scope — the rail is doing exactly its job,
  and T-3427 already keeps these out of the denominator so they are not
  distorting scores, only failing to inform them. But it reframes the rail from
  "prevention" to "prevention plus an existing backlog".
- **Triggered:** nothing filed here. T-3429 (external value-driver reviewer,
  which will require a `scoring:` block) is the natural owner of giving these six
  a mechanism; noting it so that task starts from a known list rather than
  rediscovering it.

### 2026-09-22 — `--explain` turned out to be the load-bearing verb, not `--validate-scoring`
- **What changed:** the spec lists three authoring verbs as peers. In use, the
  useful one is `--explain <id> <task> --scoring-file <draft>`: it scores a REAL
  task against a DRAFT spec and writes nothing. That is what tells an author a
  level never fires, or fires on everything — which is the actual authoring
  failure mode. `--validate-scoring` only catches shape errors.
- **Plan impact:** none structurally, but the ordering in the docs was changed to
  lead with `--explain` rather than list it third
  (`policy/driver-scoring-example.yaml` header, design report §Authoring surface).
- **Triggered:** no new task.

### 2026-09-22 — a slow full `fw audit` masks a working rail
- **What changed:** verifying the audit leg with `timeout 550 bin/fw audit` showed
  NO BVP line and looked like a missing rail. The audit had in fact been killed
  around source line 2796 of 7553, well before the check at 3433 — and it had
  already printed 30 findings, so the output looked complete. Five concurrent cron
  audits on this host make lock contention and slow runs routine.
- **Plan impact:** the Verification line for the audit leg pins the wiring
  (`check_bvp_driver_scorability` defined and called) plus a direct run of the
  underlying library, rather than grepping a full-audit run — which would be both
  slow and, per T-3326, anchored to mutable corpus state.
- **Triggered:** no new task; recorded because "the audit printed no line" is a
  false negative that reads exactly like a real one.

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

### 2026-09-22 — A handler always outranks a declarative spec
- **Chose:** dispatch order handler → alias → spec → unscored, so a hand-written
  handler wins whenever both exist for the same driver.
- **Why:** a handler is the richer mechanism (it can read arbitrary structure); a
  policy-file edit must not be able to silently displace framework code. The
  losing case is loud rather than silent — `--explain` says which source scored.
- **Rejected:** spec-wins (a policy edit becomes a code override with no review);
  error-on-both (punishes a project for documenting an axis the framework
  already handles).

### 2026-09-22 — The worked example ships inert, under a comment
- **Chose:** `policy/value-drivers.yaml` carries `F-EXAMPLE` commented out, and the
  copyable spec lives in `policy/driver-scoring-example.yaml`.
- **Why:** every currently-active free driver already has a handler, so by the
  decision above a live spec attached to one would never fire — shipping it live
  would be a worked example that demonstrably does nothing. The AC explicitly
  allows "a new example under a comment".
- **Rejected:** attaching a spec to F-RECALL (inert for the same reason, but
  misleadingly live-looking).

### 2026-09-22 — `strip_template` defaults to true
- **Chose:** template stripping on by default; opt out per spec.
- **Why:** the 1409-sprind trap is the expensive failure and it is silent — a
  keyword drawn from template prose matches the whole corpus uniformly and ranks
  nothing, while looking like a working driver. Measured here: "committed fixture"
  scores 4 unstripped and 0 stripped on a task that only contains it as template
  guidance.
- **Rejected:** default false (fails open into the exact trap the spec names).

### 2026-09-22 — `--validate-scoring` exits 2, not 1, on an invalid spec
- **Chose:** exit 2 for a spec that parses but fails validation.
- **Why:** keeps "file missing/unreadable" (1) distinct from "file is not a valid
  spec" (2), so a Verification line can tell an authoring error from a typo'd path.

### 2026-09-22 — the design report is not fabric-registered
- **Chose:** fabric cards for `lib/bvp-scorability.sh`,
  `policy/driver-scoring-example.yaml` and the test file; none for
  `docs/reports/T-3428-declarative-scoring.md`.
- **Why:** report registration is the clear exception in this corpus — 17 of 728
  files under `docs/reports/` carry a card, and no recent sibling (T-3427, T-3426,
  T-3398, T-3203) registered one. Following the convention beats following the
  literal word "new files".

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-09-22T10:38:04Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3428-bvp-rubric-driven-scoring-free-and-arc-s.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-40c193b2
- **Timestamp:** 2026-09-22T11:59:04Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-09-22T11:56:55Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
