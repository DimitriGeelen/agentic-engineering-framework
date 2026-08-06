---
id: T-2830
name: "fw work-on --switch-focus fails silently (RC=1, zero output)"
description: >
  `fw work-on "name" --type build --switch-focus` exits 1 printing nothing at all.
  Two composing defects: create-task.sh never got the T-1890 --switch-focus no-op
  branch (parity gap on the create leg), and bin/fw's `set -euo pipefail` kills the
  script at the command-substitution assignment that captured the error message,
  before the line that would have printed it.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [bug, governance]
components: [bin/fw, agents/task-create/create-task.sh]
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
created: 2026-08-06T15:58:14Z
last_update: '2026-08-06T16:00:14Z'
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
  - ts: '2026-08-06T16:00:09Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 2
      effort: 7
    rationale: blast_radius=3 (no-signal); tier=2 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-06T16:00:14Z'
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

# T-2830: fw work-on --switch-focus fails silently (RC=1, zero output)

## Context

Hit live while filing the OBS-179 task. `bin/fw work-on "<name>" --type build --switch-focus`
returned RC=1 and wrote **zero bytes to stdout and stderr**. No task created, no error.

Two defects compose:

1. **Parity gap (L-399 / T-1890).** `--switch-focus` is the bypass contract for the
   T-1730 focus-drift gate. T-1890 shipped the silent no-op branch into
   `update-task.sh` and `lib/{learning,pattern,decision}.sh` — but **not** into
   `agents/task-create/create-task.sh`, which `fw work-on` shells to on the
   create path. Its arg loop rejects the unknown flag.
2. **Silent swallow.** `bin/fw` runs under `set -euo pipefail` (line 12). The create
   path is `wo_output=$(create-task.sh ... 2>&1)` followed by `echo "$wo_output"`.
   When the assignment's command substitution exits non-zero, `set -e` terminates
   `fw` **at the assignment** — so the captured message is discarded and never
   reaches the terminal. The error is captured and then thrown away by the capture.

Defect 2 is what makes defect 1 unfindable: a plain "Unknown option: --switch-focus"
would have been a 10-second fix. This is the same shape as T-1890's origin, where the
agent's workaround (direct-invoke `bash agents/task-create/update-task.sh`) escaped
the hook regex — an incomplete contract pushes the caller onto an ungoverned path.

## Acceptance Criteria

### Agent
- [ ] `create-task.sh` accepts `--switch-focus` as a silent no-op (consumes the flag,
      does not treat it as the task name, does not error) — per L-399 step 2.
- [ ] `bin/fw work-on <name> --type build --switch-focus` creates the task and exits 0.
- [ ] A downstream `create-task.sh` failure under `fw work-on` reaches the terminal
      instead of being swallowed — the captured output is printed and the exit code
      propagated, rather than `set -e` aborting at the assignment.
- [ ] `tests/unit/work_on_switch_focus.bats` pins all three, including a
      **negative control that asserts the silent-swallow is gone** (a genuinely
      failing create still prints something and still exits non-zero).
- [ ] Mutation-checked: reverting each leg independently turns the corresponding
      test red, and the result recorded in ## Decisions.

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

bash -n bin/fw
bash -n agents/task-create/create-task.sh
grep -q -- '--switch-focus) shift ;;' agents/task-create/create-task.sh
out=$(bats tests/unit/work_on_switch_focus.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
out=$(bats tests/unit/create_task_inception_recommendation_gate.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'

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

**Symptom:** `bin/fw work-on "<name>" --type build --switch-focus` → RC=1, **zero bytes
on stdout and stderr**, no task created. Discovered by hitting it, not by a test.

**Root cause — two defects that only fail together this badly:**

1. `agents/task-create/create-task.sh` had no `--switch-focus` branch, so its arg loop
   fell through to `*) echo "Unknown option: $1"; exit 1`. T-1890 shipped that branch to
   `update-task.sh` and `agents/context/lib/{learning,pattern,decision}.sh` — the three
   consumers the focus-drift hook *gates* — but `create-task.sh` is reachable from the
   block message's open-ended phrasing ("Append `--switch-focus` to a fw command") while
   not being one of the gated patterns, so it was outside the parity sweep's frame.
2. `bin/fw` runs `set -euo pipefail`. The create path was
   `wo_output=$(create-task.sh … 2>&1)` then `echo "$wo_output"`. A non-zero substitution
   makes `set -e` terminate **at the assignment**, so the message that had just been
   captured into `wo_output` was discarded before the echo could run.

**Why structurally allowed:** the `2>&1` capture is written to be *helpful* — it collects
stderr so it can be replayed to the user. Under `set -e` that same capture becomes the
thing that guarantees the user sees nothing: the error is redirected away from the
terminal into a variable that is then never read. The more carefully the output is
captured, the more completely it vanishes. Nothing in the codebase distinguishes
"capture so I can print it" from "capture so I can parse it", and only the former is
broken by `set -e`.

This is also why the trivial defect (1) survived: it produces a perfectly clear
diagnostic that no one has ever been able to read.

**Prevention:** `tests/unit/work_on_switch_focus.bats` test 3 asserts a *failing* create
under `fw work-on` still reaches the terminal — non-empty output plus non-zero exit —
independent of which flag is rejected. That is the general guard; the `--switch-focus`
tests only pin this instance. Mutation-checked in both directions (see ## Decisions).

## Evolution

### 2026-08-06 — found while filing a different task
- **What changed:** this task did not exist at session start. It was hit while running
  `fw work-on` to file the OBS-179 task, and investigated instead of retried — the
  silent RC=1 was the signal. CLAUDE.md ranks framework-tooling errors above the task in
  hand, which is what made it correct to stop and fix this first.
- **Plan impact:** OBS-179's task (T-2831) was filed by the *fixed* command, so the fix
  is exercised end-to-end by the thing that motivated it.
- **Triggered:** T-2831 (OBS-179, with a falsified premise — see that task's Context).

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

### 2026-08-06 — fix both legs, not just the flag

- **Chose:** ship the `--switch-focus` no-op *and* the non-swallowing guard in one
  change, with the swallow test written to be flag-agnostic.
- **Why:** T-1890's own authoring rule — "if you can't ship end-to-end in one commit,
  the contract is incomplete". Shipping only the flag would have left the next
  downstream rejection equally invisible, and there is no reason to think
  `--switch-focus` is the last flag anyone will append to a fw command.
- **Rejected:** dropping `set -e` for the create path (too broad — `set -e` is load-
  bearing across 6000 lines of `bin/fw`); and `wo_output=$(…) || true` (keeps the exit
  code from propagating, converting a silent failure into a *false success*, which is
  strictly worse).

### 2026-08-06 — mutation check, both directions

Each leg reverted independently against the live suite, then restored and md5-verified:

| Mutation | t1 parity | t2 e2e | t3 swallow | t4 no-half-task |
|---|---|---|---|---|
| A — remove `--switch-focus` branch | **red** | **red** | ok | ok |
| B — restore capture-then-echo | ok | ok | **red** | ok |
| (none — both fixes in place) | ok | ok | ok | ok |

Clean discrimination: neither leg's test passes on the other leg's absence, so neither
test is riding on the other's fix. Files restored to `dda9da9c…` (bin/fw) and
`68e87b4d…` (create-task.sh), confirmed by md5 after each revert.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-08-06T15:58:14Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2830-probe-task-name.md
- **Context:** Initial task creation
