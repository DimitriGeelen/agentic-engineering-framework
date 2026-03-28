# Dispatch Template: Sequential TDD Development

> Dispatch fresh agents for each implementation step, with review between steps.

## When to Use

- Implementing a multi-step plan where each step is a commit
- Building features with test-first discipline
- Any implementation where spec compliance review between steps catches drift

## Evidence

- T-058: Subagent-driven TDD across 8 implementation tasks
  - Caught missing `git_log` in `gather_inputs` via spec compliance review
  - Each task dispatched to fresh agent with clean context

## Template

```
Implement step [N] of [PLAN]: [step description].

Context:
- Task: T-XXX — [task name]
- Plan: [path to plan file or inline description]
- Previous steps completed: [list of what's done]
- Current state: [what exists now]

Requirements for this step:
1. [Specific requirement]
2. [Specific requirement]
3. [Test criteria]

Files to create/modify:
- [file path]: [what to do]

After implementation:
1. Write all files using the Write/Edit tool
2. Verify the code works (run tests if applicable)
3. Return a summary of what was implemented and any issues found

Do NOT proceed to step [N+1] — that will be handled by a separate agent.
```

## Dispatch Pattern

```python
# Sequential — each step depends on the previous
for step in plan.steps:
    result = Task(subagent_type="general-purpose", prompt=f"Implement step {step.n}...")
    # Review result for spec compliance
    # Commit the step
    # Then dispatch next step
```

## Integration with Skills

This pattern is already formalized in the `superpowers:subagent-driven-development` skill.
Use the skill for structured TDD workflows. Use this template for simpler sequential
implementations that don't need full TDD discipline.

## Anti-Patterns

- Dispatching all steps in parallel (they depend on each other)
- Skipping review between steps (drift accumulates)
- Giving one agent the entire plan (context explosion, no checkpoints)
- Not committing between steps (no recovery point if context runs out)
