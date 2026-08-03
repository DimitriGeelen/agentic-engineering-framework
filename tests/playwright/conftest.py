"""Playwright test fixtures for Watchtower (T-969).

Provides:
- watchtower_server: starts Watchtower on TEST_PORT, tears down after session
- browser_instance: single Chromium browser for the session
- page: fresh browser page (tab) for each test
"""
import os
import subprocess
import time
import urllib.request
import urllib.error

import pytest
from playwright.sync_api import sync_playwright

TEST_PORT = int(os.environ.get("FW_TEST_PORT", "3099"))
TEST_URL = f"http://localhost:{TEST_PORT}"


def _warm_slow_routes():
    """T-2104: pre-hit slow-aggregation routes so subsequent page.goto calls
    don't time out on cold-start latency. See T-2104 task body for rationale."""
    for route in ("/approvals", "/inception", "/tasks", "/timeline", "/bvp"):
        try:
            urllib.request.urlopen(f"{TEST_URL}{route}", timeout=30)
        except (urllib.error.URLError, urllib.error.HTTPError, OSError):
            pass


@pytest.fixture(scope="session")
def watchtower_server():
    """Start Watchtower in a subprocess for the test session."""
    # Check if already running on test port
    try:
        urllib.request.urlopen(f"{TEST_URL}/health", timeout=5)
        _warm_slow_routes()  # T-2104: warm even if reusing an existing server
        yield None  # Server already running, don't manage it
        return
    except urllib.error.HTTPError:
        _warm_slow_routes()  # T-2104
        yield None  # Server is up (503 = Ollama unreachable but app healthy)
        return
    except (urllib.error.URLError, ConnectionRefusedError, OSError):
        pass

    project_root = os.environ.get(
        "PROJECT_ROOT",
        os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    )
    env = {
        **os.environ,
        "FW_PORT": str(TEST_PORT),
        "FLASK_ENV": "testing",
    }
    # Use DEVNULL for stdout/stderr to prevent pipe buffer deadlock.
    # Flask logs every request to stderr; after ~150 requests the 64KB
    # pipe buffer fills and the server blocks, causing all tests to timeout.
    stderr_file = "/tmp/watchtower-test-stderr.log"
    stderr_fh = open(stderr_file, "w")
    proc = subprocess.Popen(
        ["python3", "-m", "web.app", "--port", str(TEST_PORT)],
        env=env,
        stdout=subprocess.DEVNULL,
        stderr=stderr_fh,
        cwd=project_root,
    )

    # Wait for server ready (max 15s)
    for _ in range(30):
        try:
            urllib.request.urlopen(f"{TEST_URL}/health", timeout=2)
            break
        except urllib.error.HTTPError:
            break  # Server is up (503 = Ollama unreachable, app is still healthy)
        except (urllib.error.URLError, ConnectionRefusedError, OSError):
            time.sleep(0.5)
    else:
        proc.kill()
        proc.wait(timeout=5)
        stderr_fh.close()
        stderr_content = open(stderr_file).read()[:500]
        raise RuntimeError(
            f"Watchtower failed to start on port {TEST_PORT}.\n"
            f"stderr: {stderr_content}"
        )

    # T-2104: warm up slow-aggregation routes before tests run.
    # Cold-start latency on /approvals (6-15s), /timeline (~8s), /tasks (~7s)
    # otherwise exceeds the 15s page.goto navigation timeout (set on the page
    # fixture) and masks real height/content regressions as TimeoutError. The
    # body / frontmatter / episodic caches (T-1954, T-2083, T-2102) are
    # process-local; a fresh subprocess starts cold every test session.
    _warm_slow_routes()

    yield proc

    proc.terminate()
    try:
        proc.wait(timeout=5)
    except subprocess.TimeoutExpired:
        proc.kill()
        proc.wait(timeout=3)
    stderr_fh.close()


@pytest.fixture(scope="session")
def browser_instance():
    """Single Chromium browser instance for the test session."""
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        yield browser
        browser.close()


@pytest.fixture
def page(browser_instance, watchtower_server):
    """Fresh browser page for each test.

    Primes the session with a CSRF token (T-1343 / G-048): since `/api/*`
    blanket CSRF exemption was removed, tests POSTing to /api need
    `X-CSRF-Token`. The fixture navigates to `/` first (sets the session
    cookie + reads the meta token) then sets it as a default header on
    the browser context, so `page.request.post(...)` calls work without
    per-test boilerplate.
    """
    context = browser_instance.new_context()
    pg = context.new_page()
    pg.set_default_timeout(10_000)  # 10s instead of 30s default
    # T-2774: navigation budget is deliberately far above the 5s LOAD_CAP_MS that
    # test_all_routes_load_time.py enforces. The two numbers do different jobs and
    # the gap between them is the point.
    #
    # The load cap is the *assertion* about latency: it fails with "route X took
    # 8213ms > 5000ms", which names the problem. The navigation timeout is only a
    # backstop against a genuinely hung page. When it sat at 15s it was doing both
    # jobs badly — a route between 15s and healthy died as `TimeoutError` inside
    # `page.goto`, before any assertion ran, so every test touching that route
    # failed with an error that says nothing about *why*. Worse, it reads as
    # flaky: the same route passes whenever a warm cache puts it under 15s, so the
    # signal looks like test infrastructure noise rather than a slow page.
    #
    # That is the failure mode T-1960/T-1961 hit, and it is what sent an earlier
    # diagnosis chasing an imaginary loopback block — a timeout is "did not answer
    # inside my budget", not "is broken", and conflating the two cost real time.
    # With the backstop at 45s, a slow-but-working route now loads and fails the
    # load-cap assertion by name; only a truly hung page hits the timeout.
    pg.set_default_navigation_timeout(int(os.environ.get("FW_TEST_NAV_TIMEOUT_MS", "45000")))
    try:
        pg.goto(TEST_URL + "/", wait_until="domcontentloaded")
        token = pg.evaluate(
            "() => document.querySelector('meta[name=\"csrf-token\"]')"
            "?.getAttribute('content') || ''"
        )
        if token:
            context.set_extra_http_headers({"X-CSRF-Token": token})
    except Exception:
        pass  # Best-effort; tests that need CSRF will fail loudly on 403
    yield pg
    context.close()


@pytest.fixture
def base_url():
    """Base URL for the test server."""
    return TEST_URL


# --- Timing report hook ---

_test_durations = []


@pytest.hookimpl(hookwrapper=True)
def pytest_runtest_makereport(item, call):
    """Record test duration for slow test reporting."""
    outcome = yield
    report = outcome.get_result()
    if report.when == "call":
        _test_durations.append((item.nodeid, report.duration))


def pytest_terminal_summary(terminalreporter, config):
    """Print the 10 slowest tests at session end."""
    if not _test_durations:
        return
    terminalreporter.section("slowest 10 tests")
    for nodeid, duration in sorted(_test_durations, key=lambda x: -x[1])[:10]:
        terminalreporter.write_line(f"  {duration:6.2f}s  {nodeid}")
