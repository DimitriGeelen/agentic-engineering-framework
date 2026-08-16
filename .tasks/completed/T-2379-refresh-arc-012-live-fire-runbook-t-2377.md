---
id: T-2379
name: "refresh arc-012 live-fire runbook: T-2377 gauge fix + interactive-not-bgjob
  caveat + verify-gauge precheck"
description: >
  refresh arc-012 live-fire runbook: T-2377 gauge fix + interactive-not-bgjob caveat
  + verify-gauge precheck

status: work-completed
workflow_type: build
owner: agent
horizon:
arc_id: continuous-run
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
created: 2026-06-13T20:06:49Z
last_update: '2026-08-16T22:25:04Z'
date_finished: 2026-06-13T20:13:19Z
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
  - ts: '2026-08-16T22:25:04Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      Discard fidelity: 0
      Loop closure (conditional): 0
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: Discard fidelity=0 (no-signal); Loop closure (conditional)=0 
      (no-signal); D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=2 
      (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2379: refresh arc-012 live-fire runbook: T-2377 gauge fix + interactive-not-bgjob caveat + verify-gauge precheck

## Context

`docs/runbooks/arc-012-continuous-mode-live-fire.md` (T-2369) is the operator's
guide for the one un-automatable junction of the continuous loop — the live
`claude-fw` restart. It predates this session's fixes and now has two correctness
gaps that would make the operator's run silently fail or send them in circles:

1. **The lowered-window trigger assumed the gauge could see tokens.** Before T-2377
   the budget gauge was blind in worktree / background-job sessions (it reconstructed
   the transcript dir from PROJECT_ROOT instead of using the hook's stdin
   `transcript_path`). The runbook's troubleshooting row "Critical never fires →
   transcript not found" describes that exact bug with no pointer to the fix or a
   pre-check. T-2377 (deployed to master) fixes it; the runbook must say so and add a
   verify-gauge pre-check so the operator confirms the gauge reads real tokens
   *before* burning a session.
2. **No interactive-vs-background-job guidance.** A background-job harness manages
   its own compaction (multiple `compact_boundary` markers; the transcript can end on
   a boundary so the gauge reads ~0 even when correct). The live-fire must be run in
   an **interactive** `claude-fw` terminal. The runbook never says this.

Also: the `startup` SessionStart matcher (T-2376) is now a real prerequisite (the
auto-restart emits `startup`, not `resume`), and the loop chain now has full
per-link test coverage (T-2377/T-2378/T-2373/T-2376) the "See also" should list.

This is the last friction-removal before the operator's single live observation —
the arc-012 §G-062 headline demo.

## Acceptance Criteria

### Agent
- [x] Runbook Prerequisites name the deployed fixes the live-fire now depends on: T-2377 (gauge reads stdin transcript_path), T-2376 (`startup` SessionStart matcher wired)
- [x] Runbook adds an explicit **interactive-not-background-job** warning (bg-job harness self-compaction confounds the gauge + restart)
- [x] Runbook adds a **verify-gauge pre-check step** the operator runs before launching, that confirms the gauge reports real tokens (not "unavailable") — catching the T-2377 class up-front
- [x] The "Critical never fires" troubleshooting row points at the gauge/transcript-path check (T-2377), not just "lower the window"
- [x] "See also" lists the four per-link tests: `budget_gauge_stdin_transcript.bats`, `continuous_loop_critical_signal.bats`, `claude_fw_restart_terminator.bats`, `continuous_loop_auto_restart_advance.bats`
- [x] The verify-gauge pre-check command actually works when run (exits 0 / prints a token line on a healthy gauge)
- [x] `bin/fw reviewer T-2379` returns Overall PASS

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

grep -q "INTERACTIVE terminal — NOT a background job" docs/runbooks/arc-012-continuous-mode-live-fire.md
grep -q "T-2377" docs/runbooks/arc-012-continuous-mode-live-fire.md && grep -q "T-2376" docs/runbooks/arc-012-continuous-mode-live-fire.md
grep -q "Verify the gauge can see tokens" docs/runbooks/arc-012-continuous-mode-live-fire.md
grep -q "budget_gauge_stdin_transcript.bats" docs/runbooks/arc-012-continuous-mode-live-fire.md && grep -q "continuous_loop_critical_signal.bats" docs/runbooks/arc-012-continuous-mode-live-fire.md
precheck=$(bin/fw hook checkpoint status 2>&1); echo "$precheck" | grep -q "Context tokens:"
out=$(bin/fw reviewer T-2379 2>&1); echo "$out" | grep -qE "Overall:.*(PASS|CONCERN)" && ! echo "$out" | grep -q "Overall:.*FAIL"

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

**Symptom:** The arc-012 live-fire runbook would have led an operator running it from a
worktree/background job (or a checkout without the T-2377 fix) in circles: critical never
fires, the gauge silently reports "unavailable", and the runbook's troubleshooting row
pointed only at "lower the window" — the one action that cannot help when the gauge can't
find the transcript at all.

**Root cause:** the runbook (T-2369) was written before the gauge's transcript-discovery
defect (T-2377) was understood. It documented the *symptom* of that defect as a
troubleshooting row ("transcript not found") without a fix pointer, and gave no
interactive-vs-background-job guidance — so its failure mode and the framework's actual
failure mode silently diverged once T-2377 landed.

**Why structurally allowed:** runbooks are prose docs with no test that ties them to the
behaviour they describe; nothing flags a runbook whose troubleshooting advice predates a
fix to the very thing it troubleshoots. Doc/code drift is invisible to the audit.

**Prevention:** the refreshed runbook adds (1) a verify-gauge pre-check step the operator
runs *before* burning a session — turning the silent-failure into an explicit early stop;
(2) the interactive-not-bg-job prerequisite; (3) a corrected troubleshooting row pointing
at the gauge/transcript-path check. The Verification block greps the runbook for these
additions, so a future regression that strips them fails the gate. (Broader doc↔code drift
detection remains unaddressed — noted, not in scope here.)

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

### 2026-06-13 — verify-gauge precheck can't use `checkpoint status` blindly
- **What changed:** discovered that the obvious precheck (`bin/fw hook checkpoint status`)
  is itself subject to the T-2377 class — its manual invocation has no stdin
  `transcript_path`, so it falls back to PROJECT_ROOT reconstruction. That works in the
  *intended* interactive-main-repo scenario (launch cwd = PROJECT_ROOT) but reports
  "unavailable" in a worktree/bg-job. The precheck is therefore only valid in the same
  context the live-fire requires — which is why the runbook gates it behind the
  interactive-not-bg-job prerequisite rather than presenting it as a context-free check.
- **Plan impact:** the precheck step (3a) is explicitly scoped to the interactive session
  and cross-checked against `.context/working/.budget-status` (hook-written, stdin-correct)
  rather than relying on the manual `status` reading alone.
- **Triggered:** no new sub-task; informed the runbook wording. Broader doc↔code drift
  detection noted in RCA as out-of-scope.

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

### 2026-06-13T20:06:49Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/arc012-continuous-run-s4s5/.tasks/active/T-2379-refresh-arc-012-live-fire-runbook-t-2377.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-cf9a91c3
- **Timestamp:** 2026-06-13T20:13:20Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-13T20:13:19Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
