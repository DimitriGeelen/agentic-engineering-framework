---
id: T-4205
name: "Tests leak into the host's real TermLink outbound queue: sidecar receipt tests
  (T-3684/T-3745) and a learning-post test (PL-235) reached /root/.termlink/outbound.sqlite
  and the fleet learnings channel (010 report)"
description: >
  010-termlink msg 967ce2aa (2026-10-14): 11 sidecar.receipt posts 2026-10-07 05:29Z
  from_agent t3684/t3745 (messages legacy-1, m1) to test-only inboxes were dead-lettered
  in 010's real outbound queue and fired their canary for a week; 2026-10-13 10:21Z
  a 'test learning' (PL-235, task T-500, origin_project proj) was queued for the REAL
  channel:learnings and only stopped because their flush could not deserialize it.
  Fix: every test that can reach a TermLink transport runs with an isolated TERMLINK
  runtime/HOME or a fake transport; add a guard (fixture/conftest or bats helper)
  that fails a test which would touch the host queue/hub. Find the T-3684/T-3745 tests
  and the learning-post test. Register in concerns.yaml (structural: tests can publish
  fleet-wide).

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
created: 2026-10-14T21:49:04Z
last_update: 2026-10-14T23:31:47Z
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
  - ts: '2026-10-14T21:51:08Z'
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
  - ts: '2026-10-14T22:00:37Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=280,acs=9)
    rubric_sha: e4a00f38e801
---

# T-4205: Tests leak into the host's real TermLink outbound queue: sidecar receipt tests (T-3684/T-3745) and a learning-post test (PL-235) reached /root/.termlink/outbound.sqlite and the fleet learnings channel (010 report)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] RCA written: every test/code path that reached the host TermLink transport (outbound queue / hub) is named with file:line and the mechanism (real `termlink` on PATH, real HOME, or real TERMLINK_RUNTIME_DIR)
- [x] Shared isolation mechanism: one pytest autouse fixture in tests/unit/conftest.py and one bats helper (tests/test_helper.bash), both putting the recording fake tests/lib/termlink-tripwire/termlink first on PATH and pointing TERMLINK_RUNTIME_DIR at a per-test temp dir (HOME is deliberately not redirected: git and ~/.claude read it — see RCA)
- [x] Every affected test file (sidecar receipt/watcher/session-ready tests T-3684/T-3745, learning-post tests add_learning_id_allocator.bats and context_learning.bats) runs through the shared isolation and no longer reaches ~/.termlink
- [x] Tripwire: a test that would call the real termlink transport fails loudly (fake binary records the call and the suite-wide guard asserts no un-isolated call happened)
- [x] Regression test proves the old test shape now hits the fake/tmp runtime, not the host runtime
- [x] Every test file that references termlink still passes (grep tests/ -rl termlink, run them all); ~/.termlink/outbound.sqlite mtime/size unchanged across the affected suites — the 20 t3580_* reds were made hermetic by the follow-up (see Updates 2026-10-15): t3580_*, t3986, t4010, t3852, t3582, t3949, test_t3579, test_t3581_round4 and the tripwire regression: 544 passed both inside a dispatched worker and with its env unset; outbound.sqlite unchanged (102400 bytes, mtime 1792014170)
- [x] G-115 in .context/project/concerns.yaml names the structural fix and this task

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
bats tests/unit/t4205_termlink_tripwire.bats
python3 -m pytest -q -p no:cacheprovider tests/unit/test_t4205_termlink_tripwire.py
bats tests/unit/add_learning_id_allocator.bats tests/unit/context_learning.bats tests/unit/sidecar_inbox_hook.bats
python3 -m pytest -q -p no:cacheprovider tests/unit/test_sidecar_receipts_t3684.py tests/unit/test_sidecar_session_ready_t3745.py tests/unit/test_sidecar_watcher_t3684.py tests/unit/test_sidecar_receiver_t3693.py
bin/fw test lint
# structure audit exits 1 on WARN-only; the gate is "no FAIL"
for i in $(seq 1 30); do bin/fw audit --section structure > .context/scratch/t4205-audit.out 2>&1; [ $? -ne 75 ] && break; sleep 20; done; grep -q "^Fail: 0" .context/scratch/t4205-audit.out
python3 -m pytest -q -p no:cacheprovider tests/unit/t3580_judge_cli_test.py tests/unit/t3580_round8_test.py

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

