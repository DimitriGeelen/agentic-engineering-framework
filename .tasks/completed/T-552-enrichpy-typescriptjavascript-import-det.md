---
id: T-552
name: "enrich.py TypeScript/JavaScript import detection — extend fabric edge discovery beyond bash/python/html"
description: >
  enrich.py only parses .sh/.py/.html imports. On TypeScript projects, zero edges detected. Add import detection for: import/export from, require(), dynamic import(). Map import paths to registered component paths (relative, package, barrel). Consider pluggable parser architecture for future languages (Go, Rust, Java). Origin: T-549 OpenClaw eval — 52 edges added manually because enricher was language-blind.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-03-23T16:06:19Z
last_update: 2026-03-24T21:28:54Z
date_finished: 2026-03-24T21:28:54Z
---

# T-552: enrich.py TypeScript/JavaScript import detection — extend fabric edge discovery beyond bash/python/html

## Context

enrich.py only parses .sh/.py/.html imports. On TS/JS projects, zero edges detected. Add import detection for ES modules and CommonJS patterns.

## Acceptance Criteria

### Agent
- [x] `detect_ts_js_imports` function added to `enrich.py`
- [x] Function detects: `import from`, `export from`, `require()`, dynamic `import()`
- [x] Only relative imports resolved (bare package imports skipped)
- [x] Extension resolution: tries `.ts`, `.tsx`, `.js`, `.jsx`, `index.*`
- [x] Wired into `compute_forward_edges` for `.ts`, `.tsx`, `.js`, `.jsx` files
- [x] enrich.py parses without error

## Verification

python3 -c "import py_compile; py_compile.compile('agents/fabric/lib/enrich.py', doraise=True)"
grep -q "detect_ts_js_imports" agents/fabric/lib/enrich.py

## Decisions

## Updates

### 2026-03-23T16:06:19Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-552-enrichpy-typescriptjavascript-import-det.md
- **Context:** Initial task creation

### 2026-03-24T21:26:13Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-24T21:28:54Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
