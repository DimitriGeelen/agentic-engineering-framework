# Deep Dive #5: The Healing Loop

## Title

My AI agent kept making the same mistake. So I taught it to learn from failure.

## Post Body

Third time this week. The agent tries to parse a YAML file, hits a syntax error, and instead of investigating, it rewrites the file from scratch. Loses the existing comments, the careful ordering, the embedded references.

I explain the fix. It works. Next session: same mistake. Zero recall.

AI agents don't learn from failure by default. Every error is experienced in isolation. There's no mechanism to say "we've seen this before, here's what worked."

### The healing loop

The [Agentic Engineering Framework](https://github.com/DimitriGeelen/agentic-engineering-framework) implements an antifragile healing loop — a system that literally gets stronger from failures:

```
Error occurs
  ↓
1. CLASSIFY — What type of failure? (code, dependency, environment, design, external)
  ↓
2. LOOKUP — Have we seen this before? Search pattern database
  ↓
3. SUGGEST — Recommend recovery using escalation ladder
  ↓
4. RESOLVE — Apply fix, record what worked
  ↓
5. LOG — Store as pattern for future reference
```

When a task hits an issue:

```bash
# Task hits a problem
fw task update T-042 --status issues --reason "YAML parse error in config.yaml"

# Healing loop activates automatically
fw healing diagnose T-042
```

Output:

```
🔍 Diagnosis for T-042
  Symptom: YAML parse error in config.yaml
  Classification: code (syntax)

  Similar patterns found:
  ├── P-023: YAML parse errors (seen 4 times)
  │   Resolution: Validate before overwrite, preserve comments
  │   Success rate: 100%
  └── P-041: Config file corruption during edit
      Resolution: Read file first, edit in-place, don't rewrite

  Suggested recovery:
  1. Read current file content
  2. Identify the syntax error (likely indentation)
  3. Fix the specific line — do NOT rewrite the entire file
  4. Validate: python3 -c "import yaml; yaml.safe_load(open('config.yaml'))"
```

### The error escalation ladder

Not every failure deserves the same response. The framework uses a graduated escalation:

| Level | Response | Example |
|-------|----------|---------|
| **A** | Don't repeat it | "We tried X, it failed — don't try X again" |
| **B** | Improve technique | "When parsing YAML, validate first" |
| **C** | Improve tooling | "Add a pre-commit YAML lint check" |
| **D** | Change ways of working | "All config changes go through a validation pipeline" |

Most failures need Level A (don't do that again). But when the same failure class appears 3+ times, it escalates: maybe the tooling needs to prevent it (C), or maybe the workflow needs to change (D).

### Pattern database

Every resolved failure becomes a pattern:

```yaml
# patterns.yaml
- id: P-023
  type: failure
  category: code
  symptom: "YAML parse error after agent edit"
  root_cause: "Agent rewrites entire file instead of editing in-place"
  resolution: "Read file, edit specific lines, validate after"
  task_origin: T-015
  occurrences: 4
  last_seen: 2026-03-01
  success_rate: 1.0
```

When a new error matches an existing pattern, the agent gets the resolution immediately — no trial-and-error, no repeated mistakes.

### Antifragility in practice

This is the key insight: **every failure makes the system more capable.**

- First YAML parse error: costs 20 minutes of debugging
- Pattern recorded: P-023
- Second occurrence: recognized in seconds, resolved with known fix
- Third occurrence: escalated to Level C — added YAML validation to verification gate
- Fourth occurrence: **doesn't happen** because the gate catches it before commit

The system didn't just recover from the failure. It became immune to it.

### The thinking behind this

The healing loop concept came from an observation about how mature engineering organizations work. When a production incident occurs at a well-run company, the response isn't just "fix it" — it's: classify, find similar incidents, apply known playbooks, record the resolution, update the playbook.

We formalized this into what we call the **error escalation ladder**. It was informed by ISO 27001's four-level assurance model, adapted for software:

| Level | ISO Equivalent | Framework Implementation |
|-------|---------------|-------------------------|
| Risk identification | Risk assessment | `.context/project/risks.yaml` (38 risks cataloged) |
| Control design | Control adequacy | 23 controls mapped to risks |
| Operational testing | OE testing | 20 of 23 controls auto-testable every 30 min |
| Discovery | Continuous improvement | Pattern detection across time |

The real breakthrough came from T-194, a multi-session inception that started with a governance failure: I asked the agent to investigate audit scheduling, and it completed the investigation in 2 minutes without ever consulting me — the human owner of the task. That failure sparked a deep review of all our controls, which revealed:

- We had **23 controls** (not 11 as assumed — our inventory was incomplete)
- **High-risk items had the weakest controls** — inverted correlation
- One critical risk (human sovereignty) had **NO structural control at all**

The healing loop was our answer to Level 4: instead of just checking "are controls working?", actively search for patterns the controls miss. We call this the discovery layer (T-200): **12 discovery capabilities** that analyze patterns across time, finding things no single check can see. Example: "58% episodic decay rate" — discovered by looking across all 170+ episodic records, impossible to see from any single task.

### The proactive side

The healing loop isn't only reactive. When the agent notices a practice repeating across 3+ tasks, it considers codifying it:

1. **Mine** episodic memory for evidence
2. **Assess** whether codification adds value
3. **Codify** if warranted (protocol, template, guideline)
4. **Record** as learning + decision

This is how the framework improves its own governance over time. It's not just a set of static rules — it's a system that evolves based on what it encounters.

### Try it

```bash
curl -fsSL https://raw.githubusercontent.com/DimitriGeelen/agentic-engineering-framework/main/install.sh | bash
cd your-project && fw init

# View known failure patterns
fw healing patterns

# Diagnose a task with issues
fw healing diagnose T-042

# Record a resolution
fw healing resolve T-042 --mitigation "Added YAML validation step"
```

GitHub: https://github.com/DimitriGeelen/agentic-engineering-framework

---

## Platform Notes

**Reddit (r/ClaudeAI, r/ChatGPTCoding):** The "rewrites the file from scratch" behavior is a known pain point. People will relate immediately.
**LinkedIn:** Frame as organizational learning — "The best teams don't just fix bugs, they build immunity. The same principle applies to AI agents."
**Dev.to:** Expand with the full pattern YAML schema and how to seed patterns from your own experience.

## Hashtags

#ClaudeCode #AIAgents #Antifragile #DevTools #OpenSource #ErrorHandling
