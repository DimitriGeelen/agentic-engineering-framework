---
id: T-552
name: "enrich.py TypeScript/JavaScript import detection — extend fabric edge discovery
  beyond bash/python/html"
description: >
  enrich.py only parses .sh/.py/.html imports. On TypeScript projects, zero edges
  detected. Add import detection for: import/export from, require(), dynamic import().
  Map import paths to registered component paths (relative, package, barrel). Consider
  pluggable parser architecture for future languages (Go, Rust, Java). Origin: T-549
  OpenClaw eval — 52 edges added manually because enricher was language-blind.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-03-23T16:06:19Z
last_update: '2026-06-11T22:24:24Z'
date_finished: 2026-03-24T21:28:54Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:24Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
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

## Reviewer Verdict (v1.5)

- **Scan ID:** R-339e46c3
- **Timestamp:** 2026-06-02T15:03:32Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
