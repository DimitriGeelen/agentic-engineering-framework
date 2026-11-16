---
id: T-5196
name: "Watchtower approvals at volume, slice A: persistent on-disk memo of per-row
  verdict-ledger validation keyed on immutable git object ids, surviving restarts
  (T-5186 GO)"
description: >
  Build slice of inception T-5186 (GO 2026-11-16). Evidence: docs/reports/T-5186-watchtower-volume-performance.md.

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
created: 2026-11-16T19:37:24Z
last_update: 2026-11-16T22:34:33Z
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
  - ts: '2026-11-16T19:45:22Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=302,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-11-16T19:45:49Z'
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
---

# T-5196: Watchtower approvals at volume, slice A: persistent on-disk memo of per-row verdict-ledger validation keyed on immutable git object ids, surviving restarts (T-5186 GO)

## Context

<!-- All four parts are required before source edits (T-4907). Plain language; link design docs for substantial tasks. -->
**Background / trigger:** Inception T-5186 (GO 2026-11-16, report docs/reports/T-5186-watchtower-volume-performance.md F2). A cold approvals page costs 34–44 s at ~5,000 tasks, still about 40 s after slices B (T-5194) and C (T-5195). Of that, 1,909 `git show` (10.5 s) and 6 `git log` (7.3 s) calls come from `lib/verdict_ledger.py` `_git_out`, plus ~12 s of Python validation. Slice B also left one trigger open: a commit touching `.context/reviews/` moves the global git generation and invalidates every task, and about 42 such commits happen a day.

**Problem / hypothesis:** `_git_out`'s memo (`_GIT_MEMO`) lives in process memory and is dropped whenever the git state token changes, i.e. on every commit, and on every restart. Yet most of those calls ask for content addressed by a full object id (`git show <sha>:<path>`, `git cat-file`, `git ls-tree <sha>`), whose answer can never change. Recomputing them after each commit and restart is pure waste.

**Goal:**
1. A persistent, content-addressed memo for `_git_out` calls whose answer is fixed by full 40-hex object ids. On disk under `.context/working/` (gitignored), survives restarts, never invalidated by new commits. Calls that depend on refs or HEAD keep today's in-memory memo.
2. Measure what remains of a cold page after (1). If per-row validation in Python or `git log` still dominates, propose the next step with numbers; do not build it here.
3. Investigate the commit-touching-review-ledgers trigger from slice B. Fix it only if a change can be shown not to serve a stale READY (equivalence test). Otherwise record why it must stay and what it costs.

**Expected outcome:** A cold approvals page (after a restart) costs well under half of today's ~40 s, and a commit no longer throws away immutable git results. No readiness verdict differs from today's.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [ ] (Revised 2026-11-17 after the independent review; the on-disk memo was reverted in 95e10c8d2.) `_git_out`'s object-content reads (`show <40-hex>:<path>`, and `ls-tree` on a 40-hex tree if it fits) go through ONE long-lived `git cat-file --batch` process per repo instead of a subprocess each. Nothing is written to disk. Answers are identical to the per-call `git` they replace, including a missing object (same failure), which a test proves on a temp repo.
- [ ] The batch process is safe: a lock per process for concurrent threads; restarted if it dies or desyncs; falls back to the per-call path on any error; no zombie or leaked process (test).
- [ ] Measured in-process: cold approvals page before/after (fresh process), and the subprocess census. Numbers recorded here.
- [x] Slice B's leftover trigger (commits touching `.context/reviews/`) is either fixed with an equivalence test proving no stale READY, or kept with the reason and cost recorded in ## Decisions.
- [ ] Every existing test that touches lib/verdict_ledger.py or readiness passes, invariants pass, `bin/fw vendor self --check --task T-5196` is clean, and Watchtower is restarted and current.

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
python3 -m pytest tests/unit/test_t5196_git_object_memo.py -q -p no:cacheprovider > /tmp/.t5196.out 2>&1 && grep -q passed /tmp/.t5196.out
python3 -m pytest tests/unit/test_t5194_readiness_per_task_key.py tests/unit/test_t5195_approvals_single_flight.py tests/web/test_t4394_readiness_git_key.py tests/web/test_t4133_readiness_perf.py -q -p no:cacheprovider > /tmp/.t5196b.out 2>&1 && grep -q passed /tmp/.t5196b.out
git check-ignore -q .context/working/git-object-memo.db
bin/fw vendor self --check --task T-5196
bin/fw watchtower current

## Measurements

All in-process on this repo (~5,200 task files, ~400 awaiting review), same host, 2026-11-16.
"off" = this code with the immutable memo disabled (`_immutable_args` patched to False), i.e. the
pre-T-5196 code path. Wall times; the host was otherwise lightly loaded.

