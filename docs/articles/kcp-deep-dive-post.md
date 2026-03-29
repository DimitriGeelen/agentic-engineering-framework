# How I Ingested Another Framework Into My Engineering Agent — and What It Found

When you govern AI agents structurally, every external codebase is both a risk and an opportunity. The risk is context pollution and uncontrolled writes. The opportunity is pattern extraction at a depth no manual review achieves. I built a repeatable workflow for this — and the first real test produced 33 actionable patterns from a project I had only read the spec of before.

## The Setup

Thor Henning Hetland's Knowledge Context Protocol (KCP) had been on my radar since March. His premise is precise: a YAML manifest (`knowledge.yaml`) that structures project knowledge for AI agent navigation. "KCP is to knowledge what MCP is to tools." The spec is at v0.14, with 17 RFCs, multi-language implementations in Java, TypeScript, and Python, and a measured result of 53-80% fewer agent tool calls compared to unguided exploration.

I had already researched the spec on paper. What I had not done was ingest the actual codebase — the implementation patterns, the testing approach, the developer experience decisions that a spec review cannot reveal.

## Path C — External Codebase Ingestion

**"Analysis happens inside the target, not from the framework."**

The Agentic Engineering Framework has three paths. Path A initialises a new project. Path B adopts governance into an existing codebase. Path C treats an external repository as an analysis target — clone it, initialise framework governance, execute seed tasks, harvest findings. The isolation requirement is structural: a TermLink session operates inside the target project. The framework session never touches external code directly.

The workflow had been proven once before, on a different codebase, with five human corrections during the process. Those corrections became the documented procedure. This was the second experiment — a cold-start test of the codified template.

The sequence: clone, spawn an isolated terminal session, initialise governance, verify health (0 failures, 3 warnings — expected for a fresh project), then dispatch an autonomous worker to execute the five seed tasks inside the target.

Four of five seed tasks passed. The fifth — defining project goals — produced a partial result with a human review pending. Framework health after ingestion: 51 audit checks passing, 7 warnings, 2 failures traceable to pre-framework git history. The template worked without tribal knowledge.

## Five Discovery Agents, Four Directives

With governance established and seed tasks complete, I dispatched five parallel discovery agents across the KCP codebase. Each explored a different domain:

1. Specification and manifest format — the YAML structure, metadata model, dependency declarations
2. MCP bridge and tool integration — how KCP exposes knowledge as MCP resources
3. Testing and conformance — cross-language test runners, validation patterns, fixture design
4. Developer experience and CLI — onboarding, CLI design, documentation approach
5. Federation and multi-agent governance — delegation chains, authority declarations, compliance models

Each agent scored every pattern it found against the framework's four constitutional directives:

- **D1 Antifragility** — does this strengthen the system under stress?
- **D2 Reliability** — does this improve predictability and auditability?
- **D3 Usability** — is this a joy to use, extend, and debug?
- **D4 Portability** — does this avoid lock-in?

Scores run 1-5 per directive, maximum 20 per pattern.

## 33 Patterns, Ranked

The five agents returned 43 raw patterns. After deduplication: 33 unique findings. The top fifteen scored 17 or higher out of 20.

**Score 20/20 — Single-source-of-truth generation.** Generate instruction files from a single manifest. KCP marks generated files with source headers to prevent drift. The framework currently maintains its agent instruction file by hand — a structural fragility.

**Score 19/20 — Four patterns tied.** Topology-first dependency declarations (declare prerequisites and conflicts between knowledge units). Intent-driven selective loading (each unit declares what question it answers — agents skip exploration entirely). Deterministic URI mapping for governance artifacts. Three-tier validation (errors block, warnings advise, clean passes silently).

**Score 18/20 — Six patterns.** Audience-targeted segmentation (different views for orchestrators, workers, debuggers). DAG federation without central coordination. Observability-first instrumentation (all operations logged to SQLite, exposed via a stats command). Incremental adoption levels (start minimal, add governance progressively). Graceful degradation for external dependencies. Cycle detection with silent ignore in dependency graphs.

**Score 17/20 — Four patterns.** Authority declarations mapping initiative versus approval per operation. Compliance as root defaults with per-unit overrides. Context window budgeting via token estimates and load priorities. Freshness validation signals.

## What We Adapted

The scoring produced a clear tier structure.

**Tier A — directly applicable, build tasks created:**

Observability instrumentation: structured event logging to SQLite with a queryable stats command. The framework has metrics but no instrumentation of what agents actually use.

Three-tier validation consistency: codify the error/warning/clean pattern across all framework tools, not just the health check and audit commands.

Context budgeting hints: add token estimates and load priorities to component cards, enhancing the existing budget management system.

Authority declarations: KCP's `initiative | requires_approval | denied` per operation maps directly to the framework's existing governance declaration layer, already approved for implementation.

**Tier B — inception tasks, exploration needed:**

Single-source-of-truth generation requires architectural evaluation. Generating the agent instruction file from a structured manifest would eliminate drift but changes the maintenance model.

Incremental adoption levels — initialising with tasks only and adding governance layers progressively — reduces onboarding friction for new projects.

DAG federation enables cross-machine knowledge graphs without central coordination. Relevant for multi-agent work but premature today.

## The Decision Rationale

**"Integrate and contribute, do not fork or reinvent."**

KCP solves a real problem the framework has: agent navigation efficiency. The 53-80% reduction in tool calls is measured, not claimed. The manifest format is MIT-licensed, the spec is versioned, and the author is actively iterating.

The framework already has the underlying data — component cards with purpose and dependencies, a context system with decisions and learnings, governance rules in structured files. What it lacks is a machine-readable discovery layer that agents can query structurally rather than search through.

The path forward is generation, not duplication. A sync command that reads component cards and context data, emits a `knowledge.yaml`, and stays on the KCP upgrade path. The MCP bridge comes for free. Future KCP spec evolution benefits the framework without rebuild cost.

Seven tasks created. Three build tasks for patterns that stand independently. Three inception tasks for patterns that need scoping. One inception task for KCP integration itself. Nothing committed to until each is individually evaluated.

## What the Process Revealed

The deep-dive produced more than a pattern list. It validated the ingestion workflow itself — a codified template that a cold-start agent followed without human intervention. It exposed friction points: worker observability (dispatched agents are invisible to the human), directory conventions not documented, git identity not inherited across terminal sessions. Each friction point became a framework improvement task.

Eight friction points found. Three template improvements applied during the experiment. One new inception task for dispatch observability.

**"The onboarding process is the test. Friction points become framework improvement tasks."**

The domain changed — from governing internal development to analysing external codebases. The principle did not: structural enforcement, measurable outcomes, every finding traced to a task.

---

*The Agentic Engineering Framework is an open governance layer for AI agent workflows. KCP (Knowledge Context Protocol) is developed by Thor Henning Hetland at Cantara. Both projects are open source.*
