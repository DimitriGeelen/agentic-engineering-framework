# T-835 Agent B: Human Review Tooling Audit

**Date:** 2026-04-04
**Scope:** Audit existing tools for human task review; identify gaps for efficient processing of 54+ stale tasks.

---

## 1. Existing Tooling Inventory

### 1.1 Watchtower Approvals Page (`/approvals`)

**Files:** `web/blueprints/approvals.py`, `web/templates/approvals.html`, `web/templates/_approvals_content.html`

Three urgency-ordered sections (approvals.py:1-7):
- **A. Tier 0 approvals** — agent-blocking destructive commands
- **B. GO/NO-GO inception decisions** — pending inception tasks
- **C. Human ACs** — tasks with unchecked Human acceptance criteria

**Capabilities:**
- Summary counts bar (Tier 0, GO decisions, Human ACs, Total) — `_approvals_content.html:4-21`
- Priority sorting: REVIEW first, then stale (>7d), then RUBBER-STAMP — `approvals.py:214-230`
- Per-task AC card with expandable details (Steps/Expected/If-not) — `_approvals_content.html:134-171`
- Inline checkbox toggling via htmx POST to `/api/task/<id>/toggle-ac` — `_approvals_content.html:138-145`
- "Complete Task" button appears when all ACs checked — `_approvals_content.html:173-181`
- Age badge with stale warning (>7d amber) — `_approvals_content.html:123-128`
- Mobile review link per task — `_approvals_content.html:129`
- Auto-refresh every 10s via htmx polling — `approvals.html:201-206`

**Limitations:**
- **No batch operations** — every AC toggle is a single POST. No "select all" or "approve multiple."
- **No filtering/sorting controls** — hardcoded priority order, cannot filter by type, age, owner, or horizon.
- **No dismiss/snooze** — cannot hide tasks you've seen but aren't ready to act on.
- **No progress tracking** — no "3 of 54 reviewed" indicator or session progress bar.
- **Loads all tasks at once** — no pagination; 54+ tasks create a very long page.

### 1.2 Mobile Review Page (`/review/T-XXX`)

**Files:** `web/blueprints/review.py`, `web/templates/review.html`

Single-task review card (review.py:1-8):
- Standalone template (no base.html chrome) — optimized for QR scan
- Shows only Human ACs with large touch targets
- htmx polling for live updates via `/review/<task_id>/acs`
- Links to research artifacts

**Limitations:**
- **Single-task only** — no way to navigate to next/previous task needing review.
- **No queue navigation** — must scan a new QR code or manually type URL for each task.
- **No batch completion** — must complete tasks one at a time.

### 1.3 CLI: `fw verify-acs`

**File:** `lib/verify-acs.sh`

Automated evidence collection (verify-acs.sh:1-12):
- Scans `work-completed` tasks with unchecked Human ACs
- Auto-verifies RUBBER-STAMP ACs where possible (URL checks, file existence, CLI commands) — `verify-acs.sh:118-167`
- Skips REVIEW ACs (human judgment required) — `verify-acs.sh:222-229`
- Reports PASS/FAIL/SKIP/REVIEW summary — `verify-acs.sh:253-268`
- Outputs Watchtower URL for reviewing verified tasks

**Limitations:**
- **Only scans `work-completed` tasks** — `verify-acs.sh:196`. Tasks in `started-work` or `issues` with Human ACs are invisible.
- **No auto-check capability** — cannot automatically check ACs that pass verification.
- **Pattern matching is brittle** — URL/command detection relies on keyword matching in AC text (`verify-acs.sh:123-166`). Custom or unusual AC descriptions won't match.
- **Requires Watchtower running** for HTTP checks — `verify-acs.sh:49-53`.

### 1.4 CLI: `fw task stale`

**File:** `bin/fw` (line ~1780-1880)

Simple age-based scanner:
- Lists active tasks with no updates in N days (default 7)
- Color-coded by age (>30d red, >14d yellow)
- Sortable by age

**Limitations:**
- **Output only** — shows a table, but no actions. Cannot triage, close, or batch-update from this view.
- **No AC awareness** — shows all stale tasks, not just those awaiting human review.
- **No integration with approvals** — different view from `/approvals`.

### 1.5 CLI: `fw task review T-XXX`

**File:** `lib/review.sh`

Emits per-task review card:
- Watchtower URL with LAN IP detection — `review.sh:37-63`
- QR code (if python3 qrcode installed) — `review.sh:93-103`
- Human AC count — `review.sh:68-82`
- Research artifact links — `review.sh:106-118`

**Limitations:**
- **Single-task only** — must run once per task.
- **No "next task" suggestion** — after reviewing one, you're on your own.

### 1.6 Task Detail Page (`/tasks/T-XXX`)

**File:** `web/blueprints/tasks.py`

Full task view with:
- AC checkboxes (toggle via htmx) — `tasks.py:581-600`
- "Complete Task" button when all ACs checked — `tasks.py:409-413`
- Status/owner/horizon/type editing — `tasks.py:475-518`
- Research artifact links — `tasks.py:398-406`

