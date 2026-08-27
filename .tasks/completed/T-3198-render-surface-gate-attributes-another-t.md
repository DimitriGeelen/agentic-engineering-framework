---
id: T-3198
name: "render-surface gate attributes another task's files via commit-body cross-references"
description: >
  lib/render_surface.sh:91 derives a task's footprint from 'git log --all --grep <task_id>
  --name-only'. That matches the task id ANYWHERE in a commit message, including a
  prose cross-reference in another task's body. T-3186 was blocked from closing on
  web/blueprints/config.py, a file its own commit (325b7edc2) never touched: two other
  commits (T-3190 261cf6de7, T-3127 f0fec8e43) mention T-3186 in their bodies and
  do touch config.py, so the union dragged it in. The gate fired for a real reason
  in its own terms but named the wrong owner, and the fix an agent reaches for is
  --skip-render-review, which is exactly the habit P-013 exists to prevent: every
  false positive spends bypass credibility that the true positives need. Likely fix:
  match the SUBJECT line (or a leading 'T-XXX:' prefix) rather than the whole message,
  with the current broad grep as fallback when the narrow one finds nothing. Same
  class affects any consumer of _render_surface_git_touched_paths.

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
created: 2026-08-27T09:29:59Z
last_update: 2026-08-27T10:16:53Z
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
  - ts: '2026-08-27T09:45:08Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=202,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-27T09:45:16Z'
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

# T-3198: render-surface gate attributes another task's files via commit-body cross-references

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `_render_surface_git_touched_paths` matches the commit SUBJECT line (a leading `T-XXX` reference), not the whole message, so a prose cross-reference in another task's body no longer donates its footprint
- [x] The broad whole-message grep is retained as a FALLBACK, used only when the subject-scoped match finds nothing — so tasks whose commits predate the subject-prefix convention behave exactly as they do today
- [x] Regression pinned with a fixture reproducing the observed shape: task A's commit touches no render surface, task B's commit mentions A in its body AND touches `web/blueprints/`; the gate must fire for B and not for A
- [x] Control leg: a commit that genuinely IS task A's (subject `T-A: …`) and touches a render surface still fires the gate — narrowing must not turn the rail off
- [x] Every other consumer of `_render_surface_git_touched_paths` is identified and named in the task body, since the helper is shared and the fix moves all of them at once
- [x] `bash -n lib/render_surface.sh` passes (L-408) and the existing render-surface suites stay green

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

bash -n lib/render_surface.sh
bats tests/unit/t3198_render_surface_attribution.bats > /tmp/.t3198.out 2>&1 && grep -q '^ok 8 ' /tmp/.t3198.out && ! grep -q '^not ok' /tmp/.t3198.out
bats tests/unit/test_render_surface_gate.bats > /tmp/.t3198b.out 2>&1 && grep -q '^ok 1 ' /tmp/.t3198b.out && ! grep -q '^not ok' /tmp/.t3198b.out
bash -c 'source lib/render_surface.sh; test "$(_render_surface_git_touched_paths T-3186 | grep -c "web/blueprints/config.py")" = "0"'
bash -c 'source lib/render_surface.sh; test "$(_render_surface_git_touched_paths T-3194 | grep -c "web/blueprints/config.py")" = "0"'
bash -c 'source lib/render_surface.sh; test "$(_render_surface_git_touched_paths T-2837 | grep -c "web/blueprints/config.py")" = "0"'
bash -c 'source lib/render_surface.sh; test "$(_render_surface_git_touched_paths T-3127 | grep -c "web/blueprints/config.py")" != "0"'
bash -c 'source lib/render_surface.sh; test "$(_render_surface_git_touched_paths T-3190 | grep -c "web/blueprints/config.py")" != "0"'

## RCA

**Symptom:** `--status work-completed` refused on T-3186 and T-3194 (and earlier
T-2837) citing `web/blueprints/config.py`, a file none of those tasks touched.
Each close spent a `--skip-render-review` Tier-2 bypass.

**Root cause:** `_render_surface_git_touched_paths` derived a task's footprint
from `git log --all --grep "$task_id" --name-only`. `--grep` matches the whole
commit message, so a commit that merely *cited* a task in its body donated its
entire changed-file list to that task. The subject line records authorship in
this repo; the body records cross-references. The helper read them as the same
thing.

A second, independent defect was found while pinning the first: the match was a
bare substring, so `T-900` inherited `T-9001`'s footprint. That one was live in
the original code and would have survived a subject-only fix — it was caught by
this task's own regression test, not by inspection.

