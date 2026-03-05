# Notification & Discoverability Gaps: Human-Required Actions

## Executive Summary

The framework has **structural support for surfacing human actions** (via partial-complete mechanism and Watchtower cockpit), but **no proactive notification layer**. Humans must actively visit the web UI to discover pending work. No email, webhook, Slack, or CLI alert mechanisms exist.

---

## 1. Human Action Discovery Pathways (What Exists)

### 1.1 Partial-Complete Mechanism (T-193, CLAUDE.md)
- **What it does:** When a task has `### Human` acceptance criteria section, the agent can complete the agent ACs and set status to `work-completed`
- **Task state:** Task stays in `.tasks/active/` with `status: work-completed` and `owner: human`
- **File location:** `/opt/999-Agentic-Engineering-Framework/agents/task-create/update-task.sh` (lines 215-280)
- **Gate:** Human must manually check their ACs and run `fw task update T-XXX --status work-completed` to move to completed/

### 1.2 Watchtower Cockpit "Awaiting Your Verification" Section (T-193, cockpit.py)
- **What it does:** Scans active tasks for unchecked `### Human` ACs and displays them with unchecked item details
- **Function:** `get_human_verify_tasks()` in `/opt/999-Agentic-Engineering-Framework/web/blueprints/cockpit.py` (lines 64-115)
- **UI location:** Cockpit page shows "Awaiting Your Verification (N)" amber section (cockpit.html lines 102-122)
- **Display:** Lists task ID, name, AC progress (e.g., "2/3 checked"), and bulleted unchecked items
- **Link:** Each task links directly to task detail page where human can check boxes

### 1.3 Task Ownership (Web UI)
- **Web tasks page:** Filters by `owner: human` available (via select dropdown in tasks.html line 408)
- **Web task detail:** Inline owner selector allows changing ownership
- **Kanban board:** Shows owner badge on cards
- **But:** No filter exists by "needs-human-action" or automatic surfacing

### 1.4 Resume Agent (resume.sh)
- **What it does:** Synthesizes state on session start, includes "Suggested First Action"
- **Missing:** Does not scan for partial-complete tasks or human ACs pending verification
- **Reference:** Lines 83-200 show status synthesis, but no human action detection

---

## 2. Notification Gaps (What's Missing)

### 2.1 No External Notifications
- **Email:** No mechanism to send email when human action required
- **Webhook:** No webhook triggers for human ACs pending
- **Slack/Teams:** No integration to post to messaging platforms
- **Browser push:** No PWA/browser notifications when visiting web UI
- **Search:** `grep -r "notify\|email\|webhook\|slack\|alert"` on Python/Shell yields only `checkpoint.sh` references to internal logging

### 2.2 No CLI Surfacing
- **No fw command:** No `fw task list --owner human` or `fw task list --needs-verification`
- **No audit check:** Audit script (audit.sh) checks CTL-025 (partial-complete state exists) but doesn't count or report human ACs pending
- **Resume doesn't detect:** `fw resume status` doesn't flag "N tasks awaiting human verification"

### 2.3 No Session Start Awareness
- **Handover doesn't highlight:** Handover template (handover.sh lines 311-495) includes active tasks but doesn't separate "awaiting human" tasks
- **No "Suggested First Action" logic:** Handover template has `[TODO]` for suggested action but doesn't auto-populate based on human ACs pending

### 2.4 No Scheduled Reminders
- **Audit cron (every 30 min):** Audit runs every 30 minutes (per git status) but produces YAML file — no alerting mechanism reads or acts on it
- **Handover episodic gaps:** Handover checks episodic completeness but not human action completeness

---

## 3. Journey Map: "Agent Marks Work-Completed" to "Human Discovers Action Required"

