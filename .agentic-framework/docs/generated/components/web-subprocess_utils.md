# subprocess_utils

> Consistent subprocess execution for git and fw commands. Provides run_git_command() and run_fw_command() with standardized timeouts, encoding, and error handling.

**Type:** script | **Subsystem:** watchtower | **Location:** `web/subprocess_utils.py`

**Tags:** `python`, `subprocess`, `git`, `watchtower`, `reliability`

## What It Does

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [shared](/docs/generated/web-shared) | calls | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

## Used By (12)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [session](/docs/generated/web-blueprints-session) | calls | Flask blueprint: Session |
| [core](/docs/generated/web-blueprints-core) | calls | Flask blueprint: Core |
| [quality](/docs/generated/web-blueprints-quality) | calls | Flask blueprint: Quality |
| [tasks](/docs/generated/web-blueprints-tasks) | calls | Flask blueprint: Tasks |
| [metrics](/docs/generated/web-blueprints-metrics) | calls | Flask blueprint: Metrics |
| [cockpit](/docs/generated/web-blueprints-cockpit) | called_by | Flask blueprint: Cockpit |
| [core](/docs/generated/web-blueprints-core) | called_by | Flask blueprint: Core |
| [inception](/docs/generated/web-blueprints-inception) | called_by | Blueprint 'inception' — routes: /inception |
| [metrics](/docs/generated/web-blueprints-metrics) | called_by | Flask blueprint: Metrics |
| [quality](/docs/generated/web-blueprints-quality) | called_by | Flask blueprint: Quality |
| [session](/docs/generated/web-blueprints-session) | called_by | Flask blueprint: Session |
| [tasks](/docs/generated/web-blueprints-tasks) | called_by | Flask blueprint: Tasks |

---
*Auto-generated from Component Fabric. Card: `web-subprocess_utils.yaml`*
*Last verified: 2026-03-11*
