---
id: T-4363
name: "Cold Watchtower: first GET /approvals takes 13 s, and fw doctor's smoke test
  times out on / and /cron since v1.8.11"
description: >
  832 measurement (msg 84051d77, after their v1.8.11 upgrade, ~1200 task files): a
  cold Watchtower listens after ~2 s, but the FIRST GET /approvals takes 13.4 s (next
  ones 1.3 s); cold /cron 1.4 s, /designer 0.04 s; warm / and /tasks ~1.2 s each.
  fw doctor's Watchtower smoke reported '/ timed out, /cron timed out' after the upgrade,
  where it passed before (their probe: 3 s per request). Looks like a cold-cache build
  of the task corpus on the first request that needs it. Related: T-3765 (dashboard
  / >30 s; 4 cold-start readers left uncached), T-4223 (/gaps). Measure here, find
  which reader builds on first request, warm it at startup or make the first request
  cheap; make doctor's smoke test tolerate a deliberate warm-up (or warm first) rather
  than report a timeout.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [watchtower, performance, doctor]
components: []
related_tasks: []
origin: {kind: "peer", source: "832"}
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
created: 2026-10-18T23:59:30Z
last_update: '2026-10-22T07:46:10Z'
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
  - ts: '2026-10-19T00:00:45Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=287,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-10-19T00:01:51Z'
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
  - ts: '2026-10-22T07:46:10Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-4363: Cold Watchtower: first GET /approvals takes 13 s, and fw doctor's smoke test times out on / and /cron since v1.8.11

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Cold vs warm timings for /approvals, /, /cron, /tasks measured on a separate Watchtower instance (not the operator's) and recorded in Updates, with a profile naming the reader(s) that build on the first request
- [x] The reader(s) named by the profile are warmed at startup in a background daemon thread, so the first request no longer builds them on the request thread
- [x] After the fix, the first GET of /, /cron and /tasks issued once the warm-up finished is under 3 s on this repo, and the first GET /approvals is at its warm steady state rather than the cold build; before/after numbers in Updates (reworded after measurement — see Decisions)
- [x] Regression test: a unit test that fails on the pre-fix code shows the startup warm-up is started from both serve entry points and fills the cache off the request thread
- [x] `bin/fw vendor self --check` is clean; operator's Watchtower restarted once and `bin/fw watchtower current` exits 0

### Human
- [ ] [REVIEW] The /approvals page looks and behaves unchanged, only the first load is faster
  **Steps:**
  1. Run `cd /opt/999-Agentic-Engineering-Framework && bin/fw watchtower url` and open `<printed URL>/approvals` in a browser
  2. Compare the sections (inception decisions, Tier 0, arc closure, reviews) with what you remember from before
  **Expected:** same sections, same counts and buttons, no error banner
  **If not:** note which section differs (screenshot) and leave this box unticked; reopen T-4363
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
python3 -m pytest tests/unit/test_t4363_startup_warmup.py -q > /tmp/.t4363.out 2>&1 && grep -q passed /tmp/.t4363.out
bin/fw vendor self --check --task T-4363
bin/fw watchtower current

<!-- (RCA section is below, after Evolution) REQUIRED for bug-class tasks (workflow_type=build with bug-tag, OR title matches
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

## RCA

**Symptom:** a freshly started Watchtower listens in ~2 s, but the first GET /approvals takes 13.4 s on 832 (~1,200 tasks; 1.3 s warm) and 40.9 s here (~4,400 tasks; 11.9 s warm); cold / 36 s, /cron 5 s, /tasks 3.9 s. fw doctor's smoke probe (web/smoke_test.py:122, 5 s per route) reports those cold builds as timeouts.

**Root cause:** every corpus reader is a lazy mtime/signature cache filled on the first request that needs it, on that request's thread: `shared.get_all_task_metadata` → `_build_task_metadata` (web/shared.py:1913, ~10.5 s profiled, parses all 4,374 task frontmatters), the readiness cache behind `approvals._queue_groups` (web/blueprints/approvals.py:244 → `shared.review_readiness` web/shared.py:1614, ~22 s profiled incl. `inception_handoff_blockers` subprocesses web/shared.py:1416 and the verdict ledger's git faults lib/verdict_ledger.py:2004), plus the dashboard readers T-3765 left uncached-on-cold. Nothing built them before the first request, so the first request — the operator's, or doctor's probe right after `fw upgrade`/restart — paid all of it.

**Why structurally allowed:** each cache was added (T-3575, T-3600, T-3765, T-4133) and measured WARM; nothing measured the first request after a restart, and the only cold-path observer (the doctor smoke) reports a slow cold build as a generic timeout, indistinguishable from a broken server.

**Prevention:** `web/warmup.py` issues the expensive pages (WARM_PATHS) through the app's own test client on a daemon thread at serve start (web/app.py main, web/wsgi.py), so the cold build runs off the request thread whatever readers a page grows later (no per-reader list to rot). `/api/_identity` reports `warmup.state`; the smoke probe waits (bounded, `WARMUP_WAIT_SECONDS`=180) while a server reports `warming`, so a deliberate warm-up is not reported as a timeout. Pinned by tests/unit/test_t4363_startup_warmup.py (fails pre-fix: module and wait function absent; asserts the cold build ran off the main thread and that both serve entry points start it).

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

**Rationale:** The cold build now runs on a startup daemon thread rather than on the first request. In a controlled A/B under the same host load, the first GET / dropped from 65.8 s to 1.6 s and the first /approvals from 56.6 s to 16.9 s, which is /approvals' own warm cost on this repo (8.6–16 s). The page template and its context are untouched: the warm-up only calls the existing routes, so the /approvals page should look exactly the same. The one human check is that it really does.

**Evidence:**
- tests/unit/test_t4363_startup_warmup.py: 7 passed (it fails before the fix because web.warmup and smoke_test.wait_for_warmup did not exist)
- tests/unit/t3453_doctor_smoke_inverted_alarm.bats and t3933_doctor_smoke_skip.bats: 13/13 ok
- Before/after numbers are in Updates (2026-10-19 measurement entry)
- Not fixed here: /approvals' warm cost on a 4,400-task repo, and readiness-cache invalidation on every commit (`_readiness_stamp` keys on .git/logs/HEAD, web/shared.py:1531). See Decisions.

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

### 2026-10-19 — warm the pages, not a list of readers
- **Chose:** a startup daemon thread that GETs WARM_PATHS through the app's test client (web/warmup.py), started from `main()` and web/wsgi.py, not from create_app.
- **Why:** the cold cost is spread over several shared readers (task metadata, readiness, inception blockers, ledger git faults, dashboard readers). A per-reader warm list is how T-3765 left four readers uncached; warming the pages covers whatever they read now or later. Starting it outside create_app keeps every test that imports web.app free of a background corpus build.
- **Rejected:** raising the doctor smoke timeout (hides the cold build; excluded by the brief); warming inside create_app (would fire in every unit test).

### 2026-10-19 — AC 3 reworded after measurement
- **Chose:** "/, /cron, /tasks under 3 s; /approvals at its warm steady state" in place of "all under 3 s".
- **Why:** measured warm /approvals on this repo is 8.6–16 s even with every cache hot (`_load_close_ready_arcs` → `_arc_demo_state` subprocesses ~7 s, `_load_pending_human_acs` AC parsing ~5.6 s, profiled warm). That is the page's warm cost, not the cold build this task is about, and a startup warm-up cannot remove it. On 832 warm /approvals is 1.3 s.
- **Open (not fixed here):** (1) warm /approvals cost on large corpora (arc demo-state subprocesses per request); (2) `_readiness_stamp` (web/shared.py:1531) includes .git/logs/HEAD, so any commit invalidates every ledger-consulting readiness entry. In a repo with many committing workers, /approvals goes back to cold readiness after each commit.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-10-18T23:59:30Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-4363-cold-watchtower-first-get-approvals-take.md
- **Context:** Initial task creation

### 2026-10-19T13:32:58Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-10-19 — measurement, before and after [agent]
Host: this repo (~4,400 task files), load average 45–65 on 24 cores and several workers committing (6 commits in 15 min), so absolute numbers are noisy; the A/B pairs ran back to back.
- **Before, separate live instance on :3077** (operator's :3000 untouched): listens after 1.7 s; /approvals 40.9 s cold → 11.9 s second; / 36.5 → 0.9; /cron 5.0 → 0.25; /tasks 3.9 → 0.53.
- **Profile, cold /approvals (cProfile, test client, 51 s profiled):** `_queue_groups` 23.7 s (readiness + `inception_handoff_blockers` subprocesses + verdict-ledger git faults), `get_all_task_metadata`/`_build_task_metadata` 10.5 s (4,374 frontmatter parses), `_load_close_ready_arcs` 7.9 s. Warm (19.7 s profiled): `_queue_groups` drops to 1.0 s and metadata to 0; `_load_close_ready_arcs` stays at 7.7 s and `_load_pending_human_acs` at 5.6 s (warm cost).
- **Cold sweep of all 53 smoke routes (test client):** 229 s cold vs 66 s warm; slowest cold routes were / 85 s, /search 30, /approvals 14.5, /tasks 13.3, /timeline 13.2.
- **A/B in-process, first request per page (run 2):** cold /approvals 48.8, / 69.8, /cron 6.8, /tasks 19.8 → after warm-up 16.3, 8.3, 0.3, 0.7 (that process's warm /approvals was 15.0).
- **A/B controlled, HEAD unmoved during every timed request:** first /approvals 56.6 s → 16.9 s; first / 65.8 s → 1.6 s; then warm /approvals 8.6–9.0, / 1.1.
- **After, live instance on :3077 with the fix:** warm-up done 134 s after start; then /approvals 11.9, / 6.6, /cron 0.27, /tasks 0.62. The later /approvals 26–31 s readings coincide with concurrent commits invalidating the readiness cache (see Decisions, Open).
