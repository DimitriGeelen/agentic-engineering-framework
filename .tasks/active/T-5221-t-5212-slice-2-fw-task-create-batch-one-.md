---
id: T-5221
name: "T-5212 slice 2: fw task create-batch (one writer shared with create-task) and
  fw arc instantiate (an arc plus its tasks from a template and parameters, in one
  call)"
description: >
  Build slice 2 of inception T-5212 (GO 2026-11-18), from 1409's prototype; slice
  1 was T-5217.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
# write_set:                      # T-3512: optional — globs (relative to PROJECT_ROOT)
#                                 # naming the files this task intends to write. Declared
#                                 # at CAPTURE, unlike components: which the framework
#                                 # resolves from git history at close. Feeds TWO things:
#                                 #   1. `fw write-set check T-A T-B` — without it the
#                                 #      comparison has nothing to compare and every real
#                                 #      pair exits 2 (undecidable). 0 of 3032 tasks
#                                 #      declared it, so that gate has never had an input.
#                                 #   2. BVP blast_radius before close — the 0.6-weighted
#                                 #      cost term, unavailable for 85% of rankable tasks
#                                 #      because components: only exists once the task is
#                                 #      finished (T-3471).
#                                 # Example: write_set: ["lib/bvp.sh", "tests/unit/t*_bvp*"]
#                                 # An EMPTY list is a real declaration ("writes nothing"),
#                                 # which is not the same as omitting the field. Omitted
#                                 # means unknown, and unknown must never score as cheap.
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
created: 2026-11-18T07:26:01Z
last_update: '2026-11-18T07:30:24Z'
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
bvp_scores_proposed:
  - ts: '2026-11-18T07:26:09Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-11-18T07:30:24Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=318,acs=8)
    rubric_sha: e4a00f38e801
---

# T-5221: T-5212 slice 2: fw task create-batch (one writer shared with create-task) and fw arc instantiate (an arc plus its tasks from a template and parameters, in one call)

## Context

<!-- All four parts are required before source edits (T-4907). Plain language; link design docs for substantial tasks. -->
**Background / trigger:** This is build slice 2 of inception T-5212 (GO 2026-11-18; research docs/reports/T-5212-batch-task-creation.md, IW-3 answered "all yes"). Slice 1 (T-5217, shipped in be.58) gave one allocator with block reservation and a ledger. 1409 creates one arc plus 13 tasks per municipality, from a class file and a template arc. That is 14 separate fw calls today: 29.7 s per unit with one view, 52 s with 24 (sidecar 6c1880ec). Their prototype's create-batch did it in 2.6 s per unit.

**Problem / hypothesis:** Even with slice 1, each task is still its own create-task process, and its per-call work (validation, hooks, side effects) runs every time. create-task.sh renders the task file inline, so a batch path would otherwise be a second writer of task files, the same class of problem as the two allocators.

**Goal:** Create an arc and its tasks in one call, through one task-file writer, built on slice 1's allocator.
- **One writer.** The task-file rendering in agents/task-create/create-task.sh moves into one module (1409 used render_task.py). create-task calls it, unchanged in output.
- **`fw task create-batch --spec F.jsonl --purpose <text>`.**
  - It validates every entry first, by the same rules as create-task, and refuses the whole batch on any invalid entry.
  - It makes one reservation (fw_id_allocate N) and writes all files through the shared writer, each file opened exclusively.
  - It marks the reservation created in the ledger at the end.
  - Inception tasks, --start/focus and --origin are refused in a batch.
  - Side effects that only need to run once run once per batch.
- **`fw arc instantiate <template-arc> --param k=v ... [--dry-run]`.** It creates the arc from a template arc plus parameters (arc ids may be fixed names from the parameters, as at 1409), then its tasks through create-batch, in one call. With --dry-run it prints what would be created and writes nothing.

All verb and flag names are in English.

**Expected outcome:** An arc with 13 tasks is created in one call, in under 3 s per unit on a repo with several views. The files are identical to the ones create-task writes one at a time.

## Acceptance Criteria

