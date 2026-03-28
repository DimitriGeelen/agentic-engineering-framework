# T-010: OpenClaw Value Extraction — Adoptable Patterns and Components

## Overview

Synthesizes findings from T-007 (architecture), T-008 (patterns), T-009 (quality) into a concrete adoption roadmap. Assessed extraction feasibility for each pattern and ranked by value/effort ratio.

---

## 1. Extraction Feasibility Assessment

### Pattern A: Composition-Based Channel Abstraction

**Source:** T-008 finding — 17 optional adapter slots, composition over inheritance
**Quality:** A grade (T-009), exemplary type safety
**Files:** 25 (src/plugin-sdk/channel-*.ts)
**Core LOC:** ~400
**External deps:** @sinclair/typebox, chokidar
**Internal coupling:** HIGH — pulls from 6+ core subsystems (channels, config, routing, plugin-runtime, pairing, delivery)

**Extraction verdict:** The *pattern* is highly adoptable (adapter composition), but extracting the *code* requires also extracting channels, config, routing, and plugin runtime. **Adopt the pattern, don't copy the code.**

**What to extract:**
- The `ChannelPlugin<ResolvedAccount>` type shape (17 adapter slots)
- The `defineChannelPluginEntry()` registration pattern
- The three-phase loading model (setup-only → config → full runtime)
- The multi-account design (`listAccountIds` + `resolveAccount`)

### Pattern B: Config Hot-Reload with Declarative Rules

**Source:** T-008 finding — declarative reload rules + selective restart
**Quality:** A- grade (T-009)
**Files:** 3 (src/gateway/config-reload*.ts)
**Core LOC:** ~200
**External deps:** chokidar (file watching)
**Internal coupling:** LOW-MEDIUM — depends on config types and plugin registry

**Extraction verdict:** **Most extractable code.** 200 LOC with clear boundaries. The declarative rule system (config path → hot/restart/none) is framework-agnostic.

**What to extract:**
- `diffConfigPaths()` — diff algorithm for config changes
- `buildGatewayReloadPlan()` — rule matcher producing reload plan
- The `ReloadRule` type: `{ prefix, kind, actions[] }`
- Debounced file watcher pattern

### Pattern C: Frontmatter-Driven Skills Discovery

