---
id: T-2373
name: "arc-012: add budget-critical terminator to claude-fw so auto-restart fires"
description: >
  arc-012: add budget-critical terminator to claude-fw so auto-restart fires

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [arc:continuous-run, fix]
arc_id: continuous-run
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
created: 2026-06-13T14:42:12Z
last_update: 2026-06-13T14:42:12Z
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

# T-2373: arc-012: add budget-critical terminator to claude-fw so auto-restart fires

## Context

Implements the fix designed in T-2372 (RCA). The budget-critical → auto-restart
chain in `bin/claude-fw` has no terminator: `checkpoint.sh` writes
`.context/working/.restart-requested` at critical, but the wrapper only checks the
signal AFTER `claude` exits — and nothing ends the running `claude`. So the
budget-critical auto-restart never fires (the `/compact` path works because
`/compact` ends the context itself). This task adds the terminator for both
execution modes (plain foreground + TermLink PTY).

Reproduction + control already committed in T-2372:
`tests/integration/claude_fw_restart_terminator.bats`. This task extends that
harness with a terminator-fires case and an opt-out case.

## Acceptance Criteria

### Agent
- [x] **Plain mode terminator:** a fresh `.restart-requested` written while `claude`
      runs triggers a background watcher that SIGTERMs (then SIGKILLs after grace)
      the wrapper's `claude` child, so the existing restart-on-exit branch fires.
      Verified by the bats "FIX" case (alive stub → `Auto-restart #1` → `Max restarts`).
- [x] **TermLink mode terminator:** the PTY poll loop checks for a fresh signal each
      cycle and injects `/exit` to end the claude session so restart fires.
      (Implemented + `bash -n`; live E2E of the inject path is deferred to the Human
      `[REVIEW]` AC since bats cannot spin a real TermLink session.)
- [x] **run_start_epoch guard (edge case a):** the terminator only acts on a signal
      whose mtime ≥ the current run's start epoch AND <5min old, so a leftover/stale
      signal cannot instantly re-kill a freshly-resumed session.
- [x] **Fail-safe opt-out:** `FW_NO_TERMINATOR=1` disables the terminator (restores
      pre-fix behavior). Verified by the bats "OPT-OUT" case (alive stub → no restart).
- [x] **No regression:** `bash -n bin/claude-fw` passes and the CONTROL case
      (claude exits with fresh signal → restart-on-exit) stays green.
- [x] **Reviewer PASS:** `bin/fw reviewer T-2373` → Overall PASS/CONCERN (no FAIL).
      (R-1ace5d88 PASS; one `human-ac-mechanical-signal` FP suppressed via OV-0cbc85a8, 90d.)

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

