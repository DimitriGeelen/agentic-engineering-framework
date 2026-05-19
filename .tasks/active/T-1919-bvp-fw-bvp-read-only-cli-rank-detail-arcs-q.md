---
id: T-1919
name: "BVP T-NEW-4: fw bvp read-only CLI verbs (rank, detail T-<id>, arcs, --quadrant filter)"
description: >
  Read-only `fw bvp` CLI surface — computes BVP scores live from policy weights + task scores (D9 reactive). Composes 3-signal cost (blast_radius/tier/effort) per F8-mechanic and Q2 default.

status: captured
workflow_type: build
owner: agent
horizon: now
tags: [bvp, build, slice-4, cli]
components: [lib/bvp.sh, bin/fw]
related_tasks: [T-1915, T-1916, T-1918]
arc_id: value-prioritisation
created: 2026-05-19T07:00:00Z
last_update: 2026-05-19T07:00:00Z
date_finished: null
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
- [ ] `lib/bvp.sh` exists and exports the four read verbs above
- [ ] `bin/fw` routes `bvp` to `lib/bvp.sh`
- [ ] `fw bvp` outputs ranked task list, BVP desc, columns: T-ID | name | BVP | cost | quadrant
- [ ] `fw bvp T-<id>` outputs: per-driver scores (D1..Dn), per-driver weight, weighted total, 3-component cost (blast_radius / tier / effort separately + composite)
- [ ] `fw bvp arcs` outputs ranked arc list, global-driver-only (per D2)
- [ ] `fw bvp --quadrant hv-lc` filters; same for hv-hc, lv-lc, lv-hc
- [ ] Verbs are read-only — running them does NOT modify any file (verified by git status diff before/after)
- [ ] Cost composite uses 0.6/0.3/0.1 weights from F8; falls back to T-shirt S=2/M=4/L=6/XL=8 if blast_radius unavailable (Q2)

## Verification

test -f lib/bvp.sh
bin/fw bvp --help 2>&1 | grep -q quadrant
git_before=$(git status --short | wc -l); bin/fw bvp > /dev/null 2>&1 || true; git_after=$(git status --short | wc -l); [ "$git_before" = "$git_after" ]

## Decisions

## Updates
