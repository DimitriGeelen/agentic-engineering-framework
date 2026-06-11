---
id: T-379
name: "Settings page with engine selector and config persistence"
description: >
  Create web/blueprints/settings.py with routes for settings page. YAML persistence
  at .context/settings.yaml (gitignored). Engine selector (Ollama/OpenRouter), model
  picker, API key management UI. Gear icon in nav. Depends on T-377 (LLM provider)
  and T-378 (key storage). Parent: T-375.

status: work-completed
workflow_type: build
owner: human
horizon:
tags: [ui, settings]
components: [web/app.py, web/templates/base.html]
related_tasks: []
created: 2026-03-09T09:41:42Z
last_update: '2026-06-11T22:24:20Z'
date_finished: 2026-03-09T09:57:39Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:20Z'
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

# T-379: Settings page with engine selector and config persistence

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] web/blueprints/settings.py created with routes for page, save, save-key, delete-key, test-connection, models
- [x] web/templates/settings.html with engine selector, API key management, info section
- [x] YAML persistence at .context/settings.yaml (gitignored)
- [x] Gear icon added to nav in base.html
- [x] Blueprint registered in app.py
- [x] Settings page returns 200 with correct content

### Human
- [x] [RUBBER-STAMP] Settings page looks good and gear icon is visible
  **Steps:**
  1. Open http://localhost:3000/settings/
  2. Verify gear icon appears in top-right nav
  3. Check provider dropdown, model fields, API key section render
  **Expected:** Clean Pico CSS layout with engine selector, model fields, key management
  **If not:** Note which section looks broken

## Verification

curl -sf http://localhost:3000/settings/ | grep -q "LLM Engine"
python3 -c "from web.blueprints.settings import bp; print('OK')"

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

### 2026-03-09T09:41:42Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-379-settings-page-with-engine-selector-and-c.md
- **Context:** Initial task creation

### 2026-03-09T09:53:22Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-09T09:57:39Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-03-10T22:04:14Z — status-update [task-update-agent]
- **Change:** horizon: now → next

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f91febd6
- **Timestamp:** 2026-06-02T15:02:29Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** yes
- **Findings:** 3

**Per-AC findings:**

- **AC#2 (Agent)** — web/templates/settings.html with engine selector, API key management, info section
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/templates/settings.html in: web/templates/settings.html with engine selector, API key management, info section`
- **AC#3 (Agent)** — YAML persistence at .context/settings.yaml (gitignored)
  - **AC-verify-mismatch** (narrow, heuristic) — `path=context/settings.yaml in: YAML persistence at .context/settings.yaml (gitignored)`

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 1
     - evidence: `curl -sf http://localhost:3000/settings/ | grep -q "LLM Engine"`

- **Layer-1 escalations:** 1
  1. **secret-handling** (high) — Secret or credential changes
     - matched: `API key`
