---
id: T-4350
name: "Incremental vector reindex writes a full second copy of the index every run
  (11.7 GiB/h disk writes on .107): update in place"
description: >
  dimitri-mint-dev T-135 (msg fcd9a929, measured 2026-10-19): cron wrote 1,740 GiB
  in 6 d 4 h; fw index reindex runs hourly in 8 projects, each 'incremental' run with
  3-14 changed files takes 26-162 s because web/embeddings.py:518 writes a second
  full-size copy of the index beside the live one (both build paths). Copies land
  in a Timeshift-snapshotted subvolume (old blocks pinned), disk 87% full, btrfs flush
  kworkers in D state, io PSI full avg10 up to 12. Fix: incremental path updates in
  place — delete/insert only changed chunks in one SQLite transaction with WAL so
  readers keep the old snapshot until commit; keep copy+swap only for a full rebuild
  (model/schema change, corruption).

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [index, performance, io]
components: [tests/unit/test_incremental_reindex.py, web/embeddings.py]
related_tasks: []
origin: {kind: "peer", source: "dimitri-mint-dev"}
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
created: 2026-10-18T22:57:14Z
last_update: '2026-10-19T23:15:29Z'
date_finished: 2026-10-19T10:39:57Z
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
  - ts: '2026-10-18T23:00:45Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=287,acs=4)
    rubric_sha: e4a00f38e801
  - ts: '2026-10-19T23:15:29Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 2
      effort: 8
    rationale: blast_radius=3 (2-components); tier=2 (workflow:build); effort=8 
      (lines=356,acs=10)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-10-18T23:01:55Z'
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

# T-4350: Incremental vector reindex writes a full second copy of the index every run (11.7 GiB/h disk writes on .107): update in place

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Reproduced on a temp index (not the live one): an incremental run with 1 changed file copies the whole database (copy2 to `.reindex.<pid>.tmp`) and the scratch is the same size as the index; recorded in the Updates section with before/after bytes
- [x] Regression test in `tests/unit/test_incremental_reindex.py` asserts an incremental run never creates a full-size scratch copy (no `.reindex.*.tmp` created, and no `shutil.copy2` of DB_PATH); it FAILS on the pre-fix code and PASSES after the fix (red run recorded in Updates)
- [x] `reindex_incremental()` in `web/embeddings.py` updates the live database in place for a small delta (≤ `IN_PLACE_MAX_FILES` = 32 changed files, against an existing file_state baseline): changed/removed rows are deleted and re-inserted in ONE sqlite transaction on DB_PATH; the commit is the only point where the new state is visible. Journal mode stays the default rollback journal, not WAL (see Decisions)
- [x] Atomicity preserved: the existing ATOMIC tests (`test_a_run_killed_mid_way_does_not_advance_the_manifest`, `test_a_killed_run_leaves_the_previous_index_still_serving`) and the disk-guard tests in `tests/unit/test_t3860_reindex_disk_guard.py` still pass
- [x] Copy+swap is kept for the full-rebuild paths: `build_index()`, the bootstrap-baseline, large deltas (> 32 files) and the OBS-258 resume path still go through the scratch copy and `os.replace`
- [x] Disk before/after measured on a temp index for the incremental run: scratch copy 11,825,152 B → 0 B; process write_bytes 12,939,264 B → 544,768 B
- [x] `bin/fw vendor self --check` is clean after the change (web/ is vendored)

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
- [ ] [REVIEW] Watchtower search results still look right after the reindex change
  **Steps:**
  1. Open the Watchtower search page (`cd /opt/999-Agentic-Engineering-Framework && bin/fw watchtower url` prints the base URL; append `/search?q=release decision`)
  2. Look at the result list
  **Expected:** relevant tasks and learnings listed with titles and snippets, as before; no error panel or empty list
  **If not:** note the query and what is wrong; the reindex change is in web/embeddings.py reindex_incremental (T-4350)

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

