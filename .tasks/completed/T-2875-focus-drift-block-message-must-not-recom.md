---
id: T-2875
name: "Focus-drift block message must not recommend a remedy the framework refuses"
description: >
  Focus-drift block message must not recommend a remedy the framework refuses

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
created: 2026-08-08T16:57:38Z
last_update: 2026-08-08T17:06:21Z
date_finished: 2026-08-08T17:06:21Z
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
  - ts: '2026-08-08T17:00:08Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-08T17:00:14Z'
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

# T-2875: Focus-drift block message must not recommend a remedy the framework refuses

## Context

The focus-drift block message (`agents/context/check-active-task.sh:377-378`) offers three
remedies and lists first:

    1. Switch focus first:
       bin/fw context focus <TARGET>

T-2874 made `fw context focus` refuse a **completed** task id. So whenever the drift target
is completed — the common case, because the usual trigger is a follow-up commit attributed to
a task that just closed — remedy #1 is a command the framework itself now refuses. The agent
is told to run it, runs it, gets a second refusal, and has to discover options 2/3 on its own.

This is not new breakage introduced by T-2874. Before T-2874 remedy #1 *appeared* to work
(exit 0) and then deadlocked every subsequent gated call on "Task X is not active". T-2874
changed it from silently broken to loudly broken. Both are wrong; only the second is visible,
which is why it is now fixable.

Class: L-399 / T-1890 bypass-contract parity — a mechanism named in a block message must
actually work when followed. Hit live in this session (T-2874 vendored-refresh commit).

## Acceptance Criteria

### Agent
- [x] When the drift target resolves to a **completed** task, the block message does NOT
      offer `context focus <target>` as a remedy
- [x] When the drift target is completed, the message names a remedy that works, and states
      in one line why focus cannot point at a completed task
- [x] Every command the message names in the completed-target branch is verified to actually
      succeed — no second dead remedy substituted for the first
- [x] When the drift target is **active**, the message is unchanged (option 1 still offered)
- [x] bats coverage for both branches, including an anti-vacuity leg that re-opens the defect
      by mutating the branch condition in live source (not a `git show HEAD~N:` teeth check,
      which goes inert on the next commit — T-2874 origin)

**Evidence for AC3** (the "no second dead remedy" criterion, which is the one that earned
its keep): the completed-target branch names exactly two mechanisms, both verified —
`FW_SWITCH_FOCUS=1` was executed live this session to land the T-2874 vendored-refresh
commit, and `--switch-focus` is pinned end-to-end against its four downstream consumers by
`tests/unit/check_active_task_switch_focus.bats` legs 6-9. A reopen command was considered
and REJECTED: `fw task update <id> --status started-work` does not move a file from
`completed/` back to `active/` (no such move exists in `update-task.sh` — only the forward
`active/ → completed/` at line 1895), so focus would refuse it a second time. Asserted
negatively by leg 5 so a future author cannot reintroduce it.

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
# Single pipe only — no intermediate tail/awk/sed stages between capture and grep
# (T-2090): `echo "$out" | tail -3 | grep -q PAT` re-introduces the SIGPIPE risk
# the capture step closed off — the middle stage is what `grep -q` slams its
# stdin on. grep scans the whole captured string anyway, so the tail-3 was
# cosmetic. Drop it: `echo "$out" | grep -q PAT`.
#
# AND ONLY WHILE THE CAPTURE IS SMALL (T-2743). The two hints above are correct
# for the captures they were written about, and both invert above the pipe
# buffer. `echo "$out" | grep -q PAT` is NOT SIGPIPE-free — it is SIGPIPE-free
# only while "$out" fits in the 65536-byte pipe buffer. Above that, with an
# early match: echo blocks on the full pipe, grep -q exits, echo takes SIGPIPE,
# pipeline exits 141 under pipefail — the exact failure L-387 exists to prevent.
# Measured: a Watchtower page is 146,366 bytes, rc=141 on 3/3 runs, deterministic
# not racy. Any line that curls a rendered page is exposed (routes run 50-200KB).
# For anything that might be large, redirect to a file:
#     cmd -o /tmp/.out && grep -q "PATTERN" /tmp/.out
#     curl -sf "$(bin/fw watchtower url)/page" -o /tmp/.out && grep -q "PAT" /tmp/.out
# This is the better default even when size is not a concern: `&&` keeps the
# PRODUCING command's exit code in the verdict, where `out=$(cmd)` discards it —
# the T-2738 problem one layer down. A 404 from curl fails the line instead of
# silently producing an empty capture for grep to not-match.
#
# REHEARSING A LINE BY HAND DOES NOT REHEARSE THE GATE (T-2743). Your interactive
# shell has no `set -eo pipefail`. The line above returned 0 when run by hand and
# 141 under P-011, from the same directory, the same second. To rehearse for real:
#     bash -c 'set -eo pipefail; <your verification line>'
#
# BUT NOT for a test runner (T-2738): the capture above discards the command's
# exit code, and `set -e` is suppressed inside the `if` condition the gate runs
# each line in — so in `cmd1; cmd2` only cmd2 is the verdict. For pytest/bats
# that exit code WAS the verdict, and the pass marker you grep instead survives
# a partial failure: a suite printing "3 failed, 9 passed" satisfies
# `grep -q "9 passed"`. Generalising to `grep -qE "[0-9]+ passed"` matches the
# same output. Either keep the exit code:
#     python3 -m pytest <file> -q > /tmp/.out 2>&1 && grep -q passed /tmp/.out
# or add the guard the exit code used to supply:
#     out=$(python3 -m pytest <file> -q 2>&1); echo "$out" | grep -q passed && ! echo "$out" | grep -q failed
#     out=$(bats <file> 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# The close gate refuses the unguarded form. Bypass: FW_ALLOW_UNJUDGED_TEST_RUN=1.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

