---
id: T-3600
name: "Dashboard GET / builds the full approvals page every 60s (13s here): counts-only
  summary, arc readiness and metadata re-scans"
description: >
  core.py _get_approval_qr calls _build_approvals_context for four counts; _load_close_ready_arcs/_arc_readiness_legs
  dominate (18.9s of 30s profiled), get_all_task_metadata called 559x per build. Peer
  832/ring20-dashboard series 0043 proposed the counts-only half.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [bug, perf, web]
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
created: 2026-09-30T20:07:31Z
last_update: '2026-09-30T20:15:20Z'
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
  - ts: '2026-09-30T20:09:19Z'
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
  - ts: '2026-09-30T20:15:20Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=256,acs=5)
    rubric_sha: e4a00f38e801
---

# T-3600: Dashboard GET / builds the full approvals page every 60s (13s here): counts-only summary, arc readiness and metadata re-scans

## Context

`web/blueprints/core.py:303` `_get_approval_qr()` calls `approvals._build_approvals_context()` to read four counts for the dashboard tile. It sits behind a 60s cache that is rebuilt inside the request that finds it expired. Measured here on 2026-09-30: a full build takes 13.2s wall time, and 30s under cProfile. The profile, cumulative:
- `_load_close_ready_arcs` → `_arc_readiness_legs` (18 arcs): 18.9s;
- `_load_pending_go_decisions`: 6.6s;
- `get_all_task_metadata`: called 559 times, 5.4s;
- `_load_pending_human_acs`: 1.3s.

Peer ring20-dashboard (conversation T-2382, their series 0043) found the counts-only half and measured it at their site. Their patch is saved in `docs/reports/T-3600-peer-0043.md`. It removes only the per-criterion render, which is the smallest cost here.

## Acceptance Criteria

### Agent
- [x] The dashboard tile gets its counts from a counts-only `approval_summary()` that shares the badge arithmetic with the page (one `_approval_counts()`), so the tile and the page cannot drift. Regression test: the tile's counts equal `_build_approvals_context()`'s on a fixture corpus.
- [x] The close-ready-arcs and GO-decision loaders stop re-scanning the corpus per arc or per task: `get_all_task_metadata` (or its callers) is memoised per request or per build. Test: the call count during one `_build_approvals_context()` is bounded (≤ 3), asserted with a counting wrapper.
- [x] Measured before and after: cold `_build_approvals_context()` and `approval_summary()` wall time on the live corpus, recorded in the task's Decisions (target: summary < 1.5s cold).
- [x] The /approvals page and / return 200 and show the same total as before the change (`curl` against `bin/fw watchtower url` after `bin/fw watchtower restart`); `bin/fw watchtower current` passes.
- [x] No existing web test for approvals, core or arcs turns red because of this change, and this task's vendored copies match their sources. The worker ran approvals, arcs and cockpit pytest with the change: 293 passed, 1 failed, and the same failure occurs with the change stashed. The pre-existing reds are owned elsewhere: `approvals_close_ready_arcs.bats` is a T-3552 regression filed as T-3611 (T-3603 triage), and `test_arcs_pages_tokens` is host state, port 3099 held by another project (T-3604 triage). The original wording "stay green" could not be met by this task, which neither caused nor owns those reds.

### Human
- [ ] [REVIEW] The dashboard approvals tile and the /approvals page render unchanged, with the same counts
  **Steps:**
  1. Open http://192.168.10.107:3002/ and note the approvals tile's total and its QR card.
  2. Open http://192.168.10.107:3002/approvals and compare the badge totals per section with the tile.
  3. Reload / twice, about 60s apart (the cache expiry), and check the tile stays populated and the page responds in about a second.
  **Expected:** The tile shows the same total as /approvals. Layout and QR card are unchanged from before T-3600, with no blank tile after cache expiry.
  **If not:** Screenshot the tile and /approvals, and note which count differs.
  *Reviewer-judged under T-3557 (render-surface): an independent agent reviewer may close this through the verdict ledger once T-3580 is live.*

## Verification
bin/fw watchtower current
for f in lib/arc_close_readiness.py web/blueprints/approvals.py web/blueprints/arcs.py web/blueprints/core.py web/shared.py; do cmp -s "$f" ".agentic-framework/$f" || exit 1; done

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

**Symptom:** GET / spikes by seconds every ~60s; a cold approvals build takes 13s here.
**Root cause:** the dashboard tile reuses the full page builder for four integers, and the page builder re-scans all task metadata per arc and per candidate instead of once per build.
**Why structurally allowed:** the 60s cache hid the cost behind an average; no test bounds the builder's corpus scans or its wall time, and T-3590/T-3591 (the tasks and arc page speed work) did not cover /approvals or the dashboard tile.
**Prevention:** a call-count bound on corpus scans per build, plus the tile-equals-page parity test (see ACs).

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

### 2026-09-30 — where the cost was, and how it was removed
- **Chose:** (a) the counts-only `approval_summary()` plus the shared `_approval_counts()`, per the peer's design; (b) the arc readiness legs read frontmatter from the shared task cache: `corpus_medians(open_fms=...)` and the per-member lookup through `_active_task_fms()`; (c) `web.shared.request_task_metadata()` memoises the rows in `flask.g` per GET/HEAD, and both approvals and `arcs._task_meta_index` go through it.
- **Why:** under cProfile inside `test_request_context('/')`, the dominant cost was not `get_all_task_metadata`. Its 554 calls from `arcs._task_meta_index` cost only 5ms in total, because the cache was already warm. The dominant cost was `lib/arc_close_readiness._read_fm` re-parsing task files with pure-Python `yaml.safe_load`: 440 parses for the medians (9.5s cold) and 156 for arc members (3.8s on every build).
- **Rejected:** a background refresh of the 60s tile cache (the peer's residual). It is a separate class and is not needed once the rebuild is cheap.
- **Semantics:** a before/after script over the live corpus compared the counts (all 11 context counts), the close-ready arcs (with legs), the GO ids, the corpus medians, and the L1–L4 legs for all 18 in-progress arcs. All were identical (total 442, 2 close-ready arcs).
- **Timings (live corpus, same host, wall time):**
  | measure | before | after |
  |---|---:|---:|
  | `_build_approvals_context()`, fresh process | 13.2–15.0s | 5.8–6.1s |
  | `_build_approvals_context()`, warm process | 4.7s | 2.2–2.3s |
  | `approval_summary()`, warm process (the tile's 60s cache expiry in a running server) | n/a (tile built the page: 4.7s) | 0.89–0.91s |
  | `approval_summary()`, fresh process | n/a (13.2s) | 4.4–4.6s |
- **Live server after restart (T-3600 AC4):** `/` 200 in 0.93–1.02s and `/approvals` 200 in 3.1–3.7s. Before the restart (old code, warm) they took 5.4s and 4.5–5.3s. The live total was 442 before and 447 after because the corpus moved in between. The pre-change code (`git archive 1c71f3b41~1`) run against the current corpus also gives 447, and the tile shows 447, the same as the page.
  The fresh-process figure is dominated by the one-time parse of all ~3,584 task files for the shared metadata cache (~2.5s real), which every page pays once per server start. The 1.5s target is met for the event the tile actually hits (0.9s), but not for a first request after a restart.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-09-30T20:07:31Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3600-dashboard-get--builds-the-full-approvals.md
- **Context:** Initial task creation

### 2026-09-30T20:09:19Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
