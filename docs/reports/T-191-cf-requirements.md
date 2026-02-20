# T-191: Component Fabric — Requirements (Phase 2)

## Purpose
Use case deep dives + human validation. Synthesized from Phase 1 research and interactive dialogue.

## Priority Matrix

All 6 use cases validated as HIGH priority. No partial solution — full spatial memory system required.

| Use Case | Frequency | Trigger | Core Data Structure |
|----------|-----------|---------|-------------------|
| UC-1 Navigate | Every investigation | Agent/human curiosity | Graph traversal + topic index |
| UC-2 Impact | Every change | Pre-change analysis | Graph transitive traversal |
| UC-3 UI Identify | Every UI interaction | Agent UI reasoning | UI node cards + vertical chains |
| UC-4 Onboard | Every session start | Automatic injection | Generated summary view |
| UC-5 Regress | Every commit | Post-commit hook | Graph traversal on git diff |
| UC-6 Completeness | Every audit cycle | Cron / on-demand | Registry vs filesystem scan |

**Key insight:** The dependency graph is the single core data structure. UC-1/2/5 traverse it. UC-4 summarizes it. UC-3 extends its node types. UC-6 validates it.

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

**Phase 2a/2c synthesis:**
- All 6 use cases HIGH priority — no partial solution viable
- Core data structure: dependency graph with typed edges and transitive traversal
- Three node types: script, UI, data file
- UC-4 requires auto-injection at session start (generated compact summary)
- UC-5 reuses UC-2 graph, no new schema
- UC-6 validates the graph itself — needs file-pattern rules and staleness timestamps

---

## Minimum Viable Schema (Phase 2a synthesis)

Derived from 6 validated use cases + Phase 1 research (topology sample, UI patterns, landscape survey).

### Storage Model

```
.fabric/
  components/          # One YAML per component
    budget-gate.yaml
    learnings-page.yaml
    learnings-data.yaml
  subsystems.yaml      # Subsystem groupings (UC-4 onboarding)
  watch-patterns.yaml  # File patterns that trigger "unregistered" warnings (UC-6)
  summary.md           # Auto-generated compact overview (UC-4, injected at session start)
```

**Why one-file-per-component:** Agents read only what they need (context budget). Grep/glob find components fast. Git diff shows exactly what changed. Scales to hundreds of components.

### Component Card Schema (universal fields)

```yaml
# .fabric/components/<name>.yaml
id: C-001                        # Unique, stable identifier
name: budget-gate                # Human-readable name
type: script                     # script | hook | route | template | fragment | data | config
subsystem: budget-management     # Groups into subsystems (UC-4)
location: agents/context/budget-gate.sh  # Primary file path
tags: [budget, enforcement, context]     # Topic search keywords (UC-1)

purpose: "Block tool execution when context budget exceeds threshold"

# Dependencies — typed edges (UC-1, UC-2, UC-5)
depends_on:                      # What this component CONSUMES
  - target: F-001                # Component ID
    type: reads                  # reads | calls | triggers | extends | includes | renders
    location: agents/context/budget-gate.sh:45  # Where in source
    contract: "JSON with fields: level, tokens, timestamp"  # Soft coupling spec

depended_by:                     # What CONSUMES this component (reverse edges)
  - target: C-010                # Settings.json hook config
    type: triggers
    location: .claude/settings.json:PreToolUse

last_verified: 2026-02-20       # Staleness tracking (UC-6)
created_by: T-138               # Task traceability
```

### UI Component Card Extension

```yaml
# Additional fields for type: route | template | fragment
route:
  url: /learnings
  method: GET
  handler: web/blueprints/discovery.py:learnings  # file:function

template: web/templates/learnings.html

interactive_elements:            # UC-3: machine-readable UI identity
  - data_component: learnings-table
    data_action: sort-date
    htmx: "hx-get=/learnings?sort=date hx-swap=outerHTML"
    api_endpoint: GET /learnings?sort=date
    backend_effect: "Re-query and re-render learnings list"

template_inheritance:            # Template tree (Phase 1 decision)
  extends: _wrapper.html
  includes: [_session_strip.html]
```

### Data File Card Extension

```yaml
# Additional fields for type: data | config
format: yaml                     # yaml | json | text | markdown
schema_summary: "Map with 'learnings' key → list of {id, learning, source, task, date, context, application}"

writers: [C-005]                 # Components that write this file
readers: [C-020, C-030]         # Components that read this file
coupling: soft                   # soft = format change breaks silently
```

