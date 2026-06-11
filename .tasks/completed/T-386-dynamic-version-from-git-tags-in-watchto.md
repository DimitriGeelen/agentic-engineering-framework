---
id: T-386
name: "Dynamic version from git tags in Watchtower footer"
description: >
  Replace hardcoded v1.0.0 in base.html footer with dynamic version from git describe
  or fw version.

status: work-completed
workflow_type: build
owner: human
horizon:
tags: [ui, version]
components: []
related_tasks: []
created: 2026-03-09T11:10:20Z
last_update: '2026-06-11T22:24:20Z'
date_finished: 2026-03-09T14:00:29Z
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
---

# T-386: Dynamic version from git tags in Watchtower footer

## Context

Replace hardcoded `v1.0.0` in `base.html` footer with dynamic version from `git describe --tags --always`. Version is computed once at app startup and injected as Jinja global `fw_version`.

## Acceptance Criteria

### Agent
- [x] `fw_version` Jinja global set from `git describe --tags --always` in `create_app()`
- [x] `base.html` footer uses `{{ fw_version }}` instead of hardcoded `v1.0.0`
- [x] Fallback to `"dev"` if git command fails
- [x] Footer renders actual version (e.g. `v1.2.6-68-g6eb08f3`)

### Human
- [x] [RUBBER-STAMP] Footer version looks correct
  **Steps:**
  1. Open http://localhost:3000/
  2. Scroll to the bottom of the page
  **Expected:** Footer shows `Watchtower v1.2.6-XX-gHASH` (not `v1.0.0`)
  **If not:** Check Flask logs at `/tmp/flask.log`

## Verification

curl -sf http://localhost:3000/ | grep -q 'Watchtower v'
python3 -c "import web.app; app = web.app.create_app(); assert 'fw_version' in app.jinja_env.globals"

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

### 2026-03-09T11:10:20Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-386-dynamic-version-from-git-tags-in-watchto.md
- **Context:** Initial task creation

### 2026-03-09T13:58:27Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-09T14:00:29Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-47ec4802
- **Timestamp:** 2026-06-02T15:02:31Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 1
     - evidence: `curl -sf http://localhost:3000/ | grep -q 'Watchtower v'`