| Cold /approvals, fresh process | run 1 | run 2 | warm repeat (same process) |
|---|---:|---:|---:|
| off (before) | 34.8 s | 36.6 s | 2.6–2.8 s |
| empty memo (first fill) | 33.9 s | — | 2.6 s |
| memo warm on disk | 25.4 s | 25.9 s | 2.4–2.7 s |

Subprocess census (`docs/reports/T-5186-profile-subprocesses.py`, profiler overhead included):

| | subprocesses | `git show` | `git log` | page wall |
|---|---:|---:|---:|---:|
| before | 2,040 (33.4 s) | 1,909 (16.9 s) | 6 (9.2 s) | 49.2 s |
| after, empty memo | 512 (17.4 s) | 389 (2.1 s) | 6 (7.4 s) | 33.1 s |
| after, memo warm | 171 (15.4 s) | 67 (0.3 s) | 6 (8.3 s) | 28.8 s |

`_git_out` call shapes on one cold page: 3,033 `show <40-hex>:<path>` and 28 `ls-tree … <40-hex> --`
(memoised on disk); not memoised: 36 `rev-parse`, 21 `cat-file -e`, 21 `merge-base --is-ancestor`,
21 `log --reverse --format=%H HEAD -- <ledger>`, 4 `show HEAD:<path>`, 4 `log <sha>..HEAD --grep`,
4 `diff`, 1 `log --all`, 1 `log --full-history`.

Memo size after one page: 341 rows, 79.6 MB. Nearly all of it is every committed version of
`verdicts.jsonl` (550 KB, 152 versions) and `review-completions.jsonl` (496 KB), read by the
append-only walks (`load_ledger`, `history_fault`).

**Goal 3 trigger cost** (warm process; a commit touching `.context/reviews/` simulated by clearing
the ref-keyed memos and moving the global generation): the page itself stays at 2.7–2.9 s (it serves
stale WAITING, T-5195), and the background refresh of every awaiting task finishes after
**23.6 s off → 12.6 s with the memo**. Frequency: 101 such commits in the last 7 days (~14/day),
177 in 30 days.

**Goal 2: what remains of a cold page with the memo warm (~25 s)**, from cProfile:
- ref-dependent git, ~7.0 s in 48 `_git_out` subprocesses: `log --all --name-only` (producer index),
  the per-ledger `log --reverse HEAD -- <file>` walks, `log <rev>..HEAD --grep`.
- `inception_handoff_blockers` → 47 `bash -c` subprocesses, ~5.2 s (not ledger code).
- task frontmatter YAML for ~5,200 files, ~4.4 s (`get_all_task_metadata`).
- the append-only walks still read and compare every committed ledger version in Python
  (`history_fault` ~2.4 s over 21 calls) and `_imm_context` ~1.0 s over 3,061 calls.

