---
id: T-3627
name: "Watchtower wedged: /graduation re-reads ~7000 files per request uncached; 59
  of 91 threads stuck, every route timed out (2026-10-01)"
description: >
  Operator could not reach Watchtower. py-spy (docs/reports/T-wt-hang-2026-10-01-pyspy.txt):
  59/91 threads in discovery.py _build_application_index (graduation view) reading
  every task + episodic file, 83 CLOSE-WAIT connections, even static files timed out;
  restart restored it. Fix: cache the application index (mtime/signature, like T-3590/T-3600),
  bound concurrent work so one slow route cannot starve the server, and keep the log
  across restarts (restart truncated watchtower.log, losing the caller evidence).

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [bug, web, perf]
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
created: 2026-10-01T08:42:58Z
last_update: '2026-10-01T08:45:21Z'
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
  - ts: '2026-10-01T08:44:19Z'
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
  - ts: '2026-10-01T08:45:21Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=275,acs=7)
    rubric_sha: e4a00f38e801
---

# T-3627: Watchtower wedged: /graduation re-reads ~7000 files per request uncached; 59 of 91 threads stuck, every route timed out (2026-10-01)

## Context

Operator could not reach Watchtower on 2026-10-01. py-spy dump: docs/reports/T-wt-hang-2026-10-01-pyspy.txt (59/91 threads in `_build_application_index`).

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `_build_application_index` (web/blueprints/discovery.py) is cached on a corpus signature, reusing the T-3590/T-3600 mechanism (`_task_files_signature` / the shared task cache), so a warm `/graduation` does not re-read the corpus. Test: a counting wrapper shows 0 file reads on the second request; cold and warm timings are recorded in Decisions.
- [x] Any other route that re-reads the whole corpus per request without a cache is found (profile the routes the playwright route sweep hits) and listed in Decisions. The ones as bad as /graduation are fixed here; the rest get one follow-up task.
- [x] One slow route cannot starve the server: bound concurrent heavy work (for example a per-route in-flight limit returning 503 with Retry-After, or one shared build lock so concurrent misses wait for a single build). Test: 30 concurrent cold /graduation requests leave / and a static file answering within 2s.
- [x] `bin/fw watchtower restart` keeps the previous log (rotate to `watchtower.log.1`, do not truncate). Test included.
- [x] Who called /graduation about 60 times at once is identified if the evidence allows (playwright route sweeps such as tests/playwright/test_response_times.py and test_all_routes_height.py against the LIVE server, the nightly runner, or monitors). If a test hits the live operator Watchtower, it is pointed at its own fixture server instead. `bin/fw watchtower current` passes after the final restart.

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

python3 -m pytest tests/web/test_t3627_watchtower_wedge.py -q -p no:cacheprovider > /tmp/.t3627-py.out 2>&1 && grep -q "8 passed" /tmp/.t3627-py.out
timeout 120 bats tests/unit/t3627_watchtower_log_rotate.bats > /tmp/.t3627-bats.out 2>&1 && ! grep -q "^not ok" /tmp/.t3627-bats.out
test "$(grep -c '# skip' /tmp/.t3627-bats.out)" -eq 0
bin/fw vendor self --check
bin/fw watchtower current

## RCA

**Symptom:** 2026-10-01 Watchtower stopped answering every route, static files included. py-spy: 59 of 91 threads inside `discovery._build_application_index` (the /graduation view), 83 sockets in CLOSE-WAIT (clients had already given up).

**Root cause:** the T-1233 application index was a 60s TTL cache with no build lock. Every request that arrived after expiry re-read every task + episodic file (~6,700 files, 2.3s alone) itself, and concurrent misses each ran the full scan. Under load each scan slows the others (GIL + I/O), so requests outlive their clients' timeouts, clients retry, and the pile only grows: a positive-feedback wedge that ends with every server thread in the same loop. `graduation()` also called `_count_applications` once per learning (~700 calls per request).

**Why structurally allowed:** no Watchtower cache had single-flight; T-3575/T-3590 made the task caches change-driven but still let N concurrent misses build N times. Nothing bounded concurrent heavy work, and the response-time tests measure one request at a time, which cannot see contention. `fw watchtower restart` truncated `watchtower.log`, so the evidence of who called was destroyed by the act of recovering.

