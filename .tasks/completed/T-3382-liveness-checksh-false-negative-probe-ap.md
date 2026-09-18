---
id: T-3382
name: "liveness-check.sh false negative: probe /api/_identity and match project_root, not root-page reachability (OBS-437)"
description: >
  liveness-check.sh false negative: probe /api/_identity and match project_root, not root-page reachability (OBS-437)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [monitor, bug]
components: [agents/monitor/liveness-check.sh]
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
created: 2026-09-18T04:35:23Z
last_update: 2026-09-18T04:42:13Z
date_finished: 2026-09-18T04:42:13Z
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
---

# T-3382: liveness-check.sh false negative: probe /api/_identity and match project_root, not root-page reachability (OBS-437)

## Context

OBS-437. `agents/monitor/liveness-check.sh:63` decided `watchtower: running|stopped`
with `curl -sf -m 2 "$wt_url/"` — the heaviest page in the app under a 2-second
budget. Measured 2026-09-17 with Watchtower confirmed up (identity endpoint
returning our `project_root`, review pages 200): the root page took 4.47s and
2.37s on consecutive hits, curl exited 28, and the rail wrote `stopped`. The
liveness log shows its last `running` sample on 2026-06-12 followed by
`stopped` through 2026-08-14 while the server was in fact serving — a FALSE
NEGATIVE emitted for ~two months before the exec-bit death (T-3380) silenced
the rail entirely. The two bugs were stacked; this one became visible only
because T-3380 fixed the first.

The fix is not a longer timeout. `/` cannot say WHOSE server answered, and on
this host `:3000` belongs to another project (T-1376/T-2732 wrong-server
class) — a bare 200 from the wrong Watchtower is the false-green twin of this
false negative. `/api/_identity` answers in ~1ms and carries `project_root`;
`lib/watchtower.sh:_watchtower_identity_matches` (T-1803/T-3054) is already the
single source of truth for that handshake, used by `fw doctor` and the
launcher's port-kill guard. This rail sources it rather than copying it.

Distinct from OBS-435 (Watchtower-down has no consumer) — that is left alone.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `liveness-check.sh` decides `watchtower` via `_watchtower_identity_matches` sourced from `lib/watchtower.sh` — no second copy of the identity parse, no `curl … "$wt_url/"` reachability probe left in the file
- [x] Three states recorded, not two: `running` (identity matches our `project_root`), `foreign` (something answers `/api/_identity` on our URL but is not ours), `stopped` (nothing answers)
- [x] Bats regression suite with a control leg: a fixture server whose `/` is slower than the old 2s budget but whose `/api/_identity` is ours reads `running`; the same server with a different `project_root` reads `foreign`; no server reads `stopped`; and the old probe shape is shown red against the slow fixture so the green proves something (L-668)
- [x] Sourcing `lib/watchtower.sh` under the script's `set -euo pipefail` does not kill the rail: the script exits 0 and writes a sample when the lib is present, and still exits 0 (falling back to `foreign`/`stopped`) when it is absent
- [x] Live confirmation: with Watchtower up, one run of the script writes `watchtower: running` to `liveness-latest.yaml`; the next cron sample after deploy agrees
- [x] `bin/fw vendor self --check` clean (agents/ is a vendored path) and the exec bit from T-3380 preserved (`git ls-files -s agents/monitor/liveness-check.sh` still 100755)
- [x] `## RCA` written (bug-class gate, T-1550) and OBS-437 marked promoted to this task

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

# The rail sources the canonical identity handshake and no longer carries the old probe
grep -q '_watchtower_identity_matches' agents/monitor/liveness-check.sh
! grep -qE 'curl -sf -m 2 "\$\{wt_url%/\}/"' agents/monitor/liveness-check.sh
# Regression suite green with ZERO skips (T-3217: a skip prints "ok" too)
bats tests/unit/t3382_liveness_identity_probe.bats > .context/working/.t3382-bats.out 2>&1 && ! grep -q '^not ok' .context/working/.t3382-bats.out && ! grep -q '# skip' .context/working/.t3382-bats.out
# Sibling T-3380 suite still green (same file, exec-bit leg)
bats tests/unit/t3380_cron_exec_bit.bats > .context/working/.t3380-bats.out 2>&1 && ! grep -q '^not ok' .context/working/.t3380-bats.out
# Exec bit from T-3380 preserved in the index
git ls-files -s agents/monitor/liveness-check.sh | grep -q '^100755'
# Live: with Watchtower up, one run records running (scoped off when nothing is running — then the run must still exit 0)
PROJECT_ROOT="$PWD" bash agents/monitor/liveness-check.sh && { ! curl -sf -m 5 "$(bin/fw watchtower url)/api/_identity" >/dev/null || grep -q '^watchtower: running' .context/monitors/liveness-latest.yaml; }
# Vendored copy in sync (agents/ is a vendored path, OBS-250: sync BEFORE close)
bin/fw vendor self --check

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

