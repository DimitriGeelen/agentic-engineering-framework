---
id: T-2291
name: "CLAUDE.md tool-set.yaml-touching tasks Verification rule (arc-010 sibling to
  cron)"
description: >
  CLAUDE.md tool-set.yaml-touching tasks Verification rule (arc-010 sibling to cron)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [arc-010, docs]
components: []
related_tasks: [T-2290, T-2265, T-2258]
arc_id: capability-overlay
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
created: 2026-06-09T16:51:47Z
last_update: '2026-08-16T22:25:00Z'
date_finished: 2026-06-09T16:54:56Z
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
  - ts: '2026-06-11T22:24:14Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 3
      F-RECALL: 0
      F-ORCH: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=3 (body:portability-abstraction); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=1 (body/components:prompt-incidental); F1=0 (no-signal); 
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:00Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 3
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=3 (body:portability-abstraction); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=1 (body/components:prompt-incidental); F1=0 (no-signal); 
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2291: CLAUDE.md tool-set.yaml-touching tasks Verification rule (arc-010 sibling to cron)

## Context

T-2290 hardened doctor's MCP manifest stale-check to use content compare instead of raw mtime. The detection now reliably surfaces real drift between `policy/capability-overlay/tool-set.yaml` and `agents/mcp/framework-mcp-manifest.json`. Agents working on tool-set edits today have no documented Verification-block rule that pins this check — same gap that L-364 closed for cron-registry drift before §Cron-touching tasks landed in CLAUDE.md. This slice adds the sibling rule so agents writing tool-set edits structurally include the doctor content-check in their `## Verification`.

## Acceptance Criteria

### Agent
- [x] CLAUDE.md gains a `**Tool-set.yaml-touching tasks (T-2290, arc-010):**` paragraph adjacent to §Cron-touching tasks (after the T-1942+T-1943 closure line, before `### Task Lifecycle`)
- [x] The new paragraph specifies the trigger (edited `policy/capability-overlay/tool-set.yaml` OR `agents/mcp/manifest.py`) and the canonical Verification one-liner (`out=$(bin/fw doctor 2>&1); echo "$out" | grep -q "framework MCP " && ! echo "$out" | grep -q "manifest stale relative to tool-set.yaml"`)
- [x] The paragraph cross-references T-2290 (mtime → content compare) so readers know the check is now content-authoritative, not mtime-fragile
- [x] CLAUDE.md still parses cleanly — no Markdown syntax errors, headings unchanged at known offsets (§Cron-touching unchanged, §Task Lifecycle still at line ~204 after the insertion)

## Verification

# Markdown still parses; new paragraph anchor exists, doctor check is the canonical T-2290 form.
grep -q "Tool-set.yaml-touching tasks" CLAUDE.md
grep -q "T-2290, arc-010" CLAUDE.md
grep -qF 'out=$(bin/fw doctor 2>&1); echo "$out" | grep -q "framework MCP "' CLAUDE.md
# §Cron-touching section is unchanged (still preceded by L-364, T-1771, T-1942, T-1943 citation)
grep -q "Cron-touching tasks (L-364, T-1771, T-1942, T-1943)" CLAUDE.md
# Doctor itself still healthy
out=$(bin/fw doctor 2>&1); echo "$out" | grep -q "framework MCP " && ! echo "$out" | grep -q "manifest stale relative to tool-set.yaml"
# Reviewer (L-387 capture-first)
rev=$(bin/fw reviewer T-2291 2>&1); echo "$rev" | grep -qE "Overall:.*(PASS|CONCERN)"

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

### 2026-06-09 — arc-010 follow-on doc rule

- **What changed:** T-2290 made doctor's MCP drift signal content-authoritative (not mtime-fragile). The Verification one-liner is now stable enough to mandate. This slice adds the agent-facing rule in CLAUDE.md so the structural prevention chain (agent writes rule into Verification → P-011 runs it on close → drift caught) actually fires for tool-set edits.
- **Plan impact:** Documentation-only, no source edits beyond CLAUDE.md. Single insertion adjacent to §Cron-touching tasks (parallel structural shape).
- **Triggered:** None. The class is now closed at the agent-instruction surface for arc-010's tool-set drift; no further follow-on required this round.


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

### 2026-06-09T16:51:47Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2291-claudemd-tool-setyaml-touching-tasks-ver.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-151f898c
- **Timestamp:** 2026-06-09T16:56:46Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

- **Suppressed:** 1 (by override)
  - AC-verify-mismatch @ AC#2 (Agent)

### 2026-06-09T16:54:56Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
