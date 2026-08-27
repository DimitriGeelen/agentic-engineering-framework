---
id: T-3194
name: "Branch-hygiene remediation text still tells operators to merge origin/master
  under the release train"
description: >
  T-3188 retargeted the MEASUREMENT to the dev branch, but the advice printed with
  each finding still names origin/master: bin/fw:3527 (doctor FORK mitigation), agents/audit/audit.sh:2470-2473
  (audit fork mitigation), agents/handover/handover.sh:446-450 (MERGEBACK_NUDGE).
  Between releases master is older than bleeding-edge, so following that advice merges
  a stale tree into a live branch. Not fixed in T-3188 because bin/fw and agents/audit/audit.sh
  are held dirty by another session's uncommitted T-3127 work - same blocker as T-3186.

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
created: 2026-08-27T08:04:06Z
last_update: 2026-08-27T09:33:23Z
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
  - ts: '2026-08-27T08:15:08Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=202,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-27T08:15:14Z'
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
  - ts: '2026-08-27T09:33:24Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 1
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=1 (body:episodic-only); F-AUTONOMY=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3194: Branch-hygiene remediation text still tells operators to merge origin/master under the release train

## Context

T-3188 retargeted branch hygiene's **measurement** to the dev branch. It left
every string of **advice** printed alongside a finding naming a literal
`master`. Under the release train master is older than bleeding-edge between
releases, so the remediation instructed the operator to merge the older tree
into the newer one — advice that undoes the very state the finding detected.

Six sites, four files:

| Site | What it said |
|---|---|
| `bin/fw` doctor cleanup + FORK | `fw integrate run` / `git merge origin/master` |
| `agents/audit/audit.sh` FORK mitigation | `merge origin/master INTO the branch` |
| `agents/handover/handover.sh` fork arm | `git merge origin/master` ×3 |
| `agents/handover/handover.sh` nudge arm | `fw integrate run master --push` |
| `lib/branch-hygiene.sh` `fw_go_live` refusal | `git merge origin/master` |
| `lib/branch-hygiene.sh` `fw_go_live` landing | `fw integrate run master --push` |

The handover nudge is the sharpest of these: it is what SessionStart injects,
so the next agent reads `fw integrate run master --push` as an instruction
carrying the framework's own authority — landing a strand straight onto the
consumer install surface.

`fw_go_live` needed more than prose. It does not merely advise a target, it
`git merge --ff-only`s onto one. Retargeting its messages while the merge still
aimed at master would have been worse than leaving both wrong: the command
would move the checkout **backward** while reporting that it reconciled. Its
comparand moved with its text.

All six now interpolate `_fw_bh_dev_name`, a single helper reading the same
`FW_DEV_BRANCH` knob as T-3186/T-3187/T-3188. It deliberately does **not** try
to unify the two comparand resolvers already in this file — those prefer
different refs on purpose and are pinned by T-3188's tests. It unifies only the
error-prone half: the branch *name* interpolated into advice across four files.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Every branch-hygiene remediation string names the RESOLVED dev branch, not a literal `master`: `bin/fw` doctor FORK mitigation, `agents/audit/audit.sh` audit FORK mitigation, `agents/handover/handover.sh` both MERGEBACK_NUDGE arms, and `lib/branch-hygiene.sh` fw_go_live's refusal + landing advice
- [x] No remediation string still says `fw integrate run master --push` — that instruction lands a strand directly on the consumer install surface, which is the exact injection the release train exists to prevent
- [x] The branch name is interpolated from the same `FW_DEV_BRANCH` resolution T-3186/T-3187/T-3188 use, so a repo that overrides the knob gets advice naming ITS branch, not ours
- [x] Fallback preserved: with no dev branch present every string reads exactly as it did before, so pre-T-3185 repos see no change
- [x] The fork advice keeps its substance — reconcile-while-small, merge the target INTO the branch, do NOT use one-way `fw integrate` on a fork (T-100194/T-100195). Retargeting must not quietly drop the T-100194 lesson
- [x] Tests in `tests/unit/t3194_remediation_target.bats`, every "no longer says master" assertion paired with one asserting the retargeted string IS present — deleting the advice must not read as a pass
- [x] Mutation-tested: reverting each site to its literal-master form reddens only that site's tests
- [x] `bash -n bin/fw`, `bash -n agents/audit/audit.sh`, `bash -n agents/handover/handover.sh`, `bash -n lib/branch-hygiene.sh` all pass (L-408), and `tools/bats-dead-negation-lint.py` reports clean (L-651)

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

# The suite, guarded per T-2738 (a pass marker survives a partial failure).
out=$(bats tests/unit/t3194_remediation_target.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# No regression in the four sibling hygiene suites that share this library.
# t100195 and t3095 are EXCLUDED on purpose: both carry pre-existing reds
# (T-3199, T-3195) verified by stashing this task's edits and re-running.
out=$(bats tests/unit/t100143_branch_hygiene.bats tests/unit/t100196_go_live.bats tests/unit/t3187_branch_identity_guard.bats tests/unit/t3188_hygiene_release_train.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# L-408: all four edited shell files must still parse.
bash -n bin/fw
bash -n agents/audit/audit.sh
bash -n agents/handover/handover.sh
bash -n lib/branch-hygiene.sh
# L-651: no assertion left in dead position behind a bare `!`.
python3 tools/bats-dead-negation-lint.py tests/unit/t3194_remediation_target.bats > /tmp/.t3194-lint 2>&1 && grep -q "dead 0" /tmp/.t3194-lint
# The defect itself, live: doctor's remediation must name the branch the scan
# measured against — asked of the resolver rather than hard-coded, so the line
# still means something in a repo whose dev branch is named something else.
# Two traps this form avoids, both hit while writing it:
#   `|| true` — `fw doctor` exits nonzero on WARNs, and under `set -e` that
#   aborts the line before grep ever runs (observed: rc=2 with the string
#   present in the file). The producer's exit code is not the assertion here.
#   redirect, not pipe — as a pipeline under `set -eo pipefail` a match
#   SIGPIPEs the producer to 141, so the regressed state would report PASS.
_t3194_dev=$(bash -c 'source lib/branch-hygiene.sh; _fw_bh_dev_name .'); bin/fw doctor > /tmp/.t3194-doctor 2>&1 || true; grep -q "fw integrate run $_t3194_dev" /tmp/.t3194-doctor

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

### 2026-08-27T08:04:06Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3194-branch-hygiene-remediation-text-still-te.md
- **Context:** Initial task creation

### 2026-08-27T09:33:23Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
