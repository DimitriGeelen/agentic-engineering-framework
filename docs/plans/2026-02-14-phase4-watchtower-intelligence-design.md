# Phase 4 Design: Watchtower Intelligence Layer

**Task:** T-058 Phase 4
**Status:** Draft v2 — revised after 4-perspective review
**Authority:** Constitutional Directives D1-D4
**Predecessor:** Phase 3 (Operational Intelligence — metrics, patterns, system health)
**Schema version:** 1

---

## 1. Vision

Phase 4 transforms Watchtower from a **dashboard** (read-only display) into a **cockpit** (situational awareness + control surfaces). The framework gains the ability to observe the project, detect what matters, make framework-level decisions, and present both humans and AI agents with a synthesized picture and actionable controls.

**Thesis:** The Watchtower is the shared intelligence layer between human and AI. Both consumers need the same thing: information to understand the project state, and an interface to direct work. The scan engine provides the information. The cockpit UI and structured output provide the interfaces.

---

## 2. The Problem Today

### For Humans
- Information is scattered across CLI commands (`fw task list`, `fw metrics`, `fw gaps`, `fw patterns`)
- The web UI shows data but offers no controls — it's a display, not a command surface
- No synthesized picture: human must read 5+ pages and mentally assemble "what matters"
- No inline actions: seeing a stale task requires opening terminal to act on it

### For AI Agents
- Session start requires reading LATEST.md, active tasks, gaps, metrics — manual synthesis
- The `/resume` skill is a hand-coded workaround for missing framework intelligence
- The handover's "Suggested First Action" is a human-written hint because the framework can't compute it
- No prioritized action queue — agent must decide what to work on based on scattered data

### The Common Need
Both human and AI agent need:
1. **Situational awareness** — What's the state of everything? What changed? What's at risk?
2. **Prioritized recommendations** — What should happen next, and why?
3. **Controls** — Ability to approve, dismiss, redirect, reprioritize

---

## 3. Design Principles

1. **One scan, two interfaces** — The scan engine produces structured output. The web UI renders it for humans. The CLI outputs it for agents. Same intelligence, different presentation.

2. **Tasks are the gravitational center** — Consistent with 010-TaskSystem.md. Scan recommendations manifest as task operations (create, update, reprioritize, heal). The scan output is ephemeral and stateless — all persistent state lives in the task system and context fabric, never in scan YAML.

3. **Analysis is Tier 3, action is Tier 1** — The scan itself is read-only (Tier 3: pre-approved diagnostic). Any state mutation (creating tasks, triggering healing, recording decisions) goes through existing `fw` commands with their existing Tier 1 enforcement. The scan recommends; existing commands execute.

4. **Feedback loops are mandatory** — Per D1 (Antifragility), the scan must learn from the outcomes of its own recommendations. Human approvals, dismissals, and overrides feed back into the next scan's effectiveness. The scan is itself antifragile.

5. **Shell-out, never reimplement** — Consistent with 030-WatchtowerDesign.md §8. The cockpit UI calls the scan engine. The scan engine delegates mutations to existing `fw` CLI commands.

6. **Scan supplements, never replaces** — The scan complements the handover (strategic context, tacit knowledge, failed approaches) and existing tools. It does not replace reading LATEST.md or using `fw audit`.

---

## 4. Architecture

### 4.1 Scan Engine

A Framework-level Python module that reads project state and produces a structured scan result.

**Location:** `web/watchtower/`

The scan engine lives alongside the existing Python codebase in `web/`. Rationale: the `lib/` directory contains only shell scripts (`init.sh`, `harvest.sh`) and introducing Python there would break D4 (Portability) expectations. The `web/` directory already contains Python with YAML parsing dependencies. The `fw scan` CLI command shells out to this module explicitly via `python3 -m web.watchtower.scan`, consistent with how `fw serve` shells out to `python3 -m web.app`. This is NOT an agent — it has no AGENT.md, no INITIATIVE, no subcommand routing. It is Framework intelligence at AUTHORITY level.

**Inputs (all read-only, Tier 3):**
- `.tasks/active/*.md` — task status, staleness, dependencies
- `.tasks/completed/*.md` — completion history, velocity
- `.context/project/patterns.yaml` — failure/success/antifragile/workflow patterns
- `.context/project/learnings.yaml` — learnings and graduation candidates
- `.context/project/practices.yaml` — practices, application counts, origin dates
- `.context/project/decisions.yaml` — decision history (including scan dismissals)
- `.context/project/gaps.yaml` — gap triggers and evidence
- `.context/audits/*.yaml` — audit history and trends
- `.context/handovers/LATEST.md` — last session state
- `.context/scans/` — previous scan results (for feedback loop and delta detection)
- `git log` — recent commits, traceability

**Output:** `.context/scans/YYYY-MM-DD-HHMMSS.yaml` + `.context/scans/LATEST.yaml` (symlink)

