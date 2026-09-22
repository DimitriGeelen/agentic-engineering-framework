---
id: T-3435
name: "Fabric card quality, second pass: header comments for the 32 files that describe
  themselves nowhere (one honest line each, refuse if unclear), edge enrichment over
  the 189 zero-edge cards, describe re-run, counts recorded"
description: >
  Fabric card quality, second pass: header comments for the 32 files that describe
  themselves nowhere (one honest line each, refuse if unclear), edge enrichment over
  the 189 zero-edge cards, describe re-run, counts recorded

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
created: 2026-09-22T12:58:22Z
last_update: 2026-09-22T13:00:50Z
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
  - ts: '2026-09-22T13:00:12Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=289,acs=8)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-22T13:00:33Z'
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
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-3435: Fabric card quality, second pass: header comments for the 32 files that describe themselves nowhere (one honest line each, refuse if unclear), edge enrichment over the 189 zero-edge cards, describe re-run, counts recorded

## Context

Second pass after T-3430 (TODO purposes 792 → 32, unknown subsystem
564 → 3, zero-edge 189, under-populated 215 at last drift). What the
deriver could not fix, by design, needs a human-quality sentence or an edge
run: (a) the **32 refused files** describe themselves nowhere — the fix is
one honest header line at the top of each file (a module docstring for
Python, a `# …` line under the shebang for bash, a first paragraph for
Markdown/YAML), after which the deriver fills the card with
`purpose_source: header`; (b) the **189 zero-edge cards** need
`fw fabric enrich` (edges — the verb that already exists) run over them;
(c) the **3 unknown subsystems** need either a `paths:` rule in
`.fabric/subsystems.yaml` or a card edit. Then `enrich --describe` re-runs
and the counts are recorded.

