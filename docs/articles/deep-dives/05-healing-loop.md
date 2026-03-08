# Deep Dive #5: The Healing Loop

## Title

Governing AI Agents: The Healing Loop — how failure makes the system stronger

## Post Body

**Systems that merely recover from failure are fragile. Systems that learn from failure are antifragile.**

In incident management, the difference between a mature organisation and an immature one is not the frequency of failures — it is what happens after. An immature team fixes the immediate problem and moves on. A mature team classifies the incident, searches for precedents, applies the known playbook, records the resolution, and updates the playbook. The fix is temporary. The learning is permanent.

AI coding agents, by default, are immature systems. Every error is experienced in isolation. The agent encounters a YAML parse error, rewrites the file from scratch (losing comments, ordering, and embedded references), and the problem is "solved." Next session, same error, same destructive response, zero recall. There is no mechanism to say "this has happened before, and here is what worked."

I built a healing loop — a system that classifies failures, matches them against known patterns, suggests recovery using a graduated escalation, and records every resolution for future reference. **The system does not just recover. It strengthens.**

### The loop

```
Error occurs
  1. CLASSIFY — What type? (code, dependency, environment, design, external)
  2. LOOKUP  — Have we seen this before? Search pattern database
  3. SUGGEST — Recommend recovery using escalation ladder
  4. RESOLVE — Apply fix, record what worked
  5. LOG     — Store as pattern for future reference
```

When a task encounters an issue:

```bash
fw task update T-042 --status issues --reason "YAML parse error in config.yaml"
# Healing loop activates automatically
fw healing diagnose T-042
```

The diagnosis searches the pattern database and returns known resolutions:

```
Diagnosis for T-042
  Symptom: YAML parse error in config.yaml
  Classification: code (syntax)

  Similar patterns found:
    P-023: YAML parse errors (seen 4 times)
      Resolution: Validate before overwrite, preserve comments
      Success rate: 100%

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
| **A** | Do not repeat it | "Approach X failed — do not try X again" |
| **B** | Improve technique | "When parsing YAML, validate first" |
| **C** | Improve tooling | "Add a pre-commit YAML lint check" |
| **D** | Change ways of working | "All config changes go through a validation pipeline" |

Most failures need Level A. But when the same failure class appears 3+ times, it escalates. The tooling needs to prevent it (C), or the workflow needs to change (D). The escalation is not automatic — the agent proposes, the framework logs, the human decides.

### Antifragility in practice

- First YAML parse error: 20 minutes of debugging. Pattern recorded as P-023.
- Second occurrence: recognised in seconds. Known fix applied.
- Third occurrence: escalated to Level C. YAML validation added to the verification gate.
- Fourth occurrence: does not happen. The gate catches it before commit.

The system did not just recover from the failure. It became immune to it.

### The research behind the design

I formalised the healing loop after studying how the framework's own governance model compared to ISO 27001's four-level assurance structure:

| Level | ISO Equivalent | Framework Implementation |
|-------|---------------|-------------------------|
| Risk identification | Risk assessment | 38 risks cataloged in risk register |
| Control design | Control adequacy | 23 controls mapped to risks |
| Operational testing | OE testing | 20 of 23 controls auto-testable every 30 min |
| Discovery | Continuous improvement | Pattern detection across time |

The research (T-194) started with a governance failure: I asked the agent to investigate audit scheduling, and it completed the investigation in 2 minutes without consulting me — the human owner of the task. That failure sparked a deep review of all controls. The review revealed that the framework had 23 controls, not 11 as assumed. The inventory was incomplete without a formal register. High-risk items had the weakest controls — an inverted correlation. One critical risk (human sovereignty) had no structural control at all.

The healing loop was the answer to the fourth level: instead of only checking whether controls work, actively search for patterns the controls miss. This became the discovery layer (T-200) — 12 capabilities that analyse patterns across time, finding things no single check can see. One example: the 58% episodic decay rate was discovered by looking across all 170+ episodic records. No individual task audit could have surfaced it.

### The proactive side

The healing loop is not only reactive. When a practice repeats across 3+ tasks, the agent considers codifying it: mine episodic memory for evidence, assess whether codification adds value, codify if warranted, record as learning and decision. This is how the framework improves its own governance over time. It is not a static rule set. It is a system that evolves based on what it encounters.

**A system that only recovers from failure is fragile. A system that learns from failure is antifragile. The domain changed from incident management to AI agent governance. The principle did not.**

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

GitHub: [github.com/DimitriGeelen/agentic-engineering-framework](https://github.com/DimitriGeelen/agentic-engineering-framework)

---

## Platform Notes

**Dev.to / Hashnode:** Use as-is. Can expand with the full pattern YAML schema and how to seed patterns from experience.
**LinkedIn:** Open with "The best teams do not just fix incidents. They build immunity. The same principle applies to AI agents."
**Reddit (r/ClaudeAI):** Shorten. Lead with the "rewrites the file from scratch" scenario.

## Hashtags

#ClaudeCode #AIAgents #Antifragile #DevTools #OpenSource #ErrorHandling