**Error handling:** The scan degrades gracefully. If any input source is missing or corrupt, the scan produces a partial result and logs the error. A `scan_status` field indicates completeness.

```yaml
schema_version: 1
scan_id: SC-2026-0214-1530
scan_status: complete          # complete | partial | failed
timestamp: 2026-02-14T15:30:00Z
errors: []                     # list of {source, error} if partial/failed

summary: |
  Project health is good (94% traceability, audit passing, 1 active task).
  Top priority: T-058 (Watchtower Phase 4), currently in design phase.
  Two items need your decision: L-005 graduation candidate and G-005 gap approaching trigger.
  Risk: last 3 commits lack task references.
  Strength: 2 new patterns captured since last scan, 1 healing mitigation confirmed effective.

project_health:
  tasks_active: 1
  tasks_completed: 57
  traceability: 94%
  knowledge: {learnings: 8, practices: 7, patterns: 9, decisions: 8}
  gaps_watching: 3
  audit_status: PASS
  velocity: {avg_days_per_task: 2.3, tasks_completed_this_week: 3}

# --- Antifragility indicators (D1) ---
antifragility:
  patterns_added_since_last_scan: 2
  learnings_graduated: 0
  mitigations_confirmed_effective: 1      # applied and failure did not recur
  mitigations_ineffective: 0              # applied but failure recurred
  novel_failures: 0                       # issues with no matching pattern
  dead_letter_practices: 1               # practices with 0 applications after 14+ days
  scan_accuracy:
    recommendations_approved: 12
    recommendations_dismissed: 3
    approval_rate: 80%

# --- Items requiring human decision (SOVEREIGNTY) ---
needs_decision:
  - id: REC-001
    type: graduation
    summary: "Learning L-005 appeared in 4 tasks — ready to graduate to practice"
    evidence: [T-012, T-033, T-041, T-055]
    rationale: "Framework threshold is 3+ occurrences for graduation candidacy"
    suggested_action: {command: "fw task create", args: "--name 'Graduate L-005 to practice' --type refactor --owner human"}
    priority: medium
    priority_factors:
      - rule: graduation_threshold
        detail: "4 occurrences across tasks (threshold: 3+)"

  - id: REC-002
    type: gap_escalation
    summary: "G-005 at 82% trigger threshold — graduation pipeline needs tooling"
    evidence: {current: 82, threshold: 100, trend: "+12% this week"}
    rationale: "Gap decision trigger approaching; no tooling exists to address it"
    suggested_action: {command: "fw task create", args: "--name 'Build graduation pipeline tooling' --type build --owner human"}
    priority: high
    priority_factors:
      - rule: gap_trigger_approaching
        detail: "82% of threshold (>80% triggers recommendation)"
      - rule: trend_acceleration
        detail: "+12% this week, projected to reach threshold in 2 weeks"

  - id: REC-003
    type: dead_letter_practice
    summary: "Practice P-003 has 0 applications since creation 21 days ago"
    evidence: {practice_id: P-003, created: "2026-01-24", applications: 0}
    rationale: "Graduated practices should show application within 14 days"
    suggested_action: "Review P-003 — is it wrong, irrelevant, or unenforced?"
    priority: low
    priority_factors:
      - rule: practice_adoption
        detail: "0 applications, 21 days since graduation (threshold: 14 days)"

  - id: REC-004
    type: novel_failure
    summary: "T-047 entered issues with failure type not matching any known pattern"
    evidence: {task: T-047, failure_description: "API timeout on cold start"}
    rationale: "Novel failures are the primary source of new capability (D1)"
    suggested_action: "Diagnose and capture as new pattern"
    priority: high
    priority_factors:
      - rule: novel_failure_detection
        detail: "No pattern in patterns.yaml matches this failure signature"

# --- Framework recommendations (not yet acted on) ---
# These are Tier 1 actions the framework recommends. They execute
# only when the human approves (cockpit) or the agent applies them.
framework_recommends:
  - id: FRA-001
    type: stale_task
    summary: "T-043 has had no update for 14 days"
    recommended_action: {command: "fw task update T-043 --add-note 'Flagged as stale by scan SC-2026-0214-1530'"}
    priority: medium
    priority_factors:
      - rule: stale_detection
        detail: "14 days since last update (threshold: 14 days, derived from project velocity avg 2.3 days/task)"

  - id: FRA-002
    type: healing_suggestion
    summary: "Pattern FP-003 matches T-047 issue description"
    recommended_action: {command: "fw healing diagnose T-047"}
    priority: medium
    priority_factors:
      - rule: pattern_match
        detail: "FP-003 mitigation has 80% effectiveness (4/5 applications resolved the issue)"

# --- Opportunities (low priority, exploratory) ---
opportunities:
  - id: OPP-001
    type: pattern_consolidation
    summary: "3 success patterns (SP-001, SP-002, SP-003) share common theme — candidate for practice"
    evidence: [SP-001, SP-002, SP-003]
    suggested_action: "Review patterns for practice extraction"
    priority: low

  - id: OPP-002
    type: escalation_advancement
    summary: "Antifragile pattern AF-001 has been at step A for 4 occurrences — ready for step B"
    evidence: {pattern: AF-001, current_step: A, occurrences_at_step: 4, threshold: 3}
    suggested_action: "Advance AF-001 to step B (improve technique)"
    priority: low

# --- Prioritized work queue ---
work_queue:
  - task_id: T-058
    name: "Watchtower Command Center - Design Spec"
    status: started-work
    priority: 1
    priority_factors:
      - rule: session_continuity
        detail: "Last handover listed T-058 as active work-in-progress"
      - rule: status
        detail: "Status: started-work (active execution)"

# --- Risks requiring attention ---
risks:
  - type: traceability_drift
    summary: "Last 3 commits lack task references"
    severity: medium
    suggested_action: "Run fw audit to verify; ensure git hooks are installed"

# --- Changes since last scan (for mid-session re-scans) ---
changes_since_last_scan:
  new_recommendations: [REC-004]
  resolved_recommendations: []
  priority_changes: []
  new_risks: [traceability_drift]
  resolved_risks: []

# --- Context from last handover (for agent orientation) ---
recent_failures:
  - source: handover
    description: "Playwright installer fails on Linux Mint — use symlink workaround"
  - source: patterns
    relevant_to: T-058
    pattern: FP-002
    description: "Inline Python heredocs in bin/fw grow unwieldy — extract to modules"

warnings:
  - "Web server running on :3000"
  - "Playwright requires symlink: /opt/google/chrome/chrome -> /usr/bin/chromium"
```

