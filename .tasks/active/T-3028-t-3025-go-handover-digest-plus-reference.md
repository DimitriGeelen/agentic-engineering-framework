---
id: T-3028
name: "T-3025 GO: handover digest-plus-reference for the three dump sections"
description: >
  T-3025 GO: handover digest-plus-reference for the three dump sections

status: work-completed
workflow_type: build
owner: human
horizon:
tags: []
components: [agents/handover/handover.sh, lib/config.sh, 
      tests/unit/handover_digest.bats, web/blueprints/config.py]
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
created: 2026-08-16T07:56:57Z
last_update: 2026-08-29T08:38:08Z
date_finished: 2026-08-16T08:38:36Z
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
  - ts: '2026-08-16T08:00:08Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-16T08:00:16Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 3
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=3 (body:portability-abstraction); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:15Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 3
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=3 (body:portability-abstraction); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=1 (body/components:context-fabric-incidental); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3028: T-3025 GO: handover digest-plus-reference for the three dump sections

## Context

Implements the T-3025 GO: **option (3), digest-plus-reference, scoped to the three
dump sections only.** Decision recorded by the operator via Watchtower (`5148d07f6`).

The measured case (T-3022 §Spike 9-10, T-3025 §Spike 11-12): `.context/handovers` is
68% of the indexed corpus and 79% of the last month's growth. Section accounting of a
265,888-byte handover shows **state dumps are 97.3%** of it — Observation Inbox
137,505 B, Work in Progress 69,568 B, Awaiting Your Action 48,355 B — against ~2 KB of
session narrative. Consecutive handovers are byte-identical across those three
sections. The prototype at `docs/reports/T-3025-digest-spike.py` reduced a real
handover 273,761 → 18,762 B (14.6×) with **all 14 narrative sections byte-identical
by md5**.

The GO's reasoning, which sets the scope: narrative is what a cold reader needs and it
is preserved in full; what gets referenced is enumerated live state — a queue snapshot
that is stale the moment it is written and that every consumer re-derives anyway.
Referencing the part that goes stale and embedding the part that does not is the split,
not a compromise.

**GO condition 2 is already satisfied** by T-3027: `tasks_active:` now means active, so
frontmatter carries correct identity + state for every in-flight task. That is what
makes eliding the WIP dump safe — the T-3025 IW-2 probe's digest arm failed precisely
because the surviving carrier asserted a false status, and it no longer does. Condition 1
(digest must carry per-task Status) is subsumed, but the retained top-N entries carry
Status anyway.

**Reversibility is a requirement, not a nicety.** The whole chain (E′ → F → A) was
ordered to put subtraction before construction. `FW_HANDOVER_DIGEST=0` must restore the
full dumps with no other change.

Not in scope: candidate A (binary quantization), and any change to the 14 narrative
sections.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] All three dump sections digest to `count + regenerating command + top-N entries`: Observation Inbox (`fw note triage`), Work in Progress (`fw task list --status started-work`), Awaiting Your Action (`fw review-queue`)
- [x] The partial-complete footer inside Work in Progress — which re-lists the same set as Awaiting Your Action — is digested too, since leaving it whole would keep ~40% of the savings on the table
- [x] Every digested section states its own total, so a reader can tell a truncated list from a complete one; a section listing fewer than it claims says so (preserving the T-2927 mismatch line, which is the control that made the last silent-truncation bug visible)
- [x] `FW_HANDOVER_DIGEST=0` restores byte-identical full dumps — verified by generating both ways and diffing, not by reading the code
- [x] `FW_HANDOVER_DIGEST` and `FW_HANDOVER_DIGEST_TOP_N` are registered in **both** `lib/config.sh` FW_CONFIG_REGISTRY and `web/blueprints/config.py` (the two are pinned equal by `config registry key count matches across sources`; a one-sided registration fails the pre-push audit — T-3024 origin)
- [x] All 14 narrative sections are byte-identical between digested and undigested output, checked by md5 per section rather than by eyeball
- [x] A real generated handover is ≥5× smaller than the same handover undigested, measured on this repo's live corpus
- [x] `tests/unit/handover_digest.bats` pins: digest on/off parity for narrative, count-vs-listed honesty, top-N respected, and that an empty section digests to nothing rather than to a "0 items" stub


### Human

- [ ] [REVIEW] The digested handover still gives you what you open a handover for

  This is the one thing no measurement settles, and it is the open half of the
  T-3025 GO. Byte counts and md5 parity say the narrative survived; they cannot say
  whether a session start reads *well*. You are also the party IW-1 was left to —
  whether the handover's primary consumer is a cold reader (narrative) or a live
  session (enumerations). If the enumerations turn out to be what you actually
  reach for, this is the wrong trade and `HANDOVER_DIGEST=0` is the answer, not a
  tweak.

  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && bin/fw handover`
  2. Open the newest file in `.context/handovers/` and read it as if you had been
     away a week.
  3. For contrast, generate the old shape and open it too:
     `cd /opt/999-Agentic-Engineering-Framework && FW_HANDOVER_DIGEST=0 bin/fw handover`

  **Expected:** the digested one answers "where am I, what must I not do, what next"
  without your needing the full dumps; where it truncates, it says so and names the
  command that gives you the rest.

  **If not:** say which section you missed and whether you wanted *more entries*
  (raise `HANDOVER_DIGEST_TOP_N`) or *the whole dump back* (set `HANDOVER_DIGEST=0`
  — that path is tested and restores the previous output unchanged). Either is one
  `bin/fw config set` away; nothing needs rebuilding.

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

## Measured Result

Generated both ways against this repo's live corpus, same session, minutes apart:

| | full (`FW_HANDOVER_DIGEST=0`) | digested | ratio |
|---|---|---|---|
| **whole file** | 270,039 B | 17,643 B | **15.3×** |
| `## Observation Inbox` | 141,774 B | 1,504 B | 94× |
| `## Work in Progress` | 69,198 B | 5,279 B | 13× |
| `## Awaiting Your Action (Human)` | 48,566 B | 1,635 B | 30× |
| 14 narrative sections | — | — | **byte-identical (md5)** |

