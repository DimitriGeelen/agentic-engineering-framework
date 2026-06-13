---
id: T-2368
name: "arc-012 end-to-end continuous-loop integration test — drive resume->inject across multi-cycle + cap + ceiling"
description: >
  arc-012 end-to-end continuous-loop integration test — drive resume->inject across multi-cycle + cap + ceiling

status: started-work
workflow_type: test
owner: agent
horizon: now
tags: []
components: []
related_tasks: [T-2158, T-2363, T-2364, T-2365, T-2366, T-2367]
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
created: 2026-06-13T12:41:17Z
last_update: 2026-06-13T12:41:17Z
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

# T-2368: arc-012 end-to-end continuous-loop integration test — drive resume->inject across multi-cycle + cap + ceiling

## Context

arc-012's continuous-run loop has full per-component unit coverage
(`test_inject_next_directive.py` 40 tests, `t2366_discard_manifest.bats` 8,
`resume.bats`, `fw_resume.bats`) but **no test drives the chain end-to-end** —
the integration seam where `post-compact-resume.sh` invokes the injector,
captures its stdout, and folds the directive into the SessionStart
`additionalContext` JSON (post-compact-resume.sh:267-313) is unverified. This
is the exact "shipped before substrate-verified" pattern (D-058 / T-1641).

This task adds `tests/integration/continuous_loop.bats` that drives the **real**
`post-compact-resume.sh` (not a reimplementation) against a temp PROJECT_ROOT,
feeding SessionStart hook JSON on stdin, across multiple resume cycles plus the
two refusal modes (cap-termination, tier-ceiling freeze). It does NOT cover the
`claude-fw` process auto-restart junction (an interactive wrapper — operator-side
live demo, see arc headline_mechanic) — that boundary is documented, not mocked.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `tests/integration/continuous_loop.bats` exists and drives the real `agents/context/post-compact-resume.sh` (feeding SessionStart JSON on stdin, capturing the emitted `additionalContext` JSON) — not a reimplementation of the injector logic
- [x] Multi-cycle: running the resume hook 3× with continuous-mode `enabled: true` advances `current_iteration` 0→1→2→3 in `.continuous-mode.yaml` and surfaces a `## Next Directive (iteration N/...)` section each cycle
- [x] Cap-termination: at `current_iteration == max_iterations`, the next resume emits `## Next Directive — LOOP TERMINATED` and WITHHOLDS the directive body from auto-pickup (the counter records the over-cap attempt `new_iter`, per shipped spec — what the cap withholds is the directive, not the increment)
- [x] Tier-ceiling freeze (S5 end-to-end): a directive whose planned `next_task` resolves to a task with `cost_estimate.blast_radius > tier_ceiling` emits `## Next Directive — TIER CEILING EXCEEDED` and FREEZES `current_iteration` (counter unchanged through the real script)
- [x] Compact-reset: a SessionStart with `source: compact` resets `current_iteration` to 0 before the post-resume advance (fresh-loop semantics) — proves the manual `/compact` path through the real hook
- [x] `bats tests/integration/continuous_loop.bats` is green AND `python3 -m pytest tests/unit/test_inject_next_directive.py -q` still passes (no regression)

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
bats tests/integration/continuous_loop.bats
python3 -m pytest tests/unit/test_inject_next_directive.py -q
out=$(bin/fw reviewer T-2368 2>&1); echo "$out" | grep -qE "Overall:.*(PASS|CONCERN)" && ! echo "$out" | grep -q "Overall:.*FAIL"

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

### 2026-06-13 — integration seam surfaced two behaviors unit tests cannot

- **What changed:** Driving the *real* `post-compact-resume.sh` (vs the injector
  in isolation) exposed two facts the 40 unit tests never assert:
  1. **JSON `ensure_ascii` escaping.** The hook wraps the injector's section in
     `json.dumps(output)` (post-compact-resume.sh:303-313, default
     `ensure_ascii=True`), so the section headers' em-dash (`—`, U+2014) is
     escaped to `—` in the actual SessionStart output. The injector's raw
     stdout has the literal `—`; downstream consumers receive the escaped form.
     The integration assertions therefore key on ASCII substrings
     (`LOOP TERMINATED`, `TIER CEILING EXCEEDED`) — which is exactly what a real
     consumer greps. A unit test on the injector's stdout would pass on `—` and
     miss this.
  2. **Cap-termination advances the counter.** My filing assumed cap-termination
     froze the counter at the cap (symmetry with the S5 ceiling freeze). The
     shipped spec (unit test `test_loop_terminated_state_records_reason`,
     max=0 → current_iteration=1) advances `current_iteration` to `new_iter` on
     the over-cap attempt and *withholds the directive*. The ceiling case freezes
     (operator resumes the same iteration after sign-off); the cap case does not
     (the loop is done, not paused). AC#3 + t3 were corrected to assert reality.
- **Plan impact:** AC#3 reworded from "does NOT advance the counter past the cap"
  to "withholds the directive; counter records the over-cap attempt". No source
  change — this is a verify task; the asymmetry is by design, not a bug.
- **Triggered:** No new sub-task. Considered filing the cap/ceiling counter
  asymmetry as an OBS but it is intentional and documented in both injector code
  paths — not a defect.

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

### 2026-06-13T12:41:17Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/arc012-continuous-run-s4s5/.tasks/active/T-2368-arc-012-end-to-end-continuous-loop-integ.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b258d262
- **Timestamp:** 2026-06-13T12:48:50Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

- **Suppressed:** 1 (by override)
  - AC-verify-mismatch @ AC#1 (Agent)
