# session

> Provider-neutral dataclass defining the terminal session descriptor schema with metadata, capabilities, and process info

**Type:** script | **Subsystem:** watchtower | **Location:** `web/terminal/session.py`

## What It Does

### Framework Reference

When you need to propose a new free driver, an arc-scoped driver, or sharpen an existing one, the canonical workflow lives in **`policy/prompts/`** — NOT inlined into this CLAUDE.md.

| Bundle file | When to reach for it |
|-------------|----------------------|
| `policy/prompts/bvp-driver-session.md` | **Always start here.** Keystone. Three workflows (A=batch-propose, B=discover+sharpen, C=sharpen named topic). Entry/exit conditions, outputs, init refusal, degraded mode. |
| `policy/prompts/artefact-template.md` | When writing the research artefact (`docs/reports/T-XXXX-bvp-driver-*.md`). YAM

*(truncated — see CLAUDE.md for full section)*

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [terminal](/docs/generated/web-blueprints-terminal) | called_by | Flask blueprint providing the interactive web terminal API with session creation, I/O, resize, and profile-based configuration |
| [registry](/docs/generated/web-terminal-registry) | called_by | Provides CRUD operations and YAML file persistence for terminal session records stored in .context/sessions/ |

## Related

### Tasks
- T-967: Session profiles + provider registry for orchestrator readiness (T-962 Phase 4)

---
*Auto-generated from Component Fabric. Card: `web-terminal-session.yaml`*
*Last verified: 2026-04-06*
