---
id: T-1293
name: "Prompt file schema + fw prompt create/list/show/copy CLI (T-1283 B1)"
description: >
  Prompt file schema + fw prompt create/list/show/copy CLI (T-1283 B1)

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-04-18T08:53:33Z
last_update: '2026-06-11T22:23:44Z'
date_finished: 2026-04-18T09:04:26Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:44Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=2 (body:lightly-promoted); F-ORCH=0 (no-signal); 
      F3=1 (body/components:prompt-incidental); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1293: Prompt file schema + fw prompt create/list/show/copy CLI (T-1283 B1)

## Context

B1 of T-1283 (GO recorded 2026-04-17). Foundational: markdown+YAML-frontmatter
prompt files under `prompts/` + `fw prompt` CLI (create/list/show/copy).
Local-only; sync (B5) and Watchtower UI (B3) build on top.

See: docs/reports/T-1283-prompt-register.md

Schema per Q1/Q2 decisions:
- File: `prompts/<slug>.md`
- Frontmatter: `id`, `name`, `description`, `kind` (agent|system|user), `tags`,
  `variables` (array of `{{var}}` names), `created`, `updated`
- Body: prompt text with `{{var}}` substitutions

## Acceptance Criteria

### Agent
- [x] `prompts/` directory created with a README describing the schema
- [x] `lib/prompt.sh` exists with subcommands: create, list, show, copy
- [x] `bin/fw prompt <subcommand>` routes to `lib/prompt.sh`
- [x] `fw prompt create --name "foo" --kind agent --body "Hello {{name}}"` writes
      a valid markdown file with YAML frontmatter to `prompts/foo.md`
- [x] `fw prompt list` outputs one line per prompt (id, name, kind, tags)
- [x] `fw prompt show <id>` prints the full body (frontmatter stripped)
- [x] `fw prompt copy <id> [--var name=world]` prints the body with `{{var}}`
      substitutions applied; missing vars left as `{{var}}` (no hard error)
- [x] `fw help` mentions the `prompt` command
- [x] `tests/unit/lib_prompt.bats` exists and passes (>=5 tests covering
      create, list, show, copy, variable substitution)

## Verification

grep -qE '^[[:space:]]*prompt\)[[:space:]]*$' bin/fw
grep -q 'do_prompt "\$@"' bin/fw
test -f lib/prompt.sh
bash -n lib/prompt.sh
test -d prompts
test -f prompts/README.md
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

### 2026-04-18T08:53:33Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1293-prompt-file-schema--fw-prompt-createlist.md
- **Context:** Initial task creation

### 2026-04-18T09:04:26Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-27fa49f8
- **Timestamp:** 2026-06-02T14:56:30Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
