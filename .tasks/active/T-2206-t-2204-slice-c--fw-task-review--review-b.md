---
id: T-2206
name: "T-2204 Slice C — fw task review / review-batch refuses emission when inception has template-only Recommendation block"
description: >
  T-2204 Slice C — fw task review / review-batch refuses emission when inception has template-only Recommendation block

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
created: 2026-06-04T20:06:25Z
last_update: 2026-06-04T20:06:25Z
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

# T-2206: T-2204 Slice C — fw task review / review-batch refuses emission when inception has template-only Recommendation block

## Context

T-2204 GO Slice C (the consumer-side leg of the L-399 producer/consumer parity fix). Closes the gap where `fw task review T-XXX` and `fw task review-batch T-A T-B ...` emit `/inception/<id>` handoff URLs for inception tasks whose `## Recommendation` block is template-only or empty.

This complements T-2205 (Slice B, the producer-side Write/Edit hook): even if a producer slipped past the hook (or the hook isn't wired yet on a consumer project), this consumer-side gate prevents the operator-facing problem — the operator never sees a class-correct URL pointing at a blank decision form.

unlocks_inception_decision: [T-2204:slice-c]

## Acceptance Criteria

### Agent
- [x] `audit_inception_recommendation <task_file>` already exists in `lib/task-audit.sh:117` (T-1497). Returns 0 if Recommendation populated, 1 otherwise. Reused directly — no new function needed.
- [x] `emit_review` (`lib/review.sh:149-186`) wired to BLOCK on inception with empty Recommendation. Was WARNING (T-1215/T-1545); now exit 1 + block message naming bypass mechanism. Bypass: `FW_ALLOW_EMPTY_RECOMMENDATION=1` → NOTE + Tier-2 log + continue.
- [x] `emit_review_batch` (`lib/review.sh:291-380`) gained pre-pass: scans all inception members for empty Recommendation; refuses entire batch with named bypass on any failure; emits non-blocking NOTE + log when bypass set.
- [x] Bypass via `FW_ALLOW_EMPTY_RECOMMENDATION=1` env var — symmetric with T-2205 Slice B per T-1890 producer/consumer parity. `_log_empty_recommendation_bypass` helper writes to `.context/working/.gate-bypass-log.yaml`.
- [x] Block message names canonical fix path (edit Recommendation block with verdict+rationale) AND the env-var bypass.
- [x] Non-inception tasks pass through silently (audit guard inspects workflow_type first).
- [ ] Unit tests in `tests/unit/audit_inception_recommendation.bats` — **NOT YET WRITTEN (next session — Write tool blocked by budget critical 96%).** Will cover: non-inception passes, populated Rec passes, template-only blocks, FW_ALLOW_EMPTY_RECOMMENDATION=1 bypass, batch refuses on any failure, Tier-2 log entry on bypass.
- [x] Block-message stderr (agent-facing) names: (a) `FW_ALLOW_EMPTY_RECOMMENDATION=1` env-var bypass, (b) the canonical fix (edit Recommendation), (c) cross-refs T-679 / T-1715 / T-1716 / T-2204 / T-2205. Audience-axis-correct (T-2143) — agent-facing stderr stays ### Agent self-eval. Self-eval against `lib/review.sh:163-186` (emit_review block) and `lib/review.sh:328-357` (emit_review_batch block).

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

bats tests/unit/audit_inception_recommendation.bats
out=$(bin/fw reviewer T-2206 2>&1); echo "$out" | grep -q "Overall:.*PASS"

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

### 2026-06-04T20:06:25Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2206-t-2204-slice-c--fw-task-review--review-b.md
- **Context:** Initial task creation
