# T-586 Phase 1: Language Audit

**Date:** 2026-03-23
**Task:** T-586 — Language strategy: TypeScript adoption for new framework components

## Executive Summary

The framework is a **three-language hybrid** (bash + Python + HTML/Jinja), not "bash scripts for portability." Python is deeply embedded — 55% of bash scripts shell out to `python3`, with 199 inline `python3 -c` blocks across 78 files. The "no dependencies" argument is already void: the framework requires Python 3, PyYAML, Flask, and optionally Ollama/Qdrant/tantivy.

## Language Distribution

| Language | Files | LOC | % of total |
|----------|-------|-----|------------|
| Bash (.sh) | 98* | 42,170 | 44.6% |
| Python (.py) | 55 | 25,356 | 26.8% |
| HTML/Jinja (templates) | 84 | 13,540 | 14.3% |
| JavaScript (.js, client) | 12 | 13,422 | 14.2% |
| **Total** | **249** | **94,488** | |

*98 unique bash scripts (excluding `.agentic-framework/` vendored copies)

### Inline Python in Bash

| Metric | Value |
|--------|-------|
| `python3 -c` invocations | 199 across 78 files |
| `python3` invocations (all forms) | 315 across 96 files |
| Estimated inline Python LOC | ~6,360 lines |
| Bash scripts that call Python | 54 of 98 (55%) |
| Pure bash scripts | 44 of 98 (45%) |

### Python LOC by Subsystem

| Subsystem | LOC | Nature |
|-----------|-----|--------|
| Watchtower web UI | 10,010 | Standalone Flask app |
| Agents + lib (inline in bash) | 2,668 | `python3 -c` blocks |
| Standalone agent scripts | ~1,500 | enrich.py, generate_article.py, etc. |
| Inline in bash (estimated) | ~6,360 | YAML/JSON parsing, path ops, regex |

## What Python Does Inside Bash

Every non-trivial data operation in bash shells out to Python:

| Pattern | Occurrences | Examples |
|---------|-------------|---------|
| YAML parse/write | 130 | Read task frontmatter, write focus.yaml, parse config |
| Path manipulation | 87 | Resolve paths, check containment, extract components |
| JSON parse/write | 74 | Parse hook input, format output, read settings.json |
| Date/time ops | 43 | Timestamps, duration calculation, ISO formatting |
| Regex matching | 42 | Commit message validation, pattern extraction |

### Hook Python Usage (PreToolUse/PostToolUse)

Every Claude Code hook uses inline Python:

| Hook | python3 calls | Purpose |
|------|--------------|---------|
| check-active-task.sh | 3 | Parse focus.yaml, session.yaml, task frontmatter |
| check-tier0.sh | 3 | Parse command for dangerous patterns |
| check-project-boundary.sh | 4 | Parse paths, analyze bash commands |
| budget-gate.sh | 2 | Parse JSON transcript, calculate tokens |
| checkpoint.sh | 2 | Parse budget status, read session state |
| error-watchdog.sh | 1 | Parse tool output for error patterns |
| check-fabric-new-file.sh | 1 | Parse JSON hook input |
| check-dispatch*.sh | 3 | Parse agent dispatch parameters |

## External Dependencies (Already Required)

### Python packages (required):
- **PyYAML** — used by every agent (44 imports across files, 130 inline uses in bash)
- **Flask** — Watchtower web UI (10 blueprint files)
- **Jinja2** — Flask templates (84 template files)
- **MarkupSafe** — Flask dependency

### Python packages (optional):
- **ollama** — LLM integration (6 imports)
- **markdown2** — Markdown rendering (6 imports)
- **tantivy** — Full-text search (2 imports)
- **sqlite-vec** — Vector embeddings (2 imports)
- **pytest** — Testing (4 imports)

### System requirements:
- **Python 3.9+** — hard requirement (framework fails without it)
- **Git** — hard requirement
- **bash 3.2+** — hard requirement (macOS minimum)
- **Node.js** — NOT currently required by framework; IS required by Claude Code