### 4.2 Scan Phases

The scan has two distinct phases with different authority tiers:

| Phase | Authority | What it does | Mutates state? |
|-------|-----------|-------------|----------------|
| **Analysis** | Tier 3 (pre-approved) | Reads all inputs, computes recommendations, writes scan YAML | Only writes to `.context/scans/` (diagnostic output) |
| **Application** | Tier 1 (via existing commands) | Human approves recommendations in cockpit, or agent applies them via CLI | Yes — through `fw task create`, `fw healing diagnose`, etc. |

The scan NEVER directly mutates task files, patterns, or context. All mutations go through existing `fw` commands with their existing enforcement. The `framework_recommends` section is a proposal log — not a record of actions already taken.

### 4.3 Scan Triggers

| Trigger | When | Consumer |
|---------|------|----------|
| `fw context init` | Session start | AI agent reads LATEST.yaml |
| `GET /` (dashboard) | Human opens Watchtower | Web UI renders cached LATEST.yaml |
| `fw scan` | Manual invocation | Either human or agent |
| `POST /api/scan` | Refresh button in cockpit | Web UI re-renders with fresh scan |

**Performance:** The dashboard page loads immediately using cached LATEST.yaml. The `[Refresh Scan]` button triggers a fresh scan. The `[Scan: Nm ago]` indicator shows cache age.

**Performance budget:** Scan must complete in under 3 seconds for projects with up to 100 active tasks and 500 completed tasks. For larger projects, the scan should sample completed tasks (last 100) and cache intermediate results.

### 4.4 Scan is Stateless

The scan YAML is **ephemeral**. Each scan re-derives all recommendations from current project state. There is no dismiss/undo state stored in scan YAML. Instead:

- **Dismissing** a recommendation records a decision via `fw context add-decision "Deferred L-005 graduation" --rationale "Not enough evidence yet"`. The next scan reads decisions.yaml and filters out items with matching recent decisions.
- **Approving** a recommendation executes the suggested action via the existing command (e.g., `fw task create`). The next scan sees the new task and no longer recommends it.
- **Overriding** a framework recommendation is simply not applying it. The next scan may recommend it again if conditions still hold.

This keeps the task system and context fabric as the sole gravitational center. The scan has no state of its own.

### 4.5 Cockpit UI (Human Interface)

The dashboard (`/`) transforms from a static display into an interactive cockpit.

**Section visibility rules (progressive disclosure):**

| Section | Shown when | Hidden when |
|---------|-----------|-------------|
| Needs Decision | `needs_decision` is non-empty | Empty |
| Framework Recommends | `framework_recommends` is non-empty | Empty |
| Work Direction | Always | Never (core value) |
| Opportunities | `opportunities` is non-empty | Empty |
| System Health + Recent Activity | Always | Never (context) |

Each section shows **max 3 items** by default with a "Show all (N)" expansion link.

When all optional sections are hidden, the cockpit shows: Work Direction + System Health + a "All Clear" banner.

**Visual differentiation:**

