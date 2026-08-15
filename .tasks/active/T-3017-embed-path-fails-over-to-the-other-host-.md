---
id: T-3017
name: "embed path fails over to the other host instead of going dark (T-3008 open
  item b)"
description: >
  embed path fails over to the other host instead of going dark (T-3008 open item
  b)

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: [tests/unit/test_embed_health.py, web/embeddings.py, web/embed_health.py]
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
created: 2026-08-15T12:26:54Z
last_update: 2026-08-15T12:41:35Z
date_finished: 2026-08-15T12:41:35Z
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
  - ts: '2026-08-15T12:30:08Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-15T12:30:15Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 3
      D4: 2
      F-RECALL: 3
      F-AUTONOMY: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=3 (body:component-discoverability); 
      D4=2 (body:env-class-handled); F-RECALL=3 (body:fw-recall-or-memory-link);
      F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=1 
      (body/components:context-fabric-incidental); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3017: embed path fails over to the other host instead of going dark (T-3008 open item b)

## Context

T-3008's second open item:

> (b) automatic failover — the typed classifier makes "on `contention`, retry the
> fallback host" a small change and would make this choice unnecessary.

It stopped being hypothetical on 2026-08-15. The CPU sidecar on `127.0.0.1:11435`
died mid-run and nothing restarted it; because `EMBED_HOST` is pinned to it, every
embedding path in the framework — `fw ask`, `fw recall`, search, reindex — went
dark at once, while a second host holding the same model sat idle and healthy the
whole time (OBS-259). One process exiting took out a subsystem that had a working
alternative one config line away.

T-3016 gave the framework a second configured embed host for throughput reasons.
That incidentally means a fallback now *exists* to fail over to. This task uses
it: on a host-level failure the embed path tries the other host before giving up,
and says loudly when it does — a silent failover would trade an outage for a
mystery, which is the same false-green this arc exists to remove.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `_embed()` retries on the alternate host when the primary fails with a
      host-level class (`ollama-down`, `model-absent`, `contention`), and does
      **not** fail over on `error` (a malformed request fails everywhere)
- [x] Failover emits a WARNING naming both hosts and the triggering class, and
      increments observable state — a failover that leaves no trace is an outage
      converted into a mystery
- [x] When both hosts fail, the raised `EmbedUnavailable` reports the *primary's*
      class, not the fallback's — the operator's remedy is on the primary
- [x] No failover when both settings resolve to the same host (the single-host
      install must not double its retry budget)
- [x] Discriminating fixtures (PL-206): each guarantee shown red with the
      failover disabled and green with it restored — mutation recorded in
      Decisions
- [x] `tests/unit/test_incremental_reindex.py` and `tests/unit/test_embed_health.py`
      green, plus new failover tests

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

- [ ] [REVIEW] Search results still look right now that index and query vectors come from different hosts

  **Steps:**
  1. Open `http://192.168.10.107:3000/search` (or run `bin/fw recall "framework governance task lifecycle"`)
  2. Try 2-3 queries you know the answer to — a task name, a concept, a file you remember
  3. Check the top few results are the ones you would have picked

  **Expected:** Results are relevant and ordered sensibly. This is a judgement call, not a
  threshold: the change routes *document* embedding to the GPU host while *queries* are
  embedded on the sidecar, so the two sides of every comparison are now produced by
  different backends. Same model and same 768 dimensions, so they are interchangeable in
  principle — but float precision differs between CPU and GPU, and the only honest test of
  whether that matters for ranking is a human looking at rankings. I could not verify this
  mechanically: the sidecar was down for the whole session, so no CPU-vs-GPU vector
  comparison was possible.

  **If not:** If results look scrambled rather than merely different, say so and I will
  measure cosine similarity between the two hosts' embeddings of identical text once the
  sidecar is back. The fix, if needed, is one line — point `embed_host` at the same host as
  `embed_bulk_host` so both sides are produced identically.

  **Note:** worth doing *after* the index rebuild finishes (~1.6 h from 14:20). Before then
  the index is partial and poor results mean incomplete coverage, not bad vectors.

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

python3 -m pytest tests/unit/test_embed_health.py tests/unit/test_incremental_reindex.py -q > /tmp/.t3017 2>&1 && grep -q "47 passed" /tmp/.t3017
grep -q "^FAILOVER = frozenset" web/embed_health.py
python3 -c "import sys; sys.path.insert(0,'.'); from web.embed_health import FAILOVER, ERROR, DEGRADED; assert ERROR not in FAILOVER and DEGRADED not in FAILOVER, 'error/degraded must not fail over'"
python3 -c "import sys; sys.path.insert(0,'.'); from web.embeddings import embed_failover_state; assert 'count' in embed_failover_state()"

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

