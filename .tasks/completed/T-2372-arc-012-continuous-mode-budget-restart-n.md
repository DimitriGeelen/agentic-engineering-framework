---
id: T-2372
name: "arc-012 continuous-mode budget-restart never fires: nothing terminates claude
  at critical so wrapper restart-on-exit never reached"
description: >
  arc-012 continuous-mode budget-restart never fires: nothing terminates claude at
  critical so wrapper restart-on-exit never reached

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: [T-2363, T-2364, T-2367, T-179, T-186]
arc_id: continuous-run
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
created: 2026-06-13T14:20:42Z
last_update: '2026-08-16T22:25:03Z'
date_finished: 2026-06-13T14:30:06Z
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
  - ts: '2026-08-16T22:25:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      Discard fidelity: 0
      Loop closure (conditional): 0
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 1
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: Discard fidelity=0 (no-signal); Loop closure (conditional)=0 
      (no-signal); D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=1 
      (body:episodic-only); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=1 (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-2372: arc-012 continuous-mode budget-restart never fires: nothing terminates claude at critical so wrapper restart-on-exit never reached

## Context

Surfaced by an operator live-fire of arc-012 continuous mode (2026-06-13): lowering the
context window to force budget-critical did **not** auto-restart the session. Investigation
(read of `agents/context/checkpoint.sh` + `bin/claude-fw`) found the loop has a missing link:
the budget-critical → restart chain writes the signal but never *terminates* the running
`claude`, and the wrapper only acts on the signal **after** `claude` exits.

The compaction path (`/compact` → post-compact-resume → inject) works and fires in prod
(confirmed: `current_iteration` advances on `/compact`). The **budget-critical path** is the
broken one. This is the antifragile payoff of the T-2369 live-fire runbook — the test found
the defect.

Fix approach (operator-steered toward TermLink): add a **terminator** — a concurrent watch
that, when `.restart-requested` appears fresh while `claude` is running, ends the session so
the wrapper's existing restart-on-exit logic fires. In TermLink mode the terminator is
`termlink pty inject <session>` of claude's quit; in plain mode it is a background poller that
signals the claude PID. Regression-tested via a TermLink stub harness (no real-claude tokens
burned to prove the wrapper logic).

## Acceptance Criteria

> **Scope (this task = diagnose + reproduce + design):** the actual `bin/claude-fw`
> terminator patch is deferred to a focused follow-up — `bin/claude-fw` is the session
> launcher (highest blast-radius file; a bug bricks startup), the correct terminator has
> real subtlety (start-time signal guard, TTY-safe process targeting, two modes), and it
> needs real-claude E2E for the `/exit`-vs-SIGTERM timing. Rushing it at end-of-long-session
> = D-058 ship-before-verified. Design is in `## Decisions`; follow-up specified in `## Recommendation`.

### Agent
- [x] **RCA captured** (symptom / root cause / why structurally allowed / prevention) in `## RCA`,
      grounded in reads of `agents/context/checkpoint.sh` + `bin/claude-fw`.
- [x] **Reproduction harness committed:** `tests/integration/claude_fw_restart_terminator.bats`
      drives the REAL `bin/claude-fw` with a stub `claude` (no real-claude tokens). Two cases:
      BUG (alive stub → no restart, signal unconsumed) + CONTROL (exiting stub → restarts to
      MAX_RESTARTS). Deterministic, green (2/2). Pins the defect and will validate the fix.
- [x] **Fix design documented** in `## Decisions`: the terminator (background watcher kills the
      foreground claude on fresh signal; TermLink-mode inject-quit), with the edge cases the
      patch must handle (start-time guard so a restart doesn't instantly re-kill the resumed
      session; pkill targeting; TTY safety; fail-safe = no-op).
- [x] Reviewer PASS: `bin/fw reviewer T-2372 2>&1 | grep -qE "Overall:.*(PASS|CONCERN)"` and not FAIL.

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

(none — this task is diagnosis + reproduction + design, all agent-verifiable. The
real-claude E2E [REVIEW] AC belongs to the follow-up fix task; see `## Recommendation`.)

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
# stdin on. `echo "$out"` is small and immediate; grep scans the whole captured
# string anyway, so the tail-3 was cosmetic. Drop it: `echo "$out" | grep -q PAT`.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

bash -n bin/claude-fw
bats tests/integration/claude_fw_restart_terminator.bats
out=$(bin/fw reviewer T-2372 2>&1); echo "$out" | grep -qE "Overall:.*(PASS|CONCERN)" && ! echo "$out" | grep -q "Overall:.*FAIL"

## RCA

**Symptom:** Operator lowered the context window to force budget-critical in a `claude-fw`
session (the T-2369 live-fire); the session did **not** auto-restart. The continuous-mode
headline mechanic ("agent crosses the budget threshold without operator relay") did not fire.

**Root cause:** The budget-critical → restart chain is missing a *terminator*. The chain is:
checkpoint.sh (at critical) commits a handover + writes `.context/working/.restart-requested`
→ `claude-fw` restarts via `claude -c`. But `claude-fw`'s main loop (`bin/claude-fw:122-201`)
runs `command claude` and **only checks the signal after claude exits** (`:146-147` then
`:160`). Nothing terminates the *running* claude at critical — checkpoint.sh (PostToolUse hook)
can't exit its parent; budget-gate (PreToolUse) only *blocks* tools, it doesn't end the
session. So claude stays alive (idle/blocked), the wrapper blocks on it, and the restart
branch is never reached. Reproduced deterministically:
`tests/integration/claude_fw_restart_terminator.bats` — alive-stub → no restart (signal
unconsumed); exiting-stub → restarts to MAX_RESTARTS. The restart-on-exit logic is correct;
the gap is purely the missing terminator.

**Why structurally allowed:** the loop was built and unit-tested per-leg (T-2363 signal-write,
T-2364/T-2365 resume-inject, T-2368 integration of the resume side) but the *budget-critical →
session-end* junction was only ever exercised by the **compaction** path (`/compact` ends the
context itself, so the wrapper sees an exit). The budget path's terminator was assumed to exist
("wrapper will auto-restart on exit") but no component actually produces the exit. D-058
"shipped before substrate-verified" — the seam between checkpoint's signal and the wrapper's
exit-check was never E2E-fired until this live-fire.

**Prevention:** (1) this committed reproduction harness pins the defect and will validate the
fix; (2) the fix adds the terminator; (3) the T-2369 live-fire runbook (the test that surfaced
it) becomes the standing E2E. Prevention is distinct from the fix: the harness ensures a future
refactor can't silently re-open the gap.

## Evolution

### 2026-06-13 — live-fire surfaced a real defect; task re-scoped diagnose-only
- **What changed:** Filed as "fix the restart"; investigation showed the fix touches the
  session launcher (`bin/claude-fw`, highest blast-radius) and needs real-claude E2E for the
  quit-timing. The durable, low-risk deliverable is diagnosis + reproduction + design.
- **Plan impact:** The terminator patch + E2E are deferred to a focused follow-up (design
  ready in `## Decisions`). This task ships the RCA + the regression harness.
- **Triggered:** Follow-up fix task recommended in `## Recommendation` (not auto-filed to
  avoid a half-scoped task at session end).

## Decisions

### 2026-06-13 — terminator fix design (for the follow-up patch)
- **Chose:** A background *terminator watcher* the wrapper launches alongside claude. While
  claude runs, it polls `.restart-requested`; when fresh, it ends the claude session so the
  existing restart-on-exit branch fires.
- **Plain mode:** claude must stay foreground (TTY). Pre-launch a sibling watcher
  `( ... ) & WATCHER=$!`; on fresh signal it `kill -TERM`s the wrapper's claude child
  (targeted via the wrapper PID, not a broad pkill). After `command claude` returns, kill the
  watcher. SIGTERM is acceptable — the handover is already committed before the signal is written.
- **TermLink mode:** claude lives in the PTY (not a wrapper child); the existing poll loop
  (`:130-145`) gains a signal check → `termlink pty inject "$SESSION" "/exit" --enter` (then
  fall through to the restart branch). This is the path the operator steered toward.
- **Edge cases the patch MUST handle:** (a) **start-time guard** — the wrapper `rm`s the signal
  before each restart (`:178`), but a stale-but-fresh signal at first launch would make the
  watcher instantly kill the new claude; record wrapper-start epoch and only act on signals
  newer than it. (b) **fail-safe** — any watcher error must degrade to today's behaviour (no
  restart), never a spurious kill. (c) **poll interval** vs handover duration (handover can take
  ~tens of seconds; poll ≤10s so the signal isn't missed but claude isn't killed mid-handover).
