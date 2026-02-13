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
- Attempted to define success metrics theoretically
- Critical review revealed metrics were unmeasurable
- Pivoted to experimentation
- Created .tasks/, metrics.sh, first task
- Observed real metric change
- Learning emerged from doing

---

## Practice Lifecycle

```
Observation in task → Repeated pattern → Candidate practice → Proven practice
```

Practices are not permanent. They can be:
- **Promoted** to a directive if they prove constitutional
- **Retired** if they stop being useful
- **Refined** as understanding deepens

---

*This is a living document. Practices emerge from use, not speculation.*
