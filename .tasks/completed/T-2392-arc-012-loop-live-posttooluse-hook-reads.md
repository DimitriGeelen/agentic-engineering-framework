---
id: T-2392
name: "arc-012 loop: live PostToolUse hook reads 0 tokens despite correct PROJECT_ROOT
  (transcript_path mismatch)"
description: >
  Bug B from T-2390 re-drive 2. After forcing PROJECT_ROOT=worktree (Bug A bypassed)
  the gauge resolves correctly (.tool-counter/.budget-status write to worktree, checkpoint
  ran 107x) but the loop STILL did not fire: in-hook get_context_tokens returns 0
  every check. Gauge logic PROVEN correct (manual hook invocation with same PROJECT_ROOT
  = 972318 tokens, both stdin and reconstruction paths). Main checkout same HEAD,
  no local mods, has T-2375+T-2377. So CC passes a valid-but-wrong transcript_path
  to the live PostToolUse hook, bypassing reconstruction via find_transcript's explicit-path
  branch (line 72). NOT yet fixable blind. FIRST STEP: instrumented re-drive -- tee
  the live hook stdin (instrument <worktree>/bin/fw hook dispatcher, which is T-559-allowlisted)
  and read the captured transcript_path. arc012-livefire-demo worktree is left pre-configured
  for this. See T-2390 ## Re-drive 2 Bug B.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [C-007, C-008, agents/context/session-metrics.sh, bin/fw, 
      lib/paths.sh, tests/unit/t2391_project_root_inherited_stale.bats]
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
created: 2026-06-14T10:01:22Z
last_update: '2026-08-16T22:25:04Z'
date_finished: 2026-06-14T17:28:13Z
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
      D3: 0
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=0 (no-signal); D4=2 
      (body:env-class-handled); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=1 
      (body/components:context-fabric-incidental); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2392: arc-012 loop: live PostToolUse hook reads 0 tokens despite correct PROJECT_ROOT (transcript_path mismatch)

## Context

Bug B from the arc-012 continuous-loop live-fire. The budget gauge is blind in
every git-worktree session because Claude Code keys the transcript projects dir
on the **launch cwd (main repo)**, not on `PROJECT_ROOT` (the worktree), so
`find_transcript`/budget-gate reconstruct the wrong dir and read 0 tokens →
critical never fires → the loop never arms. Full data-proven RCA below.

Fix: both reconstruction sites must search **both** candidate dirs (the
PROJECT_ROOT-keyed one AND the primary-worktree/main-repo-keyed one) and pick the
globally-newest transcript. Shared resolver `fw_claude_project_dirs` in
`lib/paths.sh` (DRY across the two hooks). Reconstruction is the *fallback* path —
the T-2377 stdin `transcript_path` preference stays first.

## Acceptance Criteria

### Agent
- [x] `fw_claude_project_dirs()` added to `lib/paths.sh`: emits the candidate
      Claude Code transcript project dirs — the `PROJECT_ROOT`-keyed dir AND the
      primary-worktree (main-repo, via `git rev-parse --git-common-dir` → parent)
      keyed dir — de-duplicated, existing dirs only. Graceful when not a git repo.
- [x] `agents/context/checkpoint.sh` `find_transcript()` reconstruction searches
      all `fw_claude_project_dirs` candidates and returns the globally-newest
      `*.jsonl` (stdin explicit-path branch unchanged, tried first).
- [x] `agents/context/budget-gate.sh` fallback searches all
      `fw_claude_project_dirs` candidates and picks the globally-newest transcript
      (stdin transcript_path preference unchanged, tried first).
- [x] `agents/context/session-metrics.sh` (third reconstruction copy) migrated to
      the shared resolver — also clears its stale pre-T-2375 slash-only sanitizer
      (missed by the T-2380 corpus sweep).
- [x] bats pins the worktree-blindness fix: synthetic worktree-keyed (stale) +
      main-repo-keyed (live/newest) dirs → resolver picks the live one; and the
      non-worktree (main-repo) case → single candidate dir, no regression.
- [x] `bash -n` clean on both hooks + `lib/paths.sh` (L-408).

<!-- No Human ACs — every criterion is agent-verifiable (resolver behaviour +
     bats + bash -n). Live-fire of the full continuous loop in a real worktree
     session is tracked separately (it depends on this fix landing on master). -->

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

bash -n lib/paths.sh
bash -n agents/context/checkpoint.sh
bash -n agents/context/budget-gate.sh
bash -n agents/context/session-metrics.sh
bats tests/unit/t2392_worktree_transcript_resolution.bats

## RCA

**CORRECTED 2026-06-14 (the original "valid-but-wrong transcript_path" RCA was WRONG; this is data-proven from a normal session — no tmux spawn needed).**

**Symptom:** In-hook `get_context_tokens` returns 0 in worktree sessions despite a
correct PROJECT_ROOT → budget gauge blind → continuous loop never arms. NB the bug
is NOT tmux-spawn-specific: it hits *every* worktree session (proven in the live
background session 77ac04c8 this turn — `.budget-status` frozen at 136K while the
session was actually at ~302K).

**Root cause:** Claude Code keys the transcript projects dir on the **launch cwd
(the main repo)**, not on PROJECT_ROOT (the worktree). This session's live
transcript is at `~/.claude/projects/-opt-999-Agentic-Engineering-Framework/77ac04c8….jsonl`
(38MB, live), but `find_transcript` (checkpoint.sh:70) reconstructs the dir from
PROJECT_ROOT=worktree → `…--claude-worktrees-arc012-continuous-run-s4s5/`, which
holds only STALE transcripts. `ls -t | head -1` picks the newest *stale* one
(88f3e240 @ 00:04); all its entries pre-date `.session-start-ts` (14:24:56) so the
T-1088 filter zeroes them → tokens=0. The hook stdin transcript_path is EMPTY
(`.gauge-debug.log`: `hooktr=[]`), so T-2377's "prefer stdin path" fix has nothing
to prefer and falls to this broken reconstruction.

**Why structurally allowed:** reconstruction assumed the projects dir is a pure
function of PROJECT_ROOT. T-2375 fixed the *encoding*, T-2377 added the stdin
*preference* — but neither covered the case "stdin path absent AND CC keyed the dir
on a cwd ≠ PROJECT_ROOT" (the worktree-launched-from-main case). Same
worktree-coordination class as T-2391 (PROJECT_ROOT poison) and OBS-077 (cron).

**Prevention / FIX (proven, ready to build):** `find_transcript` (in BOTH
checkpoint.sh and budget-gate.sh — both reconstruct) must consider **both** the
PROJECT_ROOT-keyed dir AND the **primary-worktree (main-repo)-keyed** dir
(`git rev-parse --git-common-dir` → parent → `fw_claude_project_dir_name`), then
pick the **globally newest** transcript across the candidate dirs. Live-proof the
target: `get_context_tokens` on the main-keyed 77ac04c8 under the current
session-start-ts = **301867 tokens** (752/1692 entries kept). bats: synthetic
worktree-keyed(stale) + main-keyed(live) dirs → picks live. Live-prove with
`checkpoint.sh status` reading this session's real ~302K. Consider extracting the
shared resolver into `lib/paths.sh` (DRY across the two hooks).

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

### 2026-06-14T10:01:22Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/arc012-continuous-run-s4s5/.tasks/active/T-2392-arc-012-loop-live-posttooluse-hook-reads.md
- **Context:** Initial task creation

### 2026-06-14T17:19:07Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-686fd6f1
- **Timestamp:** 2026-06-14T17:28:14Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-14T17:28:13Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
