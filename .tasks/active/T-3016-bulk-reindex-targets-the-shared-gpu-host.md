---
id: T-3016
name: "bulk reindex targets the shared GPU host (T-3008 open item a)"
description: >
  bulk reindex targets the shared GPU host (T-3008 open item a)

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: [tests/unit/test_embed_health.py, 
      tests/unit/test_incremental_reindex.py, web/embeddings.py]
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
created: 2026-08-15T12:15:38Z
last_update: '2026-08-16T22:24:15Z'
date_finished: 2026-08-15T12:40:49Z
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
  - ts: '2026-08-16T22:24:15Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 3
      F-AUTONOMY: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=3 (body:fw-recall-or-memory-link); F-AUTONOMY=0 (no-signal); F3=0
      (no-signal); F1=1 (body/components:context-fabric-incidental); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3016: bulk reindex targets the shared GPU host (T-3008 open item a)

## Context

T-3008 kept `embed_host` pointed at the CPU sidecar (`127.0.0.1:11435`) for
*queries* — warm latency is indistinguishable (208 ms shared vs 210 ms sidecar)
and the sidecar is immune to fleet contention. In the same decision it recorded
an open item it did not have budget for:

> (a) bulk reindex — slices 3/5 re-embed ~9k docs, where the GPU *would* matter,
> so the reindexer specifically should target the shared host

T-3014 then measured the bootstrap against the sidecar: 1.9 chunks/s, 394,230
chunks, ~29 h solo. That number is a property of the CPU path, not of the corpus.
This task ships open item (a): the reindexer embeds against the shared host while
queries keep the isolated sidecar. One knob, two paths, each on the host T-3008
already reasoned it belonged on.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `Config.EMBED_BULK_HOST` resolves `FW_EMBED_BULK_HOST` env → saved
      `embed_bulk_host` → `OLLAMA_HOST`, independently of `EMBED_HOST`
- [x] `reindex()` embeds via the bulk host; `search()` and the health probe still
      embed via `EMBED_HOST` — pinned by a test that sets the two to *different*
      hosts and asserts which client each path actually called
- [x] The reindex result dict names the host it embedded against, so a silent
      host switch cannot hide in a green run
- [x] Discriminating fixture (PL-206): the host-separation test goes red when
      `reindex()` is reverted to `EMBED_HOST`, green when restored — mutation
      shown in Decisions, not asserted
- [x] Bulk-host throughput measured with the same 64×1000-char method that
      produced the 1.9 chunks/s sidecar baseline, recorded in Decisions
- [x] `tests/unit/test_incremental_reindex.py` and `tests/unit/test_embed_health.py`
      both green

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

python3 -m pytest tests/unit/test_incremental_reindex.py tests/unit/test_embed_health.py -q > /tmp/.t3016-tests 2>&1
# Pin this task's own guarantee by name, not the whole-suite count: a total
# is invalidated by any sibling task adding a test (T-3017 did exactly that,
# 42 -> 47), and pytest already fails non-zero on a real failure.
python3 -m pytest tests/unit/test_incremental_reindex.py -q -k host > /tmp/.t3016-host 2>&1 && grep -q "4 passed" /tmp/.t3016-host
python3 -c "import sys; sys.path.insert(0,'.'); from web.config import Config; assert Config.EMBED_BULK_HOST, 'EMBED_BULK_HOST unset'"
grep -q "EMBED_BULK_HOST" web/config.py
grep -q "host=bulk_host" web/embeddings.py

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

**Rationale:** All six Agent ACs are met with measured, reproduced evidence, and
the change is already proving itself in production — the reindex running right
now picked it up and is embedding at 77.3 chunks/s against the real corpus,
against a 1.9 chunks/s baseline on the path it replaced. The single Human AC is a
judgement call I genuinely cannot make mechanically: index vectors are now
produced on a different backend from query vectors, and whether that float-precision
difference matters for *ranking* is a question about what results look right to
you. It is not blocking anything — worth doing after the rebuild finishes.

**Evidence:**
- Synthetic 64x1000-char batch, 3 trials: 69.1 / 69.9 / 69.8 chunks/s on the GPU
  host vs 1.9 chunks/s on the CPU sidecar. Same model, same 768 dimensions.
- Live corpus measurement on the running reindex: 45,526 -> 49,008 chunks in 45s
  = 77.3 chunks/s. 394,230 chunks projects to ~1.6 h against ~29 h.
- `pytest tests/unit/test_incremental_reindex.py -k host` -> 4 passed.
- Mutation, per path: reverting the bootstrap line reddens
  `test_bootstrap_embeds_against_the_bulk_host`; reverting the incremental line
  reddens `test_incremental_embeds_against_the_bulk_host`. Both green on restore.
- The first version of the routing test passed against a mutated
  `reindex_incremental` — it asserted on the bootstrap branch while the mutation
  landed in the incremental one. That is recorded in Decisions rather than quietly
  fixed, because it is the same false-green shape this arc exists to remove.
- `EMBED_BULK_HOST` defaults to `OLLAMA_HOST`; single-host installs have
  `EMBED_HOST == OLLAMA_HOST` already and see no behaviour change.

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

### 2026-08-15 — one knob per workload, not one host per install

- **Chose:** a second setting, `EMBED_BULK_HOST`, defaulting to `OLLAMA_HOST`,
  read only by the two reindex paths. `EMBED_HOST` keeps serving queries.
- **Why:** the two workloads have opposite cost functions. A query is one vector
  where warm latency decides and the hosts are indistinguishable (208 vs 210 ms,
  T-3008); a reindex is 394,230 vectors where throughput decides and the hosts
  are 37× apart. Measured this session with the same 64×1000-char method that
  produced the sidecar baseline:

  | host | chunks/s | 394,230 chunks |
  |------|----------|----------------|
  | CPU sidecar `127.0.0.1:11435` | 1.9 | ~29 h |
  | GPU shared `192.168.10.107:11434` | 69.9 (69.1 / 69.9 / 69.8 over 3 trials) | **1.6 h** |

  Same model, same 768 dimensions, so the vectors are interchangeable. Defaulting
  to `OLLAMA_HOST` means installs without a sidecar already have
  `EMBED_HOST == OLLAMA_HOST` and see no behaviour change at all.
- **Rejected:** moving `EMBED_HOST` itself to the GPU — that reintroduces exactly
  the contention fragility T-3006 removed, for no measured query benefit.
  Rejected: leaving both on the sidecar — a 29-hour job in front of an hourly
  cron is the T-3014 convergence problem, and this removes it rather than
  tolerating it.

### 2026-08-15 — the routing test had to be shown failing, twice

- **Chose:** a discriminating fixture per reindex path, mutation-verified
  separately rather than once for "the routing".
- **Why:** the first version of this test passed against a mutated
  `reindex_incremental`. It was asserting on the bootstrap path — a fresh
  fixture has no index, so `reindex_incremental()` delegates to `build_index()`
  and never enters the incremental branch. One test, two branches, and the
  mutation landed in the branch the test did not reach. Splitting it produced
  the honest result: mutating the bootstrap line reddens
  `test_bootstrap_embeds_against_the_bulk_host`, mutating the incremental line
  reddens `test_incremental_embeds_against_the_bulk_host`, and each is green on
  restore.
- **Rejected:** trusting the single green test. It was green for a reason that
  had nothing to do with the guarantee — the same shape as the AC4 flock defect
  in T-3014, found one layer down.

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

### 2026-08-15T12:15:38Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3016-bulk-reindex-targets-the-shared-gpu-host.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ed8f2ca1
- **Timestamp:** 2026-08-15T12:40:57Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-15T12:40:49Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
