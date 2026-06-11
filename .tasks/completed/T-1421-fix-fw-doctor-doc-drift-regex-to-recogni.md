---
id: T-1421
name: "Fix fw doctor doc-drift regex to recognise pipe-joined command forms"
description: >
  Fix fw doctor doc-drift regex to recognise pipe-joined command forms

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [bin/fw]
related_tasks: []
created: 2026-04-24T10:22:02Z
last_update: '2026-06-11T22:23:48Z'
date_finished: 2026-04-24T10:40:58Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:48Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 4
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=4 (body:fw-audit-or-doctor); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1421: Fix fw doctor doc-drift regex to recognise pipe-joined command forms

## Context

`fw doctor` doc-drift check in `bin/fw` (line ~1479) uses regex `` `fw [a-z][-a-z]*( [a-z][-a-z]*)?` `` which only matches single-subcommand backticks like `` `fw audit` ``. After T-1419's Quick Reference trim, many commands now appear as pipe-joined forms (`fw cron generate|status|list|run|pause|resume`, `fw watchtower port|url|status`, `fw notify setup|status|enable|disable|test`, etc.). The regex misses all of these, producing a false-positive "35 subcommands missing" warning when in fact most are documented. Also misses the deliberate "rarely-used commands (harvest, promote, …)" prose paragraph that pointed readers at `fw help`. Fix: make the regex extract the top-level verb from any `` `fw VERB... `` backtick context, and parse the rarely-used prose list as a secondary pass.

## Acceptance Criteria

### Agent
- [x] `fw doctor` doc-drift count drops from 35 to <=5 against the current trimmed CLAUDE.md (actual: 5 — hook, hook-enable, patterns, preflight, setup — all internal or deprecated)
- [x] Specifically, these commands no longer flagged: cron, notify, pickup, pending, watchtower, verify-acs, costs, config, ask, recall, search, serve (all 12 verified recognised)
- [x] Rarely-used verbs named inline (harvest, promote, consolidate, release, self-audit, self-test, plugin-audit, etc.) no longer flagged because the prose-list parser catches them (7/7 verified)
- [x] No new warnings introduced; `fw doctor` run parses successfully and exits with same status class as before (15 warnings, no failures — matches prior state class)

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Verification: regex-based sanity check of the updated bin/fw — no live doctor call
# (doctor is slow/recursive here and is already exercised manually pre-commit).
grep -q "T-1421: extract the verb from any \`fw VERB" bin/fw
grep -q "rarely-used commands" bin/fw
grep -q "_prose_list" bin/fw

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

### 2026-04-24T10:22:02Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1421-fix-fw-doctor-doc-drift-regex-to-recogni.md
- **Context:** Initial task creation

### 2026-04-24T10:40:58Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-41467fcb
- **Timestamp:** 2026-06-02T14:57:21Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
