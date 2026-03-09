---
id: T-378
name: "Fernet encrypted API key storage"
description: >
  Create web/secrets_store.py with PBKDF2 key derivation from /etc/machine-id, Fernet encrypt/decrypt, CRUD API (get/set/delete/list). Store at .context/secrets/api-keys.enc. Env vars take precedence. Parent: T-375.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [security, keys]
components: []
related_tasks: []
created: 2026-03-09T09:41:40Z
last_update: 2026-03-09T09:51:13Z
date_finished: null
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
