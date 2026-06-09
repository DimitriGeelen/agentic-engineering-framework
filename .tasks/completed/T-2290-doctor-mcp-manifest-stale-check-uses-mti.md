---
id: T-2290
name: "doctor MCP manifest stale check uses mtime — false-positives on content-identical
  refresh (arc-010)"
description: >
  doctor MCP manifest stale check uses mtime — false-positives on content-identical
  refresh (arc-010)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [arc-010]
components: []
related_tasks: [T-2265, T-2258, T-2287]
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
created: 2026-06-09T15:21:10Z
last_update: 2026-06-09T16:33:27Z
date_finished: 2026-06-09T16:33:27Z
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
cost_estimate_proposed:
  - ts: '2026-06-09T15:30:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 7
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-06-09T15:30:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 3
      F-RECALL: 0
      F-ORCH: 0
    rationale: D1=2 (body:learning-ref); D2=0 (no-signal); D3=0 (no-signal); 
      D4=3 (body:portability-abstraction); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2290: doctor MCP manifest stale check uses mtime — false-positives on content-identical refresh (arc-010)

## Context

`bin/fw doctor` emits **WARN  framework MCP manifest stale relative to tool-set.yaml** whenever `tool-set.yaml -nt manifest.json` (mtime-based check at `bin/fw:1257`). The mtime comparison is unreliable — `git checkout`, `fw vendor self`, formatters, and `touch` all update mtime without changing content. Observed today: `manifest-show` md5 == on-disk md5, yet WARN fires.

Sibling pattern: cron-registry drift uses content/sha hashing (L-364 chain). This slice brings MCP manifest drift detection into parity. Three other `-nt` sites exist (`lib/build.sh:29`, `agents/context/loop-detect.sh:13`, `bin/fw:1513`) — all TypeScript build-cache checks where rebuilding-on-mtime is *correct* behaviour (cheap, idempotent). The MCP check is the only one driving an operator-facing WARN.

## Acceptance Criteria

### Agent
- [x] doctor check at `bin/fw:1257` uses content comparison (md5 of `manifest-show` stdout vs md5 of on-disk manifest), NOT raw mtime — mtime test stays as a cheap fast-path that *triggers* the content check
- [x] When `tool-set.yaml -nt manifest.json` but content matches (content-identical refresh class), doctor emits the existing OK line — no new WARN, no false positive
- [x] When `tool-set.yaml` content genuinely changes without `fw mcp emit-manifest` (real-stale class), doctor still emits the existing WARN with the same "Run: fw mcp emit-manifest" guidance
- [x] When manifest file is absent, doctor still emits the existing SKIP line (no regression on that branch)
- [x] New bats file `tests/unit/t2290_doctor_mcp_content_check.bats` covers all three legs: content-identical-mtime-newer → OK, content-changed → WARN, manifest-absent → SKIP. All tests PASS
- [x] Existing t2287 / sibling bats tests (`tests/unit/t2287_self_vendor_policy_subdir.bats`) still PASS — no regression

## Verification

# Pinned tests
bats tests/unit/t2290_doctor_mcp_content_check.bats
bats tests/unit/t2287_self_vendor_policy_subdir.bats
# Doctor passes with content-identical mtime drift
touch policy/capability-overlay/tool-set.yaml
out=$(bin/fw doctor 2>&1); echo "$out" | grep -q "framework MCP 22 tools" && ! echo "$out" | grep -q "manifest stale relative to tool-set.yaml"
# Reviewer (L-387 capture-first)
rev=$(bin/fw reviewer T-2290 2>&1); echo "$rev" | grep -qE "Overall:.*(PASS|CONCERN)"

## RCA

**Symptom:** doctor emits "framework MCP manifest stale relative to tool-set.yaml" WARN even when manifest content matches what `manifest-show` would emit. Verified by md5sum equality.

**Root cause:** the stale check at `bin/fw:1257` uses raw mtime (`-nt`), which is updated by any tooling that rewrites/touches `tool-set.yaml` regardless of whether content changed. Touch-without-content-change is common (git checkout, vendor-sync, formatter pass, IDE save).

**Why structurally allowed:** mtime is cheap to check but a poor proxy for content drift. The existing pattern in the codebase (cron registry) uses content hashing for the same drift class. This site was an outlier.

**Prevention:** content-hash gate (md5 of `manifest-show` vs on-disk file) is now the authoritative drift signal. Mtime stays as a cheap fast-path that *triggers* the content check, so we still avoid hashing on every doctor run. A bats test pins all three legs (false-positive cleared, real drift detected, absent state) to prevent silent regression.

## Evolution

### 2026-06-09 — arc-010 follow-on slice

- **What changed:** Discovered doctor's MCP manifest stale check is mtime-based (single site at `bin/fw:1257`), yields false positives whenever tool-set.yaml mtime advances without content change. Diff of `manifest-show` vs on-disk = empty (md5 equal), yet WARN fires.
- **Plan impact:** Single-site fix. No spec-vs-build divergence; this is a substrate hardening follow-on after arc-010 Slice 2 (T-2265) shipped the manifest contract.
- **Triggered:** This task. Sibling check at `bin/fw:1513` (TS src vs out) is *correct* mtime behaviour (rebuild on staleness, cheap+idempotent) — no parity change needed.


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

### 2026-06-09T15:21:10Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2290-doctor-mcp-manifest-stale-check-uses-mti.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-95451f44
- **Timestamp:** 2026-06-09T16:40:35Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-09T16:33:27Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
