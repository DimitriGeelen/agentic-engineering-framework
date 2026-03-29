# T-705: KCP Integration Research

## Problem Statement

The framework has rich structural data (fabric cards, context YAML files, task state, learnings, decisions) but no standard way for external AI agents or tools to discover and navigate this knowledge. KCP (Knowledge Context Protocol) provides exactly this: a `knowledge.yaml` manifest that makes project knowledge navigable by AI agents.

**Integration question:** Should the framework generate a `knowledge.yaml` from its existing data and adopt the kcp-mcp bridge for agent-accessible context?

## Prior Research

- **T-487** (2026-03-14): Evaluated KCP spec v0.10 for T-477 governance declaration layer. Found: advisory metadata format, 3 conformance levels, 289 CLI manifests, federation support, 53-80% fewer agent tool calls claim
- **T-697** (2026-03-29): Path C deep-dive on KCP codebase itself. Validated: Java+TS+Python implementations, MCP bridge pattern, conformance testing, 17 RFCs

## What Integration Would Look Like

### Phase 1: Generate `knowledge.yaml` from Existing Data

Map existing framework data to KCP units:

```yaml
project: "my-project"
kcp_version: "0.14"
units:
  # From fabric cards
  - id: "subsystem-context-fabric"
    topic: "Context Fabric"
    summary: "Persistent memory system — working, project, episodic"
    content_type: reference
    source_files:
      - agents/context/context.sh
      - agents/context/lib/*.sh

  # From task state
  - id: "active-tasks"
    topic: "Current Work"
    summary: "Active tasks and their status"
    content_type: reference
    api_endpoint: "fw task list --json"
    freshness: dynamic

  # From learnings
  - id: "project-learnings"
    topic: "Learnings"
    summary: "Knowledge gained during development"
    source_files:
      - .context/project/learnings.yaml
    freshness: accumulating

  # From decisions
  - id: "architectural-decisions"
    topic: "Decisions"
    summary: "Architectural choices with rationale"
    source_files:
      - .context/project/decisions.yaml
```

**Generator:** A script (`fw kcp generate` or `lib/kcp.sh`) that reads fabric cards and context YAML, emits `knowledge.yaml`.

### Phase 2: kcp-mcp Bridge

Add the kcp-mcp bridge to `.mcp.json` so AI agents can query project context via MCP tools:

```json
{
  "mcpServers": {
    "kcp": {
      "command": "npx",
      "args": ["-y", "@anthropic/kcp-mcp-bridge", "--manifest", "knowledge.yaml"]
    }
  }
}
```

This would let any MCP-aware agent discover project structure, task state, learnings, and architectural decisions without reading dozens of files.

## Analysis

### Benefits

1. **Standard format** — knowledge.yaml is an emerging standard with multi-language tooling. Better than our custom `.fabric/` cards for external consumption
2. **MCP bridge** — agents get structured access to project context without reading raw YAML files
3. **Federation** — could link framework knowledge to consumer project knowledge (multi-project context sharing)
4. **Community positioning** — being an early KCP adopter strengthens the "we adopt standards" narrative (D4 Portability)
5. **Token budget guidance** — KCP `hints.total_token_estimate` helps agents decide what to load (aligns with P-009)

### Costs and Risks

1. **KCP is early-stage** — v0.14 spec, still actively evolving. The spec may change in ways that break our generator. 17 RFCs suggest rapid iteration
2. **Adoption unknown** — KCP has no significant production adopters yet beyond Cantara's own projects. We'd be betting on a standard that may not gain traction
3. **Generator maintenance** — every new fabric card, context file, or task field change would need a generator update. This is the T-702 problem (sync burden) with an external format
4. **kcp-mcp bridge dependency** — adds `npx` / npm dependency to the MCP config. The framework currently has zero npm dependencies for core. Violates D4 (Portability) ironically while trying to serve it
5. **Overlap with existing mechanisms:**
   - Fabric cards already serve the "structural navigation" purpose for agents reading the codebase
   - CLAUDE.md already tells the agent about project structure and conventions
   - `.context/` YAML files are directly readable
   - The real question: is knowledge.yaml better than what we already have?
6. **Thor Henning Hetland (Cantara) relationship** — adopting KCP builds community, but it's a one-person-plus-small-team project. Dependency risk if development stalls

### Key Question: Does the Framework Need This?

The framework's target agent (Claude Code) already has:
- CLAUDE.md auto-loaded at session start (full project context)
- Read tool for accessing any file
- Fabric overview/deps/impact commands for structural navigation
- Context agent for memory management

KCP's value proposition is "agents waste tool calls exploring unfamiliar codebases." But the framework already solves this through CLAUDE.md + handovers + fabric. The agent isn't exploring blindly — it starts every session with a full context recovery (LATEST.md, focus.yaml, session.yaml).

**Where KCP would add value:**
- External agents (not Claude Code) that don't have CLAUDE.md
- Cross-project discovery (agent working on project A queries knowledge.yaml of project B)
- Multi-agent scenarios where non-primary agents need context (G-004)

These are future scenarios, not current needs.

## Recommendation

**DEFER** — the pattern is valuable, the timing is wrong.

### Rationale

1. **No immediate need** — the framework already provides rich context to its primary agent (Claude Code) through CLAUDE.md, handovers, and fabric. Adding knowledge.yaml would duplicate existing context delivery in a different format
2. **KCP is still maturing** — v0.14 with 17 active RFCs. Adopting now risks rebuilding when the spec stabilizes
3. **npm dependency concern** — the kcp-mcp bridge requires npm/npx. The framework has zero npm core dependencies. Adding one for KCP breaks the "no package manager dependencies" principle
4. **Generator maintenance burden** — same problem as T-702 (single-source-of-truth): keeping generated output in sync with evolving source data
5. **Revisit triggers:**
   - When KCP reaches v1.0 (spec stability)
   - When multi-agent coordination is implemented (G-004 gap resolved)
   - When a second AI coding agent (not Claude Code) needs framework context
   - When the community shows adoption signal (3+ production users beyond Cantara)

### What to Do Now

1. **Watch KCP development** — track v1.0 milestone, note when MCP bridge matures
2. **Keep fabric cards** — they serve the same purpose for our primary agent
3. **Reference in launch content** — mention KCP as a standard we're watching (positions us as standards-aware)
4. **If Thor asks** — we're interested in generating knowledge.yaml as a downstream output of our fabric cards once the spec stabilizes. We could contribute upstream: governance-specific unit types, enforcement metadata
