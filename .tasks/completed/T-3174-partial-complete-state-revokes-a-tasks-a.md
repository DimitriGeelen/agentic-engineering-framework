---
id: T-3174
name: "partial-complete state revokes a task's authority to commit its own closure
  artefacts"
description: >
  Inbound field report from 001-CashWeb-Lightspeed-Ecwid-integration (their G-053,
  three incidents in one day), reproduced independently at HEAD. A task in
  partial-complete (status work-completed + owner human + still in .tasks/active/)
  is
  refused by agents/context/check-active-task.sh :750 for any non-exempt Bash command,
  including the git commit that would land the closure artefacts the transition itself
  just wrote. The block message offers `fw work-on T-XXX`, but status-transitions.yaml
  gives work-completed NO outgoing transition, so `fw work-on <that task>` exits 1
  with
  "Invalid transition 'work-completed' -> 'started-work'". The only exit is attributing
  the commit to a different task, destroying the traceability P-002 protects. Three
  findings beyond their report: (1) Write/Edit to .context/, .tasks/, .claude/ is
  already
  exempt at :441 and exits 0 in the same state - the gate implements the proposed
  boundary
  on one side only, so the fix is parity not new policy; (2) the :750 branch is
  unreachable for genuinely-archived tasks, which exit at :718 with a different message,
  so :750 fires ONLY for partial-complete; (3) no graduated bypass exists - unlike
  the
  sibling focus-drift gate's --switch-focus / FW_SWITCH_FOCUS=1, the only escape is
  FW_SAFE_MODE=1, which disables the whole gate. Prevalence: they report 19; our own
  repo
  has 243 of 409 active tasks (59%) in this state. Same class as G-092.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [agents/context/check-active-task.sh, status-transitions.yaml, 
      agents/task-create/update-task.sh]
related_tasks: [T-1730, T-1890, T-679]
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
created: 2026-08-26T15:39:11Z
last_update: 2026-09-03T17:25:11Z
date_finished: 2026-09-03T17:25:11Z
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
  - ts: '2026-08-26T15:45:08Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 2
      effort: 8
    rationale: blast_radius=3 (3-components); tier=2 (workflow:build); effort=8 
      (lines=298,acs=9)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-26T15:45:13Z'
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
---

# T-3174: partial-complete state revokes a task's authority to commit its own closure artefacts

## Context

Inbound field report from 001-CashWeb-Lightspeed-Ecwid-integration (their G-053, three
incidents in one day), reproduced independently at HEAD before registration.

**The trap.** `fw task update T-XXX --status work-completed` with an unchecked Human AC
produces partial-complete: `status: work-completed`, `owner: human`, file stays in
`.tasks/active/`. From that moment `agents/context/check-active-task.sh` refuses any
non-exempt Bash command while focus is on that task — including the `git commit` that
would land the closure artefacts the transition itself just wrote
(`.context/project/decisions.yaml`, `.context/working/feedback-stream.yaml`, the task file).

**Reproduced at HEAD, scratch PROJECT_ROOT, verbatim:**

```
$ echo '{"cwd":"…","tool_name":"Bash","tool_input":{"command":"git commit -m \"T-900: close artefacts\""}}' \
    | CLAUDECODE=1 bin/fw hook check-active-task
BLOCKED: Task T-900 has status 'work-completed'.

To unblock:
  fw work-on T-XXX   (resume another task)
  fw work-on 'name'  (create a new task)
…
Policy: P-002 (Cannot modify files under a completed task)
exit 2
```

**The offered remedy does not exist.** `status-transitions.yaml` gives `work-completed`
**no outgoing transition** — it is terminal in the table. Measured:

```
$ fw work-on T-900
ERROR: Invalid transition 'work-completed' → 'started-work'
work-on: status transition for T-900 failed — focus will NOT be set
exit 1
```

So the only exit is attributing the commit to a *different* task — which destroys exactly
the traceability P-002 exists to protect. 001-CashWeb did this three times today (T-154
and T-156 both committed under T-155; T-012 same shape).

**Three findings they did not report, measured while verifying:**

1. **The gate already implements the boundary they proposed as a caveat — on one side
   only.** `Write`/`Edit` to `.context/*`, `.tasks/*`, `.claude/*` is exempted at :441 and
   exits 0 even under partial-complete; only source writes are blocked. Bash has no
   `file_path`, so `git commit` falls through to the status gate at :750. Same task, same
   state, opposite answers. The fix is **parity**, not a new policy.

