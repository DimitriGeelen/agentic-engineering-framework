---
id: T-1823
name: "web/test_app.py consumer-vs-framework data-shape bleed — 5-7 tests assume framework-repo state"
description: >
  FB-B (MEDIUM) reported independently by penelope (050-email-archive), claude-002-cpn (002-CPN), termlink-agent (010-termlink) on 2026-05-13/14. web/test_app.py contains 5-7 tests that assert framework-repo fixture data (G-001 in /gaps, '001-Vision' in /project, 'Watchtower v' prefix in footer, 'System Health' heading) which consumers cannot satisfy. fw doctor SKIPs 'Test infrastructure (consumer project — tests live in framework repo)' but fw test all runs them anyway — inconsistent intent. Suggested fix (consistent across reporters): add @pytest.mark.framework_repo and auto-skip when .framework.yaml exists at PROJECT_ROOT (i.e. running in consumer mode). OR have fw test all honor the same consumer-skip the doctor uses. Affected tests: TestErrorHandlers::test_404_for_nonexistent_task, TestDataIntegrity::test_gaps_page_shows_gaps, TestDataIntegrity::test_project_page_lists_docs, TestDataIntegrity::test_project_doc_renders_markdown, TestPhase3Integration::test_dashboard_has_system_health, TestNavigation::test_footer_shows_watchtower, TestEmptyTaskFiles::test_task_file_no_frontmatter, TestEmptyTaskFiles::test_task_file_empty.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [test-infra, fw-upgrade-incident-2026-05-14, bug]
components: []
related_tasks: [T-1822, T-1634]
arc_id: project-shape-resilience
created: 2026-05-14T07:30:49Z
last_update: 2026-05-14T14:22:11Z
date_finished: 2026-05-14T14:22:11Z
---

# T-1823: web/test_app.py consumer-vs-framework data-shape bleed — 5-7 tests assume framework-repo state

## Context

FB-B reported independently by penelope, claude-002-cpn, termlink-agent. `web/test_app.py` contains tests that assume framework-repo fixture data ("G-001 in /gaps", "001-Vision in /project", "Watchtower v" footer, "System Health" heading). On a consumer project these assertions can't be satisfied — the consumer's gaps/project/dashboard look different. `fw doctor` already SKIPs the test-infrastructure check on consumers, but `fw test all` runs the tests anyway, causing red CI for every consumer. Aligning the two surfaces requires a per-test marker so individual tests can declare "framework-repo only" and auto-skip elsewhere, plus a conftest-level fixture that detects consumer mode.

## Acceptance Criteria

### Agent
- [x] `web/conftest.py` defines a `framework_repo` marker and registers it via `pytest_configure` (silences PytestUnknownMarkWarning). `_is_consumer_mode()` mirrors `bin/fw` Check 9 — FRAMEWORK_ROOT vs PROJECT_ROOT realpath comparison.
- [x] Auto-skip mechanism: `pytest_collection_modifyitems` hook adds skip marker to all `framework_repo`-tagged tests when `_is_consumer_mode()` returns True.
- [x] 8 framework-repo-only tests in `web/test_app.py` got the `@pytest.mark.framework_repo` marker: TestErrorHandlers::test_404_for_nonexistent_task, TestDataIntegrity::test_gaps_page_shows_gaps + test_project_page_lists_docs + test_project_doc_renders_markdown, TestPhase3Integration::test_dashboard_has_system_health, TestNavigation::test_footer_shows_watchtower, TestEmptyTaskFiles::test_task_file_no_frontmatter + test_task_file_empty.
- [x] In framework-repo mode (current host), all 8 marker'd tests PASS — `python3 -m pytest web/test_app.py -k "..." -v` → 8 passed.
- [x] In simulated consumer mode (FRAMEWORK_ROOT=this repo, PROJECT_ROOT=tmpdir with .framework.yaml), all 8 marker'd tests SKIP — `python3 -m pytest web/test_app.py -k "..." -v` → 8 skipped.
- [x] No existing test loses coverage: full suite still 145/145 PASSED in framework-repo mode, non-marked tests run normally on consumer mode (verified test_csrf_via_header, test_404_for_invalid_task_id still PASS under simulated consumer).

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

