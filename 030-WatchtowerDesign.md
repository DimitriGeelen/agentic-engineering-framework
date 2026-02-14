# 030 — Watchtower Command Center Design Specification

**Status:** Draft
**Task:** T-058
**Authority:** Constitutional Directives D1-D4
**Predecessor:** 025-ArtifactDiscovery.md

## 1. Vision

Transform the web UI from a read-only artifact browser into **Watchtower** — a command center that supports the full application development lifecycle. Watchtower is a governance consciousness: it reflects the project's understanding of itself back to humans and agents.

**Thesis:** "Your project knows more than you think. Watchtower surfaces what it has learned, warns about what it has forgotten, and shows what it is becoming."

## 2. Name

**Watchtower** — a high vantage point to observe the entire project. You use `fw` to work, you use Watchtower to observe and command.

## 3. Lifecycle Stages

| # | Stage | What Happens | Current Support | Watchtower Adds |
|---|-------|-------------|-----------------|-----------------|
| 1 | Inception | Bootstrap, first session | `fw init` | Guided landing, health checklist, task creation form |
| 2 | Planning | Decompose work, decisions | `fw task create` (CLI) | Kanban board, task creation modal, decision recorder |
| 3 | Development | Build cycles, issues | `fw git`, `fw task update` | Session cockpit, git widget, activity feed, healing UI |
| 4 | Quality Gate | Audit, test, verify | `fw audit`, `fw test` | Quality page, run audit/tests, gate status, trend chart |
| 5 | Release | Version, changelog, tag | Nothing | Auto-changelog from commits, release draft/finalize |
| 6 | Operations | Incidents, feedback loop | Nothing | Incident tracker linked to tasks/releases |
| 7 | Evolution | Learn, graduate, refactor | `fw healing`, `fw gaps` | Knowledge graph, graduation pipeline, trigger monitoring |
| 8 | Handover | Context transfer | `fw handover` | Session banner, handover viewer |

## 4. Navigation Redesign

**From:** 9 flat items (Dashboard, Project, Directives, Timeline, Tasks, Decisions, Learnings, Gaps, Search)

**To:** 4 groups + home + search

```
[Watchtower]  Work | Knowledge | Govern | [Search]
```

| Group | Contains | What It Answers |
|-------|----------|----------------|
| Home (logo click) | Dashboard | What needs attention? How is the project? |
| Work | Tasks, Timeline, Releases | What are we doing / did / shipped? |
| Knowledge | Learnings+Patterns+Practices, Decisions | What does the project know? |
| Govern | Directives, Gaps, Quality Gate | Is everything compliant? |
| Search | Global search | Find anything |

**Progressive nav:** Empty projects see only Home + Tasks. Other items appear as content is created.

## 5. Dashboard

### Power User View (tasks > 0)

```
+-------------------------------------------------------+
| WATCHTOWER                             [audit: PASS]   |
+-------------------------------------------------------+
| NEEDS ATTENTION              | RECENT ACTIVITY         |
| - T-058: no update in 5d    | S-2026-0214-1533        |
| - G-005: 40% to trigger     |   3 tasks completed     |
| - L-005: never referenced   |   1 learning captured   |
+------------------------------+-------------------------+
| PROJECT PULSE                                          |
| Tasks: 0 active, 57 done | Gaps: 3 watching           |
| Knowledge: 8L, 8P, 8D | Traceability: 94%            |
+-------------------------------------------------------+
```

### New User View (tasks = 0)

```
+-------------------------------------------------------+
| Welcome to Watchtower                                  |
| Your project is connected to the framework.            |
|                                                        |
| Setup Checklist:                          2/5 done     |
| [x] Framework config                                  |
| [x] Git hooks installed                               |
| [ ] First task created        [Create Task]           |
| [ ] Session initialized       [Init Session]          |
| [ ] First handover            `fw handover`           |
+-------------------------------------------------------+
```

## 6. Key New Pages

### 6.1 Quality Gate (`/quality`)

- Gate status banner: PASS/WARN/FAIL with counts
- "Run Audit" + "Run Tests" + "Full Check" buttons
- Audit sections as accordion (WARN/FAIL open by default)
- Traceability gauge, episodic completeness bar
- Audit trend sparkline
- Test results panel (pass/fail counts, failure details)

### 6.2 Releases (`/releases`)

