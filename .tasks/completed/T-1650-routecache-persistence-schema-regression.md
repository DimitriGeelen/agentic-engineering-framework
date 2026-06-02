---
id: T-1650
name: "route_cache persistence-schema regression test (framework-side pin)"
description: >
  W10 #5 — route_cache.json on-disk schema can drift via `#[serde(rename)]` without
  notice; deserialization would silently fail and produce a cold cache on every
  restart. Framework-side half: parse RouteCache / RouteCacheEntry / ModelStats /
  LearnedFrom from /opt/termlink/crates/termlink-hub/src/route_cache.rs, pin the
  field set in tests/fixtures/, fail the contract test on rename. Cross-repo half
  (add a version tag inside the on-disk JSON + refuse-and-rebuild on mismatch)
  filed as TermLink push to termlink-agent. Origin:
  docs/reports/T-1641-worker-10-defenses.md item #5.

status: work-completed
workflow_type: test
owner: agent
horizon: null
tags: [from-T-1641, t-1061-followup, drift-defense, termlink, contract]
components: [tests/fixtures/termlink-route-cache-schema.json, tests/unit/test_termlink_route_cache_schema.py]
related_tasks: [T-1641, T-1644, T-1064, T-1065, T-1648, T-1651]
arc_id: orchestrator-rethink
created: 2026-05-01T12:20:27Z
last_update: 2026-05-01T18:58:38Z
date_finished: 2026-05-01T13:07:42Z
---

# T-1650: route_cache persistence-schema regression test

## Context

T-1064/T-1065 introduced a persistent route_cache.json on the hub side. The
schema is governed by serde derives — a `#[serde(rename = "x")]` or removal
silently produces a deserialization error at startup → empty cache → cold
router → no specialist routing.

Framework-side defense: pin the field set against the Rust source. Companion
to T-1648 (governance frame contract) and T-1651 (list --json contract).

## Acceptance Criteria

### Agent
- [x] `tests/fixtures/termlink-route-cache-schema.json` exists, listing the field set for RouteCache, RouteCacheEntry, ModelStats, RequestSchema, LearnedFrom variants
- [x] `tests/unit/test_termlink_route_cache_schema.py` exists and uses pytest
- [x] Test parses /opt/termlink/crates/termlink-hub/src/route_cache.rs and asserts each pinned struct retains its fields
- [x] Test asserts LearnedFrom enum still has Orchestrator + Builtin variants
- [x] Test skips gracefully when /opt/termlink not present
- [x] Test passes against current upstream HEAD
- [x] TermLink push delivered to termlink-agent with the version-tag-and-refuse-rebuild proposal (cross-repo half)

## Verification

test -f tests/fixtures/termlink-route-cache-schema.json
python3 -c "import json; d=json.load(open('tests/fixtures/termlink-route-cache-schema.json')); assert 'RouteCacheEntry' in d['structs']"
test -f tests/unit/test_termlink_route_cache_schema.py
python3 -m pytest tests/unit/test_termlink_route_cache_schema.py -v --tb=short

## RCA

**Symptom:** route_cache.json has no on-disk schema version. A serde rename or field removal in /opt/termlink would land at master, ship, then on next hub restart deserialize fails → cold cache → no specialist routing → orchestrator-arc invisibly degrades.

**Root cause:** The persistence layer uses serde defaults without a version tag, so the only signal of a schema change is "deserialization fails." Hub treats deserialize failure as "no cache yet" and starts cold — silent.

**Why structurally allowed:** No framework-side contract test pinning the schema. Cross-repo dependency (W10 #8 → T-1652) but no assertion (T-1652 is documentation, not contract).

**Prevention:** This task pins the schema from framework side via source-parse — parallels T-1648's approach for FrameType. Cross-repo proposal (version tag + refuse-and-rebuild) sent to termlink-agent so the hub itself learns to detect the drift instead of silently failing.

## Decisions

### 2026-05-01 — Source-parse over compile-and-link

- **Chose:** Same pattern as T-1648 — Python regex parses Rust source for `pub <field>:` lines and `pub enum X { ... }` variants. No Rust toolchain dependency.
- **Why:** Cheap, framework-native, catches the only failure modes that matter (rename, removal, variant deletion).
- **Rejected:** (a) Compile a smoke test against termlink-hub crate — heavy. (b) Persist a real cache and reload — flaky.

## Updates

### 2026-05-01T15:30:00Z — promoted-and-scoped [agent]
- **Action:** Promoted horizon later→now, status captured→started-work.
- **Context:** Continuing Arc C (T-1644) drift defenses per autonomous-mode directive.
- **Scope split:** Framework-side schema pin in this task; cross-repo version-tag proposal sent via TermLink to termlink-agent.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-43e3b4ed
- **Timestamp:** 2026-06-02T14:58:53Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** yes
- **Findings:** 1

**Per-AC findings:**

- **AC#3 (Agent)** — Test parses /opt/termlink/crates/termlink-hub/src/route_cache.rs and asserts each pinned struct retains its fields
  - **AC-verify-mismatch** (narrow, heuristic) — `path=opt/termlink/crates/termlink-hub/src/route_cache.rs in: Test parses /opt/termlink/crates/termlink-hub/src/route_cache.rs and asserts each pinned struct retains its fields`

- **Layer-1 escalations:** 1
  1. **cross-project-blast** (medium) — Cross-project or cross-repo change
     - matched: `cross-repo`
### 2026-05-01T13:07:42Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-05-01T18:58:38Z — status-update [task-update-agent]
- **Change:** tags: +arc:orchestrator-rethink
