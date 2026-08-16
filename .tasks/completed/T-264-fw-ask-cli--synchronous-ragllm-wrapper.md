---
id: T-264
name: "fw ask CLI — synchronous RAG+LLM wrapper"
description: >
  Build fw ask CLI command: synchronous wrapper around rag_retrieve() + non-streaming
  Ollama call. Keystone for all framework integrations. Create lib/ask-api.py (~80
  lines: wrapper + non-streaming Ollama + JSON output), lib/ask.sh (~30 lines: arg
  parsing + Python invocation), add route in bin/fw. Support: --scope {all,patterns,episodic,specs,tasks}
  to bias retrieval, --json for programmatic consumption, --concise for brief answers.
  Net: ~150 new lines. Ref: docs/reports/T-261-framework-enhancement.md §1 (onboarding),
  §Architectural Notes. Predecessor: T-255 (RAG), T-256 (ask endpoint). Enables: T-266
  (healing integration), T-267 (session briefing).

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [qa, cli, framework]
components: [bin/fw]
related_tasks: []
created: 2026-02-24T08:37:00Z
last_update: '2026-08-16T22:25:12Z'
date_finished: 2026-02-24T09:31:19Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:17Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 3
      F-ORCH: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=3 (body:fw-recall-or-memory-link); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=1 
      (body/components:context-fabric-incidental); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:12Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 3
      F-AUTONOMY: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=3 (body:fw-recall-or-memory-link); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=1 
      (body/components:context-fabric-incidental); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-264: fw ask CLI — synchronous RAG+LLM wrapper

## Context

Keystone CLI for programmatic Q&A access. Ref: [T-261-framework-enhancement.md](../../docs/reports/T-261-framework-enhancement.md) §1

## Acceptance Criteria

### Agent
- [x] lib/ask.py implements synchronous RAG+LLM wrapper using rag_retrieve() + ollama.chat()
- [x] lib/ask.sh provides shell wrapper with arg parsing and --help
- [x] fw ask route added to bin/fw
- [x] --json flag outputs structured JSON (answer, model, sources, thinking_used)
- [x] --concise flag requests brief answers
- [x] --think/--no-think flags control thinking mode
- [x] Auto-detect thinking mode via should_think() classifier

## Verification

# lib/ask.py exists
test -f lib/ask.py
# lib/ask.sh exists and is executable
test -x lib/ask.sh
# fw ask route exists
grep -q '"ask"' bin/fw || grep -q 'ask)' bin/fw
# fw ask --help works
fw ask --help 2>&1 | grep -q "Usage"
# Python module imports
python3 -c "from lib.ask import ask; print('OK')"

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

### 2026-02-24T08:37:00Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-264-fw-ask-cli--synchronous-ragllm-wrapper.md
- **Context:** Initial task creation

### 2026-02-24T09:23:43Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-24T09:31:19Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-99c7a3bb
- **Timestamp:** 2026-06-02T15:01:47Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 6
     - evidence: `grep -q '"ask"' bin/fw || grep -q 'ask)' bin/fw`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 8
     - evidence: `fw ask --help 2>&1 | grep -q "Usage"`