- **Why not:** killing claude from checkpoint.sh (PostToolUse hook) directly — a hook SIGTERMing
  its parent Claude Code process is fragile and could lose state before the handover completes.
  The watcher fires *after* checkpoint has committed the handover + written the signal.

## Recommendation

**Recommendation:** GO on this diagnosis; file the terminator patch as the next focused task.

**Rationale:** The defect is fully diagnosed with a deterministic reproduction (2/2 green) and a
ready fix design. The patch itself touches the session launcher (high blast-radius) and needs
real-claude E2E for quit-timing, so it warrants a focused session, not an end-of-long-session
rush (D-058). Until the patch lands, the **compaction path works** — `/compact` fires the loop
(confirmed: `current_iteration` advances), so continuous mode is usable via manual compaction;
only the *budget-critical auto* trigger is pending.

**Evidence:**
- `tests/integration/claude_fw_restart_terminator.bats` 2/2 (BUG + CONTROL).
- Root cause traced to `bin/claude-fw:122-201` (restart only on claude exit) + checkpoint.sh
  writing the signal without terminating claude.
- Control proves restart-on-exit works → defect isolated to the missing terminator.

**Follow-up task to file:** "arc-012: add budget-critical terminator to claude-fw (watcher kills
foreground claude / TermLink inject-quit on fresh signal)" — design + edge cases in `## Decisions`;
real-claude E2E (`FW_CONTEXT_WINDOW=100000 claude-fw --termlink`) as the `[REVIEW]` Human AC.

## Decision

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

### 2026-06-13T14:20:42Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/arc012-continuous-run-s4s5/.tasks/active/T-2372-arc-012-continuous-mode-budget-restart-n.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-5a70be04
- **Timestamp:** 2026-06-13T14:30:29Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-13T14:30:06Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
