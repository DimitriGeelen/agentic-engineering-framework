# ask

> fw ask subcommand. Provides interactive question/answer prompts for framework configuration and user input collection.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/ask.sh`

**Tags:** `lib`, `fw-subcommand`, `interactive`

## What It Does

fw ask — synchronous RAG+LLM wrapper (T-264)
Usage:
fw ask "How do I create a task?"
fw ask --json "What is the healing loop?"
fw ask --concise "List enforcement tiers"
fw ask --think "Why does the healing agent fail?"

### Framework Reference

### File Structure

```
.tasks/
  active/      # In-progress tasks (e.g., T-042-add-oauth.md)
  completed/   # Finished tasks
  templates/   # Task templates by workflow type
```

### Task File Format

Tasks are Markdown with YAML frontmatter. Use `default.md` as template.

**Required frontmatter fields:**
- `id`, `name`, `description`, `status`, `workflow_type`, `horizon`, `owner`, `created`, `last_update`

### Horizon (Priority Scheduling)

The `horizon` field controls when a task should be considered for work:

*(truncated — see CLAUDE.md for full section)*

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `?` | uses |

## Related

### Tasks
- T-264: fw ask CLI — synchronous RAG+LLM wrapper

---
*Auto-generated from Component Fabric. Card: `lib-ask.yaml`*
*Last verified: 2026-03-04*