### Current Flow
```
Agent completes task with ### Human ACs
  ↓
Agent runs: fw task update T-XXX --status work-completed
  ↓
Task stays in .tasks/active/ with status: work-completed, owner: human
  ↓
[SILENCE — no notification]
  ↓
Human must proactively:
  1. Visit web UI Cockpit page
  2. Look for "Awaiting Your Verification" section (amber)
  3. Click task link
  4. Check boxes and submit
  OR
  1. Run: fw task list --owner human (doesn't filter by partial-complete)
  2. Manually grep active dir for work-completed status
```

### What's Broken
- **No pull mechanism:** Human is not pulled into action; must push (visit UI)
- **No nudge:** No periodic reminders (cron job checking and emailing, for example)
- **No CLI first-class query:** `fw task list --owner human --status work-completed` doesn't exist
- **No session inject:** Handover doesn't say "⚠ 2 tasks awaiting your verification"

---

## 4. Structural Ownership (by Subsystem)

### Cockpit (web/blueprints/cockpit.py)
- **Responsibility:** Scans tasks for human ACs pending
- **Function:** `get_human_verify_tasks()` — fully implemented
- **Status:** ✓ Works (proves data layer exists)

### Audit Script (agents/audit/audit.sh)
- **Responsibility:** Could report human ACs pending as a check
- **Current:** Only validates partial-complete state exists (CTL-025)
- **Gap:** Doesn't count or warn about human ACs pending

### Handover Agent (agents/handover/handover.sh)
- **Responsibility:** Could flag awaiting-human tasks in "Where We Are"
- **Current:** Lists active tasks but doesn't segment by owner/status
- **Gap:** No detection or highlighting of human ACs pending

### Resume Agent (agents/resume/resume.sh)
- **Responsibility:** Could surface human actions as first action suggestion
- **Current:** Shows generic "Suggested First Action" from last handover
- **Gap:** No detection of human ACs pending

### CLI (bin/fw)
- **Responsibility:** Could provide query commands for human-owned tasks
- **Current:** No filters for partial-complete or human ACs pending
- **Gap:** No `fw task query --needs-human-verification`

---

## 5. Audit Findings

### Existing Partial-Complete Support
- ✓ CLAUDE.md documents the feature (lines in CLAUDE.md referencing T-193, Agent/Human AC Split)
- ✓ Cockpit UI renders "Awaiting Your Verification" section
- ✓ update-task.sh gates completion correctly (ownership, AC checking)
- ✓ Task files support ### Agent / ### Human headers

### Missing Notification Infrastructure
- ✗ No email/webhook/Slack integration
- ✗ No CLI query command for human-owned partial-complete tasks
- ✗ No audit warning when human ACs pending exceed threshold
- ✗ No handover highlighting
- ✗ No resume detection
- ✗ No cron job to check and notify

### Gap Severity
- **Severity:** HIGH (Usability) — feature exists but is undiscoverable
- **Impact:** Human may work on wrong tasks while unaware that agent work is ready for review
- **Root Cause:** Notification tier didn't get implemented; only structural gates and UI view were built

---

## 6. Recommended Quick Wins

1. **CLI command:** Add `fw task list --needs-human-verification` (alias for `owner: human AND status: work-completed`)
2. **Resume agent:** Detect partial-complete tasks and include in status output: "⚠ 2 tasks awaiting your verification"
3. **Audit check:** New check — count and warn if >3 partial-complete tasks (advisory, not blocking)
4. **Handover:** Automatically add "## Awaiting Your Verification" section with links if any human ACs pending
5. **Session start:** Include in handover "Suggested First Action" logic: prefer partial-complete tasks for human review

---

## References
- T-193: Implement P-010 AC tagging (Partial-complete introduced)
- CLAUDE.md: Agent/Human AC Split section (Behavioral Rules)
- cockpit.py: `get_human_verify_tasks()` function (Cockpit page implementation)
- cockpit.html: "Awaiting Your Verification" section (Template lines 102-122)
- update-task.sh: Partial-complete logic (lines 215-280)
