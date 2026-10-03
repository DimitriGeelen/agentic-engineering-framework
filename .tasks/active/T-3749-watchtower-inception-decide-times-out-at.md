---
id: T-3749
name: "Watchtower inception decide times out at 30 s and reports Command timed out
  although the decision landed"
description: >
  web/blueprints/inception.py runs fw inception decide with timeout=30; the chain
  runs past 30 s, the operator sees a timeout for a decision that DID land (T-3631,
  2026-10-02), and the kill can interrupt post-completion steps (T-3744 root cause).
  Measure the chain, detach or speed the slow side effects, make the message reflect
  what landed.

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
created: 2026-10-02T22:33:14Z
last_update: 2026-10-03T12:18:13Z
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
  - ts: '2026-10-02T22:45:22Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=269,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-10-02T22:45:37Z'
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

# T-3749: Watchtower inception decide times out at 30 s and reports Command timed out although the decision landed

## Context

Watchtower ran `fw inception decide` under `run_fw_command(timeout=30)`. On
T-3631 (2026-10-02) the chain ran past 30 s, was killed mid-chain, and the page
reported "Automatic completion was blocked by a framework gate … Reason: Command
timed out" — for a decision that had landed and a task that had completed.

### Measured decide chain (before the fix)

Harness: `tests/scripts/t3749-decide-timing.sh [--xtrace]` — local clone of this
repo into a scratch dir, a synthetic inception filed there, the clone's `bin/fw`
run the way Watchtower runs it (CLAUDECODE stripped, `--from-watchtower`). Real
corpus size; no real task decided. Per-step times are from the `--xtrace` run
(PS4 carries `$EPOCHREALTIME`, set through BASH_ENV because bash ignores an
inherited PS4 as root); the plain run measured task-in-completed/ at 26.4 s and
exit at 41.7 s.

| # | Step | Window (s) | Wall (s) |
|---|------|-----------:|---------:|
| 1 | bin/fw start + decide preflight (readiness, review marker, disposition) | 0.0–0.6 | 0.6 |
| 2 | Decision write (`## Decision` block, Human-AC tick, Updates entry) | 0.6–0.8 | 0.2 |
| 3 | update-task.sh start + reviewer-verdict revalidation (`verdict_ledger.py apply`) | 0.8–2.5 | 1.7 |
| 4 | AC / verification / recommendation gates | 2.5–2.7 | 0.2 |
| 5 | **Self-deferral gate** (`lib/design_register.py self-deferral` — YAML-parses every task) | 2.8–23.1 | **20.3** |
| 6 | Reviewer static scan | 23.1–23.4 | 0.3 |
| 7 | Status write + `git mv` to completed/ — **primary result** | 23.4–23.5 | 0.1 |
| 8 | Notify, focus clear | 23.5–23.6 | 0.1 |
| 9 | Components auto-populate (grep/sed per fabric card + git mining) | 23.6–34.8 | 11.1 |
| 10 | Episodic generation (incl. 0.9 s post-write index) | 34.8–37.3 | 2.6 |
| 11 | Continuous-mode, archived-horizon invariant | 37.3–37.5 | 0.1 |
| 12 | `emit_review` (review URL, link validator) | 37.5–39.6 | 2.2 |
| | **Total** | | **39.6** |

BVP estimate: not on this path (update-task.sh runs it only on `started-work`,
backgrounded). Outcome backprop: inside step 11, <0.1 s.

### After the fix

