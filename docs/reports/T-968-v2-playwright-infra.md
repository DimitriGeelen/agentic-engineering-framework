# T-968: Playwright Test Infrastructure for Watchtower

## Context

Watchtower is a Flask/Jinja/htmx web UI (43 templates, ~70 routes, port 3000).
Existing test infrastructure:

- **Tier 1 (programmatic):** 127 bats tests (unit + integration), pytest `web/test_app.py` (Flask test client), `web/smoke_test.py` (route discovery + content markers)
- **Tier 2 (TermLink E2E):** 8 shell-based E2E tests via `tests/e2e/runner.sh`
- **Tier 3 (Playwright):** Nothing yet

The smoke test already validates HTTP 200 + content markers for all routes using Flask's test client. Playwright adds value for: JavaScript-dependent behavior (htmx navigation, dynamic forms, modals), visual regression, and cross-browser confidence.

## Decision: Python vs JavaScript

**Recommendation: Playwright Python (sync API)**

| Factor | Python | JavaScript/TypeScript |
|--------|--------|-----------------------|
| Language match | Flask/Python project | Requires Node.js ecosystem |
| Install | `pip install playwright` | `npm init`, `package.json`, `node_modules/` |
| Test runner | pytest (already used) | `npx playwright test` (new runner) |
| Config file | `conftest.py` (Python) | `playwright.config.ts` (TS) |
| CI complexity | `pip install` + `playwright install` | `npm ci` + `npx playwright install` |
| MCP plugin | Not applicable (MCP is interactive, not CI) | Same |
| Flask integration | Direct: import app, start in fixture | Subprocess: start server externally |
| Debugging | pdb, pytest -s | Playwright Inspector (richer but separate) |
| Community docs | Solid, slightly less than JS | Larger community |
| Codegen | `playwright codegen localhost:3000` | Same |

**Why Python wins for us:**
1. Zero new tooling — pytest is already used (`web/test_app.py`)
2. Flask test server can be started in a pytest fixture (no subprocess management)
3. Team already writes Python; cognitive load is lower
4. No `package.json` / `node_modules` pollution in a non-Node project
5. The sync API is sufficient — we don't need parallel browser contexts

## MCP Plugin vs Test Runner

The Playwright MCP plugin (`mcp__plugin_playwright_playwright__*`) is for **interactive exploration** — navigating pages, clicking buttons, inspecting state during development. It is NOT a test runner and cannot:
- Run test suites in CI
- Assert conditions programmatically
- Generate test reports
- Run headless in GitHub Actions

**Use the MCP plugin for:** writing tests interactively (explore the page, find selectors, validate behavior), then codify findings into pytest test files.

**Use `pytest` for:** running Playwright tests in CI, local `fw test` invocation, and regression suites.

## Proposed Directory Structure

```
tests/
  playwright/
    conftest.py          # Fixtures: browser, page, server startup/teardown
    test_navigation.py   # htmx navigation between pages
    test_tasks.py        # Task list, task detail, kanban
    test_fabric.py       # Fabric explorer, dependency graph
    test_search.py       # Search page, results rendering
    test_smoke.py        # Playwright version of smoke test (all routes render)
    test_review.py       # Review/approval UI, AC checkboxes
```

No config file needed — pytest + conftest.py handles everything.

## conftest.py — Server Fixture

```python
"""Playwright test fixtures for Watchtower."""
import subprocess
import time
import urllib.request
import urllib.error

import pytest
from playwright.sync_api import sync_playwright

# Use a non-conflicting port for test server
TEST_PORT = 3099
TEST_URL = f"http://localhost:{TEST_PORT}"


@pytest.fixture(scope="session")
def watchtower_server():
    """Start Watchtower in a subprocess for the test session."""
    env = {
        **__import__("os").environ,
        "FW_PORT": str(TEST_PORT),
        "FW_SECRET_KEY": "playwright-test-key",
        "FLASK_ENV": "testing",
    }
    proc = subprocess.Popen(
        ["python3", "web/app.py", "--port", str(TEST_PORT)],
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )

    # Wait for server ready (max 10s)
    for _ in range(20):
        try:
            urllib.request.urlopen(f"{TEST_URL}/health", timeout=1)
            break
        except (urllib.error.URLError, ConnectionRefusedError):
            time.sleep(0.5)
    else:
        proc.kill()
        raise RuntimeError(f"Watchtower failed to start on port {TEST_PORT}")

    yield proc

    proc.terminate()
    proc.wait(timeout=5)


@pytest.fixture(scope="session")
def browser_instance():
    """Single browser instance for the session."""
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        yield browser
        browser.close()


@pytest.fixture
def page(browser_instance, watchtower_server):
    """Fresh page (tab) for each test."""
    context = browser_instance.new_context()
    pg = context.new_page()
    yield pg
    context.close()
```

## Sample Test File

