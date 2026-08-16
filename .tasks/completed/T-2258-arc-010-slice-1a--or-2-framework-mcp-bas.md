---
id: T-2258
name: "arc-010 Slice 1A — capability-overlay tool-set classification artefact"
description: >
  arc-010 Slice 1A — ship the canonical tool-set classification YAML
  (read-only, agent-authority, sovereignty-bound-excluded) consumed by
  Slice 1B (scan extension) and Slice 2 (framework MCP server).

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: [T-2209, T-2256]
arc_id: capability-overlay
unlocks_inception_decision: [T-2209:iw2-verb-scope]
created: 2026-06-08T12:15:22Z
last_update: '2026-08-16T22:24:59Z'
date_finished: 2026-06-08T12:24:09Z
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
      D2: 0
      D3: 0
      D4: 3
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=3 (body:portability-abstraction); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:59Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 3
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=3 (body:portability-abstraction); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2258: arc-010 Slice 1A — capability-overlay tool-set classification artefact

## Context

arc-010 (capability-overlay) ships in 4 slices per T-2209 §10/§12. Slice 1A produces the machine-readable tool-set classification that Slice 1B (orchestrator-mcp-scan extension, drafted in T-2256) and Slice 2 (framework MCP server process) both consume. T-2209 §3 has the curated minimal set in prose; this slice formalises it as `policy/capability-overlay/tool-set.yaml`. ~22 verbs total: ~16 read-only, ~6 agent-authority, with explicit sovereignty-bound exclusions documented.

This slice unblocks Slice 1B (scan needs a manifest to diff against) and Slice 2 (server needs a verb list to register). Both are separate tasks.

## Acceptance Criteria

### Agent
- [x] `policy/capability-overlay/tool-set.yaml` exists and parses cleanly as YAML
- [x] Tool-set contains exactly three top-level classes: `read_only:`, `agent_authority:`, `sovereignty_bound_excluded:`
- [x] Every entry in `read_only:` and `agent_authority:` has `{name, fw_command, description}` populated (no template stubs)
- [x] Every `fw_command` value names a real fw subcommand (resolves via the case dispatcher in `bin/fw`)
- [x] Sovereignty-bound exclusions documented with rationale (why each cannot be MCP-exposed today)
- [x] Reviewer scan returns PASS on T-2258 (R-9f761348 / 2026-06-08T12:22:24Z, 0 findings)

### Human

(none — pure design artefact, no rendering surface, no human-judgment AC. All verification is structural.)

## Verification

# File exists (covers AC#1 directly — AC-verify-mismatch detector wants the literal path named).
test -f policy/capability-overlay/tool-set.yaml
# Schema + verb-resolution validator. Helper lives in tests/unit/ (P-011 parses Verification
# line-by-line; heredocs would be split into per-line shell commands).
out=$(python3 tests/unit/test_capability_overlay_toolset.py 2>&1); echo "$out" | grep -q "^OK$"
# Reviewer PASS or CONCERN (FAIL blocks completion). L-387-safe: capture-then-grep.
out=$(bin/fw reviewer T-2258 2>&1); echo "$out" | grep -qE "Overall:.*(PASS|CONCERN)" && ! echo "$out" | grep -q "Overall:.*FAIL"

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

### 2026-06-08 — scope refined from "OR-2 scan extension" to "tool-set classification artefact"

- **What changed:** Initial filing title was "OR-2 framework MCP baseline scan extension" per T-2256 pre-stage. On planning, the OR-2 scan reads from a manifest that doesn't exist yet (Slice 2 hasn't built the MCP server). Shipping the scan in isolation = dead code until Slice 2 lands. Higher-leverage Slice 1A: ship the tool-set classification YAML that BOTH Slice 1B (scan) AND Slice 2 (server) consume. Scope flipped from "the scan reading a manifest" → "the manifest itself".
- **Plan impact:** T-2256's pre-stage draft (probe_framework_tools() bash + framework-mcp-baseline.yaml.draft) remains valid Slice 1B scope, not Slice 1A. Slice 1B will rename `.draft` and read from this YAML's `read_only:` + `agent_authority:` lists. Slice 2 builds the MCP server from this same manifest.
- **Triggered:** No new task; T-2256's pre-stage artefacts stay parked for Slice 1B authoring. T-2258 ships the canonical machine-readable verb classification.

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

### 2026-06-08T12:15:22Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2258-arc-010-slice-1a--or-2-framework-mcp-bas.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-9450aa41
- **Timestamp:** 2026-06-08T12:24:10Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-08T12:24:09Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
