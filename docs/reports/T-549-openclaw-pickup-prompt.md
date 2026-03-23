# OpenClaw Evaluation — Pickup Prompt

Use this as the prompt when starting a new Claude Code session in `/opt/openclaw-evaluation/` on 192.168.10.107.

---

## Pickup Prompt (copy everything below this line)

You are starting a new governed session in the OpenClaw evaluation project. The Agentic Engineering Framework has been initialized here. Follow the framework's rules in CLAUDE.md.

### Context

**What this project is:** An evaluation of OpenClaw (https://github.com/openclaw/openclaw) — a 331K+ star Node.js/TypeScript personal AI assistant with multi-platform messaging (WhatsApp, Telegram, Slack, Discord, Signal, iMessage, 15+ channels).

**What we're doing:** A structured deep-dive to:
1. **Identify** — map OpenClaw's architecture, design patterns, components, and functionality
2. **Evaluate** — assess which elements are valuable for our project goals
3. **Carve out** — isolate the valuable pieces
4. **Adopt/Integrate** — determine what to bring into our projects

**What we're NOT doing:**
- NOT running OpenClaw (no `pnpm install`, no `openclaw onboard`, no gateway startup) — this is static code analysis only
- NOT modifying OpenClaw's source code
- NOT contributing back to OpenClaw
- Do NOT start, execute, or run any OpenClaw services without explicit human confirmation

### Current State

- Framework initialized: `fw doctor` passes (6 warnings, 0 failures)
- Git hooks installed (commit-msg, post-commit, pre-push)
- 6 onboarding tasks in `.tasks/active/` (T-001 through T-006)
- Node 22.22.1 available via `source ~/.nvm/nvm.sh && nvm use 22`
- pnpm 10.32.1 installed globally

### Your Mission (Phase by Phase)

**Phase 1: Complete Onboarding (T-001 through T-006)**
Work through the 6 onboarding tasks in order. These bootstrap governance:
- T-001: Orientation + health check (`fw doctor`)
- T-002: First governed commit
- T-003: Register key components — THIS IS CRITICAL. Map OpenClaw's architecture into the component fabric. Register at minimum:
  - Entry points (main CLI, gateway server, onboarding wizard)
  - Core packages in `packages/` (identify the monorepo structure)
  - Channel integrations (WhatsApp, Telegram, Discord at minimum)
  - Skills platform
  - UI components
  - Config/build files (package.json, tsconfig, pnpm-workspace.yaml)
  - Target: 30-50 components for a project this size, not just 5-10
- T-004: Complete task lifecycle
- T-005: Generate first handover
- T-006: Add project learning

**Phase 2: Create Evaluation Inception Tasks**
After onboarding is complete, create inception tasks FOR THIS PROJECT to plan the evaluation:

1. `fw inception start "OpenClaw architecture mapping — gateway, control plane, agent runtime, workspace isolation"`
2. `fw inception start "OpenClaw design pattern inventory — multi-agent routing, channel abstraction, skills platform"`
3. `fw inception start "OpenClaw component quality assessment — which are well-built, which are fragile"`
4. `fw inception start "OpenClaw value extraction — adoptable patterns and components for our projects"`
5. `fw inception start "Framework ingestion learnings — what worked and what broke during init/fabric bootstrap"`

**Phase 3: Execute Evaluation**
Work through the inception tasks. For each:
- Fill in problem statement, exploration plan, assumptions
- Conduct the research (read code, map dependencies, trace data flows)
- Record findings in research artifacts (`docs/reports/T-XXX-*.md`)
- Make go/no-go decisions

### OpenClaw Architecture (What We Know So Far)

```
Gateway (WebSocket control plane, ws://127.0.0.1:18789)
├── Sessions, presence, config, webhooks
├── Multi-agent routing (isolated workspaces per channel/account)
└── Pi agent runtime (AI operations, RPC mode)

Channels
├── WhatsApp (Baileys library)
├── Telegram (grammY library)
├── Discord (discord.js)
├── Signal (signal-cli)
├── Slack, iMessage, 15+ others
└── Group routing, mention gating, per-channel rules

Apps
├── macOS menu bar (Voice Wake, Talk Mode)
├── iOS node (Canvas, voice, device pairing)
├── Android node (Connect tab, chat, voice)
└── Web Control UI + Canvas (A2UI visual workspace)

Skills Platform
├── Bundled skills
├── Managed skills
├── Workspace-level skills
└── Browser control (dedicated Chrome/Chromium)

Infrastructure
├── Cron jobs, webhooks, Gmail Pub/Sub
├── CLI tools (onboarding, messaging, agent interaction)
└── Systemd/launchd daemon support
```

### Key Directories to Explore

```
packages/          # Core monorepo packages — start here
apps/              # Platform applications
src/               # Source code
skills/            # Skill modules
extensions/        # Extension plugins
ui/                # UI components
.agent/workflows/  # Agent workflow definitions
.agents/           # Agent configurations
vendor/            # Third-party integrations
docs/              # Documentation
test/              # Test suites
```

### Rules

1. Follow CLAUDE.md governance (task-first, commit cadence, context budget)
2. All evaluation tasks live HERE in this project — not in the upstream framework repo
3. DO NOT run OpenClaw services without explicit human confirmation
4. Record all findings in research artifacts (`docs/reports/`)
5. Quality over speed — the component fabric should be excellent, not just adequate
6. If you discover something that would improve the Agentic Engineering Framework itself, note it in a learning: `fw context add-learning "description" --task T-XXX --source observation`

### Meta-Learning Goals

While doing this evaluation, pay attention to:
- **Framework gaps:** What's missing or broken when initializing on a large TypeScript monorepo?
- **Fabric quality:** Can the component fabric meaningfully map a project of this scale?
- **Onboarding friction:** Were the onboarding tasks helpful or did they get in the way?
- **TermLink needs:** What TermLink features would have made this easier?

Record these as learnings — they'll be harvested back into the framework project later.
