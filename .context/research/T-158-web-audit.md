# Watchtower Web UI Testing Audit — T-158

## 1. Python Files Summary

| File | Lines | Purpose |
|------|-------|---------|
| app.py | 185 | Flask app setup, CSRF protection, error handlers |
| shared.py | 138 | Path resolution, navigation config, ambient status |
| blueprints/core.py | 340 | Dashboard, project docs, directives |
| blueprints/tasks.py | 275 | Task list, detail, create/update APIs |
| blueprints/discovery.py | 341 | Decisions, learnings, gaps, search, patterns, graduation |
| blueprints/quality.py | 216 | Quality gate, audit/test APIs |
| blueprints/session.py | 226 | Session status, decisions/learnings API, healing |
| blueprints/metrics.py | 198 | Project health metrics |
| blueprints/cockpit.py | 217 | Scan-driven dashboard, control action APIs |
| blueprints/inception.py | 297 | Inception tasks, assumptions, decisions |
| blueprints/timeline.py | 152 | Session timeline, emergency handover collapse |
| blueprints/enforcement.py | 160 | Enforcement status, hook validation, bypass log |
| watchtower/scanner.py | 429 | Framework scanning logic |
| watchtower/rules.py | 545 | Scan rules & prioritization |
| watchtower/prioritizer.py | 102 | Prioritization engine |
| watchtower/feedback.py | 81 | Feedback collection |
| watchtower/__main__.py | 68 | CLI entry point |
| test_app.py | 794 | Comprehensive Flask tests (38 test methods) |
| watchtower/test_scan.py | 609 | Watchtower scanner tests |
| **TOTAL** | **5,375** | |

## 2. HTML Templates (26 files)

### Core Layout
- `base.html` — Main HTML structure with Pico CSS
- `_wrapper.html` — Page wrapper (renders content_template inside base)
- `_error.html` — Error page fragment

### Navigation & Status
- `_session_strip.html` — Session cockpit strip (branch, changes, focus task)

### Main Pages
- `index.html` — Dashboard with inception checklist, task counts, audit status
- `cockpit.html` — Scan-driven dashboard (needs_decision, framework_recommends, opportunities)
- `project.html` — Project documentation list
- `project_doc.html` — Markdown document renderer

### Task Management
- `tasks.html` — Task list with board/list views, filters (status, type, component, tag), sort
- `task_detail.html` — Task detail with frontmatter, episodic memory

### Work Pages
- `timeline.html` — Session timeline with emergency collapse
- `inception.html` — Inception task list with decision filters
- `inception_detail.html` — Inception detail with sections (problem, assumptions, exploration, constraints, scope, criteria, decision, updates)
- `assumptions.html` — Assumption registry

### Knowledge Pages
- `learnings.html` — Learnings, patterns (failure/success/antifragile/workflow), practices
- `decisions.html` — Decisions (architectural & operational)
- `patterns.html` — Pattern browser with type filter
- `graduation.html` — Learning graduation status
- `gaps.html` — Gap register

### Governance
- `directives.html` — Constitutional directives with linked practices, decisions, gaps
- `enforcement.html` — Enforcement status (Tier 0-3, hook status, bypass log)
- `quality.html` — Quality gate (audit results, traceability, episodic completeness, test results)
- `metrics.html` — Project health metrics

### Utilities
- `search.html` — Search results by category (Tasks, Episodic Memory, Project Memory, Handovers, Specs)
- `_timeline_task.html` — Timeline task row component
- `_quality_audit_fragment.html` — Audit results fragment (for htmx reload)

## 3. Routes & Endpoints (38 total)

### Core Routes (GET)
| Route | Method | Purpose | Side Effects |
|-------|--------|---------|--------------|
| `/` | GET | Dashboard (inception or cockpit) | Loads scan, audit, handover data |
| `/project` | GET | Project docs list | Scans 0*.md files |
| `/project/<doc>` | GET | Render markdown doc | Path sanitization required |
| `/directives` | GET | Constitutional directives | Loads directives, practices, decisions, gaps |

### Task Management (GET + API POST)
| Route | Method | Purpose | Side Effects |
|-------|--------|---------|--------------|
| `/tasks` | GET | Task board/list with filters | Loads all active+completed tasks, episodic tags |
| `/tasks/<task_id>` | GET | Task detail page | Loads frontmatter + episodic memory |
| `/api/task/create` | POST | Create task | Calls `fw task create` (subprocess) |
| `/api/task/<task_id>/status` | POST | Update status | Calls `fw task update --status` (subprocess) |
| `/api/task/<task_id>/horizon` | POST | Set horizon (now/next/later) | Calls `fw task update --horizon` (subprocess) |

