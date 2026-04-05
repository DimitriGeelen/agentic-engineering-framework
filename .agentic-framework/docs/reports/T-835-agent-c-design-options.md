# T-835: Design Options for Clearing the Stale Task Backlog

**Date:** 2026-04-04
**Context:** 101 tasks with `status: work-completed` sit in `.tasks/active/` with 96 unchecked Human ACs across them. The current Watchtower `/approvals` page shows these one-per-card, requiring individual checkbox clicks. This document evaluates three options for efficient batch clearing.

## Current State

| Metric | Value |
|--------|-------|
| Work-completed tasks in `active/` | 101 |
| Tasks with unchecked Human ACs | ~90+ |
| Total unchecked Human ACs | 96 |
| Tasks with `[RUBBER-STAMP]` ACs | 41 |
| Tasks with `[REVIEW]` ACs | 72 |
| Tasks with ONLY `RUBBER-STAMP` (no `REVIEW`) | 31 |

### Existing Infrastructure

- **`/approvals` page** — Lists all pending Human ACs per task with htmx checkbox toggles and "Complete Task" button (appears when all ACs checked). Polls every 10s via htmx.
- **`/api/task/<id>/toggle-ac`** — Toggles a single AC checkbox by line index in the task file.
- **`/api/task/<id>/complete`** — Calls `fw task update --status work-completed --force` to move task to `completed/`.
- **`fw verify-acs`** — CLI tool (`lib/verify-acs.sh`) that scans work-completed tasks, runs automated checks (HTTP probes, file existence, command execution) for RUBBER-STAMP ACs, and reports PASS/FAIL/SKIP/REVIEW.
- **`lib/notify.sh`** — Push notification via ntfy (skills-manager dispatcher on `.150`). Supports categories: tier0, task-complete, audit, handover, human-ac-ready, manual.
- **Confidence markers** — `[RUBBER-STAMP]` (mechanical, automatable) and `[REVIEW]` (human judgment).
- **AC parsing** — `_parse_acceptance_criteria()` in `web/blueprints/tasks.py` already extracts section (agent/human), confidence, steps, expected, if_not, line_idx.

---

## Option A: Batch Approval Page

**UX:** A new `/approvals/batch` page (or enhancement to existing `/approvals`) that groups tasks by AC type and enables multi-select operations.

### How It Works

1. **Grouped view:** Instead of task-by-task cards, show two sections:
   - **RUBBER-STAMP queue** — Flat list of all unchecked RUBBER-STAMP ACs across all tasks, each with a checkbox. "Select All" at top. Evidence column shows `fw verify-acs` results inline.
   - **REVIEW queue** — Grouped by similarity (e.g., "Review article tone", "Review UI layout"), collapsible, with task links.
2. **Batch actions bar** (sticky footer):
   - "Approve Selected" — checks all selected AC checkboxes in their task files
   - "Complete All Fully-Checked" — finds tasks where all ACs are now checked, runs `fw task update --status work-completed` for each
3. **Pre-flight evidence:** Before showing the batch page, run verify-acs logic in the backend. Display PASS/FAIL badge next to each RUBBER-STAMP AC. PASS items are pre-selected.
4. **Progress indicator:** After clicking "Approve Selected", show a progress bar as each AC is toggled via the existing `/api/task/<id>/toggle-ac` endpoint.

### Implementation

- **New template:** `web/templates/approvals_batch.html`
- **New route:** `@bp.route("/approvals/batch")` in `web/blueprints/approvals.py`
- **New API:** `@bp.route("/api/approvals/batch-toggle", methods=["POST"])` — accepts JSON `{acs: [{task_id, line_idx}]}`, toggles all, returns count
- **New API:** `@bp.route("/api/approvals/batch-complete", methods=["POST"])` — finds fully-checked tasks, completes them
- **verify-acs integration:** Extract the Python verification logic from `lib/verify-acs.sh` into a shared module (`web/verify.py`), call it during page render to show evidence badges
- **Link from existing page:** Add "Batch Mode" button on `/approvals` header

### Effort: **M** (Medium) — ~3-4 hours

