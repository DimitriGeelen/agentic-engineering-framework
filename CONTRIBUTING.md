# Contributing to the Agentic Engineering Framework

Thanks for your interest in contributing. This guide will help you get started.

## Getting Started

### Prerequisites

- Bash 4.0+ (macOS: `brew install bash`)
- Git 2.20+
- Python 3.8+ (for Watchtower web UI and YAML validation)

### Setup

```bash
# Clone the repo on the development branch (contributors: clone your fork, see "Pull Request Process")
git clone --branch bleeding-edge https://github.com/DimitriGeelen/agentic-engineering-framework.git
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
# Open the URL printed on startup (default port 3000 — use `fw watchtower url` to query the live port)
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
- The framework version and a summary of `fw doctor` (failures and warnings in your own words; do not paste host names, paths, user names or tokens)

### Reporting Security Problems

Never in a public issue. Use GitHub's private vulnerability reporting ("Report a vulnerability" on the Security tab); see [SECURITY.md](SECURITY.md).

### Suggesting Features

Use the [feature request template](https://github.com/DimitriGeelen/agentic-engineering-framework/issues/new?template=feature-request.yml). Describe:
- The problem you're solving
- Your proposed solution
- Which subsystem it affects

### Branches and Release Channels

There is no `main` branch. Work lands on `bleeding-edge`; `master` only moves at a release.

| Channel | What it is | Rhythm |
|---|---|---|
| Bleeding edge (`bleeding-edge`, pre-release tags `vX.Y.Z-be.N`) | Everything new, merged pull requests included | daily |
| Pre-release | What two or three different projects showed working in the field | weekly |
| Stable (`master`, release tags `vX.Y.Z`) | What ran as pre-release for at least two weeks, with no open failure | monthly |

Check your change against the latest pre-release before you open a pull request.

### Pull Request Process

1. **Issue first.** Open or pick an issue and agree the approach in it before writing code. The maintainer's intake turns each issue into a framework task (for example #104 became T-4935); that task must exist on `bleeding-edge` before you open the pull request. A documentation-only pull request may skip the issue for form only (a typo, a broken link, layout); one that rewords a rule or describes a behaviour differently needs an issue like any other change.
2. **Fork and branch** from `bleeding-edge`. Suggested branch names: `fix/<issue>-<keyword>` or `feat/<issue>-<keyword>`.
3. **One pull request per issue**, opened against `bleeding-edge`, with "Fixes #N" in the description.
4. **Fill in the pull request template:** the approach and the class of defect it closes, a test that fails before the change and passes after it, the commands you ran with their output, `fw audit` and the tests you touched, a `fw doctor` summary, and what you did not test.
5. **Checks run on GitHub** ("PR checks": the structural invariants plus the tests your change adds or changes). For a first-time contributor the maintainer approves the run with one click.
6. **Review:** the framework's agents read the change, run the deeper tests on isolated hosts and post a one-screen recommendation. A change from outside is reviewed one risk level higher than the same change made internally.
7. **The maintainer merges** into `bleeding-edge`; nobody else can. A refusal is one line on the pull request.
8. **After the merge** the change ships in the next `be-tag` and is field-tested before it reaches pre-release and stable.

### Commit Messages

Every commit names the intake task and the issue, and carries a sign-off:

```
T-4234 (#106): Fix the empty upgrade preview

Signed-off-by: Your Name <you@example.com>
```

`git commit -s` adds the `Signed-off-by:` line. By signing off you certify the [Developer Certificate of Origin](https://developercertificate.org/): you wrote the change, or have the right to submit it. The `commit-msg` hook checks the task reference; do not bypass it with `--no-verify`.

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

Contributions are licensed under Apache-2.0, like the project (section 5 of the [licence](LICENSE)), with a DCO sign-off on every commit. There is no contributor licence agreement.
