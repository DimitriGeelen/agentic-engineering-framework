---
id: T-4802
name: "lib/dispatch_records.py: local backend for the shared worker contract (§6.2
  store + conformance adapter), option A of T-4801"
description: >
  T-4801 GO (2026-10-27, option A): build the local backend the shared worker contract
  (wc/0.3.3) requires (T-4435 condition 3) as a store plus conformance adapter only.
  No wiring into fw termlink dispatch or run.sh (options B/C are later decisions;
  T-4435 condition 4: shadow before switch-over). Design is fixed by docs/specs/shared-worker-contract-transitions.md
  §2 (record schema), §3 (transition table, fence reasons, outcome derivation), §4
  (allocation, no overlap), §6.1-6.5 (local mechanism). Entry point fixed by tests/conformance/worker-contract/run_local.py:52-81
  (lib/dispatch_records.py exposing conformance_adapter()). Research: docs/reports/T-4801-local-reference-backend.md.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [lib/dispatch_records.py, tests/unit/test_worker_contract_vectors.py]
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
created: 2026-10-27T09:50:02Z
last_update: 2026-10-27T10:06:15Z
date_finished: 2026-10-27T10:06:15Z
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
  - ts: '2026-10-27T09:50:26Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 2
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=2 (body:telemetry-or-audit-entry); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-4802: lib/dispatch_records.py: local backend for the shared worker contract (§6.2 store + conformance adapter), option A of T-4801

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->
Option A of T-4801 (GO 2026-10-27): the §6.2 store and its conformance adapter, judged by tests/conformance/worker-contract/vectors.yaml. Feature build, not a bug: no RCA.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] lib/dispatch_records.py implements the §6.2 store: one JSON record per dispatch under a configurable root (default `.context/dispatch-records/`). Every write takes an exclusive flock on `<dispatch_id>.lock`, reads, checks nonce + supervisor_gen + expected prior state, applies, writes a temp file, fsyncs, renames over the record, fsyncs the directory, and releases. The lock times out (10 s default, injectable) and the write fails closed with fence_reject(cas_mismatch)
- [x] It implements the wc/0.3.3 §3 transition table (T1, T2, T3, T3b, T4, T5, T6, T6b, T7a-d, T8 and T-RECLAIM), the closed fence_reject reason list, per-attempt fencing, no overlapping attempts (§4.3) and the outcome derivation with refusal ahead of rule 1 (the order all three parties already run; v0.3.4 draft). Dispatch closure (v0.3.4 draft §4.7) is NOT implemented: the local backend keeps dispatches open like the hub
- [x] `conformance_adapter()` returns an adapter for run_local.py with an injected clock and liveness probe. It declares its capabilities honestly: supervisor_gen fencing; no answer_channel (§5) and no real_worker unless actually built, so those cases report n/a or not-implemented
- [x] `python3 tests/conformance/worker-contract/run_local.py` reports 0 fail. Every case whose requires the adapter meets passes, and the result table (pass / fail / not-implemented / n/a per case) is recorded in the task Updates. A mutant check (the adapter reporting one wrong outcome) makes run_local.py FAIL, recorded too
- [x] Unit tests in tests/unit/t4802_dispatch_records_test.py cover the store mechanics directly: CAS refusal on a stale prior state, lock timeout fails closed, a crash mid-write leaves the old record intact (temp file not renamed), and concurrent writers serialise
- [x] Scope fence holds: no change to agents/termlink/, run.sh, lib/spawn-env.sh or the dispatches.jsonl ledger (`git diff --stat` of the task's commits touches only lib/dispatch_records.py, its vendored copy, its tests, its fabric card and the task file); vendor in sync

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

python3 -m pytest -q tests/unit/t4802_dispatch_records_test.py
python3 tests/conformance/worker-contract/run_local.py --json > /tmp/.t4802-run.json; python3 -c "import json; d=json.load(open('/tmp/.t4802-run.json')); r=d.get('results',d) if isinstance(d,dict) else d; assert not [x for x in r if x.get('status')=='fail'], 'conformance FAIL'"
python3 -m pytest -q tests/unit/test_worker_contract_vectors.py
bin/fw vendor self --check --task T-4802

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

### 2026-10-27 — fence_reject is logged at dispatch level, not in the attempt's history
- **Chose:** every fence_reject is appended to a dispatch-level `fence_log` (plus `notices` where §3.3 asks for one); no attempt field changes.
- **Why:** §3.3 says a rejected write "changes nothing", and CC-05/CC-13/CC-24 assert `record_unchanged` and unchanged histories after a reject. Keeping the log off the attempt honours "outside the lifecycle".
- **Rejected:** a marker entry in the attempt's history: it breaks `admissible_histories`/`record_unchanged`, and every reader that takes state from the last history `to` would need a special case.

### 2026-10-27 — hand-back `commission` is filled in by the adapter
- **Chose:** the store applies outcome rule 1 strictly (commission must equal the dispatch id); the adapter writes `commission: <dispatch_id>` into vector hand-backs, which omit it.
- **Why:** §2 makes `commission` part of the hand-back schema and rule 1 refuses a mismatch; a real worker writes the dispatch it was commissioned for. The unit tests pin the mismatch case. Reported, not changed: the vectors could state `commission` in their hand-backs to make this explicit.
- **Rejected:** treating a missing commission as valid: a hand-back for another dispatch would pass rule 1.

### 2026-10-27 — local `lost` = probe absence + G, evidence read first; no equivalent routes
- **Chose:** a probe `absent` on a seen-alive attempt starts G; after G the sweep writer reads the worker-dir evidence and takes T3/T3b/T7b when a bound signed completion exists, else T4/T7c (§3.2, §6.3). `confirm_end` = probe confirmed and G elapsed; on a `done` attempt it is forbidden_transition before any evidence is read. `hub_restart` re-instantiates the Store over the same files. G = 120 s, so the plain CC-08 path holds and `equivalent_routes` is empty: every transition-subject case ran its real path.
- **Rejected:** G = 0 (absence is lost at once): allowed by §2 for a backend that reads evidence first, but it needs the CC-08 equivalent route and gives evidence written just after exit no time to land.

### 2026-10-27 — capabilities declared honestly
- **Chose:** {supervisor_gen, caller_chosen_ids}. Not offered: answer_channel (questions can be appended, fenced, because CC-06 fences that write; answers/wait/ack are not built), registry_epoch, lease, real_worker. Dispatch closure (§4.7) not built: dispatches stay open, as on the hub. Signed completion = HMAC-SHA256 with an injected key (production key wiring is option B's).
- **Why:** a capability declared but not built would turn an n/a into a false pass.

### 2026-10-27 — the runner's own no-backend tests
- **Chose:** two tests in tests/unit/test_worker_contract_vectors.py asserted lib/dispatch_records.py does not exist ("local backend now exists: update this test"). They now point the runner at an absent path through a fixture, so the no-backend path stays tested, and a third test pins that the real local backend reports no fail and no not-implemented. Runner, vectors and spec unchanged.
- **Rejected:** deleting them: the no-backend behaviour is still the runner's contract for other checkouts.

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

### 2026-10-27T09:50:02Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-4802-libdispatchrecordspy-local-backend-for-t.md
- **Context:** Initial task creation

### 2026-10-27T09:50:24Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-10-27 — conformance results (worker w4802)
`python3 tests/conformance/worker-contract/run_local.py` → backend lib/dispatch_records.py, summary **n/a=3, pass=22**, 0 fail, 0 not-implemented (5 repeated runs identical).

| case | status | note |
|---|---|---|
| CC-01..CC-09 | pass | |
| CC-10 | pass | `answer-path-resumes` variant n/a (answer_channel) |
| CC-11 | n/a | answer_channel, real_worker not offered |
| CC-12 | n/a | answer_channel not offered |
| CC-13 | pass | `eight-writers-lock`, `lock-timeout-fails-closed` pass; lease variants n/a |
| CC-14 | pass | `supervisor-gen` pass; `lease` n/a |
| CC-15, CC-16 | pass | plain paths (T1 after resolve; refusal via T3), no equivalent route |
| CC-17 | n/a | registry_epoch not offered |
| CC-18 | pass | caller-chosen ids offered |
| CC-19..CC-22 | pass | |
| CC-23 | pass | `worker-field-accepted` variant n/a (answer_channel) |
| CC-24, CC-25 | pass | |

Mutant check: a backend wrapping this module whose derive_outcome reports `paused` as `succeeded` → `fail=2 (CC-16, CC-19), n/a=3, pass=20`, exit 1.
Unit tests: tests/unit/t4802_dispatch_records_test.py 10 passed; together with tests/unit/test_worker_contract_vectors.py 51 passed, 0 skipped.
Scope: commit 7c1f441cc touches lib/dispatch_records.py, its vendored copy, tests/unit/t4802_dispatch_records_test.py, tests/unit/test_worker_contract_vectors.py (the runner's no-backend tests, see Decisions), the fabric card and this task file; nothing under agents/termlink/, run.sh, lib/spawn-env.sh or dispatches.jsonl. All four ## Verification lines pass under `set -o pipefail`; `bin/fw test invariants` green.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-159496e3
- **Timestamp:** 2026-10-27T10:06:30Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 3

**Per-AC findings:**

- **AC#1 (Agent)** — lib/dispatch_records.py implements the §6.2 store: one JSON record per dispatch under a configurable root (default `.context/dispatch-records/`). Every write takes an exclusive flock on `<dispatch_id>
  - **AC-verify-mismatch** (narrow, heuristic) — `path=lib/dispatch_records.py in: lib/dispatch_records.py implements the §6.2 store: one JSON record per dispatch under a configurable root (default `.context/dispatch-records/`). Ever`
- **AC#6 (Agent)** — Scope fence holds: no change to agents/termlink/, run.sh, lib/spawn-env.sh or the dispatches.jsonl ledger (`git diff --stat` of the task's commits touches only lib/dispatch_records.py, its vendored co
  - **AC-verify-mismatch** (narrow, heuristic) — `path=lib/spawn-env.sh in: Scope fence holds: no change to agents/termlink/, run.sh, lib/spawn-env.sh or the dispatches.jsonl ledger (`git diff --stat` of the task's commits tou`
- **AC#2 (Human)** — [REVIEWER] Block message names both bypass mechanisms
  - **reviewer-prose-mismatch** (partial, heuristic) — `matched='reads' in: Verdict: PASS; no findings on `block-message-completeness``

### 2026-10-27T10:06:15Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
