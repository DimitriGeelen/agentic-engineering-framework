---
id: T-3011
name: "T-3005 slice 2: index canary and corpus_manifest — the keystone control"
description: >
  T-3005 slice 2: index canary and corpus_manifest — the keystone control

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
created: 2026-08-15T07:35:22Z
last_update: 2026-08-15T07:57:04Z
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
  - ts: '2026-08-15T07:45:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-15T07:45:12Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=1 (body/components:context-fabric-incidental); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3011: T-3005 slice 2: index canary and corpus_manifest — the keystone control

## Context

Slice 2 of the T-3005 GO (`docs/reports/T-3005-vector-substrate-controls.md`,
§Sequencing): *"Canary + `corpus_manifest` — the keystone control; makes 3–6 verifiable."*

**Specified, not started.** Written at 225K context so the next session inherits a scoped
task rather than a half-built one.

The problem this closes: T-3004 found four instruments all green during a total recall
outage. `is_index_ready()` counts rows; `built_at` reports when the DB was *opened*, not
when it was *built*. Nothing in the stack exercises embed → store → retrieve, so nothing
could go red. The canary is a positive control that can.

**Two design constraints learned after T-3005 was written** — both change the design, so
read them before implementing:

1. **Rank-based, not score-based.** T-3007 will switch the embedding model (step B), and
   T-3007's own analysis warns that thresholds calibrated against
   `nomic-embed-text-v2-moe`'s score distribution are invalidated by the switch. A canary
   asserting "top hit for its own unique token" survives a model change; one asserting
   "similarity > 0.8" does not. Do not introduce a score threshold here.
2. **The canary must be provably under the chunk cap** (`MAX_CHUNK_CHARS`, T-3010).
   A canary that is itself truncated is green for the wrong reason — worse than none.

**The second canary is the interesting one.** T-3009/T-3010 found a defect where content
past ~1,600 chars was silently discarded while the row still looked indexed. A *tail*
canary — an oversized synthetic document whose unique token sits deliberately far into it
— is retrievable only if chunking and embedding covered the whole document. That makes it
a standing detector for OBS-251 regressing, which no unit test can be (unit tests pin the
chunker; this pins the whole pipeline).

**Scope fence.** This slice builds the control and proves it on a small synthetic index.
It does **not** rebuild the real index (393,082 chunks — that is the shared reindex owned
by slices 3/5) and does **not** add the doctor/audit rail (slice 4 consumes what this
slice emits).

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `build_index()` writes a **content canary**: a synthetic document containing a
      unique token (`FWCANARY-<epoch>`), whose text is provably shorter than
      `MAX_CHUNK_CHARS` so it cannot itself be truncated.
- [x] `build_index()` also writes a **tail canary**: an oversized synthetic document whose
      unique token sits past the byte offset where the pre-T-3010 chunker would have
      truncated. Retrievable only if the whole document was chunked and embedded.
- [x] `verify_canaries()` retrieves both by semantic search and asserts each is the **top
      hit for its own token** — a rank assertion, with **no score threshold anywhere**, so
      it survives the T-3007 model switch without recalibration.
- [x] A `corpus_manifest` is persisted at build time and readable **without** rebuilding:
      file count, chunk count, model name, `EMBEDDING_DIM`, `MAX_CHUNK_CHARS`,
      `EMBED_CONTEXT_TOKENS`, build start/end timestamps, and the git HEAD it was built
      from. This is what slice 4's rail reads and what makes "the index is stale" a
      checkable claim rather than an inference from `built_at`.
- [x] **Both canaries are observed failing.** A test deliberately regresses the pipeline
      (a chunker stub that truncates, and an index missing the canary) and asserts the
      canary goes red. Per T-3005 constraint 3: a positive control nobody has watched fail
      is a hypothesis, and this arc has now shipped three instruments that were green
      because they asserted nothing.
- [x] Canary verification runs against a **small synthetic corpus** in the test, not the
      393k-chunk real one — so the test is seconds, not hours, and does not depend on the
      shared reindex having happened.
- [x] The manifest round-trips (write → read → compare) and tolerates a missing/corrupt
      manifest by reporting absence, not by raising.

### What the ACs did not say, and had to be added

A third document — a **decoy** — is planted and deliberately never verified.

The tail canary was built, unit-tested green, and then **observed passing on a real
index under a deliberately truncating chunker**. Twice. Two separate causes, both
false greens in the control itself:

1. **The canary was never actually truncated.** `TAIL_OFFSET_CHARS` was first set to
   1,600 from the *median* 3.19 chars/token. The canary's own filler is plain English
   at ~4.5 chars/token, so the document came to ~460 tokens — under the 512 ceiling.
   Sized against the *maximum* observed ratio instead (now 6,000 chars).
2. **"Top hit" was satisfied by having no rival.** Even once genuinely truncated, the
   canary still ranked first, because on a 5-document index nothing else was closer to
   the probe. A rank assertion with no competitor asserts nothing. The decoy is
   topically adjacent to the tail probe and wins when the tail chunk is absent.

Measured on a real index after both fixes:

| pipeline | ranking for the tail probe | `corpus_health()` |
|---|---|---|
| healthy | `tail.md` **0.1560**, decoy 0.0210 | `ok` |
| truncating | **decoy 0.0170**, `tail.md` **0.0000** | `fault` |

Recording this because it is the whole point of T-3005 constraint 3. Had I trusted the
fake-`search_fn` unit tests — all green throughout — this slice would have shipped a
control that could not fail, into an arc whose founding finding was four instruments
that could not fail.

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
#
# Canary verification runs against an injected search_fn, so it is seconds and
# needs no index rebuild. The live end-to-end proof is recorded in the AC notes.
python3 -m pytest tests/unit/test_canary_manifest.py -q > /tmp/.t3011-a.out 2>&1 && grep -q "passed" /tmp/.t3011-a.out
python3 -m pytest tests/unit/test_chunk_cap.py tests/unit/test_embed_health.py -q > /tmp/.t3011-b.out 2>&1 && grep -q "passed" /tmp/.t3011-b.out
python3 -c "import ast; ast.parse(open('web/canary.py').read()); ast.parse(open('web/corpus_manifest.py').read())"
python3 -c "import sys; sys.path.insert(0,'.'); from web import embeddings as E; assert callable(E.corpus_health)"

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

### 2026-08-15T07:35:22Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3011-t-3005-slice-2-index-canary-and-corpusma.md
- **Context:** Initial task creation

### 2026-08-15T07:38:04Z — status-update [task-update-agent]
- **Change:** horizon: now → next
- **Change:** status: started-work → captured (auto-sync)

### 2026-08-15T07:57:04Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)
