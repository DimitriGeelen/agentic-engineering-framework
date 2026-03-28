# T-563: OpenClaw Comparative — Extension SDK Design

## What Enables 80+ Extensions?

### OpenClaw Extension Model

**Source:** T-549 architecture mapping, value extraction report

| Factor | How OpenClaw does it |
|--------|---------------------|
| Minimal surface | 3-file extension: `SKILL.md` + `index.ts` + `config.ts` |
| Discovery | Bundled (in-repo), Managed (config allowlist), Workspace (auto-scan dir) |
| Isolation | Each extension runs in its own skill scope, can't crash others |
| DX | Frontmatter-based metadata, hot-reload in dev, template generators |
| Contributor flow | PR to skills/ directory, auto-discovered on merge |
| Tool registration | Extension declares tools → aggregated into `OpenClawTools` |

### Our Extension Model

| Factor | How we do it |
|--------|-------------|
| Agent scripts | `agents/<name>/` with `AGENT.md` + `<name>.sh` + `lib/` |
| Skills | `.claude/skills/` with markdown descriptions, invoked by `/skill-name` |
| Hooks | `.claude/settings.json` with PreToolUse/PostToolUse entries |
| Discovery | Manual registration in settings.json (hooks) or file-based (skills) |
| Isolation | Process-level (bash scripts), no shared state except `.context/` |
| DX | Template task files, `fw task create` generator |

### Comparison

| Dimension | OpenClaw | Our Framework | Assessment |
|-----------|----------|---------------|------------|
| Extension count | 80+ | ~12 agents + ~10 skills | We're smaller but more governed |
| Contributor barrier | Low (3-file template) | Medium (AGENT.md + bash script) | **Gap: higher barrier** |
| Extension isolation | Language-level (TypeScript modules) | Process-level (bash subshells) | Parity (different mechanism) |
| Hot-reload | Built-in | Manual restart | **Gap: no hot-reload** |
| Extension discovery | 3-tier auto-discovery | Manual registration | **Gap: no auto-discovery** |

### Key Finding: Different Design Goals

OpenClaw is an **extensible platform** — maximizing the number of extensions is a design goal. Contributor DX is critical.

Our framework is a **governance system** — extensions (agents, hooks) are carefully designed and reviewed. We don't want 80+ extensions; we want 15-20 well-governed ones.

### Adoptable Pattern: Auto-Discovery for Agents

Currently, new agents require manual registration in multiple places. OpenClaw's 3-tier discovery (bundled + managed + workspace) could inspire auto-discovery of `agents/*/AGENT.md` files.

**Effort:** Low. Not urgent — our agent count is stable.

## Recommendation: NO-GO on SDK Design

Our framework doesn't need an extension SDK. Our "extensions" are governed agents and hooks, not community plugins. The contributor barrier is intentional — agents need to follow framework governance rules.

**Adopt later if needed:** Auto-discovery of agents when the count exceeds ~20.
