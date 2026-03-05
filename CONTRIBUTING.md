# Contributing to the Agentic Engineering Framework

Thanks for your interest in contributing. This guide will help you get started.

## Getting Started

### Prerequisites

- Bash 4.0+ (macOS: `brew install bash`)
- Git 2.20+
- Python 3.8+ (for Watchtower web UI and YAML validation)

### Setup

```bash
# Clone the repo
git clone https://github.com/DimitriGeelen/agentic-engineering-framework.git
cd agentic-engineering-framework

# Check everything works
./bin/fw doctor

# Install git hooks (enforces commit traceability)
./bin/fw git install-hooks

# Initialize a session
./bin/fw context init
```

### Running the Watchtower Dashboard (Optional)

```bash
cd web/
pip install -r requirements.txt
python app.py
# Open http://localhost:3000
```

## Architecture Overview

```
bin/fw                    CLI entry point — routes commands to agents
agents/
  audit/                  90+ compliance checks (cron, pre-push, on-demand)
  context/                Memory system — focus, budget gates, patterns, decisions
  git/                    Task-traced git operations + hooks
  handover/               Session continuity documents
  healing/                Error recovery loop (diagnose → resolve → pattern)
  task-create/            Task lifecycle (create, update, verify, complete)
  fabric/                 Component topology — deps, impact, drift detection
  resume/                 Post-compaction context recovery
lib/                      fw subcommands (init, inception, promote, bus)
web/                      Watchtower dashboard (Flask + htmx)
.tasks/                   Task files (active/ + completed/)
.context/                 Three-layer memory (working, project, episodic)
.fabric/                  Component cards (126 components, 336 edges)
```

**Key pattern:** Each agent has a bash script (mechanical execution) and an `AGENT.md` (intelligence/guidance for AI agents). The bash scripts are the source of truth for behavior.

## How to Contribute

### Reporting Bugs

Use the [bug report template](https://github.com/DimitriGeelen/agentic-engineering-framework/issues/new?template=bug-report.yml). Include:
- Steps to reproduce
- Expected vs actual behavior
- Output of `fw doctor`

### Suggesting Features

Use the [feature request template](https://github.com/DimitriGeelen/agentic-engineering-framework/issues/new?template=feature-request.yml). Describe:
- The problem you're solving
- Your proposed solution
- Which subsystem it affects

### Pull Request Process

1. **Fork and branch** from `main`
2. **Create a task** for your work: `fw work-on "Description" --type build`
3. **Reference the task** in every commit: `git commit -m "T-XXX: description"`
4. **Run checks** before submitting:
   ```bash
   fw doctor        # Framework health
   fw audit         # Compliance checks (90+ checks)
   ```
5. **Open a PR** against `main` with a clear description of what changed and why
6. **Respond to review** — maintainers will review within a few days

### Commit Messages

Every commit must reference a task:

```
T-042: Fix login validation bug
T-099: Add retry logic to API client
```

This is enforced by the `commit-msg` hook. If you need to bypass (emergency only), use `--no-verify` and document the reason.

### Code Style

- **Bash scripts:** Use `set -euo pipefail`, quote variables, use `local` for function variables
- **Python (Watchtower):** Follow PEP 8, use type hints where practical
- **YAML:** 2-space indentation, no tabs
- **Markdown:** One sentence per line in source (wraps naturally in rendered output)

## Good First Issues

Look for issues labeled [`good first issue`](https://github.com/DimitriGeelen/agentic-engineering-framework/labels/good%20first%20issue). These are scoped, well-documented tasks suitable for newcomers.

Typical first contributions:
- Adding agent templates for new workflows
- Improving documentation or examples
- Adding audit checks for new compliance rules
- Fixing small CLI bugs or improving error messages
- Adding tests for existing functionality

## Questions?

- Open a [GitHub Discussion](https://github.com/DimitriGeelen/agentic-engineering-framework/discussions) for questions
- Check existing issues before opening a new one
- Read [FRAMEWORK.md](FRAMEWORK.md) for the full operating guide

## License

By contributing, you agree that your contributions will be licensed under the project's existing license.
