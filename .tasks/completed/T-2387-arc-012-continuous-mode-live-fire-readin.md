---
id: T-2387
name: "arc-012 continuous-mode live-fire readiness verification"
description: >
  Verify the 4 loop links + settings.json startup-matcher wiring on worktree and master to answer how far we are from a live continuous-mode test.

status: work-completed
workflow_type: test
owner: agent
horizon: null
tags: [arc:continuous-run, testing]
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
created: 2026-06-13T23:18:41Z
last_update: 2026-06-13T23:21:49Z
date_finished: 2026-06-13T23:21:49Z
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

# T-2387: arc-012 continuous-mode live-fire readiness verification

## Context

Answer the operator's recurring question — "how far are we from testing continuous mode?" —
with verified evidence rather than memory. Check each of the 4 arc-012 loop links' code + the
SessionStart `startup`-matcher wiring on both the worktree and master, and produce a green-light
readiness checklist + the precise remaining operator action(s).

## Acceptance Criteria

### Agent
- [x] Link #1 (gauge, T-2377): confirmed reading live tokens this session — budget cache `{"level":"warn","tokens":230265,...,"source":"budget-gate"}` live in this worktree
- [x] Link #4 (startup matcher, T-2376): worktree `.claude/settings.json` has only `compact`+`resume` matchers (behind); **master HAS the `startup` matcher** (`git show master:.claude/settings.json` line 34). Link #4 IS wired on the deployed branch — the worktree checkout is simply stale.
- [x] Supporting code confirmed: `lib/init.sh:646` wires the startup matcher (so `fw upgrade` adds it); `bin/claude-fw:280` writes the `.auto-restart-pending` sentinel; `agents/context/post-compact-resume.sh:21-42` reads SOURCE_TAG + advances on `startup` only when the sentinel is present (cold-start no-op), increments `current_iteration` (line 286)
- [x] Readiness verdict written (see ## Readiness Verdict)

## Readiness Verdict

**Engineering distance to a live continuous-mode test: ~zero. It is down to one operator-run
live-fire.**

All four loop links are coded, deployed to master, and unit/integration-tested:

| Link | What | State |
|------|------|-------|
| #1 gauge | budget-gate/checkpoint read live tokens from the Claude Code transcript (stdin `transcript_path`) | T-2377 deployed; **proven live this session** (read 230K in a worktree) |
| #2 signal | checkpoint.sh writes `.restart-requested` at critical (directive folded in) | T-2363/T-2378, integration-tested |
| #3 terminator | claude-fw SIGTERMs claude on a fresh signal + restarts `claude -c` + writes `.auto-restart-pending` | T-2373, `bin/claude-fw:280` |
| #4 advance | SessionStart `startup` matcher → post-compact-resume advances `current_iteration` (sentinel-gated) | T-2376, **master settings.json:34 + post-compact-resume.sh:21-42** |

Loop is armed: `.continuous-mode.yaml` → `enabled: true`, `max_iterations: 10`, `current_iteration: 1`.

**The only remaining step** is the live end-to-end fire — the one un-automatable junction
(Human AC on T-2373 + T-2376), which doubles as the **arc-012 G-062 headline demo**. Procedure
in `docs/runbooks/arc-012-continuous-mode-live-fire.md`.

**Prerequisites for the operator's live-fire (all from the runbook):**
1. Run on a **master checkout** (the worktree is behind — lacks the startup matcher). Or merge
   this worktree branch to master first.
2. **Interactive** `claude-fw` session — NOT a background job (bg-job self-compaction confounds
   the gauge + restart).
3. **Quiet repo** (OBS-075) — no other `claude-fw` wrappers running on this repo, or the
   repo-global `.restart-requested` signal restarts them all.
4. `FW_CONTEXT_WINDOW=20000 claude-fw` to fire the loop in minutes instead of hours.

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
#
# --- readiness verification ---
# Master settings.json has the SessionStart startup matcher (link #4 wired on deployed branch).
out=$(git show master:.claude/settings.json 2>&1); grep -q '"matcher": "startup"' <<<"$out"
# Loop is armed.
grep -q '^enabled: true' .context/working/.continuous-mode.yaml
# Supporting code present: init.sh wiring, claude-fw sentinel, post-compact-resume startup logic.
grep -q '"matcher": "startup"' lib/init.sh
grep -q 'auto-restart-pending' bin/claude-fw
grep -q 'SOURCE_TAG' agents/context/post-compact-resume.sh

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

### 2026-06-13T23:18:41Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/arc012-continuous-run-s4s5/.tasks/active/T-2387-arc-012-continuous-mode-live-fire-readin.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f7ca5726
- **Timestamp:** 2026-06-13T23:21:49Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-13T23:21:49Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
