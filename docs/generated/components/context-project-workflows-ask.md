# ask

> Workflow config for `fw ask`: routes web/ask.py's synchronous RAG answer through ollama-local with a litellm cloud fallback on connection error.

**Type:** data | **Subsystem:** context-fabric | **Location:** `.context/project/workflows/ask.yaml`

## What It Does

Workflow config for `fw ask`: routes web/ask.py's synchronous RAG answer through
ollama-local with a litellm cloud fallback on connection error.

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

*(truncated — see CLAUDE.md for full section)*

---
*Auto-generated from Component Fabric. Card: `context-project-workflows-ask.yaml`*
*Last verified: 2026-08-16*