`LazyTaskIndex` (step 5 loads only the ids a task names; the same predicate for
the register close-check that build closes also paid): plain runs measured
task-in-completed/ at **3.2 s** and exit at **18.0–18.3 s** (2 runs). The 15 s
after the move (steps 9–12) now run in the detached runner; Watchtower answers
on the primary result.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] The decide chain is measured: wall time per step (decision write, completion, episodic, reviewer, BVP, other side effects) recorded in ## Context
- [x] A Watchtower GO returns well inside its timeout: the primary decision and completion run synchronously; slow side effects run detached and their outcome is logged, so a timeout can no longer cut the chain mid-flight
- [x] When the decision landed, Watchtower never says "Command timed out" / "Automatic completion was blocked"; it says what landed and what is still running
- [x] Regression test covers the message classification (landed + timed-out side effect → success wording)

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
- [ ] [REVIEW] Recording an inception decision in Watchtower says what landed and what is still finishing
  **Steps:**
  1. Open Watchtower's approvals page (`cd /opt/999-Agentic-Engineering-Framework && bin/fw watchtower url`, then add `/approvals`) or any pending inception at `/inception/T-XXXX`
  2. Record a decision (GO / NO-GO / DEFER) on an inception you actually want decided
  3. Read the message that replaces the decide form (or the banner after the page reloads)
  **Expected:** Within a few seconds the message says "Decision recorded — GO" (or your choice); if follow-up steps are still running it adds a ⏳ line saying they are finishing in the background, with a log path. It never says "Command timed out", and it only says "blocked by a framework gate" when completion was really refused (with the gate's reason).
  **If not:** Screenshot the message and note the task id and the time; the run's log is under `.context/working/decide/<task>-<time>/`.

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

timeout 600 python3 -m pytest tests/unit/test_t3749_decide_detached.py tests/unit/test_inception_decide_htmx_error.py tests/web/test_inception_decide_hardening.py tests/web/test_inception_decide_e2e.py tests/unit/test_decide_commit.py tests/unit/test_inception_decide_warning_widen.py tests/unit/test_t3694_design_register.py -q -p no:cacheprovider > /tmp/.t3749-pytest.out 2>&1 && grep -q passed /tmp/.t3749-pytest.out && ! grep -qE "[0-9]+ failed" /tmp/.t3749-pytest.out
python3 -c "import ast,sys; [ast.parse(open(f).read()) for f in ('web/decide_runner.py','web/blueprints/inception.py','lib/design_register.py')]"
grep -q "LazyTaskIndex(root) if tasks is None" lib/design_register.py
python3 -c "s=open('web/blueprints/inception.py').read(); b=s[s.index('def record_decision'):s.index('def _decision_recorded_in_task')]; assert 'run_fw_command' not in b and '_run_decide(' in b"
bin/fw vendor self --check
bin/fw watchtower current

## RCA

**Symptom:** GO on T-3631 in Watchtower showed "⚠ Your decision is saved. Automatic completion was blocked by a framework gate … Reason: Command timed out", while the decision had landed and the task had completed (reviewer stamp 27 s after the decision). The kill also left a stale index entry and, before T-3744, `horizon: now` on completed tasks.

**Root cause:** two faults compounding. (1) Watchtower ran the whole decide chain synchronously under `run_fw_command(timeout=30)`, which kills the child on timeout and returns the string "Command timed out" as stderr; the route then classified "decision landed + non-zero" as a gate refusal, so a kill was worded as a gate. (2) The chain had grown to ~40 s: the T-3694 self-deferral gate YAML-parsed all ~3,700 task files on every close (20.3 s) to look up the few ids a task names, so the primary result alone took ~23 s — inside 30 s only by luck of the corpus size.

**Why structurally allowed:** nothing measured close latency, so each gate added cost silently, and the Watchtower path had a fixed timeout that only ever failed after the corpus grew past it. The message classifier had two buckets (landed / not landed) and treated every non-zero as a gate, so "killed" had no word of its own.

**Prevention:** the chain is never under a request timeout again (detached runner, own session, flock against double starts) and the message is classified from four observed facts (landed, completed, running, rc), pinned by `tests/unit/test_t3749_decide_detached.py` (a running chain can never be classified as a gate refusal; a slow fake chain outlives the wait and finishes). `tests/scripts/t3749-decide-timing.sh` re-measures the chain per step on the real corpus.

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
**Rationale:** The kill is gone by construction (the decide runs in its own session with no timeout) and the primary result now lands in ~3 s instead of ~23 s, so Watchtower answers well inside its wait. Messages are classified from what actually happened, and every Agent AC is backed by a test. What remains is your read of the wording on a real decision (Human AC).
**Evidence:**
- Measured chain (## Context): task-in-completed/ 23.4 s → 3.2 s; exit 39.6–41.7 s → 18 s; the 20.3 s step was the self-deferral gate's full task index
- `tests/unit/test_t3749_decide_detached.py`: 25 tests — classify table, wording per outcome (landed+running, landed+done, landed+gate-refused, not landed, pending, busy), slow fake chain outlives the wait, finishes in its own session, second launch refused, failed follow-up commit surfaced
- Existing decide suites green after moving their mocks to `_run_decide` (htmx error, hardening, e2e with the real chain, vendored e2e, commit, warning widen)
- Independent review: `docs/reports/T-3749-review-codex.md`

## Decisions

### 2026-10-03 — where the chain stops being synchronous
- **Chose:** detach the WHOLE `fw inception decide` (own session, per-task flock) and have Watchtower wait for the primary result (decision written, task in completed/), rather than splitting update-task.sh into a synchronous core and backgrounded side effects.
- **Why:** update-task.sh's guarantees stay exactly as they are (same order, same gates, nothing moved); the only thing that changes is that no request timeout can reach the process. The speed-up came from the cheap safe fix in the one predicate that dominated (lazy index, same answers per id).
- **Rejected:** backgrounding steps 9–12 inside update-task.sh — changes what a CLI close guarantees on return (components/episodic present) for every caller, to fix one caller. Raising the timeout — moves the cliff, keeps the kill.

### 2026-10-03 — gate wording kept for a genuine refusal
- **Chose:** "Automatic completion was blocked by a framework gate" still appears, but only when the chain FINISHED with the decision written and the task still in active/ (LANDED_GATE_REFUSED), with the gate's own reason. A still-running chain is LANDED_COMPLETING ("completing the task is still running"), and a kill can no longer happen.
- **Why:** the brief requires the existing gate wording for a real refusal; the AC forbids it for the timeout case, which no longer exists.

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

### 2026-10-02T22:33:14Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3749-watchtower-inception-decide-times-out-at.md
- **Context:** Initial task creation

### 2026-10-02T23:21:46Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