| Section | Left border | Icon | Meaning |
|---------|------------|------|---------|
| Needs Decision | Amber/yellow | Warning triangle | "Waiting on you" |
| Framework Recommends | Blue | Info circle | "Framework suggests" |
| Work Direction | None | Numbered list | "Your work queue" |
| Opportunities | Green | Lightbulb | "Optional improvements" |

**Layout:**

```
+-----------------------------------------------------------+
| WATCHTOWER                     [Scan: 2m ago] [Refresh]   |
+-----------------------------------------------------------+
|                                                            |
| ⚠ NEEDS YOUR DECISION (2)            [Show all]          |
| ┌──────────────────────────────────────────────────────┐  |
| │▌L-005 ready to graduate → practice                   │  |
| │▌Appeared in 4 tasks (threshold: 3+)                  │  |
| │▌[Approve] [Defer + Reason]                           │  |
| ├──────────────────────────────────────────────────────┤  |
| │▌G-005 at 82% trigger — needs tooling                 │  |
| │▌Trend: +12% this week                               │  |
| │▌[Create Task] [Defer + Reason]                       │  |
| └──────────────────────────────────────────────────────┘  |
|                                                            |
| ℹ FRAMEWORK RECOMMENDS (2)                                |
| ┌──────────────────────────────────────────────────────┐  |
| │▌T-043 stale (14 days, avg velocity 2.3d)             │  |
| │▌[Apply: Flag as stale] [Ignore]                      │  |
| ├──────────────────────────────────────────────────────┤  |
| │▌FP-003 matches T-047 issue (80% effective)           │  |
| │▌[Apply: Run healing] [Ignore]                        │  |
| └──────────────────────────────────────────────────────┘  |
|                                                            |
| WORK DIRECTION                                             |
| ┌──────────────────────────────────────────────────────┐  |
| │ 1. T-058: Watchtower Phase 4          [Focus] [Skip] │  |
| │    Session continuity + active status                 │  |
| │ 2. T-043: (stale — needs attention)   [Focus] [Skip] │  |
| │    Stale detection, 14 days since update              │  |
| └──────────────────────────────────────────────────────┘  |
|                                                            |
| SYSTEM HEALTH             │ RECENT ACTIVITY               |
| Traceability: 94%         │ S-2026-0214: 3 commits        |
| Knowledge: 8L 7P 9Pa 8D  │ Last audit: PASS               |
| Gaps: 3 watching          │ Tasks completed today: 0       |
| Strength: +2 patterns     │                                |
|   1 mitigation confirmed  │ [Full Metrics →]               |
+-----------------------------------------------------------+
```

**Post-action feedback:** After any control button click, the affected item shows an inline confirmation (e.g., "Task created: T-059") via htmx `hx-swap="outerHTML"`, then fades on next render cycle.

**Control actions (all shell out to `fw` CLI via existing API endpoints):**

| Control | What happens | Backend |
|---------|-------------|---------|
| Approve (needs_decision) | Executes suggested_action, creates task/decision | `fw task create` or `fw context add-decision` |
| Defer + Reason (needs_decision) | Records decision with rationale, suppresses from future scans | `fw context add-decision "Deferred: {summary}" --rationale "{user reason}"` |
| Apply (framework_recommends) | Executes recommended_action | `fw task update` or `fw healing diagnose` |
| Ignore (framework_recommends) | No action; scan may re-recommend next time | No backend call |
| Focus (work_queue) | Sets session focus | `fw context focus T-XXX` |
| Skip (work_queue) | No action; moves to next item | No backend call |
| Refresh Scan | Triggers fresh scan, reloads cockpit | `POST /api/scan` |

**Relationship to existing pages:**

| Existing | Phase 4 action | Rationale |
|----------|---------------|-----------|
| Needs Attention | **Replaced** by Needs Decision + Framework Recommends | Dynamic scan-driven, not static |
| Project Pulse | **Replaced** by System Health (scan-enriched) | Scan adds velocity, antifragility indicators |
| Recent Activity | **Kept** | Backward-looking context the scan doesn't provide |
| Metrics page (`/metrics`) | **Linked** from cockpit "Full Metrics →" | Deep-dive, not replaced |
| Patterns page (`/patterns`) | **Linked** from cockpit | Deep-dive, not replaced |
| Quality page (`/quality`) | **Linked** from cockpit | Deep-dive, not replaced |

**Error state:** If the scan fails or no scan exists, the cockpit shows: "Scan unavailable: {reason}. Showing last known state. [Retry]" and falls back to the existing dashboard data (Needs Attention, Project Pulse).

### 4.6 Agent Interface (AI Consumer)

**Session start protocol (enhanced):**

```bash
# 1. Initialize session (auto-runs scan)
fw context init

# 2. Read handover for strategic context (tacit knowledge, failed approaches, gotchas)
cat .context/handovers/LATEST.md

# 3. Read scan for prioritized actions
cat .context/scans/LATEST.yaml

# 4. Pick highest priority item
fw context focus T-058
```