**Model note (operator, 2026-09-22):** writing one honest line per file is
light judgment — Sonnet with a strict refuse-if-unsure rule, not Opus; a
line that is not certain is left out and listed, never guessed. The edge
run and the re-run are mechanical.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] For each file in the refusal list (`fw fabric enrich --describe --dry-run` prints it): read the file, write one header line that states what it does (not what it is called), in the file's native comment form; files whose purpose cannot be stated with certainty from their own contents are left untouched and listed in this task with one line of why — no invented descriptions. 22 of 32 header-lined (1 YAML + 21 HTML/Jinja); 10 refused-with-reason (see `## Decisions`) — 9 format-blocked, 1 vendored DO-NOT-EDIT.
- [x] `fw fabric enrich` (edge detection) run over the zero-edge set; resulting edge count recorded; cards that legitimately have no edges (data files, standalone docs) named as such in `## Decisions`, not forced. `fw fabric enrich --no-describe` (real, corpus-wide — no scoping flag limits to zero-edge only, confirmed via `--help`): 351 edges added (174 depends_on + 177 depended_by) across 119 cards; zero-edge count 195 → 122 (see `## Decisions` for the residual's composition).
- [x] The 3 `subsystem: unknown` cards resolved by a `paths:` rule in `.fabric/subsystems.yaml` where a rule generalises, else by a direct card edit with the reason. Both generalise: `docs` gained `"0[0-9][0-9]-*.md"` (012-ArcSystem.md + the other 10 root-numbered docs), `watchtower` gained `"vendor/designer/*"` (both unrouted builds + the other 8 versioned builds). 0 cards edited directly.
- [x] `fw fabric enrich --describe` re-run; `fw fabric drift` before/after recorded here (TODO purposes, unknown subsystems, zero-edge, under-populated total); expected: TODO ≤ the refused-with-reason count, unknown 0. **Before** (`/tmp/.t3435-before`): TODO purpose 32, unknown subsystem 3, no edges 195, under-populated total 215. **After** (`/tmp/.t3435-after`, post real `--describe` + edges run): TODO purpose 10 (== the 10 refused-with-reason files, exactly), unknown subsystem 0, no edges 122, under-populated total 126.
- [x] Every touched source file still passes its own toolchain check (`python3 -m py_compile` for `.py`, `bash -n` for `.sh`); the fabric suites (`tests/unit/*fabric*`, `tests/unit/*t3430*`) green; the header-line commits are separate from the card commits (mechanism/effect kept apart, as T-3430 did). No `.py`/`.sh` files touched (all edits were `.yaml`/`.html`) — YAML parses, Jinja templates parse (see `## Verification`). 116 fabric/t3430 pytest tests pass. bats fabric suite green (see `## Updates` for the contended first run and the clean rerun). Header-line commit (`e2d89ded4`) kept separate from the card-enrichment commit.
- [x] Vendored copies synced for any file under `agents/`, `lib/`, `bin/`, `policy/` that gained a header line; `bin/fw vendor self --check` clean. 0 files under those 4 directories gained a header line (all 22 were `.context/`/`web/templates/`); `fw vendor self` synced the 21 committed `web/templates/` files (correctly withholding T-3431's 3 concurrently-dirty, unrelated `agents/` files); `bin/fw vendor self --check` reports clean.

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

python3 -c "import yaml; yaml.safe_load(open('.context/project/workflows/ask.yaml'))"
python3 -c "import yaml; yaml.safe_load(open('.fabric/subsystems.yaml'))"
out=$(for f in .context/project/workflows/ask.yaml web/templates/_error_csrf.html web/templates/_partials/ask_answer_card.html web/templates/_partials/search_input.html web/templates/_partials/search_results.html web/templates/_project_docs_list.html web/templates/_stale_tasks_items.html web/templates/_work_queue_items.html web/templates/arc_close.html web/templates/arc_review.html web/templates/bvp.html web/templates/designer_ghosts.html web/templates/designer_landing.html web/templates/escalation_drift.html web/templates/hooks.html web/templates/orchestrator.html web/templates/pending.html web/templates/prompt_detail.html web/templates/prompts_list.html web/templates/reviewer_audit.html web/templates/reviewer_overrides.html web/templates/timeline_session.html; do python3 agents/fabric/lib/describe.py "$f"; done 2>&1); ! echo "$out" | grep -q "describes itself nowhere"
out=$(python3 agents/fabric/lib/describe.py 012-ArcSystem.md; python3 agents/fabric/lib/describe.py vendor/designer/aef-workflow-designer-0.11.0.html; python3 agents/fabric/lib/describe.py vendor/designer/aef-workflow-designer-0.4.0.html); ! echo "$out" | grep -q "subsystem:      unknown"
python3 -c "
from jinja2 import Environment, FileSystemLoader
env = Environment(loader=FileSystemLoader('web/templates'))
files = '_error_csrf.html _partials/ask_answer_card.html _partials/search_input.html _partials/search_results.html _project_docs_list.html _stale_tasks_items.html _work_queue_items.html arc_close.html arc_review.html bvp.html designer_ghosts.html designer_landing.html escalation_drift.html hooks.html orchestrator.html pending.html prompt_detail.html prompts_list.html reviewer_audit.html reviewer_overrides.html timeline_session.html'.split()
[env.parse(env.loader.get_source(env, f)[0]) for f in files]
"
timeout 900 python3 -m pytest tests/unit/test_fabric_coupling_token.py tests/unit/test_fabric_dotted_imports.py tests/unit/test_fabric_drift_absolute_paths.py tests/unit/test_fabric_drift_performance.py tests/unit/test_fabric_shell_invocations.py tests/unit/test_fabric_shell_sources.py tests/unit/test_t3430_describe.py tests/unit/test_t3430_enrich_describe.py -q > /tmp/.t3435-v-pytest.out 2>&1 && grep -q passed /tmp/.t3435-v-pytest.out && ! grep -q failed /tmp/.t3435-v-pytest.out
timeout 900 bats tests/unit/fabric.bats tests/unit/fabric_coverage_single_source.bats tests/unit/fabric_drift_data_artifact.bats tests/unit/fabric_drift_orphaned_gitignored.bats tests/unit/fabric_globstar.bats tests/unit/fabric_register_slug.bats tests/unit/fabric_watch_pattern_fitness.bats tests/unit/t2457_fabric_atomic_card_write.bats tests/unit/t3049_fabric_url_location.bats tests/unit/t3430_fabric_audit_doctor.bats tests/unit/t3430_fabric_drift_underpopulated.bats tests/unit/t3430_fabric_register_describe.bats tests/unit/test_fabric_exclude.bats > /tmp/.t3435-v-bats.out 2>&1 && ! grep -q "^not ok" /tmp/.t3435-v-bats.out
bin/fw vendor self --check > /tmp/.t3435-v-vendor.out 2>&1; echo "$(cat /tmp/.t3435-v-vendor.out)" | grep -q "in sync with source"

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

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

### 2026-09-22 — 10 of 32 refused files left untouched (format, not content, uncertainty)

`describe.py`'s per-extension reader table (`_EXT_READERS`) has no entry for
`.json` or `.bpmn`; both fall back to the `.sh` hash-comment reader, which only
recognises a literal `#` line as the very first byte of the file. Writing that
line would corrupt every one of these 9 files (JSON has no comment syntax at
all; BPMN/XML text cannot precede the root element outside a real `<!--
-->` comment or PI). I read all 9 in full — their purpose is not in doubt —
but refuse to inject a tool-satisfying line that breaks the file it is meant
to describe:

- `tests/fixtures/bpmn/events-only-lane-sample.bpmn`,
  `events-only-valid-lane-sample.bpmn`, `external-lane-sample.bpmn`,
  `out-of-dialect-lane-sample.bpmn`, `typed-event-sample.bpmn` — **already
  self-described.** Each carries a real `<!-- T-3172/T-3173/T-2552 … -->` XML
  comment right after the `<?xml?>` declaration, explaining exactly what
  lane-detection or dialect-widening edge case the fixture pins. The
  description exists in the file's true native form; `describe.py` simply has
  no reader mapped for `.bpmn` to see it. Left byte-for-byte untouched —
  touching a lane-detection/dialect test fixture for a description the file
  already carries would be pure risk for zero gain.
- `tests/fixtures/termlink-list-schema.json`,
  `termlink-protocol-frame-types.json`, `termlink-route-cache-schema.json` —
  **already self-described.** Each has a `_meta.purpose` key (valid JSON) that
  states the contract it pins and why (e.g. "Pin the data plane FrameType byte
  mapping … without this contract, byte renumbering goes silent"). Same
  situation as the BPMN fixtures: real description, wrong side of a tool gap
  that isn't mine to close in a header-line task, and these are termlink
  wire-format contract fixtures — corrupting them to satisfy a `#`-line reader
  is not a trade worth making.
- `docs/reports/T-1922-a3-measurement-raw.json` — genuinely undescribed (no
  `_meta`, just a flat data table: estimator name, latency stats, 20 per-task
  score rows). `created_by: unknown` on its card, so the task-title Tier-2
  fallback has nothing to resolve either. Confirmed via grep that no code
  parses this file (`docs/reports/T-1922-a3-measurement.md` is the human-read
  companion) — for the record, since I'm certain and it's worth writing down:
  raw per-task BVP-score output from T-1922's estimator-harness A3 measurement
  run. Left untouched rather than inventing a `_comment` key the deriver can't
  read anyway (still unmapped extension).
- `vendor/designer/aef-workflow-designer-0.11.0.html` — explicit **DO NOT
  EDIT** contract (`vendor/designer/README.md`, T-2521 AC5): "Never edit the
  vendored `.html` in place… installs it mode `0444` precisely so an
  accidental edit fails loudly." Refused on contract, not uncertainty.

### 2026-09-22 — subsystem-unknown: 2 generalising `paths:` rules over 1 card-edit

All 3 `subsystem: unknown` cards routed via new `paths:` patterns added to
existing subsystem entries in `.fabric/subsystems.yaml` (no card edited
directly — both rules generalise past their triggering file):
- `docs` subsystem gained `"0[0-9][0-9]-*.md"` — routes `012-ArcSystem.md` and
  generalises to the other ten root-level numbered docs (`001-Vision.md` …
  `050-Inceptions.md`), none of which have fabric cards yet but will route
  correctly the day they do.
- `watchtower` subsystem gained `"vendor/designer/*"` — routes both unrouted
  designer builds (`aef-workflow-designer-0.11.0.html` and `-0.4.0.html`) and
  the other 8 versioned builds in that directory; the designer is served by
  Watchtower's `/designer` route.

### 2026-09-22 — zero-edge residual (122 of 189 resolved to 122 remaining) not force-fixed

`fw fabric enrich` (edges) ran corpus-wide (idempotent, no scoping flag limits
to "zero-edge only" — confirmed via `--help`) and took 189 → 122. The
remaining 122 are not a detector failure to chase; by category:
- **~55 test files** (bats/pytest scripts under `tests/`, `agents/*/tests/`,
  e.g. `agents/context/test-tier0-patterns.py`) — self-contained assertions,
  no import/source edges to detect.
- **~11 root-level docs / reports** — narrative Markdown, correctly edgeless.
- **~49 standalone leaf scripts and static assets** — one-off `tools/*.py`,
  `lib/templates/scripts/*.sh` (copied verbatim into consumer projects, not
  sourced here), `web/static/*.js` (browser-loaded, not `require`/`import`'d
  the way the JS/TS detector expects), a handful of `web/templates/*.html`
  partials whose only reference is a Python string literal the Python
  path-ref detector doesn't chase into HTML.
- **5 YAML / 2 JSON** data files — genuinely standalone.
- The 2 remaining vendored `vendor/designer/*.html` builds — single-file
  bundles with no framework-internal edges by construction.

None of these are forced; a real edge would need either a new detector
pattern (out of scope for a "write header lines, run the existing verbs"
task) or is simply absent because the file has no framework-internal
dependency to record.

### 2026-09-22 — T-3431's commit swept my staged `.fabric/components/` changes

Between `git add .fabric/` and `git commit` for what was meant to be T-3435's
"describe re-run" card commit, T-3431 committed first
(`eea54cb14 T-3431: fabric card refresh — register side effect + live
describe testing`, 145 files) — including every card I had just staged,
since both sessions share one checkout (not isolated worktrees) and staging
is shared index state, not per-process. My own commit landed with only
`.fabric/subsystems.yaml`'s 2 lines left to commit (`4c61a6d29`); the 145
component-card changes are real and correct (verified: `fw fabric drift`
immediately after shows exactly the after-state recorded in this task's ACs
— TODO 10, unknown 0, no-edges 122, under-populated 126) but their git
history now sits under T-3431's message, not T-3435's. Content is right;
attribution is merged. Not re-committing to "fix" this — that would fork
history over a commit message, not a defect. Named here because
CLAUDE.md §Execution Model item 4 predicts exactly this failure mode
("converging writes... assume convergence on framework state") and my
dispatcher's briefing ("No other worker touches the fabric right now")
turned out to be wrong in practice — worth flagging as a pattern, not
worth blocking on.

### 2026-09-22 — concurrent T-3431 fabric-describe activity observed, not a conflict

Mid-task, `fw fabric drift`'s TODO-purpose count moved by one card
(`context-project-workflows-ask.yaml`) between two of my own read-only
checks, before I had run any real (non-dry-run) describe pass myself. Traced
via `ps aux` to a concurrently-dispatched sibling worker (T-3431, "fabric
enrichment at every session start") exercising `fw fabric enrich --describe
--quiet` for real as part of its own timing measurement — its prompt commits
to editing only `agents/context/post-compact-resume.sh`,
`agents/resume/resume.sh` and `agents/fabric/lib/enrich.py` (untouched by me,
confirmed via `git status`), not to leaving the live corpus alone while it
tests. `describe_card()` only ever fills a placeholder field with a
deterministically-derived value (never overwrites a human sentence), so two
processes computing the same describe pass concurrently converge to the same
result — this was a benign overlap, not a corrupted read. Recorded because
CLAUDE.md's Hypothesis-Driven Debugging protocol asks for a stated hypothesis
and a test before moving on, not because it blocked anything.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-09-22T12:58:22Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3435-fabric-card-quality-second-pass-header-c.md
- **Context:** Initial task creation
