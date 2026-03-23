# OpenClaw Evaluation — Pickup Prompt

Use this as the prompt when starting a new Claude Code session in `/opt/openclaw-evaluation/` on 192.168.10.107.

---

## Pickup Prompt (copy everything below this line)

You are starting a new governed session in the OpenClaw evaluation project. The Agentic Engineering Framework (v1.2.6) has been initialized here. TermLink is installed for cross-terminal persistence and parallel dispatch. Follow the framework's rules in CLAUDE.md — it contains both OpenClaw's original project guidelines AND the full Agentic Engineering Framework governance.

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

### Environment

- **Machine:** 192.168.10.107 (Linux, Ubuntu)
- **Project:** `/opt/openclaw-evaluation/`
- **Framework:** `.agentic-framework/` (vendored, v1.2.6)
- **CLAUDE.md:** 1015 lines — OpenClaw original (lines 1-215) + framework governance (lines 216+)
- **Node:** 22.22.1 via nvm (`source ~/.nvm/nvm.sh && nvm use 22`)
- **pnpm:** 10.32.1
- **TermLink:** installed at `~/.cargo/bin/termlink`
- **Git hooks:** commit-msg, post-commit, pre-push — all installed
- **Onboarding tasks:** T-001 through T-006 in `.tasks/active/`

### Framework Commands (fw CLI)

```bash
# Task management
fw work-on "task name" --type build    # Create + focus + start
fw work-on T-XXX                       # Resume existing task
fw task update T-XXX --status work-completed
fw context focus T-XXX                 # Set focus

# Inception (exploration before building)
fw inception start "problem to explore"
fw inception decide T-XXX go|no-go --rationale "..."

# Context & fabric
fw doctor                              # Health check
fw fabric register <path>             # Register component
fw fabric overview                     # Subsystem summary
fw fabric deps <path>                  # Show dependencies
fw fabric blast-radius                 # Impact of changes
fw fabric drift                        # Detect unregistered files

# Git (governed)
fw git commit -m "T-XXX: description"
fw git status

# Session management
fw handover --commit                   # End-of-session handover
fw context add-learning "..." --task T-XXX --source observation
fw metrics                             # Project status
```

### TermLink Commands (cross-terminal persistence)

TermLink enables persistent terminal sessions and parallel agent dispatch. Use it for heavy parallel work instead of Claude Code's Task tool agents.

```bash
# Check TermLink
fw termlink check                      # Verify installation
termlink list                          # List active sessions

# Spawn persistent session
fw termlink spawn --task T-XXX         # Open tagged terminal session
termlink spawn --name eval-worker --backend background --shell --wait

# Execute commands in sessions
termlink interact <session> "<cmd>" --json --strip-ansi   # Sync execution
termlink pty inject <session> "<input>" --enter            # Async input
termlink pty output <session> --lines N                    # Read output

# Parallel dispatch (spawns claude -p workers)
fw termlink dispatch --name arch-eval --prompt "Evaluate OpenClaw gateway architecture..."
fw termlink dispatch --name pattern-eval --prompt "Inventory design patterns in packages/..."
fw termlink wait --name arch-eval      # Wait for worker completion
fw termlink result arch-eval           # Read worker result

# Session management
termlink attach <session>              # Full TUI mirror
termlink signal <session> SIGTERM      # Terminate session
fw termlink cleanup                    # Clean all sessions
fw termlink status                     # List active sessions
```

**When to use TermLink dispatch:**
- 3+ parallel evaluation tasks (architecture, patterns, components)
- Deep code analysis that produces large output (>1K tokens)
- Work that should survive context compaction
- Heavy parallel fabric registration (multiple subsystems)

**When to use regular Task tool agents:**
- Quick file lookups or grep searches
- Single-file analysis
- Lightweight sub-tasks

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
  - **Use TermLink dispatch** to parallelize fabric registration across subsystems
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
6. `fw inception start "TermLink learnings — what worked and what's missing for remote evaluation workflows"`

**Phase 3: Execute Evaluation**
Work through the inception tasks. For each:
- Fill in problem statement, exploration plan, assumptions
- Conduct the research (read code, map dependencies, trace data flows)
- **Use TermLink dispatch for parallel evaluation** — e.g., spawn workers to analyze different subsystems simultaneously
- Record findings in research artifacts (`docs/reports/T-XXX-*.md`)
- Make go/no-go decisions
- Commit after every meaningful unit of work

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
src/               # Source code (CLI, commands, infra, media, routing)
skills/            # Skill modules
extensions/        # Extension plugins (channel plugins: msteams, matrix, zalo, voice-call)
ui/                # UI components
.agent/workflows/  # Agent workflow definitions
.agents/           # Agent configurations
vendor/            # Third-party integrations
docs/              # Documentation (Mintlify-hosted)
test/              # Test suites
```

### Rules

1. Follow CLAUDE.md governance (task-first, commit cadence, context budget)
2. All evaluation tasks live HERE in this project — not in the upstream framework repo
3. DO NOT run OpenClaw services without explicit human confirmation
4. Record all findings in research artifacts (`docs/reports/`)
5. Quality over speed — the component fabric should be excellent, not just adequate
6. Use TermLink dispatch for heavy parallel work (3+ concurrent analyses)
7. Commit after every meaningful unit of work (context budget protection)
8. If you discover something that would improve the Agentic Engineering Framework itself, note it in a learning: `fw context add-learning "description" --task T-XXX --source observation`
9. If you discover something that would improve TermLink, note it similarly with `--source termlink-observation`

### Meta-Learning Goals

While doing this evaluation, pay attention to and record learnings for:

**Framework improvement:**
- What's missing or broken when initializing on a large TypeScript monorepo?
- Can the component fabric meaningfully map a project of this scale?
- Were the onboarding tasks helpful or did they get in the way?
- Is the CLAUDE.md merge (original + governance) clean or confusing?
- What inception/evaluation patterns would be useful as framework templates?

**TermLink improvement:**
- Does TermLink dispatch work well for parallel codebase analysis?
- What commands were missing or awkward?
- Would session grouping or result aggregation help?
- Is the spawn → interact → result flow intuitive for evaluation workflows?

Record these as learnings — they'll be harvested back into the framework and TermLink projects.
