# ask

> TODO: describe what this component does

**Type:** data | **Subsystem:** unknown | **Location:** `.context/project/workflows/ask.yaml`

## What It Does

T-1719 A3: fw ask's provider-routing decision.
Unlike every other workflow in this directory, `ask` never spawns a worker —
lib/ask.py answers synchronously in the calling process. That is why
worker_kind is `ollama-direct`, a kind registered specifically for this
(lib/resolver.py + lib/workflow_lint.py; parity witness
lib/worker_kinds_parity.py, surfaced by `fw doctor` per T-1734/T-1735).
Reusing `ollama-thin-loop` would have made every dispatch row claim a tool
loop ran when none did, and the entire point of routing ask through the
Resolver is that the telemetry is true.
The dispatch is captured through the same resolver.capture_dispatch() every

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
