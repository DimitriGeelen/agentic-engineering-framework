# Phase 3: Operational Intelligence — Design Document

**Task:** T-058 Watchtower Command Center
**Phase:** 3 of 4
**Date:** 2026-02-14
**Approach:** A (Metrics Dashboard + Pattern Browser)

## Scope

Three deliverables:

1. `/metrics` page — project health dashboard with computed indicators
2. `/patterns` page — first-class pattern browser with escalation ladder visualization
3. Dashboard enhancement — system health row on index page

Plus: navigation update, patterns removed from `/learnings`, new tests.

## 1. Metrics Page

**New file:** `web/blueprints/metrics.py`
**New template:** `web/templates/metrics.html`
**Route:** `GET /metrics`

### Data Sources (all in-process, no subprocess)

| Metric | Source | Computation |
|--------|--------|-------------|
| Active tasks | `.tasks/active/T-*.md` | glob count |
| Completed tasks | `.tasks/completed/T-*.md` | glob count |
| Traceability % | `git log --oneline -200` | regex match T-\d+ |
| Description quality % | task frontmatter | count where len(description) >= 50 |
| AC coverage % | task body | count tasks with acceptance criteria section |
| Learnings count | `learnings.yaml` | len(learnings) |
| Patterns count | `patterns.yaml` | sum of all pattern lists |
| Decisions count | `decisions.yaml` | len(decisions) |
| Practices count | `practices.yaml` | len(practices) |
| Recent commits | `git log --oneline -10` | parse hash + message |
| Stale tasks | task frontmatter | last_update > 7d ago |

### Layout

```
[Header: "Project Metrics" + refresh button]

[4-card grid row]
  [ Tasks: N active / N done ]
  [ Traceability: N% gauge   ]
  [ Quality: N% desc, N% AC  ]
  [ Knowledge: NL NP ND      ]

[2-card wide row]
  [ Recent Commits (10)       | Stale/Issues Tasks ]
```

- Refresh button: `hx-get="/metrics" hx-target="#content"`
- Metric cards use Pico `<article>` with inline styles for gauge bars
- Traceability gauge: colored div bar (green/yellow/red)
- Commit list highlights T-XXX refs in bold

## 2. Patterns Page

**Modified file:** `web/blueprints/discovery.py` (add route)
**New template:** `web/templates/patterns.html`
**Route:** `GET /patterns`
**Query param:** `?type=failure|success|antifragile|workflow` (optional filter)

### Data Source

`patterns.yaml` — four sections: `failure_patterns`, `success_patterns`, `antifragile_patterns`, `workflow_patterns`

### Layout

```
[Header: "Patterns" + count]

[Tab bar: All | Failure | Success | Antifragile | Workflow]

[Pattern cards — one per pattern]
  ┌──────────────────────────────────────────┐
  │ [FP-001] badge    Pattern Name           │
  │                                          │
  │ Description text...                      │
  │                                          │
  │ Mitigation/Context: ...                  │
  │ Learned from: T-XXX  |  Date: 2026-02-14│
  └──────────────────────────────────────────┘

[Antifragile patterns get extra section:]
  ┌──────────────────────────────────────────┐
  │ [AF-001] badge    Pattern Name           │
  │ ...                                      │
  │ Escalation: [A]──[B]──[C]──[D]          │
  │              ✓     ✓     ✓     ✓         │
  │ Capability gained: ...                   │
  └──────────────────────────────────────────┘
```

- Tab bar: links with `?type=X`, active tab styled. "All" shows everything.
- Badge colors: red (failure), green (success), purple (antifragile), blue (workflow)
- Escalation ladder: horizontal flex with 4 step boxes, connected by lines. Steps mentioned in the pattern's `escalation_ladder` field get highlighted.
- Cross-references: task IDs link to `/tasks/T-XXX`

### Removal from `/learnings`

The entire `<!-- Patterns section -->` block (the `<details>` with failure/success/workflow tables) is removed from `learnings.html`. A link to `/patterns` is added in its place: "See all patterns →"

## 3. Dashboard Enhancement

**Modified file:** `web/templates/index.html`
**Modified file:** `web/blueprints/core.py`

Add after the Project Pulse `<article>`:

```
[System Health row]
  Traceability: [====== 95%]  |  Knowledge: 12L 7P 10D  |  Patterns: 7 (4 failure)
```

- Reuse `_get_traceability()` already called for the dashboard
- Add `_get_pattern_summary()` helper: counts by type
- Knowledge counts already available via `_get_knowledge_counts()`
- Each metric links to its respective page

## 4. Navigation Update

In `shared.py`, update `NAV_GROUPS`:

```python
NAV_GROUPS = [
    ("Work", [
        ("Tasks",    "tasks.tasks",        None),
        ("Timeline", "timeline.timeline",  None),
    ]),
    ("Knowledge", [
        ("Learnings", "discovery.learnings",  None),
        ("Patterns",  "discovery.patterns",   None),  # NEW
        ("Decisions", "discovery.decisions",  None),
    ]),
    ("Govern", [
        ("Directives", "core.directives",       None),
        ("Gaps",       "discovery.gaps",         None),
        ("Quality",    "quality.quality_gate",   None),
        ("Metrics",    "metrics.project_metrics", None),  # NEW
    ]),
]
```

## 5. Tests

Add to `test_app.py`:

- `test_metrics_page_returns_200`
- `test_metrics_has_task_counts`
- `test_metrics_has_traceability`
- `test_metrics_has_knowledge_counts`
- `test_metrics_htmx_fragment`
- `test_patterns_page_returns_200`
- `test_patterns_has_all_types`
- `test_patterns_filter_by_type`
- `test_patterns_antifragile_has_escalation`
- `test_learnings_no_longer_has_patterns`
- `test_learnings_has_patterns_link`
- `test_nav_has_patterns`
- `test_nav_has_metrics`
- `test_dashboard_has_system_health`

## File Changes Summary

| File | Action | Description |
|------|--------|-------------|
| `web/blueprints/metrics.py` | CREATE | Metrics blueprint with data gathering |
| `web/templates/metrics.html` | CREATE | Metrics page template |
| `web/templates/patterns.html` | CREATE | Patterns page template |
| `web/blueprints/discovery.py` | MODIFY | Add `/patterns` route |
| `web/templates/learnings.html` | MODIFY | Remove patterns section, add link |
| `web/blueprints/core.py` | MODIFY | Add pattern summary to dashboard data |
| `web/templates/index.html` | MODIFY | Add System Health row |
| `web/shared.py` | MODIFY | Update NAV_GROUPS |
| `web/app.py` | MODIFY | Register metrics blueprint |
| `web/test_app.py` | MODIFY | Add ~14 new tests |