### Agent
- [x] Task-file rendering lives in one module, used by both create-task and create-batch. A byte-compare test shows create-task's output unchanged apart from id and timestamp.
- [x] `fw task create-batch` validates every entry before reserving, makes exactly one reservation per batch, writes files that are byte-identical to single creates apart from id and timestamp (test with 13 entries), and refuses inception, --start and --origin entries
- [x] A batch killed mid-write leaves no partial file and no reissued id, and `fw task id reconcile` reports the incomplete reservation (test)
- [x] `fw arc instantiate` creates an arc and its tasks from a template plus parameters in one call. --dry-run writes nothing. The created arc and tasks pass `fw audit` structure checks (test in a tmp repo).
- [x] Measured in a tmp repo with 24 worktrees: one arc plus 13 tasks takes under 3 s per unit (numbers recorded in the task)
- [x] Existing create-task, arc, T-5217 allocator, upgrade_fresh_machine_simulation and audit suites pass, as do `bin/fw test invariants` and `bin/fw vendor self --check --task T-5221`. Also grep tests/ for tests that depend on create-task's inline rendering.

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

<!--
  Render-touching build tasks (web/templates, web/static, web/blueprints, web/shared.py,
  web/app.py …) add a section headed "Visual Verification" (level-2 heading) after
  Verification, with one checklist table — the check-visual-verification gate reads it
  at commit time (T-4213; T-4202 GO):

    | state | control | 1024 | 1440 | 1920 | note |
    |-------|---------|------|------|------|------|
    | toolbar | Load | ok | ok | ok | |

  Cells: ok / clipped / hidden / overlap / unreachable (non-ok needs a note). Each
  listed state needs screenshots at every UX_SHOT_WIDTHS width:
  fw ux shots <T-ID> <state>=<URL>. This comment is inert: the gate ignores it.
-->

## Verification

<!-- T-4906: guidance is an HTML comment so GitHub does not render its `#` lines as
     headings; the completion gate strips HTML comments before running anything.
     Write your commands BELOW this comment, one per line.
# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
# Build/refactor/decommission tasks with NO command here are refused. If nothing can be
# run, add the line `# verification: none — <why nothing can be run>`; it is serviced
# (queued for review: add a check / other evidence / accept). See docs/reports/T-4024-servicing-loop.md.
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
# THE EXCEPTION — capture first, grep the capture with a HERE-STRING:
#     out=$(cmd 2>&1); grep -q "PATTERN" <<<"$out"
# No pipe, so no SIGPIPE at any size. Do NOT write `echo "$out" | grep -q PAT`:
# it is not safe "below 64 KB" as this file used to say (T-4921, 832 T-1340). The
# builtin writes a multi-line value line by line, so grep -q can exit before the
# last write at ANY size (measured 4 in 3,000 for a 40-line value), and above the
# pipe buffer it fails every time (T-2743: 146,366-byte page, 3/3). In a gate that
# allows on "no match" that is a fail-OPEN (T-4920: the Tier 0 pre-filter).
# The capture still discards cmd's exit code, so a 404 yields an empty capture that
# grep merely fails to match rather than a failed line — prefer THE DEFAULT above.
#
# TEST RUNNERS need a guard either way (T-2738). `set -e` is suppressed inside the
# `if` condition the gate runs each line in, so in `cmd1; cmd2` only cmd2 is the
# verdict — and the pass marker you grep for survives a partial failure: a suite
# printing "3 failed, 9 passed" satisfies `grep -q "9 passed"`, and generalising
# to `grep -qE "[0-9]+ passed"` matches the same output. Keep the exit code:
#     python3 -m pytest <file> -q > /tmp/.out 2>&1 && grep -q passed /tmp/.out
# or add the guard the exit code used to supply:
#     out=$(python3 -m pytest <file> -q 2>&1); grep -q passed <<<"$out" && ! grep -q failed <<<"$out"
#     out=$(bats <file> 2>&1); grep -q '^ok 1 ' <<<"$out" && ! grep -q '^not ok' <<<"$out"
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
# Vendored-path hint (T-3236, T-4419): if you edited bin/fw, lib/, agents/, policy/,
# web/, tools/ or .tasks/templates/, run `bin/fw vendor self` and add
#     bin/fw vendor self --check --task T-XXXX
# (your own task id). It checks only the files your commits changed, so another
# worker's uncommitted edit does not block your close; that drift is listed as
# "in flight, not this task". The whole-tree `--check` stays for audit/pre-push.
-->
timeout 900 bats tests/unit/t5221_create_batch.bats > /tmp/.t5221.out 2>&1 && ! grep -q "^not ok" /tmp/.t5221.out
test "$(grep -c '# skip' /tmp/.t5221.out)" -eq 0
timeout 900 bats tests/unit/create_task.bats tests/unit/t5217_id_allocator.bats tests/unit/arc_create_start_flag.bats > /tmp/.t5221b.out 2>&1 && ! grep -q "^not ok" /tmp/.t5221b.out
timeout 900 bats tests/unit/upgrade_fresh_machine_simulation.bats > /tmp/.t5221c.out 2>&1 && ! grep -q "^not ok" /tmp/.t5221c.out
python3 -m pytest -q tests/unit/test_task_create_description_yaml.py > /tmp/.t5221d.out 2>&1 && grep -q passed /tmp/.t5221d.out
bin/fw vendor self --check --task T-5221

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

