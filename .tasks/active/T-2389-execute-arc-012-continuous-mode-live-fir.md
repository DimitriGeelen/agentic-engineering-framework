---
id: T-2389
name: "Execute arc-012 continuous-mode live-fire via TermLink + capture demo"
description: >
  Execute arc-012 continuous-mode live-fire via TermLink + capture demo

status: work-completed
workflow_type: test
owner: agent
horizon: now
tags: [arc:continuous-run, livefire, demo]
components: []
related_tasks: [T-2369, T-2387, T-2158]
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
created: 2026-06-14T06:56:58Z
last_update: '2026-07-01T03:28:00Z'
date_finished: '2026-07-01T03:28:00Z'
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
  - ts: '2026-06-16T12:45:04Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 1
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=1 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-06-16T12:45:06Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      Discard fidelity: 0
      Loop closure (conditional): 0
      D1: 4
      D2: 0
      D3: 2
      D4: 3
      F-RECALL: 2
      F-ORCH: 0
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: Discard fidelity=0 (no-signal); Loop closure (conditional)=0 
      (no-signal); D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=3 (body:portability-abstraction); F-RECALL=2 
      (body:lightly-promoted); F-ORCH=0 (no-signal); F-AUTONOMY=0 (no-signal); 
      F3=1 (body/components:prompt-incidental); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2389: Execute arc-012 continuous-mode live-fire via TermLink + capture demo

## Context

Execute the arc-012 continuous-mode live-fire end-to-end (the one un-automatable
junction: a real `claude-fw` → `claude` restart) and capture wire evidence as the
G-062 `--demo` artefact for `fw arc close continuous-run`. Procedure:
`docs/runbooks/arc-012-continuous-mode-live-fire.md`. Driven via TermLink per
operator instruction.

**Isolation (OBS-075):** two `claude-fw` wrappers are live on this repo's master
checkout (PIDs 1752988/1753004); the restart signal is keyed per git-toplevel, so
the live-fire runs in a DEDICATED worktree off master (own toplevel → isolated
`.restart-requested`; carries master's `startup` matcher T-2376 + the T-2377 gauge
fix). Worker is a TermLink PTY `claude-fw` session (interactive, not a bg job —
Prereq 3) with `FW_CONTEXT_WINDOW=20000`.

## Acceptance Criteria

### Agent
- [x] Isolated live-fire worktree created off master (verified: own git-toplevel, `startup` matcher present in its `.claude/settings.json`, T-2377 gauge fix present)
- [x] TermLink PTY `claude-fw` worker spawned with `FW_CONTEXT_WINDOW=20000` — spawned + classic session driven (after clearing trust/FleetView/MCP first-run gates). **BUT gauge did NOT read tokens** → see finding; this is the blocker, not a pass.
- [ ] Self-trigger: `checkpoint.sh` fires the critical auto-handover from budget pressure — **NOT achieved** (gauge blind → critical never detected). Root cause in finding.
- [ ] Auto-restart + advance — **NOT achieved** (blocked upstream by the gauge).
- [ ] Bounded — N/A (loop never armed).
- [x] Wire evidence captured to `docs/reports/T-2389-livefire-evidence.md`; worker torn down (tmux kill + termlink deregister); worktree removed; `~/.claude.json` edits reverted; temp cleaned.

**Outcome: NO-GO for arc-012 closure via this run.** The headline mechanic did
not fire. The live-fire surfaced a real integration gap invisible to the four
per-link tests: when the spawned session's hooks run, fw resolves `PROJECT_ROOT`
to `/root` (proven by `check-project-boundary` blocking a livefire Bash with
"Project root: /root"), blinding budget-gate/checkpoint → no `.budget-status`, no
`.restart-requested`, `current_iteration` stays 0. Same class as T-2377 but via
hook-cwd/`CLAUDE_PROJECT_DIR` rather than transcript path. Full evidence +
two follow-up recommendations in the report.

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

# Evidence report exists and documents findings
test -f docs/reports/T-2389-livefire-evidence.md

# Evidence report contains the NO-GO recommendation
grep -q "NO-GO for closure via this run" docs/reports/T-2389-livefire-evidence.md

# Evidence report documents the root cause finding
grep -q "Project root: /root" docs/reports/T-2389-livefire-evidence.md

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

### 2026-06-14T06:56:58Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/arc012-continuous-run-s4s5/.tasks/active/T-2389-execute-arc-012-continuous-mode-live-fir.md
- **Context:** Initial task creation

### 2026-06-30 — live-fire-executed [worker-dispatch]
- **Action:** Executed arc-012 continuous-mode live-fire test via TermLink
- **Outcome:** NO-GO - headline mechanic did not fire end-to-end
- **Finding:** fw resolved PROJECT_ROOT to `/root` in spawned session hooks, blinding budget-gate/checkpoint
- **Evidence:** Captured in `docs/reports/T-2389-livefire-evidence.md`
- **Impact:** Surfaced integration gap invisible to per-link unit tests - hook cwd/CLAUDE_PROJECT_DIR propagation issue
- **Recommendation:** Two follow-ups needed: (1) fix hook project-root resolution, (2) harden runbook for first-run gates

### 2026-07-01 — task-completed [worker-dispatch]
- **Action:** Marked task complete after verification commands passed
- **Status:** All deliverables complete - evidence report documents NO-GO outcome with root cause
- **Unchecked ACs:** Three middle ACs remain unchecked as they represent the failure modes discovered (self-trigger, auto-restart, bounded loop) - these are the test's negative findings, properly documented in the evidence report
