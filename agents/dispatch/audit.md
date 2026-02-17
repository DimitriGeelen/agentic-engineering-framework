# Dispatch Template: Parallel Audit / Review

> Dispatch agents to review different artifact categories for quality and compliance.

## When to Use

- Comprehensive project audits across multiple artifact types
- Code review across multiple files/modules
- Compliance checks against framework standards
- Any systematic review of project state

## Evidence

- T-072: 3 parallel auditors → analyzed 71 tasks, 72 episodics, 6 memory files
  - Each agent focused on one category → thorough coverage
  - Combined into comprehensive audit report

## Template

```
Audit [ARTIFACT CATEGORY] for [QUALITY CRITERIA].

Context:
- We are working on T-XXX: [task name]
- Artifact location: [directory or file pattern]
- Standards to check against: [framework rules, template format, etc.]

Your scope: [SPECIFIC CATEGORY — e.g., "all files in .context/episodic/"]

Check each artifact for:
1. [Criterion 1 — e.g., "Required YAML fields present"]
2. [Criterion 2 — e.g., "enrichment_status is 'complete'"]
3. [Criterion 3 — e.g., "summary is not a TODO placeholder"]

Return your findings as:

## Summary
- Total checked: N
- Pass: N | Warn: N | Fail: N

## Issues (if any)
1. [file]: [issue] (severity: warn|fail)

If >20 issues found, write full report to [output file path] and return only
the summary here. Keep response under 2K tokens.
```

## Dispatch Pattern

```python
# Split artifacts into independent categories
Task(subagent_type="Explore", prompt="Audit task files in .tasks/...")
Task(subagent_type="Explore", prompt="Audit episodic files in .context/episodic/...")
Task(subagent_type="Explore", prompt="Audit project memory in .context/project/...")

# Combine summaries into overall report
```

## Anti-Patterns

- Single agent auditing everything (too slow, too much context)
- Agents returning full file contents of non-compliant files
- Not specifying severity levels (everything looks equally important)
- Overlapping audit scopes between agents
