---
id: T-378
name: "Fernet encrypted API key storage"
description: >
  Create web/secrets_store.py with PBKDF2 key derivation from /etc/machine-id, Fernet
  encrypt/decrypt, CRUD API (get/set/delete/list). Store at .context/secrets/api-keys.enc.
  Env vars take precedence. Parent: T-375.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [security, keys]
components: []
related_tasks: []
created: 2026-03-09T09:41:40Z
last_update: '2026-08-16T22:25:29Z'
date_finished: 2026-03-09T09:53:12Z
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
  - ts: '2026-08-16T22:25:29Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-378: Fernet encrypted API key storage

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] web/secrets_store.py created with get/set/delete/list API
- [x] PBKDF2 key derivation from /etc/machine-id with Fernet encryption
- [x] Environment variable override (OPENROUTER_API_KEY takes precedence)
- [x] .context/secrets/ gitignored
- [x] Store/retrieve/delete/list all verified working

## Verification

python3 -c "from web.secrets_store import get_api_key, set_api_key, delete_api_key, list_configured_keys; print('OK')"
grep -q 'secrets' .gitignore

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

### 2026-03-09T09:41:40Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-378-fernet-encrypted-api-key-storage.md
- **Context:** Initial task creation

### 2026-03-09T09:51:13Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-09T09:53:12Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-97d47dac
- **Timestamp:** 2026-06-02T15:02:28Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
