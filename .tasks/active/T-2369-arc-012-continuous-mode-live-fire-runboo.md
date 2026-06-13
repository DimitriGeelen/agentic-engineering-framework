---
id: T-2369
name: "arc-012 continuous-mode live-fire runbook — operator end-to-end test via claude-fw with lowered FW_CONTEXT_WINDOW"
description: >
  arc-012 continuous-mode live-fire runbook — operator end-to-end test via claude-fw with lowered FW_CONTEXT_WINDOW

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: []
related_tasks: [T-2158, T-2363, T-2364, T-2365, T-2366, T-2367, T-2368]
arc_id: continuous-run
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
created: 2026-06-13T12:51:52Z
last_update: 2026-06-13T12:58:49Z
date_finished: 2026-06-13T12:58:49Z
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

# T-2369: arc-012 continuous-mode live-fire runbook — operator end-to-end test via claude-fw with lowered FW_CONTEXT_WINDOW

## Context

arc-012's continuous-run loop is build-complete (S0–S5) and the resume→inject
leg is now covered by an automated integration test (T-2368). The ONE junction
that cannot be self-tested by an agent is the live `claude-fw` auto-restart
across multiple cycles — it requires an interactive session launched via the
`claude-fw` wrapper (this background job is not). That live multi-cycle run IS
the arc's `headline_mechanic` and the demo artefact G-062 requires to close the
arc.

This task ships an operator runbook (`docs/runbooks/arc-012-continuous-mode-live-fire.md`)
that makes the live test runnable in minutes: lowering `FW_CONTEXT_WINDOW` (e.g.
to 20000) makes checkpoint.sh's critical threshold (`window × 95%`) fire after a
short session instead of burning 285K tokens, so the operator can observe the
full self-compact → handover → auto-restart → resume → directive-inject loop
across ≥2 cycles. The operator's run of this runbook (Human [REVIEW] AC) produces
the closure demo.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `docs/runbooks/arc-012-continuous-mode-live-fire.md` exists with sections: Prerequisites, How the lowered-window trigger works, Step-by-step (enable continuous-mode → file directive → launch via `claude-fw` → observe), Expected observations, Success criteria (mapped to the arc headline_mechanic), and Teardown
- [x] Every command in the runbook is copy-pasteable per T-609/T-1257 (single-line, `cd /opt/999-Agentic-Engineering-Framework &&` prefixed, `bin/fw` form for this framework repo) and references only verified-existing verbs/flags per L-477 (`claude-fw`, `fw resume status`, `fw config set/get`, `FW_CONTEXT_WINDOW`, `.continuous-mode.yaml`, `.next-directive.yaml`)
- [x] Runbook maps success to the arc headline_mechanic explicitly: ≥2 iterations observed, `current_iteration` advancing in `.continuous-mode.yaml`, directive surfaced each cycle, NO operator relay between cycles, and the tier-ceiling refusal demonstrated as the bounded-autonomy stop
- [x] Runbook includes a Teardown section that restores `FW_CONTEXT_WINDOW`, sets `enabled: false` in `.continuous-mode.yaml`, and removes `.next-directive.yaml`
- [x] Verb-existence check passes: every `fw`/`claude-fw`/env reference in the runbook resolves (grep-confirmed against the codebase)

