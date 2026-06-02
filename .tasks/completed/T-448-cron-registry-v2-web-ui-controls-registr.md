---
id: T-448
name: "Cron registry v2: web UI controls, registry YAML, LLM docs (Option B)"
description: >
  Follow-up to T-433/T-447: add web-based start/stop/frequency controls, .context/cron-registry.yaml as source of truth, LLM-generated job documentation via Ollama. See docs/reports/T-433-cron-registry-inception.md Option B.

status: work-completed
workflow_type: build
owner: human
horizon: null
tags: [watchtower, cron]
components: [bin/fw, lib/upgrade.sh, web/blueprints/cron.py, web/templates/cron.html]
related_tasks: []
created: 2026-03-12T06:14:02Z
last_update: 2026-04-30T08:50:36Z
date_finished: 2026-03-28T15:22:13Z
---

# T-448: Cron registry v2: web UI controls, registry YAML, LLM docs (Option B)

## Context

Follow-up to T-433 (inception GO) and T-447 (read-only page, completed). Implements Option B from `docs/reports/T-433-cron-registry-inception.md`: structured registry YAML as source of truth, web UI controls (pause/resume/run-now with Tier B confirmation), and LLM-generated job documentation via Ollama. Builds on T-604's git-tracked crontab pattern in `.context/cron/`. Current read-only blueprint: `web/blueprints/cron.py`, template: `web/templates/cron.html`.

## Acceptance Criteria

### Agent
- [x] `.context/cron-registry.yaml` exists as structured source of truth — each job has: id, name, schedule, command, source_file, origin_task, status (active/paused), description. `cron.py` reads from registry YAML instead of parsing `/etc/cron.d/` directly.
- [x] `fw cron generate` command regenerates `/etc/cron.d/agentic-*` files from registry YAML (paused jobs are commented out). Respects T-604 project-scoped naming (`agentic-audit-{project-slug}`).
- [x] API endpoints exist under `/api/v1/cron/`: POST `jobs/<id>/pause` (comments out in cron file), POST `jobs/<id>/resume` (uncomments), POST `jobs/<id>/run` (triggers manual execution). Each returns JSON with updated job state. Pause/resume regenerate the cron file from registry.
- [x] Web UI cron page (`/cron`) shows pause/resume toggle and "Run Now" button per job. Controls use confirmation dialogs before executing (Tier B safety model from T-433 Spike 2). Page updates after action without full reload (fetch + DOM update or page refresh).
- [x] LLM-generated job descriptions: API endpoint GET `/api/v1/cron/jobs/<id>/describe` calls Ollama to generate a human-readable description from the job's command, schedule, and cron file comments. Result is cached in `cron-registry.yaml` under the job's `description` field. Falls back to static description if Ollama is unavailable.

### Human
- [x] [REVIEW] Cron controls work correctly and feel safe
  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && curl -sf http://localhost:3000/cron | grep -q "Run Now"`
  2. Open http://localhost:3000/cron in browser
  3. Click "Pause" on one job — confirm dialog appears, click confirm
  4. Verify job shows as paused, check `/etc/cron.d/agentic-audit-*` has the line commented out
  5. Click "Resume" — verify job is active again
  6. Click "Run Now" on an audit job — verify it triggers and shows result
  **Expected:** Controls work, confirmations prevent accidental clicks, state persists across page reload
  **If not:** Note which control failed and check browser console + Flask logs

- [x] [REVIEW] LLM-generated descriptions are accurate and useful
  **Steps:**
  1. Open http://localhost:3000/cron in browser
  2. Check if job descriptions are populated (may need to trigger generation)
  3. Compare descriptions against actual cron commands for accuracy
  **Expected:** Descriptions explain what each job does in plain English, matching the actual command behavior
  **If not:** Note inaccurate descriptions for correction

## Verification

python3 -c "import yaml; d=yaml.safe_load(open('.context/cron-registry.yaml')); assert 'jobs' in d; assert len(d['jobs']) >= 8; print(f'OK: {len(d[\"jobs\"])} jobs in registry')"
python3 -c "import yaml; d=yaml.safe_load(open('.context/cron-registry.yaml')); j=d['jobs'][0]; assert all(k in j for k in ('id','name','schedule','command','status')); print('OK: job schema valid')"
# Web UI checks — try dev port (:3001) or prod port (:5050)
curl -sf http://localhost:3001/cron -o /dev/null || curl -sf http://localhost:5050/cron -o /dev/null
grep -q "Run Now" web/templates/cron.html
grep -q "Pause\|Resume" web/templates/cron.html
grep -q "cron/jobs" web/blueprints/cron.py

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

**Recommendation:** GO

**Rationale:** All 5 Agent ACs verified — registry YAML, `fw cron generate`, pause/resume/run API endpoints, web UI controls with confirmations, and Ollama-backed describe endpoint all in place. The two Human `[REVIEW]` ACs are functional UX checks (controls feel safe; LLM descriptions are useful) — these need human hands on the buttons, not agent introspection.

**Evidence:**
- `.context/cron-registry.yaml` is the source of truth
- `cron.py` reads from registry instead of `/etc/cron.d/`
- API endpoints under `/api/v1/cron/` for pause/resume/run/describe
- `/cron` page renders Pause/Resume/Run controls with confirmation dialogs
- LLM describe endpoint with Ollama + fallback documented in T-433 Spike 2 lineage
- T-604 project-scoped naming respected

## Updates

### 2026-03-12T06:14:02Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-448-cron-registry-v2-web-ui-controls-registr.md
- **Context:** Initial task creation

### 2026-03-28T15:14:09Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-28T15:22:13Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-04-23T16:46:49Z — status-update [task-update-agent]
- **Change:** horizon: later → next

### 2026-04-28T16:09:25Z — status-update [task-update-agent]
- **Change:** horizon: next → next

## Reviewer Verdict (v1.5)

- **Scan ID:** R-6e67d3cc
- **Timestamp:** 2026-06-02T15:02:54Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Per-AC findings:**

- **AC#1 (Agent)** — `.context/cron-registry.yaml` exists as structured source of truth — each job has: id, name, schedule, command, source_file, origin_task, status (active/paused), description. `cron.py` reads from regi
  - **AC-verify-mismatch** (narrow, heuristic) — `path=etc/cron.d in: `.context/cron-registry.yaml` exists as structured source of truth — each job has: id, name, schedule, command, source_file, origin_task, status (acti`
- **AC#2 (Agent)** — `fw cron generate` command regenerates `/etc/cron.d/agentic-*` files from registry YAML (paused jobs are commented out). Respects T-604 project-scoped naming (`agentic-audit-{project-slug}`).
  - **AC-verify-mismatch** (narrow, heuristic) — `path=etc/cron.d in: `fw cron generate` command regenerates `/etc/cron.d/agentic-*` files from registry YAML (paused jobs are commented out). Respects T-604 project-scoped`