**Source:** T-008 finding — SKILL.md format + directory scan + eligibility
**Quality:** A- grade (T-009)
**Files:** 19 (src/agents/skills/*.ts)
**Core LOC:** ~600
**External deps:** @mariozechner/pi-coding-agent (skill format)
**Internal coupling:** MEDIUM — config, plugins, sandbox, infra

**Extraction verdict:** Bundled skills discovery is low-cost to extract. Plugin-based skills adds medium coupling. **Extract the frontmatter format + directory scanner, skip the plugin integration.**

**What to extract:**
- SKILL.md format (YAML frontmatter + markdown body)
- Directory scanning with eligibility checks (required bins, env vars)
- Token-budget-aware prompt formatting (150 skill limit, 30K char cap)
- Three-tier layering (bundled → managed → workspace)

### Pattern D: Session Key Derivation + Route Resolution

**Source:** T-007 finding — deterministic composable session keys + 7-tier routing
**Quality:** A- grade (T-009)
**Files:** 11 (src/routing/*.ts)
**Core LOC:** ~300
**External deps:** none (pure logic)
**Internal coupling:** LOW — shallow type imports from channels/config

**Extraction verdict:** **Lowest coupling, zero runtime deps, pure logic.** Most directly extractable component.

**What to extract:**
- Session key format: `agent:<agentId>:<scope>` with variants (per-peer, per-channel-peer, group)
- Route resolution cascade (7-tier priority matching)
- Binding config schema (channel + accountId + peer + guild + team + roles)
- LRU route caching with config-invalidation

### Pattern E: Request-Scoped Context (Gateway)

**Source:** T-007 finding — per-request context objects
**Quality:** A grade (T-009)
**Files:** Part of server-methods.ts
**Core LOC:** ~50 (pattern only)
**Coupling:** N/A — it's a pattern, not a module

**Extraction verdict:** **Trivial to adopt.** It's a design pattern, not extractable code. Each RPC handler receives `{ logger, broadcast, sessions, nodes, chatState }` instead of accessing globals.

### Pattern F: Multi-Provider LLM Failover

**Source:** T-007 finding — profile rotation with cooldown + auto-recovery
**Quality:** B+ grade (T-009, agent runtime complexity)
**Files:** Multiple in src/agents/ (model-selection.ts, auth-profiles.ts, provider-runtime.ts)
**Internal coupling:** HIGH — deeply integrated with Pi agent runtime

**Extraction verdict:** **Study, don't extract.** The failover logic is tightly coupled to the Pi agent runtime. The *strategy* (round-robin profiles with cooldown + auto-rotation on billing/auth errors) is adoptable, but the code isn't portable.

---

## 2. Prioritized Adoption Roadmap

Ranked by **value/effort ratio** (highest first):

| Priority | Pattern | Value | Effort | Action | Files to Study |
|----------|---------|-------|--------|--------|----------------|
| **P1** | Request-scoped context | High | Trivial | **Adopt pattern** | server-methods.ts |
| **P2** | Session key derivation | High | Low | **Extract code** | src/routing/*.ts |
| **P3** | Config hot-reload | High | Low-Med | **Extract code** | config-reload*.ts |
| **P4** | Skills discovery | Med-High | Medium | **Extract format + scanner** | src/agents/skills/workspace.ts, bundled-dir.ts |
| **P5** | Channel abstraction | High | High | **Adopt pattern, not code** | plugin-sdk/channel-contract.ts |
| **P6** | Multi-provider failover | Medium | High | **Study strategy** | model-selection.ts |

### Recommended Extraction Order

**Phase 1 — Quick Wins (1-2 days)**
1. Adopt request-scoped context pattern in our gateway handlers
2. Extract session key derivation (pure logic, zero deps, 300 LOC)
3. Extract config hot-reload (200 LOC + chokidar)

**Phase 2 — Moderate Effort (3-5 days)**
4. Extract skills discovery format (SKILL.md + directory scanner)
5. Design our own channel abstraction using OpenClaw's adapter composition pattern

**Phase 3 — Study & Design (1 week)**
6. Study multi-provider failover strategy, design our own implementation
7. Design our own plugin SDK using OpenClaw's three-phase loading model

---

## 3. Component Extraction Map

### Directly Extractable (copy + adapt)

```
src/routing/session-key.ts          → Session key format + validation
src/routing/resolve-route.ts        → Route resolution cascade
src/routing/bindings.ts             → Binding lookup
src/gateway/config-reload.ts        → File watcher + debounce
src/gateway/config-reload-plan.ts   → Declarative reload rules
src/agents/skills/workspace.ts      → Skills workspace resolution
src/agents/skills/bundled-dir.ts    → Directory scanner
src/agents/skills/frontmatter.ts    → SKILL.md parser
```

### Pattern-Only (study, reimplement)

```
src/plugin-sdk/channel-contract.ts  → Adapter composition shape
src/gateway/server-methods.ts       → RPC registry + request-scoped context
src/agents/model-selection.ts       → Provider failover strategy
```

### Not Extractable (too coupled)

```
src/agents/pi-embedded-runner/      → Pi agent runtime (3.2K LOC, Pi-specific)
src/gateway/server.impl.ts          → Full gateway (1.3K LOC, monolithic)
src/plugins/types.ts                → Plugin type system (2K LOC, OpenClaw-specific)
```

---

## 4. Assessment

**GO decision criteria met:**
- 5 patterns have favorable value/effort ratio (P1-P5)
- Extraction boundaries are clean for P1-P3 (request context, session keys, config reload)
- P4-P5 require pattern adoption rather than code extraction, which is still high value

**Key insight:** The highest-value extractions are the simplest. Session key derivation and config hot-reload are pure logic with minimal coupling. The channel abstraction and skills platform are best adopted as *design patterns* rather than code lifts.
