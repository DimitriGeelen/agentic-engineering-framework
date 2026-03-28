---
title: "Component Fabric — UI Component Documentation Patterns"
task: T-191
date: 2026-02-19
status: complete
phase: "Phase 1c — UI Documentation Research"
tags: [component-fabric, research, ui, htmx, flask, templates, documentation]
predecessor: docs/reports/T-191-cf-aef-topology-sample.md
---

# Component Fabric — UI Component Documentation Patterns

> **Task:** T-191 | **Date:** 2026-02-19 | **Phase:** 1c (UI Documentation Research)
> **Principle:** "The thinking trail IS the artifact"

## Research Objective

How should Component Fabric document web UI components for AI agent consumption — specifically for server-rendered apps (Flask/Jinja2/htmx) where the "component" concept is fundamentally different from React/Vue component trees?

This question is urgent because the AEF web UI is the part of the codebase where agents are most blind: they cannot observe the rendered page, cannot see user interactions, and have no structural map of what template renders where, what JS binds to what elements, or what API endpoint backs what UI action.

---

## 1. AEF Web UI Architecture (What We're Documenting)

Analysis of the actual `web/` directory reveals:

| Aspect | Detail |
|--------|--------|
| Framework | Flask + Jinja2 + htmx (server-rendered fragments) |
| Styling | Pico CSS (classless/semantic) |
| JS framework | None — htmx handles all dynamic interaction |
| Separate JS files | **Zero** — all JS is inline in templates |
| Page routes | 19+ (dashboard, tasks, timeline, inception, metrics, etc.) |
| API endpoints | 25+ (all return HTML fragments, not JSON) |
| Templates | 24+ (pages, fragments, partials) |
| Static assets | 3 (htmx.min.js, pico.min.css, logo.png) |
| Blueprints | 10 (core, tasks, timeline, discovery, quality, session, metrics, cockpit, inception, enforcement) |
| Rendering pattern | `render_page()` — wraps fragment in `_wrapper.html` for full loads, returns raw fragment for htmx requests |
| CSRF | Global `before_request` validates token on POST/PATCH/PUT/DELETE |

**Key architectural insight:** In this app, the "component" is NOT a reusable code unit (like a React component). The "component" is a **template fragment + route handler + inline JS triple**. The boundaries are:

1. **Page component** = route handler + full template + inherited base layout
2. **Interactive element** = htmx-attributed HTML element + API endpoint + response fragment
3. **Inline behavior** = `<script>` block in template that uses `fetch()` for operations htmx can't handle

This is a fundamentally different documentation challenge from React/Storybook.

---

## 2. Research Findings: What Exists

### 2.1 AGENTS.md for UI

**Status:** Exists, but React/Vue-centric.

