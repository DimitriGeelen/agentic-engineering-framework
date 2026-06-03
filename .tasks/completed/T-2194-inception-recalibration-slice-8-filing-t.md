---
id: T-2194
name: "Inception recalibration Slice 8: filing-time placeholder check — Open Questions
  section non-empty + ≥1 declared question"
description: >
  T-2186 Slice 8. PreToolUse hook on Write/Edit to inception task files refuses if
  ## Open Questions section is missing, empty, or contains only template placeholders.
  Mirrors existing G-020 placeholder gate (build-task ACs) — the inception equivalent.
  Each question must carry the per-question shape from Slice 4 (prose + confidence
  + later-filled disposition + rationale slot). Bypass family: --skip-open-questions-check
  + FW_SKIP_OPEN_QUESTIONS_CHECK=1. Bats pin. Verification: hook refuses on placeholder/empty/missing
  Open Questions on inception; allows non-inception; allows well-filed inception;
  bypass works + log entry written.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [inception, gate, filing-time, T-2186-slice, placeholder-check]
components: []
related_tasks: [T-2186, T-2188, T-2190]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-06-02T22:05:27Z
last_update: 2026-06-03T05:30:33Z
date_finished: 2026-06-03T05:30:33Z
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
  - ts: '2026-06-02T22:15:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-06-02T22:15:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2194: Inception recalibration Slice 8: filing-time placeholder check — Open Questions section non-empty + ≥1 declared question

## Context

Filing-time mirror of G-020 for inceptions. When the active task is `workflow_type: inception` and its `## Open Questions` section contains zero filed `- **IW-N:**` questions (template-only or empty), Write/Edit on non-exempt source files is refused. The task file itself stays editable (under `.tasks/*` exempt path) so the agent can add questions to unblock. Bypass: `FW_ALLOW_INCEPTION_OPEN_QUESTIONS_DRIFT=1`. Builds on T-2190 which shipped the `## Open Questions` template section.

## Acceptance Criteria

### Agent
- [x] `agents/context/check-active-task.sh` extended with an inception-placeholder block: when the active task has `workflow_type: inception` AND its `## Open Questions` section exists but contains zero `- **IW-N:**` entries, source-file Write/Edit is blocked with exit 2 and a structured message naming the bypass mechanism and the unblock path (add ≥1 `- **IW-N:**` to the section).
- [x] Grandfather rule honoured: inceptions with NO `## Open Questions` section at all pass through (no block). Only the placeholder-with-no-IW case triggers the gate. Non-inception workflow types are exempt (build-task path already gated by G-020).
- [x] Bypass `FW_ALLOW_INCEPTION_OPEN_QUESTIONS_DRIFT=1` allows the write and writes a Tier-2 entry to `.context/working/.gate-bypass-log.yaml` naming the gate.
- [x] Bats test `tests/unit/inception_open_questions_gate.bats` pins: placeholder-only blocks, filed-IW passes, no-section grandfathered, non-inception exempt, bypass works + logs. All tests PASS (6/6, +1 over filed scope).
- [x] Reviewer agent scan (`bin/fw reviewer T-2194`) returns Overall: PASS (scan R-7abc0f55, 2026-06-03T05:29:53Z, findings: none).

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

bats tests/unit/inception_open_questions_gate.bats
out=$(bin/fw reviewer T-2194 --no-write 2>&1); echo "$out" | grep -q "Overall:.*PASS"
grep -q "Inception Open Questions readiness gate" agents/context/check-active-task.sh
grep -q "FW_ALLOW_INCEPTION_OPEN_QUESTIONS_DRIFT" agents/context/check-active-task.sh

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

### 2026-06-03 — extended check-active-task.sh in place rather than a new hook
- **What changed:** Original sketch implied a new dedicated PreToolUse hook (`check-inception-open-questions.{sh,py}`). On reading `check-active-task.sh` it was already the natural home — the G-020 build-readiness block sits at L482-507 and exempts inceptions explicitly. Adding a parallel inception block alongside is one file, one trace, one ordering rule (after Inception awareness, before G-020 build path). No `.claude/settings.json` change needed (the hook is already registered).
- **Plan impact:** Saved the `bin/fw hook-enable` round-trip and the enforcement-baseline refresh that T-2188 needed. Bats test target is the existing hook, not a new one.
- **Triggered:** None — kept slice scoped.

<!-- Evolution closed.
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

### 2026-06-02T22:05:27Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2194-inception-recalibration-slice-8-filing-t.md
- **Context:** Initial task creation

### 2026-06-03T05:24:16Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now

## Reviewer Verdict (v1.5)

- **Scan ID:** R-86e0a603
- **Timestamp:** 2026-06-03T05:30:36Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-03T05:30:33Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
