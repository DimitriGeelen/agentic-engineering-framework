---
id: T-2377
name: "budget gauge blind in worktree sessions — use hook stdin transcript_path not
  reconstructed project dir"
description: >
  budget gauge blind in worktree sessions — use hook stdin transcript_path not reconstructed
  project dir

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [C-007, C-008]
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
created: 2026-06-13T19:08:37Z
last_update: '2026-08-16T22:25:04Z'
date_finished: 2026-06-13T19:28:27Z
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
      D1: 4
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=2 (body:default-change); D4=2 
      (body:env-class-handled); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2377: budget gauge blind in worktree sessions — use hook stdin transcript_path not reconstructed project dir

## Context

The arc-012 continuous-run loop never armed in real use because its **link #1 — the
budget gauge — is blind in every git-worktree / background-job session.** Both gauge
entry points (`agents/context/checkpoint.sh` `find_transcript()` and
`agents/context/budget-gate.sh`) reconstruct the Claude Code transcript directory from
`PROJECT_ROOT` (`$HOME/.claude/projects/<sanitized-PROJECT_ROOT>`). In a worktree the
session's cwd is the worktree, but Claude Code writes the transcript to the project dir
of the **launch cwd** (the main repo). So the gauge searches the worktree-suffixed dir
(empty / stale sibling) while the live transcript sits in the un-suffixed dir →
"Context tokens: unavailable" → critical never detected → `.restart-requested` never
written → terminator never fires → loop never advances.

T-2375 (OBS-073) fixed only the dir-name *character encoding* (`.`→`-`). The *base path*
is still wrong for worktrees because it is derived from cwd, not from the session's real
transcript location.

**Fix:** stop reconstructing. Claude Code passes the authoritative `transcript_path` to
every PreToolUse/PostToolUse hook on stdin — sibling hooks already consume it
(`subagent-stop.sh:63`, `chat-bare-path-scan.sh:48`, `session-end.sh`, `stop-guard.sh`).
Prefer `transcript_path` from the hook stdin JSON; fall back to the existing
reconstruction only when stdin carries no usable path (manual `checkpoint.sh status`).

## Acceptance Criteria

### Agent
- [x] `budget-gate.sh` uses `transcript_path` from the hook stdin JSON when present and the file exists, before falling back to PROJECT_ROOT reconstruction
- [x] `checkpoint.sh` `find_transcript()` accepts an explicit transcript path (from stdin/env) and prefers it over reconstruction; existing `find_transcript` callers and manual `checkpoint.sh status` still work via fallback
- [x] Fallback path is preserved byte-for-byte when no stdin transcript_path is available (no regression for non-worktree sessions / manual invocation)
- [x] New regression test proves: given a stdin payload with `transcript_path` pointing at a fresh transcript in an UNRELATED project dir, the gauge reads that file's tokens (not the PROJECT_ROOT-derived dir)
- [x] Existing budget/transcript tests still pass (`transcript_dir_name_sanitization.bats`, any budget-gate/checkpoint bats)
- [x] `bin/fw reviewer T-2377` returns Overall PASS (no new anti-patterns)

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
bash -n agents/context/checkpoint.sh
bats tests/integration/budget_gauge_stdin_transcript.bats
bats tests/integration/transcript_dir_name_sanitization.bats
out=$(bin/fw reviewer T-2377 2>&1); echo "$out" | grep -qE "Overall:.*(PASS|CONCERN)" && ! echo "$out" | grep -q "Overall:.*FAIL"

## RCA

**Symptom:** The arc-012 continuous-run loop "has not been working" (operator,
2026-06-13). The budget gauge reports `Context tokens: unavailable (no usage data)`
in this and every worktree/background-job session; budget-critical is therefore never
detected, `.restart-requested` is never written, and the auto-restart loop never arms.

**Root cause:** `find_transcript()` (checkpoint.sh:64-72) and budget-gate.sh:177-181
locate the Claude Code transcript by reconstructing `$HOME/.claude/projects/<dir>`,
where `<dir>` is derived from `PROJECT_ROOT`. In a git worktree the framework's
`PROJECT_ROOT` resolves to the worktree path, but **Claude Code keys the transcript dir
on the session's launch cwd (the main repo), not the current cwd.** So the gauge
searches `…--claude-worktrees-arc012-…/` (which holds only a stale sibling jsonl) while
the live transcript is written to `…-opt-999-Agentic-Engineering-Framework/`. Verified
live: the active `77ac04c8….jsonl` (6532 lines, mtime 21:07, ~126K tokens) sits in the
un-suffixed dir; the worktree-suffixed dir holds only `704852f7….jsonl` (172 lines,
18:19, stale).

**Why structurally allowed:** the gauge *reconstructs* a path it could *receive*.
Claude Code passes the exact `transcript_path` to every hook on stdin, and five sibling
hooks in the same directory already consume it — but checkpoint.sh/budget-gate.sh predate
that pattern (T-149/L-093 era) and never adopted it. T-2375 (OBS-073) treated the symptom
in the same code path (dir-name encoding) without questioning the reconstruction itself,
so the deeper base-path defect survived as a "fixed" gap. No test exercised the gauge
against a stdin payload whose transcript lives outside the PROJECT_ROOT-derived dir.

**Prevention:** (1) the fix removes the reconstruction as the primary path — using the
authoritative stdin `transcript_path` eliminates the encoding bug, the worktree base-path
bug, and the "newest-sibling-jsonl" heuristic (T-791) in one move; (2) new regression test
`budget_gauge_stdin_transcript.bats` pins "stdin transcript_path in an unrelated project
dir is read in preference to the PROJECT_ROOT-derived dir" — the exact condition no prior
test covered; (3) learning captured so future gauge work reaches for stdin first.

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

### 2026-06-13T19:08:37Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/arc012-continuous-run-s4s5/.tasks/active/T-2377-budget-gauge-blind-in-worktree-sessions-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-fe9fa625
- **Timestamp:** 2026-06-13T19:28:30Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-13T19:28:27Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
