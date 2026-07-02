---
id: T-2260
name: "arc-010 Slice 1B — activate framework-mcp baseline + wire probe_framework_tools()
  into orchestrator-mcp-scan.sh"
description: >
  arc-010 Slice 1B — activate framework-mcp baseline + wire probe_framework_tools()
  into orchestrator-mcp-scan.sh

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
unlocks_inception_decision:
  - T-2209:iw2-verb-scope
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-06-08T12:45:36Z
last_update: '2026-06-11T22:24:13Z'
date_finished: 2026-06-08T12:52:43Z
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
  - ts: '2026-06-11T22:24:13Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 0
      D4: 3
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=0
      (no-signal); D4=3 (body:portability-abstraction); F-RECALL=2 
      (body:lightly-promoted); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2260: arc-010 Slice 1B — activate framework-mcp baseline + wire probe_framework_tools() into orchestrator-mcp-scan.sh

## Context

arc-010 capability-overlay Slice 1B — second leg of Slice 1. Slice 1A (T-2258) shipped the canonical 22-verb classification at `policy/capability-overlay/tool-set.yaml`. This slice activates the **drift-defense scan extension** prepared by T-2256: strip `.draft` from the baseline file, add `probe_framework_tools()` + `probe_framework_gate_calls()` to `agents/audit/orchestrator-mcp-scan.sh`, emit `framework_findings:` in the LATEST YAML, and surface a `framework-mcp` line in `bin/fw audit`. Reads the manifest at `$FW_MCP_MANIFEST` (default `$FRAMEWORK_ROOT/agents/mcp/framework-mcp-manifest.json`) which doesn't yet exist — Slice 2 ships it. Scan must pass cleanly (status `pass`, exit 0) in the pre-Slice-2 state with manifest absent (EC-1 per T-2256 §8). All code-shape decisions are pre-committed in `docs/reports/T-2256-or-2-scan-extension-draft.md` §3-§9.

`unlocks_inception_decision: [T-2209:iw2-verb-scope]` (sibling of T-2258 — same decision, second leg).

## Acceptance Criteria

### Agent
- [x] `.context/audits/framework-mcp-baseline.yaml.draft` no longer exists; `.context/audits/framework-mcp-baseline.yaml` (no `.draft`) is in place with the same content shape (`baseline_count: 0`, three categories `gated`/`mutators_ungated`/`readonly_exempt` all with empty `tools:` lists)
- [x] `agents/audit/orchestrator-mcp-scan.sh` defines `probe_framework_tools()` and `probe_framework_gate_calls()` (per T-2256 §3 sketch) and exposes the manifest path via the `FRAMEWORK_MCP_MANIFEST` env var, returning empty cleanly when the manifest doesn't exist (EC-1)
- [x] `agents/audit/orchestrator-mcp-scan.sh` hard-error refactor: scan exits 2 only when **both** termlink probe AND framework probe return empty (per T-2256 §5). With manifest absent but termlink reachable, scan proceeds.
- [x] `agents/audit/orchestrator-mcp-scan.sh` Python heredoc emits a `framework_findings:` key in `orchestrator-LATEST.yaml` with the parallel set-ops mirror of the termlink leg (status, gate_drop_outs, new_unclassified_tools, ratchet_candidates, gated_baseline, gated_current, total_current)
- [x] Running `bash agents/audit/orchestrator-mcp-scan.sh` exits 0 in the pre-Slice-2 state (manifest absent, baseline empty); `framework_findings.status` in `orchestrator-LATEST.yaml` equals `pass`
- [x] `agents/audit/audit.sh` orchestrator section surfaces a `framework-mcp` summary line (so `bin/fw audit` output contains a parseable framework-mcp status marker)
- [x] [REVIEWER] `bin/fw reviewer T-2260` returns Overall: PASS (no findings or only acceptable findings with documented rationale)
- [x] All existing tests still pass — `cd tests/unit && bats t2095_upgrade_self_vendor_extraction.bats` PASS as a regression net for the broader audit subsystem (T-2095 is the closest cross-cutting bats suite)

### Human
<!-- All ACs above are agent-verifiable. No Human AC needed for this slice. -->

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
test -f .context/audits/framework-mcp-baseline.yaml
! test -f .context/audits/framework-mcp-baseline.yaml.draft
grep -q "probe_framework_tools" agents/audit/orchestrator-mcp-scan.sh
grep -q "probe_framework_gate_calls" agents/audit/orchestrator-mcp-scan.sh
grep -q "FRAMEWORK_MCP_MANIFEST" agents/audit/orchestrator-mcp-scan.sh
grep -q "framework_findings" agents/audit/orchestrator-mcp-scan.sh
grep -q "framework-mcp scan" agents/audit/audit.sh
out=$(bash agents/audit/orchestrator-mcp-scan.sh 2>&1); echo "$out" | grep -q "Framework-mcp: pass"
python3 -c 'import yaml; d=yaml.safe_load(open(".context/audits/orchestrator-LATEST.yaml")); ff=d.get("framework_findings") or {}; assert ff.get("status")=="pass"; assert ff.get("manifest_present") is False'
audit_out=$(bin/fw audit --section orchestrator 2>&1); echo "$audit_out" | grep -q "framework-mcp scan: PASS"
( cd tests/unit && bats t2095_upgrade_self_vendor_extraction.bats ) > /tmp/T-2260-bats.log 2>&1 && ! grep -qE "^not ok" /tmp/T-2260-bats.log
reviewer_out=$(bin/fw reviewer T-2260 2>&1); echo "$reviewer_out" | grep -qE "Overall:.*(PASS|CONCERN)" && ! echo "$reviewer_out" | grep -q "Overall:.*FAIL"

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

### 2026-06-08T12:45:36Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2260-arc-010-slice-1b--activate-framework-mcp.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-380de09f
- **Timestamp:** 2026-06-08T12:52:46Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-08T12:52:43Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
