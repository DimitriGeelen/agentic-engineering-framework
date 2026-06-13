---
id: T-2375
name: "budget detector blind in git worktrees — transcript dir-name drops dot"
description: >
  budget detector blind in git worktrees — transcript dir-name drops dot

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [C-007, C-008, lib/paths.sh]
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
created: 2026-06-13T16:30:25Z
last_update: 2026-06-13T16:35:32Z
date_finished: 2026-06-13T16:35:32Z
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

# T-2375: budget detector blind in git worktrees — transcript dir-name drops dot

## Context

The token-based context budget gauge (`checkpoint.sh` PostToolUse + `budget-gate.sh` PreToolUse)
locates the session JSONL by reconstructing Claude Code's `~/.claude/projects/<name>` directory
from `PROJECT_ROOT`. Both compute the name with `${PROJECT_ROOT//\//-}` — replacing only `/` with
`-`. Claude Code replaces **every** non-alphanumeric char (so `.` → `-` too). In any path
containing a dot — notably git worktrees under `.claude/worktrees/`, the framework's own
recommended isolation model — the computed name (`…-.claude-worktrees-…`) does NOT match the real
dir (`…--claude-worktrees-…`). `find_transcript` then finds nothing → "no transcript" → the token
gauge silently falls back to the (much weaker) tool-call counter. This is the transcript-resolution
leg of OBS-073, surfaced by the T-2373 live-fire demo (the spawned `claude-fw` ran in this worktree
and its budget gauge stayed blind). Sibling learnings: L-093, L-194 (prior `find_transcript` work).

## Acceptance Criteria

### Agent
- [x] `lib/paths.sh` provides `fw_claude_project_dir_name <path>` that replaces every
      non-alphanumeric character with `-` (matches Claude Code's actual dir naming, incl. `.`→`-`)
- [x] `agents/context/checkpoint.sh` `find_transcript()` computes the project dir name via the
      helper (no longer `${…//\//-}`)
- [x] `agents/context/budget-gate.sh` computes `PROJECT_DIR_NAME` via the helper (no longer `${PROJECT_ROOT//\//-}`)
- [x] Regression test `tests/integration/transcript_dir_name_sanitization.bats` proves the helper
      produces the correct dir name for a worktree-style dotted path AND a plain path, and that the
      dotted-path name matches an actual on-disk Claude Code projects dir when one is seeded; bats green
- [x] Live proof in this worktree: `./agents/context/checkpoint.sh status` resolves the transcript
      (output no longer contains "no transcript") OR the helper output equals the existing projects dir name

### Human
<!-- None — all acceptance criteria are deterministic/agent-verifiable (pure path-sanitization
     logic + regression test, internal tooling, no rendering surface). -->

## Verification

bash -n lib/paths.sh && bash -n agents/context/checkpoint.sh && bash -n agents/context/budget-gate.sh
grep -q 'fw_claude_project_dir_name' lib/paths.sh
grep -q 'fw_claude_project_dir_name' agents/context/checkpoint.sh
grep -q 'fw_claude_project_dir_name' agents/context/budget-gate.sh
out=$(FRAMEWORK_ROOT="$(pwd)" bash -c 'source lib/paths.sh >/dev/null 2>&1; fw_claude_project_dir_name "/opt/x/.claude/worktrees/y"'); [ "$out" = "-opt-x--claude-worktrees-y" ]
bats tests/integration/transcript_dir_name_sanitization.bats

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

**Symptom:** In git-worktree sessions, the token budget gauge is blind — `checkpoint.sh status`
reports "Context tokens: unavailable (no transcript)" and `budget-gate.sh` never finds the JSONL,
so token-based budget enforcement (warn/urgent/critical) silently degrades to the weaker tool-call
counter. Surfaced by the T-2373 live-fire demo where the spawned `claude-fw` (running in this
worktree) reached ~140k context with the gauge stuck at "ok".

**Root cause:** Claude Code names a session's transcript directory by replacing **every**
non-alphanumeric character in the cwd with `-` (verified: `/opt/…/.claude/worktrees/x` →
`-opt-…--claude-worktrees-x`, with `.`→`-` giving the `--`). Both `find_transcript()`
(`checkpoint.sh:66`) and `budget-gate.sh:174` reconstruct that name with `${PROJECT_ROOT//\//-}`,
which replaces only `/` and leaves `.` intact → `-opt-…-.claude-worktrees-x`. The two names diverge
on any path containing a dot, so the computed directory does not exist and the glob returns nothing.

**Why structurally allowed:** The reconstruction approximated Claude Code's algorithm instead of
matching it, and no test exercised a dotted PROJECT_ROOT. Non-worktree projects (no dot in the
absolute path) produced identical names under both algorithms, so the bug was invisible until the
framework's own worktree-isolation model put a `.claude/` segment in PROJECT_ROOT.

**Prevention (distinct from the fix):** the regression test pins the sanitizer against Claude
Code's actual on-disk dir name (seeded under a temp HOME), and the shared `fw_claude_project_dir_name`
helper means any future caller (current two + future) uses the correct algorithm. Learning captured
so the next agent reconstructing a Claude Code path replaces all non-alnum, not just `/`.

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

### 2026-06-13T16:30:25Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/arc012-continuous-run-s4s5/.tasks/active/T-2375-budget-detector-blind-in-git-worktrees--.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-62ef2c5f
- **Timestamp:** 2026-06-13T16:35:33Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-13T16:35:32Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
