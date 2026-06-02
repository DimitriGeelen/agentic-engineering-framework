---
id: T-1294
name: "Prompt register cross-agent ID namespacing (T-1283 B2)"
description: >
  Prompt register cross-agent ID namespacing (T-1283 B2)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-18T14:51:58Z
last_update: 2026-04-18T14:55:35Z
date_finished: 2026-04-18T14:55:35Z
---

# T-1294: Prompt register cross-agent ID namespacing (T-1283 B2)

## Context

B2 of T-1283. Per Q5 decision in docs/reports/T-1283-prompt-register.md, every
prompt gets a stable unique ID of the form `<agent-id>/P-NNN` so references
survive cross-agent/cross-machine exchange.

- `<agent-id>`: short host id (reused from TermLink tagging — e.g. `107`, `121`)
  - Resolved in order: `FW_AGENT_ID` env > `.framework.yaml` `agent_id` >
    hostname-derived last IP octet > `local`
- `P-NNN`: zero-padded sequential counter, allocated from per-agent state file
  `.context/working/.prompt-counter` (atomic flock)
- Full qualified ID (FQID) written to frontmatter as `qid: 107/P-042`
- Filenames stay slug-based; FQID is the stable cross-fleet reference
- `fw prompt show` / `copy` accept both the local slug and the FQID

Version-pinning (`107/P-042@abc123`) is deferred to a later build unit.

## Acceptance Criteria

### Agent
- [x] `lib/prompt.sh` exposes `_prompt_resolve_agent_id` honoring env → config → hostname → fallback
- [x] `lib/prompt.sh` exposes `_prompt_next_counter` with flock-guarded allocation
- [x] `fw prompt create` writes `agent_id`, `counter`, and `qid` to frontmatter
- [x] Counter increments strictly on each create (no gaps, no reuse)
- [x] `fw prompt show <slug>` and `fw prompt show <qid>` both resolve the same prompt
- [x] `fw prompt copy <slug>` and `fw prompt copy <qid>` both substitute variables
- [x] `fw prompt list` shows the FQID column
- [x] Env override works: `FW_AGENT_ID=xyz fw prompt create --name ...` yields `qid: xyz/P-NNN`
- [x] `tests/unit/lib_prompt.bats` extended with ≥4 new tests covering agent-id
      resolution, counter monotonicity, FQID lookup, and env override
- [x] All bats tests pass (existing 12 + new)

## Verification

grep -q '_prompt_resolve_agent_id' lib/prompt.sh
grep -q '_prompt_next_counter' lib/prompt.sh
grep -q 'qid:' lib/prompt.sh
bash -n lib/prompt.sh
bats tests/unit/lib_prompt.bats

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

### 2026-04-18T14:51:58Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1294-prompt-register-cross-agent-id-namespaci.md
- **Context:** Initial task creation

### 2026-04-18T14:55:35Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f5e06646
- **Timestamp:** 2026-06-02T14:56:30Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