- AGENTS.md is now a Linux Foundation standard, auto-read by Codex, Copilot, Cursor, Aider, Zed
- [Builder.io guide](https://www.builder.io/blog/agents-md) recommends documenting component APIs, design tokens, and build conventions
- [HeroUI](https://v3.heroui.com/docs/react/getting-started/agents-md) publishes an AGENTS.md for its component library

**Gap for us:** All examples assume a component-based framework where each component is a self-contained file with props/exports. Flask/Jinja2 apps have no such boundary — the "component" spans a route handler (Python), a template (HTML+Jinja2), and inline JS. No AGENTS.md template exists for this architecture.

### 2.2 Flask/Jinja2 Template Documentation

**Status:** Prose-only documentation, no machine-readable format.

- Flask docs cover template inheritance (`base.html` → child templates)
- Jinja2 macros serve as the closest equivalent to reusable components
- `url_for()` provides route-template linkage, but only at render time — not queryable statically

**Gap for us:** No standard format for documenting the template → route → JS triangle as a machine-readable artifact. The documentation is always human prose, never structured data.

### 2.3 Component Registries for Server-Rendered Apps

**Status:** Effectively non-existent for Flask.

- Django has `django-viewcomponent` (inspired by Rails ViewComponent)
- Rails ViewComponent gem is the most mature SSR component pattern
- Storybook has experimental SSR support but requires a JavaScript runtime
- No component registry equivalent exists for Flask/Jinja2

**Gap for us:** This is a genuine gap in the ecosystem. The closest achievable pattern is a static YAML registry listing templates, their parameters, and their relationships — which is exactly what Component Fabric would provide.

### 2.4 HTML `data-*` Attributes for Machine Identification

**Status:** `data-testid` is the dominant pattern, but designed for testing, not AI agents.

- `data-testid` best practices: unique per page, stable across releases, named by purpose not appearance
- `data-component` is used informally as a component boundary marker
- No AI-specific `data-*` attribute standard exists (no `data-agent-id` spec)

**Recommendation for AEF:** Add two attributes to key interactive elements:
- `data-component="component-name"` — marks component boundaries (maps to Component Fabric card)
- `data-action="action-name"` — marks interactive elements (maps to interaction flow steps)

These cost nothing to add, survive CSS refactors, and give agents (and Playwright) stable handles.

### 2.5 Interaction Flow Documentation

**Status:** Visual tools only (Miro, Figma). No machine-readable format.

- UML activity diagrams are the closest standard but require diagramming tools
- User flow documentation is universally visual/graphical
- No `flows.yaml` or Markdown interaction spec format exists anywhere

**Recommendation for AEF:** Define a simple text-based interaction flow format:
```
## Flow: Update Task Status
1. User clicks status dropdown on task card (data-action="change-status")
2. htmx POST /api/task/{id}/status with {status: "new-value"}
3. Server: update-task.sh --status {value} → writes task file
4. Response: HTML fragment replaces dropdown (hx-swap="outerHTML")
5. If board view: triggers full board reload via htmx.ajax('GET', '/tasks?view=board')
```

---

## 3. Synthesis: What Component Fabric Needs for UI

### 3.1 The Unit of Documentation

For React apps: one component = one file = one card.
For Flask/htmx apps: one "UI component" = a **triple**:

```
┌──────────────────────────────┐
│ UI Component Triple          │
├──────────────────────────────┤
│ Route handler (Python)       │  → e.g., tasks.task_detail()
│ Template (Jinja2/HTML)       │  → e.g., task_detail.html
│ Inline JS (if any)           │  → e.g., startKanbanNameEdit()
│                              │
│ Connected API endpoints:     │  → e.g., POST /api/task/{id}/status
│ Connected response fragments:│  → e.g., status dropdown outerHTML
└──────────────────────────────┘
```

### 3.2 Proposed UI Component Card Schema

```yaml
# Hypothetical component card for task detail page
id: UI-002
name: task-detail
type: page
container: web
subsystem: task-management

route:
  url: "/tasks/<task_id>"
  method: GET
  handler: tasks.task_detail
  blueprint: tasks
  template: task_detail.html
  data_passed: [task_frontmatter, ac_list, csrf_token]

interactive_elements:
  - id: status-dropdown
    element: "<select>"
    data_action: change-status
    htmx: "hx-post=/api/task/{id}/status hx-swap=outerHTML"
    api_endpoint: POST /api/task/{id}/status
    backend_effect: "update-task.sh --status {value}"

  - id: horizon-dropdown
    element: "<select>"
    data_action: change-horizon
    htmx: "hx-post=/api/task/{id}/horizon hx-swap=outerHTML"
    api_endpoint: POST /api/task/{id}/horizon
    backend_effect: "update-task.sh --horizon {value}"

  - id: task-name-edit
    element: "<span> → <input> (click-to-edit)"
    data_action: edit-name
    js_function: "inline fetch('/api/task/{id}/name')"
    api_endpoint: POST /api/task/{id}/name
    backend_effect: "sed replacement in task .md file"

  - id: ac-checkbox
    element: "<input type=checkbox>"
    data_action: toggle-ac
    htmx: "hx-post=/api/task/{id}/toggle-ac hx-swap=outerHTML"
    api_endpoint: POST /api/task/{id}/toggle-ac
    backend_effect: "toggles [ ]/[x] in task markdown"

  - id: description-editor
    element: "<textarea>"
    data_action: edit-description
    htmx: "hx-post=/api/task/{id}/description hx-swap=outerHTML"
    api_endpoint: POST /api/task/{id}/description
    backend_effect: "replaces ## Description section in task file"

template_inheritance:
  extends: _wrapper.html → base.html
  includes: [_session_strip.html]
  js_inline: true  # has <script> block

related_components:
  - UI-001  # tasks list page (navigates here)
  - UI-010  # session strip (sidebar)
```

### 3.3 Proposed Interaction Flow Format

```yaml
# Hypothetical interaction flow for task status change
flow_id: IF-003
name: "Change task status"
trigger: "User selects new value in status dropdown"
component: UI-002  # task-detail

steps:
  - action: "User clicks status <select>"
    element: "status-dropdown"
    type: user-input

  - action: "htmx fires POST /api/task/{id}/status"
    payload: "status={selected_value}"
    headers: "X-CSRF-Token"
    type: api-call

  - action: "Server runs update-task.sh --status {value}"
    effect: "Task file frontmatter updated"
    type: backend

  - action: "Response HTML fragment replaces dropdown"
    swap: "outerHTML on select element"
    type: dom-update

  - action: "If board view: htmx.ajax reloads /tasks?view=board"
    condition: "document.querySelector('[data-view=board]')"
    type: conditional-reload
```

### 3.4 What's Unique About htmx Apps

Traditional SPA documentation focuses on client-side state. htmx apps have a fundamentally different pattern:

| SPA (React/Vue) | htmx (Server-Rendered) |
|-----------------|----------------------|
| Component = JS file with props | Component = route + template + inline JS |
| State in client (Redux/Context) | State on server (files, DB) |
| API returns JSON | API returns HTML fragments |
| Client renders | Server renders |
| JS bundles to document | Inline `<script>` blocks |
| Component tree = import graph | Component tree = template inheritance |
| Event handlers in component | htmx attributes on HTML elements |
| Testing: component unit tests | Testing: endpoint integration tests |

**Implication:** Component Fabric cards for htmx apps must document the **full vertical chain** (element → htmx attribute → API endpoint → backend effect → response fragment), not just the component boundary.

---

## 4. AEF Web UI: Component Inventory (High-Level)

From the exploration, the web UI has these component clusters:

### Pages (full route + template pairs)
| Page | Route | Template | Interactive? |
|------|-------|----------|-------------|
| Dashboard/Cockpit | GET / | index.html / cockpit.html | Yes — action buttons |
| Tasks (board/list) | GET /tasks | tasks.html | Yes — create form, inline edits, dropdowns |
| Task Detail | GET /tasks/{id} | task_detail.html | Yes — status/horizon/owner/type dropdowns, AC checkboxes, name edit, description edit |
| Timeline | GET /timeline | timeline.html | Yes — expandable task rows |
| Quality | GET /quality | quality.html | Yes — run audit/tests buttons |
| Search | GET /search | search.html | Yes — search form |
| Inception | GET /inception | inception.html | Minimal |
| Inception Detail | GET /inception/{id} | inception_detail.html | Yes — add assumption, resolve, decide |
| Metrics | GET /metrics | metrics.html | Minimal (refresh link) |
| Enforcement | GET /enforcement | enforcement.html | Read-only |
| Decisions | GET /decisions | decisions.html | Read-only |
| Learnings | GET /learnings | learnings.html | Read-only |
| Gaps | GET /gaps | gaps.html | Read-only |
| Patterns | GET /patterns | patterns.html | Read-only |
| Graduation | GET /graduation | graduation.html | Read-only |
| Directives | GET /directives | directives.html | Read-only |
| Project Docs | GET /project, /project/{doc} | project.html, project_doc.html | Read-only |
| Assumptions | GET /assumptions | assumptions.html | Read-only |

### API Endpoints by Category
- **Task CRUD** (7): create, status, horizon, owner, type, name, toggle-ac, description
- **Session** (2): status, init
- **Discovery** (2): add-decision, add-learning
- **Quality** (2): run-audit, run-tests
- **Cockpit/Scan** (4): refresh, approve, defer, apply, focus
- **Timeline** (1): task detail expansion
- **Inception** (3): add-assumption, resolve, decide
- **Healing** (1): diagnose

### Shared Fragments
- `base.html` — shell layout, nav, toast, htmx config
- `_wrapper.html` — full-page wrapper for SPA-like navigation
- `_session_strip.html` — sidebar session status + forms
- `_timeline_task.html` — expandable task detail in timeline
- `_quality_audit_fragment.html` — audit result display
- `_error.html` — error page

---

## 5. Key Design Decisions for Component Fabric

Based on this research, the following decisions are recommended for Phase 3 (data model):

### D-1: Separate card types for scripts vs UI components
CLI scripts (budget-gate.sh) and UI components (task-detail page) need different card schemas. Scripts have stdin/stdout interfaces; UI components have routes, templates, interactive elements, and htmx attributes.

### D-2: Document the full vertical chain for htmx
Each interactive element should trace: `HTML element → htmx attribute → API endpoint → backend effect → response fragment`. This is the "soft coupling" of the UI world.

### D-3: Add `data-component` and `data-action` attributes to templates
Low-cost, high-value: gives agents stable handles for identifying and discussing UI elements. Compatible with Playwright selectors for testing.

### D-4: Interaction flows as first-class artifacts
Not embedded in component cards — separate flow documents that reference components. One flow can span multiple components (e.g., "create task" involves tasks.html form → POST /api/task/create → redirect to task_detail).

### D-5: Template inheritance is the component tree
For htmx/Jinja2 apps, the import graph equivalent is `{% extends %}` / `{% include %}` / `{% block %}`. This IS the component hierarchy and should be documented as such.

---

## 6. Open Questions for Phase 2

1. **Auto-generation feasibility:** Can we parse Jinja2 templates to extract `{% extends %}`, `{% include %}`, and htmx attributes automatically? (Likely yes — regex or Jinja2 AST)
2. **Granularity threshold:** Does every `<select>` on every page get its own card, or only "significant" interactive elements? Need a heuristic.
3. **Live verification:** Can `curl` or Playwright verify that documented routes still respond and return expected elements? (→ verification gate integration)
4. **Template change detection:** When a template changes, which component cards need updating? Can we derive this from `{% extends %}` / `{% include %}` chains?
5. **Card location:** Co-located with templates (`web/fabric/task-detail.yaml`) or centralized (`.fabric/ui/task-detail.yaml`)?

---

## Cross-References

- **Phase 1a:** [Research Landscape](T-191-cf-research-landscape.md) — C4 model, Storybook MCP, soft coupling taxonomy
- **Phase 1b:** [AEF Budget Topology](T-191-cf-aef-topology-sample.md) — proof-of-concept for CLI script cards
- **Genesis:** [Genesis Discussion](T-191-cf-genesis-discussion.md) — design principles, use cases
- **Task:** `.tasks/active/T-191-component-fabric--structural-topology-sy.md`

---

## Sources

1. [AGENTS.md specification](https://agents.md/) — Linux Foundation standard
2. [Builder.io AGENTS.md guide](https://www.builder.io/blog/agents-md)
3. [HeroUI AGENTS.md](https://v3.heroui.com/docs/react/getting-started/agents-md)
4. [Flask templating docs](https://flask.palletsprojects.com/en/stable/templating/)
5. [ArjanCodes Flask/Jinja2](https://arjancodes.com/blog/rendering-templates-with-jinja2-in-flask/)
6. [TestDriven.io Django ViewComponent](https://testdriven.io/blog/django-reusable-components/)
7. [BugBug data-testid guide](https://bugbug.io/blog/software-testing/data-testid-attributes/)
8. [Alphabin data-testid](https://www.alphabin.co/blog/data-testid-attribute-for-automation-testing)
9. [MuukTest data-testid](https://muuktest.com/blog/test-attributes-in-html-for-test-automation)
10. [Miro user flow templates](https://miro.com/templates/user-flow/)
11. [IxDF user flows](https://www.interaction-design.org/literature/topics/user-flows)