- [ ] [REVIEW] Real-claude E2E: budget-critical auto-restart fires without manual `/compact`
      **Steps:**
      1. `cd /opt/999-Agentic-Engineering-Framework && FW_CONTEXT_WINDOW=20000 bin/claude-fw --termlink`
         (low window forces budget-critical within a few turns; `--termlink` lets you observe).
      2. Work normally until the budget hits critical (`checkpoint.sh` commits a handover and
         writes `.context/working/.restart-requested`).
      3. Watch: the session should end on its own and the wrapper should print
         `Auto-restart #1` then resume with `claude -c` — no manual `/compact` needed.
      **Expected:** session auto-restarts within ~10s of critical; resumed session shows
      `current_iteration` advanced and the next-directive injected.
      **If not:** capture `bin/claude-fw` stderr + `.context/working/.restart-requested` mtime;
      check the terminator watcher launched (plain mode) or the `/exit` inject (TermLink mode).
      Why Human: `bin/claude-fw` is the session launcher (highest blast-radius) and quit-timing
      against a real interactive claude cannot be settled by the stub-driven bats harness —
      it needs a live session that the operator drives. Irreversible-action class (T-954 #3).

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
bash -n bin/claude-fw
bats tests/integration/claude_fw_restart_terminator.bats
out=$(bin/fw reviewer T-2373 2>&1); echo "$out" | grep -qE "Overall:.*(PASS|CONCERN)" && ! echo "$out" | grep -q "Overall:.*FAIL"

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

**Symptom:** Operator ran the T-2369 live-fire (lowered `FW_CONTEXT_WINDOW` to force
budget-critical) and the session did NOT auto-restart — continuous mode untestable via
the budget path.

**Root cause:** The budget-critical → restart chain has no terminator. `checkpoint.sh`
(PostToolUse) at critical commits a handover and writes `.context/working/.restart-requested`,
then `bin/claude-fw` is supposed to restart via `claude -c`. But the wrapper runs
`command claude` in the foreground and only checks the signal *after* claude exits
(`bin/claude-fw:146,162`). Nothing ends the *running* claude at critical: `checkpoint.sh`
(PostToolUse) cannot exit its parent, and `budget-gate.sh` (PreToolUse) only blocks the next
tool. So claude stays alive, the wrapper blocks, and the working restart-on-exit branch is
never reached.

**Why structurally allowed:** the loop was unit-tested per-leg (T-2363/2364/2365/2368) but the
budget-critical → session-end junction was only ever exercised by the COMPACTION path
(`/compact` ends the context itself, so the wrapper sees an exit). The budget path's terminator
was assumed ("wrapper will auto-restart on exit") but no component produces the exit — classic
D-058 ship-before-substrate-verified at the checkpoint↔wrapper seam.

**Prevention:** this fix adds the missing terminator AND pins it with
`tests/integration/claude_fw_restart_terminator.bats`: the "terminator fires" case proves an
alive claude at critical IS ended and restart fires; the opt-out case + CONTROL case bound the
behavior. The harness drives the REAL `bin/claude-fw` with a stub `claude` (no real tokens), so
any future regression of the terminator surfaces in CI/pre-push.

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

### 2026-06-13 — terminator targeting & kill discipline
- **What changed:** confirmed at build time that the wrapper's only direct children during a
  run are `claude` and the watcher itself, so `pgrep -P "$$"` minus the watcher's own PID
  yields exactly the claude process — no fragile `comm`-name matching needed.
- **Plan impact:** dropped the originally-planned `ps -o comm=` name filter (would have *missed*
  claude when its comm is `node`/truncated); kill the wrapper's direct child(ren)-except-self
  instead. Safer for the goal and provably non-spurious.
- **Triggered:** SIGTERM→grace→SIGKILL escalation added (interactive claude may defer SIGTERM
  while a foreground child runs); poll/grace made env-tunable (`FW_TERMINATOR_POLL`,
  `FW_TERMINATOR_GRACE`) so the bats harness runs in seconds.

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Recommendation

**Recommendation:** GO (merge + activate), pending the one live E2E Human AC.

**Rationale:** This closes the T-2372 root cause — the budget-critical auto-restart
that the operator reported "did not trigger". The terminator is implemented for both
execution modes with a start-time guard (edge case a) and a fail-safe opt-out. All 6
Agent ACs pass; the stub-driven harness proves the plain-mode fix end-to-end against
the REAL wrapper (alive claude → terminated → restart fires), with CONTROL + OPT-OUT
cases bounding the behavior. The only thing the harness cannot settle is the `/exit`
quit-timing against a *live* interactive claude — that is the single remaining
Human `[REVIEW]` AC, deliberately gated because `bin/claude-fw` is the highest-blast-radius
file in the system (T-954 irreversible-action class).

**Evidence:**
- `bin/claude-fw`: `_terminator_watch` (plain mode, SIGTERM→grace→SIGKILL) + TermLink
  poll-loop `/exit` inject + `run_start_epoch` guard + `FW_NO_TERMINATOR` opt-out.
- `tests/integration/claude_fw_restart_terminator.bats` 3/3: FIX / CONTROL / OPT-OUT.
- Reviewer R-1ace5d88 PASS (OV-0cbc85a8 suppresses one `human-ac-mechanical-signal` FP, 90d).
- `bash -n bin/claude-fw` clean.

**Live validation (Human):** `cd /opt/999-Agentic-Engineering-Framework && FW_CONTEXT_WINDOW=20000 bin/claude-fw --termlink` → work to critical → confirm auto-restart fires with no manual `/compact`. This is also the arc-012 G-062 headline-mechanic demo.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-06-13T14:42:12Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/arc012-continuous-run-s4s5/.tasks/active/T-2373-arc-012-add-budget-critical-terminator-t.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-31000675
- **Timestamp:** 2026-06-13T14:53:21Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

- **Suppressed:** 1 (by override)
  - human-ac-mechanical-signal @ AC#3 (Human)
