---
id: T-2403
name: "autonomous continuous-mode never arms: restart signal only written via blocked PostToolUse path"
description: >
  autonomous continuous-mode never arms: restart signal only written via blocked PostToolUse path

status: started-work
workflow_type: build
owner: agent
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
created: 2026-06-14T21:26:32Z
last_update: 2026-06-14T21:26:32Z
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

# T-2403: autonomous continuous-mode never arms: restart signal only written via blocked PostToolUse path

## Context

Autonomous continuous mode (arc-012) has never armed end-to-end in a real session — the loop never advances past `current_iteration: 1`. Across many sessions the four loop links were built and unit-tested (gauge T-2375/2377/2391/2392, signal T-2378, terminator T-2373, advance T-2376) and the directive was refreshed (T-2401), but the integrated `critical → restart → advance` chain has never fired. This task fixes the ACTUAL break, confirmed by code trace (see RCA), and proves it E2E.

**Confirmed not-the-cause (already working):** the gauge reads tokens and DETECTS critical correctly — seen live this session at the 20K window (`budget-gate` fired "SESSION WRAPPING UP … 650%"). The break is downstream of detection.

## Acceptance Criteria

### Agent
- [x] `budget-gate.sh` writes `.context/working/.restart-requested` on the critical-BLOCK path (the `exit 2` branch) — decoupled from the PostToolUse/handover path. **Evidence:** `_write_restart_signal` at `budget-gate.sh:53`, called at `:200` (fast path) + `:363` (slow path), both AFTER the `allowed`-class exit-0 check. bats tests 17-18 assert the file appears on block (Write + Bash).
- [x] The signal write is idempotent (budget-gate runs on every call) and does NOT fire on the `allowed` path — so a restart cannot be triggered mid-wrap-up (mid-commit/handover). **Evidence:** call sites sit after `if [ "$CMD_CLASS" = "allowed" ]; then exit 0; fi` (`:182`/`:345`); bats tests 19-21 assert NO signal on Read / git-commit / wrap-up-Write at critical; overwrite-cat is idempotent.
- [x] Normal operation is unbroken: `ok`/`warn`/`urgent` levels behave exactly as before; the gate still blocks correctly at critical; `bash -n agents/context/budget-gate.sh` clean. **Evidence:** `bash -n` clean; bats tests 1-3 (ok/warn/urgent) + 4,12 (critical still blocks) + 22-23 (ok/urgent write no signal) all PASS.
- [x] The restart-signal JSON shape matches what `checkpoint.sh:210-212` emits (timestamp, session_id, reason, tokens, optional `directive` fold from `.next-directive.yaml`) so `claude-fw` + `post-compact-resume` consume it identically. **Evidence:** helper emits the same field set + T-2363 directive fold; bats tests 24 (keys/session_id/tokens), 25 (directive present), 26 (directive absent) PASS.
- [x] Integration test drives a REAL critical state → asserts `.restart-requested` is written by budget-gate when the agent is blocked and makes no allowed call. **Evidence:** `tests/integration/budget_gate.bats` 26/26 PASS (10 new T-2403 tests), reviewer R-097ad1f4 PASS.

### Human
- [ ] [REVIEW] Observable live E2E: a real `claude-fw` session driven to critical (via TermLink, watched from outside) writes `.restart-requested` → terminator SIGTERMs claude → `claude -c` relaunches → `## Next Directive (iteration 2/5)` re-injects → `.continuous-mode.yaml current_iteration` ticks 1→2.
  **Steps:** 1) In an isolated worktree off master, `cd <wt> && bin/fw config set CONTEXT_WINDOW 20000`. 2) Spawn a real `claude-fw` session under TermLink (`termlink`/tmux), observe from a second terminal. 3) Have it make any general tool call → critical fires → watch for restart. 4) `grep current_iteration <wt>/.context/working/.continuous-mode.yaml`. 5) Revert `CONTEXT_WINDOW` to 300000.
  **Expected:** `current_iteration: 2` after the restart, with the iteration-2 directive block visible in the relaunched session. This IS the arc-012 G-062 headline-mechanic demo — capture the screen as the arc-close `--demo` artifact.
  **If not:** capture which link stalled (signal written? terminator fired? relaunch happened? advance ran?) and re-diagnose from that link.

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
bats tests/integration/budget_gate.bats
out=$(bin/fw reviewer T-2403 2>&1); echo "$out" | grep -q "Overall:.*PASS"

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

**Symptom:** Autonomous continuous mode never arms — the loop never advances past `current_iteration: 1` in a real session, despite all four loop links being built + unit-tested. Operator: "we are working on autonomous continuous mode, which is still not working."

