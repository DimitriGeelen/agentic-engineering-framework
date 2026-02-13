# Practices — Agentic Engineering Framework

> Practices are learned patterns that emerge from using the framework.
> They derive from the four directives but are operational, not constitutional.
> A practice graduates here when it proves valuable across multiple instances.

---

## P-001: Measure What Exists, Not What Should Exist

**Derived from:** D1 (Antifragility)

**The practice:**
Don't design metrics for systems that don't exist. Build the minimum system, use it, observe what's measurable, then define metrics from observed reality.

**The pattern:**
1. Theoretical design fails or stalls
2. Pivot to building minimum viable version
3. Use it to generate real data
4. Observe what can actually be measured
5. Define metrics from observed reality
6. Extract learnings and iterate

**Why it matters:**
- Theoretical metrics measure "compliance artifacts" not outcomes
- You can't know what's measurable until you try to measure it
- Using the system reveals friction that documentation hides
- Observable change validates the approach (Traceability: 0% → 50%)

**Anti-pattern:**
Spending days designing the perfect measurement system for something that doesn't exist yet.

**Origin:** T-001 (2026-02-13)

---

## P-002: Structural Enforcement Over Agent Discipline

**Derived from:** D2 (Reliability)

**The practice:**
Don't rely on agents (or humans) to remember and follow rules. Build gates, hooks, and checks that make non-compliance harder than compliance.

**The pattern:**
1. Document the rule (specification)
2. Implement a check (automation)
3. Make the check blocking or highly visible
4. Log violations for pattern detection

**Why it matters:**
- Agents don't have persistent memory across sessions
- Humans forget, get distracted, take shortcuts
- "Documented norms" ≠ "Structural enforcement"
- Audit found: initial commit had no task because nothing prevented it

**Anti-pattern:**
Writing rules in markdown and hoping agents read and follow them.

**Origin:** Framework Coherence Agent review, T-001 (2026-02-13)

---

## P-003: Adoption Before Measurement

**Derived from:** D1 (Antifragility)

**The practice:**
Create and use the system before trying to measure it. You need usage data before metrics are meaningful.

**The pattern:**
1. Build minimum viable structure
2. Use it for real work (dogfooding)
3. Generate actual data through use
4. Then define what to measure
5. Then set targets based on observed baselines

**Why it matters:**
- Chicken-and-egg: need usage to measure, need measurement to prove value
- Break the loop by prioritizing adoption
- Metrics on an unused system are meaningless
- Real usage reveals what actually matters

**Anti-pattern:**
Designing elaborate metrics dashboards before anyone uses the system.

**Origin:** Practical Implementation Agent review, T-001 (2026-02-13)

---

## P-004: Distinguish Existence from Quality

**Derived from:** D2 (Reliability)

**The practice:**
Counting files, fields, and checkboxes is easy but misleading. Design metrics that capture whether content is meaningful, not just present.

**The pattern:**
1. Start with existence metrics (something is better than nothing)
2. Recognize their limits (easily gamed, no quality signal)
3. Add quality heuristics (length, structure, references)
4. Eventually add outcome metrics (did it help?)

**Why it matters:**
- "Task file exists" ≠ "Task is well-defined"
- "Updates section not empty" ≠ "Updates are useful"
- Compliance theater: green metrics, zero value
- Quality metrics are harder but more honest

**Anti-pattern:**
Celebrating 100% task coverage when tasks contain "TBD" and "see ticket."

**Origin:** Metrics Validity Agent review, T-001 (2026-02-13)

---

## P-005: Bootstrap Exceptions Are First-Class

**Derived from:** D1 (Antifragility), D2 (Reliability)

**The practice:**
Every system has moments that precede its own rules (creating the task system requires work before tasks exist). Document these explicitly rather than pretending they don't exist.

**The pattern:**
1. Recognize bootstrap moments when they occur
2. Document them immediately with: what, why, who authorized
3. Create retroactive records where appropriate
4. Don't let bootstrap become a permanent excuse

**Why it matters:**
- Initial commit (acb4594) had no task - this is unavoidable
- Pretending it didn't happen creates audit gaps
- Explicit exceptions are honest; silent ones are debt
- Bootstrap exceptions should shrink over time, not grow

**Anti-pattern:**
Ignoring the initial "rule-free" period and hoping no one notices.

**Origin:** T-003 creation, enforcement audit (2026-02-13)

---

## P-006: Hybrid Agent Architecture

**Derived from:** D3 (Usability), D4 (Portability)

**The practice:**
Build agents as two layers: bash scripts for mechanical operations (portable, reliable), markdown definitions for intelligence guidance (adaptable, documentable).

**The pattern:**
1. Identify mechanical operations (file creation, validation, git)
2. Implement as bash scripts (works anywhere, fails obviously)
3. Document intelligence layer in AGENT.md (what to ask, how to judge)
4. Integrate via CLAUDE.md (Claude Code) or equivalent

**Why it matters:**
- Pure bash: reliable but dumb
- Pure LLM: smart but unpredictable
- Hybrid: mechanical reliability + intelligent guidance
- Portable: bash works everywhere; AGENT.md works with any LLM

**Anti-pattern:**
Building agents as monolithic LLM prompts with no mechanical fallback.

**Origin:** T-002 design and implementation (2026-02-13)

---

## P-007: Systematic Session Capture

**Derived from:** D1 (Antifragility), D2 (Reliability)

**The practice:**
Before ending a session or changing focus, systematically scan the conversation for uncaptured work items, learnings, and decisions. Don't rely on memory.

**The pattern:**
1. Pause before context switch
2. Scan conversation for: tasks discussed, decisions made, learnings emerged, questions raised
3. Create tasks for all identified work
4. Capture learnings as practices or task updates
5. Only then proceed

**Why it matters:**
- Sessions contain more than we act on
- Initial scan created 3 tasks; thorough scan found 10+
- Reactive capture misses systemic work
- Context is lost between sessions; tasks persist

**Anti-pattern:**
Creating tasks only for the immediate next step, losing everything else discussed.

**Origin:** Meta-failure in T-001 session (2026-02-13) — we discussed 10+ work items but only created 3 tasks.

---

## Practice Lifecycle

```
                    ┌─────────────┐
                    │ DIRECTIVES  │  ← Constitutional (D1-D4)
                    │   (D-XXX)   │     Stable anchors
                    ├─────────────┤
                    │  PRACTICES  │  ← Operational (P-XXX)
                    │   (P-XXX)   │     Proven patterns ← YOU ARE HERE
                    ├─────────────┤
                    │  LEARNINGS  │  ← Recognized (L-XXX)
                    │   (L-XXX)   │     Worth remembering
                    ├─────────────┤
                    │   UPDATES   │  ← Observed (in task)
                    │ (task logs) │     Single instance
                    └─────────────┘
```

### Graduation Criteria

| From | To | Evidence Needed | Approver |
|------|-----|-----------------|----------|
| Task Update | Learning | Same pattern in 2+ tasks | Agent |
| Learning | Practice | 3+ successful applications, traces to directive | Agent |
| Practice | Directive | Universal, stable 6+ months, foundational | Human |

### Retirement Criteria

Practices can be:
- **Promoted** to a directive if they prove constitutional (human decision required)
- **Retired** if context changes or better practice emerges
- **Refined** as understanding deepens

See **T-011** for full graduation criteria specification.

---

*This is a living document. Practices emerge from use, not speculation.*