python3 -m pytest tests/unit/test_incremental_reindex.py tests/unit/test_t3860_reindex_disk_guard.py -q > .context/working/T-4350-pytest.out 2>&1 && ! grep -q failed .context/working/T-4350-pytest.out && grep -q passed .context/working/T-4350-pytest.out
python3 -m pytest tests/unit/test_incremental_reindex.py -q -k no_full_size_scratch > .context/working/T-4350-regress.out 2>&1 && grep -q passed .context/working/T-4350-regress.out
bin/fw vendor self --check
bin/fw watchtower current

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

## Visual Verification

Evidence for the `[REVIEW]` criterion, captured 2026-10-20 by a non-producer worker
(`fw ux shots T-4350 "search=<watchtower>/search?q=release%20decision"`). Screenshots:
`.context/visual/T-4350/search@{1024,1440,1920}.png`. The page shows **hybrid results**
("Found 20 results for release decision (hybrid) — 13449 docs indexed, 749004 chunks"),
not the T-4458 keyword-fallback notice; no error panel, list not empty.

| state | control | 1024 | 1440 | 1920 | note |
|-------|---------|------|------|------|------|
| search | result list | ok | ok | ok | 20 results, hybrid mode; release/decision tasks, decisions.yaml, fabric cards, one episodic |
| search | result titles | ok | ok | ok | T-ID + title per result; the episodic T-4364 result's title renders as a `====` separator line (pre-existing title extraction, not the reindex) |
| search | result snippets | ok | ok | ok | snippet per result with query terms bolded; one filter chip reads "(19)" with an empty label |
| search | error/notice area | ok | ok | ok | no error panel and no keyword-fallback notice: the hybrid path answered inside the deadline |

## RCA

**Symptom:** every hourly `fw index reindex` run that changes 3-14 files writes a full second copy of the vector index (`vec.db.reindex.<pid>.tmp`, same size as `vec.db`) before embedding anything. Reported on dimitri-mint-dev (T-135): 1,740 GiB written in 6 d 4 h, 26-162 s per "incremental" run, btrfs flush kworkers in D state, disk 87% full. Reproduced on a 11.8 MB temp index with a 1-file change: scratch copy = 11,825,152 B (= index), process write_bytes delta = 12,939,264 B.

**Root cause:** `web/embeddings.py:1114` — `reindex_incremental()` makes its working copy with `shutil.copy2(DB_PATH, tmp_path)` on EVERY non-resumable run (the resume branch at :1112 only covers a parked `.reindex.resume`). The copy exists to give the run an atomic swap (`os.replace` at :1313), but the incremental diff is a few chunks; copying the whole database to carry them is the cost. The same copy+swap design was written for the 29-58 h bootstrap (OBS-258) and was applied unchanged to the steady-state path.

**Why structurally allowed:** the disk-guard (T-3860) checks free space for the copy, so it passes on a big disk and treats the copy as the cost of doing business; `test_incremental_only_reembeds_changed_files` pins how much is *embedded*, not how much is *written*; nothing measures bytes written per run. The ATOMIC tests pin the swap's outcome (old index survives a kill), so they stay green whether or not a copy is made.

**Prevention:** `test_incremental_run_has_no_full_size_scratch_copy` (tests/unit/test_incremental_reindex.py) fails if an incremental run copies the live database or leaves a scratch file while embedding. The fix changes the incremental path to in-place writes in one transaction under WAL; copy+swap stays only for the full-build and bootstrap/resume paths. The atomicity guarantee is preserved by SQLite (readers see the previous snapshot until commit; a killed run rolls back), and the existing ATOMIC tests remain the check on it.

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
**Rationale:** The hourly incremental reindex no longer writes a full-size scratch copy of the index for small deltas (≤32 files): it updates in one SQLite transaction, where commit is the publish and a killed run rolls back. Large deltas, the bootstrap and the resume path keep copy plus os.replace. Search is served from the same index, so the one human check is that results still look right.
**Evidence:**
- Temp index, one changed file: scratch copy 11,825,152 B → 0 B; process write_bytes 12,939,264 B → 544,768 B
- Regression test test_incremental_run_has_no_full_size_scratch_copy red before, green after; 41 passed in the two reindex files, 68 in adjacent embed suites
- Live search after the change (Watchtower restarted, `watchtower current` exit 0): /search?q=release+decision returns HTTP 200 with 40 distinct task references

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