**Root cause (confirmed by code trace, verified by reading the files):**
The restart signal `.context/working/.restart-requested` — the trigger the `claude-fw` terminator watches for — is written in exactly ONE place: `checkpoint.sh:210-212`, and only INSIDE the `if timeout … handover.sh --commit` *success* block (`checkpoint.sh:182`). `checkpoint.sh` is a **PostToolUse** hook → it only runs *after a tool successfully executes*. Meanwhile `budget-gate.sh:288-307` (PreToolUse) at critical **blocks** every general tool (`exit 2`) and writes only `.budget-status` (`:262`) — it NEVER writes the restart signal. So: at critical → general tool blocked → its PostToolUse never fires → `checkpoint` never writes the signal → terminator waits forever → no restart → iteration never advances. The signal only gets written by the accident of the agent making an *allowed* call (commit/handover/read) AND auto-handover succeeding AND the cooldown not suppressing it — which didn't happen in the live-fires.

**Why structurally allowed:** the signal-emit was coupled to the PostToolUse+handover-success path — the exact path that is shut off at critical. And every prior "fix" was unit-tested only; no test ever drove the full `critical → signal → terminator → restart → advance` chain end-to-end, so the dead-lock at link 1 was never observed. (Pairs the T-2389 finding "loop has NEVER fired E2E.")

**Prevention:** (a) write the restart signal from `budget-gate.sh` — the PreToolUse hook that *reliably* fires at critical (it is the thing detecting+blocking); (b) ship an E2E integration test that drives a real `critical → restart → advance` (observed from outside via TermLink) as the acceptance gate, so this class can never silently dead-lock again.

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

### 2026-06-14 — Where to write the restart signal (the fix-design fork)
- **Chose (proposed, confirm at implement-time):** write `.restart-requested` in `budget-gate.sh` on the **critical-BLOCK path only** (the `exit 2` branch at `:307`), NOT on the `allowed` path (`:289-291`).
- **Why block-path-only:** by the time the agent is being *blocked* on general tools at critical, it's effectively stuck/done — restarting then is correct. Writing on the *allowed* path would risk the terminator (5s poll) killing claude mid-commit/mid-handover. Block-path keeps the "wrap up, THEN restart" ordering.
- **Handover stays best-effort:** `claude -c` preserves the conversation on restart, and `post-compact-resume` re-injects the directive — so a missing handover degrades context quality but does NOT break the loop. Decoupling the signal from handover-success is the whole point.
- **Rejected — budget-gate generates the handover itself synchronously:** correct ordering but heavy (handover on a blocked tool call, and budget-gate runs on every call) — risks stalling the session. Revisit only if `claude -c` context loss proves unacceptable.
- **Rejected — leave it in checkpoint.sh + rely on agent wrap-up behavior:** that's the current fragile state; behavioral, not structural; it's what's been failing.
- **Caution — `budget-gate.sh` is the single highest-blast file** (gates every tool call). The signal-write must be wrapped so it can NEVER cause the gate to error/exit non-deterministically (e.g. `{ … ; } 2>/dev/null || true`); a bug here blocks ALL tools. Pin with the E2E test before close — do not ship unit-tested-only (that's how every prior round failed).

## Recommendation

- **Recommendation:** GO (merge to master, then run the live-fire Human AC)
- **Rationale:** This is the confirmed root-cause fix for "autonomous continuous mode never arms" — the restart signal is now emitted by the PreToolUse hook that reliably fires at critical, decoupled from the blocked PostToolUse/handover path that dead-locked link 1. All five Agent ACs pass with cited evidence; the highest-blast-radius caution (budget-gate gates every tool) is addressed (failure-wrapped helper, syntax-clean, normal ok/warn/urgent paths proven unbroken). Per the RCA, the one thing every prior round skipped — a test driving the real critical→signal behavior — now exists and passes.
- **Evidence:**
  - `agents/context/budget-gate.sh:53` `_write_restart_signal`, called at `:200` + `:363` (both after the allowed-class exit-0), wrapped `{ … } 2>/dev/null || true`.
  - `tests/integration/budget_gate.bats` — **26/26 PASS** (10 new T-2403 tests: signal on block path, none on allowed/ok/urgent, JSON shape + directive-fold parity with `checkpoint.sh:210-212`).
  - `bash -n` clean; reviewer **R-097ad1f4 PASS** (needs_human=no).
  - Commit `3e62fbc50` (worktree branch `worktree-arc012-continuous-run-s4s5`).
- **Remaining (Human AC):** the observable live-fire E2E (critical → terminator restart → `current_iteration` 1→2) — this is the arc-012 G-062 headline demo and is operator-side by nature (needs a real `claude-fw` session, fix merged to master first).

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-06-14T21:26:32Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/arc012-continuous-run-s4s5/.tasks/active/T-2403-autonomous-continuous-mode-never-arms-re.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-097ad1f4
- **Timestamp:** 2026-06-14T21:57:21Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
