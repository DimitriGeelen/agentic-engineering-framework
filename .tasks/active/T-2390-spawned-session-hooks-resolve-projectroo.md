---
id: T-2390
name: "Spawned-session hooks resolve PROJECT_ROOT to /root — blinds budget gauge (T-2389 finding)"
description: >
  T-2389 live-fire surfaced: when a claude-fw session spawned via TermLink/tmux runs its hooks, fw resolves PROJECT_ROOT to /root (check-project-boundary banner 'Project root: /root'), blinding budget-gate/checkpoint so .restart-requested is never written and the continuous-mode loop never arms. HYPOTHESIS to investigate (feedback_remediation_plans_are_hypotheses): universal (affects main-checkout sessions too) OR spawn-launch artifact (bash -lc cd+exec did not propagate CLAUDE_PROJECT_DIR)? Same class as T-2377 but via hook-cwd not transcript_path. Evidence: docs/reports/T-2389-livefire-evidence.md

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [arc:continuous-run, bug, gauge, hooks]
components: []
related_tasks: [T-2389, T-2377]
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
created: 2026-06-14T07:16:26Z
last_update: 2026-06-14T07:34:10Z
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

# T-2390: Spawned-session hooks resolve PROJECT_ROOT to /root — blinds budget gauge (T-2389 finding)

## Context

T-2389 live-fire finding: a TermLink/tmux-spawned `claude-fw` session (CC 2.1.177)
ran its hooks with `PROJECT_ROOT` resolved to `/root` (check-project-boundary banner
"Project root: /root") → budget-gate/checkpoint blind → continuous-mode loop never
armed. Evidence: `docs/reports/T-2389-livefire-evidence.md`.

## Findings (2026-06-14, mechanism identified)

- **NOT universal.** My own normally-launched session's gauge resolves correctly
  (`.budget-status` updated to real tokens). Only the headless tmux-spawned session
  mis-resolved. arc-012's loop is not fundamentally broken.
- **Mechanism:** `bin/fw:find_project_root()` (line 67) walks up from `$PWD`
  looking for `.framework.yaml`/`.tasks`. The boundary hook
  (`agents/context/check-project-boundary.sh:146`) then reads `PROJECT_ROOT` from
  the env fw set. When the spawned session's hooks ran with an effective cwd that
  resolved to `/root`, every fw-backed hook in the chain inherited the wrong root.
- **fw consults `CLAUDE_PROJECT_DIR` nowhere** (grep of bin/fw lib/ agents/ = 0
  hits) — yet Claude Code sets it specifically so hooks know the project dir
  independent of cwd. **Candidate fix:** make `find_project_root()` prefer
  `$CLAUDE_PROJECT_DIR` (when it points at a dir containing `.framework.yaml`/`.tasks`)
  before the `$PWD` walk-up. Same spirit as T-2377 (use what Claude Code hands the
  hook, don't reconstruct). To confirm: verify CC actually sets `CLAUDE_PROJECT_DIR`
  to the session's project (not `/root`) for a spawned session before relying on it.

## Acceptance Criteria

### Agent
- [x] Classify universal-vs-launch-artifact + resolution mechanism — DONE: NOT universal (own session resolves fine); mechanism = `find_project_root()` walks `$PWD`, ignores `CLAUDE_PROJECT_DIR`. See ## Findings + ## RCA.
- [x] Identify + ship the fix — DONE + unit-proven: `bin/fw` now prefers `CLAUDE_PROJECT_DIR` (validity-gated) over the `$PWD` walk; `tests/unit/t2390_project_root_claude_dir.bats` 3/3 (t1 fix works, t2 reproduces bug, t3 safe fallthrough). Commit on branch.
- [ ] Live re-drive confirmation — **HANDED OFF** (blocked by parent session budget critical, not by the fix). Re-drive worktree is pre-configured + ready (see ## Re-drive ready-state); a fresh session spawns + drives in a few steps.
- [x] N/A (not universal — no escalation needed)
- [ ] RCA filled (done below); reviewer PASS (pending — run `fw reviewer T-2390` next session)

## Re-drive ready-state (for the next session — fix is shipped, just needs driving)

The worktree `/opt/999-Agentic-Engineering-Framework/.claude/worktrees/arc012-livefire-demo`
(branch `livefire-demo-2390`, off master) is **pre-configured** so the loop will fire with the
fix active:
- `startup` matcher present (off master, T-2376).
- Its `bin/fw` is the **fixed** one (CLAUDE_PROJECT_DIR preference) — verified.
- Its `.claude/settings.json` hooks **self-reference** that fixed `bin/fw` (sed-rewritten from the
  hard-coded main path), so the hook chain runs the fix.
- continuous-mode (`max_iterations:3, current_iteration:0`) + `.next-directive.yaml` seeded.
- Trust + MCP-disable seeded in `~/.claude.json` for the worktree path.

Next session (with budget headroom), drive it:
1. `termlink spawn --name lf --backend tmux --env FW_CONTEXT_WINDOW=20000 --env "P=<prompt>" --wait -- bash -lc 'cd <worktree> && exec claude-fw "$P" --permission-mode acceptEdits'`
2. `tmux send-keys -t tl-lf Escape` (dismiss the CC 2.1.177 MCP dialog).
3. **PROBE FIRST:** send a prompt making claude run one **Bash** call writing to a *worktree-internal*
   path (e.g. `echo probe >> .context/working/probe.log`). Then check the worktree's
   `.context/working/.budget-status` got written (→ hooks resolve to the worktree, fix works) and
   that no `check-project-boundary` "Project root: /root" block appears. If confirmed, drive the
   burn (Reads to climb + a Bash at high tokens) → critical → `.restart-requested` → iteration
   advances. budget-gate matches **Write|Edit|Bash NOT Read** — burn must include Bash.
4. Teardown: `tmux kill-session`, `git worktree remove ../arc012-livefire-demo --force`, revert the
   `~/.claude.json` entry, `git branch -D livefire-demo-2390` (Tier-0).

## RCA

**Symptom:** arc-012 continuous-mode loop never armed in the T-2389 TermLink-driven live-fire;
`check-project-boundary` blocked a livefire Bash with banner "Project root: /root".

**Root cause:** `bin/fw:find_project_root()` resolves PROJECT_ROOT by walking up from `$PWD`.
Claude Code runs hook commands with cwd = `$HOME` (/root) for the spawned session, so the walk
mis-resolved (latched a stray `/root/.tasks` or fell back wrong). Every fw-backed hook in the
chain inherited the wrong root → budget-gate/checkpoint read/wrote the wrong CONTEXT_DIR → gauge
blind → no `.restart-requested`.

**Why structurally allowed:** fw consulted `CLAUDE_PROJECT_DIR` **nowhere** — the env var Claude
Code provides to hooks precisely so they resolve the project independent of invocation cwd. The
four per-link integration tests stub the transcript and run fw from the correct cwd, so none
exercised a real session whose hooks resolve their own root. Same blindness class as T-2377
(reconstruct-instead-of-trust) but via hook-cwd rather than transcript-path.

**Prevention:** (fix) `bin/fw` prefers `CLAUDE_PROJECT_DIR` (validity-gated) before the `$PWD`
walk; (test) `tests/unit/t2390_project_root_claude_dir.bats` pins fix + bug-repro + safe
fallthrough.

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

### 2026-06-14T07:16:26Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/arc012-continuous-run-s4s5/.tasks/active/T-2390-spawned-session-hooks-resolve-projectroo.md
- **Context:** Initial task creation

### 2026-06-14T07:34:10Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)