The scan **supplements** the handover — it does not replace it. The handover provides strategic context (what was tried, what failed, session-specific warnings). The scan provides operational intelligence (what matters now, what to work on, what changed).

**The `summary` field** in the scan YAML provides a natural-language briefing (3-5 sentences) optimized for LLM consumption. Agents should read the `summary` for orientation, then drill into structured sections as needed.

**Agent override protocol:** The `work_queue` is advisory, not binding. The agent may deviate if it has reason to (human instruction, discovered critical bug, stale scan data). When deviating, the agent should log the reason in the task's Updates section: "Deviated from scan work_queue: {reason}."

**Mid-session re-scan:** After completing a task or making significant state changes, the agent can run `fw scan` to get an updated picture. The `changes_since_last_scan` section highlights deltas so the agent doesn't have to diff the full output.

### 4.7 Impact on Existing Tools

| Tool | Post-scan role | Change |
|------|---------------|--------|
| **Handover** | Unchanged. Strategic context (what was tried, what failed, warnings). Scan does not replace. | None — handover remains mandatory at session end |
| **Resume agent** | `resume status` presents LATEST.yaml in CLI format. `resume sync` still syncs working memory. `resume quick` returns scan summary. | Modified — reads scan output instead of re-gathering |
| **Audit agent** | Unchanged. Audit verifies compliance against rules. Scan synthesizes situational awareness. Distinct concerns. | None — scan reads audit results as input, does not duplicate audit logic |
| **`/resume` skill** | Reads LATEST.md (strategic) + LATEST.yaml (operational). Presents unified briefing. | Modified — adds scan output to its synthesis |

**Boundary between `fw audit` and `fw scan`:**
- `fw audit` answers: "Is the project compliant?" — pass/warn/fail against defined rules
- `fw scan` answers: "What needs attention?" — prioritized recommendations for action
- The scan reads audit results as one of its inputs. It does not re-run audit logic. An "audit regression" risk in the scan output means the scan noticed the latest audit is worse than the previous one.

---

## 5. Scan Rules (Detection Logic)

### 5.1 Challenges / Issues

| Rule | Trigger | Output section | Priority |
|------|---------|---------------|----------|
| Stale task | Task in `started-work` with no update > threshold* | `framework_recommends` | Medium |
| Unresolved healing | Task in `issues` with no resolution >7 days | `needs_decision` | High |
| Traceability drift | Last N commits lack task references | `risks` | High |
| Audit regression | Current audit score < previous audit score | `risks` | High |
| Gap trigger approaching | Gap evidence >80% of decision trigger threshold | `needs_decision` | Medium |
| Novel failure | Task in `issues` with no matching pattern in patterns.yaml | `needs_decision` | High |

*Staleness threshold is adaptive: computed as 6x the project's average task velocity (from completed task timestamps). Default: 14 days if insufficient data.

### 5.2 Opportunities

| Rule | Trigger | Output section | Priority |
|------|---------|---------------|----------|
| Graduation candidate | Learning appears in 3+ tasks | `needs_decision` | Medium |
| Pattern consolidation | 3+ success patterns share theme keywords | `opportunities` | Low |
| Practice candidate | Audit finds 3+ similar issues | `opportunities` | Low |
| Escalation advancement | Pattern at current step for 3+ occurrences | `opportunities` | Low |
| Dead-letter practice | Practice with `applications: 0` and created >14 days ago | `needs_decision` | Low |

**Escalation ladder data model:** For the escalation advancement rule to work, patterns need these fields:

```yaml
# Required additions to patterns.yaml entries
escalation_step: A          # Current step: A, B, C, or D
occurrences_at_step: 3      # Count since last escalation
last_escalated: 2026-02-01  # When step last changed
```

The scan checks `occurrences_at_step >= 3` and recommends advancing to the next step. Currently only `antifragile_patterns` have ladder structure; the schema change extends to all pattern types.

### 5.3 Strength Verification (D1 — Antifragility)

| Rule | Trigger | Output section | Priority |
|------|---------|---------------|----------|
| Mitigation effectiveness | Pattern mitigation applied, same failure not seen in subsequent 3 tasks | `antifragility.mitigations_confirmed_effective` | — |
| Mitigation ineffectiveness | Pattern mitigation applied, same failure recurred | `needs_decision` | Medium |
| Practice adoption | Practice created >14 days ago with applications > 0 | `antifragility` (positive signal) | — |
| Strength gain | New patterns/learnings/graduations since last scan | `antifragility` summary | — |

### 5.4 Work Direction

| Rule | Logic | Output |
|------|-------|--------|
| Priority ordering | Issues > stale > active (by recency) > captured | Sorted `work_queue` |
| Session continuity | Tasks from last handover ranked higher | Weighted `work_queue` |
| Dependency awareness | Tasks blocking others ranked higher | Weighted `work_queue` |
| Multi-task context | Related tasks noted in `work_queue` entries | `related_tasks` field per entry |