# The fix's own suite. `^ok 6` is the anti-vacuity leg specifically — a suite that
# passes 1-5 while 6 silently skips would certify a hook with no fix in it, which is
# exactly how T-2874's expiring git-ref teeth check went inert while reporting ok.
# File-redirect rather than $(capture) | grep (T-2743): `&&` keeps the PRODUCING
# command's exit code in the verdict, where out=$(cmd) discards it — so a bats run that
# dies before emitting TAP fails the line instead of yielding an empty capture for grep
# to not-match. Also immune to the 64KB pipe-buffer SIGPIPE inversion regardless of how
# much these suites grow.
bats tests/unit/focus_drift_remedy_scope.bats > /tmp/.t2875a 2>&1 && grep -q '^ok 6' /tmp/.t2875a && ! grep -q '^not ok' /tmp/.t2875a && ! grep -q '# skip' /tmp/.t2875a
# T-2874's suite must stay green — this edits the consumer of the same predicate.
bats tests/unit/focus_active_scope.bats > /tmp/.t2875b 2>&1 && grep -q '^ok 7' /tmp/.t2875b && ! grep -q '^not ok' /tmp/.t2875b
# The rest of the hook's own coverage, unbroken.
bats tests/unit/check_active_task_fp_fix.bats tests/unit/check_active_task_switch_focus.bats tests/unit/check_active_task_cwd_resolution.bats > /tmp/.t2875c 2>&1 && ! grep -q '^not ok' /tmp/.t2875c
bash -n agents/context/check-active-task.sh
# LIVE integration, not a fixture: drives the real hook against this repo's real task tree
# with a really-completed target (T-2874), asserting the dead remedy is absent and a working
# one is present. rc=2 is the EXPECTED outcome here, so the exit code cannot carry the
# verdict and the assertion is made on the message text — which is where the defect lived.
# The `|| true` is REQUIRED, not sloppiness: the gate runs each line under `set -eo pipefail`
# and the hook exits 2 by design, so without it `set -e` aborts the line at the pipeline and
# the greps never run. This line passed by hand and failed under the gate until the rehearsal
# (`bash -c 'set -eo pipefail; <line>'`) surfaced it — T-2743, and a reminder that an
# interactive shell does not rehearse P-011.
printf '{"tool_name":"Bash","tool_input":{"command":"git commit -m \\"T-2874: x\\""}}' | CLAUDECODE=1 bash agents/context/check-active-task.sh > /tmp/.t2875d 2>&1 || true; grep -q "T-2874 is not active" /tmp/.t2875d && grep -q "FW_SWITCH_FOCUS=1" /tmp/.t2875d && ! grep -q "context focus T-2874" /tmp/.t2875d

## RCA

**Symptom:** the focus-drift gate blocks an action and offers, as its first remedy,
`fw context focus <TARGET>` — a command the framework refuses whenever TARGET is completed.
Following the instruction produces a second refusal.

**Root cause:** the remedy list was static text. It named a mechanism without consulting
whether that mechanism was applicable to the specific target it was interpolating.

**Why structurally allowed:** the two sides moved independently. T-1730 wrote the message
when `fw context focus` accepted any id, so remedy #1 was universally applicable and hard-coding
it was correct. T-2874 narrowed focus to active-only — a change to the *reader* of the message's
advice — and nothing connected the two. There is no gate asserting that commands quoted inside
block messages are executable in the state that produced the block, so the message kept claiming
a capability the system had dropped. Same shape as L-399/T-1890, where a hook advertised
`--switch-focus` to four downstream consumers that rejected it: producer and consumer of a
contract shipped on one side only.

Worth stating plainly: before T-2874 this was *worse* and invisible. Remedy #1 exited 0 and
then deadlocked every later gated call on "Task X is not active" — the writable-but-unusable
state. T-2874 converted a silent failure into a loud one, which is what made it fixable.

**Prevention:** the completed-target branch names only mechanisms verified to work, and the
candidate replacement remedy (`--status started-work` as a reopen) was checked against
`update-task.sh` before being offered, found non-functional, and is now asserted *negatively*
by `focus_drift_remedy_scope.bats` leg 5 — so reintroducing it goes red. Leg 6 mutates live
source rather than reading a git ref, so the teeth cannot expire on the next commit.

Residual, not fixed here: nothing generically verifies that commands embedded in block-message
text are runnable. This fix hardens one message. A static scan for "block message quotes a fw
command" cross-checked against the gate conditions would generalise it — filed as OBS rather
than built, since one instance is not yet a pattern.

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

### 2026-08-08T16:57:38Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2875-focus-drift-block-message-must-not-recom.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-07f3a83e
- **Timestamp:** 2026-08-08T17:06:38Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **mock-only-integration** (partial, heuristic) @ AC vs Verification cross-check
     - evidence: `bats tests/unit/focus_drift_remedy_scope.bats > /tmp/.t2875a 2>&1 && grep -q '^ok 6' /tmp/.t2875a && ! grep -q '^not ok' /tmp/.t2875a && ! grep -q '# skip' /tmp/.t2875a`

### 2026-08-08T17:06:21Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
