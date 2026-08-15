---
id: T-3010
name: "chunker: enforce the char cap on sections without paragraph breaks"
description: >
  Promoted from observation OBS-251. _chunk_content's 1500-char cap does not hold
  for
  sections that contain no blank-line paragraph breaks — they are emitted whole and
  uncapped, then silently truncated at the embedder's hard 512-token ceiling.

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
created: 2026-08-15T07:19:19Z
last_update: '2026-08-15T07:30:07Z'
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
  - ts: '2026-08-15T07:20:16Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=1 
      (body/components:context-fabric-incidental); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-08-15T07:30:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3010: _chunk_content's 1500-char cap does not hold: sections without paragraph breaks are emitted whole and uncapped. Corpus p99 = 3299 chars, largest chunk = 170,873 chars (114x target), which loses ~99.7% of its content at the embedder's hard 512-token ceiling. 4,255 chunks provably truncate today (exact lower bound; ~7,691 = 2.7% estimated). Distinct defect from the model ceiling — fixing the chunker removes most of the loss with no model change. Repro: python3 tools/measure_chunk_tokens.py

## Context

From OBS-251, measured in T-3009 (`tools/measure_chunk_tokens.py`, results in
`docs/reports/T-3007-embedding-model-and-adaptation.md`).

`web/embeddings.py:_chunk_content` takes `max_chars=1500`, but the cap is advisory in
two places:

1. **Oversized single paragraph.** The long-section branch splits on `"\n\n"` and appends
   whichever piece it is holding. A paragraph that is itself longer than `max_chars` is
   appended whole — nothing splits it further. Corpus p99 is 3,299 chars and the largest
   chunk is **170,873** (114× target).
2. **A silent-truncation fallback.** `if not raw_chunks: return [content[:max_chars]]`
   discards everything past the cap rather than splitting. Correction to the original
   framing: this branch is only reached for whitespace-only input, because the heading
   regex yields the whole document as one section when there are no headings. So it is a
   latent hazard rather than an active one — heading-less content was being mangled by
   defect 1, not by this. Fixed anyway; noted here so the record is not overclaimed.

The consequence is not just oversized chunks — the embedder truncates at a hard
**512 tokens** (T-3009, proven: cosine 1.000000000 between texts differing only past the
boundary). A 170,873-char chunk is embedded from its first ~1,600 characters; the other
99.7% is not in the index and cannot be retrieved, while the row still *looks* indexed.

**The cap value is also wrong, independently of it not holding.** Measured chars-per-token
runs 2.01–4.20. At the floor, 1,500 chars is ~746 tokens — over the ceiling. Only ≤1,030
chars is *provably* under it. So fixing the enforcement alone still leaves the
1,030–1,500 band truncating (~21% of it, measured). Both halves are one deliverable:
**a chunk this function emits must be embeddable in full.**

Deliberately out of scope: choosing the *next* model (T-3007 step B). This task makes the
cap derive from whatever ceiling is in force, so the switch changes one number.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `_chunk_content` never emits a chunk longer than the cap, for **any** input —
      specifically: a section with no blank-line paragraph breaks, a single paragraph
      longer than the cap, content with no markdown headings at all, and content that is
      one unbroken run with no whitespace to split on.
      → `_split_to_budget()` walks separators coarse-to-fine (`\n\n` → `\n` → `. ` → ` `)
      and ends at a hard character cut, so the bound holds even for input with no
      whitespace at all. All four shapes covered by tests.
- [x] **No content is discarded.** The `content[:max_chars]` fallback is replaced by
      splitting. Pinned by a property test: the concatenation of emitted chunks, with
      overlap removed, contains every character of the input.
      → `_assert_lossless` in `tests/unit/test_chunk_cap.py` — subsequence check over
      whitespace-stripped text, applied to every cap test rather than as one isolated case.
- [x] The cap **derives** from the embedder's measured token ceiling and a conservative
      chars-per-token floor rather than being a bare literal, so T-3007 step B changes the
      ceiling and the cap follows. Both constants carry the T-3009 measurement as their
      provenance.
      → `EMBED_CONTEXT_TOKENS = 512`, `CHARS_PER_TOKEN_FLOOR = 2.0`,
      `MAX_CHUNK_CHARS = int(...)` = **1024**. `test_budget_derives_from_the_measured_ceiling`
      pins the derivation *and* refuses a floor above the measured 2.01 — the floor is what
      makes the cap a proof rather than an average.
- [x] Re-walking the corpus shows **zero** chunks above the cap (`--assert-cap`), and a
      re-run of the token measurement reports **0 provably-over** and a measured
      over-rate of 0 in the ambiguous band.
      → `--assert-cap 1024`: **393,082 chunks, over=0, max 1,022**. Token re-run:
      **provably over = 0, ambiguous band = 0**. The band being empty matters — it means
      every chunk is *provably* under the ceiling, so the verdict is a proof and not an
      estimate. (Before: 4,255 provably over, ~7,691 estimated.)
