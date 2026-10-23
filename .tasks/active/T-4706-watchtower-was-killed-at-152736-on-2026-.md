---
id: T-4706
name: "Watchtower was killed at 15:27:36 on 2026-10-23 and stayed down ~1h47m unnoticed;
  nothing restarts it (watchtower-ensure last ran 2026-10-22 18:47)"
description: >
  Evidence: watchtower.log ends at 15:27:36 with two /api/_identity probes (127.0.0.1
  and 192.168.10.107) and no error, the pattern of bin/watchtower.sh start's port-holder
  identity check before it frees the port; /api/_identity includes project_root, so
  the caller ran a Watchtower start/restart FOR THIS PROJECT (or with PROJECT_ROOT
  pointing here). No OOM, no worker typed a stop/kill (transcripts searched). At 15:27:29
  the parent's close batch for T-4693 and T-4690 started (their tests: t4693_watchtower_start_time,
  t4690_clean_tree_after_close, episodic_footprint_refresh, t4403_hook_block_preserve).
  Also running then: workers for T-4691/T-4692 (upgrade tests) and T-4694. Find the
  caller (a test that runs watchtower.sh start/restart with the real PROJECT_ROOT,
  or an upgrade/restart path), fix it so tests never touch the live Watchtower (extend
  T-4671's live_repo_guard to the live Watchtower pid), and add supervision: a cron/systemd
  ensure that restarts a dead Watchtower and an alert when it was down (watchtower-ensure.log
  last entry 2026-10-22T18:47:43Z). Restarted by the parent at 17:14 (pid 79042).

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
created: 2026-10-23T15:16:04Z
last_update: '2026-10-23T15:45:35Z'
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
  - ts: '2026-10-23T15:16:53Z'
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
  - ts: '2026-10-23T15:45:35Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=338,acs=9)
    rubric_sha: e4a00f38e801
---

# T-4706: Watchtower was killed at 15:27:36 on 2026-10-23 and stayed down ~1h47m unnoticed; nothing restarts it (watchtower-ensure last ran 2026-10-22 18:47)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [ ] The caller that killed the live Watchtower at 13:27:36Z is named in ## RCA with file:line and evidence, OR (if unattributable) the placement mechanism below is recorded as the most likely class with the evidence for it
- [ ] The caller can no longer signal the live project's Watchtower from a test (fixed at the source; regression test fails without the fix)
- [ ] `bin/watchtower.sh start` (and restart) runs the server in its OWN systemd scope (reuse lib/agent-scope.sh `fw_agent_scope_prefix`, slice aef.slice, unit aef-watchtower-*), falling back cleanly where systemd is absent; a test proves the started server's /proc/<pid>/cgroup is its own scope, not the caller's unit. Evidence 2026-10-23 17:2x: a `fw watchtower start` from the parent session put the server in `/system.slice/agentic-fleet-cockpit.service` (055's cockpit unit, which hosts this session), so a cockpit restart would kill it; the 15:27 victim had been started by a worker (w4663) and lived in whatever unit that was. Parent moved the live server by hand: `systemd-run --scope --slice=aef.slice --unit=aef-watchtower-<ts> bin/fw watchtower restart` -> cgroup /aef.slice/aef-watchtower-1792770391.scope.
- [x] T-4671 live_repo_guard also fails a test that changes or kills the live Watchtower pid (bats test covers it)
- [x] Supervision: a cron registry entry runs an ensure path that restarts a dead Watchtower and appends the outage to a log; `fw cron generate` run (crontab install is the operator's)
- [x] `fw doctor` WARNs when a Watchtower outage was recorded recently (bats test covers it)
- [x] `bin/fw vendor self --check --task T-4706` clean

### Human
- [ ] [RUBBER-STAMP] Install the regenerated crontab so the Watchtower keep-alive (`watchtower-ensure-5m`) runs
  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && bin/fw cron install && grep -c "watchtower ensure" /etc/cron.d/agentic-audit-999-agentic-engineering-framework`
  **Expected:** prints `1`; `bin/fw doctor` then shows `Cron registry in sync` (the Verification line that checks it turns green).
  **If not:** run `bin/fw cron status` and note the error.

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
#
# Vendored-path hint (T-3236, T-4419): if you edited bin/fw, lib/, agents/, policy/,
# web/, tools/ or .tasks/templates/, run `bin/fw vendor self` and add
#     bin/fw vendor self --check --task T-XXXX
# (your own task id). It checks only the files your commits changed, so another
# worker's uncommitted edit does not block your close; that drift is listed as
# "in flight, not this task". The whole-tree `--check` stays for audit/pre-push.
timeout 300 env -u FW_DISPATCHED_WORKER bats tests/unit/t4706_watchtower_live_guard.bats > /tmp/.t4706-a.out 2>&1 && ! grep -q "^not ok" /tmp/.t4706-a.out && grep -q "^ok 11 " /tmp/.t4706-a.out
test "$(grep -c '# skip' /tmp/.t4706-a.out)" -eq 0
timeout 600 bats tests/unit/t3877_watchtower_ensure.bats tests/unit/t4671_live_repo_guard.bats tests/unit/t3661_watchtower_status_exit.bats tests/unit/t4306_watchtower_zombie_pid.bats > /tmp/.t4706-b.out 2>&1 && ! grep -q "^not ok" /tmp/.t4706-b.out
test "$(grep -c '# skip' /tmp/.t4706-b.out)" -eq 0
bash -n bin/fw && bash -n bin/watchtower.sh && bash -n lib/watchtower-ensure.sh
out=$(bin/fw doctor 2>&1); echo "$out" | grep -q "Cron registry in sync" && ! echo "$out" | grep -q "Cron registry edited but not generated"
bin/fw vendor self --check --task T-4706

## RCA

**Symptom:** The live Watchtower (pid 1697481) died at 15:27:36 local (13:27:36Z) on 2026-10-23. Its log ends with two `/api/_identity` 200s (127.0.0.1, then 192.168.10.107) and no error. It stayed down about 1h47m until the parent restarted it at 17:14 (pid 79042). The 5-minute RSS monitor (`.context/monitors/watchtower-rss.jsonl`) logged `down` from 15:30 to 17:10, and nothing acted on it.

**Root cause (killer): not attributed. These causes were ruled out by evidence:**
- **`bin/watchtower.sh stop`/`restart`:** `do_stop` (bin/watchtower.sh:159-206) deletes the pid file, but at 15:12Z the pid file still named 1697481 (mtime 00:35:35, `fw watchtower status` → "Stale PID file exists").
- **`bin/watchtower.sh start`'s fuser path (:339-366):** with a live pid file, start takes the `is_running` reuse branch (:286-300) and never reaches fuser. That also makes the "port-holder check before freeing the port" reading of the two probes impossible: that path probes 127.0.0.1 twice, and the log shows one.
- **The parent's close batch for T-4693/T-4690:** it started at 13:27:39Z (transcript 087d333f), 3 s after the death, and none of the 4 tests it ran touches Watchtower (grepped).
- **The T-4692 worker's `bin/fw upgrade` of a temp consumer (13:27:17Z, still running at the kill):** step 4b only prints a restart NOTE (lib/upgrade.sh:2449-2462), and the consumer had no Watchtower state.
- **OOM, segfault, a systemd unit stop:** kernel and system journals for 15:27:20-15:27:50 show none. `pen-tmux-server.service` stopped at 15:27:48, 12 s later. The w4663 worker scope `run-r06fff2e8…scope` (the worker that started pid 1697481 at 22:35Z) was deactivated at 00:17:01 on 2026-10-23.
- **Other agent transcripts at 13:26:30-13:27:40Z** (AEF, 055, 832, termlink): no kill, stop or restart of this Watchtower.

What remains: a userspace signal by pid or port from a process with no transcript record. Plausible sources are a test or script whose PROJECT_ROOT resolved to the live checkout. lib/paths.sh:38-45 falls back to the live repo when PROJECT_ROOT is unset, and every session and worker here exports `PROJECT_ROOT=/opt/999-Agentic-Engineering-Framework`, so a test that forgets to override it targets the live server.

**Root cause (unnoticed outage, the part that is fixed):** the only ensure path was session-start (agents/context/post-compact-resume.sh → lib/watchtower-ensure.sh); `watchtower-ensure.log` last ran 2026-10-22T18:47:43Z. `liveness-1m` and the RSS monitor *record* down states; nothing restarted the server and nothing surfaced the outage.

**Why structurally allowed:** bin/watchtower.sh had no notion of "called from a test"; the T-4671 live_repo_guard watched git status/index only, not live processes; no cron restarted a dead Watchtower; doctor reported only the current state (and only on demand).

**Prevention:**
- `bin/watchtower.sh` `_watchtower_live_test_refusal` refuses start/stop/restart/ensure (exit 4) under bats or pytest when PROJECT_ROOT is the checkout the test runs from. Override: `FW_WATCHTOWER_ALLOW_LIVE_IN_TEST=1`.
- `tests/live_repo_guard.bash` fails a test when a Watchtower that was alive at begin is dead or replaced at end.
- `watchtower-ensure-5m` cron runs `fw watchtower ensure`, which starts a dead Watchtower and appends the outage to `.context/working/watchtower-outages.jsonl`.
- `fw doctor` WARNs on any outage in the last 7 days (`FW_WATCHTOWER_OUTAGE_DAYS`), so the next kill is both repaired within 5 min and visible, with its pid and last-seen time for attribution.
- Pinned by tests/unit/t4706_watchtower_live_guard.bats (9 of 11 fail on HEAD; the 2 passing are control legs).
- Side fix: t3877 setup now unsets FW_DISPATCHED_WORKER (4 of 6 cases were red when run from a dispatched worker).

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

### 2026-10-23T15:16:04Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-4706-watchtower-was-killed-at-152736-on-2026-.md
- **Context:** Initial task creation

### 2026-10-23T15:16:51Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