### 2026-11-18 — one writer: lib/render_task.py, validation in lib/task-create-rules.sh
- **Chose:** lift create-task's three inline writers (inception template, default template, inline heredoc fallback) verbatim into `lib/render_task.py` (`write-one` for create-task, `write-batch` for create-batch); lift the name/type/horizon/owner/recursion checks into `lib/task-create-rules.sh` (functions return 1 instead of exiting, messages byte-identical). Every file is written to `<tasks>/.writing/<pid>-<rand>.<name>` and hard-linked into `active/`: link(2) is exclusive and atomic, so a kill leaves only complete files. Pinned by goldens written by the pre-change create-task (commit 7ef993ddc): `tests/fixtures/t5221/golden/` (default, refactor+start, inception, inline fallback; frozen templates in `tests/fixtures/t5221/templates/`, generator `gen.sh`).
- **Why:** one writer of task files, the same rule as one allocator. Shell rules stay shell so create-task's messages and exit codes do not move.
- **Rejected:** re-implementing validation in Python for the batch (two rule sets that drift); a plain `open(path, 'w')` in the batch (a kill leaves a half file).

### 2026-11-18 — create-batch: arc membership and what runs once
- **Chose:** spec keys name, description, type, owner (required), horizon, tags, related, arc_id. `arc_id` is the only addition over create-task and adds one `arc_id:` line after `related_tasks:` (T-1849 membership); entries without it are byte-identical to create-task. Refused: inception type, keys start/status/focus/origin/recommendation/rationale/id, flags --start/--origin. Once per batch: library loading, the lock and the union-scan check (one `fw_id_allocate N`), template reads, one python start for rendering, one ledger append of the created rows (`fw_id_ledger_created` now takes several ids). Max 100 entries (FW_ID_BLOCK_MAX).
- **Why:** create-task has no per-task side effects a batch needs (origin, recommendation block and --start focus are all refused), so the per-call cost was process start-up and the scan.
- **Rejected:** arc membership by `arc:<slug>` tag (legacy form, T-1850 migrates away from it).

### 2026-11-18 — template arc format (fw arc instantiate)
- **Chose:** a YAML file, `.context/arcs/templates/<name>.yaml` or any path (arc readers glob `arcs/*.yaml`, so the subdirectory is never read as an arc):
  ```yaml
  template: municipality-scan          # informational
  params: {municipality: null, region: west}   # or a list (all required); null = required
  arc:
    id: "scan-{municipality}"          # the arc slug; a fixed name from a parameter is fine
    name: "Municipality scan: {municipality}"
    description: "..."
    headline_mechanic: "An analyst runs the scan for {municipality} and sees ..."
    start: true                        # optional: created in-progress
    anchor: 1                          # optional: 1-based task index -> anchor_task
  tasks:                               # create-batch entries (same keys, same rules; no arc_id)
    - {name: "Collect sources for {municipality}", description: "...", type: build, owner: agent, horizon: next, tags: [scan, "{region}"]}
  ```
  `{name}` placeholders in any string or list item; `{{`/`}}` are literal braces. An undeclared placeholder, a missing required parameter and an unknown `--param` are all errors, listed together. Order: expand and validate everything (arc id free, headline mechanic, every task via `create-batch --dry-run --new-arc`) → `arc_create` → one `create-batch` (purpose `arc:<slug>`) → `anchor_task`. If no task got written the arc file is removed again. Fixture: `tests/fixtures/t5221/municipality-scan.yaml` (13 tasks).
