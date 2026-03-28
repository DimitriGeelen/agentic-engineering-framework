# T-008: OpenClaw Design Pattern Inventory

## Overview

Four major design patterns examined: channel abstraction, skills platform, multi-agent routing, and config hot-reload. All four are well-designed and extractable.

---

## 1. Channel Abstraction Pattern

### The Contract

`ChannelPlugin<ResolvedAccount>` in `src/channels/plugins/types.plugin.ts` — a composition of 17 optional adapter slots:

| Adapter | Purpose |
|---------|---------|
| `config` | Account resolution, listing, validation |
| `configSchema` | JSON schema + UI hints for config forms |
| `setup` / `setupWizard` | Account creation, migration, onboarding UI |
| `messaging` | Target parsing, routing, cross-context formatting |
| `outbound` | Send text/media/polls with delivery tracking |
| `streaming` | Chunking, formatting, delivery modes |
| `threading` | Reply tracking, thread context |
| `security` | DM policy, allowlists |
| `pairing` | Approval workflows |
| `groups` | Group-specific overrides (mention-required, tools) |
| `mentions` | Mention parsing and context |
| `actions` | Rich message tools (reactions, moderation) |
| `directory` | Peer/group discovery and caching |
| `lifecycle` | Config change / account removal hooks |
| `gateway` | WebSocket routes |
| `status` | Health probes, audits |
| `heartbeat` | Keepalive logic |
| `agentTools` | Channel-specific agent tools |

### Key Design Choices

- **Composition over inheritance** — No base class; all adapters are optional fields
- **Multi-account** — `listAccountIds()` + `resolveAccount()` enable multiple simultaneous bots per channel
- **Three loading phases** — Setup-only → Config loading → Full runtime (avoids eager loading)
- **Plugin entry helper** — `defineChannelPluginEntry()` standardizes registration

### Message Envelope

```typescript
type ChannelOutboundContext = {
  cfg, to, text, mediaUrl?, audioAsVoice?, forceDocument?,
  replyToId?, threadId?, accountId?, silent?
};
```

### Assessment

**Strength:** Extremely flexible. A minimal channel needs only `config` + `outbound`. Full channels like Discord use all 17 adapters. No wasted interface surface.

**Extractable:** Yes — the adapter composition pattern is framework-agnostic.

---

## 2. Skills Platform Pattern

### What Is a Skill?

A markdown file (`SKILL.md`) with YAML frontmatter describing an agent-facing tool. Skills are injected into the agent's system prompt; the agent decides when to invoke them.

### Three Tiers

| Tier | Location | Control |
|------|----------|---------|
| Bundled | `skills/*/SKILL.md` (in-repo) | Config allowlist |
| Managed | `~/.bun/skills/` (ClawHub) | `skills.json` lockfile |
| Workspace | `.agents/<agentId>/skills/` | Per-agent directory |

### Discovery & Loading

1. Scan directories → parse YAML frontmatter
2. Filter by eligibility (required binaries, env vars, config keys)
3. Apply token budget (150 skills max, 30K chars)
4. Format into system prompt (full or compact mode)
5. Agent reads prompt, triggers via tool call

### Metadata Format

```yaml
---
name: github
description: GitHub CLI integration
metadata:
  openclaw:
    emoji: 🐙
    requires:
      bins: [gh]
      env: [GITHUB_TOKEN]
    install:
      - kind: brew
        formula: gh
---
```

### Skills vs Extensions

| Aspect | Skills | Extensions |
|--------|--------|------------|
| Purpose | Agent tools (decision-making) | Platform services (I/O) |
| Format | Markdown + optional binary | TypeScript + manifest |
| Install | ClawHub / directory | npm workspace |
| Invocation | Agent-initiated | Event-driven |

### Assessment

**Strength:** Frontmatter-driven discovery with lazy eligibility. Token-budget-aware. Per-agent isolation.

**Extractable:** Yes — the SKILL.md format + directory scan + eligibility check pattern is portable.

---

## 3. Multi-Agent Routing Pattern

### Binding System

Declarative config binds channels/accounts/peers to agents:

```yaml
agents:
  list:
    - id: main
      bindings:
        - channel: discord
          accountId: "server-1"
          peer: { kind: group, id: "channel-id" }
    - id: telegram-agent
      bindings:
        - channel: telegram
```

### Resolution Cascade (7 tiers, highest priority first)

1. **Peer binding** — Exact DM/group match
2. **Parent peer** — Thread inherits parent's binding
3. **Guild + roles** — Discord server + role
4. **Guild only** — Discord server
5. **Team** — MS Teams org
6. **Account** — Account-scoped fallback
7. **Channel** — Channel-wide default

### Key Properties

- **Single gateway, multiple agents** — One gateway serves N independent agents
- **Lazy agent selection** — Resolved per-message, not per-connection
- **Session isolation** — Each agent has separate memory, tools, config at `~/.openclaw/agents/<id>/`
- **Route caching** — LRU cache (4000 entries), invalidates on config change
- **ACP alternative** — Agents can run embedded or via external ACP runtime

### Assessment

**Strength:** Config-driven, no hardcoding. Lazy selection enables runtime binding changes. Cache makes it performant.

**Extractable:** Yes — the tiered binding resolution + config-driven dispatch is a clean, portable pattern.

---

## 4. Config Hot-Reload Pattern

### Architecture

```
File watcher → Debounce (300ms) → Read + Validate → Diff paths →
  Build reload plan → Hot-reload OR Restart
```

### Reload Modes

| Mode | Behavior |
|------|----------|
| `off` | No hot-reload; require restart |
| `restart` | Any change triggers gateway restart |
| `hot` | Apply safe changes; restart only when necessary |
| `hybrid` (default) | Prefer hot, fall back to restart |

### Declarative Reload Rules

Each config path maps to a reload kind:

| Config Path | Kind | Action |
|---|---|---|
| `hooks.*` | hot | Reload hooks module |
| `cron.*` | hot | Restart scheduler |
| `agents.defaults.model*` | hot | Restart heartbeat |
| `browser.*` | hot | Restart browser daemon |
| `plugins.*` | restart | Full gateway restart |
| `gateway.*` | restart | Core settings |
| Channel configs | hot | Plugin-defined rules |

### Key Design Choices

- **Declarative safety rules** — Unknown changes trigger restart (fail-safe)
- **Selective restart** — Only affected subsystem restarts
- **Plugin extensibility** — Plugins register their own reload rules
- **Validation before apply** — Invalid config is rejected, reloader stays alive
- **Config as state machine** — Changes are explicit transitions, not ad-hoc patches

### Assessment

**Strength:** Declarative rules prevent mistakes. Plugin-extensible. Selective restart avoids downtime.

**Extractable:** Yes — the declarative reload-rule system + diff-and-plan approach is framework-agnostic.

---

## Summary: Pattern Adoption Matrix

| Pattern | Quality | Portability | Complexity | Recommendation |
|---------|---------|-------------|------------|----------------|
| Channel abstraction | ★★★★★ | High | Medium | **Adopt** — composition-based adapter pattern |
| Skills platform | ★★★★☆ | High | Low | **Adopt** — frontmatter discovery + eligibility |
| Multi-agent routing | ★★★★☆ | Medium | Medium | **Study** — tiered binding is clever but specific |
| Config hot-reload | ★★★★★ | High | Medium | **Adopt** — declarative reload rules |

All four patterns are GO for further evaluation in T-010 (value extraction).