### Edge Types

| Type | Meaning | Example |
|------|---------|---------|
| `reads` | Opens and parses file | `discovery.py` reads `learnings.yaml` |
| `writes` | Creates or modifies file | `learning.sh` writes `learnings.yaml` |
| `calls` | Direct invocation (source, subprocess) | `context.sh` calls `learning.sh` |
| `triggers` | Event-based invocation (hooks, cron) | Settings.json triggers `budget-gate.sh` |
| `extends` | Template inheritance | `learnings.html` extends `_wrapper.html` |
| `includes` | Template inclusion | `base.html` includes `_session_strip.html` |
| `renders` | Route renders template | `/learnings` route renders `learnings.html` |
| `htmx` | Frontend-to-backend via htmx | `hx-get=/learnings?sort=date` → `discovery.py` |

### Subsystem Registry (UC-4)

```yaml
# .fabric/subsystems.yaml
subsystems:
  - id: budget-management
    name: Context Budget Management
    purpose: "Track and enforce context token budget within sessions"
    key_components: [C-001, C-002, F-001]  # Entry points for drill-down
    summary: "checkpoint.sh → budget-gate.sh → .budget-status → hooks"

  - id: learnings-pipeline
    name: Learnings Pipeline
    purpose: "Capture, store, display, and validate project learnings"
    key_components: [C-005, F-010, C-020, C-030]
    summary: "add-learning → learnings.yaml → discovery.py → /learnings + audit"
```

### Watch Patterns (UC-6)

```yaml
# .fabric/watch-patterns.yaml — file patterns that should have component cards
patterns:
  - glob: "agents/*/*.sh"
    expected_type: script
  - glob: "agents/*/lib/*.sh"
    expected_type: script
  - glob: "web/blueprints/*.py"
    expected_type: route
  - glob: "web/templates/*.html"
    expected_type: template
  - glob: ".context/project/*.yaml"
    expected_type: data
  - glob: "lib/*.sh"
    expected_type: script
  - glob: "bin/*"
    expected_type: script

# Files matching these patterns but NOT in .fabric/components/ trigger drift warnings
```

### Query Interface (CLI)

```bash
# UC-1: Navigate
fw fabric search "learnings"              # Topic search by tags/name
fw fabric get C-005                       # Get component card by ID
fw fabric deps learning.sh                # Point traversal: what connects to this file?

# UC-2: Impact
fw fabric impact learning.sh              # Full transitive downstream chain
fw fabric impact learning.sh --depth 2    # Limit traversal depth

# UC-3: UI Identify
fw fabric ui /learnings                   # All interactive elements on route
fw fabric ui --action sort-date           # Find element by data-action

# UC-4: Onboard
fw fabric overview                        # Compact subsystem summary (~500 tokens)
fw fabric subsystem budget-management     # Drill into one subsystem

# UC-5: Regress
fw fabric blast-radius HEAD               # Downstream impact of last commit
fw fabric blast-radius abc123..def456     # Impact of commit range

# UC-6: Completeness
fw fabric drift                           # Full scan: unregistered + stale
fw fabric validate C-005                  # Re-validate one component's edges
```

### Generated Summary (UC-4 auto-injection)

Auto-generated from `subsystems.yaml` + component counts. Injected at session start by SessionStart hook (like handovers). Target: ~500 tokens.

```markdown
## System Topology (auto-generated)
12 subsystems, 47 components, 83 edges

Budget Management (5 components): checkpoint.sh → budget-gate.sh → .budget-status → hooks
Task System (8 components): create-task.sh → update-task.sh → .tasks/ → audit checks
Learnings Pipeline (4 components): add-learning → learnings.yaml → discovery.py → /learnings
Context Fabric (6 components): context.sh → focus/init/status → working memory files
...
Last validated: 2026-02-20 | Drift: 0 unregistered, 0 stale
```

### Non-Functional Requirements

| Requirement | Threshold | Rationale |
|-------------|-----------|-----------|
| Component card read | < 2K tokens | Context budget (P-009) |
| Summary view | < 500 tokens | Session start injection |
| Drift scan | < 30 seconds | Must fit in audit cron (30 min cycle) |
| Blast radius query | < 5 seconds | Post-commit hook, must not slow commits |
| Registration overhead | < 5 minutes per component | Must not impede development velocity |
| File format | YAML | Human-readable, git-friendly, consistent with framework |
| No external deps | bash + python3 (already required) | D4 Portability |

