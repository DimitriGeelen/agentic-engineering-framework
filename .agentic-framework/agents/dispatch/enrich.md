# Dispatch Template: Content Generation / Enrichment

> Dispatch agents to produce or enrich files. Each agent writes to disk and returns only a summary.

## When to Use

- Enriching episodic memory skeletons
- Generating reports or documentation
- Batch file creation from templates
- Any task where agents produce files

## Evidence

- T-073: 9 parallel enrichers → **CONTEXT EXPLOSION (177K tokens)**
  - Root cause: agents returned full YAML content into context
  - Lesson: agents MUST write to disk, return only summary
- Files survived on disk despite context crash (write-early discipline works)

## Template

```
Enrich [FILE] based on [SOURCE].

Context:
- We are working on T-XXX: [task name]
- File to enrich: [target file path]
- Source material: [source file path or description]
- Template/format: [reference to template, e.g., ".context/episodic/TEMPLATE.yaml"]

Instructions:
1. Read the source material at [path]
2. Read the target file at [path]
3. Fill in all [TODO] sections using information from the source
4. Write the completed file using the Write tool

CRITICAL: Write the file to disk using the Write tool. Do NOT return the file
contents in your response. Return ONLY:

Done: [file path] — [one-line summary of what was enriched]

Keep your response to ONE LINE. The orchestrator has limited context budget.
```

## Dispatch Pattern

```python
# Cap at 5 parallel agents (T-073 used 9 → crash)
# Use run_in_background for large batches
Task(subagent_type="general-purpose", prompt="Enrich file 1...", run_in_background=True)
Task(subagent_type="general-purpose", prompt="Enrich file 2...", run_in_background=True)
# ... max 5 parallel

# Check output files for completion
```

## Anti-Patterns

- Returning full file content in response (CAUSED T-073 CRASH)
- Dispatching >5 enrichment agents in parallel
- Not specifying the exact file path to write to
- Asking agent to "return the enriched content for review" (context explosion)
