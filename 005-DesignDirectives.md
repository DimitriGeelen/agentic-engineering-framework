# Design Directives — Agentic Engineering Framework

> These directives are the constitutional principles of this project.
> Every architectural decision, API design, and implementation choice
> must be traceable back to one or more of these directives.
> They are listed in priority order.

---

## Directive 1: Antifragility

**The system must get stronger under stress, not merely survive it.**

- Failures are learning events, not just errors to recover from.
- Every failure path must produce structured insight that improves future behavior.
- The framework should benefit from disorder: unexpected inputs, novel error types,
  and edge cases should expand the system's capability over time.
- Design for the unexpected — rigid systems are fragile systems.

**Architectural implications:**
- Feedback loops are mandatory, not optional.
- Error handling must capture *why* something failed, not just *that* it failed.
- Context from failures must be persisted and queryable.
- Recovery strategies must evolve based on observed patterns.

---

## Directive 2: Reliability

**The system must behave predictably and consistently under known conditions.**

- Observable, traceable execution — every decision the system makes must be auditable.
- Deterministic where possible, gracefully non-deterministic where necessary (LLM outputs).
- No silent failures. Every operation reports its outcome explicitly.
- State management must be robust — no orphaned state, no invisible corruption.

**Architectural implications:**
- Structured logging and tracing at every layer.
- Explicit state machines for workflow execution.
- Health checks and invariant assertions throughout.
- Idempotent operations where feasible.

---

## Directive 3: Usability (Developer Experience)

**The framework must be a joy to use, extend, and debug.**

- Sensible defaults with full override capability.
- Clear, consistent APIs — if you've used one tool adapter, you can guess the next.
- Errors must be actionable — tell the developer what went wrong AND what to try.
- Documentation is a first-class deliverable, not an afterthought.
- Progressive disclosure of complexity: simple things simple, complex things possible.

**Architectural implications:**
- Convention over configuration, but configuration always available.
- Unified interface patterns across all layers (Tool, Context, Workflow, Agent).
- Rich error types with suggested remediation.
- Examples and templates for every major capability.

---

## Directive 4: Portability

**The framework must not be captive to any single provider, language, or environment.**

- LLM provider independence: swap between Anthropic, OpenAI, local models, etc.
- Language agnosticism for agents: the framework orchestrates; agents can be in any language.
- Environment agnosticism: local dev, CI/CD, cloud, edge.
- Protocol-based integration: prefer standards (MCP, LSP, OpenAPI) over proprietary interfaces.

**Architectural implications:**
- Pluggable provider layer with uniform interface.
- MCP for tool exposure to LLMs.
- Spec-driven contracts between layers (JSON Schema, Protocol Buffers, or similar).
- No hard dependency on any single cloud provider or runtime.

---

## How These Directives Interact

```
Antifragility ←→ Reliability
    │                 │
    │  Antifragility needs Reliability as its foundation.
    │  You can't learn from failures if you can't
    │  reliably observe and record them.
    │                 │
    ▼                 ▼
Usability ←———→ Portability
    │                 │
    │  Portability without Usability is academic.
    │  Usability without Portability is a trap.
    │  Together they ensure the framework is both
    │  accessible and free.
    │                 │
    └────────┬────────┘
             │
    All four converge on the same principle:
    BUILD SYSTEMS THAT EMPOWER, NOT CONSTRAIN.
```

---

## Decision Log

> Every significant architectural decision should be recorded here
> with a reference to which directive(s) it serves.

| Date       | Decision                                          | Directives Served | Rationale |
|------------|---------------------------------------------------|-------------------|-----------|
| 2026-02-13 | LLM integration via layered approach: Direct API → Pluggable Provider → MCP | D1, D2, D4 | Direct API ensures reliability (D2). Pluggable layer ensures portability (D4). MCP ensures standard tool interface. Layering ensures antifragility (D1) — any layer can evolve independently. |
| 2026-02-13 | Context Fabric as foundational layer (#2 in stack) | D1, D2, D3 | Context is the spine — self-healing (D1) and self-learning (D1) depend on structured context. Reliable state (D2). Relevance scoring improves DX (D3). |
| 2026-02-13 | Design directives recorded in `docs/DESIGN_DIRECTIVES.md` | D2, D3 | Traceability (D2). Onboarding clarity (D3). |
| 2026-02-13 | Composition hierarchy: Scripts → Commands → Skills → Agents | D1, D3, D4 | Commands are the universal interface boundary (D4). Skills group by domain (D3). Agents compose skills. "Automate downward" principle pushes stable logic into scripts (D1). |
| 2026-02-13 | Staged manifest maturity: Exploration → Stabilization → Automation | D1, D2, D3 | Exploration: sparse, human-in-loop. Stabilization: collaborative, framework observes and suggests enrichments. Automation: full contract, agent-reliable. Manifests grow from reality, not speculation (D1). Low friction to start (D3). Full contracts when stakes are high (D2). |
| 2026-02-13 | Dual manifest structure: manifest.yaml + COMMAND.md | D2, D3 | Machine-readable contract (D2) paired with human-readable judgment guide (D3). LLMs read both — manifest for *how*, COMMAND.md for *whether and why*. |
| 2026-02-13 | Framework targets Claude Code as primary environment | D3, D4 | File-based, CLI-friendly, CLAUDE.md-compatible. Context Fabric can generate project-level CLAUDE.md from command/skill/agent structure. |
| 2026-02-13 | Task storage: Markdown with YAML frontmatter, git-synced | D1, D2, D3, D4 | Human-readable when framework breaks (D1). Machine-parseable frontmatter (D2). Editable in any editor/Claude Code (D3). Git-syncable, no vendor lock (D4). |
| 2026-02-13 | Task enforcement: Strict by default, four-tier bypass model | D1, D2 | Tier 0: never bypass (consequential). Tier 1: strict default. Tier 2: human situational. Tier 3: pre-approved (ITIL standard change). Structural enforcement over agent discipline (D2). |
| 2026-02-13 | Authority model: Agent=initiative, Framework=authority, Human=sovereignty | D1, D2 | Agent proposes, framework enforces, human overrides. Prevents agent drift (D2). Enables antifragile governance (D1). |
| 2026-02-13 | Tasks can engage multiple agents (primary + supporting) | D3 | Avoids artificial task fragmentation. Unified traceability. Workflow type guides agent relevance. |
| 2026-02-13 | Error response escalation ladder: A(don't repeat) → B(improve technique) → C(improve tooling) → D(change ways of working) | D1 | Graduated response to failures from tactical to structural. |

---

*This is a living document. It evolves as our understanding deepens,
but the four directives themselves are stable anchors.*