2. **The `work-completed)` branch is unreachable for genuinely-finished tasks.** An
   archived task fails the `find_task_file … active` lookup at :715 and exits at :718 with
   *"is not active (may be completed or missing)"*. So :750 fires **only** for
   partial-complete — the code comment at :731 even says so — and its message is the only
   advice the framework gives for a state that is by construction unfinished.

3. **There is no graduated bypass.** Unlike the sibling focus-drift gate (`--switch-focus`
   / `FW_SWITCH_FOCUS=1`, both Tier-2 logged), this branch offers none. The only escape is
   `FW_SAFE_MODE=1`, which disables the entire task gate.

**Prevalence.** They report 19 partial-complete tasks. Our own repo: **243 of 409 active
tasks (59%)** are `status: work-completed` still sitting in `active/`. This is the majority
state of our task set, not an edge case.

**Why (c) is a no-op.** They proposed "write the closure artefacts before the status
flips". Measured: those artefacts are written by `agents/task-create/update-task.sh`
*in-process* (decision capture ~:2235, episodic/backprop ~:2278/:2331), and the PreToolUse
hook gates *tool calls*, not a script's own writes. Those writes are never blocked. What is
blocked is the subsequent `git commit`, and any later correction — neither of which (c)
reaches. Recommending (a), scoped as above.

**Class.** Same shape as G-092: the write side accepts a state the read side then refuses.
Here the *same file* is writable via one tool and unreachable via another.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `agents/context/check-active-task.sh` distinguishes **partial-complete**
      (`status: work-completed` AND file still in `.tasks/active/` AND `owner: human`)
      from a task that is genuinely finished. The `work-completed)` branch at :750 is
      reached ONLY in the partial-complete case today — a fully-completed task exits
      earlier at :716 with a different message — so the branch can be specialised
      without touching the archived-task path
- [x] Under partial-complete, a Bash command is allowed when it writes only governance
      paths (`.context/`, `.tasks/`, `.claude/`), matching the exemption Write/Edit
      already gets at :441. Source-file writes stay blocked. This is **parity with an
      existing decision**, not a new policy: today `Write` to `.tasks/active/T-900.md`
      exits 0 while `git commit -m "T-900: ..."` exits 2, for the same task in the same
      state
- [x] `git commit` referencing the partial-complete task is permitted under that rule,
      so the task can commit its own closure artefacts under its own id. Verified by
      the probe that currently fails (see `## Context`)
- [x] The block message no longer offers a remedy that cannot be executed. Today it
      prints `fw work-on T-XXX   (resume another task)`; `fw work-on <the-task-itself>`
      exits 1 with `Invalid transition 'work-completed' → 'started-work'` because
      `status-transitions.yaml` gives `work-completed` no outgoing edge at all. Whatever
      the message ends up saying must be executable as printed — L-399 / T-1890 contract
- [x] Whatever escape remains for the genuinely-blocked case names a mechanism that
      works for `git commit` (external parser — flags are rejected, so env-var form per
      T-1890 leg 3), and logs Tier-2 to `.context/working/.gate-bypass-log.yaml`.
      `FW_SAFE_MODE=1` is not an acceptable answer: it disables the whole task gate
- [x] Bats coverage pins the matrix end-to-end: {partial-complete, archived} ×
      {governance-path write, source write, `git commit`}. The partial-complete ×
      `git commit` cell is the regression cell
- [x] `## Decisions` records why (a) was chosen over (b) and (c), including the measured
      reason (c) is a no-op — see `## Context`

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