**Recommendation:** GO

**Rationale:** Six Agent ACs met, four mutations each shown red then green, and —
the part I would weigh most — it was verified against the real outage rather than
a fixture. The sidecar was still down while this was written, so the failing case
was available for free: `search()` raised before the change and returned 33
results after it, with one WARNING and the failover counter at 1. The Human AC is
the same ranking judgement as T-3016 and is not blocking.

**Evidence:**
- Live, against the actually-dead sidecar: one WARNING naming both hosts, and
  `embed_failover_state()` -> `{count: 1, last: {from: 127.0.0.1:11435,
  to: 192.168.10.107:11434, status: ollama-down}}`. 33 results returned.
- `pytest tests/unit/test_embed_health.py tests/unit/test_incremental_reindex.py`
  -> 47 passed.
- Mutations: failover disabled -> 3 red; `FAILOVER` widened to include
  `error`/`degraded` -> unclassifiable-does-not-fail-over red; reporting the
  fallback's class -> primary-is-reported red; dropping the `alt != target`
  guard -> single-host-does-not-double-retries red (plus 2 retry-bound tests).
  All green on restore.
- T-3008 sketched this as contention-only. The class that actually took the
  subsystem down was `ollama-down`, which that set would have missed — worth
  noting because it is the second time this week a control was scoped to the
  failure someone expected rather than the one that happened.
- Does *not* fix OBS-259's other half: the sidecar still has no supervisor and no
  recorded launch parameters. This lowers the severity of its death from
  "every embedding path down" to "logged degradation"; it does not restart it.

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

### 2026-08-15 — which failure classes earn a second host

- **Chose:** fail over on `ollama-down`, `model-absent` and `contention`; not on
  `error` or `degraded`.
- **Why:** the first three are properties of the *endpoint* — unreachable, does
  not hold the model, slots taken — and a second endpoint may have none of them.
  `error` is the classifier saying it does not recognise the failure, which most
  often means the request itself; replaying it elsewhere fails twice and doubles
  the wait. `degraded` means the host is slow but answering, and racing a second
  host would add load to fix a condition that clears itself.
- **Rejected:** failing over on everything (turns every malformed request into
  two, and makes the `error` class meaningless); failing over on nothing but
  `contention`, as T-3008 originally sketched — the class that actually took the
  subsystem down on 2026-08-15 was `ollama-down`, which that set would have missed.

### 2026-08-15 — the failover must be loud, and must not shift the blame

- **Chose:** a WARNING naming both hosts and the triggering class, a counter in
  `embed_failover_state()`, and — when both hosts fail — an `EmbedUnavailable`
  carrying the *primary's* class rather than the fallback's.
- **Why:** a silent failover is worse than the outage it hides. The subsystem
  keeps working, nobody learns a host died, and the survivor quietly becomes the
  next single point of failure — the same shape as every other defect in this
  arc, where the instrument was healthy-looking and the state was not. The
  blame direction matters for the same reason: the operator's remedy is on the
  primary, and reporting the stopgap's `model-absent` would send them to fix the
  host that was only ever standing in.
- **Rejected:** logging at INFO (invisible in practice); reporting whichever
  host failed last (points at the wrong machine).

### 2026-08-15 — verified against the real outage, not a fixture

- **Chose:** demonstrate on the live dead sidecar before closing.
- **Why:** the failing tests in this repo have twice been green for reasons
  unrelated to their guarantee (T-3014 AC4, T-3016 routing). The sidecar was
  still down while this was written, which made the real thing available:
  `search("framework governance task lifecycle")` returned 33 results with one
  WARNING and `count: 1`, `from: 127.0.0.1:11435`, `to: 192.168.10.107:11434`,
  `status: ollama-down`. Before this change the same call raised.
- **Rejected:** closing on unit tests alone, given that record.

### 2026-08-15 — mutation results

Each guarantee shown red with the mechanism broken, green with it restored:

| mutation | red |
|----------|-----|
| `_fallback_host` returns None (failover off) | dead-primary, recorded-not-silent, primary-is-reported |
| `FAILOVER` widened to include `error`/`degraded` | unclassifiable-does-not-fail-over |
| report `alt_last` instead of `last` | primary-is-the-one-reported |
| drop the `alt != target` guard | single-host-does-not-double-retries (+2 retry-bound tests) |

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

### 2026-08-15T12:26:54Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3017-embed-path-fails-over-to-the-other-host-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-83db05a1
- **Timestamp:** 2026-08-15T12:41:57Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-15T12:41:35Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