test -f web/conftest.py
grep -q "framework_repo" web/conftest.py
grep -q "pytest_collection_modifyitems" web/conftest.py
bash -c '[ "$(grep -c "@pytest.mark.framework_repo" web/test_app.py)" -eq 8 ]'
bash -c 'out=$(python3 -m pytest web/test_app.py -k "test_404_for_nonexistent_task or test_gaps_page_shows_gaps or test_project_page_lists_docs or test_project_doc_renders_markdown or test_footer_shows_watchtower or test_dashboard_has_system_health or test_task_file_no_frontmatter or test_task_file_empty" 2>&1); echo "$out" | grep -qE "8 passed"'
bash -c 'td=$(mktemp -d); touch "$td/.framework.yaml"; out=$(FRAMEWORK_ROOT=/opt/999-Agentic-Engineering-Framework PROJECT_ROOT="$td" python3 -m pytest web/test_app.py -k "test_gaps_page_shows_gaps or test_project_page_lists_docs or test_project_doc_renders_markdown or test_footer_shows_watchtower or test_dashboard_has_system_health or test_404_for_nonexistent_task or test_task_file_no_frontmatter or test_task_file_empty" 2>&1); rm -rf "$td"; echo "$out" | grep -qE "8 skipped"'

## RCA

**Symptom:** Every consumer running `fw test web` (or `fw test all`) saw 6-8 red tests asserting framework-repo-specific data ("G-001 in /gaps", "001-Vision doc", "Watchtower v" footer, "System Health" heading). Reported independently by 3 agents (penelope, claude-002-cpn, termlink-agent) within 24 hours.

**Root cause:** `web/test_app.py` was written by-and-for framework-repo development. Some assertions are universal (HTTP 200 on routes), but ~8 tests bind to specific framework-repo content. The test suite has no per-test mode marker — every consumer that vendors the framework runs the full suite, even when the fixture data is meaningless on their project.

**Why structurally allowed:**
1. `fw doctor` Check 9 already SKIPs "Test infrastructure" on consumers via FRAMEWORK_ROOT vs PROJECT_ROOT, but `fw test web` doesn't honor the same heuristic.
2. No pytest marker existed for "this test is framework-repo only" — so tests that conceptually couldn't pass on consumers had no way to declare it.
3. The framework's own CI is framework-repo-only, so the bug never surfaced in upstream test runs. Only consumers hit it — and each one independently.

**Prevention:**
1. `web/conftest.py` introduces the `framework_repo` marker + `pytest_collection_modifyitems` auto-skip on consumer mode (this task).
2. Convention now established: any new framework-repo-data-dependent test should be marked `@pytest.mark.framework_repo`. Documented in the conftest module docstring.
3. Learning candidate: "Test infrastructure SKIP heuristics in doctor must mirror in pytest. The two surfaces are advisory vs operational — they must agree on consumer mode or one is lying." File as L-entry referencing T-574 (origin of the doctor split).

## Evolution

### 2026-05-14 — marker-based opt-in over fw-test-web-side filter
- **What changed:** Two implementation shapes considered: (A) make `fw test web` parse args and add `--ignore=...` or `-k 'not framework_repo'` when consumer-mode is detected; (B) move the consumer-detect logic into `web/conftest.py` so any `pytest`-driven invocation honors it (including direct pytest, IDE test runners, CI). Chose (B): the conftest approach is invocation-path-independent and doesn't require all consumers to upgrade `fw` to a newer version.
- **Plan impact:** Zero changes to `bin/fw test web` block — same command works on framework-repo and consumers, with different behavior. `fw doctor` Check 9 SKIP heuristic now aligns with `fw test web` behavior (both via FRAMEWORK_ROOT != PROJECT_ROOT).
- **Triggered:** None. Implementation followed directly from the marker-based approach.

### 2026-05-14 — env-var driven consumer-mode (no path walking from conftest)
- **What changed:** Initial impulse: have `_is_consumer_mode()` walk up from cwd looking for `.framework.yaml`. Realised this is brittle — pytest may be run from anywhere, especially from CI runners that cd to an isolated workspace. The `fw` shim already exports FRAMEWORK_ROOT + PROJECT_ROOT on every invocation, so reading those is both simpler AND more reliable.
- **Plan impact:** Fallback for "neither env var set" treats as framework-repo (local hacking case); explicit env-set is the only path to consumer-mode skip. This matches user expectation: nobody running pytest manually in the framework repo wants their tests silently skipped.

## Updates

### 2026-05-14T07:30:49Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1823-webtestapppy-consumer-vs-framework-data-.md
- **Context:** Initial task creation

### 2026-05-14T14:11:03Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f2002499
- **Timestamp:** 2026-06-02T14:59:51Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** yes
- **Findings:** none

- **Layer-1 escalations:** 1
  1. **destructive-action** (high) — Destructive operation in verification or AC
     - matched: `rm -rf`
### 2026-05-14T14:22:11Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
