"""Playwright test fixtures for Watchtower (T-969).

Provides:
- watchtower_server: starts Watchtower on TEST_PORT, tears down after session
- browser_instance: single Chromium browser for the session
- page: fresh browser page (tab) for each test
"""
import datetime
import json
import os
import signal
import subprocess
import time
import urllib.request
import urllib.error

import pytest
from playwright.sync_api import sync_playwright

TEST_PORT = int(os.environ.get("FW_TEST_PORT", "3099"))
TEST_URL = f"http://localhost:{TEST_PORT}"

# T-2782: how old an already-listening server may be before this fixture recycles it
# instead of adopting it. An adopted server is unmanaged — nothing tears it down between
# sessions — so without a bound it accumulates indefinitely. T-2777 measured one that had
# been up since the previous day at 656MB RSS / 66min CPU, serving routes in 13-16s that a
# fresh instance served in under 3s, and that reading was initially diagnosed as host
# contention rather than as a degraded fixture.
MAX_ADOPT_AGE_S = int(os.environ.get("FW_TEST_SERVER_MAX_AGE_S", "3600"))


def _warm_slow_routes():
    """T-2104: pre-hit slow-aggregation routes so subsequent page.goto calls
    don't time out on cold-start latency. See T-2104 task body for rationale."""
    for route in ("/approvals", "/inception", "/tasks", "/timeline", "/bvp"):
        try:
            urllib.request.urlopen(f"{TEST_URL}{route}", timeout=30)
        except (urllib.error.URLError, urllib.error.HTTPError, OSError):
            pass


def _probe_identity(timeout=5):
    """Identity of whatever is listening on TEST_PORT, or None if nothing answers.

    Deliberately `/api/_identity` (T-1284) rather than `/health`. `/health` answers
    "something is listening"; only identity answers "the right thing is listening", and
    the gap between those two questions is the framework's own documented false-green
    (CLAUDE.md §Watchtower Port: 371 verification lines asserted against a *different
    project's* Watchtower on :3000 and passed, because every consumer project runs the
    same Flask app).
    """
    try:
        with urllib.request.urlopen(f"{TEST_URL}/api/_identity", timeout=timeout) as resp:
            return json.loads(resp.read().decode())
    except (urllib.error.URLError, urllib.error.HTTPError,
            ConnectionRefusedError, OSError, ValueError):
        return None


def _port_occupied(timeout=1):
    """Whether anything at all holds TEST_PORT, identifiable or not.

    Distinct from `_probe_identity() is not None`: a non-Watchtower listener answers the
    socket but not `/api/_identity`, and conflating "silent" with "absent" sends the
    fixture down the start path to fail on bind with "Watchtower failed to start" — an
    error about the wrong thing entirely.
    """
    import socket
    with socket.socket() as sock:
        sock.settimeout(timeout)
        return sock.connect_ex(("localhost", TEST_PORT)) == 0


def _server_age_s(ident, now=None):
    """Seconds since the listening server started, or None if it won't say."""
    started = (ident or {}).get("started_at")
    if not started:
        return None
    try:
        ts = datetime.datetime.fromisoformat(started)
    except ValueError:
        return None
    if ts.tzinfo is None:
        ts = ts.replace(tzinfo=datetime.timezone.utc)
    now = now or datetime.datetime.now(datetime.timezone.utc)
    return (now - ts).total_seconds()