## Component Classification

### Pure Bash (no Python, stays bash forever):
- Git hooks: commit-msg, post-commit, pre-push
- CLI entry point: `bin/fw`
- Simple glue: path resolution, command routing, env setup
- Shell utilities: `_sed_i`, color output, argument parsing

### Bash + Python Hybrid (candidates for TS):
- **All PreToolUse/PostToolUse hooks** (10 hooks, all use inline Python for YAML/JSON)
- **Task management**: create-task.sh, update-task.sh (YAML frontmatter parsing)
- **Context fabric**: focus.sh, init.sh, status.sh (YAML read/write)
- **Audit system**: audit.sh (9 python3 -c blocks — heaviest user)
- **Fabric system**: register.sh, query.sh, traverse.sh, drift.sh (YAML/graph ops)
- **Handover**: handover.sh (7 python3 calls — YAML assembly)
- **Resume**: resume.sh (3 python3 calls — state synthesis)

### Standalone Python (separate decision):
- **Watchtower**: Full Flask app (10K LOC) — stays Python unless rewritten
- **enrich.py**: Fabric edge discovery (standalone, could be TS)
- **generate_article.py**: Doc generation (standalone, could be TS)

### Client JavaScript (stays JS):
- **12 files in web/static/**: htmx, cytoscape, chart.js — browser code, stays as-is

## Node.js Availability Assessment

| Platform | Node.js availability | Notes |
|----------|---------------------|-------|
| macOS | Not pre-installed; available via Homebrew, nvm | Claude Code users already have it |
| Ubuntu/Debian | apt package `nodejs`; nvm common | Widely available |
| RHEL/CentOS | dnf/yum package; nvm | Available |
| WSL | Same as Linux distro | Available |
| Claude Code users | **Required** — Claude Code is a Node.js app | Guaranteed present |

**Key finding:** Every Claude Code user already has Node.js installed. The framework's primary user base is Claude Code users. Node.js portability concern is moot for the target audience.

**Caveat:** If the framework is used with non-Claude-Code agents (future portability), Node.js becomes an additional requirement.

## Key Findings

1. **"Bash for portability" is fiction.** The framework is already a Python-dependent hybrid. 55% of bash scripts can't function without Python 3.
2. **Python is used as a data processing layer, not for business logic.** 90%+ of inline Python is YAML parsing, JSON handling, path ops, and date formatting — exactly what a typed language would do better.
3. **The audit system is the heaviest Python user** (21 python3 invocations). It's also the most complex bash script and would benefit most from type safety.
4. **Every hook uses Python.** The 200ms hook response time constraint means any language change must be fast to start. Python cold start: ~50ms. Node.js cold start: ~80ms. Compiled JS: ~30ms.
5. **Node.js is already available on every target platform**, and guaranteed for Claude Code users.
6. **Adding TypeScript would be language 4 during migration**, but could replace Python to return to 2 (bash + TS). The question is whether the migration path achieves this or creates a worse 3-language state.
7. **The Watchtower web UI (10K LOC Python/Flask) is the anchor.** Unless it's rewritten, Python stays as a dependency. TS adoption would mean: bash (orchestration) + TS (data processing/hooks) + Python (web UI). That's still 3 languages.

## Implications for Phase 2 (Prototype Spike)

The audit data suggests the prototype comparison (Phase 2) should focus on:
- **Hook performance**: Can a TS hook respond within 200ms? (Python: ~50ms overhead per `python3 -c`)
- **YAML handling**: Is TS YAML parsing as convenient as PyYAML? (130 YAML parse points to eventually migrate)
- **Developer experience**: Is `const data = yaml.parse(fs.readFileSync(path))` better than `python3 -c "import yaml; ..."`?
- **The Watchtower question**: Does keeping Flask mean we permanently stay at 3 languages?
