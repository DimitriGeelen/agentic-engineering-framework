# Consumer Project Setup

How to add the Agentic Engineering Framework to an existing project.

## Prerequisites

- The framework repo is cloned (e.g., `/opt/999-Agentic-Engineering-Framework`)
- `bin/fw` is on your PATH (the installer adds a symlink to `~/.local/bin/fw`)
- Git is initialized in your project directory

## Step 1: Initialize

From your project directory:

```bash
cd /path/to/your-project
fw init --provider claude
```

This creates:
- `.tasks/active/` and `.tasks/completed/` — task file directories
- `.context/` — working memory, handovers, episodic memory
- `.framework.yaml` — project config (version pin, upstream_repo)
- `CLAUDE.md` — governance rules (if `--provider claude`)
- `.claude/settings.json` — hook configuration
- Git hooks (commit-msg, post-commit, pre-push)

## Step 2: Upgrade (sync with framework)

After the framework evolves, sync improvements to your project:

```bash
fw upgrade /path/to/your-project
# Or from inside the project:
fw upgrade
```

**What gets upgraded:**
- CLAUDE.md governance sections (project-specific sections preserved)
- Task templates and seed files
- Git hooks and `.claude/settings.json` hook config
- `bin/fw` CLI shim and lib/*.sh subcommands
- Agent scripts (task-create, handover, git, healing, fabric, etc.)

**What does NOT happen:**
- Framework source code is NOT copied into your project
- Agents and libraries remain in the framework repo, accessed via the shim
- Your project-specific CLAUDE.md sections are preserved
- Your tasks, context, and episodic memory are untouched

Use `fw upgrade --dry-run` to preview changes before applying.

## .framework.yaml fields

| Field | Purpose |
|-------|---------|
| `version` | Pinned framework version (set by `fw upgrade`) |
| `upstream_repo` | Path or URL to the framework repo (used by `fw update` for re-vendoring) |
| `upgraded_from` | Previous version before last upgrade |
| `last_upgrade` | Timestamp of last `fw upgrade` run |

Example:
```yaml
version: 1.5.291
upstream_repo: /opt/999-Agentic-Engineering-Framework
upgraded_from: 1.5.246
last_upgrade: 2026-04-12T07:00:00Z
```

## Architecture: shim model

The framework uses a **shim model**, not vendoring:

- `bin/fw` in your project is a thin shim that resolves the framework
  install path (from `.framework.yaml` or symlink) and delegates to it
- All agents, libraries, and hooks live in the framework repo
- Your project stores only tasks, context, and project-specific config
- `fw upgrade` refreshes the shim and hook config, not the framework code

This means multiple projects can share one framework install. When you
upgrade the framework repo (git pull), all projects get the new agents
and libraries immediately — `fw upgrade` only needs to sync config files.

## TermLink (optional, machine-wide)

TermLink is intentionally machine-wide, NOT per-project. It uses Unix
sockets at system paths for cross-session discovery — per-project
vendoring would defeat this.

Install once:
```bash
# macOS
brew install DimitriGeelen/termlink/termlink

# From source
cargo install --path crates/termlink-cli
```

Verify: `fw termlink check` (also shown in `fw doctor` output).

## Health check

After setup, verify everything works:

```bash
fw doctor
```

This checks: framework installation, .framework.yaml, task directories,
context directories, git hooks, version pin drift, TermLink availability,
and consumer project fleet health.

## Quick reference

| Action | Command |
|--------|---------|
| Initialize project | `fw init --provider claude` |
| Upgrade project | `fw upgrade` |
| Check health | `fw doctor` |
| Create first task | `fw work-on "my first task" --type build` |
| Run audit | `fw audit` |
