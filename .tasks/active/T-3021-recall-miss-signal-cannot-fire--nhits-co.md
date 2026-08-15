---
id: T-3021
name: "recall miss signal cannot fire — n_hits counts returned rows, not relevant
  ones"
description: >
  recall miss signal cannot fire — n_hits counts returned rows, not relevant ones

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
created: 2026-08-15T19:26:26Z
last_update: '2026-08-15T19:30:14Z'
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
  - ts: '2026-08-15T19:30:08Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-15T19:30:14Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 3
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=3 (body:component-discoverability); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-3021: recall miss signal cannot fire — n_hits counts returned rows, not relevant ones

## Context

T-3019 shipped the fourth T-3005 signal — **Used** — to close the G-064 zero-consumer
shape. It records one telemetry row per outermost recall with `outcome ∈ {hit, miss,
unavailable}`, and defines `miss` as `n_hits == 0`.

Measured against the now-populated index (396,797 chunks), that definition can
essentially never be true. `_semantic_search` issues a KNN query with `k = limit * 3`
and **no distance threshold** (`web/embeddings.py:1134-1140`), so it returns the k
nearest rows for *any* query vector. Pure gibberish returns a full result set.

Live evidence — these were recorded by the telemetry as **hits**:

| query | n_hits | top_score |
|-------|--------|-----------|
| `zqxjv wombat photosynthesis quarterly` | 9 | 0 |
| `purple bicycle tax return mitochondria` | 6 | 0 |
| `flrbgnt xxqq zzzv` | 5 | 0 |
| `postgres vacuum autovacuum tuning` | 11 | 0 |

`usage_summary` over 35 rows: `{"hits": 34, "misses": 0, "miss_rate": 0.0}`.

The separation the code already computes is `top_score`, not `n_hits`:
`similarity = max(0, 1.0 - distance)` (`web/embeddings.py:1147`) clamps everything at
or beyond L2 distance 1.0 to exactly `0`. Every known-good query scored `> 0`
(min 0.016, median 0.106, max 0.436); every nonsense and every plausible-but-absent
query scored exactly `0`. `top_score` is **already recorded in every telemetry row** —
the fix is to read the field that carries the signal instead of the one that does not.

Blast radius beyond the metric: query text is retained *only on misses*
(`recall_telemetry.record.__exit__`). Since misses never fire, no query text is ever
retained — so T-3005 slice 6b (miss-driven reindex priority) has no data source at
all. This task unblocks it.

## Acceptance Criteria

### Agent
- [x] `recall_telemetry` classifies outcome from `top_score`, not `n_hits`: a recall whose best result scored `0` records `outcome: miss` even when rows were returned
- [x] A recall with `top_score > 0` still records `outcome: hit`; `unavailable` (exception path) is unchanged
- [x] Query text is retained on the newly-firing misses, so slice 6b has a corpus to rank
- [x] `usage_summary` reports a non-zero `miss_rate` when miss-class queries are present in the window
- [x] Regression test pins the defect: a gibberish query against a populated index records `miss` (and fails against the old `n_hits == 0` rule)
- [x] Mutation check: reverting the classifier to `n_hits == 0` turns that test red — proving the new rule is the single load-bearing mechanism, not belt-and-braces
- [x] `fw doctor` recall-usage verdict still emits all three branches (OK / WARN-empty / WARN-unavailable) and is not broken by the outcome change
- [x] `## RCA` filled: symptom, root cause, why structurally allowed, prevention

**Evidence — end-to-end against the live 396,797-chunk index (not fixtures):**

| outcome | n_hits | top | query / hash |
|---------|--------|-----|--------------|
| hit  |  5 | 0.087 | `#bf95b77da14f51de` |
| hit  |  3 | 0.117 | `#b1248ad4a91a5e45` |
| miss |  9 | 0 | `zqxjv wombat photosynthesis quarterly` |
| miss |  5 | 0 | `flrbgnt xxqq zzzv` |
| miss | 11 | 0 | `postgres vacuum autovacuum tuning` |

`miss_rate: 0.6` — the field was structurally pinned to `0.0` before this change. Misses
carry their query text; hits carry only the hash, as designed.

Mutation discrimination: reverting `_found_something` to `return n_hits > 0` turns
exactly 3 tests red (the three asserting new behaviour) and leaves 29 green, including
the compatibility guards that hold under both rules. Suite 26 → 32 legs, 0 failed.

Doctor branches, all three observed: `OK|recall usage: 5 queries in 7d, 3 miss`,
`WARN|... 0 queries in 7d — semantic recall may have no consumers`,
`WARN|... 1 could not run`.

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

