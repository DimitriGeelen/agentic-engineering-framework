---
id: T-2914
name: "Autonomous resolver loop re-dispatches non-advancing tasks indefinitely — 127x,
  94x, 57x with zero outcomes"
description: >
  Autonomous resolver loop re-dispatches non-advancing tasks indefinitely — 127x,
  94x, 57x with zero outcomes

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
created: 2026-08-10T20:43:43Z
last_update: '2026-08-10T20:45:12Z'
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
  - ts: '2026-08-10T20:45:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 7
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-10T20:45:12Z'
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

# T-2914: Autonomous resolver loop re-dispatches non-advancing tasks indefinitely — 127x, 94x, 57x with zero outcomes

## Context

Found while investigating what I first mis-diagnosed as "a second operator session in
this working tree" (OBS-211). **It is not another operator.** It is this framework's own
autonomous dispatch loop — and the investigation turned up more than the symptom.

### What is actually running

`resolver-loop.timer` — a **systemd** timer, `enabled` and `active`, firing every 30 min:

```
ExecStart=/opt/999-.../bin/fw resolver loop --dispatch --max 1 --cooldown-min 30
WorkingDirectory=/opt/999-Agentic-Engineering-Framework
```

Deliberate and operator-installed (T-2494 / T-2495 moved the loop off host cron precisely
so it would need "NO crontab, NO .context cron-registry entry"). **Autonomous dispatch
being live is not the defect.** Three other things are.

### Defect 1 — non-convergence: the same task is dispatched indefinitely

`.context/dispatches.jsonl` holds **1312** records.

| task | dispatches | window |
|---|---|---|
| T-2420 | **127x** | 2026-06-26 → 07-05 (9 days) |
| T-2353 | **94x** | 2026-06-26 → 07-05 |
| T-2862 | **57x** | 2026-08-08 → 08-10 (13 today) |
| T-2389 | 47x | 2026-06-29 → 07-05 |

T-2862 is the live case and the cleanest evidence: **57 dispatches; `last_update:
2026-08-08`; `status: started-work` — unmoved for two days; and `grep -c T-2862
dispatch-outcomes.jsonl` = 0.** Fifty-seven workers spawned, zero outcomes, zero
advancement.

`--cooldown-min 30` against a 30-minute timer cannot bound this — the cooldown expires as
the next tick fires. Nothing asks "has this task advanced since the last N dispatches?",
so a task no worker can finish is retried indefinitely.

Same shape as T-2912 (`fw upgrade` reporting a fix it never performs), one layer up:
**an operation whose repetition is indistinguishable from progress.** A loop that
dispatches looks busy; only the outcome column shows it is not.

### Defect 2 — the "not focused" eligibility test is point-in-time

The service comment states the filter: *agent-owned, scoped, non-inception, not
in-flight, **not focused**, not in cooldown.* Correct as written, and it still produced
this today:

| time | event |
|---|---|
| 19:34 | I create T-2909; focus moves to it |
| 19:55 | I create T-2910; focus moves — **T-2908 now unfocused** |
| **19:56:55** | loop dispatches a worker onto T-2908, which I had opened and was working |
| 20:02 | I create T-2911; focus moves — T-2910 now unfocused |
| **20:26:59** | loop dispatches a worker onto T-2910 while I am mid-build on its script |

"Not focused" encodes the assumption that focus marks the one task anyone is working. In
a session that opens several tasks and moves focus between them — the normal shape of
this framework's own workflow — **every task just opened becomes eligible the moment
focus moves to the next.** The filter is not wrong; its premise is.

Consequences, all observed today: the T-2908 worker created **T-2913** and set focus to
it mid-session; it committed `0719801cc T-2908: register fabric cards` under my task id;
it ran `fw vendor self` (VERSION 1.6.14 → 1.6.16) between my vendor and my push, so the
T-2240 gate re-fired and my push needed three rounds; it edited
`agents/context/check-rail-mcp-label.sh` at 22:14:35. Focus was clobbered repeatedly, so
the T-1730 drift gate fired on **correct** actions and invited Tier-2 bypasses to work
around a gate that was right about a state that was wrong.

### Defect 3 — dispatch provenance is null, which is why this needed an investigation

```
{'dispatch_id': '5cf52e59…', 'task_id': 'T-2908', 'ts': '2026-08-10T19:56:55Z',
 'dispatched_by': None, 'origin': None, 'session': None, 'worker': None}
```

Every provenance field is null; the record cannot say what dispatched it. I found the
timer by elimination — root crontab, `/etc/cron.d`, then `systemctl list-timers` — after
`.context/cron-registry.yaml` truthfully reported the *cron* loop `paused` and `fw doctor`
truthfully reported "Cron registry in sync".

Both statements are correct, and together they read as *no autonomous dispatch is
running*, which was false. That is a **fourth drift class** beyond the three CLAUDE.md
documents (registry→generated, generated→deployed, deployed→executable): a scheduler the
registry has no entry for at all, by design, and which therefore no surface reports.

## Scope

Bound the retry behaviour and make provenance non-null. The filter redesign (defect 2) is
a **separate** decision — a policy question about what "someone is working on this" means,
not a bug fix — and must not be smuggled in here.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [ ] A task that has not advanced across N consecutive dispatches stops being
      re-dispatched and is surfaced instead — "advanced" defined against something a
      worker cannot trivially satisfy (status change, AC tick, or a commit referencing
      it), not merely "a dispatch record was written"
- [ ] Proven against the live evidence: T-2862 (57 dispatches, unchanged since
      2026-08-08, 0 outcomes) is excluded by the new rule, and the rule is shown RED
      against current code first — current behaviour is that it dispatches, so a test
      written after the fix would pass against the bug
- [ ] `--cooldown-min` is reconciled with the timer interval, or removed. A cooldown
      equal to the fire interval cannot suppress anything across ticks and reads as a
      bound that is not one
- [ ] Every dispatch record carries non-null provenance — at minimum what invoked it
      (systemd unit / cron id / interactive session) — so "what dispatched this?" is
      answerable from the record instead of by elimination across three schedulers
- [ ] A single surface reports whether autonomous dispatch is live, covering the systemd
      path. Today `fw doctor` says "Cron registry in sync" and the registry says the loop
      is `paused`; both are true, and together they imply nothing is dispatching while a
      systemd timer dispatches every 30 minutes
- [ ] Zero-outcome dispatches are visible: 57 dispatches of T-2862 produced 0 rows in
      `dispatch-outcomes.jsonl` and no surface reported that

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

### 2026-08-10T20:43:43Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2914-autonomous-resolver-loop-re-dispatches-n.md
- **Context:** Initial task creation
