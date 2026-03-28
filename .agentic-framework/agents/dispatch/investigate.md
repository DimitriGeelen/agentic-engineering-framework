# Dispatch Template: Parallel Investigation

> Dispatch 3-5 Explore agents to research different aspects of a problem simultaneously.

## When to Use

- Root cause analysis across multiple subsystems
- Feature evaluation across multiple dimensions
- Codebase exploration spanning several domains
- Any research where aspects are independent

## Evidence

- T-059: 3 parallel investigators → root cause analysis (success)
- T-061: 4 parallel investigators → bypass analysis (comprehensive)
- T-086: 5 parallel evaluators → feature evaluation (informed decision)

## Template

```
Investigate [ASPECT] of [PROBLEM].

Context:
- We are working on T-XXX: [task name]
- The framework uses [relevant structure: .tasks/, .context/, agents/]
- [Any specific framework knowledge the agent needs]

Your scope: [SPECIFIC ASPECT — e.g., "search episodic memory for patterns"]

Do NOT investigate [OUT OF SCOPE aspects — those are handled by other agents].

Return your findings as a numbered list:
1. Finding: [what you found]
   Evidence: [file:line or command output]
   Implication: [what it means]

Keep your response under 2K tokens. Reference files by path, don't paste contents.
The orchestrator has limited context budget.
```

## Dispatch Pattern

```python
# Dispatch 3-5 agents in parallel, each with a different aspect
Task(subagent_type="Explore", prompt="Investigate [aspect 1]...")
Task(subagent_type="Explore", prompt="Investigate [aspect 2]...")
Task(subagent_type="Explore", prompt="Investigate [aspect 3]...")

# Wait for all, then synthesize findings
```

## Anti-Patterns

- Dispatching >5 agents (context explosion risk)
- Overlapping scopes (agents duplicate work)
- Asking agents to return raw file contents (use file:line references instead)
- Not specifying output format (agents return unstructured prose)
