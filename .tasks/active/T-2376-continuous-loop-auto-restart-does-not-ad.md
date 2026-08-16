---
id: T-2376
name: "continuous-loop auto-restart does not advance — SessionStart lacks startup
  matcher"
description: >
  continuous-loop auto-restart does not advance — SessionStart lacks startup matcher

status: work-completed
workflow_type: build
owner: human
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
created: 2026-06-13T16:36:09Z
last_update: '2026-08-16T22:24:09Z'
date_finished: 2026-06-13T16:48:05Z
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
  - ts: '2026-08-16T22:24:09Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 3
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=3 (body:fw-recall-or-memory-link);
      F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2376: continuous-loop auto-restart does not advance — SessionStart lacks startup matcher

## Context

The continuous-run loop's manual `/compact` path self-advances (resets+advances `current_iteration`,
reinjects the directive) because `.claude/settings.json` registers SessionStart matchers for `compact`
and `resume`. But the **budget-critical auto-restart** path (`claude-fw` → `claude -c`, fixed by
T-2373's terminator) emits SessionStart source `startup`, which matches **neither** matcher — so
`post-compact-resume` never fires on auto-restart: budget isn't reseeded, `current_iteration` doesn't
advance, and the directive isn't reinjected. The loop **restarts but does not self-advance**. This is
the loop-advance leg of OBS-074, surfaced by the T-2373 live-fire demo (after the terminator fired and
`claude -c` resumed, `current_iteration` stayed 0 / `last_source` stayed `compact`).

The hook (`post-compact-resume.sh`) and injector (`inject-next-directive.py`) already accept
`source=startup`; the gap is purely the missing matcher registration plus distinguishing a loop
auto-restart from an unrelated cold `claude` start (so cold starts keep their pre-T-2376 behavior).
Pairs with [[project_t2373_budget_terminator_shipped]] (terminator) and T-2375 (budget gauge in worktrees).

## Acceptance Criteria

### Agent
- [x] `lib/init.sh` canonical SessionStart generator includes a `startup` matcher block →
      `$fw_prefix hook post-compact-resume` (so `fw init` / `fw upgrade` wire it for all projects)
- [x] `bin/claude-fw` writes a one-shot `.context/working/.auto-restart-pending` sentinel immediately
      before restarting via `claude -c` (placed at the shared restart point so both plain and
      TermLink restarts, which converge at `CLAUDE_ARGS=("-c")`, are covered)
- [x] `agents/context/post-compact-resume.sh`: `source=startup` WITHOUT the sentinel → no-op
      (exit 0, preserves pre-T-2376 cold-start behavior — this hook never fired on cold starts);
      `source=startup` WITH the sentinel → consume it (rm) + run the full resume path so the
      directive injector advances the loop; `compact`/`resume` behavior unchanged
- [x] `tests/integration/continuous_loop_auto_restart_advance.bats` proves: (a) claude-fw writes the
      sentinel before restart, (b) the resume hook advances `current_iteration` on startup+sentinel,
      (c) does NOT advance (and emits nothing) on startup-without-sentinel, (d) still advances on
      compact/resume; bats green
- [x] `fw hook-enable --name post-compact-resume --event SessionStart --matcher startup --dry-run`
      emits the would-be settings.json addition (evidence artifact for the Human wiring step)

### Human
- [ ] [REVIEW] Wire the `startup` SessionStart matcher into this repo's `.claude/settings.json`
      (B-005 blocks agent edits to settings.json — this is the operator's to apply)
      **Steps:**
      1. `cd /opt/999-Agentic-Engineering-Framework/.claude/worktrees/arc012-continuous-run-s4s5 && bin/fw hook-enable --name post-compact-resume --event SessionStart --matcher startup`
      2. `cd /opt/999-Agentic-Engineering-Framework/.claude/worktrees/arc012-continuous-run-s4s5 && bin/fw enforcement baseline`
      3. `cd /opt/999-Agentic-Engineering-Framework/.claude/worktrees/arc012-continuous-run-s4s5 && bin/fw doctor 2>&1 | grep -i "enforcement\|sessionstart"`
      **Expected:** settings.json now has a SessionStart `startup` matcher → `hook post-compact-resume`; doctor reports enforcement baseline OK (no CHANGED FAIL).
      **If not:** re-run `bin/fw hook-enable ... --dry-run` to inspect the diff; confirm the python registrar wrote the block.
- [ ] [REVIEW] Live E2E — auto-restart self-advances the loop (the arc-012 self-driving headline, paired with T-2373)
      **Steps:**
      1. With T-2375 + this fix + the settings wiring in place, run the continuous-mode live-fire (`FW_CONTEXT_WINDOW` low so budget-critical fires), OR write a fresh `.context/working/.restart-requested` to trigger the terminator.
      2. Let claude-fw auto-restart via `claude -c`.
      3. After resume: `cat .context/working/.continuous-mode.yaml | grep -E 'current_iteration|last_source'`
      **Expected:** `current_iteration` advanced by 1 and `last_source: startup` (the loop self-advanced on auto-restart, not just on manual /compact); the "## Next Directive" section appears in the resumed session's context.
      **If not:** check `.auto-restart-pending` was created+consumed; confirm `claude -c` emitted SessionStart source `startup` (the assumption this fix rests on).

## Verification

bash -n bin/claude-fw && bash -n agents/context/post-compact-resume.sh
python3 -c "import json; json.dumps('ok')"
grep -q '"matcher": "startup"' lib/init.sh
grep -q 'auto-restart-pending' bin/claude-fw
grep -q 'auto-restart-pending' agents/context/post-compact-resume.sh
bats tests/integration/continuous_loop_auto_restart_advance.bats
out=$(bin/fw hook-enable --name post-compact-resume --event SessionStart --matcher startup --dry-run 2>&1); echo "$out" | grep -qi startup

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

**Symptom:** After a budget-critical auto-restart (claude-fw → `claude -c`, the T-2373 path), the
continuous loop restarts but does not self-advance: `current_iteration` stays put, `.budget-status`
isn't reseeded, `last_source` stays `compact`, and the directive isn't reinjected. Manual `/compact`
advances correctly; only the autonomous path is affected. Surfaced by the T-2373 live-fire demo.

**Root cause:** `.claude/settings.json` registers SessionStart matchers only for `compact` and
`resume`. `claude -c` (the wrapper's restart) emits SessionStart source `startup`, which matches
neither — so `post-compact-resume` (which reseeds budget, advances the loop via
`inject-next-directive.py`, and reinjects the directive) is never invoked on auto-restart. The hook
and injector already accept `startup`; only the matcher registration was missing.

**Why structurally allowed:** the continuous-loop substrate (T-2362..T-2367) was built and tested
against the `/compact` path (which fires the `compact` matcher), and the budget-critical→restart
path was itself dead until T-2373. So the `startup`-source gap had no live exerciser until the
T-2373 terminator made auto-restart actually happen — at which point the missing matcher surfaced.

**Prevention (distinct from the fix):** (1) the bats regression test exercises the advance on
startup+sentinel and the no-op on cold-start, pinning the behavior; (2) the `.auto-restart-pending`
sentinel makes the auto-restart-vs-cold-start distinction explicit and testable rather than implicit;
(3) the generator change means every `fw init`/`fw upgrade` wires the matcher, so consumers don't
inherit the gap. Residual: the live E2E (Human AC) is the only place the real `claude -c` SessionStart
source is confirmed — documented as the assumption this fix rests on.

## Recommendation

**Recommendation:** GO (pending the two Human ACs)

**Rationale:** The autonomous loop's missing leg is closed in code. All 5 Agent ACs pass: the
`startup` matcher is in the canonical generator, claude-fw writes the one-shot sentinel before
`claude -c`, the resume hook advances on auto-restart-startup while leaving cold starts untouched,
and the bats suite pins all four source behaviors. Reviewer PASS, no findings. The two remaining
Human ACs are the parts the agent structurally cannot complete: (1) wiring the matcher into this
repo's `.claude/settings.json` (B-005 — operator runs `fw hook-enable`), and (2) the live real-`claude
-c` E2E that confirms the SessionStart source is actually `startup` (the one assumption code can't
self-verify). Together with T-2373 (terminator) and T-2375 (worktree budget gauge), this completes
the three prerequisites for a fully self-driving continuous loop.

**Evidence:**
- 5/5 Agent ACs ticked; reviewer R-951bb2f9 PASS, 0 findings.
- `tests/integration/continuous_loop_auto_restart_advance.bats` 5/5; T-2373 terminator 3/3 (regression);
  `continuous_loop.bats` 6/6 + `test_inject_next_directive.py` 40/40 (no regression from the stdin restructure).
- `fw hook-enable ... --matcher startup --dry-run` emits the would-be settings block (Human-AC #1 evidence).

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

### 2026-06-13T16:36:09Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/arc012-continuous-run-s4s5/.tasks/active/T-2376-continuous-loop-auto-restart-does-not-ad.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-311c0a0c
- **Timestamp:** 2026-06-13T16:48:25Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-13T16:48:05Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