### Human
- [ ] [REVIEW] Operator runs the runbook end-to-end and observes a multi-cycle continuous session (this run IS the arc-012 closure demo for G-062)
  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && cat docs/runbooks/arc-012-continuous-mode-live-fire.md` — read the runbook
  2. Follow its Step-by-step section: enable continuous-mode, file a small directive, launch `FW_CONTEXT_WINDOW=20000 claude-fw`, and work a short interactive session until critical fires
  3. Observe ≥2 auto-restart cycles without relaying anything yourself between them
  4. After the run: `cd /opt/999-Agentic-Engineering-Framework && bin/fw resume status` and `cat .context/working/.continuous-mode.yaml`
  **Expected:** `current_iteration` advanced ≥2; the directive was surfaced in each resumed session; the session self-restarted via `claude-fw` with no manual relay; the tier-ceiling refusal fired when the planned next task's blast-radius exceeded the ceiling. Capture the terminal recording / `.continuous-mode.yaml` snapshots as the `--demo` artefact for `fw arc close continuous-run`.
  **If not:** note which junction stalled (checkpoint didn't fire → check `FW_CONTEXT_WINDOW` + `cat .context/working/.budget-status`; no restart → confirm you launched via `claude-fw` not `claude`; no directive → check `.next-directive.yaml` present and `enabled: true`) and report it — that's a real bug in the loop, file it.
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
test -f docs/runbooks/arc-012-continuous-mode-live-fire.md
for s in "Prerequisites" "trigger works" "Step-by-step" "Expected observations" "Success criteria" "Teardown"; do grep -qi "$s" docs/runbooks/arc-012-continuous-mode-live-fire.md || { echo "MISSING SECTION: $s"; exit 1; }; done
command -v claude-fw >/dev/null && grep -q "CONTEXT_WINDOW" agents/context/checkpoint.sh
bin/fw reviewer T-2369 > /tmp/.t2369-rev 2>&1; grep -qE "Overall:.*(PASS|CONCERN)" /tmp/.t2369-rev && ! grep -q "Overall:.*FAIL" /tmp/.t2369-rev

## Recommendation

**Recommendation:** GO

**Rationale:** The runbook is complete, accurate, and operator-ready. Every
referenced verb/flag is verified to exist (L-477), all six required sections are
present, and the mechanism it relies on (`FW_CONTEXT_WINDOW` → `TOKEN_CRITICAL =
window × 95%`) is confirmed in `checkpoint.sh:31`. Running it is the single
remaining step to a true end-to-end test of continuous mode — and the same run
produces the `--demo` artefact that `fw arc close continuous-run` requires
(G-062). There is no agent-side work left; this is a hand-off, not a deferral.

**Evidence:**
- `docs/runbooks/arc-012-continuous-mode-live-fire.md` — full runbook (commit `c8d18f936`).
- All 5 Agent ACs ticked; Verification 4/4 PASS at completion gate.
- Reviewer PASS, 0 findings (after fixing a real L-387 SIGPIPE risk in the section-check, not just suppressing it).
- Automated coverage already in place: `tests/integration/continuous_loop.bats` (6/6, T-2368) + `tests/unit/test_inject_next_directive.py` (40/40).
- The live `claude-fw` restart is the only un-automatable junction; the runbook makes it a minutes-long operator action.

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

### 2026-06-13 — runbook is the structural counter for the un-automatable junction

- **What changed:** Confirmed the live `claude-fw` auto-restart is the single
  loop junction that no agent can self-test from a background job (the wrapper
  acts on process *exit*, and a background job is not launched through it). The
  honest closure path is therefore: automate everything up to the restart
  (T-2368), then hand the operator a minutes-not-hours runbook for the restart
  itself. The enabling insight is that `FW_CONTEXT_WINDOW` moves
  `TOKEN_CRITICAL` (window × 95%) — set it to 20000 and the *entire* real loop
  fires after a few minutes of work, identical downstream to a 300K run.
- **Plan impact:** None — this was the planned shape. The operator's run of the
  runbook (the [REVIEW] Human AC) doubles as the G-062 `--demo` artefact, so the
  arc-close demo and the live test are the same action.
- **Triggered:** No new sub-task. arc-012 is now: build-complete (S0–S5) +
  resume-leg auto-tested (T-2368) + live-fire runbook (this) → ready for the
  operator live run → Sovereign `fw arc close`.

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

### 2026-06-13T12:51:52Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/arc012-continuous-run-s4s5/.tasks/active/T-2369-arc-012-continuous-mode-live-fire-runboo.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-49e71215
- **Timestamp:** 2026-06-13T12:58:51Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-13T12:58:49Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
