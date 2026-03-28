# Task Creation Agent

> Creates new tasks following the framework's task system specification.

## Purpose

Guide the creation of properly structured tasks with:
- Unique ID generation
- Required field population
- Correct file placement
- Initial commit with task reference

## When to Use

- Starting new work that requires tracking
- Before making changes (Tier 1 enforcement)
- When `metrics.sh` shows work happening without task context

## Inputs Required

| Field | Required | Description |
|-------|----------|-------------|
| name | yes | Short, descriptive task name |
| description | yes | What this task accomplishes |
| workflow_type | yes | specification, design, build, test, refactor, decommission |
| owner | yes | human or agent name |
| priority | no | high, medium (default), low |
| tags | no | Categorization tags |

## Workflow

1. **Generate ID** — Find highest existing T-XXX, increment
2. **Gather inputs** — Prompt for required fields
3. **Create file** — Populate template, write to `.tasks/active/`
4. **Validate** — Check YAML parses, required fields present
5. **Report** — Show created task summary

## Validation Rules

- ID must be unique
- Name must be non-empty
- Description must be non-empty
- workflow_type must be one of: specification, design, build, test, refactor, decommission
- Status starts as `captured` or `started-work` (if work begins immediately)
- File must be valid YAML + Markdown

## Integration

- **AI Agents:** Can invoke via natural language (e.g., "create a new task for X")
- **Script:** `create-task.sh` handles mechanical operations
- **Output:** Returns task ID and file path

## Example Usage

```bash
# Interactive mode
./agents/task-create/create-task.sh

# With arguments
./agents/task-create/create-task.sh --name "Fix login bug" --type build --owner human
```

## Error Handling

| Error | Response |
|-------|----------|
| Duplicate ID | Regenerate ID |
| Missing required field | Prompt for input |
| Invalid workflow_type | Show valid options |
| File write failure | Report error, suggest fix |
