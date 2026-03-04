# Agentic Engineering Framework

A governance framework for systematizing how AI agents work within engineering projects. It enforces task traceability, structural gates, context management, and antifragile error handling — so agents operate predictably and transparently.

This is not a library. It's a set of structural rules, patterns, and enforcement mechanisms that any file-based, CLI-capable AI agent can follow.

## Prerequisites

- **Bash** 4.4+ (Linux/macOS/WSL2)
- **Git** 2.20+
- **Python** 3.8+ with PyYAML (`pip install pyyaml`)

## Install

```bash
# Clone the framework
git clone <repo-url> /opt/999-Agentic-Engineering-Framework
cd /opt/999-Agentic-Engineering-Framework

# Add fw to PATH (optional, recommended)
sudo ln -sf "$(pwd)/bin/fw" /usr/local/bin/fw

# Verify
fw doctor
```

## Quickstart: New Project

```bash
# In your project directory
cd /path/to/your-project
git init

# Initialize framework (creates .context/, .tasks/, hooks, CLAUDE.md)
fw init

# Check health
fw doctor

# Start your first task
fw work-on "Set up project structure" --type build

# When done, generate handover
fw handover --commit
```

## Quickstart: Self-Hosted (Framework Development)

The framework develops itself using its own governance. From the framework repo:

```bash
fw context init          # Start session
fw work-on T-XXX         # Resume a task
fw audit                 # Check compliance
fw handover --commit     # End session
```

## Core Principle

**Nothing gets done without a task.** This is enforced structurally by hooks that block file edits without an active task.

## Key Commands

| Command | Purpose |
|---------|---------|
| `fw work-on "name"` | Create task + set focus + start work |
| `fw doctor` | Check framework health |
| `fw audit` | Run compliance audit |
| `fw context init` | Initialize session |
| `fw handover --commit` | End-of-session handover |
| `fw help` | Show all commands |

## Documentation

- **[FRAMEWORK.md](FRAMEWORK.md)** — Full operating guide (provider-neutral, includes [glossary](FRAMEWORK.md#glossary))
- **[CLAUDE.md](CLAUDE.md)** — Claude Code integration + complete reference
- **[Watchtower](web/)** — Web dashboard for task/audit monitoring

## Architecture

```
bin/fw                    CLI entry point
agents/                   Agent scripts + AGENT.md intelligence
  context/                Context Fabric (memory system)
  git/                    Task-traced git operations
  handover/               Session handover generation
  healing/                Antifragile error recovery
  task-create/            Task creation + update
  audit/                  Compliance checking
lib/                      fw subcommands (init, setup, harvest)
.tasks/                   Task files (active + completed)
.context/                 Working memory, project memory, episodic memory
.fabric/                  Component topology map
```

## Four Directives (Priority Order)

1. **Antifragility** — System strengthens under stress
2. **Reliability** — Predictable, observable, auditable
3. **Usability** — Joy to use, sensible defaults
4. **Portability** — No provider lock-in

## License

Proprietary. All rights reserved.