Close to the prototype's prediction (273,761 → 18,762 B, 14.6×), which is the
useful part: the spike measured a post-processed handover, this is the generator
producing it directly, and they agree.

**Reversibility proven against the pre-change script, not against the code.**
Generated a handover with `git show HEAD:agents/handover/handover.sh` and compared
section-by-section with `FW_HANDOVER_DIGEST=0` output: **16 of 17 sections
md5-identical, section sets equal.** The one difference is `## Token Usage`, which
carries live session metrics (turn counts moved 5827 → 5823 between the two runs) —
not a structural difference.

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

bash -n agents/handover/handover.sh
out=$(bats tests/unit/handover_digest.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# T-3027's classifier must keep passing — this task changed the same generator.
out=$(bats tests/unit/handover_task_classification.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# Both config keys registered on BOTH sides. A one-sided registration is green
# locally and red only at the pre-push audit's cross-source parity invariant,
# where it reads as a hung push rather than a config error (T-3024 origin).
[ "$(grep -c '"HANDOVER_DIGEST|' lib/config.sh)" -eq 1 ]
[ "$(grep -c '"HANDOVER_DIGEST_TOP_N|' lib/config.sh)" -eq 1 ]
[ "$(grep -c '("HANDOVER_DIGEST",' web/blueprints/config.py)" -eq 1 ]
[ "$(grep -c '("HANDOVER_DIGEST_TOP_N",' web/blueprints/config.py)" -eq 1 ]
bash -c 'source lib/config.sh; [ "$(fw_config HANDOVER_DIGEST)" = "1" ] && [ "$(fw_config HANDOVER_DIGEST_TOP_N)" = "5" ]'

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

**Recommendation:** GO — keep the digest on, at `HANDOVER_DIGEST_TOP_N=5`.

**Rationale:**

Your GO on T-3025 authorised this shape and this scope, and the build came in where
the spike said it would: 15.3× on the whole file, all 14 narrative sections
byte-identical. The spike measured a post-processed handover; this is the generator
emitting it directly, and the two agree — which is the part worth trusting, not the
ratio itself.

The reason I am comfortable recommending GO rather than asking you to pilot it is
that the failure mode has a proven exit. `HANDOVER_DIGEST=0` was tested against the
*pre-change script*, not against my reading of the code: 16 of 17 sections
md5-identical, section sets equal, the one difference being live session metrics that
moved between two runs seconds apart. If the digest turns out to be wrong for how you
work, one `bin/fw config set` puts the old handover back exactly.

The one thing I cannot settle is IW-1, and it is genuinely yours: whether the
handover's primary consumer is a cold reader (narrative — in which case this trade is
right) or a live session (the enumerations — in which case it is wrong and the growth
should be attacked elsewhere). The cold-reader probe supports the first reading, but
it probed an agent, not you. That is what the Human AC asks.

**What I am not claiming:** that this closes the corpus-growth problem. It removes the
largest term — handovers were 68% of the indexed corpus and 79% of its growth — but
candidate A (binary quantization, ~10× on recall latency) remains unstarted and
unauthorised, and E′'s inclusion-set work is T-3024, still with you for review.

**Evidence:**

- Whole file 270,039 → 17,643 B (15.3×); per-section 141,774 → 1,504, 69,198 → 5,279,
  48,566 → 1,635. Generated both ways against this repo's live corpus, minutes apart.
- 14/14 narrative sections byte-identical by md5; section sets equal.
- Reversibility proven against `git show HEAD:agents/handover/handover.sh`, not
  asserted from the diff.
- 10 bats tests in `tests/unit/handover_digest.bats` run the real generator against a
  synthetic corpus; totals are derived from disk so they stay independent oracles.
- T-3027 landed first and is the precondition: `tasks_active:` now means active, so
  eliding the WIP dump no longer leaves a false status as the sole carrier.
- Both config keys registered on both sides; `fw_config` resolves 1 and 5.

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

### 2026-08-16T07:56:57Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3028-t-3025-go-handover-digest-plus-reference.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-0ed71de8
- **Timestamp:** 2026-08-16T08:39:20Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#1 (Human)** — [REVIEW] The digested handover still gives you what you open a handover for
  - **human-ac-mechanical-signal** (partial, heuristic) — `matched='names the\n  c' in Expected: the digested one answers "where am I, what must I not do, what next"   without your needing the full dumps; where it truncates, it says so a`
### 2026-08-16T08:22:55Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-08-16T08:38:36Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
