---
id: T-801
name: "fw costs CLI — token usage tracking from JSONL transcripts"
description: >
  Build task following T-799 (GO) and T-800 (GO) inception decisions. Implement fw
  costs CLI that parses Claude Code JSONL session transcripts to report token usage
  per-session and project totals. Subscription model — cost measured in tokens consumed,
  not dollars. Data source: ~/.claude/projects/ JSONL files with per-turn usage objects
  containing input_tokens, cache_creation_input_tokens, cache_read_input_tokens, output_tokens.
  Key deliverables: (1) JSONL parser extracting token usage, (2) fw costs command
  with session/project/summary views, (3) Watchtower integration for token dashboard.

status: started-work
workflow_type: build
owner: human
horizon: now
tags: [cost, tokens, observability, cli]
components: [bin-fw, budget-gate]
related_tasks: [T-799, T-800, T-596, T-699]
created: 2026-04-03T19:01:09Z
last_update: '2026-05-28T22:54:12Z'
date_finished:
bvp_scores_proposed:
  - ts: '2026-05-19T18:27:46Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T20:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F1: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F1=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T22:54:12Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-19T21:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 2
      effort: 8
    rationale: blast_radius=3 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-801: fw costs CLI — token usage tracking from JSONL transcripts

## Context

Follows T-799 (GO) and T-800 (GO) inception decisions. Research artifact: `docs/reports/T-799-T-800-token-cost-analysis.md`.
Subscription model — cost is measured in tokens consumed, not dollars.
Data source: `~/.claude/projects/` JSONL transcripts with per-turn `usage` objects.
Existing pattern: `budget-gate.sh` already parses JSONL for context budget tracking.

## Acceptance Criteria

### Agent
- [x] `lib/costs.sh` exists with `costs_main()` entry point and `_costs_parse_all()` parser
- [x] `bin/fw` routes `costs` command to lib/costs.sh
- [x] `fw costs` (no args) shows project-total token usage summary
- [x] `fw costs session` shows per-session token breakdown
- [x] `fw costs session <id>` shows detailed breakdown for a specific session
- [x] Output shows: input_tokens, cache_read, cache_create, output_tokens, total per session
- [x] Project totals aggregate across all available transcripts
- [x] `fw costs help` shows usage information
- [x] Component card registered in `.fabric/`

### Human
- [x] [REVIEW] Output format is clear and useful
  **Steps:**
  1. Run `cd /opt/999-Agentic-Engineering-Framework && bin/fw costs`
  2. Run `cd /opt/999-Agentic-Engineering-Framework && bin/fw costs session`
  3. Review the output format and data presentation
  **Expected:** Token usage data is clearly presented, numbers are human-readable (K/M suffixes), session IDs identifiable
  **If not:** Note which columns are confusing or what data is missing

## Verification

# lib/costs.sh exists
test -f lib/costs.sh
# fw costs runs without error
bin/fw costs >/dev/null
# fw costs session runs without error
bin/fw costs session >/dev/null
# fw costs help runs without error
bin/fw costs help >/dev/null
# Component card registered
test -f .fabric/components/lib-costs.yaml

## Recommendation

**Recommendation:** GO

**Rationale:** All 9 Agent ACs verified satisfied against the live codebase: `lib/costs.sh` ships with `costs_main` / `_costs_parse_all`; `bin/fw costs` is wired with sub-routes (default summary, `session`, `session <id>`, `help`); fabric card registered. Output is human-readable with K/M token suffixes and per-session breakdown. Task has been in NO-REC limbo since 2026-04-13 — feature is delivered and used (handover S-2026-0428-1129 frontmatter cites `13.1B tokens, 79381 turns` extracted by this same code path). Awaits Human [REVIEW] of output format clarity.

**Evidence:**
- `test -f lib/costs.sh` → exists.
- `test -f .fabric/components/lib-costs.yaml` → exists.
- `bin/fw costs help` → emits usage block (Token usage tracking / fw costs subcommands).
- `bin/fw costs` → renders summary: 19 sessions, 80,065 total turns, per-category breakdown.
- Dogfood: this session's handover frontmatter reads tokens via the same code path (`13.1B` in S-2026-0428-1129).

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

### 2026-04-03T19:01:09Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-801-fw-costs-cli--token-usage-tracking-from-.md
- **Context:** Initial task creation

### 2026-04-12T09:26:19Z — status-update [task-update-agent]
- **Change:** horizon: now → next
- **Change:** status: started-work → captured (auto-sync)

### 2026-04-13T07:10:20Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-04-13T07:11:07Z — status-update [task-update-agent]
- **Change:** horizon: now → next
- **Change:** status: started-work → captured (auto-sync)

### 2026-04-28T11:33:36Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)
