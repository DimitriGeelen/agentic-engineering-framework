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
    proc = subprocess.Popen(
        ["python3", "-m", "web.app", "--port", str(TEST_PORT)],
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
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
        stdout, stderr = proc.communicate(timeout=5)
        raise RuntimeError(
            f"Watchtower failed to start on port {TEST_PORT}.\n"
            f"stdout: {stdout.decode()[:500]}\n"
            f"stderr: {stderr.decode()[:500]}"
        )

    yield proc

    proc.terminate()
    try:
        proc.wait(timeout=5)
    except subprocess.TimeoutExpired:
        proc.kill()
        proc.wait(timeout=3)


@pytest.fixture(scope="session")
def browser_instance():
    """Single Chromium browser instance for the test session."""
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        yield browser
        browser.close()


@pytest.fixture
def page(browser_instance, watchtower_server):
    """Fresh browser page for each test."""
    context = browser_instance.new_context()
    pg = context.new_page()
    yield pg
    context.close()


@pytest.fixture
def base_url():
    """Base URL for the test server."""
    return TEST_URL