- [x] Unit tests cover each failure shape above and the no-content-lost property, and at
      least one of them is **observed failing against the pre-fix chunker** — a test that
      has never gone red is a hypothesis.
      → **9 of 10 observed RED** against the pre-fix chunker (the 10th is the constants
      test, which cannot fail before the constants exist). Largest pre-fix offender caught
      by the suite: a 60,000-char chunk against a 1,024 cap.
- [x] The effect on corpus size is measured and stated (chunk count before/after), since
      a lower cap raises chunk count and therefore the cost of the single reindex that
      T-3005 slices 3/5 and T-3007 step C all share.
      → **287,812 → 393,082 chunks (+36.6%)**. That is the price of the proof and it lands
      on the shared reindex; T-3005 slice 5's scheduling and T-3007 step C's cost estimate
      should both use 393k, not 288k. Note this is 18.7× the "~21k" the T-3007 source
      reasoned from.

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
# The cap check is a pure local walk — no embed calls — so it stays honest when
# the embedder is down. The ceiling check is the one that needs the model.
python3 -m pytest tests/unit/test_chunk_cap.py -q > /tmp/.t3010-pt.out 2>&1 && grep -q "10 passed" /tmp/.t3010-pt.out
python3 tools/measure_chunk_tokens.py --assert-cap 1024 > /tmp/.t3010-cap.out 2>&1 && grep -q "over=0" /tmp/.t3010-cap.out
python3 -m pytest tests/unit/test_embed_health.py -q > /tmp/.t3010-eh.out 2>&1 && grep -q "19 passed" /tmp/.t3010-eh.out
python3 tools/measure_chunk_tokens.py --check --expect-ceiling 512 > /tmp/.t3010-ceil.out 2>&1 && grep -q "check: ceiling 512 vs expected 512 -> PASS" /tmp/.t3010-ceil.out

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

**Symptom:** Nothing. That is the whole problem. Chunks up to 170,873 chars were written
to the index, embedded from their first ~1,600 characters, and stored as rows that look
exactly like correctly-indexed rows. No error, no warning, no log line. The content was
simply not findable, and nothing distinguished "we have no document about X" from "we have
a document about X and threw away the half that mentions it."

**Root cause:** `_chunk_content` treated its `max_chars` argument as a *target* while the
embedder treats its context window as a *limit*. Concretely, the long-section branch split
on `"\n\n"` and appended whatever it was accumulating; a paragraph larger than the cap was
never split further, because the code had no separator left to try and no fallback. A
markdown section with single-newline line breaks (a table, a long list, a code block, YAML)
is one "paragraph" by that definition — which is why the worst case was 114× the target
rather than 2×.

**Why structurally allowed** — three independent reasons, and the third is the interesting one:

1. **No test asserted the cap.** The chunker had tests for splitting *behaviour* (does it
   split on headings, does overlap appear) but none for its *bound*. A function whose
   entire contract is "output is at most N" had that contract unpinned.
2. **The two components were correct in isolation and wrong together.** The chunker's cap
   (1500) and the embedder's ceiling (512 tokens ≈ 1030 chars at the observed floor) were
   each defensible numbers, chosen at different times by different tasks (T-263 set the
   chunk size; T-263 also chose the model). Nothing in the code connected them, so nothing
   could notice they disagreed. This is the same shape as T-3004's `_get_db()` defect: a
   local invariant held, a global one did not.
3. **The failure mode is a false green, so nothing ever prompted anyone to look.** A
   truncated chunk still produces a valid 768-dim vector, a valid row, and a plausible
   search hit. `is_index_ready()` counts rows and would count these. This is the same
   class the framework already documents for port-3000 verification lines — *"a red line
   gets noticed at the next close, while a green line that asserts nothing is
   indistinguishable from one that asserts everything."* It was true here for the whole
   life of the index.

**Prevention** — distinct from the fix, and deliberately at two levels:

- **The bound is now derived, not written down.** `MAX_CHUNK_CHARS` is computed from
  `EMBED_CONTEXT_TOKENS × CHARS_PER_TOKEN_FLOOR`. The two numbers that disagreed are now
  one expression, so they cannot drift apart again. When T-3007 step B switches models,
  the cap moves with the ceiling instead of being a literal someone must remember.
- **`tools/measure_chunk_tokens.py --assert-cap` is a corpus-wide standing check** that
  runs in seconds with no embed calls, so it works when the embedder is down and is cheap
  enough to sit in a Verification block. `--check` separately pins the ceiling itself, so
  a model swap that changes it turns a line red rather than quietly invalidating the cap.
- **The tests were observed failing** (9/10 RED pre-fix) rather than written green. Per
  T-3005's constraint 3: a positive control nobody has watched fail is a hypothesis.

**Not prevented, and worth naming:** this class was found by *measuring on the way to
something else* (T-3009's ceiling check), not by any rail. There is still no automated
signal that would have raised it, and the general form — "component A's assumption about
component B has silently diverged" — is what T-3005 slices 2 and 4 exist to catch. This
fix removes one instance; it does not close the class.

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

### 2026-08-15T07:19:19Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3010-chunkcontents-1500-char-cap-does-not-hol.md
- **Context:** Initial task creation

### 2026-08-15T07:20:15Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
