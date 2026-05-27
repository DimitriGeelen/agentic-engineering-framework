---
id: T-2036
name: "completed-before-commit deadlock — work-on silently fails to reactivate completed
  task"
description: >
  Framework gap (G-019 class) hit during T-2035.

status: work-completed
workflow_type: build
owner: agent
horizon: now
tags: []
components: [bin/fw, tests/unit/test_work_on_completed_task.bats]
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-25T08:11:56Z
last_update: 2026-05-27T22:11:41Z
date_finished: 2026-05-27T22:11:41Z
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
  - ts: '2026-05-25T08:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-25T08:15:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
---

# T-2036: completed-before-commit deadlock — work-on silently fails to reactivate completed task

## Context

Hit during T-2035 (session S-2026-0522-1941). If an agent runs
`fw task update T-XXX --status work-completed` **before** committing the code, it
lands in an unrecoverable deadlock:

1. Completion moves the file `active/ → completed/` and clears focus.
2. The `check-active-task` PreToolUse hook (agents/context/check-active-task.sh:336)
   blocks every Bash mutation (git add/commit) because the focused task is no longer
   in `active/`.
3. `fw work-on T-XXX` is the advertised recovery, but `work-completed` is a **terminal**
   status — `lib/enums.sh:68-77` has no transition out of it. So work-on's internal
   `update-task.sh --status started-work` (bin/fw:4841) fails the `is_valid_transition`
   check and exits 1 — but the call is wrapped `2>/dev/null || true`, so work-on prints
   "Ready to work on T-XXX" (**false success**) while the file stays in `completed/`.
4. The only escapes are non-obvious: `FW_SAFE_MODE` in the *session* env (an inline
   prefix doesn't reach the hook), or focusing a *different* active task and committing
   the completed one with the `FW_SWITCH_FOCUS=1` drift override (what T-2035 used).

This is G-019 class: the framework allowed a silent false-success (`work-on` claims
success while doing nothing) at exactly the moment the agent needs a clear path.

## Acceptance Criteria

### Agent
- [x] `fw work-on T-XXX` on a `work-completed` task no longer prints false "Ready to work on" — it now refuses with exit 1 and an actionable message; the `2>/dev/null || true` swallow at bin/fw:4841 is gone (also pinned by regression test #4)
- [x] A supported recovery path exists for "completed before commit" — `work-on` detects the completed-file case and emits the exact `bin/fw work-on T-<other> && git add <files> && FW_SWITCH_FOCUS=1 git commit` unblock sequence plus the alternative "reopen-by-hand" path if the close was premature
- [x] Regression test pins the chosen behaviour (`tests/unit/test_work_on_completed_task.bats`, 4 tests: completed→refuse, missing→refuse, active→succeed, swallow-string-grep-marker)

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
# Pipefail/SIGPIPE hint (L-387): P-011 runs each command under `set -eo pipefail`.
# `cmd | grep -q PATTERN` exits 141 (SIGPIPE) when grep matches and closes stdin
# while the upstream is still writing — verification then "fails" even though
# the pattern was present. Safe pattern: capture first, grep the capture:
#     out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"
# Or:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
# Origin: L-387, captured 4× (T-1716, T-1838, T-1862, T-1863) before this hint.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.
bats tests/unit/test_work_on_completed_task.bats
bash -n bin/fw

## RCA

**Symptom:** `bin/fw work-on T-XXX` on a `work-completed` task printed
`Ready to work on T-XXX` (green, "success" tone) while the task stayed in
`.tasks/completed/`. Focus remained nulled, `git add`/`git commit` continued
to be blocked by the active-task PreToolUse hook. Agent assumed focus was
restored; deadlock continued silently.

**Root cause:** Two-stage:
1. `work-completed` is a terminal lifecycle state in `lib/enums.sh` —
   `VALID_TRANSITIONS` has no `work-completed → started-work` edge.
2. `bin/fw` line 4841 invoked `update-task.sh ... --status started-work`
   with `2>/dev/null || true` — so update-task's correct exit-1 refusal
   was discarded, then `context.sh focus` ran (writes focus.yaml
   pointing at a task that's no longer in active/), then the green
   "Ready to work on" line printed. Three layers of false success.

**Why structurally allowed:** `2>/dev/null || true` is the canonical
"swallow everything we don't care about" idiom; nothing forces the call
site to distinguish "already-in-target-status idempotent re-run" (genuinely
exit-0 from update-task) from "transition refused" (exit-1). The terminal
status of `work-completed` plus the swallow conspired to turn a refusal
into a printable success.

**Prevention:**
1. Pre-check: work-on now greps active/ and completed/ before calling
   update-task — if the file is in completed/, print actionable recovery
   options and exit 1 *before* update-task is invoked at all.
2. Swallow removed: the `--status started-work` call is no longer
   wrapped in `2>/dev/null || true`. Any update-task refusal surfaces
   directly and aborts work-on with exit 1.
3. Regression test `test_work_on_completed_task.bats` test #4 greps for
   the swallow string and fails if it ever creeps back.

## Decisions

### 2026-05-28 — Refuse vs. reopen
- **Chose:** Refuse with actionable recovery (option A from the AC menu).
- **Why:** Adding a `work-completed → started-work` reopen transition
  complicates the lifecycle (now "terminal" is no longer terminal),
  weakens episodic memory guarantees, and risks masking real "I closed
  too early" bugs by making the recovery feel routine. The deadlock is
  rare enough (recovery is one extra anchor-switch); the existing
  `FW_SWITCH_FOCUS=1 git commit` path is already documented and
  Tier-2-logged. Printing the recovery path verbatim in the refusal
  message gets the same speed-of-recovery as a reopen without the
  lifecycle damage.
- **Rejected:** Add a guarded reopen transition (option B). Would have
  required new `--reopen` flag, fresh date_finished handling, audit
  surface for "tasks that were closed and then reopened", and a clear
  policy for whether episodic memory is regenerated on second close.
  All scope creep for what is ultimately a recoverable footgun.

## Recommendation

**Recommendation:** GO

**Rationale:** Bounded ~40-line edit to `bin/fw:4838-4886` (pre-check the
file's location, removed swallow, surfaced real failures). Backed by 4-test
regression bats (`tests/unit/test_work_on_completed_task.bats`): completed
→ refuse, missing → refuse, active → succeed, swallow-string grep marker
to prevent regression of the original idiom. Smoke-tested live against
T-2058 (the task I just closed in this session), T-2036 (active), and
T-9999 (non-existent) — all three paths behave as designed.

Beneficial side effect: the original P-002 silent false-success pattern
becomes self-documenting — every time an agent hits this deadlock from
now on, the work-on output names the deadlock, references this task by
number, and lists the exact recovery commands.

**Evidence:**
- Code: `bin/fw:4838-4886` (~40-line block, includes L-387-safe glob-loop
  for active/completed file detection, drop of `2>/dev/null || true`
  swallow, and the verbatim recovery message)
- Tests: `tests/unit/test_work_on_completed_task.bats` — 4/4 green
- L-387 self-application: my first attempt at file-detection used
  `ls ... | head -1`, which immediately SIGPIPEd under pipefail. Fixed
  in-place by switching to a bounded for-loop. T-2057's L-387 detector
  (now decide-pending) would have caught this at filing.

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

### 2026-05-25T08:11:56Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2036-completed-before-commit-deadlock--work-o.md
- **Context:** Initial task creation

### 2026-05-27T22:07:41Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-badfec59
- **Timestamp:** 2026-05-27T22:11:43Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-27T22:11:41Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
