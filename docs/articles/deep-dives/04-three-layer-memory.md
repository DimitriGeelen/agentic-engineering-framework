# Deep Dive #4: Three-Layer Memory

## Title

Governing AI Agents: Three-Layer Memory — giving agents institutional knowledge

## Post Body

**Undocumented decisions get re-debated. In every organisation. At every scale.**

A programme governance team meets on Tuesday and agrees: all configuration will use YAML. By Thursday, a workstream lead — who missed Tuesday's meeting — delivers a JSON config. The following week, a new team member creates a TOML file because "it seemed reasonable." Three configuration formats now coexist, each reasonable in isolation, collectively incoherent. The decision was made. It was not persisted in a form that survived the meeting.

The same failure mode appears in AI coding agents, compressed from weeks into hours. Day one: the agent and I agree on YAML for configuration. Day two, new session: the agent writes JSON. It has no record of the decision. It is not being inconsistent — it genuinely does not know. Every session starts from zero. The agent does not know what it did yesterday, what failed last week, or why PostgreSQL was chosen over MongoDB.

Prompt instructions help ("always use YAML for configs") but they do not scale. By the time you have enumerated every decision, convention, and lesson learned, the system prompt is 50K tokens of accumulated context that no one maintains.

**The problem is not that the agent forgets. The problem is that forgetting is the default, and remembering requires structure.**

### Three layers

The Agentic Engineering Framework implements three distinct memory layers, each serving a different temporal purpose:

**Working Memory — what is happening now.** Session state, current focus, active tasks. Updated continuously. Volatile — lost when the session ends, captured into the other layers before that happens.

```yaml
# .context/working/session.yaml
session_id: S-2026-0308-0809
focus: T-042
active_tasks: [T-042, T-038]
```

**Project Memory — what the project knows.** Decisions, patterns, and learnings accumulated across all sessions. When the agent starts a new session, it reads project memory and knows: YAML is the configuration standard, this API timeout has occurred before, approach X was tried and failed.

```yaml
# .context/project/decisions.yaml
- id: D-014
  date: 2026-02-15
  task: T-028
  decision: "Use YAML for all configuration files"
  rationale: "Human-readable, comments supported, existing tooling"
  rejected: ["JSON (no comments)", "TOML (less familiar to team)"]
```

**Episodic Memory — what happened.** Condensed histories of completed tasks. Not the full git log — a distilled summary of what was tried, what worked, what was learned. When a similar task arises months later, the agent reads the episodic summary instead of repeating trial-and-error.

```yaml
# .context/episodic/T-042.yaml
task: T-042
summary: "Cleaned up module imports across 8 files"
approach: "AST-based analysis, removed circular dependencies first"
outcome: success
key_insight: "Start with leaf modules, work inward"
```

### How memory flows

```
Session starts
  Read project memory (decisions, patterns, learnings)
  Restore working memory (what was in progress)
Work — make decisions, encounter issues, learn
  Continuous capture (decisions to project memory, issues to patterns)
Session ends
  Generate episodic summary (condensed history)
  Generate handover (state + recommendations for next session)
```

The agent at session start is not starting from zero. It has access to every decision ever made, every failure pattern encountered, and the full history of similar tasks.

### The research behind the design

The three-layer model did not start as a design. It emerged from failures.

The first memory system was a single `context.yaml` file with everything — current task, decisions, learnings, patterns. Within two weeks it was 500 lines long and the agent spent more time reading context than doing work.

A formal memory audit found that 58% of task files were empty in their "Updates" section — the running log I had designed was almost never populated. Meanwhile, git had a perfect record of every change with timestamps and diffs. That led to the hybrid episodic design (T-117): **git owns the timeline, task files own the decisions.** I stopped asking agents to maintain chronological logs (they forgot) and instead mined git history automatically at task completion. The episodic generator merges git data with task data to produce a condensed history.

The three-layer separation crystallized through a research spike on Google's context engineering principles (T-120) and a deep reflection on sub-agent dispatch patterns (T-097, which analyzed all 96 tasks at that point). The key finding: investigation agents need results in working memory (0% savings from offloading), while content generators must never return results to working memory (96% savings from writing to disk). Some memory is hot and ephemeral. Some is warm and persistent. Some is cold and archival. The pattern mapped directly to three layers.

I also learned that memory decay is real. A discovery analysis (T-200) found a 58% episodic decay rate — more than half of episodic records lose practical value within weeks. The solution was not to discard them but to distill patterns upward: if the same failure appears in 3+ episodic records, it graduates to a pattern in project memory. If a pattern proves reliable across 5+ tasks, it graduates to a practice. This is Decision D-003: "3+ occurrences triggers practice candidate."

### The key insight

Short-term context, accumulated knowledge, and historical reference have different requirements. By separating them, each can be optimised:

- Working memory: fast, volatile, small
- Project memory: persistent, searchable, growing
- Episodic memory: archival, condensed, referenced on demand

**The domain changed from organisational knowledge management to AI agent memory. The principle did not.**

### Try it

```bash
curl -fsSL https://raw.githubusercontent.com/DimitriGeelen/agentic-engineering-framework/master/install.sh | bash
cd your-project && fw init

# See current memory state
fw context status

# Record a decision
fw context add-decision "Use YAML for configs" --task T-042 --rationale "Human readable"

# Record a learning
fw context add-learning "Always set connection pool limits" --task T-042
```

GitHub: [github.com/DimitriGeelen/agentic-engineering-framework](https://github.com/DimitriGeelen/agentic-engineering-framework)

---

## Platform Notes

**Dev.to / Hashnode:** Use as-is. Can expand with the full YAML schema for each layer and custom queries.
**LinkedIn:** Open with "In any organisation, undocumented decisions get re-debated. AI agents have the same problem, compressed into hours instead of months."
**Reddit (r/ClaudeAI):** Shorten. Lead with the YAML/JSON anecdote, then the three-layer solution.

## Hashtags

#ClaudeCode #AIAgents #AIMemory #DevTools #OpenSource #KnowledgeManagement
