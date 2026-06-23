---
id: T-2467
name: "Worktree reliability slice 3 — vendored +x preservation + reassess T-2054/T-2462 safe-list exemptions"
description: >
  Preserve executable bit on vendored .agentic-framework/agents/**/*.sh (bare fw shim hits Permission denied). Reassess whether the T-2054/T-2462 git push/fetch/commit safe-list exemptions are still needed once slice-1 central resolver lands (IW-3, deferred). T-2464 GO Candidate C slice 3.

status: captured
workflow_type: build
owner: agent
horizon: later
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
created: 2026-06-23T13:09:08Z
last_update: 2026-06-23T13:09:08Z
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

# T-2467: Worktree reliability slice 3 — eliminate the hook-test +x dependency (live system is +x-independent)

## Context

T-2464 GO Candidate C, slice 3. RCA: `docs/reports/T-2464-worktree-reliability-rca.md`.

**Premise corrected at build time (2026-06-23):** the task was filed as "vendored +x
preservation" — but build-time investigation found the **live system never depends on the
executable bit**. Every hook in `.claude/settings.json` invokes `bin/fw hook <name>`, and
`bin/fw`'s dispatcher runs `bash "$_hook_script"` (bin/fw:6755,6760 — both branches). So
"preserving +x" solves a non-problem for production.

The *only* consumer of the +x bit was the **test suite**: 9 bats files invoked the wrapper as
a bare command (`echo … | $HOOK`), which requires +x. Worse, 7 of them guarded with
`[ -x "$HOOK" ] || skip "… not executable"` — so on a clean checkout (wrappers tracked 100644)
those tests **silently skipped**, giving zero coverage while looking green. That silent-skip is
the real defect; the +x churn (T-2468 surfaced it) was a symptom.

**Fix (Option B, not the filed Option A):** make the 9 test files invoke `bash "$HOOK"` —
matching the live dispatch exactly — and delete the silent-skip guards. This removes the +x
dependency entirely rather than perpetually maintaining +x across 66 wrapper files (Option A,
which would also need a new-wrapper regression check). Proven durable: with a wrapper
`chmod -x`'d, the suite still passes.

The **safelist reassessment (T-2054/T-2462)** that was bundled here is split to a follow-up —
it is independent governance judgment, not part of the +x finding.

## Acceptance Criteria

### Agent
- [x] All 9 hook-wrapper test files invoke via `bash "$HOOK"` (production parity — `bin/fw hook` always runs `bash "$_hook_script"`); zero bare-`$HOOK` command invocations remain
- [x] The `[ -x "$HOOK" ] || skip "… not executable"` guards removed from all 7 files — they silently skipped coverage on non-executable checkouts (the real defect masking the +x churn)
- [x] Proven durable: with a wrapper `chmod -x`'d, the suite still passes (62 tests across the 9 files, 0 failures, 0 skips)
- [x] Premise correction recorded (live system is +x-independent → Option B over filed Option A); safelist reassessment (T-2054/T-2462) split to follow-up

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
out=$(grep -rnE '\| +"?\$HOOK"?( |$)' tests/unit/check_inception_recommendation.bats tests/unit/tier0_idempotency.bats tests/unit/tier0_hash_normalization.bats tests/unit/check_tier0_comment_stripping.bats tests/unit/check_active_task_fp_fix.bats tests/unit/check_active_task_memory_exempt.bats tests/unit/check_active_task_switch_focus.bats tests/unit/test_check_active_task_bootstrap.bats tests/unit/inception_open_questions_gate.bats 2>/dev/null | grep -vE 'bash ' || true); [ -z "$out" ]
out=$(grep -rln 'not executable' tests/unit/check_inception_recommendation.bats tests/unit/tier0_idempotency.bats tests/unit/tier0_hash_normalization.bats tests/unit/check_tier0_comment_stripping.bats tests/unit/check_active_task_fp_fix.bats tests/unit/check_active_task_memory_exempt.bats tests/unit/check_active_task_switch_focus.bats tests/unit/test_check_active_task_bootstrap.bats tests/unit/inception_open_questions_gate.bats 2>/dev/null || true); [ -z "$out" ]
bats tests/unit/check_inception_recommendation.bats
bats tests/unit/tier0_idempotency.bats
bats tests/unit/tier0_hash_normalization.bats
bats tests/unit/check_tier0_comment_stripping.bats
bats tests/unit/check_active_task_fp_fix.bats
bats tests/unit/check_active_task_memory_exempt.bats
bats tests/unit/check_active_task_switch_focus.bats
bats tests/unit/test_check_active_task_bootstrap.bats
bats tests/unit/inception_open_questions_gate.bats

## RCA

**Symptom:** hook-wrapper bats tests (check-active-task, check-tier0, check-inception-*) appear
green locally but provide zero coverage on a clean checkout — they `skip` silently when the
wrapper `.sh` is tracked non-executable (100644, which 66 of 99 agent wrappers are). Surfaced
in T-2468 when a +x loss made check_inception_recommendation.bats fail with "Permission denied".

**Root cause:** the 9 test files invoked the wrapper as a bare command (`echo … | $HOOK`),
which requires the executable bit — even though the live system never does (`bin/fw hook`
dispatches via `bash "$_hook_script"`). 7 files then guarded with `[ -x "$HOOK" ] || skip`,
converting the missing-+x into a silent skip rather than a failure.

**Why structurally allowed:** the test invocation diverged from the production invocation. Live
dispatch is bash-always (+x-independent); tests were path-as-command (+x-dependent). Nothing
asserted the two matched, and the `|| skip` guard hid the divergence behind a green-looking run.

**Prevention:** tests now invoke `bash "$HOOK"` (production parity), guards removed. Regression
guard in `## Verification`: asserts no bare-`$HOOK` invocation and no `not executable` skip-guard
survives in the 9 files. Learning L-NEW: test invocation must match production invocation; a
`|| skip "not <capability>"` guard that depends on an environment property the production path
doesn't need is a silent-coverage trap.

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

### 2026-06-23T13:09:08Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/inception-gov-payload-mediation/.tasks/active/T-2467-worktree-reliability-slice-3--vendored-x.md
- **Context:** Initial task creation