### 5.5 Feedback Loop (D1 — Closed Loop)

The scan tracks its own recommendation accuracy:

```
Scan N → Recommendations → Human/Agent acts → Outcome recorded in task/context system
                                                        ↓
Scan N+1 → Reads outcomes → Updates accuracy tracking → Adjusts confidence
```

**How it works:**
1. Each recommendation has a `type` (graduation, stale_task, healing_suggestion, etc.)
2. When a human approves via cockpit, the `fw context add-decision` call includes metadata: `--source scan --recommendation-type graduation`
3. When a human defers, the decision rationale is recorded
4. The next scan reads decisions.yaml and computes: of all graduation recommendations, how many were approved vs deferred? This is the approval rate.
5. The `antifragility.scan_accuracy` section exposes this per-type accuracy

**What the scan does NOT do:** It does not automatically suppress recommendation types with low approval rates. Threshold adaptation and rule tuning are human decisions — the scan surfaces the accuracy data, the human decides whether to change the rules.

---

## 6. What This Supplements / Enhances

| Current Mechanism | Scan adds | Relationship |
|-------------------|----------|--------------|
| Handover "Suggested First Action" | Computed `work_queue[0]` with priority factors | **Supplements**: handover still provides strategic context; scan adds dynamic prioritization |
| Dashboard "Needs Attention" | Dynamic `needs_decision` + `framework_recommends` | **Replaces**: scan-driven detection is superior to static listing |
| Dashboard "Project Pulse" | Enriched `project_health` with velocity + antifragility | **Replaces**: scan adds computed metrics |
| Dashboard "Recent Activity" | — | **Keeps**: backward-looking context the scan doesn't compute |
| `/resume` skill manual gathering | Scan runs on `fw context init` | **Supplements**: resume reads scan + handover instead of 5+ files |
| Agent reading LATEST.md | Agent reads LATEST.md + LATEST.yaml | **Supplements**: scan adds operational intelligence alongside strategic context |
| `fw metrics` | Health summary in scan output | **Supplements**: scan provides summary, `/metrics` page remains for deep-dive |
| `fw audit` | Audit results as scan input | **Distinct**: audit = compliance verification, scan = situational awareness |

---

## 7. What NOT to Build

- **Background daemon** — No cron, no scheduler, no persistent process. Scan runs on demand. Consistent with CLI-first, single-session model.
- **Scan state** — No dismiss/undo tracking in scan YAML. All persistent state lives in task system and context fabric. Scan re-derives fresh each time.
- **New agents** — The scan engine is Framework AUTHORITY, not agent INITIATIVE. No `agents/watchtower/` directory, no AGENT.md.
- **New CLI command proliferation** — One new command: `fw scan`. Everything else uses existing commands as execution layer.
- **Notification system** — No push notifications, no alerts. Scan results are pulled by consumers.
- **AI decision-making about code** — The scan makes framework-level decisions (prioritize, flag, escalate). It does NOT decide how to implement, what code to write, or whether a task is done.
- **Drag-and-drop prioritization** — Priority is set by click, not drag. Consistent with 030-WatchtowerDesign.md §11.
- **Autonomous mutations** — The scan NEVER directly modifies task files, triggers healing, or creates tasks. All mutations require explicit application (human click or agent command).
- **ML/adaptive thresholds** — Thresholds are derived from project velocity (simple math), not machine learning. Adaptive ML is a Phase 5 candidate.

---

## 8. CLI Surface

### New
| Command | Purpose | Tier |
|---------|---------|------|
| `fw scan` | Run scan, output to `.context/scans/LATEST.yaml` | Tier 3 (read-only analysis + diagnostic output) |

### Modified
| Command | Change |
|---------|--------|
| `fw context init` | Now auto-runs `fw scan` after session initialization |
| `fw resume status` | Now reads and presents LATEST.yaml alongside LATEST.md |
| `fw resume quick` | Returns scan `summary` field |

### Unchanged (used as execution layer)
- `fw task create` — scan recommendations create tasks through this
- `fw task update` — scan recommendations update tasks through this
- `fw healing diagnose` — scan recommendations trigger healing through this
- `fw context add-decision` — scan deferrals and approvals recorded through this
- `fw audit` — scan reads audit output, does not duplicate audit logic

---

## 9. File Structure

```
web/
  watchtower/
    __init__.py
    scanner.py          # Main scan engine — reads inputs, delegates to rules/prioritizer
    rules.py            # Detection rules (stale, graduation, drift, novel failure, etc.)
    prioritizer.py      # Work queue ordering logic
    feedback.py         # Recommendation accuracy tracking
  blueprints/
    cockpit.py          # Cockpit UI (enhances core.py index route)
  templates/
    cockpit.html        # Cockpit template with control surfaces

.context/
  scans/
    LATEST.yaml         # Symlink to most recent scan
    SC-2026-0214-1530.yaml
```