def _adoption_decision(ident, expected_root, max_age_s=MAX_ADOPT_AGE_S, now=None,
                       port_occupied=False):
    """Decide what to do about a server already listening on the test port.

    Returns ``(action, reason)`` where action is one of:

      ``"start"``   — nothing is listening; start our own.
      ``"adopt"``   — it is our Watchtower for this project and young enough to trust.
      ``"recycle"`` — it is ours but too old; terminate it and start fresh.
      ``"reject"``  — it is not ours, or won't identify itself. Fail loudly.

    Pure so the three interesting branches are testable without spawning servers: the
    bug this replaces was never that the reuse *code* was wrong, it was that reuse had
    no decision to make. A branch with no alternatives cannot be tested for taking the
    wrong one.
    """
    if ident is None:
        if port_occupied:
            return "reject", (
                f"port {TEST_PORT} is held by something that does not answer "
                "/api/_identity. It is not a Watchtower this fixture can verify, and "
                "starting our own would fail on bind with an error about the wrong "
                "thing. Free the port, or point FW_TEST_PORT elsewhere."
            )
        return "start", "nothing listening on the test port"

    if ident.get("service") != "watchtower":
        return "reject", (
            f"something is listening on port {TEST_PORT} but does not identify as a "
            f"Watchtower (service={ident.get('service')!r})"
        )

    actual_root = os.path.realpath(str(ident.get("project_root", "")))
    if actual_root != os.path.realpath(expected_root):
        return "reject", (
            f"port {TEST_PORT} is serving a DIFFERENT project.\n"
            f"  listening server PROJECT_ROOT: {actual_root}\n"
            f"  this test run's PROJECT_ROOT:  {os.path.realpath(expected_root)}\n"
            "Every consumer project runs the same Flask app, so this server will answer "
            "every route and pass every assertion — about the wrong corpus."
        )

    age = _server_age_s(ident, now=now)
    if age is None:
        return "reject", "server will not report started_at — cannot bound its staleness"
    if age > max_age_s:
        return "recycle", f"server has been up {age / 3600:.1f}h (bound {max_age_s / 3600:.1f}h)"
    return "adopt", f"server is ours and {age / 60:.0f}min old"


def _live_watchtower_port(project_root):
    """The port the operator's own Watchtower is on, per the triple-file source of truth.

    Used only to refuse recycling it. Recycling is correct for a *test* server on 3099;
    doing it to a live session because someone set FW_TEST_PORT to the real port is the
    accident CLAUDE.md §Watchtower Port exists to prevent.
    """
    try:
        with open(os.path.join(project_root, ".context", "working", "watchtower.port")) as fh:
            return int(fh.read().strip())
    except (OSError, ValueError):
        return None


def _recycle(ident, project_root):
    """Terminate an adopted-but-stale server and wait for the port to free."""
    if _live_watchtower_port(project_root) == TEST_PORT:
        raise RuntimeError(
            f"refusing to recycle: FW_TEST_PORT={TEST_PORT} is this project's LIVE "
            "Watchtower port, not a test port. Point FW_TEST_PORT at a scratch port "
            "(default 3099) rather than having the suite kill the operator's session."
        )
    pid = ident.get("pid")
    if not pid:
        raise RuntimeError(
            f"server on port {TEST_PORT} is stale but reports no pid, so it cannot be "
            "recycled. Kill it by hand, or raise FW_TEST_SERVER_MAX_AGE_S to adopt it "
            "knowingly."
        )
    os.kill(int(pid), signal.SIGTERM)
    for _ in range(20):
        if _probe_identity(timeout=1) is None:
            return
        time.sleep(0.5)
    os.kill(int(pid), signal.SIGKILL)
    time.sleep(1)


@pytest.fixture(scope="session")
def watchtower_server():
    """Start Watchtower in a subprocess for the test session."""
    project_root = os.environ.get(
        "PROJECT_ROOT",
        os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    )

    # T-2782: decide about an already-listening server rather than adopting it blind.
    # Whichever path is taken is printed, so a reading can be attributed to the server
    # that produced it instead of re-diagnosed from scratch next session.
    ident = _probe_identity()
    action, reason = _adoption_decision(
        ident, project_root, port_occupied=(ident is None and _port_occupied())
    )
    print(f"\n[watchtower_server] {action}: {reason}")

    if action == "reject":
        raise RuntimeError(f"refusing to run against port {TEST_PORT} — {reason}")
    if action == "adopt":
        _warm_slow_routes()  # T-2104: warm even if reusing an existing server
        yield None  # Server already running, don't manage it
        return
    if action == "recycle":
        _recycle(ident, project_root)
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
def base_url(watchtower_server):
    """Base URL for the test server.

    T-2782: depends on `watchtower_server` deliberately. Without it this fixture handed
    out a URL and let the test discover for itself whether anything was there — so a
    suite whose tests take only `base_url` (test_all_routes_size.py) never started a
    server at all and silently measured whatever already held the port. Every run of it
    to date was measuring the operator's live Watchtower rather than a test instance.

    A URL is not a server. Anything that gets the URL from here now also gets the
    identity check and the staleness bound that come with starting one.
    """
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
