# self-audit

> Standalone framework integrity check (Layers 1-4) that does not depend on fw CLI. Verifies foundation files, directory structure, Claude Code hooks, and git hooks.

**Type:** script | **Subsystem:** audit | **Location:** `agents/audit/self-audit.sh`

**Tags:** `audit`, `standalone`, `integrity`

## What It Does

Self-Audit — Standalone Framework Integrity Check
Verifies Layers 1-4 of the Agentic Engineering Framework
without depending on fw CLI (solves chicken-and-egg problem).
Usage:
agents/audit/self-audit.sh                 # Run from framework root
agents/audit/self-audit.sh /path/to/project # Audit a specific project
agents/audit/self-audit.sh --quiet          # Machine-readable (no color)
Exit codes: 0=pass, 1=warnings, 2=failures

## Dependencies (10)

| Target | Relationship |
|--------|-------------|
| `bin/fw` | reads |
| `C-009` | reads |
| `agents/context/check-active-task.sh` | reads |
| `agents/context/check-tier0.sh` | reads |
| `C-007` | reads |
| `C-008` | reads |
| `agents/context/error-watchdog.sh` | reads |
| `agents/context/check-dispatch.sh` | reads |
| `agents/context/pre-compact.sh` | reads |
| `agents/context/post-compact-resume.sh` | reads |

## Related

### Tasks
- T-286: Build fw self-audit CLI command and standalone script

---
*Auto-generated from Component Fabric. Card: `agents-audit-self-audit.yaml`*
*Last verified: 2026-03-01*