- Template + 2 API endpoints + batch logic
- Reuses existing `toggle-ac` and `complete` mechanics
- No new dependencies

### Pros
- Tackles the immediate backlog fast — human can clear 31 RUBBER-STAMP-only tasks in ~2 clicks
- Evidence is visible before approving (informed decision)
- Works within existing Watchtower UI (no new systems)
- Full sovereignty — human clicks "Approve Selected", not auto-approved
- Reuses all existing infrastructure (toggle-ac API, complete API, verify-acs logic)
- REVIEW ACs benefit from grouping (see similar reviews side-by-side)

### Cons
- UI work that's less valuable after backlog is cleared (though useful for ongoing maintenance)
- REVIEW ACs still need individual reading (grouping helps but doesn't eliminate effort)
- Doesn't prevent backlog from re-accumulating
- Requires Watchtower running (mobile access only via Traefik route)

---

## Option B: Auto-Close RUBBER-STAMP Tasks

**UX:** A CLI command (`fw verify-acs --auto-close`) or cron job that programmatically verifies RUBBER-STAMP ACs and auto-completes tasks where all evidence passes.

### How It Works

1. **Extend `fw verify-acs`** with `--auto-close` flag:
   - Scan all work-completed tasks with unchecked Human ACs
   - For each task where ALL unchecked ACs are `[RUBBER-STAMP]`:
     - Run automated verification (existing `auto_verify_ac()` logic)
     - If ALL pass: toggle each AC checkbox in the task file, then `fw task update T-XXX --status work-completed --force --reason "Auto-closed: all RUBBER-STAMP ACs verified"`
     - If any fail or can't be verified: skip (leave for human)
   - Tasks with ANY `[REVIEW]` AC are always skipped
2. **Dry-run mode** (default): `fw verify-acs --auto-close --dry-run` shows what WOULD be closed
3. **Cron integration:** Register in `.context/cron/registry.yaml` for daily execution
4. **Audit trail:** Each auto-closure adds an `## Updates` entry with evidence list
5. **Notification:** Call `fw_notify "Auto-closed N tasks" "..." task-complete` after batch

### Implementation

- **Modify:** `lib/verify-acs.sh` — add `--auto-close` and `--dry-run` flag handling (~40 lines Python)
- **Add task-file editing:** Reuse the regex-based checkbox toggle from `_toggle_ac_line()` in tasks.py, or implement equivalent in the embedded Python
- **Add completion call:** `subprocess.run(["bin/fw", "task", "update", task_id, "--status", "work-completed", "--force", ...])`
- **Cron entry:** Add to `.context/cron/registry.yaml`

### Effort: **S** (Small) — ~1-2 hours

- Extend existing verify-acs embedded Python with auto-close branch
- No UI work needed
- Cron registration is trivial via `fw cron`

### Pros
- Immediately clears ~31 tasks (RUBBER-STAMP-only with passing evidence) with zero human effort
- Prevents future backlog — cron auto-closes as tasks complete
- Respects the confidence marker system — `[REVIEW]` tasks never auto-closed
- CLI-native, works headless (no Watchtower dependency)
- Audit trail preserves evidence
- Cheapest option to implement

### Cons
- Bypasses "human clicks checkbox" sovereignty principle — auto-close is agent action
- `auto_verify_ac()` coverage is limited: HTTP probes (needs Watchtower running), file checks, command execution. Some RUBBER-STAMP ACs can't be verified (e.g., "run `fw serve` on macOS" — different platform)
- Risk of false positives if confidence markers are misassigned
- Doesn't help with REVIEW ACs (59 tasks remain)

### Sovereignty Mitigation
- Default is `--dry-run` (explicit opt-in required)
- Human runs the command or approves cron registration (human-initiated, not agent-initiated)
- Every auto-closure logged with evidence in task file
- `[REVIEW]` ACs never touched — hard boundary

---

## Option C: Daily Digest Notification with Deep Links

**UX:** A scheduled notification (ntfy push) with a summary of pending reviews and deep links to Watchtower for action.

### How It Works

1. **Daily cron job** (`fw cron` registry): Runs `fw verify-acs`, generates a digest
2. **Digest content** (via ntfy):
   ```
   Pending Human Reviews: 96 ACs across 90 tasks
   
   Auto-closeable (RUBBER-STAMP, verified): 31 tasks
   → [Approve All] https://watchtower.../approvals/batch?filter=rubber-stamp
   
   Needs review: 59 tasks (72 REVIEW ACs)
   → 5 oldest: T-316 (30d), T-334 (30d), T-432 (27d)...
   → [Review] https://watchtower.../approvals
   ```
3. **Push via ntfy:** Uses existing `lib/notify.sh` → skills-manager alert dispatcher
4. **ntfy action buttons:** ntfy supports inline actions — "Approve All RUBBER-STAMP" could trigger a webhook to `/api/approvals/batch-complete`
5. **Frequency:** Daily at 09:00 (configurable), or on-demand via `fw verify-acs --digest`

### Implementation

- **New script:** `lib/verify-acs-digest.sh` (~50 lines) — wraps verify-acs output, formats for ntfy
- **Cron entry:** Register in `.context/cron/registry.yaml`
- **ntfy actions (optional):** Add `Actions:` header to ntfy message with HTTP callback to Watchtower
- **Best with Option A or B:** Deep links point to batch page (A) or trigger auto-close webhook (B)

### Effort: **S** (Small) standalone — ~1-2 hours

- Digest script + cron: ~1h
- ntfy action buttons: +30 min
- Depends on existing ntfy infrastructure being configured and enabled

### Pros
- Passive — human doesn't need to remember to check Watchtower
- Surfaces the problem daily without being intrusive
- Works on mobile (ntfy app) — review on the go
- Naturally prevents backlog growth by making pending reviews visible
- Low implementation cost
- Compounds with Option A or B — links to batch actions

### Cons
- **Doesn't solve the clearing problem alone** — surfaces the problem but still sends human to one-by-one UI
- Requires ntfy configured and enabled (currently optional, infrastructure on `.150`)
- Without Option A's batch page, deep links go to existing slow approval flow
- Digest fatigue — if backlog stays large, daily "96 ACs pending" becomes noise
- ntfy action buttons require Watchtower accessible from ntfy server (Traefik route needed)

---

## Comparison Matrix

| Factor | A: Batch UI | B: Auto-Close | C: Digest |
|--------|------------|---------------|-----------|
| **Clears current backlog** | Yes (human batch-clicks) | Partially (31 RUBBER-STAMP tasks) | No (surfaces, doesn't solve) |
| **Handles REVIEW ACs** | Yes (grouped view) | No (skips) | Surfaces oldest |
| **Prevents future backlog** | No (must visit) | Yes (cron) | Partially (visibility) |
| **Respects sovereignty** | Full (human clicks) | Partial (auto-close) | Full |
| **Effort** | M (3-4h) | S (1-2h) | S (1-2h) |
| **Dependencies** | Watchtower | None (CLI) | ntfy on `.150` |
| **Mobile-friendly** | Via Traefik | N/A | Yes (ntfy app) |
| **Works standalone** | Yes | Yes | Needs A or B for action |

---

## Recommendation

**Combine B + A in two phases:**

1. **Phase 1 (S, immediate):** Option B — `fw verify-acs --auto-close`. Clear ~31 RUBBER-STAMP-only tasks today with one command. Add cron job to prevent future RUBBER-STAMP backlog.

2. **Phase 2 (M, this week):** Option A — Batch approval page. Address the remaining ~59 tasks with REVIEW ACs. Grouped view makes review faster. "Complete All Fully-Checked" button handles the final step.

3. **Phase 3 (S, optional):** Option C — Daily digest. Nice-to-have for ongoing visibility once the backlog is cleared. Links to the batch page from Phase 2.

**Why this order:** Phase 1 has the best effort-to-impact ratio (1h work, 31 tasks cleared). Phase 2 tackles the harder REVIEW backlog with the right tool (grouped UI for human judgment). Phase 3 prevents re-accumulation.
