---
id: T-3193
name: "A release can advance master and then fail to publish its tag, and the GitHub
  Release still gets created"
description: >
  T-3190 guarded one direction: no tag survives publication if master cannot advance.
  The first real release hit the mirror image. The release-branch push to origin succeeded,
  the pre-push audit lock then blocked the TAG push, and release_tag_and_release carried
  on to create a GitHub Release for a tag origin does not have. Consumers see master
  at the new commit with no tag naming it; the GitHub Release page says the release
  shipped. The command does return non-zero, but any caller that pipes it (fw release
  ... | tail) sees the pipeline's 0 instead.

status: work-completed
workflow_type: build
owner: agent
horizon: null
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
created: 2026-08-27T07:50:47Z
last_update: 2026-08-27T21:52:13Z
date_finished: 2026-08-27T21:52:13Z
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
  - ts: '2026-08-27T08:00:09Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=206,acs=8)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-27T08:00:21Z'
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

# T-3193: A release can advance master and then fail to publish its tag, and the GitHub Release still gets created

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] A release that cannot publish its tag to a remote does not report success, and does not create a GitHub Release for a tag that remote lacks
- [x] The tag push is retried, or its precondition (the pre-push audit lock) is waited on, rather than failing on first contention — the lock is routinely held by cron and this is the common case, not the rare one
- [x] Decide and record which invariant wins when master has already advanced: roll master back, or hold the release open and retry the tag. Both are defensible; pick one and say why in `## Decisions`
- [x] `bin/fw release` propagates the function's non-zero exit, so a piped caller cannot read a failed release as a successful one
- [x] Test covers: branch push succeeds + tag push fails → no GitHub Release, non-zero exit
- [x] CONTROL LEG: branch push succeeds + tag push succeeds → GitHub Release created, exit 0, so the test above measures the failure and not the absence of the feature

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

bash -n lib/release.sh
out=$(timeout 600 bats tests/unit/t3193_release_tag_push_failure.bats 2>&1); echo "$out" | grep -q "^ok 10" && ! echo "$out" | grep -q "^not ok"
out=$(timeout 600 bats tests/unit/t3190_release_master_ff.bats tests/unit/lib_release.bats 2>&1); ! echo "$out" | grep -q "^not ok"
# T-3193: single command, own exit IS the verdict — a `cmd; test $?` chain passes
# at the gate (errexit suppressed in an if-condition) but fails a documented
# rehearsal under `set -eo pipefail`. Measured this session.
if bin/fw release nosuchsubcmd >/dev/null 2>&1; then exit 1; fi


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

**Symptom:** the first real release pushed `master` to origin, then failed to push
the tag (pre-push audit lock, held by the daily cron), then created a GitHub Release
naming a tag origin does not have. Consumers saw the install surface at the new
commit, nothing naming it, and a release page asserting the release shipped.

**Root cause:** `lib/release.sh` guarded one direction only. T-3190 added a refusal
for the release-branch push — if it reaches no remote, roll back and publish nothing.
The tag push, twenty lines later, only set `failed=1` and fell through to
`gh release create`. Two pushes, one guard.

**Why structurally allowed:** the asymmetry is invisible while both pushes succeed,
which is every run until a remote refuses exactly one of them. The audit lock does
precisely that — it is a *pre-push* gate, so it blocks the second push of a
two-push sequence after the first has already landed. The condition that produces
the bug is one the framework creates for itself, on a schedule, via cron.

**Prevention:** the tag leg now mirrors the branch leg's refusal, and 10 tests pin
it — including a control leg proving the happy path still publishes, without which
"correctly refused" and "never ran" would be the same observation.

**Mutations** (each applied to `lib/release.sh`, reverted after; `RELEASE_TAG_RETRY_SLEEP=0`):

| Mutation | Reddened |
|---|---|
| M1 — delete the refusal (restore pre-T-3193 behaviour) | tests 2, 4, 8 |
| M2 — refuse, but still create the GitHub Release | test 2 |
| M3 — force-push the release branch back (the rejected AC3 option) | test 6 |
| M4 — single attempt instead of 3 | test 9 |
| M5 — print the retry line unconditionally | test 10 (control leg) |

M1 is worth reading closely: it did **not** redden test 3 (exit non-zero). The old
code already returned non-zero, because `failed=1` was set. So the defect was never
"the command reports success" in the exit-status sense — it was the GitHub Release
being created anyway, plus a piped caller reading the pipeline's 0. Had the suite
asserted only on exit status it would have passed against the broken code.

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

### 2026-08-27 — which invariant wins when the release branch has already advanced

- **Chose:** HOLD THE RELEASE OPEN. Keep the local tag, create no GitHub Release,
  exit non-zero, and leave the pushed release branch exactly where it is.
- **Why:** by the time the tag push fails, `master` has been pushed and consumers
  may already have fetched it. Retracting it means a force-push to the install
  surface — Tier 0, destructive, and it breaks anyone who pulled in the window.
  The resulting state, "master advanced, tag pending", is untidy, honest and
  recoverable by re-running the command. The alternative state, "release
  published, tag missing", is tidy, false, and is the bug.
- **Rejected — roll master back:** it is what the *branch-push* guard does one
  block earlier, which is why it looks consistent. It is not: that guard fires
  when the branch reached NO remote, so there is nothing published to retract.
  This one fires after a successful publish. Same-looking situations, opposite
  safe actions. Pinned by the test "the already-pushed release branch is NOT
  rolled back", and mutation M3 (force-push the old sha back) reddens it.

### 2026-08-27 — AC4, and the half of it that cannot be fixed here

- **Measured:** `bin/fw release` already propagates. `bin/fw release nosuchsubcmd`
  exits 2; the case branch's status is the script's status. That half needed no fix
  and is now pinned in `## Verification`.
- **The other half is not ours to fix.** `fw release … | tail` reports *tail's*
  status — a property of shell pipelines, not of `fw`. No change inside the command
  can make a pipe surface an upstream failure; only the caller's `set -o pipefail`
  can (measured: piped exit 0, piped+pipefail exit 2).
- **What was done instead:** the refusal is written to **stderr**, which a
  `| tail` on stdout never captures, so it stays on the operator's terminal even
  when the exit status is masked. Saying "AC4 done" without this distinction would
  have claimed a guarantee the shell does not provide.


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

### 2026-08-27T07:50:47Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3193-a-release-can-advance-master-and-then-fa.md
- **Context:** Initial task creation

### 2026-08-27T21:46:13Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-8419f2be
- **Timestamp:** 2026-08-27T21:52:25Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 3
     - evidence: `out=$(timeout 600 bats tests/unit/t3190_release_master_ff.bats tests/unit/lib_release.bats 2>&1); ! echo "$out" | grep -q "^not ok"`

### 2026-08-27T21:52:13Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
