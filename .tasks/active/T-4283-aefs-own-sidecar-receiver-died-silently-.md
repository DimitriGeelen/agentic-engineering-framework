---
id: T-4283
name: "AEF's own sidecar receiver died silently ~21:16-21:18Z 2026-10-17, as a worker
  batch started; the pre-push audit then FAILed 'Sidecar watcher NOT live' (cause
  unknown)"
description: >
  Last receiver event 2026-10-17T21:16:41Z (events.jsonl RECEIPT_SENT); batch-3 workers
  (w4251 T-4251, w3640 T-3640 Tier 0 kill-by-name, w3768, w3794, w3746) dispatched
  ~21:18Z. Only AEF's receiver died; other projects' receivers (same http_server.py)
  ran 3 days. Watcher kept ticking with probe_ok=False 'receiver not running'; fw
  sidecar ensure did not restart it; fw sidecar start did (2026-10-18 00:45). Suspects:
  a test that stops/kills the receiver via the LIVE .context/sidecar/receiver.pid
  instead of a fixture, or a kill-by-name reproduction. Find the cause (git log of
  tests run by those workers; grep tests for receiver.pid / sidecar stop without a
  fixture PROJECT_ROOT), fix the test isolation, and make 'ensure' restart a dead
  receiver when the watcher reports it.

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
created: 2026-10-17T22:46:37Z
last_update: 2026-10-17T23:59:31Z
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
  - ts: '2026-10-17T22:53:21Z'
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
  - ts: '2026-10-17T23:00:49Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=297,acs=8)
    rubric_sha: e4a00f38e801
---