### 2026-10-19 — in place for small deltas, copy kept for large ones
- **Chose:** the copy is skipped only when the run changes ≤ `IN_PLACE_MAX_FILES` (32) files against an existing file_state baseline; the bootstrap-baseline, any parked resume and any larger run keep copy + `os.replace`.
- **Why:** the copy-based tests pin OBS-258: a 120-file run must park and resume across kills. An in-place run that dies is rolled back, so for a large run the in-place mode would discard hours of work. Small runs (3-14 files in the reported fleet) lose nothing on a rollback.
- **Rejected:** always in place — breaks OBS-258 resume (`test_a_partial_run_parks_its_work_instead_of_discarding_it`). Keep the copy and only trim it — a copy is still a full index write.
- **Chose rollback journal, not WAL:** with WAL a `copy2` of the live file misses frames still in `-wal`, and a swap would leave a stale `-wal` beside the new file, so WAL would have to be handled in the copy path too. Default journal keeps readers on the old snapshot until commit and sqlite rolls back a killed run. A 64 MB page cache (`PRAGMA cache_size`) keeps a normal run from spilling dirty pages into the live file, since a spill takes the exclusive lock readers wait on.
- **Chose:** `index_one` keeps its lock-skip behaviour. The in-place reindex holds the same lock, so its concurrency argument is unchanged.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-10-18T22:57:14Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-4350-incremental-vector-reindex-writes-a-full.md
- **Context:** Initial task creation

### 2026-10-19T09:44:52Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-10-19 — reproduction, red run, fix (worker w4350)
- **Repro (temp index, 300 files, `.context/working/T-4350/repro.py`, pre-fix):** index 11,825,152 B; one changed file → scratch copy 11,825,152 B; process write_bytes delta 12,939,264 B.
- **Red run (pre-fix), new test:** `python3 -m pytest tests/unit/test_incremental_reindex.py -q -k no_full_size_scratch` → `1 failed`: "incremental run copied the whole live index to …/vec.db.reindex.4009080.tmp".
- **Fix:** `web/embeddings.py` — `_incremental_delta()` (read-only diff vs file_state), `IN_PLACE_MAX_FILES = 32`, in-place single transaction branch in `reindex_incremental()`; docstrings of `reindex_incremental` and `index_one` updated.
- **Existing tests that pinned the copy path for a small delta** (`test_scratch_file_is_per_process`, `test_swap_is_refused_if_the_scratch_file_was_replaced`, two `test_t3860` mid-copy tests) now force the copy path with `IN_PLACE_MAX_FILES = 0` and make a real change so the copy is reached. The assertions are unchanged.
- **Green:** `test_incremental_reindex.py` + `test_t3860_reindex_disk_guard.py` → 41 passed; with `test_embed_health.py` and `test_t4305_embeddings_empty_state.py` → 68 passed; bats t1719, t3783 reach/health, t3058, t3045 → 0 not ok (t3045: 1 skip, not investigated).
- **Disk after (same temp index):** scratch copy 0 B; process write_bytes delta 544,768 B (was 12,939,264 B).
- **Vendor:** `FW_VENDOR_ONLY="web/embeddings.py" bin/fw vendor self` (the full sync withheld other workers' in-flight files: lib/issues_lag.py, agents/audit/audit.sh, lib/issues.py). `bin/fw vendor self --check` clean.
- **Watchtower:** `web/` changed → `bin/fw watchtower restart` (PID 1273447 → 291230); `bin/fw watchtower current` exit 0.
- **Not done:** no live-index run; the hourly job on the live host will exercise the in-place path on its next firing. Not closed (per brief).

## Reviewer Verdict (v1.5)

- **Scan ID:** R-7d0014d7
- **Timestamp:** 2026-10-19T10:41:19Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#3 (Agent)** — `reindex_incremental()` in `web/embeddings.py` updates the live database in place for a small delta (≤ `IN_PLACE_MAX_FILES` = 32 changed files, against an existing file_state baseline): changed/remove
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/embeddings.py in: `reindex_incremental()` in `web/embeddings.py` updates the live database in place for a small delta (≤ `IN_PLACE_MAX_FILES` = 32 changed files, agains`

### 2026-10-19T10:39:57Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
