# T-549: OpenClaw Deep-Dive — Research Artifact

## OpenClaw Overview

- **Repo:** https://github.com/openclaw/openclaw
- **What:** Personal AI assistant, local-first, single-user, multi-platform
- **Stack:** Node.js 24+, TypeScript, pnpm monorepo
- **Scale:** 331K+ stars, 64.5K+ forks, 21.5K commits, MIT license
- **Channels:** WhatsApp, Telegram, Slack, Discord, Signal, iMessage, 15+ others

### Architecture

- **WebSocket control plane** — central gateway on ws://127.0.0.1:18789
- **Pi agent runtime** — AI operations in RPC mode
- **Multi-agent routing** — isolated workspaces per channel/account
- **Skills platform** — bundled, managed, workspace-level

### Key Components

| Component | Purpose |
|-----------|---------|
| Gateway | WebSocket control plane (sessions, presence, config, webhooks) |
| Control UI | Web-based management interface |
| Canvas / A2UI | Visual workspace with push/eval |
| Channel integrations | WhatsApp (Baileys), Telegram (grammY), Discord (discord.js), Signal (signal-cli) |
| CLI tools | Onboarding, messaging, agent interaction |
| macOS app | Menu bar, Voice Wake, Talk Mode overlay |
| iOS/Android nodes | Canvas, voice, device pairing |
| Browser control | Dedicated Chrome/Chromium automation |
| Cron/Webhooks | Scheduled tasks, Gmail Pub/Sub |

### Project Structure

```
.agent/workflows/     # Agent workflow definitions
.agents/              # Agent configurations
apps/                 # Platform applications (macOS, iOS, Android)
packages/             # Core packages (monorepo)
ui/                   # UI components
src/                  # Source code
skills/               # Skill modules
extensions/           # Extension plugins
docs/                 # Documentation
test/                 # Test suites
vendor/               # Third-party integrations
```

### Install

```bash
# From npm
npm install -g openclaw@latest
openclaw onboard --install-daemon
openclaw gateway --port 18789 --verbose

# From source
git clone https://github.com/openclaw/openclaw.git
cd openclaw
pnpm install
pnpm ui:build && pnpm build
pnpm openclaw onboard --install-daemon
```

## Infrastructure Requirements (.107)

- SSH key-based access to 192.168.10.107
- Node.js 22.16+ or 24+ installed
- pnpm installed (`npm install -g pnpm`)
- TermLink installed (for persistent sessions)
- Agentic Engineering Framework installed (`fw` in PATH)
- ~500MB disk space (repo + node_modules + framework)

## Evaluation Dimensions

1. **Architecture** — WebSocket control plane model, RPC agent runtime, workspace isolation
2. **Design patterns** — Multi-agent routing, channel abstraction, skills platform
3. **Component quality** — Which components are well-designed, which are fragile
4. **Adoptable elements** — What patterns/components could benefit our projects
5. **Framework stress test** — How well does our framework handle a foreign TS monorepo

## Dialogue Log

### 2026-03-23 — Initial scoping
- Human requested full deep-dive evaluation of OpenClaw
- Goal: test framework's ability to ingest foreign project + extract architectural value
- Key clarification: after fw init, human starts new session in OpenClaw project with pickup prompt
- All OpenClaw evaluation tasks live in OpenClaw project, not framework project
- Meta-learnings for framework + TermLink captured back in framework project
