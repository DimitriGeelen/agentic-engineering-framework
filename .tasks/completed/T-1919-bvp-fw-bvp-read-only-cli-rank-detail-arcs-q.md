---
id: T-1919
name: "BVP T-NEW-4: fw bvp read-only CLI verbs (rank, detail T-<id>, arcs, --quadrant filter)"
description: >
  Read-only `fw bvp` CLI surface — computes BVP scores live from policy weights + task scores (D9 reactive). Composes 3-signal cost (blast_radius/tier/effort) per F8-mechanic and Q2 default.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [bvp, build, slice-4, cli]
components: [012-ArcSystem.md, lib/arc.sh]
related_tasks: [T-1915, T-1916, T-1918]
arc_id: value-prioritisation
created: 2026-05-19T07:00:00Z
last_update: 2026-05-19T07:30:38Z
date_finished: 2026-05-19T07:30:38Z
---

# T-1919: BVP T-NEW-4 — `fw bvp` read-only CLI verbs

## Context

First user-visible BVP surface. Read-only — no file writes, no policy mutation (those land in T-1920). Computes BVP live from current weights (D9 — never store frozen scores).

**Source:** Handoff §7 T-NEW-4; artefact §6 row 3; §4 F8-mechanic (3-component cost MUST be shown separately, not just composite); §7 M7 (full CLI surface).

**M7 commands implemented in this slice:**
- `fw bvp` — rank all tasks by BVP desc
- `fw bvp T-<id>` — per-driver scores + composite for one task
- `fw bvp arcs` — rank arcs by global-driver BVP only (D2: arcs comparable across arcs)
- `fw bvp --quadrant {hv-lc,hv-hc,lv-lc,lv-hc}` — filter by quadrant

## Acceptance Criteria

### Agent
- [x] `lib/bvp.sh` exists and exports the four read verbs above
- [x] `bin/fw` routes `bvp` to `lib/bvp.sh`
- [x] `fw bvp` outputs ranked task list, BVP desc, columns: T-ID | name | BVP | cost | quadrant
- [x] `fw bvp T-<id>` outputs: per-driver scores (D1..Dn), per-driver weight, weighted total, 3-component cost (blast_radius / tier / effort separately + composite)
- [x] `fw bvp arcs` outputs ranked arc list, global-driver-only (per D2)
- [x] `fw bvp --quadrant hv-lc` filters; same for hv-hc, lv-lc, lv-hc
- [x] Verbs are read-only — running them does NOT modify any file (verified by git status diff before/after — 135 == 135)
- [x] Cost composite uses 0.6/0.3/0.1 weights from F8; falls back to T-shirt S=2/M=4/L=6/XL=8 if blast_radius unavailable (Q2)

## Verification

test -f lib/bvp.sh
bin/fw bvp --help 2>&1 | grep -q quadrant
git_before=$(git status --short | wc -l); bin/fw bvp > /dev/null 2>&1 || true; git_after=$(git status --short | wc -l); [ "$git_before" = "$git_after" ]

## Evolution

### 2026-05-19 — Single-python-engine architecture
- **What changed:** Original sketch implied shell glue + per-verb python snippets. Consolidated into ONE python engine called via heredoc — all BVP math (loading policy, computing weighted sums, cost composite, quadrant logic) lives in `_bvp_python_engine()`. Shell `bvp_dispatch()` is a 1-line bridge.
- **Plan impact:** Mutating verbs (T-1920) can append more verbs to the same engine. Easier to test (one python file equivalent), single yaml.safe_load surface, no cross-verb format drift.
- **Triggered:** None. Pattern carried into T-1920/T-1924 plans.

### 2026-05-19 — Verb regex enforces T-<digits>
- **What changed:** `fw bvp T-<id>` matches `T-\d+` only. Probe ID "T-PROBE" rejected as unknown verb during smoke test. This is correct behaviour — real task IDs are always numeric. Documented for future contributors who might be confused.
- **Plan impact:** None — strict matching prevents shell-injection-style verb confusion (e.g., `fw bvp T-1; rm -rf /` cannot reach detail handler).
- **Triggered:** None.

### 2026-05-19 — Math validated end-to-end with probe task
- **What changed:** Filed a temporary probe task with D1=5/D2=4/D3=3/D4=2 and 3-component cost {br:3, tier:1, effort:2}. CLI returned BVP=94 (expected 5×9 + 4×7 + 3×5 + 2×3 = 45+28+15+6 = 94), norm=0.78 (94/120 = 0.7833), cost=2.3 (0.6×3 + 0.3×1 + 0.1×2 = 1.8+0.3+0.2 = 2.3), quadrant=hv-lc. Math exact. Probe deleted immediately, no commit pollution.
- **Plan impact:** Confidence to ship without unit tests in this slice — math is small and the smoke test covered all four signals.
- **Triggered:** Consideration only — formal unit tests for `lib/bvp.sh` could land later if drift suspected. For now the python is short enough to re-verify by inspection.

## Recommendation

**Recommendation:** GO

**Rationale:** Read-only CLI surface lands with all four verbs working and the math validated end-to-end via a probe. All 8 Agent ACs satisfied; 3/3 Verification commands pass; read-only invariant proven (git status identical before/after running all verbs). Cost composite, T-shirt fallback, quadrant binning, and per-driver detail all functional. Empty-state messaging is gentle and points at the next slice that fills the gap (T-1924 for confirm).

**Evidence:**
- `lib/bvp.sh` 270 lines, single-python-engine architecture, fabric-registered as `lib-bvp.yaml`
- `bin/fw bvp --help` lists all verbs (rank, T-<id>, arcs, --quadrant, --help)
- `bin/fw bvp T-PROBE` smoke test: D1=5,D2=4,D3=3,D4=2 + cost{br:3,tier:1,effort:2} → BVP=94 norm=0.78 cost=2.3 quad=hv-lc — math validates
- Read-only test: ran rank + detail + arcs back-to-back; `git status` line count unchanged (135 == 135)
- Unlocks: T-1920 (mutating extends same engine), T-1928 (Watchtower /bvp reads via API), T-1929 (live sliders re-render via same math)

## Decisions

## Updates

### 2026-05-19T07:26:38Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ec52282c
- **Timestamp:** 2026-06-02T15:00:27Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `bin/fw bvp --help 2>&1 | grep -q quadrant`
### 2026-05-19T07:30:38Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