### Timeline (GET + API POST)
| Route | Method | Purpose | Side Effects |
|-------|--------|---------|--------------|
| `/timeline` | GET | Session timeline with emergency collapse | Scans handovers, collapses consecutive emergency runs |
| `/api/timeline/task/<task_id>` | GET | Task detail for timeline expansion | Returns snippet with focused info |

### Discovery Pages (GET)
| Route | Method | Purpose | Side Effects |
|-------|--------|---------|--------------|
| `/decisions` | GET | Decisions (architectural + operational) | Reads decisions.yaml, 005-DesignDirectives.md |
| `/learnings` | GET | Learnings, patterns, practices | Reads learnings.yaml, patterns.yaml, practices.yaml |
| `/gaps` | GET | Gap register | Reads gaps.yaml |
| `/patterns` | GET | Pattern browser with type filter | Reads patterns.yaml, filters by type |
| `/graduation` | GET | Learning graduation status | Counts learnings, calculates coverage |
| `/search` | GET | Full-text search | Calls `grep` subprocess, searches .tasks/.context/specs |

### Quality & Metrics (GET + API POST)
| Route | Method | Purpose | Side Effects |
|-------|--------|---------|--------------|
| `/quality` | GET | Quality gate dashboard | Loads audit YAML, runs `git log` for traceability |
| `/api/audit/run` | POST | Execute audit | Calls `fw audit` (subprocess), saves YAML |
| `/api/tests/run` | POST | Execute tests | Calls `fw test` (subprocess) |
| `/metrics` | GET | Project health metrics | Git/YAML reads, no external calls |

### Session Cockpit (GET + API POST)
| Route | Method | Purpose | Side Effects |
|-------|--------|---------|--------------|
| `/api/session/status` | GET | Session state fragment | Calls `git status`, reads working memory |
| `/api/session/init` | POST | Initialize session | Calls `fw context init` (subprocess) |
| `/api/decision` | POST | Record decision | Calls `fw context add-decision` (subprocess) |
| `/api/learning` | POST | Record learning | Calls `fw context add-learning` (subprocess) |
| `/api/healing/<task_id>` | POST | Run healing diagnosis | Calls `fw healing diagnose` (subprocess, 60s timeout) |

### Inception (GET + API POST)
| Route | Method | Purpose | Side Effects |
|-------|--------|---------|--------------|
| `/inception` | GET | Inception task list with filters | Loads all inception tasks, linked assumptions |
| `/inception/<task_id>` | GET | Inception detail with sections | Loads task body, linked assumptions, episodic |
| `/inception/<task_id>/add-assumption` | POST | Add assumption | Calls `fw assumption add` (subprocess) |
| `/inception/<task_id>/decide` | POST | Record inception decision | Calls `fw inception decide` (subprocess) |
| `/assumptions` | GET | Assumption registry | Reads assumptions.yaml |
| `/assumptions/<assumption_id>/resolve` | POST | Mark assumption validated/invalidated | Calls `fw assumption validate/invalidate` (subprocess) |

### Cockpit Control Actions (POST only)
| Route | Method | Purpose | Side Effects |
|-------|--------|---------|--------------|
| `/api/scan/refresh` | POST | Trigger scan & reload cockpit | Calls `fw scan --quiet` (subprocess) |
| `/api/scan/approve/<rec_id>` | POST | Approve needs_decision item | Calls `fw` to execute action + record decision |
| `/api/scan/defer/<rec_id>` | POST | Defer needs_decision item | Calls `fw context add-decision` with deferral reason |
| `/api/scan/apply/<rec_id>` | POST | Apply framework_recommends | Calls `fw` to execute action |
| `/api/scan/focus/<task_id>` | POST | Set focus task from cockpit | Calls `fw context focus` (subprocess) |

### Governance (GET)
| Route | Method | Purpose | Side Effects |
|-------|--------|---------|--------------|
| `/enforcement` | GET | Enforcement dashboard | Reads .claude/settings.json, .git/hooks, bypass-log.yaml |

## 4. External Dependencies (subprocess calls)

### fw CLI Commands (17 unique)
All calls use `subprocess.run()` with timeouts and PROJECT_ROOT env var:

| Command | Used In | Timeout | Inputs | Side Effects |
|---------|---------|---------|--------|--------------|
| `fw task create` | tasks.py (create_task) | 30s | name, type, owner, horizon, description, tags | Creates .tasks/active/T-XXX-*.md |
| `fw task update --status` | tasks.py | 30s | task_id, status | Updates task frontmatter |
| `fw task update --horizon` | tasks.py | 30s | task_id, horizon | Updates task horizon field |
| `fw context init` | session.py | 30s | none | Initializes .context/working/ |
| `fw context add-decision` | session.py, cockpit.py | 30s | text, task, rationale, source | Writes decisions.yaml |
| `fw context add-learning` | session.py | 30s | text, task, source | Writes learnings.yaml |
| `fw context focus` | cockpit.py | 30s | task_id | Updates focus.yaml |
| `fw healing diagnose` | session.py | 60s | task_id | Analyzes task issues, returns diagnosis |
| `fw assumption add` | inception.py | 10s | statement, task | Adds to assumptions.yaml |
| `fw assumption validate` | inception.py | 10s | assumption_id, evidence | Updates assumption status |
| `fw assumption invalidate` | inception.py | 10s | assumption_id, evidence | Updates assumption status |
| `fw inception decide` | inception.py | 10s | task_id, decision (go/no-go) | Records decision in task body |
| `fw scan --quiet` | cockpit.py | 30s | none | Generates .context/scans/LATEST.yaml |
| `fw audit` | quality.py | 60s | none | Generates .context/audits/timestamp.yaml |
| `fw test` | quality.py | 120s | none | Runs project tests, returns pytest output |

### Git Commands (read-only, 10s timeout)
| Command | Used In | Purpose |
|---------|---------|---------|
| `git -C PROJECT_ROOT branch --show-current` | session.py | Get current branch |
| `git -C PROJECT_ROOT status --porcelain` | session.py | Count uncommitted changes |
| `git -C PROJECT_ROOT log -1 --oneline` | session.py | Get last commit |
| `git log --oneline -200 --format=%s` (cwd PROJECT_ROOT) | quality.py, metrics.py | Calculate traceability % |
| `grep -rn` | discovery.py (search) | Full-text search across .tasks/.context/specs |
| `grep -n` | discovery.py (search) | Extract match lines for search results |

### Shell I/O
- **File reads**: YAML (20+), Markdown (5+), task frontmatter (regex extraction)
- **File writes**: None (read-only for web UI; fw CLI writes files)
- **Environment**: PROJECT_ROOT, FW_SECRET_KEY, FW_PORT, FW_HOST

## 5. Existing Test Coverage

### test_app.py (794 lines, pytest-based)

#### Test Classes (12)
1. **TestRoutes** — 7 routes + search (parametrized)
2. **TestHtmxPartials** — htmx fragment rendering (no html wrapper)
3. **TestCSRF** — CSRF token validation (missing, invalid, valid token & header)
4. **TestErrorHandlers** — 404 for nonexistent pages, task IDs, path traversal
5. **TestTaskDetail** — Task render, ID validation, status API
6. **TestKanbanBoard** — Board/list views, create form, create API validation
7. **TestTimeline** — Timeline page, task detail API, invalid IDs
8. **TestQualityGate** — Quality page render, action buttons, API CSRF check
9. **TestSessionCockpit** — Session status, git info, decision/learning/healing APIs
10. **TestDataIntegrity** — Real framework data display (tasks, gaps, decisions, learnings, directives, docs, search)
11. **TestNavigation** — Watchtower brand, nav groups, grouped nav structure
12. (More tests in file, lines 450+)

#### Test Coverage Summary
- **38 routes tested** (all main pages + APIs)
- **CSRF protection** validated (missing token = 403, invalid = 403, valid = pass)
- **Input validation** (task ID format, status values, type enum, horizon enum)
- **Error handlers** (404, 403)
- **htmx partial rendering** (no DOCTYPE in HX-Request responses)
- **Data integrity** (framework data loads correctly)
- **API timeouts** not explicitly tested

### test_scan.py (609 lines)
- Watchtower scanner tests (rules, prioritization, gap analysis)
- Not web UI specific

### Test Runner
```bash
pytest web/test_app.py -v
```

## 6. Testing Needs & Gaps

### Critical Gaps
1. **subprocess.TimeoutExpired** — 18 calls but no timeout exception tests
2. **subprocess.run() stderr parsing** — fw CLI errors not validated in detail
3. **Edge cases**: Large YAML files, corrupted JSON/YAML, missing directories
4. **Concurrent requests** — Flask thread safety for file I/O
5. **Search performance** — `grep` on large codebase with 200+ commits
6. **YAML injection** — Safe_load used, but no malformed YAML tests

