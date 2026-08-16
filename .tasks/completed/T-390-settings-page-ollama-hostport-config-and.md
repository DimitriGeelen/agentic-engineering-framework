---
id: T-390
name: "Settings page: Ollama host/port config and model dropdown"
description: >
  Add Ollama host and port fields to the settings page. Replace manual text inputs
  for primary/fallback model with dropdowns populated from available models (fetched
  via Test Connection). Persist host/port to settings.yaml and reinitialize provider
  on save. Predecessor: T-388.

status: work-completed
workflow_type: build
owner: human
horizon:
tags: []
components: [web/blueprints/settings.py, web/templates/settings.html]
related_tasks: []
created: 2026-03-09T11:35:43Z
last_update: '2026-08-16T22:25:29Z'
date_finished: 2026-03-09T11:47:35Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:20Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:29Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-390: Settings page: Ollama host/port config and model dropdown

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] Settings page renders Ollama Host field with current value
- [x] Model datalist endpoint returns available models for autocomplete
- [x] Saved ollama_host persisted to settings.yaml and used on init

### Human
- [x] [REVIEW] Settings page layout and model autocomplete work well
  **Steps:**
  1. Go to http://localhost:3000/settings/
  2. Verify Ollama Host field shows current host URL
  3. Type in Primary Model field — should show autocomplete suggestions from available models
  4. Change Ollama Host to a different IP, click Save, then Test Connection
  **Expected:** Autocomplete works, host change takes effect
  **If not:** Check browser console for JS errors

## Verification

curl -sf http://localhost:3000/settings/ | grep -q 'ollama_host'
curl -sf 'http://localhost:3000/settings/models?format=datalist' | grep -q 'option'

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     Examples:
       python3 -c "import yaml; yaml.safe_load(open('path/to/file.yaml'))"
       curl -sf http://localhost:3000/page
       grep -q "expected_string" output_file.txt
-->

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

### 2026-03-09T11:35:43Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-390-settings-page-ollama-hostport-config-and.md
- **Context:** Initial task creation

### 2026-03-09T11:47:35Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-03-10T22:04:14Z — status-update [task-update-agent]
- **Change:** horizon: now → next

## Reviewer Verdict (v1.5)

- **Scan ID:** R-500ce62d
- **Timestamp:** 2026-06-02T15:02:33Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 1
     - evidence: `curl -sf http://localhost:3000/settings/ | grep -q 'ollama_host'`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `curl -sf 'http://localhost:3000/settings/models?format=datalist' | grep -q 'option'`