**Symptom:** on 010-termlink's host, unit tests published to the real TermLink outbound queue
and fleet channel. Eleven `sidecar.receipt` posts (2026-10-07) carried `from_agent` t3684 and
t3745 into test-only inboxes `inbox:<hub>/t3684/old-peer` and `inbox:<hub>/t3745/peer` (messages
`legacy-1`, `m1`) and fired a canary for a week. A `test learning` (PL-235, task T-500, origin
`proj`) was queued on the real `channel:learnings` (2026-10-13), and stopped only because the peer
could not deserialize it.

**Root cause (two leaks, both reaching the host binary by name):**
1. Sidecar receipts. `tests/unit/test_sidecar_receipts_t3684.py:123,124,146` (and the watcher,
   session-ready, receiver suites that drive the same path) call `receipts.send(...)` with the
   default runner. `lib/sidecar/receipts.py:_hub_post` (L208-290) runs `termlink channel post`
   by name. The topic is derived from `circuit.hub_id()`, which runs `termlink hub fingerprint`;
   on a host with a live hub that succeeds, so the topic is built and the post goes out.
   Reproduced in scratch with a fake that answers the fingerprint and accepts posts: the four
   sidecar suites made 46 `channel post` calls, including `inbox:<hub>/t3684/old-peer` (legacy-1,
   from_agent t3684) and `inbox:<hub>/t3745/peer` (m1, WAITING_NO_RECIPIENT), the peer's exact
   topics. With a refusing fake the fingerprint fails first and nothing posts, which is why a
   plain run looked clean.
2. Learning post. `tests/unit/add_learning_id_allocator.bats:65` (and `context_learning.bats:139`)
   run `fw context add-learning "test learning"` in a temp project named `proj`. That reaches
   `agents/context/lib/learning.sh:143` and `lib/publish-learning-to-bus.sh`, which probes
   `termlink channel post --help` and then posts `channel:learnings` through the host binary.
   The probe succeeded on the host, so the post ran.

**Why structurally allowed:** nothing made a unit test's transport a test concern. The only
existing guard, `tests/unit/conftest.py` `_sidecar_tests_cannot_reach_the_live_hub` (T-3727), set
`TERMLINK_RUNTIME_DIR` for `test_sidecar_*` modules only, so the bats learning tests were outside
it, and a runtime-dir pin does not stop a binary that finds its hub through HOME. I did not test
that last point against the real binary, since that would publish. Nothing asserted that a test
never ran a real subprocess on the default-runner path.

**Prevention (structural, suite-wide):**
- `tests/lib/termlink-tripwire/termlink`: a PATH-first fake. It records every call, classifies it as
  `probe` (hub fingerprint, discover, channel list, remote ping, fleet doctor, any `--help`/`--version`)
  or `call` (everything else), and refuses with exit 97. The classification lives in this one file.
- `tests/unit/conftest.py` `termlink_tripwire` (autouse): prepends the fake, sets
  `TERMLINK_RUNTIME_DIR` to a tmp dir, and fails the test at teardown if its record has a `call`.
- `tests/test_helper.bash`: prepends the fake and defines `tripwire_assert`. Wired into the teardown
  of `add_learning_id_allocator.bats` and `context_learning.bats`. `sidecar_inbox_hook.bats` already
  shadows `termlink` with its own sandbox fake.
- Regressions: `tests/unit/test_t4205_termlink_tripwire.py` (old receipt shape is refused and
  recorded, not posted) and `tests/unit/t4205_termlink_tripwire.bats` (learning-post shape is refused
  and fails `tripwire_assert`; probes pass). The loud failure was also shown with throwaway publishing
  probes in both pytest and bats; both failed and were deleted.

