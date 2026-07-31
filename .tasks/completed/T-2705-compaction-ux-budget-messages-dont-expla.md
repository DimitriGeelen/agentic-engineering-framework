---
id: T-2705
name: "Compaction UX: budget messages don't explain pre-compact hooks or post-compact
  /resume"
description: >
  Compaction UX: budget messages don't explain pre-compact hooks or post-compact /resume

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [C-007, C-008, bin/fw, tests/lint/no-backticks-in-inline-python.bats]
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
created: 2026-07-31T11:18:50Z
last_update: 2026-07-31T16:12:12Z
date_finished: 2026-07-31T16:12:12Z
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
  - ts: '2026-07-31T11:30:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-31T11:30:09Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal);
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2705: Compaction UX: budget messages don't explain pre-compact hooks or post-compact /resume

## Context

Budget-gate/checkpoint messages told the operator to run `/resume` after compaction
but never explained what the PreCompact hook captures, what the auto-injected
SessionStart:compact banner actually delivers (a truncated preview, not full
recovery — measured in `docs/context-compaction.md`), or what each budget level
means. `docs/context-compaction.md` now carries that explanation; the gate/checkpoint
messages point at it.

**Audience split (T-2143 routing):** the budget-ladder and compaction-recovery
strings emitted by `budget-gate.sh`/`checkpoint.sh` are **agent-facing** — they are
read by the agent mid-tool-call and tell it what it may still do and where to read
more. `_supervision_notice()` is the one exception: its content is meant for the
**operator** (only a human can type `claude-fw` or `/compact`), so it is phrased as
an instruction to the agent to *relay* the message rather than an attempt to act on
it directly — the agent has no tool call that types a slash command or relaunches
its own process.

## Acceptance Criteria

### Agent
- [x] The claim "`/resume` after compaction is essential" is TESTED against what
      `post-compact-resume.sh` already auto-injects, and the shipped wording states
      whatever turns out to be true — including "additive, not essential" if that is
      the finding
- [x] `docs/context-compaction.md` exists and covers: D-027 (auto-compaction
      disabled by design), what the PreCompact hook does, what SessionStart:compact
      injects, the budget ladder with thresholds read from source not guessed, and
      how to check current usage
- [x] Budget warn/urgent/critical messages point the operator at the article and say
      what to do; the `warn` message stays short (it fires often)
- [x] Operator-facing and agent-facing strings are separated deliberately, with the
      audience named in this task file (T-2143 routing)
- [x] Rendered message output is captured from a REAL invocation of
      `budget-gate.sh`, pasted into this task file — not reconstructed by hand
- [x] No change to budget thresholds or allowlist logic (this task is what the
      messages SAY, not what the gate DOES)

**Real invocation output (2026-07-31, this session)** — `.context/working/.budget-status`
seeded with synthetic level/token values, then `budget-gate.sh` run directly with a
JSON stdin payload; file restored to its prior contents immediately after capture.

```
--- warn (tokens=230000, tool=Read) ---
Note: Context at ~230000 tokens (~76%). Commit before starting new work. (docs/context-compaction.md)
  ⚠ Unsupervised session (not under claude-fw): the budget auto-restart loop will NOT fire.
    Tell the operator: relaunch via 'claude-fw' for hands-off recovery, or run '/compact' before critical (see docs/context-compaction.md).
exit=0

--- urgent (tokens=260000, tool=Read) ---
WARNING: Context at ~260000 tokens (~86%). Do not start new work. Commit and handover.
  Details: docs/context-compaction.md (budget ladder, what to do at each level)
  ⚠ Unsupervised session (not under claude-fw): the budget auto-restart loop will NOT fire.
    Tell the operator: relaunch via 'claude-fw' for hands-off recovery, or run '/compact' before critical (see docs/context-compaction.md).
exit=0

--- critical (tokens=290000, tool=Bash "echo hi", blocked) ---

══════════════════════════════════════════════════════════
  SESSION WRAPPING UP (~290000 tokens)
══════════════════════════════════════════════════════════

  Context is at ~96% of context window.
  Task files already have all essential state. Time to wrap up.

  ALLOWED: git commit/push, bin/fw handover, reading files,
           Write/Edit to .context/ .tasks/ .claude/
  BLOCKED: Write/Edit to source files, Bash (except commit/push/handover)

  Action: Commit your work, then run 'bin/fw handover'
  Details: docs/context-compaction.md (budget ladder, what handover/compact capture)
  ⚠ Unsupervised session (not under claude-fw): the budget auto-restart loop will NOT fire.
    Tell the operator: relaunch via 'claude-fw' for hands-off recovery, or run '/compact' before critical (see docs/context-compaction.md).
══════════════════════════════════════════════════════════

exit=2
```

The `warn` line stays a single short line (docs pointer inline); `urgent` and
`critical` add a one-line "Details:" pointer since those fire less often and
warrant a beat more guidance.

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

test -f docs/context-compaction.md
bash -n agents/context/budget-gate.sh
bash -n agents/context/checkpoint.sh
grep -q "docs/context-compaction.md" agents/context/budget-gate.sh
grep -q "docs/context-compaction.md" agents/context/checkpoint.sh

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

### 2026-07-31T11:18:50Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2705-compaction-ux-budget-messages-dont-expla.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-7ed95896
- **Timestamp:** 2026-07-31T16:12:14Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-07-31T16:12:12Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
