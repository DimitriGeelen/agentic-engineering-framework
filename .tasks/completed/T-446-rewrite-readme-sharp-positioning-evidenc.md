---
id: T-446
name: "Rewrite README: sharp positioning, evidence-first, 5-min demo, honest gradient"
description: >
  Rewrite README: sharp positioning, evidence-first, 5-min demo, honest gradient

status: work-completed
workflow_type: build
owner: human
horizon:
tags: []
components: []
related_tasks: []
created: 2026-03-12T00:36:10Z
last_update: '2026-06-11T22:24:21Z'
date_finished: 2026-03-14T21:00:57Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:21Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=2 (body:lightly-promoted); F-ORCH=0 (no-signal); 
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-446: Rewrite README: sharp positioning, evidence-first, 5-min demo, honest gradient

## Context

Inception T-445 GO. See `docs/reports/T-445-readme-overhaul.md` for research (positioning, evidence, voice guide).

## Acceptance Criteria

### Agent
- [x] README rewritten with sharp positioning in first 3 lines
- [x] "What this has actually stopped" section with real enforcement output
- [x] 5-minute demo section (5 commands → visible value)
- [x] Honest enforcement gradient (Claude Code tested, others untested)
- [x] Architecture/complexity moved into collapsibles
- [x] Voice matches author tone (no hype, no emojis, cross-domain analogies, specific evidence)
- [x] README ≤ 400 lines (316)
- [x] Screenshots: 6 inside collapsibles with width sizing, none in main flow

### Human
- [x] [REVIEW] Positioning reads as "governance layer" not "assistant runtime"
  **Steps:**
  1. Read the first 5 lines of README.md
  2. Ask: "Would a visitor immediately understand this is NOT another OpenClaw?"
  **Expected:** Clear differentiation in first 3 seconds
  **If not:** Note which lines feel ambiguous

## Verification

# README exists and is valid markdown
test -f README.md
# Under 400 lines
python3 -c "lines=len(open('README.md').readlines()); assert lines <= 400, f'Too long: {lines}'; print(f'OK: {lines} lines')"
# Screenshots inside collapsibles (HTML img tags)
grep -q "watchtower-tasks-board.png" README.md
grep -q "watchtower-fabric-graph.png" README.md
grep -q "watchtower-timeline.png" README.md
# All screenshots use width attribute for sizing
python3 -c "import re; t=open('README.md').read(); imgs=re.findall(r'<img[^>]+>', t); assert all('width=' in i for i in imgs), 'Some imgs missing width'; print(f'OK: {len(imgs)} sized screenshots')"
# No hype words
python3 -c "t=open('README.md').read().lower(); bad=[w for w in ['revolutionary','game-changing','cutting-edge','ai-powered'] if w in t]; assert not bad, f'Hype words found: {bad}'; print('OK: no hype')"
# No exclamation marks in prose (outside code blocks AND markdown image refs)
# T-1413: was missing the ![alt](url) strip — image syntax was false-flagging.
python3 -c "import re; t=open('README.md').read(); clean=re.sub(r'```.*?```','',t,flags=re.DOTALL); clean=re.sub(r'!\[[^\]]*\]\([^)]*\)','',clean); count=clean.count('!'); assert count==0, f'{count} exclamation marks'; print('OK: no exclamation marks')"

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Recommendation

**Recommendation:** DEFER

**Rationale:** All 8 Agent ACs are mechanically verifiable and check out (line count, sections, screenshots), but the Human AC is asking exactly the question only a human can answer: "does the positioning land in the first 3 seconds?" Voice-and-positioning is a marketing judgment, not a code judgment — agent should not GO this without the human reading it. This is the canonical [REVIEW] case from CLAUDE.md AC Classification Guidance ("subjective judgment — quality, tone, UX feel").

**Evidence:**
- README.md is 316 lines (≤400 ✓)
- "What this has actually stopped" section present
- 5-minute demo section present
- Honest enforcement gradient documented
- 6 screenshots inside collapsibles with width sizing
- Voice/tone matches author style — but THIS is the human's call, not the agent's

## Updates

### 2026-03-12T00:36:10Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-446-rewrite-readme-sharp-positioning-evidenc.md
- **Context:** Initial task creation

### 2026-03-14T21:00:57Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-04-06T22:29:17Z — status-update [task-update-agent]
- **Change:** horizon: now → next

## Reviewer Verdict (v1.5)

- **Scan ID:** R-659f09ec
- **Timestamp:** 2026-06-02T15:02:53Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
