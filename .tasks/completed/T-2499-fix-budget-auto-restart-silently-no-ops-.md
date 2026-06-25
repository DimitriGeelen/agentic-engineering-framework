---
id: T-2499
name: "fix budget auto-restart silently no-ops under plain claude not claude-fw — 300K session overran to 350K with no restart"
description: >
  fix budget auto-restart silently no-ops under plain claude not claude-fw — 300K session overran to 350K with no restart

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
created: 2026-06-25T08:32:09Z
last_update: 2026-06-25T09:14:25Z
date_finished: null
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
---

# T-2499: fix budget auto-restart silently no-ops under plain claude not claude-fw — 300K session overran to 350K with no restart

## Context

Operator observed a session run 300K→350K with no auto-restart/handover firing.
The designed mechanism is the **arc-012 continuous-run loop** (budget-critical →
auto-handover → `.restart-requested` → claude-fw restart → directive re-injection) —
an explicitly-built, shipped feature, NOT a missing one. Root cause (investigated,
see RCA): the loop's restart signal is consumed only by the `claude-fw` wrapper, but
the session ran under **plain `claude`** — so budget-gate wrote the critical signal
and nothing consumed it (a stale Jun-24 signal at 294K is the proof). This task
ships the structural prevention: make the unsupervised state LOUD so a plain-`claude`
launch can never silently disarm the loop again.

## Acceptance Criteria

### Agent
- [x] RCA section documents the full chain and names the primary root cause (signal written under plain `claude`, no `claude-fw` supervisor to consume it) + the D-027 "no auto-compact" clarification + the PreToolUse/PostToolUse text-only blind spot.
- [x] The framework can detect whether the current session is supervised by `claude-fw` (via a wrapper-set env var or supervisor sentinel) — pinned by a test. `claude-fw` exports `FW_CLAUDE_FW_SUPERVISED=1` (`bin/claude-fw`), inherited by `claude` + every hook subprocess. Pinned by `tests/integration/t2499_supervision_notice.bats`.
- [x] When budget reaches WARN (225K) in an UNSUPERVISED session, the budget hook emits a clear one-line notice that auto-restart will NOT fire and states the two recourses (relaunch via `claude-fw`, or `/compact` manually) — so the silent failure becomes loud at the point it first matters. `_supervision_notice()` in `agents/context/budget-gate.sh` fires at warn/urgent (every call) + critical-block.
- [x] `fw doctor` surfaces the unsupervised-but-high-budget state (or confirms supervision) so it's visible outside the hook path. New "Session supervision" check in `bin/fw do_doctor` — WARN when `CLAUDECODE=1` and unsupervised (with current budget tokens), OK when supervised, SKIP outside a Claude Code session.
- [x] Regression test pins: unsupervised + WARN → notice present; supervised → notice absent. `tests/integration/t2499_supervision_notice.bats` — 9 tests (hook notice across warn/urgent/critical × supervised/unsupervised + 3 doctor-line cases), all green.

### Human

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
# stdin on. `echo "$out"` is small and immediate; grep scans the whole captured
# string anyway, so the tail-3 was cosmetic. Drop it: `echo "$out" | grep -q PAT`.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.
bash -n agents/context/budget-gate.sh
bash -n bin/claude-fw
bash -n bin/fw
bats tests/integration/t2499_supervision_notice.bats

## RCA

**Symptom:** A session grew 300K→350K with no auto-handover/restart/compaction.
The operator expected "at ~300K: compact, resume, start again" to fire automatically.

**Root cause (two distinct gaps):**

