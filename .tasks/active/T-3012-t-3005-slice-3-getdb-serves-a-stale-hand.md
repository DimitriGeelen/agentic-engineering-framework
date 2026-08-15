---
id: T-3012
name: "T-3005 slice 3: _get_db() serves a stale handle — index freshness"
description: >
  T-3005 slice 3: _get_db() serves a stale handle — index freshness

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
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
created: 2026-08-15T08:37:57Z
last_update: '2026-08-15T08:45:14Z'
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
  - ts: '2026-08-15T08:45:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-15T08:45:14Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3012: T-3005 slice 3: _get_db() serves a stale handle — index freshness

## Context

Slice 3 of T-3005. `_db_built_at` records when the sqlite handle was *opened*, not
when the index was *built* — and `_get_db()` re-stamps it every time it reuses the
existing file (`web/embeddings.py:341`). The stamp therefore renews itself forever
and the staleness TTL can never fire while a non-empty DB exists. That is the
mechanism behind T-3004: a five-month-old index reporting itself seconds old.

T-3011 wrote a corpus manifest with a real `finished_at`. This slice makes freshness
*true* by deriving it from that manifest. It deliberately does **not** change rebuild
behaviour — surfacing staleness is slice 4, fixing it is slice 5. Making the number
honest first is what lets those two slices be checkable at all.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `index_freshness()` returns `{built_at, age_seconds, source}` with `source` one of
      `manifest` / `db_mtime` / `unknown`, derived from the T-3011 corpus manifest —
      never from when the sqlite handle was opened.
- [x] `_get_db()` no longer assigns a build-time stamp when it merely reuses an existing
      DB file; the handle-cache TTL is named and documented as a *connection* TTL, not an
      index-freshness clock.
- [x] The status/health dict reports `index_built_at`, `index_age_seconds` and
      `freshness_source` distinctly from the handle-open time, so a stale index cannot
      report itself fresh.
- [x] RED observed first: a test builds a synthetic index whose manifest `finished_at` is
      200 days old and asserts the reported age is ≈200 days. Against the pre-fix code it
      reports ≈0s.
- [x] RED observed first: a test calls `_get_db()` repeatedly across the TTL boundary and
      asserts the reported index build time does not advance.
- [x] `source == "unknown"` when there is neither manifest nor readable DB — absence is a
      reported state, not a zero that looks like freshness (tri-state, same rule as
      `corpus_health()` in T-3011).
- [x] Existing vector-substrate suites (`test_canary_manifest.py`, `test_chunk_cap.py`)
      stay green.

### Human

- [ ] [REVIEW] The `/health` payload tells you the index is stale without you having to know how to read it

  This one is genuinely yours: `/health` is your monitoring surface, and the question
  is whether the number lands. The agent can prove the value is *correct* (157.6 days,
  and the tests pin it) but not whether it is *legible* to the person checking on the
  system at 2am. Note the endpoint still reports `status: "stale"` alongside a
  157-day age — deciding whether that pairing reads as "mildly out of date" when it
  means "five months dead" is exactly the judgment call being handed over.

  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && bin/fw watchtower restart && sleep 5 && curl -s "$(bin/fw watchtower url)/health" | python3 -m json.tool`
  2. Read the `embeddings` block.

  **Expected:** it carries `index_age_seconds` (~13,600,000 — about 157 days) and
  `freshness_source: "db_mtime"`, and you can tell at a glance that the index is
  badly out of date.

  **If not:** say which part misleads — the units (raw seconds vs a human string),
  the `status` wording, or the absence of an explicit threshold — and it becomes
  slice 4's input, where the doctor/audit rail decides what counts as too old.

  Note: a restart is needed because the running server predates this change; that
  restart should also clear the `status: "unavailable"` you'd otherwise see (OBS-254).

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

python3 -m pytest tests/unit/test_index_freshness.py -q > /tmp/.t3012v1.out 2>&1 && grep -q passed /tmp/.t3012v1.out
python3 -m pytest tests/unit/test_canary_manifest.py tests/unit/test_chunk_cap.py -q > /tmp/.t3012v2.out 2>&1 && grep -q passed /tmp/.t3012v2.out
python3 -c "import web.embeddings as e; f=e.index_freshness(); assert set(f)=={'built_at','age_seconds','source'}, f; assert f['source'] in ('manifest','db_mtime','unknown'), f"
! grep -qE "^_db_built_at" web/embeddings.py
! grep -q "_db_built_at" web/app.py

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).
#
# ── Pipefail/SIGPIPE: grepping a command's output (L-387, T-2090, T-2743, T-2738) ──
#
# THE DEFAULT — redirect to a file, then grep the file:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
#     curl -sf "$(bin/fw watchtower url)/page" -o /tmp/.out && grep -q "PAT" /tmp/.out
# Correct at any output size, and `&&` keeps the PRODUCING command's exit code in
# the verdict. Reach for this first; the alternative below is the special case.
#
# Why not `cmd | grep -q PAT` (L-387): P-011 runs each line under `set -eo
# pipefail`. When grep matches it exits and closes stdin while cmd is still
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
# REHEARSING A LINE BY HAND DOES NOT REHEARSE THE GATE (T-2743). Your interactive
# shell has no `set -eo pipefail`. A line has returned 0 by hand and 141 under
# P-011, from the same directory, the same second. To rehearse for real:
#     bash -c 'set -eo pipefail; <your verification line>'
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

