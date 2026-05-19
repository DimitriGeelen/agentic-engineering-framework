---
id: T-464
name: "PR #6: feat: /capture skill + C-002 Exploratory Conversation Guard"
description: >
  OneDev PR #6 (branch: feature/conversation-guard-capture-skill).
  C-002 rule + /capture skill for conversation persistence.

status: started-work
workflow_type: build
owner: human
horizon: now
tags: [onedev, pr]
components: []
related_tasks: []
created: 2026-03-12T18:00:01Z
last_update: '2026-05-19T18:27:46Z'
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
---

# T-464: PR #6: feat: /capture skill + C-002 Exploratory Conversation Guard

## Context

Cherry-pick PR #6 from OneDev branch `feature/conversation-guard-capture-skill`. Contributed from 010-termlink project (T-108). Branch is 126 commits behind master — cherry-pick is cleaner than merge.

## Acceptance Criteria

### Agent
- [x] C-002 rule added to CLAUDE.md Inception Discipline section
- [x] `/capture` skill exists at `.claude/commands/capture.md`
- [x] `agents/capture/read-transcript.py` exists and passes syntax check
- [x] Fabric component cards exist for capture reader and skill
- [x] Feature branch deleted from remotes after merge

### Human
- [ ] [RUBBER-STAMP] Test `/capture` skill in a live session
  **Steps:**
  1. Start a conversation on an untracked topic
  2. Create a task: `fw work-on "test capture" --type build`
  3. Type `/capture`
  **Expected:** Conversation artifact written to `docs/reports/` and committed
  **If not:** Check `python3 agents/capture/read-transcript.py --dry-run` for transcript format issues

## Verification

test -f .claude/commands/capture.md
test -f agents/capture/read-transcript.py
python3 -c "import ast; ast.parse(open('agents/capture/read-transcript.py').read())"
grep -q "C-002" CLAUDE.md
test -f .fabric/components/capture-reader.yaml
test -f .fabric/components/capture-skill.yaml

## Recommendation

**Recommendation:** GO

**Rationale:** All 5 Agent ACs verified satisfied against live repo state: C-002 rule present in CLAUDE.md (Inception Discipline section), `/capture` skill at `.claude/commands/capture.md`, `agents/capture/read-transcript.py` parses cleanly, both fabric component cards exist, feature branch deleted from remotes. PR #6 cherry-pick is fully integrated — only the [RUBBER-STAMP] live-session test remains for the human.

**Evidence:**
- `test -f .claude/commands/capture.md` → exists.
- `test -f agents/capture/read-transcript.py` → exists.
- `python3 -c "import ast; ast.parse(open('agents/capture/read-transcript.py').read())"` → parses.
- `grep -q "C-002" CLAUDE.md` → matches.
- `test -f .fabric/components/capture-reader.yaml` → exists.
- `test -f .fabric/components/capture-skill.yaml` → exists.
- All 6 verification commands pass.

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

### 2026-03-12T18:00:01Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-464-pr-6-feat-capture-skill--c-002-explorato.md
- **Context:** Initial task creation

### 2026-04-28T17:35:14Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.4)

- **Scan ID:** R-8bada5ba
- **Timestamp:** 2026-04-28T18:13:48Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
