---
id: T-3860
name: "HIGH: hourly incremental reindex (T-3783, seeded to every consumer) writes
  a full copy of the vector index (*.reindex.<pid>.tmp, ~1.5 GB) with no free-space
  pre-check and no cleanup on failure — filled the root disk 100% on ring20-dashboard's
  production host (2026-10-04 ~22:20) and left a 464 MB orphan tmp"
description: >
  ring20-dashboard T-2462 post-upgrade review finding 8 (2026-10-05). Fix: free-space
  pre-check (need >= index size + margin, refuse loudly otherwise), trap-cleanup of
  the tmp on any exit, sweep stale *.reindex.*.tmp / *.building at start, and a health-check
  WARN on orphans. Relates T-3786 (atomic build via .building).

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: [bin/fw, lib/vector_index_health.py, web/embeddings.py]
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
created: 2026-10-05T07:38:54Z
last_update: '2026-10-06T07:45:31Z'
date_finished: 2026-10-05T07:56:00Z
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
  - ts: '2026-10-05T07:43:36Z'
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
cost_estimate_proposed:
  - ts: '2026-10-05T07:45:27Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=276,acs=8)
    rubric_sha: e4a00f38e801
  - ts: '2026-10-06T07:45:31Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 2
      effort: 8
    rationale: blast_radius=3 (3-components); tier=2 (workflow:build); effort=8 
      (lines=329,acs=9)
    rubric_sha: e4a00f38e801
---

# T-3860: HIGH: hourly incremental reindex (T-3783, seeded to every consumer) writes a full copy of the vector index (*.reindex.<pid>.tmp, ~1.5 GB) with no free-space pre-check and no cleanup on failure — filled the root disk 100% on ring20-dashboard's production host (2026-10-04 ~22:20) and left a 464 MB orphan tmp

## Context

ring20-dashboard T-2462 finding 8. Code: `web/embeddings.py` (`reindex_incremental`, `build_index`, new scratch/disk helpers), `bin/fw` index route (signal forwarding), `lib/vector_index_health.py` (`check_disk`). Fixture tests: `tests/unit/test_t3860_reindex_disk_guard.py`.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Free-space pre-check: before `reindex_incremental()` copies the index (and before `build_index()` builds), free bytes on the index filesystem are compared with the current index size plus max(20%, 500 MB) (margin only when resuming from a parked file, which needs no copy); short of that the run raises `InsufficientDiskSpace` naming needed and free bytes in one line, `fw index reindex` exits non-zero, and the live index is byte-identical
- [x] No orphan on any exit path: the copy is inside the try/finally; SIGTERM/SIGINT are turned into an exception so `finally` runs (scratch parked or removed); a disk-full error (ENOSPC / sqlite "database or disk is full") deletes the scratch instead of parking it; `build_index()` removes `.building` on failure; `fw index reindex` forwards TERM/INT to the python child via a shell trap
- [x] Start-of-run sweep: every reindex/build removes `*.reindex.<pid>.tmp*` and `*.<pid>.building` scratch whose pid is dead (plus legacy pid-less `.building` under the lock) and reports what it removed in the stats (`swept`)
- [x] `lib/vector_index_health.py` WARNs (`disk` check) on orphan scratch files with their sizes, and when free space is below what the next reindex needs
- [x] Unit tests (temp dir, monkeypatched disk-usage function): refusal on low space with live index intact, cleanup on exception, cleanup on signal, dead-pid orphan sweep, health WARNs; existing reindex/T-3786 tests stay green
- [x] Copy-vs-in-place decision recorded in ## Decisions