## RCA

**Symptom.** A vector index untouched for five months reported itself seconds old.
`index_stats()["built_at"]` returned a timestamp within milliseconds of `now` on every
call, and `STALE_SECONDS` never fired. Measured on the real index during this task:
157.6 days old, previously reported as age 0.

**Root cause.** `_db_built_at` was assigned `time.time()` inside `_get_db()`'s *reuse*
branch (`web/embeddings.py:355`, pre-fix) — the branch taken precisely when nothing is
built. The variable recorded when the sqlite handle was opened while its name, and every
reader, claimed it recorded when the index was built. Because the stamp was rewritten on
each reopen, the TTL comparison `time.time() - _db_built_at < STALE_SECONDS` measured the
age of the *connection*, which is reset by the very code path the TTL was supposed to
trigger. The clock reset itself every time it was consulted.

**Why structurally allowed.** Three things had to line up:

1. *The name asserted the semantics.* `_db_built_at` reads as build time, so no reviewer
   had cause to check. The one place the two meanings diverge — the reuse branch — is the
   common path, not the exceptional one.
2. *Nothing else knew when the index was built.* Until T-3011 wrote a corpus manifest,
   there was no independent record to disagree with the stamp. A wrong answer with no
   second source is indistinguishable from a right one.
3. *The failure direction was toward "healthy".* A clock that resets always reports
   *fresher*, never staler. Under-reporting age produces silence; over-reporting would
   have produced a false alarm someone would have chased. Only the noisy direction gets
   investigated, so this could sit for five months (same asymmetry as the port-3000 class
   in CLAUDE.md: a green line that asserts nothing is never the thing that prompts a look).

**Prevention** (distinct from the fix):

- `test_reopening_the_handle_does_not_advance_the_reported_build_time` and
  `test_the_ttl_governs_the_connection_not_the_index` fail if the restamp returns —
  they assert the *invariant* (a rebuild-free reopen changes nothing) rather than the
  implementation.
- `test_the_handle_clock_is_not_named_a_build_clock` is a rename tripwire: the misnomer
  was the bug in one word, so its return is an assertion failure rather than a silent
  regression. Mirrored at source level by two grep lines in `## Verification`.
- `source: "unknown"` makes absence a reported state. The prior design had no way to say
  "I don't know", and defaulted to a number — which is how "no answer" became "fresh".
- Slice 4 consumes `index_freshness()` in the doctor/audit rail, so the number is watched
  rather than merely available. **This slice makes the number true; it does not yet make
  anything act on it.** The index is still 157 days old at close.

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

**Recommendation:** GO

**Rationale:** The defect was reproduced before the fix, not inferred: a 200-day-old
database reported `built_at = now`, age `0.0s`, and the stamp advanced on every reopen.
After the fix the same probe reports the true age, and the real production index — asked
this question for the first time — answers 157.6 days. Eleven tests were observed RED
first and are green now, including two that fail for the original reason rather than for
a renamed symbol. The remaining Human AC is a legibility judgment on the `/health`
payload, which is yours to make and does not gate correctness.

The honest limit: this slice makes the staleness *visible*, not *fixed*. Nothing yet
reads the number and complains, and no reindex has run. That is deliberate — slice 4
watches it, slice 5 rebuilds it — but it means the index is still 157 days stale at close.
If that ordering is wrong, this is the moment to say so.

**Evidence:**
- Pre-fix probe: 200-day-old DB → `built_at` = now, age `0.0s`, advanced on reopen (`True`).
- Post-fix on the real index: `age_seconds = 13,614,849` (157.6 d), `source = db_mtime`.
- `tests/unit/test_index_freshness.py` — 11 tests, 10 observed RED pre-fix, all green now.
- `test_canary_manifest.py` + `test_chunk_cap.py` (T-3010/T-3011) unaffected: 39 green total.
- `/health` exercised via Flask test client: `status: stale`, `index_age_seconds`,
  `freshness_source` present, HTTP 200.
- Two findings filed rather than folded in: OBS-253 (pre-push audit >180s blocks every
  push), OBS-254 (`/health` swallows the embeddings exception class).

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

### 2026-08-15T08:37:57Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3012-t-3005-slice-3-getdb-serves-a-stale-hand.md
- **Context:** Initial task creation
