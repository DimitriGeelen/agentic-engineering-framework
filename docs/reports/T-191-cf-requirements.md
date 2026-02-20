# T-191: Component Fabric — Requirements (Phase 2)

## Purpose
Use case deep dives + human validation. Synthesized from Phase 1 research and interactive dialogue.

## The 6 Use Cases

Derived from the problem statement. Each needs: the query an agent asks, the data structure that answers it, and minimum viable schema.

### UC-1: Navigate ("What exists here and how does it connect?")
- **Status:** validated
- **Agent query:** Two modes: (1) "Find everything related to X" (topic/feature search across components), (2) "What does file Y connect to?" (outward traversal from a known point). Both equally important.
- **Data needed:** Components tagged with topics/features for concept search. Dependency edges for point-based traversal. Results must include both component-level pointers AND code locations (file:line).
- **Schema implications:** Components need tags/keywords for topic search. Edges need source/target with line references, not just file-level. Need two query modes in the CLI.
- **Real AEF example:** "learnings" topic search → returns cluster: `learning.sh`, `learnings.yaml`, `discovery.py:/learnings`, `learnings.html` template. Point query on `learning.sh` → shows writes to `learnings.yaml`, called by `context.sh:L42`.
- **Priority:** HIGH — daily driver, every investigation starts with navigation.

### UC-2: Impact ("What breaks if I change X?")
- **Status:** validated
- **Agent query:** "What depends on the output format of this script/file?" → full transitive chain
- **Data needed:** Dependency graph with edge types (writes, reads, calls, triggers, renders). Must support transitive traversal (A→B→C→D), not just direct neighbors.
- **Schema implications:** Edges need types. Graph must be traversable. "reads file X" and "writes file X" are first-class relationships.
- **Real AEF example:** `learning.sh` → `learnings.yaml` → `discovery.py` → `/learnings` route → `audit.sh` YAML check. Silent corruption chain from T-206.
- **Priority:** HIGH — daily driver, not just insurance. Every session involves changes with downstream effects.

### UC-3: UI Identify ("What is this element and what does it do?")
- **Status:** validated
- **Agent query:** "What is this UI element, what does it trigger, and what's the full vertical chain?" (element → htmx attribute → API endpoint → backend effect → response fragment)
- **Data needed:** UI component registry with `data-component`/`data-action` attributes mapped to backend routes and effects. Vertical chain documentation for each interactive element. Must integrate into the same dependency graph as code components.
- **Schema implications:** UI components are first-class nodes in the graph, not second-class annotations. Need a UI-specific card type (route + template + inline JS triple from Phase 1 decision). Edges connect UI elements to API endpoints to backend effects.
- **Real AEF example:** Playwright sees a "Sort by date" button on /learnings — fabric query returns: `data-action="sort-date"` → htmx `hx-get="/learnings?sort=date"` → `discovery.py:learnings()` → re-renders `learnings.html` fragment.
- **Priority:** HIGH — equally important as code-side use cases. Critical from page 1, not deferred until scale. Agents must reason about UI as confidently as code.

### UC-4: Onboard ("Give me the system's shape in 30 seconds")
- **Status:** validated
- **Agent query:** "What does this system look like?" → layered: subsystem map first, drill into component detail on demand
- **Data needed:** Two-tier structure: (1) subsystem summary (10-15 entries, ~50 lines) auto-injected at session start, (2) full component cards queryable via `fw fabric` when working on a specific area
- **Schema implications:** Components must belong to a subsystem/group. Need a generated summary view (compact) alongside full detail. Summary must fit in context budget (~500 tokens).
- **Real AEF example:** Agent starts session, gets "budget subsystem: checkpoint.sh → budget-gate.sh → .budget-status → PostToolUse hook → PreToolUse hook" as orientation. When working on budget, drills into full cards.
- **Priority:** HIGH — daily driver, every session starts cold. Automatic injection (like handovers), not on-demand.

