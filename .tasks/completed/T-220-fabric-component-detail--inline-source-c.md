---
id: T-220
name: "Fabric component detail — inline source code viewer"
description: >
  Add inline source code viewing to /fabric/component/<name> detail page. When user
  clicks a component, show the file contents with syntax highlighting. Enhances the
  fabric browser from metadata-only to full code inspection.

status: work-completed
workflow_type: build
owner: human
horizon:
tags: []
components: [web/blueprints/fabric.py, web/templates/base.html, 
      web/templates/fabric_detail.html]
related_tasks: []
created: 2026-02-20T09:16:03Z
last_update: '2026-06-11T22:24:11Z'
date_finished: 2026-02-22T08:50:53Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:11Z'
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
      F2: 1
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-220: Fabric component detail — inline source code viewer

## Context

The `/fabric/component/<name>` detail page shows component metadata but not the actual source code. Adding inline source display with syntax highlighting makes the fabric browser self-contained for code inspection.

## Acceptance Criteria

### Agent
- [x] highlight.js CSS + JS added to `web/templates/base.html` (CDN)
- [x] htmx afterSwap re-highlight hook in base template
- [x] `component_detail()` in `web/blueprints/fabric.py` reads source file from component location
- [x] Source code section rendered in `web/templates/fabric_detail.html` with syntax highlighting
- [x] Language detection from file extension (.py, .sh, .yaml, .js, .html, .md)
- [x] Safety: file must exist and be under PROJECT_ROOT, capped at 2000 lines
- [x] Missing file shows muted "file not found" message instead of error

### Human
- [x] Source code is readable with good contrast (dark theme)
- [x] Collapsible section works smoothly

## Verification

curl -sf http://localhost:3000/fabric/component/web-app | grep -q "hljs"
curl -sf http://localhost:3000/fabric/component/web-app | grep -q "Source Code"
python3 -c "import yaml; yaml.safe_load(open('.fabric/components/web-app.yaml'))"

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-02-20T09:16:03Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-220-fabric-component-detail--inline-source-c.md
- **Context:** Initial task creation

### 2026-02-22T08:50:53Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-1e687883
- **Timestamp:** 2026-06-02T15:01:31Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 5

**Per-AC findings:**

- **AC#1 (Agent)** — highlight.js CSS + JS added to `web/templates/base.html` (CDN)
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/templates/base.html in: highlight.js CSS + JS added to `web/templates/base.html` (CDN)`
- **AC#3 (Agent)** — `component_detail()` in `web/blueprints/fabric.py` reads source file from component location
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/blueprints/fabric.py in: `component_detail()` in `web/blueprints/fabric.py` reads source file from component location`
- **AC#4 (Agent)** — Source code section rendered in `web/templates/fabric_detail.html` with syntax highlighting
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/templates/fabric_detail.html in: Source code section rendered in `web/templates/fabric_detail.html` with syntax highlighting`

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 1
     - evidence: `curl -sf http://localhost:3000/fabric/component/web-app | grep -q "hljs"`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `curl -sf http://localhost:3000/fabric/component/web-app | grep -q "Source Code"`