- Release timeline (version, date, status, task count)
- Auto-generated changelog from task-traced commits
- Release detail: tasks included, decisions made, learnings generated
- Create release draft → finalize (git tag + changelog)

### 6.3 Planning Overview (`/planning`)

- Work breakdown by type/status (CSS bar chart)
- Blockers: tasks with issues + high-severity gaps
- Recent decisions
- Dependency view (if tasks have depends_on)

### 6.4 Knowledge Graph (`/knowledge-graph`)

- Directive trace tree: D1-D4 → practices → learnings → tasks
- Start from any artifact, show ancestry/descendancy
- Graduation candidates panel
- Maturity scores per learning/practice

## 7. Write Actions

### Portal-Enabled (shell out to `fw` CLI)

| Action | Endpoint | Backend | Phase |
|--------|----------|---------|-------|
| Create task | `POST /api/task/create` | `fw task create` | 1 |
| Update status | `POST /api/task/<id>/status` | `fw task update` | Done |
| Init session | `POST /api/session/init` | `fw context init` | 1 |
| Run audit | `POST /api/audit/run` | `fw audit` | 2 |
| Run tests | `POST /api/tests/run` | `pytest` | 2 |
| Record decision | `POST /api/decision` | `fw context add-decision` | 2 |
| Record learning | `POST /api/learning` | `fw context add-learning` | 3 |
| Record note | `POST /api/note` | `fw note` | 2 |
| Diagnose issue | `POST /api/healing/<id>` | `fw healing diagnose` | 2 |
| Draft release | `POST /api/release/draft` | `fw release draft` | 3 |
| Review gap | `POST /api/gap/<id>/check` | YAML update | 3 |

### CLI-Only (not in portal)

- Git operations (commit, push)
- Task deletion
- Directive changes
- Practice editing
- Handover generation

## 8. Architecture Principles

1. **Shell-out, never reimplement** — portal calls `fw` CLI via subprocess
2. **htmx fragments, not JSON** — consistent with existing pattern
3. **No database** — filesystem is source of truth
4. **Polling, not WebSocket** — data changes on minute scale
5. **CSRF on every write** — already wired up
6. **Progressive disclosure** — hide empty, grow with project
7. **Ambient status strip** — focus task, session age, audit dot, attention count

## 9. Ambient Information Strip

Below nav on every page:

```
T-058 active | Session: 2h ago | Audit: PASS | 2 items need attention
```

## 10. Implementation Phases

### Phase 1 — Foundation (viewer → command center)

1. Rename to Watchtower (titles, footer, logo)
2. Task creation form + `POST /api/task/create`
3. Inception detection + guided landing page
4. Navigation redesign (4 groups)
5. Dashboard: Needs Attention + Recent Activity + Project Pulse
6. Ambient status strip

### Phase 2 — Active Development (daily workflow)

7. Quality Gate page (audit/test runner + results display)
8. Kanban board view for tasks
9. Session banner + git state widget
10. Quick note input + decision recorder
11. Inline status changes on task list
12. Healing diagnosis UI on issue tasks

### Phase 3 — Knowledge & Release

13. `fw release draft` + `fw release finalize` CLI commands
14. Releases page with auto-changelog
15. Knowledge graph tree view
16. Graduation pipeline surfacing
17. Gap trigger monitoring with progress bars
18. Cross-reference links between all artifacts

### Phase 4 — Operations (when trigger fires)

19. `fw incident create/resolve` CLI commands
20. Incidents page linked to releases/tasks
21. Postmortem → healing pattern integration
22. Component health heatmap

## 11. What NOT to Build

- Real-time collaboration (single-user framework)
- Rich text editor (markdown is the format)
- Drag-and-drop Kanban (click-to-advance is simpler)
- Gantt charts (no time estimates in framework)
- User authentication (localhost tool)
- Deployment pipelines (framework ends at git tag)
- Monitoring/alerting (no production visibility)
- SLA tracking (no production metrics)

## 12. Success Criteria

- New user runs `fw init` + `fw serve` and creates first task from portal within 2 minutes
- Daily user completes standard workflow (create task, update status, record decision, run audit) without terminal
- Quality Gate page replaces `fw audit` + `fw test` terminal workflow
- Auto-changelog generates release notes from task-traced commits
- Knowledge graph surfaces graduation candidates that were previously invisible