```python
"""tests/playwright/test_navigation.py — htmx navigation smoke tests."""
import re
from playwright.sync_api import Page, expect

TEST_URL = "http://localhost:3099"


def test_homepage_loads(page: Page):
    """Homepage renders with Watchtower branding."""
    page.goto(TEST_URL)
    expect(page).to_have_title(re.compile("Watchtower"))
    expect(page.locator("h1")).to_contain_text("Watchtower")


def test_tasks_page_loads(page: Page):
    """Tasks page renders with task list."""
    page.goto(f"{TEST_URL}/tasks")
    expect(page.locator("h1")).to_contain_text("Tasks")
    # Table or list of tasks should exist
    assert page.locator("table, .task-list, article").count() > 0


def test_htmx_navigation(page: Page):
    """Clicking a nav link loads content via htmx without full reload."""
    page.goto(TEST_URL)
    # Click the Tasks nav link
    page.click('a[href="/tasks"]')
    # htmx replaces content — wait for the new heading
    page.wait_for_selector("h1:has-text('Tasks')", timeout=3000)
    # URL should update (htmx pushUrl)
    assert "/tasks" in page.url


def test_fabric_page_loads(page: Page):
    """Fabric page renders with component data."""
    page.goto(f"{TEST_URL}/fabric")
    expect(page.locator("h1")).to_contain_text("Fabric")


def test_search_page_loads(page: Page):
    """Search page renders with search input."""
    page.goto(f"{TEST_URL}/search")
    expect(page.locator("input[type='search'], input[name='q']")).to_be_visible()


def test_health_endpoint(page: Page):
    """Health endpoint returns JSON."""
    page.goto(f"{TEST_URL}/health")
    content = page.text_content("body")
    assert '"app"' in content
```

## Installation

```bash
# One-time setup
pip install playwright pytest-playwright
playwright install chromium

# Run tests
pytest tests/playwright/ -v

# Run specific test
pytest tests/playwright/test_navigation.py::test_homepage_loads -v

# Run with headed browser (debugging)
pytest tests/playwright/ -v --headed

# Generate test code interactively
playwright codegen localhost:3000
```

**Dependencies to add to `web/requirements.txt` (or a separate `requirements-test.txt`):**
```
playwright>=1.40
pytest-playwright>=0.4
```

Note: `pytest-playwright` is optional — it provides built-in `page`, `browser`, `context` fixtures and CLI flags (`--headed`, `--browser`). If used, the `conftest.py` simplifies significantly (no manual browser/page fixtures needed). The custom server fixture is still required since pytest-playwright doesn't know about Flask.

### With pytest-playwright (simplified conftest.py)

```python
"""conftest.py — minimal version using pytest-playwright built-in fixtures."""
import subprocess
import time
import urllib.request
import urllib.error

import pytest

TEST_PORT = 3099
TEST_URL = f"http://localhost:{TEST_PORT}"


@pytest.fixture(scope="session")
def watchtower_server():
    """Start Watchtower for the test session."""
    env = {**__import__("os").environ, "FW_PORT": str(TEST_PORT)}
    proc = subprocess.Popen(
        ["python3", "web/app.py", "--port", str(TEST_PORT)],
        env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
    )
    for _ in range(20):
        try:
            urllib.request.urlopen(f"{TEST_URL}/health", timeout=1)
            break
        except (urllib.error.URLError, ConnectionRefusedError):
            time.sleep(0.5)
    else:
        proc.kill()
        raise RuntimeError("Watchtower failed to start")
    yield proc
    proc.terminate()
    proc.wait(timeout=5)


@pytest.fixture(autouse=True)
def _ensure_server(watchtower_server):
    """Auto-use: ensure server is running for every test."""
    pass
```

Tests then use pytest-playwright's built-in `page` fixture directly — no custom browser management.

## CI Integration — GitHub Actions

Add to `.github/workflows/test.yml`:

```yaml
  playwright:
    name: Playwright Tests (Tier 3)
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.12'

      - name: Install dependencies
        run: |
          pip install -r web/requirements.txt
          pip install playwright pytest-playwright
          playwright install --with-deps chromium

      - name: Run Playwright tests
        run: pytest tests/playwright/ -v --tracing retain-on-failure

      - name: Upload traces
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: playwright-traces
          path: test-results/
          retention-days: 7
```

Key CI notes:
- `playwright install --with-deps chromium` installs browser + OS-level dependencies (libgbm, libnss3, etc.)
- `--tracing retain-on-failure` saves Playwright traces for failed tests (viewable at trace.playwright.dev)
- Runs ~30s for a 10-test suite (most time is browser install, cached after first run)
- No display server needed — Chromium runs headless

## fw test Integration

Future `fw test` command should route tier-3 tests:

```bash
fw test                    # All tiers (bats + e2e + playwright)
fw test --tier 1           # bats only
fw test --tier 2           # TermLink E2E only  
fw test --tier 3           # Playwright only
fw test --tier 3 --headed  # Playwright with visible browser
```

Implementation: `fw test --tier 3` maps to `pytest tests/playwright/ -v`.

## Recommended Approach

1. **Start with pytest-playwright** — use the built-in fixtures, add only the server fixture
2. **5 initial test files** covering: navigation, tasks, fabric, search, smoke (all-routes)
3. **Port the smoke test** — `web/smoke_test.py` validates routes via HTTP; a Playwright version validates they actually render (DOM present, not just HTTP 200)
4. **Use MCP plugin for exploration** — when writing new tests, use the MCP Playwright tools to explore the page interactively, find selectors, then codify into test files
5. **CI on PR** — add the `playwright` job to the existing `test.yml` workflow
6. **No JavaScript tooling** — no `package.json`, no `npx`, no `playwright.config.ts`

### Effort Estimate

| Item | Work |
|------|------|
| `conftest.py` + first test file | ~1 hour |
| 5 test files (navigation, tasks, fabric, search, smoke) | ~2-3 hours |
| CI workflow update | ~30 min |
| `fw test --tier 3` routing | ~30 min |
| **Total** | **~4-5 hours** |

### What NOT to Do

- Don't use `npx playwright test` — it's the JS test runner, wrong ecosystem
- Don't create `playwright.config.ts` — pytest handles config via `conftest.py` and `pytest.ini`
- Don't install Firefox/WebKit in CI — Chromium is sufficient, saves 2+ minutes
- Don't run Playwright tests against Flask test client — Playwright needs a real HTTP server (htmx/JS won't execute without a browser)
- Don't put test files in `web/` — keep all tests in `tests/playwright/`
