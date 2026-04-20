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


@pytest.fixture(scope="session")
def watchtower_server():
    """Start Watchtower in a subprocess for the test session."""
    # Check if already running on test port
    try:
        urllib.request.urlopen(f"{TEST_URL}/health", timeout=5)
        yield None  # Server already running, don't manage it
        return
    except urllib.error.HTTPError:
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
    pg.set_default_navigation_timeout(15_000)  # 15s for page.goto
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
