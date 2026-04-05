# Deep Dive #19: The Fabric Explorer

## Title

Governing AI Agents: The Fabric Explorer — from static topology to interactive architecture browser

## Post Body

**You cannot govern a system you cannot navigate.**

In transition management, one of the earliest governance deliverables is the dependency map. Before any workstream moves, the programme office establishes what connects to what, which components share interfaces, and where a delay in one area ripples into three others. The map itself is not the value. The value is the capacity to answer a question in ten seconds that would otherwise take two hours of meetings: "If I change this, what breaks?"

The Agentic Engineering Framework built this map six months ago. The Component Fabric — a set of YAML cards describing every significant file, its purpose, its dependencies, and its dependents — gave the agent structural awareness. `fw fabric deps` answered the dependency question. `fw fabric blast-radius` showed downstream impact before a commit. The map worked. But the map was invisible.

### The problem with invisible maps

The Fabric existed as 219 YAML cards and a set of CLI commands. An agent could query it. A human could not. Not without running terminal commands, reading YAML, and mentally assembling the picture from fragments.

The Watchtower web UI had a graph page. It used Cytoscape.js — a directed acyclic graph renderer that drew subsystem nodes in a static layout. It showed that subsystems existed and had edges. It did not let you drill into a subsystem to see its components. It did not let you search. It did not let you trace a path from one component to another. It was a picture of the architecture, not a tool for navigating it.

The distinction matters. A programme manager who has a dependency chart on the wall can point at boxes. A programme manager who has an interactive model can ask: "Show me every path from the billing module to the notification system." The first is documentation. The second is operational intelligence.

### From evaluation to integration

The upgrade did not start as a planned initiative. It started as a side effect.

The framework has a pattern called Path C — deep-dive evaluations of external codebases, where an agent ingests, builds a fabric, analyses architecture, and extracts learnings. During a Path C evaluation of an open-source project, one of the dispatched agents built a D3.js-based fabric explorer as part of the evaluation tooling. It was built to understand that project's architecture, not the framework's.

But the code was good. 1,584 lines of template. Force-directed D3 graph. Search. Drill-down. Pathfinding. Detail panes with source code viewing. It had been built under framework governance — task-tracked, tested, committed. The question became: does this belong upstream?

The framework's own inception process answered that. T-726 evaluated the explorer against the existing Cytoscape implementation. The assessment was straightforward:

| Capability | Cytoscape (old) | D3 Explorer (new) |
|-----------|-----------------|-------------------|
| Graph type | Static DAG | Force-directed, physics-based |
| Node types | Subsystems only | Subsystems + components (drill-down) |
| Search | None | Real-time filter |
| Pathfinding | None | Click-based BFS between any two nodes |
| Detail view | None | Multi-tab pane with source and reports |
| Inline expansion | None | Satellite nodes around parent |
| Vendor weight | ~500 KB (global) | ~274 KB (scoped) |

The decision was GO. The integration (T-730) took one session. The old Cytoscape library and template were removed. The D3 explorer took its place at `/fabric/graph`.

### What the explorer does

The graph opens with subsystem bubbles arranged by a D3 force simulation. Each bubble represents a subsystem — Framework Core (71 components), Watchtower Web UI (73 components), Context Fabric (31 components), and thirteen others. Edges show structural dependencies between subsystems. The layout is physics-based: nodes repel each other, edges pull connected nodes together, and the result settles into a stable arrangement that reflects actual coupling density.

Six architectural layers are colour-coded — Entry, Control Plane, Agent Runtime, Extensions, Platform, Infrastructure. The colours are not decorative. They encode the structural depth of a subsystem within the architecture. Control Plane subsystems cluster near Entry subsystems because they share edges. Infrastructure subsystems drift to the periphery because fewer things depend on them directly.

**Double-click a subsystem to drill down.** The graph re-renders with that subsystem's components. A subsystem with 29 components becomes 29 individual nodes with their internal dependency edges. The breadcrumb reads "All Subsystems > Framework Core." Each component shows its type — library, script, agent, data, template, config — as a single-letter indicator.

**Click the "+" button to expand inline.** Instead of navigating away, satellite component nodes orbit the parent subsystem. Dashed lines indicate the parent-child relationship. Context is preserved. This is the lightweight alternative when you want to peek inside a subsystem without losing the overview.

**Click "Path" and select two nodes.** A BFS algorithm traces the dependency chain between them, bridging across levels — component to subsystem to component — and highlights the result. "Security > Gateway > Sessions > Agents." The path is not a guess. It is computed from the actual `depends_on` and `depended_by` fields in the component cards.

**Search filters in real time.** Type a term and non-matching nodes fade to 10% opacity. The match count updates as you type. The search spans names, locations, purposes, and tags.

**The detail pane** opens as a tabbed panel — bottom or side, depending on viewport. It shows architectural findings, the component list, upstream and downstream dependencies, a lazy-loaded source code viewer, and links to related research reports. Multiple tabs can be open simultaneously, and each preserves its scroll position across tab switches.

### Security by design

The source code viewer serves files via an API endpoint that resolves paths through `os.path.realpath()` and checks containment within the project root. A request for `../../etc/passwd` resolves to a path outside the project boundary and returns 403. Files larger than 500 KB return 413. The report viewer strips path components and restricts to `.md` files in a single directory. These are not afterthoughts — they were part of the integration assessment.

### What this pattern reveals

The Fabric Explorer was not designed for the framework. It was designed by an agent working under framework governance on a different project. The fact that it was usable upstream — with a one-session integration, no API changes, and security-safe by construction — reveals something about what governance produces.

Governance does not slow down innovation. Governance makes innovation portable. The explorer was built task-tracked, scope-fenced, and tested. When the question "does this belong upstream?" arose, the answer could be evaluated mechanically: check the code, assess the API surface, run the security review, compare capabilities. The inception process produced a GO decision in under an hour because the artefact was already legible.

An ungoverned agent might have produced equally capable code. But it would have been interleaved with other changes, undocumented in its design choices, and entangled with the evaluation project's specifics. The extraction would have required reverse engineering instead of review.

**Structural governance does not constrain what agents can build. It constrains how they build it — in ways that make the output reusable, reviewable, and portable.**

The 219 components and 816 edges in the framework's topology are now navigable by any human with a browser. The map is no longer invisible. And the tool that made it visible was itself a product of the map.

---

*The Agentic Engineering Framework is open source: [github.com/DimitriGeelen/agentic-engineering-framework](https://github.com/DimitriGeelen/agentic-engineering-framework)*
