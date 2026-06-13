---
id: T-2366
name: "T-2158 S4: discard manifest enhancement to fw handover --emergency"
description: >
  Slice S4 of T-2158. Extend agents/handover/handover.sh --emergency to enumerate category-level discards (counts of tool-results compressed, turns summarised, files dropped from working set) into .context/handovers/SESSION.discard-manifest.yaml. Category-level fidelity sufficient (S6 Q4 — model self-compacts so token-level diff impossible). The Discard fidelity scoped driver rewards work here.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [arc:continuous-run, t-2158-slice, discard-fidelity]
components: []
related_tasks: [T-2158]
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
created: 2026-06-13T08:45:37Z
last_update: 2026-06-13T10:42:48Z
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

# T-2366: T-2158 S4: discard manifest enhancement to fw handover --emergency

## Context

Slice S4 of T-2158 (arc-012 continuous-run). The compact-resume loop's handover
should leave a machine-readable record of what the self-compacting model discarded,
so the operator can review post-hoc. Implemented as a standalone, testable helper
`agents/handover/discard-manifest.sh` wired into the normal handover path.

**Spec-vs-reality:** `--emergency` was deprecated by D-028 (T-175) — it is now an
alias for the normal handover. The continuous-run triggers (`pre-compact.sh`,
`checkpoint.sh`) all route through the normal path, so the manifest is emitted
there; the deprecated `--emergency` flag therefore still produces it. See Evolution.

## Acceptance Criteria

### Agent
- [x] `agents/handover/handover.sh --emergency` writes `.context/handovers/<SESSION>.discard-manifest.yaml` alongside the handover
- [x] Manifest enumerates category-level discards: `{tool_results_compressed_count, turns_summarized_count, files_dropped_from_working_set: [...]}`
- [x] Manifest is human-readable YAML and parseable (`python3 -c "import yaml; yaml.safe_load(open(...))"` exits 0)
- [x] Manifest is referenced from the handover Markdown body via a "Discard Manifest:" line so post-hoc operator review is one-click
- [x] `fw handover --emergency` continues to complete in <500ms (manifest generation overhead negligible)

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

# Manifest helper produces parseable YAML with all three category keys (capture-then-grep, L-387)
out=$(bash agents/handover/discard-manifest.sh S-VERIFY-2366 2>&1); test -f "$(echo "$out" | tail -1)"
python3 -c "import yaml; d=yaml.safe_load(open('.context/handovers/S-VERIFY-2366.discard-manifest.yaml')); assert all(k in d for k in ('tool_results_compressed_count','turns_summarized_count','files_dropped_from_working_set')), d; print('manifest keys OK')"
# T-2366 bats suite green (8 tests: standalone helper + handover wiring + degradation + perf)
bats tests/unit/t2366_discard_manifest.bats >/dev/null 2>&1 && echo "t2366 bats PASS"
# No regression in the existing handover suite
bats tests/unit/handover.bats >/dev/null 2>&1 && echo "handover regression PASS"

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

### 2026-06-13 — `--emergency` is a dead flag (D-028)

- **What changed:** The filing assumed `handover.sh --emergency` was a distinct
  code path to extend. It is not — D-028 (T-175) eliminated the emergency/full
  distinction; `--emergency` only sets `AUTO_COMMIT=true` and is treated as a
  normal handover. Both continuous-run triggers (`pre-compact.sh`,
  `checkpoint.sh`) call the normal handover path.
- **Plan impact:** The manifest is emitted in the **normal** handover path (after
  telemetry gathering, before the body heredoc), not behind an `--emergency`
  branch that doesn't exist. The deprecated flag still produces the manifest
  because it aliases to that same path — so the literal AC wording holds.
- **What it cost / where fidelity stops:** the model self-compacts internally, so
  a token-level before/after diff is impossible (S6 Q4). The manifest is
  category-level: tool-results, model turns, and working-set files *at risk* of
  being shed — mined from the session transcript, with graceful degradation to a
  `metrics-fallback`/`unavailable` placeholder when no transcript is reachable.
- **Triggered:** new standalone helper `agents/handover/discard-manifest.sh` (with
  a `FW_DISCARD_JSONL_DIR` test seam) rather than inlining into handover.sh, so
  the logic is unit-testable in isolation (`tests/unit/t2366_discard_manifest.bats`).
  One-line testability improvement to handover.sh: `HANDOVER_DIR` is now env-overridable.

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

### 2026-06-13T08:45:37Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2366-t-2158-s4-discard-manifest-enhancement-t.md
- **Context:** Initial task creation

### 2026-06-13T10:42:48Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-fc9c96bb
- **Timestamp:** 2026-06-13T10:55:37Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