### Recommended Tests (Priority)
1. **Timeout handling**: Mock subprocess timeouts for all fw CLI calls
2. **Error response parsing**: Validate error messages in HTML output
3. **Malformed YAML**: Test with corrupt assumptions.yaml, gaps.yaml, patterns.yaml
4. **File I/O edge cases**: Missing .context directories, empty task files
5. **Load testing**: Session timeline with 500+ handovers (emergency collapse)
6. **API idempotency**: Create task twice, update status twice (no side effects)
7. **Navigation**: All grouped nav items render correctly
8. **Accessibility**: ARIA labels, semantic HTML, color contrast

## 7. JavaScript

### Client-Side
- **htmx.min.js** (1 file, minified) — htmx library for SPA-like navigation
- No custom JavaScript in web/static/
- All interactivity via htmx attributes in HTML templates

### htmx Usage Pattern
```html
<!-- Example from tasks.html, cockpit.html, etc. -->
<button hx-post="/api/scan/refresh" hx-target="#cockpit">Refresh Scan</button>
<input hx-post="/api/task/create" hx-target="#task-response">
```

## 8. Dependencies (requirements.txt)

| Package | Version | Used For |
|---------|---------|----------|
| flask | >=3.0,<4.0 | Web framework, routing, templates |
| pyyaml | >=6.0 | YAML parsing (safe_load) |
| ruamel.yaml | >=0.18 | Alternative YAML parser (optional?) |
| markdown2 | >=2.4 | Project doc rendering, inception sections |
| bleach | >=6.0 | HTML sanitization (if used) |

**Test Dependencies** (inferred from test_app.py):
- pytest (imported, not in requirements.txt — add to dev requirements)

## 9. Security Considerations

### Protected
1. **CSRF** — Token on all POST/PATCH/PUT/DELETE (app.py lines 53-59)
2. **Path traversal** — `/project/<doc>` sanitizes with regex `^[A-Za-z0-9_-]+$`
3. **Task ID validation** — Regex `^T-\d{3}$` on all routes
4. **Assumption ID validation** — Regex `^A-\d{3}$`
5. **YAML parsing** — safe_load (not full_load)

### Risky
1. **subprocess.run() calls** — 18 total with user input (task name, description, tags, horizon)
   - Input sanitization: `strip()` only, no shell=True
   - Risk level: **LOW** (shell quoting unnecessary, subprocess.run uses list form)
2. **Search grep** — User query sanitized with `re_mod.sub(r"[^\w\s\-]", "", query)` (lines 123)
   - Risk level: **LOW**
3. **File I/O** — No write operations from web layer (fw CLI writes)
   - Risk level: **LOW**

## 10. Performance Hotspots

1. **Dashboard (/)** — Loads 6 different YAML files + runs git log (traceability %)
2. **Search (/search)** — Calls `grep -rn` with file count limit (50 files max)
3. **Timeline (/timeline)** — Emergency collapse algorithm runs on all handovers
4. **Task list (/tasks)** — Loads all active + completed + episodic (no pagination)
5. **Quality gate (/quality)** — git log --oneline -200 on every page load

### Optimization Candidates
- Cache traceability % (git log is slow on large repos)
- Paginate task list (board > 100 tasks is slow)
- Cache timeline emergency collapse result

## 11. Test Config

**test_app.py fixture setup:**
```python
@pytest.fixture
def client():
    app.config["TESTING"] = True
    app.config["SECRET_KEY"] = "test-secret-key"
    with app.test_client() as c:
        yield c

@pytest.fixture
def csrf_client(client):
    client.get("/")  # Populate session
    with client.session_transaction() as sess:
        token = sess.get("_csrf_token", "")
    return client, token
```

**No fixtures for:**
- Mock project root with fake tasks
- Pre-populated YAML files
- Mock subprocess calls
- Mock git commands

## Summary

**38 routes, 26 templates, 5,375 LOC**
- 794-line test suite covers happy paths + CSRF + validation
- Missing: timeout handling, error parsing, edge cases, load testing
- 18 subprocess calls (fw CLI + git) — low risk due to list-form subprocess.run
- 1 JavaScript file (htmx.min.js) — no custom code
- 5 dependencies (Flask, YAML, markdown, bleach)