- **Why:** smallest shape that covers 1409's class-file + template-arc case; arcs and tasks still go through their one writer each.
- **Rejected:** `create-batch --arc-spec` (operator answer (2) in T-5212 chose `fw arc instantiate`); Python `str.format` (any brace in a description would break).

### 2026-11-18 — measured
- tmp repo, 30 seed tasks, 24 worktrees (25 views), FW_ID_CHECK on: `fw arc instantiate` of one arc plus 13 tasks took 931 ms, 950 ms and 991 ms over three runs (bats `timing` case and smoke runs) — under 1 s per unit against 29.7-52 s before and 1409's 2.6 s. create-batch alone, 13 tasks, one view: 0.33 s.

### 2026-11-18 — suites run before report
- 130 bats files matching arc|audit|create_task|t5217|t4189|t4841|t100202|work_on|upgrade_fresh_machine_simulation (incl. _vendored)|t5221 plus 308 pytest (arc/audit/task_create): all green, no skips. `bin/fw test invariants`: 166/166 after fixing the T-5067 temp-name finding in render_task.py. `bin/fw vendor self --check --task T-5221`: in sync. tests/ grep for create-task's inline rendering (TC_TEMPLATE, indent_block, set_key, generate_slug, format_yaml_array): no test depends on it; test_task_create_description_yaml.py drives the script and passes.

### 2026-11-18 — independent review (docs/reports/T-5221-independent-review.md): fixed and left
- **Fixed, each with a test seen failing first** (t5221_create_batch.bats "review N"): 1 link() fallback to O_CREAT|O_EXCL+fsync on EPERM/ENOTSUP/EXDEV/EMLINK/ENOSYS (exclusive kept; only atomicity against a kill is lost there); 2 flow items quoted when YAML would not read them back as themselves, list items never comma-split, frontmatter parsed before any write and per entry before the reservation; 3 no rmdir of `.writing/`; 4 portable checked anchor write; 7 `.writing/` gitignored (repo + a self-written `*` .gitignore for consumers); 10 arc_id must be a slug/arc-NNN; 11 rolled-back arc-NNN recorded in `.context/arcs/.retired-ids` and never reissued.
- **Fix 2 choice:** quote only what does not round-trip, rather than quoting every item. Ordinary tags keep create-task's bytes (goldens unchanged). A bare scalar YAML types as int/bool (`2026`, `yes`) stays bare, as it always was; changing that would move create-task output and is not part of this finding.
- **5 (format_yaml_array vs old xargs):** left. The differences are improvements; the one regression it names (a leading quote producing unparseable frontmatter) is now covered by fix 2.
- **6 (newline in a name injects body):** left. Pre-existing in create-task; refusing control characters is a create-task rule change for its own task, not a slice-2 regression.
- **8 (_sweep across PID namespaces):** left. Needs a shared bind mount across containers plus a sweep inside the write window; rare, and an age guard is a design choice better made with evidence.
- **9 (multi-row ledger append can tear):** left. Low probability (>4 KB append racing another writer); the reconcile pass reads the ledger and reports what it cannot parse.
- **12 (minor: INCEPTION_TEMPLATE hint path, `shift 2` with no value, spec re-read between validate and write):** left. Cosmetic or operator-self-inflicted; none corrupts a task file.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-11-18T07:26:01Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-5221-t-5212-slice-2-fw-task-create-batch-one-.md
- **Context:** Initial task creation

### 2026-11-18T07:26:07Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
