---
title: "Component Fabric — Genesis Discussion"
task: T-191
date: 2026-02-19
status: complete
phase: "Phase 0 — Problem Framing"
tags: [component-fabric, inception, discussion, requirements]
participants: [human, claude-code]
---

# Component Fabric — Genesis Discussion

> **Task:** T-191 | **Date:** 2026-02-19 | **Phase:** 0 (Problem Framing)
> **Context:** Initial discussion between human and agent that defined the problem space, goals, and inception scope.

## Origin

The human identified a scaling problem during session S-2026-0219 while discussing T-190 (sub-agent research persistence). The observation: as the AEF codebase grows (scripts, agents, web UI, hooks, configurations), the ability to understand, debug, and enhance the system degrades because **the living topology of the code is not documented or tracked**. The framework has strong temporal memory (what happened) but weak spatial memory (what exists and how it connects).

## Problem Statement (Human's Words, Synthesized)

> "As our codebase grows, we get functions, routines, sequences of steps and dependencies that make up the application functionality. UX listeners, UX elements. It becomes more and more difficult to debug and enhance the application as this is currently not strictly well documented. We need something deep and thorough — an enforced part of the workflow. With every piece of functionality, code, script, documentation, or UI we create, this becomes part of our persistent memory and can easily be found."

> "Going forward as the app gets more complex, reading all documents will not work anymore."

## Key Design Questions and Answers

### Q1: Scope — this framework only, or universal?
**Answer: Universal.** The Component Fabric should work for any project governed by AEF, not just the framework repository itself.

### Q2: What granularity?
**Answer: Adaptive — "can we learn as we go?"** Don't prescribe fixed granularity. Start coarse (file-level), refine where complexity and change frequency demand it. The system's own usage patterns determine where to invest documentation depth.

### Q3: Technology/format?
**Answer: No opinion — focus on goals and use cases first.** Explicitly rejected jumping to solutions (vector DB, flatfile, Mermaid). The use cases and goals should drive the technology choice, not the reverse.

### Q4: Enforcement model?
**Answer: Both proactive and retroactive.** Gates prevent new drift (like the task-first PreToolUse hook). Retroactive validation via cron jobs detects accumulated drift (like the existing audit system). Parallel to how AEF already uses both preventive (hooks) and detective (audit) controls.

### Q5: Is the web UI a primary motivator?
**Answer: Not specifically the web UI — it's the general problem of UI in agentic development.** The agent cannot observe user interaction. UI elements and interaction flows must be unambiguously identifiable through documentation/metadata, not through visual inspection. This makes UI components particularly hard to work with and particularly valuable to document.

## Six Use Cases Identified

1. **Contextual navigation** — "Show me everything involved in task completion" → structured component + dependency traversal
2. **Impact analysis** — "If I change task file format, what breaks?" → reverse dependency query
3. **UI element identification** — "The status dropdown is broken" → unambiguous path from UI element → event → API → backend → state
4. **Onboarding** — Fresh agent understands system shape in seconds from component graph, not minutes of reading
5. **Regression tracing** — Connect a commit to its downstream effects structurally
6. **Completeness validation** — Detect orphan components (files that exist but aren't in the topology)

## Core Design Principles Established

1. **Structural self-awareness** — The system should know what it is (spatial memory), not just what happened (temporal memory)
2. **Earn your detail** — Granularity is adaptive: starts coarse, deepens where complexity and change frequency warrant it
3. **UI as first-class** — UI elements and interaction flows are documented as explicitly as backend components, because agents can't see them
4. **Enforced, not optional** — Like task-first, component registration is a structural gate, not a suggestion
5. **Practice what you preach** — The inception process itself must persist all research and thinking as durable artifacts (T-190 principle)

## Name Decision

**Component Fabric** — chosen by human. Parallel to "Context Fabric" (the existing memory system). Context Fabric = temporal memory. Component Fabric = spatial memory.

## Scope Decision

**5-10 sessions** — The human emphasized this is "ultra valuable, essential for being able to scale application development and functionality." This is foundational infrastructure, not a quick feature.

## Meta-Process Decision

All sub-agent research, discussion syntheses, and decision rationale must be saved to `docs/reports/T-191-cf-*.md` with proper frontmatter. The thinking trail is the artifact. If session 7 crashes, sessions 1-6's research must be fully recoverable from persistent documents, not from handovers or context windows.

## Related Tasks

- **T-120** — Google Context Engineering review (identified memory consolidation gap; Component Fabric extends this to code topology)
- **T-130** — GSD investigation (identified codebase-mapper concept as adoptable pattern)
- **T-190** — Sub-agent research persistence (the meta-problem that Component Fabric's inception will demonstrate solving)

## Next Steps

Begin Phase 1a: Web research on existing approaches to architectural knowledge management, living documentation, and dependency tracking in AI-assisted development.
