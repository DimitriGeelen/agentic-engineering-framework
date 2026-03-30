# T-726: Fabric Explorer Integration — Research & Assessment

## Source

- **Pickup message:** `/opt/openclaw-evaluation/.context/working/T-158-fabric-explorer-pickup.md`
- **Source template:** `/opt/openclaw-evaluation/.agentic-framework/web/templates/fabric_explorer.html` (1,584 LOC)
- **Source backend:** `/opt/openclaw-evaluation/.agentic-framework/web/blueprints/fabric.py` (379 LOC)
- **D3 library:** `/opt/openclaw-evaluation/.agentic-framework/web/static/d3.v7.min.js` (vendored)

## Diff Analysis: fabric.py

### Shared code (identical or near-identical)
- `_load_components()` — identical
- `_build_graph()` — identical
- `fabric_overview()` — identical
- `component_detail()` — identical (except `source_path` base dir)

### Key differences

| Area | Framework | OpenClaw | Integration Notes |
|------|-----------|----------|-------------------|
| `ACTUAL_PROJECT_ROOT` | Not present | `os.path.dirname(PROJECT_ROOT)` | Framework doesn't need this — `PROJECT_ROOT` IS the project root. Hardcode `ACTUAL_PROJECT_ROOT = PROJECT_ROOT` |
| `_load_subsystems()` | List-only format | List + dict format support | Take openclaw version — backwards-compatible enhancement |
| `fabric_graph()` | Cytoscape-based, builds nodes/edges server-side, renders `fabric_graph.html` | D3-based, passes raw component data, renders `fabric_explorer.html` | Replace entirely — D3 version is strictly better |
| `/api/fabric/report/` | Not present | New route, serves report markdown | Add — new functionality, non-breaking |
| `/api/fabric/source/` | Not present | New route, serves source files with security | Add — new functionality, non-breaking |

### Path resolution issue
In consumer projects, `PROJECT_ROOT` points to `.agentic-framework/` (the vendor dir), and `.fabric/` lives at the parent directory. The openclaw code uses `ACTUAL_PROJECT_ROOT = os.path.dirname(PROJECT_ROOT)` for this.

**For the framework repo itself:** `PROJECT_ROOT` is already the project root, so `ACTUAL_PROJECT_ROOT = PROJECT_ROOT` is correct. But for vendor installs, we need the parent. Solution:

```python
# Use PROJECT_ROOT directly in framework repo; in consumer projects,
# .fabric/ is at the actual project root (parent of vendor dir)
if os.path.basename(PROJECT_ROOT) == ".agentic-framework":
    ACTUAL_PROJECT_ROOT = os.path.dirname(PROJECT_ROOT)
else:
    ACTUAL_PROJECT_ROOT = PROJECT_ROOT
```

## Security Review

### Source API (`/api/fabric/source/<path>`)
- `os.path.realpath()` resolves symlinks and `../` — prevents traversal
- `startswith(ACTUAL_PROJECT_ROOT + os.sep)` — containment check
- 500KB size limit — prevents memory exhaustion
- `errors="replace"` — binary-safe
- **Verdict: ADEQUATE** — standard Flask file serving pattern with proper containment

### Report API (`/api/fabric/report/<path>`)
- `os.path.basename(filename)` — strips any path components
- Only allows `.md` files
- Restricted to `docs/reports/` directory
- **Verdict: ADEQUATE** — effectively hardcoded to one directory

## Template Compatibility

The `fabric_explorer.html` uses `{% extends "base.html" %}` and `{% block content %}`. It includes:
- CSS isolation via `.fabric-explorer-scope { all: initial }` — prevents Pico CSS bleeding
- Inline D3 script using `{{ components | tojson }}` for data injection
- No external JS dependencies (D3 vendored as static file)
- Dark theme that would conflict without CSS isolation

**Compatible with framework's Jinja2 + Pico CSS setup.**

## D3 v7 Conflict Assessment

- D3 is loaded as a vendored static file (`d3.v7.min.js`)
- No existing Watchtower pages use D3
- The old Cytoscape graph loads Cytoscape from CDN — will no longer be needed
- htmx and D3 don't conflict (different DOM manipulation patterns)

**No conflicts.**

## Integration Effort

1. **Merge fabric.py** — Add ACTUAL_PROJECT_ROOT logic, replace `fabric_graph()`, add 2 API routes, update `_load_subsystems()`. ~30 lines changed, ~40 lines added.
2. **Copy template** — `fabric_explorer.html` as-is (may need minor path adjustments)
3. **Copy D3** — Vendor `d3.v7.min.js` to `web/static/`
4. **Delete old** — Remove `fabric_graph.html` (Cytoscape version)
5. **Vendor sync** — Copy to `.agentic-framework/`

**Estimated: 1 session, bounded scope.**

## Recommendation

**GO** — This is a straightforward integration with clear value:
- Production-quality code (26 tests, 1,584 LOC, tested in OpenClaw evaluation)
- No breaking changes to existing routes
- Security review passed
- Bounded integration effort (copy + adapt paths, not rewrite)
- Major UX improvement: interactive graph with source viewer, report viewer, pathfinding replaces static Cytoscape view
