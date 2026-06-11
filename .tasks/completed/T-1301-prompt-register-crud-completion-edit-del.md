---
id: T-1301
name: "Prompt register CRUD completion: edit, delete, backfill (T-1283 B2-addendum)"
description: >
  Prompt register CRUD completion: edit, delete, backfill (T-1283 B2-addendum)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-18T18:38:46Z
last_update: '2026-06-11T22:23:45Z'
date_finished: 2026-04-18T18:41:50Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:45Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1301: Prompt register CRUD completion: edit, delete, backfill (T-1283 B2-addendum)

## Context

Addendum to T-1283 B1/B2: complete local CRUD for the prompt register.
Adds `edit`, `delete`, and `backfill-qid` subcommands so local
authoring workflow doesn't require hand-editing prompt files.

Fleet sync (B5) intentionally deferred — it needs a receiver-side
protocol which is a separate inception.

## Acceptance Criteria

### Agent
- [x] `fw prompt edit <id> --body TEXT` replaces the body, re-extracts
      variables, bumps `updated` timestamp, preserves id/qid/agent_id/counter
- [x] `fw prompt edit <id> --tags a,b` updates tags in frontmatter
- [x] `fw prompt edit <id> --description "..."` updates description
- [x] `fw prompt edit <id> --name "..."` updates the display name (slug is
      preserved — renaming is a separate operation)
- [x] `fw prompt delete <id>` removes the file and prints confirmation
- [x] `fw prompt delete <id> --force` skips the "are you sure" (for scripts);
      without --force in non-tty contexts the delete proceeds (bats needs it)
- [x] `fw prompt backfill-qid` scans prompts/ and assigns qid/agent_id/counter
      to any file missing these fields, using the current agent-id and fresh
      counter values; pre-existing QIDs are untouched
- [x] All subcommands accept slug OR qid as the id arg where meaningful
- [x] `tests/unit/lib_prompt.bats` extended with ≥6 new tests covering
      edit body/tags/description, delete, backfill happy path, backfill idempotency
- [x] All bats tests pass (20 existing + new)

## Verification

grep -q 'do_prompt_edit' lib/prompt.sh
grep -q 'do_prompt_delete' lib/prompt.sh
grep -q 'do_prompt_backfill' lib/prompt.sh
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

### 2026-04-18T18:38:46Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1301-prompt-register-crud-completion-edit-del.md
- **Context:** Initial task creation

### 2026-04-18T18:41:50Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-99905c26
- **Timestamp:** 2026-06-02T14:56:33Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