**Symptom:** `liveness-latest.yaml` and every 1-minute JSONL sample said
`watchtower: stopped` while the server was serving review pages at HTTP 200 and
answering `/api/_identity` with our `project_root`. The log's last `running`
sample is 2026-06-12; from there to the exec-bit death on 2026-08-14 it is
`stopped` throughout — roughly two months of a rail reporting the opposite of
reality, every minute.

**Root cause:** the probe asserted the wrong property with the wrong budget.
`curl -sf -m 2 "$wt_url/"` asked "does the heaviest page in the app render in
two seconds?" and treated the answer as "is Watchtower alive?". Measured
2026-09-17: `/` took 4.47s and 2.37s on consecutive hits (single-threaded
Flask, `debug=False`, serving a 3,367-task corpus), curl exited 28, and the
`-f` swallowed the distinction between "timed out" and "connection refused".
The property that was actually wanted — *our* Watchtower is answering — has a
purpose-built endpoint that answers in ~1ms, and that endpoint had been the
framework's identity handshake since T-1803 (2026-05). The rail was written
before it and never migrated.

**Why structurally allowed:** three things, stacked.
1. **No consumer.** Nothing read `watchtower:` out of the liveness rail
   (OBS-435 is the same finding from the other side), so a wrong value cost
   nobody anything and no one looked. A false negative in an unread rail is
   indistinguishable from a correct one.
2. **The rail had no notion of "whose server".** It could only say
   reachable/unreachable. On a host where `:3000` belongs to another project
   (T-1376/T-2732 — 371 hard-coded-port violations across 277 tasks), a
   reachability probe is a false *green* as readily as this one was a false
   *red*; the check was wrong in both directions and the framework had no
   test asserting either.
3. **Reused logic lived in one place but was not reached for.** The identity
   handshake existed in `lib/watchtower.sh` and was used by `fw doctor` and
   the launcher — but nothing required a monitor script to source it, so a
   second, weaker probe survived beside the canonical one.

**Prevention** (distinct from the fix):
- `tests/unit/t3382_liveness_identity_probe.bats` — 7 tests including the
  control leg: the *old* probe shape is run against the slow fixture and
  shown red first (L-668), then the rail is shown green against the same
  server. Pins the three states, the `set -euo pipefail` sourcing, the
  lib-absent degradation, and the absence of the old probe from the file.
  Also caught a real defect in the first version of the fix (`|| echo 000`
  after `-w '%{http_code}'` yields `000000`, reading a dead port as
  `foreign`) — test 4 went red before any sample was written.
- `tests/fixtures/slow_watchtower.py` reproduces the measured shape (slow
  `/`, fast identity) so the failure is re-creatable without a real server.
- The rail now *sources* the canonical handshake; there is one identity
  parse in the repo for the next drift to hit.
- OBS-435 (no consumer for Watchtower-down) is left open on purpose: this
  task fixes the rail's answer, not the absence of anyone asking. The two
  are separate bugs with separate fixes (one bug = one task).

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

### 2026-09-18T04:35:23Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3382-liveness-checksh-false-negative-probe-ap.md
- **Context:** Initial task creation

### 2026-09-18T04:36:08Z — status-update [task-update-agent]
- **Change:** tags: +monitor

### 2026-09-18T04:41:34Z — status-update [task-update-agent]
- **Change:** tags: +bug

## Reviewer Verdict (v1.5)

- **Scan ID:** R-97dd7ead
- **Timestamp:** 2026-09-18T04:42:21Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 135
     - evidence: `git ls-files -s agents/monitor/liveness-check.sh | grep -q '^100755'`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 137
     - evidence: `PROJECT_ROOT="$PWD" bash agents/monitor/liveness-check.sh && { ! curl -sf -m 5 "$(bin/fw watchtower url)/api/_identity" >/dev/null || grep -q '^watchtower: running' .context/monitors/liveness-latest.y`

### 2026-09-18T04:42:13Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