**Residual, stated plainly:** HOME is not redirected (git identity and `~/.claude` depend on it), so
the guard is PATH shadowing, and an absolute-path call such as `/usr/local/bin/termlink` would bypass
it. Grep found no such call in `tests/unit` (`TERMLINK_BIN` overrides only appear in templates). 30 of the
61 bats files that reference termlink do not load `test_helper` (`sidecar_inbox_hook.bats` shadows
termlink itself, so it is safe), so the bats side does not cover them. Pytest outside `tests/unit`
is also uncovered.
**Open red (not fixed here):** the `t3580_*` judge test files (other worker's, still under edit) read
the live hub fingerprint and subscribe to fleet inbox topics. The tripwire fails 20 of their tests
(`channel subscribe` refused). Pre-tripwire they passed only because they reached the real hub. The
owner needs to inject a runner or pin the hub; that is outside this task. The
live e2e tests in `tests/integration` run the real binary on purpose and are not covered. G-115 stays
open for the operator to close.

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

### 2026-10-15 — making the t3580 judge suites hermetic
- **Chose:** one autouse fixture `hermetic_review_env` in `tests/unit/_review_runtime.py` (the runtime double every review-ledger suite already imports), imported by each of its 16 user files. It unsets `FW_SIDECAR_AGENT_ID` / `FW_REVIEW_WORKER` / `FW_DISPATCHED_WORKER`, pins `FW_SIDECAR_HUB_ID`, and replaces `verdict_ledger._consult_reader` (an existing seam) with an empty reader. No production change and no new seam: `FW_SIDECAR_HUB_ID` and `_consult_reader` already existed.
- **Why:** the 20 reds had two causes, not one. 17 were the host worker's `FW_SIDECAR_AGENT_ID` leaking in (rows attributed to `reviewer-t4205b-t3580`, so `unknown` instead of `green`). With that env unset only 3 failed, and those were the hub/consult reads. One fixture covers both, wherever the suite runs.
- **Rejected:** the global `tests/unit/conftest.py` (would also pin the hub for the sidecar suites another worker owns, some of which test the unpinned path); weakening the tripwire or skipping tests (forbidden by the brief).

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-10-14T21:49:04Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-4205-tests-leak-into-the-hosts-real-termlink-.md
- **Context:** Initial task creation

### 2026-10-14T21:51:08Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-10-14 — pre-fix reproduction (worker t4205-testleak, scratch harness, no real binary)
- Recording fake that answers `hub fingerprint` and accepts posts, run over the four sidecar suites
  (`test_sidecar_receipts_t3684`, `_session_ready_t3745`, `_watcher_t3684`, `_receiver_t3693`): 196 passed,
  46 `channel post` calls, including `inbox:<hub>/t3684/old-peer` (legacy-1, from_agent t3684) and
  `inbox:<hub>/t3745/peer` (m1, WAITING_NO_RECIPIENT). Same fake refusing: 106 passed, 0 posts.
- `add_learning_id_allocator.bats` under the same fake: `channel post --help` probe only; under the real
  binary the probe succeeds and the post runs (origin `proj`, PL-235 on the fleet channel).
- `~/.termlink/outbound.sqlite` mtime/size unchanged before and after every run in this task.

### 2026-10-14 — verification (after the tripwire)
- `bats tests/unit/t4205_termlink_tripwire.bats` 3/3; `pytest tests/unit/test_t4205_termlink_tripwire.py` 2/2.
- Throwaway publishing probes (pytest and bats) failed at teardown as intended, then were deleted.
- Termlink-referencing bats (61 files) 374 ok, 0 not ok. Termlink-referencing pytest (68 files, minus `t3580_*`) 1034 passed, 2 skipped.
- `bin/fw test lint`: 6 FAIL, none in files this task touched (`.context/working/t4088/*.sh`, `agents/sessions/{antigravity,claude-code}/list.sh` and their vendored copies; SC1071 / SC2148). `bin/fw audit --section structure`: FAIL on "every test file is tracked by git" until this commit lands (the new test files), then also the untracked `tests/unit/t3852_unavailable_seat_test.py` (another worker's file, not staged here).
- Run and red: `t3580_*` judge suites (20 failed, see RCA open red). Not run: `tests/integration` live e2e (needs claude and a live hub on purpose).

### 2026-10-15 — follow-up: t3580 judge suites made hermetic (worker t4205b-t3580)
- Pre-fix, inside a dispatched worker: t3580_* + t3986/t4010/t3852 + tripwire regression 20 failed, 404 passed. With the worker env unset (`env -u FW_SIDECAR_AGENT_ID …`): 3 failed, 396 passed (round8 consult-traffic x2: "hub fingerprint unreadable"; inbox-hook control leg). So 17 of the 20 were the host's `FW_SIDECAR_AGENT_ID` leaking into the suite, and 3 were the hub/consult reads. The RCA's "open red" attribution of all 20 to the tripwire was only partly right.
- Fix: `hermetic_review_env` autouse fixture in `tests/unit/_review_runtime.py`, imported by its 16 users; round8 inbox-hook control names its own `FW_SIDECAR_AGENT_ID`. Tests only: no lib/ change, tripwire untouched, no skips.
- After: the same set plus t3582, t3949, test_t3579, test_t3581_round4: 544 passed in the worker env and 544 passed with it unset. `~/.termlink/outbound.sqlite` 102400 bytes, mtime 1792014170, before and after.
- `bin/fw test lint`: the same 6 pre-existing FAILs, none in these files. `bin/fw audit --section structure`: one FAIL, self-vendor drift on a `web/` file this follow-up did not touch (another worker's); no vendor sync run because no vendored path changed here.