# T-4283: AEF's own sidecar receiver died silently ~21:16-21:18Z 2026-10-17, as a worker batch started; the pre-push audit then FAILed 'Sidecar watcher NOT live' (cause unknown)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Root cause of the silent receiver death is localised to file:line, or the ruled-out hypotheses and missing evidence are recorded in ## RCA
- [x] No test under tests/ reads or writes the live `.context/sidecar/receiver.pid` or calls `fw sidecar stop|start` / kills `http_server.py` without a fixture PROJECT_ROOT (checked by grep; no offender found, recorded in ## RCA)
- [x] A regression test drives the fix and fails on the pre-fix tree (`test_orphan_receiver_of_this_project_is_reclaimed_so_start_proceeds` returned rc=1 before the fix)
- [x] `fw sidecar ensure` restarts a dead receiver when the watcher reports `receiver not running` (`test_ensure_restarts_a_receiver_the_watcher_reports_as_not_running`)
- [x] The sidecar unit tests closest to the changed code (test_sidecar_watcher_t3684.py, test_t4208_receiver_single_instance.py, test_sidecar_receiver_t3693.py) still pass
- [x] `bin/fw vendor self --check` is clean after the change
- [x] Round 2: the death is localised from the 16:50–21:20Z lines of `watcher/events.jsonl`, `watcher/ticks.jsonl`, `receiver/events.jsonl` and `server.log` (read-only), recorded in ## RCA with what is confirmed and what is not
- [x] `fw sidecar ensure` no longer reports a refused receiver start as `running`: a start refused by a live receiver of another copy reports `REFUSED …` (`test_ensure_reports_a_refused_receiver_start_as_refused`, fails on the pre-fix tree)
- [x] A start that will be refused no longer kills this project's live stale-code receiver first (`test_refused_start_leaves_the_live_stale_receiver_running`, fails on the pre-fix tree)

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

out=$(python3 -m pytest tests/unit/test_t4283_orphan_receiver_reclaim.py tests/unit/test_sidecar_watcher_t3684.py tests/unit/test_t4208_receiver_single_instance.py tests/unit/test_sidecar_receiver_t3693.py -q -p no:cacheprovider 2>&1); echo "$out" | grep -q passed && ! echo "$out" | grep -q failed
bin/fw vendor self --check
out=$(python3 -m pytest tests/unit/test_t4283_orphan_receiver_reclaim.py -q -p no:cacheprovider -k "refused" 2>&1); echo "$out" | grep -q "2 passed" && ! echo "$out" | grep -q failed

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

## RCA

### Round 2 (supersedes round 1's timeline)

**Timeline (from `watcher/ticks.jsonl`, `watcher/events.jsonl`, `receiver/events.jsonl` and `server.log`, read-only).** The receiver did not die at 21:16Z. The receiver events at 21:10Z and 21:16Z are `INGESTED_FROM_HUB` rows, written by the watcher's hub pull (`lib/sidecar/watcher.py:290`), not by the HTTP receiver. The last direct POST stored by the receiver was at 16:54:39Z (`receiver/events.jsonl:5161`, sender 055). The probe flipped to `receiver not running` at 16:55:20Z and stayed there until 22:45:57Z. The supervisor's `RECEIVER_RESTARTED rc=1` loop starts at 16:56:10Z (`watcher/events.jsonl:464`), right after a `STALE_CODE_RESTART` at 16:56:09Z. `server.log` was last written on 10-13, so the receiver left no traceback: it was signalled, it did not crash.

**Root cause (confirmed, apart from the exact second of the kill).** Two faults combined:
1. **AEF's `enabled.json` named the wrong agent.** Every restart from 16:56Z asked for agent `t4217-envleak`. The restart detail says so (`watcher/events.jsonl:610` and later: `could not create inbox:…/999-Agentic-Engineering-Framework/t4217-envleak`), and the supervisor passes `--agent cfg["agent"]` (`lib/sidecar/watcher.py:803`). `t4217-envleak` is the dispatch worker id of T-4217/T-4218 (commit 23ba84665, author `dispatch+t4217-en`). Dispatch exports `FW_SIDECAR_AGENT_ID=<worker>` (`lib/sidecar/circuit.py:40`), and `fw sidecar start` (run by `bin/claude-fw:1075` at every launch) calls `_start_watcher` → `watcher.enable(agent)` (`lib/sidecar/watcher.py:194`). That overwrites the project's enabled.json even when the receiver is already running, which is why nothing showed. This is the G-116 leak class. Which launch wrote it is not recorded: enabled.json was rewritten at 22:45:33Z by the manual `fw sidecar start` and has no history.
2. **A start that would be refused killed the live receiver first.** At ~16:55Z the T-4252 worker's edits to `lib/sidecar_cli.py` / `lib/sidecar/dm.py` (committed 16:58:34Z, c75652dc6) made the running receiver stale code (`watcher.is_stale`, `lib/sidecar/watcher.py:935`). The next `fw sidecar ensure` (cron `sidecar-ensure-1m`, or a `claude-fw` launch's `fw sidecar start`) entered `_start_receiver`'s stale branch (`lib/sidecar_cli.py`, T-3685 block). That branch SIGTERMed AEF's receiver and cleared the triple file. Only after that did the T-4208 rival guard check agent `t4217-envleak`, find the leaked fixture receiver pid 3441291 (`/tmp/t4218head.*`, cwd a deleted tmp dir, alive since 22:50Z 10-16), and refuse with rc 1. `ensure` mapped that rc 1 to `receiver: running` (the false green). The supervisor retried every 5 s for six hours, and every retry was refused the same way.

Not explained: the ~50 s gap between the probe failing (16:55:20Z) and the `STALE_CODE_RESTART` event (16:56:09Z). It is consistent with two consecutive ensure runs or with a `claude-fw` launch doing the kill, but neither is logged. Ruled out: a test touching the live receiver.pid (round-1 grep, still true). Round 1's orphan reclaim does not cover this case, because the blocking rival runs in another copy (a deleted tmp cwd). It is correctly left alone.

**Why structurally allowed:** (1) `ensure` mapped every rc 1 to `running`, so a refused start looked green; (2) `_start_receiver` stopped the live receiver *before* it knew the replacement would be allowed; (3) `fw sidecar start` rewrites a project's enabled agent from whatever `FW_SIDECAR_AGENT_ID` the caller inherited, with no check against the agent of the receiver already running.

**Prevention (round 2):** `_start_receiver` now checks for a live receiver of another copy holding the agent *before* the stale-code kill. If it finds one, it refuses with rc 1 and keeps the live receiver. `cmd_ensure` reports rc 1 with no triple file of ours as `REFUSED: agent … is served by pid …` (also on stderr), never `running`. Pinned by `test_ensure_reports_a_refused_receiver_start_as_refused` and `test_refused_start_leaves_the_live_stale_receiver_running`, both failing on the pre-fix tree.