---

## 10. Implementation Phases (within Phase 4)

### 4a: Scan Engine
- Build `web/watchtower/scanner.py` with input readers and output writer
- Build `web/watchtower/rules.py` with all detection rules from §5
- Build `web/watchtower/prioritizer.py` with work queue ordering
- Build `web/watchtower/feedback.py` with accuracy tracking
- Add `fw scan` command to `bin/fw` (shells out to `python3 -m web.watchtower.scan`)
- Output to `.context/scans/LATEST.yaml`
- Integrate with `fw context init` (auto-scan on session start)
- **Testing strategy:** Fixture-based tests with synthetic `.tasks/` and `.context/` directories. Each test fixture represents a known project state; expected scan output is asserted per-rule. Minimum 1 test per detection rule, plus integration tests for priority ordering and feedback loop.

### 4b: Cockpit UI
- Build `cockpit.html` with progressive disclosure (section visibility rules)
- Visual differentiation: amber (needs decision), blue (recommends), green (opportunities)
- Max 3 items per section with "Show all (N)" expansion
- Control action endpoints: approve, defer+reason, apply, ignore, focus, refresh
- Post-action inline confirmation via htmx
- Error/degraded state when scan unavailable
- Empty state: "All Clear" banner when no recommendations
- **Keep:** Recent Activity section from existing dashboard
- **Replace:** Needs Attention, Project Pulse (replaced by scan-driven sections)
- **Link:** Metrics, Patterns, Quality pages via "Full X →" links
- Tests for cockpit rendering, control actions, empty states, error states

### 4c: Agent Integration
- Update `fw resume status` to read and present LATEST.yaml
- Update `fw resume quick` to return scan `summary` field
- Update session start protocol in CLAUDE.md: read LATEST.md (strategic) then LATEST.yaml (operational)
- Handover template unchanged — "Suggested First Action" remains (it provides strategic intent; scan provides computed priority)
- **Transition:** During rollout, agents that haven't been updated still work — they read LATEST.md as before. The scan is additive, not breaking.
- Verify agent workflow: `fw context init` → read LATEST.md → read LATEST.yaml → start working

### 4d: Feedback Loop
- Wire cockpit approve/defer actions to include `--source scan --recommendation-type {type}` metadata in decision records
- Build cross-scan comparison in `feedback.py` (compare current scan with previous)
- Populate `antifragility` section: strength gains, mitigation effectiveness, scan accuracy
- Populate `changes_since_last_scan` section for mid-session re-scans
- Tests for feedback accuracy computation and cross-scan delta detection

---

## 11. Data Model Changes

### patterns.yaml — escalation tracking fields

```yaml
# Add to each pattern entry:
escalation_step: A              # A | B | C | D
occurrences_at_step: 0          # Reset on escalation
last_escalated: null            # ISO timestamp or null
```

### decisions.yaml — scan source tracking

```yaml
# When a scan recommendation is approved or deferred, the decision entry includes:
- id: OD-015
  decision: "Approved graduation of L-005 to practice"
  source: scan                  # Distinguishes scan-driven from manual decisions
  recommendation_type: graduation
  scan_id: SC-2026-0214-1530
  date: 2026-02-14
```

### scans/ directory

New directory: `.context/scans/`. Add to `.gitignore` consideration — scan results are ephemeral diagnostics. Recommend NOT committing scan files (they are re-derivable from project state).

---

## 12. Success Criteria

1. **Human opens Watchtower and immediately knows what matters** — no clicking through 5 pages
2. **Human can act inline** — approve, defer, apply without leaving the cockpit
3. **AI agent starts session and gets a prioritized work queue** — reads LATEST.md + LATEST.yaml
4. **Framework detects stale tasks, graduation candidates, gap triggers, novel failures** — without human or agent prompting
5. **All scan recommendations are auditable** — approvals and deferrals recorded in decisions.yaml
6. **The scan learns from outcomes** — accuracy tracking shows whether recommendations are useful
7. **Dead-letter practices are detected** — practices with 0 applications flagged for review
8. **No new agent architecture** — scan uses existing agents as execution layer
9. **No new CLI command proliferation** — one new command (`fw scan`), rest is existing
10. **Scan completes in <3 seconds** for projects up to 100 active tasks
11. **Cockpit degrades gracefully** — shows existing dashboard data when scan unavailable

---

## 13. Authority Model Alignment

