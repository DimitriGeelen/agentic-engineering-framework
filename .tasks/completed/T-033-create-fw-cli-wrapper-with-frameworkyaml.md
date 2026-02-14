---
id: T-033
name: Create fw CLI wrapper with framework.yaml config
description: >
  Create the fw CLI wrapper that reads .framework.yaml, resolves PROJECT_ROOT and FRAMEWORK_ROOT, and invokes agents
status: work-completed
workflow_type: build
owner: claude-code
priority: medium
tags: [cli, shared-tooling, critical-path]
agents:
  primary: claude-code
  supporting: []
created: 2026-02-13T23:45:10Z
last_update: 2026-02-14T08:55:08Z
date_finished: 2026-02-14T08:55:08Z
---

# T-033: Create fw CLI wrapper with framework.yaml config

## Design Record

**Architecture:** Single bash script (`bin/fw`) that:
1. Resolves PROJECT_ROOT by walking up from cwd looking for `.framework.yaml` or `.tasks/`
2. Resolves FRAMEWORK_ROOT from `bin/fw`'s own location (relative) or `.framework.yaml` (config-based)
3. Exports both as env vars for agents
4. Routes commands to agent scripts via `exec`

**Path Resolution Strategy (3-tier):**
- Tier 1: `bin/fw` is inside the framework repo → FRAMEWORK_ROOT = `../ from bin/`
- Tier 2: `.framework.yaml` exists in project root → read `framework_path:`
- Tier 3: Neither found → actionable error with fix instructions

**Key Decisions:**
- `exec` for routing (replaces shell process, clean exit codes)
- Doctor embedded in fw (no separate agent needed — it's a diagnostic, not a workflow)
- Version pinning via `.framework.yaml` → doctor warns on mismatch
- Error messages sent to stderr (D2)

## Specification Record

**Acceptance Criteria:**
- [x] `fw help` shows all commands with examples
- [x] `fw version` shows version + paths + version pin check
- [x] `fw doctor` validates framework health (7 checks)
- [x] `fw <agent>` routes to correct agent script
- [x] Works from inside framework repo (self-referential mode)
- [x] Works from external project via `.framework.yaml`
- [x] Actionable error when framework not found
- [x] `set -euo pipefail` for safety
- [x] `.framework.yaml.example` template committed

## Test Files

Manual testing performed:
- `fw help` — all commands listed
- `fw version` — paths and pinned version shown
- `fw doctor` — 7 health checks, warnings-only exits 0, failures exit 2
- `fw context status` — routes to context agent
- `fw healing --help` — routes to healing agent
- `fw resume quick` — routes to resume agent
- `fw task help` — task subcommand help
- External project test: /tmp/test-project with .framework.yaml → correct path resolution
- Bad framework_path test: standalone fw with invalid path → actionable error
- Arithmetic fix: `((x++))` replaced with `x=$((x + 1))` to avoid `set -e` exit on 0

## Updates

### 2026-02-13T23:45:10Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** .tasks/active/T-033-create-fw-cli-wrapper-with-frameworkyaml.md
- **Context:** Initial task creation

### 2026-02-14T08:55:08Z — build-completed [claude-code]
- **Action:** Built bin/fw CLI wrapper and .framework.yaml.example
- **Output:** bin/fw (executable), .framework.yaml.example
- **Context:** Implements shared tooling model (Option B from critical review). Routes to all 7 agents, includes embedded doctor, handles self-referential and external project modes.
- **Bug fix:** `((warnings++))` causes exit under `set -e` when incrementing from 0 — fixed to `warnings=$((warnings + 1))`
