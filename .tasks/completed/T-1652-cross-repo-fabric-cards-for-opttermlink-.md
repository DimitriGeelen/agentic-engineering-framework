---
id: T-1652
name: "Cross-repo fabric cards for /opt/termlink orchestrator modules"
description: >
  W10 #8 — Component Fabric (485 cards, none for /opt/termlink orchestrator/router/
  fallback/governance-frame). Decision: extend fabric convention to include cross-repo
  components via a `cross_project: <name>` field; register 6 termlink-side
  orchestrator-arc components so blast-radius and dependency queries from the framework
  can see across the boundary. Origin: docs/reports/T-1641-worker-07-cross-arc.md +
  W10 item #8.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [from-T-1641, t-1061-followup, fabric, cross-repo]
components: []
related_tasks: [T-1641, T-1644, T-1064, T-1065, T-1066, T-1648]
arc_id: orchestrator-rethink
created: 2026-05-01T12:20:27Z
last_update: 2026-05-01T18:58:38Z
date_finished: 2026-05-01T13:02:52Z
---

# T-1652: Cross-repo fabric cards for /opt/termlink

## Context

T-1641 reconsideration surfaced: framework fabric maps 485 components, but zero of
them are the /opt/termlink modules our orchestrator arc actually depends on
(`router.rs`, `route_cache.rs`, `bypass.rs`, `circuit_breaker.rs`,
`termlink-protocol/governance.rs`, `governance_subscriber.rs`). Blast-radius
queries stop at the boundary — we cannot see what we depend on.

This task ships hand-crafted cards for those six components plus a
`cross_project:` convention so future additions follow the same pattern.

## Acceptance Criteria

### Agent
- [x] `.fabric/components/cross-repo-termlink-router.yaml` exists with `cross_project: termlink`
- [x] `.fabric/components/cross-repo-termlink-route-cache.yaml` exists
- [x] `.fabric/components/cross-repo-termlink-bypass.yaml` exists
- [x] `.fabric/components/cross-repo-termlink-circuit-breaker.yaml` exists
- [x] `.fabric/components/cross-repo-termlink-governance-frame.yaml` exists (termlink-protocol/governance.rs)
- [x] `.fabric/components/cross-repo-termlink-governance-subscriber.yaml` exists (T-1066's data plane subscriber)
- [x] All 6 cards parse as valid YAML and include `cross_project`, `cross_repo_url`, `purpose`, and at least one local `depended_by` edge to a framework component
- [x] `.fabric/CROSS-REPO-CARDS.md` documents the convention

## Verification

ls .fabric/components/cross-repo-termlink-*.yaml | wc -l | grep -q "^6$"
python3 -c "import yaml,glob; [yaml.safe_load(open(f).read()) for f in sorted(glob.glob('.fabric/components/cross-repo-termlink-*.yaml'))]"
python3 -c "import yaml,glob; assert all(yaml.safe_load(open(f).read()).get('cross_project')=='termlink' for f in sorted(glob.glob('.fabric/components/cross-repo-termlink-*.yaml')))"
python3 -c "import yaml,glob; assert all(yaml.safe_load(open(f).read()).get('cross_repo_url') for f in sorted(glob.glob('.fabric/components/cross-repo-termlink-*.yaml')))"
python3 -c "import yaml,glob; assert all(yaml.safe_load(open(f).read()).get('depended_by') for f in sorted(glob.glob('.fabric/components/cross-repo-termlink-*.yaml')))"
test -f .fabric/CROSS-REPO-CARDS.md

## Decisions

### 2026-05-01 — Cross-repo card convention

- **Chose:** Extend existing fabric YAML format with `cross_project: <name>` + `cross_repo_url:` fields. Card slug: `cross-repo-<project>-<module>.yaml`. No code change to `bin/fw fabric register` — cross-repo cards are hand-crafted (rare) and the convention is documented.
- **Why:** Keeps framework fabric authoritative for blast-radius queries while making external dependencies visible. Avoids the alternative (extending `register` to accept cross-repo paths) which would conflate "exists in this checkout" with "is a tracked dependency."
- **Rejected:** (a) Document boundary, no cards — leaves blast-radius blind. (b) Extend `register` to fetch cross-repo files — opens the door to filesystem coupling we don't want.

## Updates

### 2026-05-01T15:10:00Z — promoted-and-scoped [agent]
- **Action:** Promoted horizon later→now; chose Option A (extend convention) per the decision recorded above.

## Reviewer Verdict (v1.4)

- **Scan ID:** R-5e66a734
- **Timestamp:** 2026-05-01T13:02:53Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** yes
- **Findings:** 6

**Per-AC findings:**

- **AC#1 (Agent)** — `.fabric/components/cross-repo-termlink-router.yaml` exists with `cross_project: termlink`
  - **AC-verify-mismatch** (narrow, heuristic) — `path=fabric/components/cross-repo-termlink-router.yaml in: `.fabric/components/cross-repo-termlink-router.yaml` exists with `cross_project: termlink``
- **AC#2 (Agent)** — `.fabric/components/cross-repo-termlink-route-cache.yaml` exists
  - **AC-verify-mismatch** (narrow, heuristic) — `path=fabric/components/cross-repo-termlink-route-cache.yaml in: `.fabric/components/cross-repo-termlink-route-cache.yaml` exists`
- **AC#3 (Agent)** — `.fabric/components/cross-repo-termlink-bypass.yaml` exists
  - **AC-verify-mismatch** (narrow, heuristic) — `path=fabric/components/cross-repo-termlink-bypass.yaml in: `.fabric/components/cross-repo-termlink-bypass.yaml` exists`
- **AC#4 (Agent)** — `.fabric/components/cross-repo-termlink-circuit-breaker.yaml` exists
  - **AC-verify-mismatch** (narrow, heuristic) — `path=fabric/components/cross-repo-termlink-circuit-breaker.yaml in: `.fabric/components/cross-repo-termlink-circuit-breaker.yaml` exists`
- **AC#5 (Agent)** — `.fabric/components/cross-repo-termlink-governance-frame.yaml` exists (termlink-protocol/governance.rs)
  - **AC-verify-mismatch** (narrow, heuristic) — `path=fabric/components/cross-repo-termlink-governance-frame.yaml in: `.fabric/components/cross-repo-termlink-governance-frame.yaml` exists (termlink-protocol/governance.rs)`
- **AC#6 (Agent)** — `.fabric/components/cross-repo-termlink-governance-subscriber.yaml` exists (T-1066's data plane subscriber)
  - **AC-verify-mismatch** (narrow, heuristic) — `path=fabric/components/cross-repo-termlink-governance-subscriber.yaml in: `.fabric/components/cross-repo-termlink-governance-subscriber.yaml` exists (T-1066's data plane subscriber)`

- **Layer-1 escalations:** 1
  1. **cross-project-blast** (medium) — Cross-project or cross-repo change
     - matched: `cross-repo`

### 2026-05-01T13:02:52Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-05-01T18:58:38Z — status-update [task-update-agent]
- **Change:** tags: +arc:orchestrator-rethink
