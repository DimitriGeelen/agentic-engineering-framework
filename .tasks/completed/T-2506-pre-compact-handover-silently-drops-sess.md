---
id: T-2506
name: "pre-compact handover silently drops session memory on missing exec bit"
description: >
  pre-compact handover silently drops session memory on missing exec bit

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [C-008, agents/context/pre-compact.sh, bin/fw]
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
created: 2026-07-06T09:18:30Z
last_update: '2026-08-16T22:25:08Z'
date_finished: 2026-07-06T09:32:05Z
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
  - ts: '2026-08-16T22:25:08Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 3
      D3: 2
      D4: 2
      F-RECALL: 1
      F-AUTONOMY: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=3 
      (body:component-silent-failure); D3=2 (body:default-change); D4=2 
      (body:env-class-handled); F-RECALL=1 (body:episodic-only); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=1 
      (body/components:context-fabric-incidental); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2506: pre-compact handover silently drops session memory on missing exec bit

## Context

The PreCompact hook (`agents/context/pre-compact.sh`) generates a handover before
`/compact` so the fresh session can be re-hydrated. In this worktree the vendored
`.agentic-framework/agents/handover/handover.sh` lost its exec bit (`-rw-rw-r--`),
and `FRAMEWORK_ROOT` resolved to the vendored tree, so the hook's
`"$FRAMEWORK_ROOT/agents/handover/handover.sh"` call died with **Permission denied**
(rc≈126). Result: `LATEST.md` was never updated, the stale prior handover got
reinjected every compaction, and the operator experienced "we keep losing memory."

The failure was recorded (`.pre-compact.handover.stderr`, `.compact-log` FAILED line,
per T-2374) but **surfaced nowhere** — `/compact` still reported success and `fw doctor`
was blind to it. This is the recurring exec-bit-loss-on-vendor class (OBS-087/OBS-090).

The structural fix makes handover capture **immune to a missing exec bit** (invoke via
the `bash` interpreter, which ignores the exec bit) AND makes the failure **visible**
(`fw doctor` WARN). Even if vendoring drops the exec bit again, memory capture no longer
silently fails.

## Acceptance Criteria

### Agent
- [x] AC1: `pre-compact.sh` invokes `handover.sh` via the `bash` interpreter (not bare exec), so a missing exec bit cannot drop the handover. Both the `--commit` and `--no-commit` branches.
- [x] AC2: Every other handover.sh invocation site reachable under compaction / budget-critical (notably `checkpoint.sh` auto-handover, T-179) is exec-bit-safe — audited, and any bare-exec in a hot path converted to interpreter-invoke. (`checkpoint.sh:182` converted; `bin/fw:4263` `exec` is the user-invoked `fw handover` — a missing bit there fails loudly to the operator, not silently, so out of the silent-memory-loss class.)
- [x] AC3: `fw doctor` emits a WARN when the last pre-compact handover FAILED (rc≠0 in `.compact-log`, or a non-empty `.pre-compact.handover.stderr`), naming the recovery.
- [x] AC4: Regression bats — mechanism proven (non-exec script runs via `bash`, fails via bare exec) + both call sites pinned to the `bash` form.
- [x] AC5: Regression bats — a seeded pre-compact FAILED marker makes `fw doctor` surface the WARN; a clean/absent state does not.

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

bash -n agents/context/pre-compact.sh
grep -Eq 'bash[^|]*handover\.sh' agents/context/pre-compact.sh
bats tests/governance/test_precompact_handover_robust.bats
out=$(bin/fw doctor 2>&1); echo "$out" | grep -q "handover"

## RCA

**Symptom:** After every `/compact`, the reinjected context was stale — it surfaced
old started-work tasks instead of the current session's work. To the operator this read
as "we keep losing memory."

**Root cause:** The PreCompact hook's handover step (`pre-compact.sh` invoking
`"$FRAMEWORK_ROOT/agents/handover/handover.sh"` **as an executable**) crashed with
`Permission denied` (rc≈126) because the vendored `.agentic-framework/agents/handover/handover.sh`
had lost its exec bit and `FRAMEWORK_ROOT` resolved to that vendored tree. handover.sh
never ran → `LATEST.md` was never repointed → the stale prior handover was reinjected.

**Why structurally allowed:** Two gaps compounded. (1) The hook invoked the script by
*direct exec*, which is exec-bit-dependent — an entirely avoidable fragility given the
recurring exec-bit-loss-on-vendor class (OBS-087/090). (2) The failure was recorded to
`.compact-log` / `.pre-compact.handover.stderr` (T-2374 removed the silent-success lie)
but **surfaced nowhere the operator or `fw doctor` would see it** — recorded ≠ surfaced.
So the framework's own memory-capture could fail indefinitely while reporting success.

**Prevention (distinct from the one-worktree chmod):**
1. `pre-compact.sh` invokes handover via `bash <script>` — interpreter invocation ignores
   the exec bit, so this class can never again drop a handover (antifragile, Directive 1).
2. `fw doctor` WARNs on a failed last pre-compact handover — converts the silent
   `.compact-log` FAILED line into a surfaced signal (Directive 2, no silent failures).
3. Regression bats pin both: exec-bit-stripped handover still captures (AC4); seeded
   failure surfaces the doctor WARN (AC5).
4. Gap registered (exec-bit-loss-on-vendor recurrence + recorded-not-surfaced class).

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

### 2026-07-06T09:18:30Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/t100199-close/.tasks/active/T-2506-pre-compact-handover-silently-drops-sess.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-63909b7f
- **Timestamp:** 2026-07-06T09:33:22Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-07-06T09:32:05Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