**Why structurally allowed:** the gate's own predicate had no notion of
authorship to be wrong about. It asked "does this id appear near these files?",
which is a genuinely different question from "did this task change these files?"
— and the two agree often enough that the divergence only shows up on tasks
whose commits happen to be cross-referenced. Nothing compared the gate's answer
against the task's actual diff, so a wrong answer was indistinguishable from a
right one from outside.

The compounding harm is specific to a *gate*: P-013 exists because three render
fixes shipped unlooked-at (T-1763/4/5). Every false positive spends the bypass
credibility the true positives depend on, and trains the reflex the gate was
built to prevent. A rail that cries wolf is weaker than no rail, because its
silence stops carrying information (L-527).

**Prevention:** `tests/unit/t3198_render_surface_attribution.bats` pins the
donor shape *and* the control legs. The controls are the load-bearing half:
"narrows correctly" and "turned the rail off" produce an identical diff and an
identical green suite, so only the paired assertion — the true owner still fires
— tells them apart. Verified by mutation, not by inspection:

| Mutation | Tests reddened |
|---|---|
| Pre-fix semantics (whole message decides authorship) | 1, 2, 7 |
| Fallback removed | 6 |
| Narrow-path digit boundary removed | 7 |
| Rail disabled entirely (helper always empty) | 1, 3, 4, 5, 6 |

The first mutation attempt reddened only test 7 and was discarded as invalid:
it mutated the awk filter, whose input is already subject-only, so it could not
have exercised the subject-vs-body claim at all. That near-miss is the same
"test measures its callee, not its subject" shape recorded on T-3186.

**Duplicate note:** filed twice. T-2840 (2026-08-06) recorded this exact defect
— same file, same line, same proposed fix, same collateral file — from a third
instance (T-2837, donor commit `8b41090b4`). It sat `captured` for 21 days and
was independently rediscovered as T-3198. The framework found this defect twice
and landed it zero times; T-2840 is closed as superseded by this task rather
than worked in parallel.

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

### 2026-08-27T09:29:59Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3198-render-surface-gate-attributes-another-t.md
- **Context:** Initial task creation

### 2026-08-27T10:16:53Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Evidence — two independent instances in one session

Both blocked on the same file (`web/blueprints/config.py`), from donor commits
neither blocked task authored:

| Blocked task | Its own commit | Donor commit that mentioned it | Donor's subject |
|---|---|---|---|
| T-3186 | `325b7edc2` (no render surface) | `261cf6de7`, `f0fec8e43` | T-3190, T-3127 |
| T-3194 | `b4304ab0a` (no render surface) | `f0fec8e43` | T-3127 |

`f0fec8e43` is a T-3127 commit whose body names T-3186 and T-3194 as blocked
dependents — the ordinary, desirable habit of recording what a commit unblocks.
The gate reads that prose as authorship.

Both closes therefore spent a `--skip-render-review` Tier-2 bypass on a false
positive. That is the cost worth naming: the gate exists because three render
fixes shipped unlooked-at (T-1763/4/5), and every false positive teaches the
reflex of bypassing it. A gate that fires on prose cross-references trains
agents out of the habit it was built to install.

Neither close simply asserted the gate was noisy — the actual /config rows were
opened and checked by hand, which is how OBS-349 (Watchtower serving 13h-stale
Python) surfaced.

## Recommendation

**Recommendation:** GO — narrow the match to the commit SUBJECT line, with the
current whole-message grep retained as fallback when the narrow form finds
nothing.

**Rationale:** The repo's commit convention is a leading `T-XXX:` on the subject
(P-002 enforces the reference; the subject prefix is universal in practice), so
subject-matching recovers true authorship without a schema change. Falling back
to the broad grep when the narrow one is empty preserves every case that works
today — including commits predating the convention — so the change can only
reduce false positives, never introduce false negatives.

**Evidence:**
- `lib/render_surface.sh:91` — `git log --all --grep "$task_id" --name-only`
- Two blocked closes above, both with clean own-commit footprints
- `_render_surface_git_touched_paths` is a shared helper, so one fix covers
  every consumer rather than the render gate alone

## Consumers of the shared helper (AC5)

`_render_surface_git_touched_paths` has exactly two callers, both in
`lib/render_surface.sh`, so one fix moves both:

| Caller | Line | What it decides |
|---|---|---|
| `task_touches_render_surface` | 143 | the P-013 gate predicate — whether a close is refused |
| `render_surface_files_in` | 182 | the file list shown to the operator in the block message |

No caller outside this file (verified: `grep -rn _render_surface_git_touched_paths`
over `lib/ web/ agents/ bin/ tools/` returns only the definition and these two).
Both were exercised in the regression suite — `task_touches_render_surface` by
tests 2 and 4, `render_surface_files_in` by test 5.
