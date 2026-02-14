# Vision — Agentic Engineering Framework

> This document captures what the project is trying to achieve and how we'll know if it's working.

---

## The Problem

AI agents (Claude Code, etc.) working on software projects currently operate without:
- **Accountability** — Actions aren't traced to deliberate intent
- **Learning** — Failures are forgotten between sessions
- **Governance** — No structural enforcement of human oversight
- **Memory** — Context is lost, every session starts fresh

The result: agents are powerful but ungoverned. Humans can't audit what happened or why. Mistakes repeat. Knowledge doesn't accumulate.

---

## The Vision

A governance framework where:
- **Nothing gets done without a task** — Every action traces to documented intent
- **Failures become learning** — Errors are captured, patterns emerge, capability grows
- **Humans retain sovereignty** — Agents propose, framework enforces, humans decide
- **Context persists** — Tasks feed memory that survives sessions

---

## The Success Question

> "When is this project successful? How can we measure progress?"

This question was asked on 2026-02-13. The journey to answer it:

### Attempt 1: Theoretical Metrics (Failed)

Proposed metrics based on the four directives:
- Antifragility: failure patterns decrease over time
- Reliability: 100% task traceability
- Usability: low bypass request frequency
- Portability: works across providers

**Problem:** These were unmeasurable. No tooling, no data, no baselines.

### Attempt 2: Critical Review

Three agents reviewed our thinking:

1. **Metrics Validity Agent:** We were measuring "compliance artifacts" not outcomes. Metrics easily gamed. Missing: learning loops, enforcement compliance, task quality.

2. **Practical Implementation Agent:** Minimum tooling needed is nearly zero. One bash script. Create tasks before measuring tasks.

3. **Framework Coherence Agent:** "Structural enforcement" is currently "documented norms." The chicken-and-egg problem is real. We're solving a specification problem when it's actually an adoption problem.

**Key insight:** "You can't measure what doesn't exist."

### Attempt 3: Experimentation (Current)

Pivot: Build minimum viable, use it, observe what's measurable, define metrics from reality.

Actions taken:
- Created `.tasks/` structure
- Created T-001 (this task)
- Created `metrics.sh`
- Observed real change: Traceability 0% → 50% → 66%

**Learning extracted:** P-001 "Measure what exists, not what should exist"

---

## Current State (2026-02-14)

### What Exists

| Component | Status |
|-----------|--------|
| Directives (constitutional principles) | Defined |
| Task System (specification + enforcement) | Operational |
| Enforcement Config (specification) | Defined |
| Task Structure (`.tasks/`) | Active — 35 completed tasks |
| Metrics Script | Working |
| Practices | 7 captured (P-001 through P-007) |
| Git Traceability | 90% of commits reference tasks |
| Agents | 8 operational: audit, context, git, handover, healing, resume, task-create, session-capture |
| `fw` CLI | Operational — unified wrapper for all agents |
| Context Fabric | Operational — working, project, and episodic memory |
| Healing Loop | Operational — diagnose, resolve, pattern extraction |
| Experiment Protocol | Tested — E-002 through E-005 completed |

### What's Measurable Now

```
- Task count (active/completed): 35 completed
- Task status distribution
- Git commit traceability: 90%
- Task file modification recency
- Quality metrics (via audit agent)
- Episodic summary quality scores
- Practice count and coverage
- Context Fabric state (working/project/episodic memory)
- Healing pattern library size
```

### What's NOT Measurable Yet

```
- Whether the framework improves outcomes across different projects
- Long-term learning loop effectiveness (multi-project)
- Cross-team adoption friction
- Framework overhead vs. productivity gains (quantified)
```
---

## Success Criteria (Evolving)

We are discovering success criteria through use. Stages 1-2 are achieved; Stage 3 is in progress.

### Stage 1: Adoption (Achieved)
> Is the system being used at all?

| Metric | Target | Current |
|--------|--------|---------|
| `.tasks/` exists | Yes | Yes |
| Active tasks > 0 | Yes | Yes |
| Commits with task refs | > 50% | 90% |

### Stage 2: Engagement (Achieved)
> Is it being used meaningfully?

| Metric | Target | Current |
|--------|--------|---------|
| Tasks completed | >= 3 | 35 |
| Tasks with Updates entries | 100% | 100% |
| Practices extracted | >= 2 | 7 |

### Stage 3: Effectiveness (In Progress)
> Is it actually helping?

| Metric | Target | Current |
|--------|--------|---------|
| Rework rate | Decreasing | Observed — healing loop captures patterns |
| Time in "issues" status | Decreasing | Improving — healing agent accelerates recovery |
| Learnings applied from past tasks | Increasing | Yes — practices and patterns actively referenced |
| Context survives session boundaries | Yes | Yes — handover + Context Fabric operational |

### Stage 4: Antifragility (Emerging)
> Does it get stronger under stress?

| Metric | Target | Current |
|--------|--------|---------|
| Novel failures lead to new practices | Yes | Yes — 7 practices extracted from real failures |
| Recovery time improves over similar failures | Yes | Emerging — healing pattern library growing |
| Framework evolves based on usage friction | Yes | Yes — agents and CLI created from friction |
---

## Open Questions

1. ~~**What would prove this approach wrong?** (Falsifiability)~~ → **Answered in T-009**
2. **Who is this framework for?** Individual? Team? Enterprise? → See T-010
3. ~~**What's the minimum viable enforcement?** If we could only build one gate, what?~~ → **Answered in T-021: Git commit hook (task reference required)**
4. ~~**How do we measure quality, not just existence?**~~ → **Answered in T-008 (quality metrics)**
5. **When does a learning graduate from task → practice → directive?** → See T-011

---

## Related

- **T-001:** Define measurable success metrics (active task for this work)
- **P-001:** Measure what exists, not what should exist
- **005-DesignDirectives.md:** Constitutional principles
- **010-TaskSystem.md:** Task structure and lifecycle

---

*This is a living document. It evolves as our understanding deepens.*
