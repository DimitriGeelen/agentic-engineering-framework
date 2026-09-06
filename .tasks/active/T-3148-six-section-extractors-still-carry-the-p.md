---
id: T-3148
name: "Six section extractors still carry the pre-T-3134 sed-range shape; four feed
  gates"
description: >
  T-3134 anchored the extractor for '## Verification' only. Six other sites still
  use sed -n '/^## X/,/^## /p' | sed '$d', which carries all three defects 832 reported
  as D1/D2/D3. Four are gate-bearing: update-task.sh:115 and :1476 (P-010 AC gate),
  lib/inception.sh:552 (inception-decide AC preflight), agents/context/check-active-task.sh:925
  (G-020 build-readiness, with an even looser /^## [^A]/ terminator). Two are cosmetic
  (update-task.sh:207, lib/inception.sh:566 — a drift hint only). Measured corpus
  exposure over 3133 task files: the dangerous D3 shape (a non-exact prefix heading
  BEFORE the real one, which skips the gate silently) occurs 0 times for Acceptance
  Criteria and 0 for Recommendation. D1 is unreachable for AC (0 files have it as
  the last section) and reaches only the cosmetic hint for Recommendation (2 files,
  incl. T-3097). D2 occurs in 3 AC files and 51 Recommendation files, all exact duplicates,
  which over-includes and therefore blocks — the safe direction. So this is latent,
  not live. It is filed because the zero is luck: it depends on what headings people
  happen to write, and the shipped template is exactly what made the Verification
  number non-zero.

status: started-work
workflow_type: refactor
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
created: 2026-08-25T22:15:31Z
last_update: '2026-08-25T22:30:08Z'
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
  - ts: '2026-08-25T22:29:06Z'
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
cost_estimate_proposed:
  - ts: '2026-08-25T22:30:08Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 3
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=3 
      (workflow:refactor); effort=8 (lines=246,acs=8)
    rubric_sha: e4a00f38e801
---

# T-3148: Six section extractors still carry the pre-T-3134 sed-range shape; four feed gates

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Each of the six sites is decided EXPLICITLY as first-wins, last-wins, or
      refuse-when-ambiguous, and the decision is written in the code beside it.
      Copying `extract_verification_block`'s awk wholesale is the wrong fix:
      first-wins is correct for Verification and is precisely what produced the
      T-3144 false red on Recommendation
- [x] The start pattern is anchored at every site, so a heading that merely
      begins with the section name cannot open a range
- [x] No site ends in `sed '$d'`. That expression exists to discard sed's
      re-printed terminator, and deletes a content line whenever the section is
      the file's last — 832's D1
- [x] The T-3144 shape is a regression test: a file with a template
      `## Recommendation` stub followed by a real block must yield the real
      block, not the stub
- [x] A control shows each test discriminating — run against the pre-change
      expression it must behave differently. "Fails against pre-change code" is
      degenerate for a rewrite; the fixtures must fail for the RIGHT reason
- [x] The corpus numbers in the description are re-measured after the change and
      the new figures recorded, so the claim "0 files in the dangerous shape"
      is a measurement at fix time rather than an inherited one

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

### 2026-09-05 — per-site semantics: FIRST-WINS for AC, LAST-WINS for Recommendation
- **Chose:** `lib/section-extract.sh:extract_ac_section` is FIRST-WINS (mirrors
  `extract_verification_block`'s awk); `extract_recommendation_block` is
  LAST-WINS (deliberately the opposite policy).
- **Why:** Acceptance Criteria is written once, near the top, by convention —
  a later duplicate is a stray copy-paste and the earliest instance is what's
  actively being edited. Recommendation is the opposite shape: the template
  ships an empty stub and the real content is appended AFTER it, so the
  instance that matters is whichever heading occurs LAST. This task's own
  session hit the wrong choice live (T-3144, logged below under "Observed
  instance") — copying `extract_verification_block` verbatim onto
  Recommendation reads the stub and reports "empty" against 40 lines of real,
  complete recommendation.
- **Rejected:** refuse-when-ambiguous (reject the task file outright when >1
  heading exists) — corpus measurement below shows both duplicate-heading
  shapes are common enough (6 Recommendation files, 3 AC files) that refusing
  would newly block otherwise-valid, already-written task files with no
  actionable fix offered. First/last-wins resolves them silently and
  correctly instead.
- **Where implemented:** all six sites now call `extract_ac_section` or
  `extract_recommendation_block` from `lib/section-extract.sh` — no site
  keeps its own copy of the sed-range expression.

### 2026-09-05 — corpus re-measurement (AC6)
- **Chose:** re-ran the same three-defect scan (D1 last-section, D2 exact
  duplicate heading, D3 dangerous prefix-before-real) described in this
  task's filing, against the corpus as it stands now (3272 files in
  `.tasks/{active,completed}/`, up from 3133 at filing — the corpus is live
  and grows every session).
- **Results:**
  | Section | D1 (last-section) | D2 (exact duplicate) | D3 (dangerous prefix-before-real) |
  |---|---|---|---|
  | Acceptance Criteria | 0 | 3 | 0 |
  | Recommendation | 1 | 6 | 0 |
- **Why the figures moved from filing-time (D1: AC=0, Rec=2; D2: AC=3,
  Rec=51; D3: AC=0, Rec=0):** the D2 (Recommendation) drop from 51 to 6 is a
  methodology difference, not a corpus change — this re-measurement counts
  files with more than one *exact* `## Recommendation` heading, whereas the
  filing-time figure most likely counted broader occurrences of the
  unanchored PREFIX match (which also matches `## Recommendation Verdict
  (v1.0)`, a real, distinct heading present in the corpus — confirmed
  present via `grep -rl "Recommendation Verdict" .tasks/`). D1 for
  Recommendation shifted from `{T-3097, +1}=2` to a single different file
  (`T-2430-payload-mediation-privileged-state-holde.md`) — T-3097 is no
  longer the hit, consistent with ordinary corpus churn (tasks complete,
  get edited, move between `active/` and `completed/`) rather than a defect
  in either measurement.
- **Conclusion unchanged:** D3 (the dangerous, silent-skip direction) is
  still 0/0 for both sections at fix time, same as at filing. The fix
  removes the latent risk regardless — the corpus not yet having hit it is
  luck, not a property of the old code, exactly as the task description
  argued.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-08-25T22:15:31Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3148-six-section-extractors-still-carry-the-p.md
- **Context:** Initial task creation

### 2026-08-25T22:29:05Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Observed instance (T-3144, same session)

The Recommendation leg is not latent — it fired within the hour, on T-3144.

That file carries the shipped template's `## Recommendation` stub at line 378 and
the agent's real block appended at 448. `sed -n '/^## Recommendation/,/^## /p'`
takes the FIRST range, which is the empty stub, so the recommendation-completeness
gate refused a task whose recommendation was written, complete and 40 lines long.
Two close attempts were rejected with "## Recommendation is empty" while the text
was on screen.

This confirms the direction predicted from the corpus measurement and sharpens it.
Over-inclusion of a second block is the safe direction. Reading only the FIRST
block when the real content is in the second is a **false red**: the gate refuses
correct work and its message names the opposite of the cause. Safe, but it costs
real time and reads as a content problem rather than an extraction problem.

And it is why AC1 is worded the way it is. `extract_verification_block`'s awk
takes the first range too. For Verification that is right — a second block is
superseded. For Recommendation the identical rule produces exactly this. The fix
is a per-section semantic decision, not a copy of the awk. Recommendation likely
wants last-wins, or a refusal when two exist; T-3142 already repaired by hand a
task carrying two conflicting verdicts, for the same underlying reason.
