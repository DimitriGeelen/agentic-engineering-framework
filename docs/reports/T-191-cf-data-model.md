# T-191: Component Fabric — Data Model (Phase 3)

## Prototype Summary

**10 component cards** across **2 subsystems** (learnings pipeline + budget management), tested against all 6 use cases.

## Storage Structure

```
.fabric/
  components/           # One YAML per component (10 cards)
    add-learning.yaml
    audit-yaml-validator.yaml
    budget-gate.yaml
    budget-status.yaml
    checkpoint.yaml
    context-dispatcher.yaml
    hook-config.yaml
    learnings-data.yaml
    learnings-route.yaml
    learnings-template.yaml
  subsystems.yaml       # 3 subsystem groupings
  watch-patterns.yaml   # 8 file patterns for drift detection
```

## Use Case Test Results

### UC-1 Navigate: PASS
- **Topic search** ("learnings"): grep across tags found 5 components in the cluster.
- **Point traversal** (from learning.sh): followed depends_on → F-001, then F-001 readers → C-003, C-004, C-005.
- **File:line references** present on all edges.

### UC-2 Impact: PASS
- **Transitive chain** from learning.sh: C-002 → F-001 → C-003 + C-004 + C-005.
- Full blast radius of 4 downstream components from 1 file change.
- Edge types (writes/reads) make the direction unambiguous.

### UC-3 UI Identify: PASS
- Interactive elements documented on learnings-template: `data_component`, `data_action`, `htmx` attributes, `api_endpoint`, `backend_effect`.
- Vertical chain visible: element → htmx → endpoint → effect.
- Only 1 interactive element on this page (navigation link). More complex pages will test this better.

### UC-4 Onboard: PASS
- Subsystem summary produced in 3 lines (~120 tokens for 3 subsystems).
- Scaled estimate: 15 subsystems × ~40 tokens = ~600 tokens. Fits in budget.
- Entry points documented for each subsystem.

### UC-5 Regress: PASS
- Simulated blast radius of commit touching learning.sh.
- Traversal: find component by file path → follow writes → follow readers. 4 downstream components.
- Implementation would need: parse git diff → look up components by location → traverse graph.

### UC-6 Completeness: PASS
- Watch patterns found **92 unregistered files** matching expected patterns.
- This is expected — we only registered 10 of ~100 components.
- Drift detection works: compares glob matches against registered locations.
- Shows the scale of full registration: ~100 component cards needed for AEF.

## Schema Findings

### What Worked Well
1. **One file per component** — easy to read, grep, git-diff. Agent reads only what it needs.
2. **Typed edges** (reads/writes/calls/triggers/renders/htmx) — unambiguous direction and coupling type.
3. **Soft coupling annotations** — `coupling: soft` + `coupling_note` documents the T-206 class of bugs.
4. **Shared constants callout** — TOKEN_WARN/URGENT/CRITICAL duplicated between budget-gate and checkpoint, visible in both cards.
5. **UI element model** — `data_component` + `data_action` + htmx chain documents the full vertical stack.

### What Needs Refinement
1. **Bidirectional edges are redundant** — `depends_on` in C-002 and `readers` in F-001 encode the same relationship. Should be stored once, derived the other direction. Otherwise drift between forward/reverse edges.
2. **Component ID assignment** — Manual C-XXX/F-XXX is error-prone. Need auto-assignment or use file path as canonical ID.
3. **"depended_by" section** — Requires knowing all consumers at registration time. Better to derive this from other cards' `depends_on` sections.
4. **Data file cards vs script cards** — Different enough to warrant separate schemas (writers/readers vs depends_on/depended_by). The current approach works but is inconsistent.
5. **Graduation pipeline (C-005)** — Referenced in learnings-data.yaml as a reader but has no component card of its own. It's a section within audit.sh, not a separate script. Sub-component granularity needed?

### Schema Decisions for Phase 4

Based on prototype evidence:

1. **Single-direction edges only.** Store `depends_on` in the consuming component. Derive `depended_by` at query time by scanning all cards. Eliminates bidirectional drift.
2. **File path as component ID.** Drop C-XXX/F-XXX numbering. Use `agents/context/lib/learning.sh` as the canonical identifier. Shorter aliases (C-002) as optional display names.
3. **Unified card schema.** One schema with optional sections (route, template_inheritance, interactive_elements, format, writers/readers). Type field determines which sections are relevant.
4. **Sub-component references.** When a component is a section within a file (e.g., YAML validation within audit.sh), reference as `agents/audit/audit.sh#yaml-validation` with line range.
5. **Auto-generation of subsystem summary.** `summary.md` generated from `subsystems.yaml` + component count. Not manually maintained.

## Scale Estimate

| Metric | Prototype | Full AEF |
|--------|-----------|----------|
| Component cards | 10 | ~100 |
| Subsystems | 3 | ~12-15 |
| Edges | ~20 | ~200-300 |
| Watch patterns | 8 | 8 (same globs cover everything) |
| Registration effort | ~30 min | ~5-8 hours (one-time) |
| Per-card maintenance | Low | Low (only on structural changes) |
| Summary tokens | ~120 | ~500-600 |