| Component | Authority Level | Justification |
|-----------|----------------|---------------|
| Scan engine (read + write diagnostic) | Tier 3 (pre-approved) | Reads project state, writes to `.context/scans/`. No task/context mutation. |
| Scan recommendations | Framework AUTHORITY | Framework-level intelligence: detect, prioritize, recommend. Transparent and logged. |
| Applying recommendations | Tier 1 via existing commands | Human clicks [Apply] → `fw task update`. Agent runs suggested command. Same enforcement as manual usage. |
| Deferring recommendations | Recorded as decision | `fw context add-decision` — lives in context fabric, not scan YAML. |
| Human override | SOVEREIGNTY | Approve/defer/ignore in cockpit. Agent can deviate from work_queue with logged reason. |
| Agent consumption | INITIATIVE | Agent reads scan, decides how to act within its initiative scope. Work queue is advisory. |

The scan engine IS the Framework exercising its authority — observing, analyzing, recommending. The human retains sovereignty through cockpit controls and the ability to override any recommendation. Agents remain at initiative level, informed by the scan but not bound by it.

---

## 14. Antifragility Commitment (D1)

This design serves D1 through four mechanisms:

1. **Detection** — The scan identifies graduation candidates, novel failures, stale patterns, and dead-letter practices. It surfaces what the project has learned and what it hasn't applied.

2. **Strength measurement** — The `antifragility` section in scan output tracks: patterns gained, mitigations confirmed effective, practices adopted. This makes "getting stronger" visible and measurable.

3. **Feedback loop** — The scan tracks its own recommendation accuracy. Approvals and deferrals are recorded with rationale. The next scan reads these outcomes. The scan is antifragile to its own mistakes.

4. **Escalation advancement** — The scan detects patterns stuck at the same escalation step and recommends advancement. This prevents the system from forever repeating step A ("don't repeat the failure") and pushes toward step D ("change ways of working").

**Known limitation:** Threshold adaptation (adjusting rules based on project rhythm) is deferred to Phase 5. Current thresholds use simple velocity-derived math, not learning-based adaptation.

---

## 15. Review Findings Addressed

| Finding | Source | Resolution |
|---------|--------|------------|
| Scan must be stateless | Architect | §4.4: Scan re-derives fresh. No dismiss/undo state. Deferrals recorded as decisions. |
| Split analysis from action | Architect | §4.2: Analysis = Tier 3, Application = Tier 1. `framework_acted` → `framework_recommends`. |
| Placement in `lib/` violates language boundary | Architect | §4.1: Moved to `web/watchtower/`. Justified: existing Python codebase, `fw scan` shells out explicitly. |
| Add natural language summary | Agent Dev | §4.1 schema: `summary` field (3-5 sentences). |
| Enrich work_queue reasons | Agent Dev | §4.1 schema: `priority_factors` list per recommendation. |
| Scan supplements handover, doesn't replace | Agent Dev | §3 principle 6, §4.6, §6: explicit "supplements" language throughout. |
| Add schema_version | Architect | §4.1 schema: `schema_version: 1`. |
| Add scan_status and errors | Architect, Agent Dev | §4.1 schema: `scan_status: complete|partial|failed`, `errors: []`. |
| Define agent override protocol | Agent Dev | §4.6: Work queue is advisory. Deviations logged in task Updates. |
| Performance budget | Agent Dev, UX | §4.3: 3-second budget. Page loads cached LATEST.yaml. |
| Scan error/degraded state in UI | UX | §4.5: "Scan unavailable" fallback to existing dashboard. |
| Progressive disclosure | UX | §4.5: Section visibility rules. Max 3 items. "All Clear" banner. |
| Visual differentiation | UX | §4.5: Amber (decisions), blue (recommends), green (opportunities). |
| Post-action feedback in UI | UX | §4.5: Inline confirmation via htmx, fade on next render. |
| Cockpit relationship to existing pages | UX | §4.5: Keep (Recent Activity), Replace (Needs Attention, Pulse), Link (Metrics, Patterns, Quality). |
| Close feedback loop | Antifragility | §5.5: Scan accuracy tracking. Outcomes feed into next scan. |
| Practice adoption verification | Antifragility | §5.2: Dead-letter practice rule. §5.3: Adoption tracking. |
| Escalation ladder data model | Antifragility | §11: Schema changes for escalation_step, occurrences_at_step, last_escalated. |
| Novel failure detection | Antifragility | §5.1: Novel failure rule (issues with no pattern match). |
| Strength gain metric | Antifragility | §4.1 schema: `antifragility` section. §5.3: Strength verification rules. |
| Mitigation effectiveness tracking | Antifragility | §5.3: Confirmed effective / ineffective tracking. |
| Define `fw audit` boundary | Architect | §4.7: Audit = compliance verification, scan = situational awareness. Scan reads audit output. |
| Resume agent post-scan role | Agent Dev | §4.7: `resume status` reads scan, `resume sync` unchanged, `resume quick` returns summary. |
| Testing strategy | Architect | §10 phase 4a: Fixture-based tests, 1 test per rule minimum. |
| Cross-scan comparison | Antifragility | §4.1 schema: `changes_since_last_scan` section. |
| Recent failures context | Agent Dev | §4.1 schema: `recent_failures` section from handover + patterns. |