### Human
- [ ] [REVIEW] Watchtower semantic search still renders results after the embeddings.py change
  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && bin/fw watchtower url` and open `<url>/search?q=vector+index+reindex` in a browser
  2. Run the query with semantic or hybrid mode, if the page offers a toggle
  **Expected:** a populated result list with snippets, laid out as before (this task changed only the build/reindex path, not query or render code)
  **If not:** screenshot the page, check `.context/working/watchtower.log` for an `embeddings` traceback, and reopen T-3860
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
python3 -m pytest tests/unit/test_t3860_reindex_disk_guard.py tests/unit/test_incremental_reindex.py tests/unit/test_t3786_index_never_built_by_readers.py -q > /tmp/.t3860-py.out 2>&1 && grep -q passed /tmp/.t3860-py.out && ! grep -q failed /tmp/.t3860-py.out
timeout 600 bats tests/unit/t3783_vector_index_health.bats > /tmp/.t3860-bats.out 2>&1 && ! grep -q "^not ok" /tmp/.t3860-bats.out
test "$(grep -c '# skip' /tmp/.t3860-bats.out)" -eq 0
bash -n bin/fw
grep -q 'trap .kill -TERM "\$_rx_pid"' bin/fw
git check-ignore -q .context/working/fw-vec-index.db.12345.building
# Vendor parity scoped to this task's files: a repo-wide `fw vendor self --check` reports
# drift from other workers' uncommitted edits (bin/fw vendor hunks, lib/sidecar, lib/upgrade.sh).
bash -c 'set -e; for f in web/embeddings.py lib/vector_index_health.py; do cmp "$f" ".agentic-framework/$f"; done; git show HEAD:bin/fw | cmp - .agentic-framework/bin/fw'
bin/fw watchtower current

## RCA

**Symptom:** ring20-dashboard's production root disk hit 100% at ~22:20 on 2026-10-04 during the hourly `fw index reindex`; a 464 MB `fw-vec-index.db.reindex.<pid>.tmp` was left behind.

**Root cause:** `reindex_incremental()` makes a full `shutil.copy2` of the index (≈1.5 GB there) before every run, with (1) no free-space check, (2) the copy *outside* the try/finally, so an ENOSPC mid-copy left the partial file, (3) Python's default SIGTERM handler, which exits without running `finally`, and (4) a failure path that *parked* the scratch as `.reindex.resume` whatever the cause, so a disk-full failure would have kept the disk full, and a half-written copy could be resumed from. `build_index()` had the same shape with `.building`.

**Why structurally allowed:** T-3014 designed the copy-then-swap for atomicity on AEF's own host, which has hundreds of GB free. Every test ran in a tmp dir on that same host, so "is there room for a second copy?" was never a question any test could ask. T-3783 then seeded the job to every consumer, so the copy started running hourly on small production disks without anyone re-asking it. The health module (T-3783) checked whether the index could answer a query. It never checked whether the next run could fit, so the first signal was a full disk.

**Prevention:** `_ensure_disk_space` refuses before writing; the `disk` check in `lib/vector_index_health.py` WARNs (doctor, audit, handover, and the cron itself) on low headroom and on orphans before the next run tries; the start-of-run sweep removes the corpses left by exits Python cannot see (SIGKILL/OOM). `tests/unit/test_t3860_reindex_disk_guard.py` uses a monkeypatched disk-usage function, so the "small disk" case now runs on any host.

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
**Rationale:** The disk-filling path is closed. The reindex refuses before writing when free space is below index size + max(20%, 500 MB). Scratch is removed or parked on exception, ENOSPC, "disk is full" and SIGTERM/SIGINT (forwarded by the `fw index reindex` shell trap). Dead-pid orphans are swept at the start of every run, and health WARNs on orphans and on low headroom. No query or render code changed. The [REVIEW] criterion exists only because `web/embeddings.py` is on the P-013 render-surface list.
**Evidence:**
- `tests/unit/test_t3860_reindex_disk_guard.py`: 17 passed (refusal with live index intact, ENOSPC mid-copy, disk-full mid-embed, SIGTERM mid-run/mid-copy/mid-build, dead-pid sweep, health WARNs)
- Existing `test_incremental_reindex.py` + `test_t3786_*`: 28 passed; `t3783_vector_index_health.bats` 33/33, `t3058` 7/7, `t3783_reach` 4/4
- Verification 8/8 passed at the close attempt; Watchtower restarted and current

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

### 2026-10-05 — copy-then-swap vs in-place incremental update
- **Chose:** keep the full copy + `os.replace`, and guard it (free-space pre-check, cleanup on every exit, dead-pid sweep, health WARN).
- **Why:** an in-place transaction would be crash-safe for sqlite-vec (vec0 is backed by ordinary shadow tables in the same journal). But the run deliberately commits every ~512 chunks so a 29-58h bootstrap survives kills (OBS-258). In place, readers would see a half-updated corpus between those commits, with canaries replanted before or after the corpus they vouch for. That breaks the T-3014 AC4 contract ("old file or new file, never a mixture") and the manifest-after-swap guarantee. The single-transaction alternative loses the resumability that lets an hourly cron converge. `index_one()` also writes to the live DB between runs, and the copy isolates those writes. Space cost: one index-sized copy, which the guard now proves fits before writing.
- **Rejected:** in-place with per-group commits (readers see a mixture, canary semantics break); in-place with one transaction (not resumable, and its rollback journal can approach index size on a bootstrap-baseline run anyway).

### 2026-10-05 — `.building` named per pid, build_index takes the reindex lock
- **Chose:** `<db>.<pid>.building`, and `build_index()` holds `.reindex.lock` (raises `IndexBusy`; the bootstrap path maps that to `skipped-locked`).
- **Why:** a pid-less name cannot be classed as live or dead, so there would be nothing to sweep by. Holding the lock is what makes a legacy pid-less `.building` provably unowned.
- **Rejected:** a separate pid sidecar file (one more artefact to orphan).

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-10-05T07:38:54Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3860-high-hourly-incremental-reindex-t-3783-s.md
- **Context:** Initial task creation

### 2026-10-05T07:43:35Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-37a963ea
- **Timestamp:** 2026-10-05T07:57:01Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-10-05T07:56:00Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