**Open, not fixed here (each its own bug):** (a) enabled.json agent poisoning by an inherited `FW_SIDECAR_AGENT_ID` in `fw sidecar start` / `_start_watcher`; (b) leaked fixture receivers still alive on this host: pid 3441291 `t4217-envleak` (it blocked AEF) and pid 3575904 `t4283-fixture-agent` (cwd `/tmp/t4283-fx.*`, from round 1). Neither was touched.

### Round 1 (timeline superseded above)

**Symptom:** AEF's receiver stopped answering. The watcher's probe read `receiver not running` from 21:02:52Z (`.context/sidecar/watcher/ticks.jsonl`), the supervisor's receiver restart returned rc=1 every ~5 s from 21:09:46Z (`watcher/events.jsonl:3101`), and nothing restarted it until a manual `fw sidecar start` at 00:45Z. A process for the agent was still answering POSTs until 21:16:41Z (`receiver/events.jsonl:5288`), so the outage was an unreachable live process, not a clean exit.

**Root cause (mechanism confirmed in a fixture; trigger not confirmed):** the restart path cannot recover when a live receiver for the agent has no triple file. `_start_receiver` (`lib/sidecar_cli.py`, rival guard) refuses any start while a live `http_server.py --agent X` exists (T-4208). A receiver whose pid/port/url files were cleared is alive but unreachable, so the guard refuses every restart: rc=1. The supervisor's `_restart_receiver` (`lib/sidecar/watcher.py:800-812`, retried at `:874-875`) and `fw sidecar ensure` (which calls the same `_start_receiver`) both fail that way. `ensure` then reports the receiver as `running` (rc 1 → "running" mapping, `lib/sidecar_cli.py` cmd_ensure). Reproduced in `tests/unit/test_t4283_orphan_receiver_reclaim.py::test_orphan_receiver_of_this_project_is_reclaimed_so_start_proceeds`: rc=1 with an orphan of this project present, before the fix.
What cleared the triple file around 21:02Z is NOT confirmed. Evidence for and against the candidates:
- Test leak: ruled out as far as the code shows. Every sidecar test reference to `receiver.pid` / receiver stop or start runs under a tmp root (`PROJECT_ROOT` pinned, `FW_SIDECAR_ENABLED_DIR` and `FW_SIDECAR_REGISTRY_DIR` isolated by `tests/unit/conftest.py`). None of the commits in the 21:00–22:30Z window touches a sidecar test. A test receiver *does* leak (`t4217-envleak`, pid 3441291, started from a `/tmp/t4218head` copy at 00:50 on 10-17, still alive); it is another agent, not AEF's, so it does not explain this outage.
- `_start_receiver`'s stale/unhealthy branch: in a fixture it SIGTERMs a live receiver whose health check fails. That kills the process rather than orphaning it, so it does not explain the orphan on its own. Its interaction with a concurrent start is the open lead.
- Next step to settle it: `.context/sidecar/receiver/server.log` and the 21:00–21:03Z lines of `receiver/events.jsonl`, which were not read in this pass.

**Why structurally allowed:** (1) the T-4208 guard keys on argv only, so it cannot tell a live orphan of this project from a live receiver of another copy, and it never checks the orphan is reachable; (2) the probe's "receiver not running" is recorded every tick with no escalation for 80 minutes; (3) `ensure` maps a refused start (rc 1) to a green `running`.

**Prevention:** `_reclaim_orphan_receivers` (`lib/sidecar_cli.py`) stops a live receiver for the agent only when it runs in THIS project's root (`/proc/<pid>/cwd`) and is older than `ORPHAN_MIN_AGE_S` (30 s), so a booting receiver is never taken for an orphan. Receivers of other copies still block (T-4208 kept). The four tests in `tests/unit/test_t4283_orphan_receiver_reclaim.py` pin reclaim, the other-copy case, the booting-receiver race, and `ensure` restarting the receiver. Open, not fixed here: rc 1 still maps to `running` in `ensure`'s output (a false green), and an unexplained trigger for the triple-file loss.

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

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-10-17T22:46:37Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-4283-aefs-own-sidecar-receiver-died-silently-.md
- **Context:** Initial task creation

### 2026-10-17T22:53:20Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
