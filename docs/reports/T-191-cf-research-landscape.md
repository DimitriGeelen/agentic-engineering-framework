---
title: "Component Fabric — Research Landscape"
task: T-191
date: 2026-02-19
status: complete
phase: "Phase 1a — Research & Landscape"
tags: [component-fabric, research, architecture, dependency-tracking, UI, context-engineering]
sources_count: 14
---

# Component Fabric — Research Landscape

> **Task:** T-191 | **Date:** 2026-02-19 | **Phase:** 1a (Research & Landscape)
> **Principle:** "The thinking trail IS the artifact"

## Research Objective

Survey existing approaches to architectural knowledge management, component registries, dependency tracking, and UI element identification — to inform the Component Fabric design. Focus on what can work file-based (D4), what works for AI agents specifically, and what the industry has learned about maintaining living architecture documentation.

## 1. Architectural Knowledge Management (AKM)

### Key Source: "From Scattered to Structured" (Jan 2026 arxiv)

**Paper:** Milam et al., [arxiv 2601.19548](https://arxiv.org/html/2601.19548v1) — proposes automating AKM across heterogeneous software artifacts.

**Knowledge types identified:**
- Explicit: requirements, design diagrams, code comments, formal docs
- Implicit: embedded in developers' minds, requires contextual inference
- External: architectural styles, design patterns, industry practices
- Emerging: meeting minutes, informal notes

**Proposed pipeline (5 stages):**
1. **Extraction** — NLP/LLM for text, static analysis for code, parsing for diagrams
2. **Schema design** — Unified schema with semantic relationships and traceability links
3. **Consolidation** — Merge duplicates, resolve conflicts, handle temporal validity
4. **Knowledge base population** — Structured, queryable store
5. **Agent-based monitoring** — LLM agent monitors artifacts, detects changes, escalates

**Key insight for Component Fabric:** The paper identifies the **temporal validity problem** — "knowledge valid at one time may become obsolete at another" — and proposes versioning + time-aware queries. They also distinguish between genuine conflicts (outdated docs), extraction errors, and planned inconsistencies (unimplemented changes). This maps directly to our staleness detection need.

**Limitation:** The paper is a vision; no implementation. The schema is described abstractly, not specified concretely.

### Relevance to Component Fabric

- Confirms the multi-source extraction approach (code + docs + behavior)
- The temporal validity problem IS our staleness detection problem
- Their "agent-based monitoring" aligns with our cron-based retroactive validation
- Their traceability links concept maps to our dependency edges

---

## 2. AI-Assisted Dependency Mapping

### Key Source: Devox Software — "Using AI for Dependency Mapping"

**Source:** [Devox blog](https://devoxsoftware.com/blog/using-ai-for-dependency-mapping-in-large-codebases-a-practical-approach/)

**Five dependency layers (beyond traditional imports):**

| Layer | Description | Example in AEF |
|-------|-------------|----------------|
| **Lexical** | Direct code imports/declarations | `source "$FW_LIB_DIR/bus.sh"` |
| **Semantic** | Shared utilities, naming patterns, co-change frequency | `checkpoint.sh` and `budget-gate.sh` always change together |
| **Operational** | Runtime invocations, feature toggles, fallback paths | PreToolUse hook → budget-gate.sh → checkpoint.sh |
| **Cross-cutting** | Shared test scaffolding, macros, reflection | Git hooks shared across all agents |
| **Soft coupling** | Config volatility, silent side-effects, data shape mutations | `.budget-status` JSON format change breaks all readers |

**Three-layer ingestion:**
1. ASTs & code → syntax trees, dependency statements, build metadata
2. Telemetry → runtime traces, test coverage, CI logs
3. Behavioral signals → production logs, version control history, deployment events

**Key insight for Component Fabric:** The **soft coupling** layer is the most valuable and hardest to detect. These are dependencies that exist in behavior but not in syntax. Example: `checkpoint.sh` writes `.budget-status` as JSON; `budget-gate.sh` reads it. There's no import statement — the dependency is through a shared file format. This is exactly the kind of dependency our agents miss.

**Data structure:** Weighted edges (frequency, coupling depth, recency), contextual nodes (test lineage, release context), delta-aware updates.

### Relevance to Component Fabric

- Our dependency model MUST include soft coupling (file I/O, shared formats)
- The five-layer taxonomy is a good starting framework for edge types
- Weighted edges are important — not all dependencies are equal
- Co-change patterns from git history can surface hidden dependencies

---

## 3. C4 Model — Hierarchical Abstraction

### Key Source: [c4model.com](https://c4model.com/), [LikeC4](https://likec4.dev/)

**Four abstraction levels:**
1. **System Context** — The whole system in its environment (users, external systems)
2. **Container** — Deployable units (web app, CLI, database, file system)
3. **Component** — Building blocks within a container (modules, services, agents)
4. **Code** — Implementation details (functions, classes, files)

**Seven diagram types:** System landscape, system context, container, component, code, dynamic (runtime interactions), deployment (infrastructure).

**LikeC4 additions:**
- Architecture-as-code DSL: `cloud = system 'Our SaaS' { backend = component ... }`
- Typed relationships: `ui -[async]-> backend 'requests via HTTPS'`
- Metadata: descriptions, icons, styling, technology tags
- Git-friendly: stored as code, diffable
- MCP server exposure for AI agents

**Key insight for Component Fabric:** The C4 hierarchy maps well to AEF:
- **System** = The framework + project
- **Container** = `agents/`, `lib/`, `web/`, `bin/`, `.context/`
- **Component** = Individual scripts, route handlers, hooks, UI components
- **Code** = Functions within scripts (earned granularity)

BUT C4 is designed for **diagramming**, not for **machine-queryable registries**. We need the hierarchical thinking without the diagram-rendering focus. LikeC4's DSL approach is closest to what we need — file-based, version-controlled, with metadata.

### Relevance to Component Fabric

- Adopt C4's hierarchical abstraction (System → Container → Component → Code)
- Use LikeC4-like declarative syntax for component cards (but simpler — YAML not DSL)
- The "dynamic diagram" concept = our interaction flow documentation
- C4's "notation independent" principle aligns with D4 (Portability)

---

## 4. Component Manifests for AI Agents

### Key Source: Storybook Design Systems MCP RFC

**Source:** [Storybook DS MCP Discussion](https://github.com/storybookjs/ds-mcp-experiment-reshaped/discussions/1), [Agentic UI Tracking Issue](https://github.com/storybookjs/storybook/issues/32276)

**Component manifest fields:**
- Component identity (name, unique ID)
- Short and long descriptions
- Props schema (keys, types, defaults, descriptions)
- Code examples (derived from stories) with contextual notes
- Related components and documentation links
- TypeScript type definitions

**Three MCP tools for agent consumption:**
1. `list_components` — Discovery: what exists?
2. `get_component_details` — Deep dive: what is this component?
3. `search_by_keywords` — Query: what's related to X?

**Distribution:**
- Dev server: `localhost:6006/manifest/components.json`
- NPM package: `node_modules/my-ds/manifest/`
- Published: `https://storybook.example.com/manifest/`

**Key insight for Component Fabric:** The three-tool pattern (list, get, search) is exactly the query interface we need. And the evolutionary approach to manifest generation is smart:
- v0: LLM-generated markdown (proof of concept)
- v0.2: Server-side extraction (names, descriptions)
- v1.0: Story-based example code generation
- v1.1: Full documentation inclusion

This maps to our adaptive granularity: start with basic registration, deepen with use.

### Relevance to Component Fabric

- Adopt the three-tool query pattern: list, get, search
- Component manifests as the unit of documentation (one file per component)
- Evolutionary manifest generation (coarse → detailed)
- The MCP exposure pattern could work for `fw fabric` commands

---

## 5. UI Element Identification for Agents

### Key Sources: Google A2UI, Storybook Agentic Research, Autosana

**Google A2UI** ([blog](https://developers.googleblog.com/introducing-a2ui-an-open-project-for-agent-driven-interfaces/)):
- Declarative data format (JSON), not executable code
- Flat list of components with **ID references** — easy for LLMs to generate/parse
- Separates UI structure from UI implementation
- Pre-approved "catalog" of trusted UI elements
- Cross-platform: same payload renders on web, mobile, native

**Storybook Agentic UI Research:**
- Without proper context, agents "produce unmergeable output, generating new code instead of reusing existing components"
- Stories serve as "machine-readable documentation" — working examples of components
- Local MCP server with filesystem access can infer available components programmatically

**Autosana / AI Testing:**
- Dynamic identification: agents analyze DOM, XML, visual layout, API responses simultaneously
- Self-healing selectors: survive UI redesigns without breaking
- Vision models interpret UI "the way a human tester would"

**Key insight for Component Fabric:** For our specific problem (CLI-based agent, Flask web UI), the core challenge is: **the agent cannot observe the rendered page**. It needs:

1. **Semantic identity** for every interactive element: not just `<select id="status-dropdown">` but `TaskStatusChanger: renders task status options, calls PATCH /api/task/:id/status, updates task_detail.html`
2. **Interaction flow declarations**: `UserClicksStatus → SelectOption → FetchAPI → UpdateBackend → RefreshPage`
3. **Component-to-backend mapping**: which template renders it, which route handles it, which function processes it

A2UI's "flat list of components with ID references" is the simplest model that could work for us — but adapted to describe EXISTING UI, not generate new UI.

### Relevance to Component Fabric

- UI elements need semantic IDs that map to their full interaction chain
- Interaction flows must be declarative (not inferred from code at query time)
- The A2UI "catalog" concept = our UI component registry
- Self-healing selectors concept → our staleness detection for UI components

---

## 6. Context Engineering for Coding Agents

### Key Sources: Martin Fowler, Propel Guide, Anthropic Trends

**Martin Fowler** ([article](https://martinfowler.com/articles/exploring-gen-ai/context-engineering-coding-agents.html)):
- File reading/searching is "the most basic and powerful context interface"
- Distinguishes Instructions (specific actions) from Guidance (conventions)
- **Notable gap: NO discussion of architecture awareness or system topology**
- Context engineering currently focuses on task-level instructions, not structural comprehension

**Propel — Structuring Codebases for AI** ([guide](https://www.propelcode.ai/blog/structuring-codebases-for-ai-tools-2025-guide)):
- AGENTS.md spec: operational info AI tools need (build commands, style, architecture overview)
- "AI tools perform best with predictable, conventional directory structures"
- Recommends: document cross-component relationships, API endpoints consumed by frontend, data model consistency
- Suggests CI/CD validation of documentation and tracking undocumented components

**Industry landscape:**
- Context engineering has replaced prompt engineering as the key discipline
- Focus is on **what context to provide**, not on making the system self-documenting
- No existing framework addresses structural topology as a first-class context layer

**Key insight for Component Fabric:** This is the gap we're filling. Current context engineering says "provide good instructions and let agents read files." But nobody is addressing "make the system's topology queryable so agents don't NEED to read every file." AGENTS.md/CLAUDE.md tells agents HOW to work. Component Fabric tells them WHAT EXISTS and HOW IT CONNECTS. These are complementary layers.

### Relevance to Component Fabric

- We're building a layer that doesn't exist in the current ecosystem
- CLAUDE.md = behavioral context (how to work); Component Fabric = structural context (what to work with)
- The Propel recommendation for CI/CD validation of docs → our cron-based validation
- Tracking undocumented components → our completeness/orphan detection

---

## 7. Synthesis: What Exists vs What We Need

### What EXISTS in the Ecosystem

| Capability | Tool/Approach | Limitation for Us |
|-----------|---------------|-------------------|
| Architecture diagrams | C4/Structurizr/LikeC4 | Diagram-focused, not query-focused |
| Component manifests | Storybook MCP | React/frontend only, not universal |
| Dependency graphs | CodeGraphContext, Pants | Require graph databases or specific build systems |
| Architecture docs | arc42, AGENTS.md | Static, manual, goes stale |
| Code understanding | AI file reading/grep | No structural awareness, scales linearly |
| UI identification | A2UI, Playwright | For generating/testing UI, not documenting existing |
| Knowledge management | AKM papers | Vision-level, not implemented |

### What DOESN'T EXIST (our opportunity)

1. **A file-based, portable component registry** that's machine-queryable without a database
2. **Adaptive granularity** that deepens documentation based on complexity signals
3. **Soft coupling detection** for file-based dependencies (shared formats, event flows)
4. **UI interaction flow declarations** for existing (not generated) web apps
5. **Enforcement integration** that gates code changes on component registration
6. **Retroactive validation** that detects topology drift via periodic scanning
7. **Universal applicability** — works for any language, framework, or project structure

### What We SHOULD ADOPT from the Ecosystem

| Concept | Source | How to Adapt |
|---------|--------|-------------|
| Hierarchical abstraction (System → Container → Component → Code) | C4 Model | Use as organizational levels, not diagram types |
| Component manifest with identity, description, interfaces, relationships | Storybook MCP RFC | YAML files, one per component, in `.fabric/` |
| Three query tools: list, get, search | Storybook MCP RFC | `fw fabric list`, `fw fabric get`, `fw fabric search` |
| Five dependency layers (lexical → soft coupling) | Devox | Edge types in our dependency model |
| Temporal validity + versioning | AKM paper | Staleness detection in cron validation |
| Declarative UI element catalog with ID references | Google A2UI | UI component cards with interaction flow declarations |
| Evolutionary manifest generation (coarse → detailed) | Storybook MCP RFC | Adaptive granularity model |
| Co-change analysis from git history | Devox | Automated dependency discovery |

---

## 8. Open Questions for Phase 1b-2

1. **Schema specifics:** What YAML fields go in a component card? (Phase 3)
2. **File location:** `.fabric/` in project root? `.context/fabric/`? Component cards co-located with code? (Phase 3)
3. **Auto-generation baseline:** Can we auto-generate coarse component cards from `find` + file analysis? (Phase 1b spike)
4. **Soft coupling detection:** Can git co-change analysis realistically surface hidden dependencies? (Phase 1b spike)
5. **UI flow format:** What's the minimum viable format for declaring UI interaction chains? (Phase 2)
6. **Query cost:** How much context does a `fw fabric get` consume? Must be <2K tokens per component. (Phase 3)
7. **Enforcement timing:** Pre-commit hook? Post-commit audit? Or check at `fw task update --status work-completed`? (Phase 4)

---

## Sources

1. [From Scattered to Structured: Automating AKM](https://arxiv.org/html/2601.19548v1) — Milam et al., Jan 2026
2. [AI for Dependency Mapping in Large Codebases](https://devoxsoftware.com/blog/using-ai-for-dependency-mapping-in-large-codebases-a-practical-approach/) — Devox Software
3. [C4 Model](https://c4model.com/) — Simon Brown
4. [LikeC4](https://likec4.dev/) — Architecture as code
5. [Storybook Agentic UI Research](https://github.com/storybookjs/storybook/issues/32276) — Storybook team, 2025
6. [Storybook DS MCP Experiment RFC](https://github.com/storybookjs/ds-mcp-experiment-reshaped/discussions/1) — Component manifest design
7. [Context Engineering for Coding Agents](https://martinfowler.com/articles/exploring-gen-ai/context-engineering-coding-agents.html) — Martin Fowler
8. [Structuring Codebases for AI Tools](https://www.propelcode.ai/blog/structuring-codebases-for-ai-tools-2025-guide) — Propel, 2025
9. [Google A2UI Project](https://developers.googleblog.com/introducing-a2ui-an-open-project-for-agent-driven-interfaces/) — Agent-to-UI specification
10. [CodeGraphContext MCP Server](https://github.com/CodeGraphContext/CodeGraphContext) — Code graph for AI assistants
11. [Autosana — Agentic UI Testing](https://siliconangle.com/2026/02/17/autosana-lands-3-2m-automate-mobile-web-ui-testing-agentic-ai/) — Feb 2026
12. [Documenting Software Architectures](https://newsletter.techworld-with-milan.com/p/documenting-software-architectures) — Milan Milanovic
13. [Software Dependency Graphs](https://www.puppygraph.com/blog/software-dependency-graph) — PuppyGraph
14. [2026 Agentic Coding Trends](https://resources.anthropic.com/hubfs/2026%20Agentic%20Coding%20Trends%20Report.pdf) — Anthropic
