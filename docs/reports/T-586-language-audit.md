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
4. **Every hook uses Python — and it's slow.** 9 python3 invocations per Write/Edit = ~450ms overhead. Exceeds the 200ms target. A single compiled TS binary would be ~30ms.
5. **Node.js is already available on every target platform**, and guaranteed for Claude Code users.
6. **Watchtower is optional and decoupled.** Framework core runs without Flask. Treating Watchtower as separate eliminates the "3 language" concern.
7. **TS can REPLACE Python in framework core**, not add to it. Core goes from bash+Python to bash+TS. Watchtower stays Python but it's optional.

## Deep Analysis: Watchtower Coupling

**Critical finding: Watchtower is OPTIONAL and DECOUPLED from framework core.**

### Coupling analysis

| Question | Answer |
|----------|--------|
| Does framework core import from `web/`? | NO — zero imports |
| Does Watchtower import from `agents/`/`lib/`? | NO — reads files from disk, no code imports |
| Can `fw task/context/audit/git/handover` run without Flask? | YES — all pure bash+Python |
| What `fw` commands touch `web/`? | Only `fw serve` and `fw scan` |

### Three-layer architecture (actual)

| Layer | Language | Purpose | Separable? |
|-------|----------|---------|-----------|
| 1. Orchestration | Bash | CLI, hooks, routing, glue | Stays bash forever |
| 2. Data processing | Python (inline) | YAML/JSON parse, path ops, string ops | **Replaceable by TS** |
| 3. Web dashboard | Python/Flask | Watchtower UI | **Optional, separate install** |

### Python dependency reality (framework core only)

| Category | What | Can be replaced? |
|----------|------|-----------------|
| **HARD dep** | PyYAML (75 reads + 7 writes in bash) | Yes — `js-yaml` npm package |
| **Standalone** | 9 Python scripts, 2,668 LOC total | Yes — all are data processing |
| **Inline** | 199 `python3 -c` blocks, ~6,360 LOC | Yes — utility binary pattern |

### Migration scenario

If TypeScript replaces inline Python + standalone scripts:
- **Framework core = bash + TS** (TWO languages — GO criterion met)
- **Watchtower = Python/Flask** (separate optional component, own install)
- Python goes from HARD requirement to OPTIONAL (only needed for web dashboard)

## Performance: Hook Overhead

### Startup benchmarks (this machine, Linux)

| Runtime | Cold start | With YAML import |
|---------|-----------|-----------------|
| bash | 2ms | N/A |
| node | 22ms | ~30ms (js-yaml) |
| python3 | 44ms | 57ms (PyYAML) |

### Current hook overhead per Write/Edit

A single `Write` tool call triggers 3 PreToolUse hooks sequentially:
1. `check-active-task.sh` — 3 `python3` calls = ~170ms
2. `check-project-boundary.sh` — up to 4 `python3` calls = ~230ms
3. `budget-gate.sh` — 2 `python3` calls = ~115ms

**Total: ~9 python3 invocations = ~450ms Python overhead per tool call**

This EXCEEDS the 200ms hook response target. A compiled TS binary doing all 9 operations in a single process invocation would run in ~30ms.

### The "fw-util" pattern

All 199 inline Python blocks reduce to ~5 operations:
1. `fw-util yaml-get <file> <field>` — replaces 75 occurrences
2. `fw-util yaml-set <file> <field> <value>` — replaces 7 occurrences
3. `fw-util json-get <file> <field>` — replaces 63 occurrences
4. `fw-util path-resolve <path>` — replaces 87 occurrences
5. `fw-util path-contains <root> <path>` — replaces remaining

A single compiled TS binary (~200 LOC) could replace ALL inline Python with faster startup and type safety.

## Revised Key Findings

1. **"Bash for portability" is fiction.** 55% of bash scripts can't function without Python 3.
2. **Watchtower is optional and decoupled.** Framework core runs without Flask/web. Treating Watchtower as a separate component eliminates the "anchor" problem.
3. **Python's ONLY hard dependency is PyYAML.** Everything else is stdlib or optional.
4. **TS CAN replace Python in framework core** — reducing from 3 languages (bash+Python+Jinja) to 2 (bash+TS), with Watchtower as optional 3rd.
5. **Current hook performance is already poor.** 9 Python invocations per tool call = ~450ms. A single TS binary would be 15x faster.
6. **Node.js is guaranteed** on the target platform (Claude Code requires it).
7. **Migration is incremental.** A `fw-util` TS binary replacing inline Python blocks can coexist with remaining Python during transition.

## Implications for Phase 2 (Prototype Spike)

The audit data suggests the prototype comparison (Phase 2) should focus on:
- **Hook performance**: Single TS binary vs 9 Python invocations — measure real hook latency
- **YAML handling**: Is `js-yaml` as convenient as PyYAML? (75 YAML parse points to migrate)
- **The fw-util pattern**: Build a minimal TS utility binary, test it as a drop-in for `python3 -c` blocks
- **Developer experience**: Is one compiled binary with subcommands better than inline Python?
- **Compilation story**: How does `fw update` trigger TS compilation? How fast is it?