**Tests (2026-11-17):** new `tests/unit/test_t5196_git_object_memo.py` 42 passed. Every pytest
file under tests/ that reads lib/verdict_ledger.py or readiness (+ T-5195's): 1,035 passed, 1 failed
when run as 4 parallel shards: `t5008…test_pkill_inside_the_seat_leaves_the_outside_decoy_alive`.
It passed alone (a pkill test racing the other shards). Ledger bats suites (8 files): 83 ok, 0 not
ok, 0 skipped. `bin/fw test invariants`: only red was this task's then-untracked test file, which
is tracked since ee89a5c73.

Proposed next step (not built here), in order of measured size: (a) make the append-only walks
incremental — persist, per ledger path, the verified prefix (commit id, line count, prefix hash)
so only commits after the last verified one are read; this also stops the memo's working set from
growing by ~1 MB per review commit; (b) cache `inception_handoff_blockers` per task-file mtime and
HEAD (~5 s); (c) an mtime-keyed frontmatter cache that survives restarts (~4 s); (d) extend the
`git log` results incrementally from the previous HEAD (~7 s).

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

### 2026-11-17 — the on-disk memo is reverted; one `git cat-file --batch` reader instead
- **Independent review (AMBER):** no path found that makes a verdict count wrongly in normal operation. But:
  - The live db was 160 MB after one page: every committed version of two append-only ledgers, stored again for each launch environment. It grows ~14 MB/day toward the 512 MiB cap, in every consumer project, for 10 s off a cold page.
  - It had two reproducible stale-answer cases: an object pruned after caching was still answered (exit 0), and a config change made through `include.path` was missed.
  - The reviewer's verdict on cost: not proportionate.
- **Chose:** revert ee89a5c73 (commit 95e10c8d2) and take the reviewer's cheaper design. The measured gain came mostly from 1,900 process spawns (~17 s), and one long-lived `git cat-file --batch` reader removes those with no disk store and no stale-answer class.
- **Rejected:** keeping the blob store with dedup and a 32 MiB cap. It is still a second copy of git's own object store, with its own invalidation rules to get right.
- The 160 MB `.context/working/git-object-memo.db` is no longer read by anything. Removing it is left to the operator.

### 2026-11-16 — what may be served from the persistent memo (superseded 2026-11-17, reverted)
- **Chose:** only `show <40-hex>:<path>` and `ls-tree [-r] [--name-only] <40-hex> -- <paths>` (lower-case full id, plain repo-relative paths, no pathspec magic, no other flags). Every key also carries a context hash: memo format version, the output text encoding, `.git/config` contents and the stats of the global/system git config files, and every replace ref (loose and packed, name → target). The memo is not used at all when the state token cannot be taken, refs move while the context is read, or a `GIT_*` variable outside a harmless list (author/committer identity, editor, pager, ssh, askpass) is set.
- **Why:** an object id fixes the object, not the answer: this repo has 2,970 replace refs on commits, and a replace ref changes what `<sha>:<path>` resolves to (test `test_replace_ref_changes_the_answer`). Config (`core.useReplaceRefs`, `core.quotePath`) and env (`GIT_NO_REPLACE_OBJECTS`, `GIT_DIR`, pathspec env) can change it too. Folding them into the key makes old entries unreachable, never stale.
- **Rejected:** `cat-file -e`, `merge-base --is-ancestor` and `rev-parse` on full ids — existence and ancestry can change when objects are pruned or grafts/shallow change, and together they are 78 cheap calls a page. Refs, HEAD, short ids, `^`/`~`, ranges and `log` stay on the in-memory, state-token memo as before.

### 2026-11-16 — storage
- **Chose:** sqlite at `.context/working/git-object-memo.db` (WAL, synchronous=NORMAL), gitignored by the existing `.context/working/*.db` / `*.db-wal` / `*.db-shm` rules. Used only when `git check-ignore` confirms it is ignored in that repo. Each row carries its args (compared on read) and a sha256 of its output (verified on read; a mismatch runs git). A file that is not a database is deleted and started again; a locked/unwritable one turns the memo off for the process. Bound 512 MiB / 100,000 rows, least-recently-used eviction to 80% (last use refreshed at most hourly), checked on a process's first write and every 256 writes. Entries over 4 MiB are not kept. Non-zero exits are never kept.
- **Why:** the brief asked for tmp+rename atomic files, but I may not edit `.gitignore`, and the only gitignored names under `.context/working/` that fit a cache are `*.db`. sqlite transactions give the same atomicity (a reader never sees a half-written entry), handle Watchtower threads plus CLI processes writing concurrently, and evict without rewriting a whole file; a per-file layout would have needed thousands of files under a misleading `*.db` directory name.
- **Known limit:** the working set is every committed version of the two big ledgers (79.6 MB today) and grows ~1 MB per review commit (~14/day), so it reaches the 512 MiB bound in roughly a month. After that the LRU will evict versions every cold page needs and the gain degrades toward today's cost (never toward a wrong answer). Next-step (a) in ## Measurements removes that growth.

### 2026-11-16 — slice B's leftover trigger: kept
- **Chose:** keep `.context/reviews/` in `_GLOBAL_GIT_INPUTS`; a commit touching it still moves the global generation.
- **Why it is global:** what the validator reads from git under `.context/reviews/` is not per-task. (1) `load_ledger` walks every committed version of `verdicts.jsonl` and refuses the WHOLE ledger (every task) when any commit modified, deleted or duplicated a row; the same append-only walk (`history_fault`) runs over `review-completions.jsonl` and the acknowledgements file. (2) Which rows count depends on whether they are committed and on the identity of the commit that introduced each row (producer and worker checks), and a completion row is tied to its task only through its dispatch id, so attributing a commit's added lines to tasks needs the whole cross-ledger link map at that commit, not the commit's diff alone. A per-task key would have to reproduce all of that exactly, and an under-attribution serves a stale READY. I could not build a temp-repo fixture that drives the full validator to READY (signed dispatch registry, runs, completions, producer identities) within this slice, so there is no equivalence test, and the rule was: no test, no change.
- **Cost:** ~14 commits/day touch `.context/reviews/`. Each one sends every awaiting task to a background refresh; the page keeps serving stale WAITING (2.7–2.9 s). The refresh took 23.6 s before this slice and 12.6 s with the memo warm.

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

### 2026-11-16T19:37:24Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-5196-watchtower-approvals-at-volume-slice-a-p.md
- **Context:** Initial task creation

### 2026-11-16T22:33:47Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)
