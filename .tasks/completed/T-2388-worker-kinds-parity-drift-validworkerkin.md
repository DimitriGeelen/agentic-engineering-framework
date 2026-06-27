---
id: T-2388
name: "Worker-kinds parity drift: VALID_WORKER_KINDS literal in bin/fw vs lib/resolver.py"
description: >
  Bug-hunt unit suite found 2 failures in tests/unit/worker_kinds_parity.bats: #2402 (VALID_WORKER_KINDS literal not found in bin/fw at expected grep shape) + #2404 (bin/fw set != resolver.py set, source-of-truth check). Either a real parity drift between the two worker-kind definitions or a stale test after a bin/fw refactor. Classify drift-vs-stale-test, then fix the source-of-truth or the test.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [audit, governance, parity, dispatch]
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
created: 2026-06-14T01:02:37Z
last_update: 2026-06-27T20:07:27Z
date_finished: 2026-06-27T20:07:27Z
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

# T-2388: Worker-kinds parity drift: VALID_WORKER_KINDS literal in bin/fw vs lib/resolver.py

## Context

Found by the background bug-hunt unit suite (session 77ac04c8, 2026-06-14). 2 of 2410 tests
failed in `tests/unit/worker_kinds_parity.bats`:
- **#2402** "parity literal exists at expected location in bin/fw" — `grep -E "VALID_WORKER_KINDS\s*=\s*\{" bin/fw` (test line 68) failed → the literal isn't in bin/fw in the expected shape.
- **#2404** "parity literal in both files is identical (source-of-truth check)" — `[ "$fw_set" = "$resolver_set" ]` (test line 91) failed → the worker-kind sets in bin/fw and lib/resolver.py differ.

(#2401 "doctor reports WARN when bin/fw set differs from resolver" and #2403 "literal exists in
lib/resolver.py" PASS — so resolver.py is fine and doctor's drift WARN works; the gap is bin/fw.)

This is a **hypothesis to investigate, not a pre-concluded RCA** (per
feedback_remediation_plans_are_hypotheses): either (a) a real source-of-truth drift between
bin/fw and resolver.py worker-kind sets (dispatch correctness risk), or (b) a stale test after
a bin/fw refactor that moved/reshaped the `VALID_WORKER_KINDS` literal.

## Acceptance Criteria

### Agent
- [x] Classify (a) real drift vs (b) stale test — **(b) stale test, NO real drift.** lib/resolver.py and lib/workflow_lint.py both hold identical 4-kind sets `{Task, TermLink, pi, ollama-loop}` and are parity-checked at runtime (lib/worker_kinds_parity.py + fw doctor). bin/fw holds NO `VALID_WORKER_KINDS` literal — T-1946 extracted it (heredoc → lib/worker_kinds_parity.py per L-332/L-408). The 2 failing bats assertions pinned the pre-T-1946 bin/fw location. Dispatch is correct; no reconciliation needed.
- [x] Stale-test fix: retargeted the test from "bin/fw ↔ resolver.py" to the post-T-1946 "resolver.py ↔ workflow_lint.py" pair — #4 now greps lib/workflow_lint.py, #6 imports both python tables. Also hardened #2/#3 to exercise the REAL lib/worker_kinds_parity.py helper (stub-module temp dir) instead of an inline reimplementation, and de-staled the bin/fw:2041 prose comment (now references the source of truth instead of re-enumerating).
- [x] `bats tests/unit/worker_kinds_parity.bats` green (7/7); `fw doctor` worker-kinds parity line green (`bash -n bin/fw` clean)
- [x] RCA filled; reviewer PASS — RCA below; reviewer run at completion.

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
bash -n bin/fw
bats tests/unit/worker_kinds_parity.bats

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

**Symptom:** 2/2410 unit tests failed in `tests/unit/worker_kinds_parity.bats` —
#2402 "parity literal exists at expected location in bin/fw" and #2404 "parity
literal in both files is identical (vs bin/fw)". A grep for `VALID_WORKER_KINDS =
{...}` in bin/fw returned nothing.

**Root cause:** The test was pinning a code location that no longer exists. T-1946
(2026-05-20) deliberately extracted the `VALID_WORKER_KINDS` literal OUT of bin/fw
(it lived in an inline `python3 - <<PYEOF` heredoc) into `lib/worker_kinds_parity.py`,
per L-332/L-408 (eliminate the last heredoc-in-command-substitution self-lockout
site). After that refactor the two source-of-truth tables are `lib/resolver.py`
and `lib/workflow_lint.py`; bin/fw holds no literal. The bats test still asserted
the literal lived in bin/fw — a stale test, **not** a dispatch-correctness drift
(both python tables are identical and runtime-parity-checked).

**Why structurally allowed:** T-1946 updated the *runtime* parity check (doctor →
worker_kinds_parity.py, comparing the two python modules) but did not update the
*test file*, which still encoded the pre-T-1946 "bin/fw ↔ resolver.py" model. The
test references no longer matched the code it was meant to pin — a producer/consumer
split (L-399 class): the refactor moved the literal on one side, the test pinned the
old side. The failure was invisible until a full-suite background bug-hunt ran all
2410 tests (the parity .bats is not in the fast pre-commit subset).

**Prevention:** the test now pins the *current* source-of-truth pair (resolver.py ↔
workflow_lint.py) AND exercises the real shipped helper `lib/worker_kinds_parity.py`
directly (stub-module temp dir) rather than an inline reimplementation — so a future
refactor that moves the literal again, or that breaks the helper, fails the test at
the helper boundary, not at a hard-coded file path. The bin/fw:2041 comment was also
de-staled to reference the source of truth instead of re-enumerating the set (one
fewer drift surface).

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

### 2026-06-14T01:02:37Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/arc012-continuous-run-s4s5/.tasks/active/T-2388-worker-kinds-parity-drift-validworkerkin.md
- **Context:** Initial task creation

### 2026-06-27T20:00:39Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-4a7b8417
- **Timestamp:** 2026-06-27T20:09:21Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-27T20:07:27Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