out=$(bats tests/unit/t3174_partial_complete_edit_matrix.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
out=$(bats tests/unit/t3179_partial_complete_commit.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
bin/fw vendor self --check

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

### 2026-09-03 — AC5 remedy: graduated env-var bypass (a), not a new transition edge (b) or FW_SAFE_MODE (c)

- **Chose:** a new, narrowly-scoped Tier-2-logged escape hatch,
  `FW_ALLOW_PARTIAL_COMPLETE_EDIT=1`, checked inside the existing
  `work-completed)` case branch in `check-active-task.sh`. It authorises
  exactly one thing — the next tool call, on the currently-focused
  partial-complete task — and writes an auditable entry to
  `.context/working/.gate-bypass-log.yaml` (task, flag, caller, and
  file-or-command). Same shape as the T-1890 focus-drift bypass
  (`FW_SWITCH_FOCUS=1`): env-var form because it must also work for `git
  commit`, whose parser rejects unrecognised flags outright.
- **Why:** it is the minimal change that closes the actual deadlock (an
  agent that needs one more EDIT — not a commit, T-3179 already solved
  that — on a task the reviewer or human sent back) without touching the
  status state machine, without widening any existing exemption's blast
  radius, and without disabling gates unrelated to this one task.
- **Rejected — (b) add `work-completed → started-work` to
  `status-transitions.yaml`:** this is what the block message used to
  (wrongly) imply already worked. Adding the edge would make `fw work-on
  T-XXX` on the SAME task succeed, but `update-task.sh`'s transition to
  `started-work` also flips `owner` back and clears `date_finished` —
  semantically re-opening the task, not authorising a single edit. That
  is a bigger behavioural change than the bug warrants: partial-complete
  is a real, intentional state (P-013 steers every render-touching build
  task there by design) and silently permitting a full status rollback
  from it would let an agent erase the "this needs human review" signal
  the state exists to preserve, not just fix the deadlock. The env-var
  escape authorises the EDIT without touching `status:`/`owner:` at all.
- **Rejected — (c) tell the agent to write closure artefacts before the
  status flips:** measured and disproved in `## Context` — the artefacts
  this task exists to unblock are written by `update-task.sh` in-process
  (`decisions.yaml`, `feedback-stream.yaml`, the task file itself) at the
  moment `--status work-completed` runs, and the PreToolUse hook only
  gates subsequent tool calls, not a script's own writes. Those writes
  were never blocked. What was blocked is everything AFTER — the `git
  commit` (T-3179) and any correction edit (AC5, this decision) — and
  (c) reaches neither.
- **Not `FW_SAFE_MODE=1`:** it disables the ENTIRE task gate for every
  command against every task for the rest of the session, not just the
  one edit on the one partial-complete task. The AC explicitly rules
  this out; the new mechanism is scoped to the `work-completed)` branch
  only and stops applying the instant the command completes.

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

### 2026-08-26T15:39:11Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3174-partial-complete-state-revokes-a-tasks-a.md
- **Context:** Initial task creation

## Status after T-3179 (2026-08-27)

T-3179 shipped the commit allowance independently and covers this task's first
three criteria. Measured, not assumed:

- **AC1-3 CLOSED.** `check-active-task.sh` now allows a bare `git commit` under
  partial-complete, scoped so `--no-verify`/`-n` stay blocked, non-commit writes
  stay blocked, and the focus-drift gate still fires first. Pinned by
  `tests/unit/t3179_partial_complete_commit.bats` (11 tests, 3 mutations).
- **AC4 PARTIAL.** The block message now leads with "'git commit' IS allowed
  here (T-3179)" and re-labels the rest "To unblock further EDITS (not commits)".
  The unexecutable-remedy complaint is softened but not removed — see AC5.
- **AC5 OPEN.** `status-transitions.yaml` still gives `work-completed` **no
  outgoing transition** (verified: the `transitions:` list has entries *to*
  work-completed from started-work and issues, and none *from* it). So an agent
  that needs one more EDIT on a partial-complete task — the reviewer found
  something, the human has not ticked yet — still cannot resume it. The message
  points at `fw work-on T-XXX (resume another task)`, which works only by
  abandoning the task; the only in-place escape remains `FW_SAFE_MODE=1`, which
  disables the whole task gate. This is the residual hole.
- **AC6 PARTIAL.** T-3179's suite covers partial-complete thoroughly. The
  `archived` half of the {partial-complete, archived} matrix is untested here —
  note the `work-completed)` branch is unreachable for genuinely-archived tasks
  (they fail the `find_task_file` lookup earlier), so that half may be
  vacuous rather than missing. Confirm before writing tests for it.
- **AC7 OPEN.** No `## Decisions` entry yet.

**Remaining scope is therefore AC5 + AC7**, plus confirming AC6 is vacuous.
Do not close this on T-3179's evidence alone.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-11fc6b27
- **Timestamp:** 2026-09-03T17:25:26Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **mock-only-integration** (partial, heuristic) @ AC vs Verification cross-check
     - evidence: `out=$(bats tests/unit/t3174_partial_complete_edit_matrix.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'`

### 2026-09-03T17:25:11Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