**Limitations:**
- **Single-task view** — no queue navigation.
- **Same toggle-one-at-a-time model** as approvals page.

### 1.7 Task Completion (`update-task.sh`)

**File:** `agents/task-create/update-task.sh`

Structural gates on completion:
- **Human sovereignty gate** (R-033) — blocks agent from completing human-owned tasks — `update-task.sh:33-50`
- **AC gate** (P-010) — blocks if agent ACs unchecked — `update-task.sh:55-148`
- **Verification gate** (P-011) — runs shell commands from `## Verification` — `update-task.sh:169-238`
- **Partial-complete** — if human ACs remain, task stays in `active/` with `work-completed` status — `update-task.sh:140-148`
- **Auto-emit review** on partial-complete — `update-task.sh:151-165`
- **Re-run detection** — re-running `--status work-completed` on partial-complete tasks checks if all ACs now satisfied, then moves to `completed/` — `update-task.sh:335-367`

---

## 2. Identified Gaps

### Gap 1: No Batch/Triage Workflow (CRITICAL)

**Problem:** With 54+ stale tasks, the human must visit each task individually, read ACs, check boxes one at a time, and click "Complete Task" per task. At ~2-3 minutes per task, this is 2-3 hours of manual work.

**Missing capabilities:**
- Select multiple tasks and mark all RUBBER-STAMP ACs as checked
- "Approve all verified" button after `fw verify-acs` identifies passing ACs
- Multi-task triage view: quick dismiss, defer, or approve
- Keyboard shortcuts for rapid review (j/k navigation, space to toggle)

### Gap 2: No Review Queue Navigation

**Problem:** `/review/T-XXX` is single-task. After checking ACs on one task, the human must manually navigate to the next. No "Next task" or queue indicator.

**Missing capabilities:**
- "Next" / "Previous" navigation on review page
- Progress indicator: "Task 3 of 54"
- Queue-based navigation ordered by priority (same as approvals page ordering)

### Gap 3: No Stale Task Classification

**Problem:** `fw task stale` shows all 54+ stale tasks as a flat list. Many may need different actions: some should be closed (outdated), some need review, some should be deferred.

**Missing capabilities:**
- Classification: "close (obsolete)", "review (still relevant)", "defer (not now)"
- Bulk status changes from the stale list
- Recommendation engine: agent could pre-classify tasks with rationale

### Gap 4: `fw verify-acs` Cannot Auto-Check Passing ACs

**Problem:** `verify-acs.sh` identifies ACs that pass automated checks but doesn't write the checkbox state. The human must still manually check them in the UI or task file.

**Missing:** `--auto-check` flag that writes `[x]` for passing RUBBER-STAMP ACs.

### Gap 5: No Approvals Page Filtering

**Problem:** The approvals page shows all pending items in a fixed order. With 54+ tasks in section C, there's no way to filter by age, confidence type, workflow type, or horizon.

**Missing:** Filter bar similar to `/tasks` page (status, type, tag, search).

### Gap 6: No "Complete All Checked" Batch Action

**Problem:** When all ACs on multiple tasks are checked, each must be completed individually via the "Complete Task" button. No way to complete all fully-checked tasks at once.

**Missing:** "Complete all ready tasks" button on approvals page.

### Gap 7: No Session Progress / Review Dashboard

**Problem:** No way to track review session progress. After reviewing 20 of 54 tasks, there's no indicator of progress, remaining work, or session history.

**Missing:** Review session tracking: started, reviewed, remaining, time spent.

---

## 3. Architecture Notes

### What Works Well
- **Priority ordering** in approvals page (REVIEW > stale > RUBBER-STAMP) is correct
- **Inline AC toggling** via htmx is fast and responsive
- **Auto-refresh** (10s polling) keeps state synchronized
- **Mobile review page** is well-designed for single-task QR workflow
- **Structural gates** (sovereignty, AC, verification) are robust

### What Needs Rethinking for Scale
- The entire review model is **single-task-oriented**. Every tool (CLI and web) processes one task at a time.
- The approvals page is the closest to a batch view but has no batch actions.
- `fw verify-acs` is the only tool that operates across tasks, but it's read-only.
- There is no API endpoint for batch AC operations — would need `/api/batch/check-acs` or similar.

---

## 4. Summary: Priority Improvements for 54+ Task Backlog

| Priority | Gap | Effort | Impact |
|----------|-----|--------|--------|
| P1 | Batch "approve verified" (`verify-acs --auto-check`) | Small | High — eliminates manual clicking for RUBBER-STAMP ACs |
| P1 | "Complete all ready" batch action on approvals page | Small | High — completes all fully-checked tasks in one click |
| P2 | Review queue navigation (next/prev on `/review/`) | Medium | High — eliminates manual URL navigation |
| P2 | Approvals page filtering (age, type, confidence) | Medium | Medium — helps focus on subsets |
| P3 | Agent pre-classification of stale tasks | Medium | Medium — reduces human triage effort |
| P3 | Keyboard shortcuts for rapid review | Small | Medium — power-user efficiency |
| P4 | Review session progress tracking | Medium | Low — nice-to-have |