1. **Unsupervised session — the signal is written into the void.** The auto-restart
   chain is: budget-gate (PreToolUse, `agents/context/budget-gate.sh:87-92,200,363`)
   detects CRITICAL at 285K → writes `.context/working/.restart-requested` → the
   `claude-fw` wrapper (`bin/claude-fw:285`), on claude's exit (or via its terminator
   watcher SIGTERM, `:121-152`), consumes a *fresh* (<5min) signal and relaunches.
   **Consumption REQUIRES the session to run under `claude-fw`.** Verified live: active
   sessions run plain `/root/.local/bin/claude --resume`; the lone `claude-fw` (PID
   178797) is an idle orphan. The smoking gun is a stale `.restart-requested` from
   2026-06-24 12:50 (`reason:"critical_budget_gate_block", tokens:294783`): budget-gate
   DID detect critical and wrote the signal, but with no supervising wrapper nobody
   consumed it and the session sailed past to 350K. Under plain `claude`, the entire
   auto-recovery is inert.

   The designed loop is **arc-012 continuous-run** — the explicit, shipped
   auto-compact-and-continue mechanism: budget-critical → auto-handover →
   `.restart-requested` → claude-fw terminator restart → resume-side directive
   re-injection (`post-compact-resume.sh`) under the bounded-autonomy ceiling
   (`.continuous-mode.yaml`). It has demoed working end-to-end (the Jun-24 signal
   quotes its own headline-mechanic). NOTE: D-027 disables Claude Code's *native*
   silent auto-compaction (which destroys working memory); arc-012 is the framework's
   deliberate *replacement* for it. The two are not in conflict — conflating "native
   auto-compact is off" with "no auto-continue exists" was an analysis error in the
   first draft of this RCA (corrected). The loop is correct; the failure is solely
   that it ran unsupervised (gap 1).

   OPEN (do NOT assert without testing): whether the `claude -c` restart
   (`bin/claude-fw:338-339`) sheds enough context on its own or relies on
   compaction-on-resume. **Evidence gathered (2026-06-25, claude-code-guide agent vs
   official CC docs):** `claude --continue` reopens the session under the same session
   ID and *appends* new messages to the existing conversation — i.e. it reloads the
   FULL prior transcript, with **no automatic compaction triggered by the resume
   itself**. `/compact` is manual; native auto-compaction is a separate background
   mechanism (and is disabled here by D-027). The SessionStart `source` value for a
   `claude -c` continuation is not documented (claude-fw assumes "startup",
   `bin/claude-fw:326-331`).

   **Implication (flagged, NOT asserted as settled):** if native auto-compact is off
   (D-027) and `claude -c` reloads full history, the supervised autonomous restart
   would resume at ~the same token weight and re-hit critical — a thrash bounded by
   `MAX_RESTARTS=5`. This *appears* to conflict with the operator's working arc-012
   demo, which is precisely the signal to re-check rather than assert: the demo may
   have run with native auto-compact enabled in that env, or there is a compaction
   step in the chain not yet traced. **Authoritative resolution is one empirical
   check** (guide agent's own recommendation): let a supervised session hit critical,
   observe the `claude -c` restart, and read `/context` on the resumed session — if the
   token count matches the prior end-state, the restart does NOT shed context and the
   restart vehicle needs revisiting (separate task); if it's lighter, the loop recovers
   as designed. This is an OPEN DECISION for the operator, deliberately NOT built under
   T-2499 (whose verified scope is the unsupervised-loudness fix). The earlier "would
   thrash" assertion remains retracted — the evidence above raises it as a *hypothesis
   with documentation support*, not a verified finding.

**Why structurally allowed:** the auto-recovery hard-depends on an opt-in wrapper
(`claude-fw`) with zero signal that it's absent. Launch plain `claude` and every
budget hook still "works" (writes signals, prints warnings) while the consumer that
makes them matter simply isn't there — a silent producer/consumer split (L-399 class).
There is no SessionStart check, no doctor check, no warning that says "you are
unsupervised; auto-restart cannot fire." Additionally both budget hooks are
PreToolUse/PostToolUse — a 300K→350K stretch of pure reasoning/text with no tool
calls bypasses them entirely (secondary blind spot).

**Prevention (this task, the part that is correct under any direction):** make the
unsupervised state LOUD — `claude-fw` sets a supervisor marker; budget-gate emits a
one-line "auto-restart will NOT fire (unsupervised) — relaunch via claude-fw or
/compact manually" at WARN (225K), and `fw doctor` surfaces it. The deeper question —
whether the auto path should compact / relaunch-fresh-from-handover (truly shedding
context) vs the operator simply always running `claude-fw` — is an OPEN DECISION
flagged to the operator (see chat handoff), not built here.

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

### 2026-06-25T08:32:09Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/inception-gov-payload-mediation/.tasks/active/T-2499-fix-budget-auto-restart-silently-no-ops-.md
- **Context:** Initial task creation