out=$(python3 -m pytest tests/unit/test_recall_telemetry.py -q 2>&1); echo "$out" | grep -q passed && ! echo "$out" | grep -q failed
grep -qF "return top_score > 0" web/recall_telemetry.py
bash -c 'source lib/recall-usage.sh && recall_usage_verdict 7' > /tmp/.t3021-doctor.out 2>&1 && grep -qE "^(OK|WARN)\|recall usage" /tmp/.t3021-doctor.out

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

**Symptom:** `fw doctor`'s recall-usage check and `usage_summary` report a `miss_rate`
of `0.0` over every window, including windows containing deliberate gibberish queries.
The "Used" signal's volume dimension works; its quality dimension is inert.

**Root cause:** `outcome` was derived from `n_hits` (count of rows returned) rather
than `top_score` (best similarity achieved). `_semantic_search` is an unthresholded
KNN — `WHERE v.embedding MATCH ? AND k = ?` with `k = limit * 3` — so it returns rows
for any query vector whatsoever. `n_hits == 0` is therefore not a weak proxy for "found
nothing"; it is a condition that only holds when the index is *empty*. The three other
T-3005 signals (Fresh, Online, Correct) already cover an empty index, so the miss
dimension could only ever fire in the one situation that was already covered, and never
in the situation it was built for.

**Why structurally allowed:** T-3019 was authored and verified *before* the bulk
reindex completed. Against a sparse index, `n_hits == 0` fires readily, so the signal
demonstrably worked when it was tested — the test was a lenient reader of a condition
that only holds transiently. The task explicitly deferred a score threshold, recorded
as "miss is defined as zero hits only, pending measurement". That was framed as
conservatism; the measurement now shows it was not a weaker definition of the right
thing but a definition of a different thing. **Deferring a threshold silently changed
what was being measured, rather than measuring it less precisely** — and nothing in the
close gate could distinguish those, because a signal that never fires and a signal with
nothing to report are the same green.

This is the G-064 zero-consumer shape recursing one level inward: the control built to
detect "nothing exercises this subsystem" was itself incapable of firing.

**Prevention:** A unit test asserting the *shape* rather than the value — that a
recall against a populated index with a known-gibberish query classifies as `miss`.
This is true or false independent of corpus size, has no threshold to tune, and goes
red under mutation of the classifier. Distinct from the fix: the fix changes one
predicate; the test pins that no future refactor may reintroduce a relevance
classifier that reads a row count. Credit to 832-Workflow-designer (agent-chat-arc
offset 11924) for the framing: *values are supposed to move, which is exactly why
value-based instruments cannot see this class; shapes are not supposed to move.*

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

### 2026-08-15 — where to put the miss boundary

- **Chose:** `top_score > 0` — the clamp boundary the retriever already computes.
- **Why:** it is measured, not invented. `max(0, 1.0 - distance)` makes `0` the point
  where the code itself declares a result unrankable. Every known-good query on the
  live index cleared it; every nonsense and plausible-but-absent query sat exactly on
  it. Nothing to tune, and it stays true as the corpus grows.
- **Rejected:** a tuned relevance threshold (e.g. `> 0.05`). The weakest genuine query
  measured 0.016, so any such number would cut into real hits on evidence I do not
  have. Inventing one is precisely how the `n_hits` rule acquired its false authority
  — it looked like a decision and was never a measurement.
- **Rejected:** removing the `max(0, ...)` clamp so distance survives below the floor.
  Defensible, and probably needed for *ranking* misses by severity in slice 6b, but it
  is a change to the retrieval contract with its own blast radius. One bug, one task.

### 2026-08-15 — miss *rate* still does not WARN, deliberately

`recall_usage_verdict` reports `OK|recall usage: 5 queries in 7d, 3 miss` — a 60% miss
rate reads as OK. That is intentional for now: I have no evidence for what a healthy
miss rate looks like on this corpus, and a threshold guessed today would be the same
mistake this task exists to fix, one level up. Making the count *visible* is this
task's job; deciding what count is *bad* needs the miss corpus that only now starts
accumulating. Forward work for slice 6b.

### 2026-08-15 — this makes T-3019's open operator question load-bearing

T-3019 carries one unticked Human AC asking the operator whether retaining raw query
text on miss rows is acceptable. While misses could not fire, that question was
hypothetical — no query text was ever written. **As of this change it is real:** miss
rows now retain full query text, and misses are common (3 of 5 in the sample above).
No new Human AC filed here — duplicating the question would split the decision across
two tasks. Flagged so the operator knows the T-3019 decision now has consequences it
did not have when it was filed.

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

### 2026-08-15T19:26:26Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3021-recall-miss-signal-cannot-fire--nhits-co.md
- **Context:** Initial task creation