**Prevention:** `web.shared.signature_cached` (stat-signature + per-cache lock, so concurrent misses share one build) and `web.shared.limit_inflight` (503 + Retry-After past N), pinned by tests/web/test_t3627_watchtower_wedge.py, including 30 concurrent cold /graduation requests while / and a static file must answer in <2s. Restart rotates the log (tests/unit/t3627_watchtower_log_rotate.bats). The remaining per-request readers are in T-3634. `tools/t3627_route_profile.py` reproduces the profile in-process.

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

### 2026-10-01 — cache shape for the graduation index
- **Chose:** a stat-signature over tasks (`_task_files_signature`, the T-3575/T-3590 one), episodics (`episodic_files_signature`, new), and patterns.yaml; the build is behind a single-flight lock (`signature_cached`); per-file L-ref sets are kept in `mtime_cached_get`, so a rebuild after one file changes re-reads only that file.
- **Why:** the wedge was concurrency on a miss, not the cost of a single miss, so freshness alone (T-3575 style) would not have prevented it. The lock does.
- **Rejected:** a longer TTL (it still stampedes at expiry, and it serves stale data); precomputing in a background thread (it adds a second lifecycle to manage for a 2s build).

### 2026-10-01 — bounding concurrency
- **Chose:** both a per-cache build lock and `limit_inflight(4)` on /graduation (503 + `Retry-After: 5`).
- **Why:** the lock alone still parks one server thread per waiting client; the limiter sheds them immediately. Measured in-process: of 30 concurrent cold requests, 26 get 503 at once; `/` and `/static/pico.min.css` answer in under 2s while the build runs.
- **Rejected:** a global WSGI concurrency cap (it would also shed cheap routes, which the AC requires to stay up).

### 2026-10-01 — timings (in-process, app.test_client, live corpus, read-only)
- /graduation cold 2.35s / 6,696 files; warm 0.18s / 5 files; **61s later (the old TTL would have rebuilt) 0.21s**; after a signature change 0.27s (per-file caches hit).
- Before: warm within 60s 0.24s; after 60s a full 2.3s rebuild, with every concurrent request rebuilding.

### 2026-10-01 — whole-corpus readers found (tools/t3627_route_profile.py, all parameterless GET routes)
Warm-request corpus file opens, before → after:
- `/` (dashboard): 4,181 → 577. `core._get_arcs_in_flight` → `scan_tasks_by_arc_membership` read every task frontmatter (3,612) on every request. **Fixed here** (`_arc_membership_index`, signature-cached). The remaining 539 are `cockpit.get_action_summary` over active tasks → T-3634.
- `/project`: 3,077 → 3. `_build_project_categories` read every episodic header on every request. **Fixed here** (per-file mtime cache).
- `/graduation`: TTL rebuild every 60s → change-driven. **Fixed here.**
- `/docs/generated`: 1,394 fabric cards per request, 3.6s warm → T-3634.
- `/metrics`: `_stale_tasks`, ~545 active tasks per request, 0.8s → T-3634.
- `/approvals`, `/approvals/content`: 2.8s warm but only ~80 files (CPU-bound) → T-3634.
- Cold-only (already cached warm): `/` 19-21s, `/search` 20s, `/cron` 14s, `/bvp` 5s.

### 2026-10-01 — caller (AC 5)
- **Not identified with certainty.** The restart truncated the log (now fixed). Evidence: the wedged server's RSS climbed 248MB→1.7GB from 22:55 to 23:15 local and 1.9→2.4GB from 03:05 to 03:35 local. Those match the nightly unit-suite starts in `.context/audits/unit-suite/runs.log`: 20:53Z and 01:03Z, both `jobs=12` (T-3602 made the suite per-file parallel at 22:53 local). The remaining `.107` traffic is this host (`hostname -I`), i.e. local processes.
- **Ruled out:** no Playwright file targets the live URL. All of them use `tests/playwright/target.TEST_URL` (FW_TEST_PORT, default 3099), and every `:3000` hit is a docstring. No file in tests/unit, tests/integration, agents, lib, bin or tools references `/graduation` over HTTP. The monitors (liveness, rss) only probe `/api/_identity` and `/health`. `agents/ux-review/ux-review.py` does default `--base` to the live URL, but it is sequential, so it cannot produce 60 concurrent requests.
- Final restart 2026-10-01 11:16: the previous 71,746-byte log was kept as `watchtower.log.1`, and `bin/fw watchtower current` returned 0 (pid 615078).
- The next occurrence will be attributable: the log now survives a restart (`watchtower.log.1`), and `limit_inflight` logs a WARNING line for every 503.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-10-01T08:42:58Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3627-watchtower-wedged-graduation-re-reads-70.md
- **Context:** Initial task creation

### 2026-10-01T08:44:18Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