### UC-5: Regress ("This commit broke something — trace the blast radius")
- **Status:** validated
- **Agent query:** "What's the blast radius of this commit?" → full transitive downstream from changed files. Auto-reported on every commit AND queryable on demand.
- **Data needed:** Mapping from files changed in a commit → component nodes → transitive downstream via dependency graph. Reuses the same graph as UC-2 (Impact), applied to git diff output.
- **Schema implications:** No new schema needed beyond UC-2's dependency graph. Needs a CLI entry point (`fw fabric blast-radius <commit>`) and a post-commit hook integration that runs the traversal automatically.
- **Real AEF example:** Commits `2ce41d8`/`d8341ad`/`5bd8185` changed `learning.sh` → post-commit hook would have reported: "Downstream: `learnings.yaml`, `discovery.py`, `/learnings` route, `audit.sh` YAML check." Silent corruption would have been flagged as a risk immediately.
- **Priority:** HIGH — warning (informational), not a gate. Agents and humans see the blast radius but are not blocked. Could evolve to gate later if warranted.

### UC-6: Completeness ("What's undocumented or drifted?")
- **Status:** validated
- **Agent query:** "What's unregistered or stale?" → detects both unregistered components (new files not in fabric) AND stale/missing edges (dependencies that changed since registration). Both equally important.
- **Data needed:** File system scan compared against component registry. Edge validation: do declared dependencies still hold in code? Are there undeclared dependencies? Needs heuristics for what constitutes a "component-worthy" file (not every .yaml or .md needs registration).
- **Schema implications:** Components need a "last validated" timestamp. Edges need a validation mechanism (can the declared relationship be confirmed by code analysis?). Need file-pattern rules for what triggers "unregistered component" warnings (e.g., `agents/*/*.sh`, `web/blueprints/*.py`, `templates/*.html`).
- **Real AEF example:** New script `lib/new-helper.sh` added without fabric registration → audit flags it. `learning.sh` changes output format → edge to `learnings.yaml` marked stale because output schema changed.
- **Priority:** HIGH — both in `fw audit` (automated cron catching) and `fw fabric drift` (deep investigation on demand).

## Dialogue Log

### Session: 2026-02-20

*(Recording dialogue as it happens — C-001 extension)*

**UC-2 discussion:**
- Presented T-206 (learning.sh → learnings.yaml → discovery.py → /learnings) as canonical example
- Human confirmed: resonates as core value, daily driver (not just insurance), needs full chain traversal (not just direct neighbors)
- Implication: graph model must support transitive queries, not just adjacency lookup

**UC-4 discussion:**
- Presented the cold-start problem: agent reads handover but has no spatial map of the system
- Human chose layered approach: floor plan first (auto-injected at session start), drill into wiring on demand
- Must be automatic (like handovers), not on-demand — agents shouldn't have to ask for orientation
- Implication: need a compact generated summary (~500 tokens) plus full detail store. Components need subsystem grouping.

**UC-1 discussion:**
- Presented the learnings bug trace as example: 4 separate grep searches to find the full component cluster
- Human confirmed both query modes equally important: topic search ("learnings") AND point traversal ("what connects to learning.sh")
- Results must include file:line references, not just component-level pointers
- Implication: components need keyword tags for topic search; edges need line-level granularity

**UC-3 discussion:**
- Human considers UI identification equally important as code-side use cases — not a "nice to have"
- Critical from page 1, not deferred until scale. Even one page needs machine-readable element identification.
- Implication: UI components must be first-class graph nodes from day one of the fabric. Cannot be a Phase 2 add-on.

**UC-5 discussion:**
- Presented T-206 commit chain as example: 3 commits to learning.sh, breakage manifested 3 hops away on /learnings page
- Human chose both: auto on every commit (post-commit hook) AND queryable on demand
- Warning only, not a gate — informational, agents not blocked. May evolve to gate later.
- Implication: blast radius is a traversal of the UC-2 dependency graph applied to git diff. No new schema, just a new query mode + hook integration.

**UC-6 discussion:**
- Presented unregistered files + stale edges as two dimensions of drift
- Human confirmed both equally important
- Both integration points: in `fw audit` for automated cron detection AND `fw fabric drift` for deep on-demand investigation
- Implication: need file-pattern rules to know what "should" be registered. Components need validation timestamps. Edges need confirmability.

