"""T-3200 — the continuous-run brake must be reachable without shell access.

The claim worth proving is NOT "a route exists and returns 200". It is that the
file the button writes is the file `stop-driver.sh` reads as Brake 1, and that
the driver actually yields on it. Those are different assertions, and only the
second one is the feature: a route that writes the wrong path returns 200 just
as cheerfully as one that writes the right path.

So every test below drives the REAL `agents/context/stop-driver.sh` as a
subprocess and asserts on its exit behaviour, not on the HTTP status.

The control legs (`test_touch_still_halts`, `test_resume_lets_an_armed_loop_continue`)
are load-bearing. "The button halts the loop" and "the loop never runs at all"
produce identical output from the halt test alone; only the paired assertion —
an armed loop DOES continue once the brake is released — tells them apart.
"""

import importlib
import subprocess
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
DRIVER = REPO_ROOT / "agents" / "context" / "stop-driver.sh"


def _build(tmp_path, monkeypatch, *, override):
    """Wire an isolated PROJECT_ROOT and return (client, root, halt_path).

    `override` picks WHICH resolution branch is under test. The two paths are
    deliberately DIFFERENT files — an earlier cut of this fixture pointed the
    override at the default location, which made the two branches produce the
    same path and left both inert: a mutant that wrote a parallel file, and a
    mutant that ignored the override entirely, each passed all seven tests.
    A fixture that cannot distinguish the branches cannot test either one.
    """
    working = tmp_path / ".context" / "working"
    working.mkdir(parents=True)
    (tmp_path / ".tasks" / "active").mkdir(parents=True)
    (tmp_path / ".tasks" / "completed").mkdir(parents=True)
    (tmp_path / ".framework.yaml").write_text(f"framework_path: {REPO_ROOT}\n")

    if override:
        halt = tmp_path / "elsewhere" / "custom-brake"
        halt.parent.mkdir(parents=True, exist_ok=True)
        monkeypatch.setenv("FW_CONTINUOUS_HALT", str(halt))
    else:
        halt = working / ".continuous-halt"
        monkeypatch.delenv("FW_CONTINUOUS_HALT", raising=False)
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))

    import web.shared
    import web.blueprints.approvals
    importlib.reload(web.shared)
    importlib.reload(web.blueprints.approvals)
    import web.app
    importlib.reload(web.app)
    app = web.app.create_app()
    app.config["TESTING"] = True

    # An ARMED loop, so "the driver yields" means the brake did it and not the
    # default disarmed state. Without this every test would pass vacuously.
    (working / ".continuous-mode.yaml").write_text(
        "enabled: true\nmax_iterations: 10\ncurrent_iteration: 1\n"
    )

    return app, halt


@pytest.fixture
def env(tmp_path, monkeypatch):
    """DEFAULT resolution — no FW_CONTINUOUS_HALT. This is the shape that ships."""
    app, halt = _build(tmp_path, monkeypatch, override=False)
    with app.test_client() as c:
        yield c, tmp_path, halt


@pytest.fixture
def env_override(tmp_path, monkeypatch):
    """OVERRIDE resolution — FW_CONTINUOUS_HALT pointing somewhere the default
    would never put it, so ignoring the override is detectable."""
    app, halt = _build(tmp_path, monkeypatch, override=True)
    with app.test_client() as c:
        yield c, tmp_path, halt


def _post(c, path):
    with c.session_transaction() as sess:
        sess["_csrf_token"] = "tok"
    return c.post(path, data={"_csrf_token": "tok"})


def _drive(tmp_path, halt):
    """Run the real Stop hook. Returns (yielded, log_text)."""
    proc = subprocess.run(
        ["bash", str(DRIVER)],
        input="{}",
        capture_output=True,
        text=True,
        env={
            "PATH": "/usr/bin:/bin",
            "HOME": str(tmp_path),
            "CLAUDE_PROJECT_DIR": str(tmp_path),
            # Mirror the branch under test: passing the override unconditionally
            # would make the driver agree with the route by construction, which
            # is exactly the agreement these tests are supposed to prove.
            **({"FW_CONTINUOUS_HALT": str(halt)} if halt.name == "custom-brake" else {}),
        },
        timeout=60,
    )
    log = tmp_path / ".context" / "working" / ".stop-driver.log"
    return proc.stdout.strip() == "{}", (log.read_text() if log.exists() else "")


# --- the feature ---------------------------------------------------------

def test_post_halt_writes_the_file_the_driver_reads(env):
    c, tmp_path, halt = env
    assert not halt.exists()

    resp = _post(c, "/api/continuous/halt")
    assert resp.status_code == 200

    # The path assertion is the one that matters: same file, not a parallel one.
    assert halt.exists(), "halt endpoint wrote nothing at the path the driver reads"

    yielded, log = _drive(tmp_path, halt)
    assert yielded, "driver did not stop despite the halt file existing"
    assert "halt-file present" in log, (
        "driver stopped, but not because of the halt — this test would pass "
        "vacuously on a disarmed loop, so the reason is asserted, not just the exit"
    )


def test_post_resume_removes_it(env):
    c, tmp_path, halt = env
    _post(c, "/api/continuous/halt")
    assert halt.exists()

    resp = _post(c, "/api/continuous/resume")
    assert resp.status_code == 200
    assert not halt.exists()


# --- control legs --------------------------------------------------------

def test_resume_lets_an_armed_loop_continue(env):
    """THE control. Without this, 'halt works' is indistinguishable from
    'the loop never continues anyway'."""
    c, tmp_path, halt = env
    _post(c, "/api/continuous/halt")
    _post(c, "/api/continuous/resume")

    yielded, log = _drive(tmp_path, halt)
    assert not yielded, (
        "armed loop still stopped after the brake was released — the halt test "
        "above would pass either way, which is why this assertion exists"
    )
    assert "halt-file present" not in log


def test_touch_still_halts(env):
    """The shell path must not become conditional on the web writer."""
    c, tmp_path, halt = env
    halt.write_text("")  # exactly what `touch` produces

    yielded, log = _drive(tmp_path, halt)
    assert yielded
    assert "halt-file present" in log


# --- posture -------------------------------------------------------------

def test_halt_requires_csrf(env):
    """Same posture as every other mutating route here — no bespoke auth."""
    c, tmp_path, halt = env
    resp = c.post("/api/continuous/halt")  # no token
    assert resp.status_code == 403
    assert not halt.exists()


def test_resume_requires_csrf(env):
    c, tmp_path, halt = env
    halt.write_text("")
    resp = c.post("/api/continuous/resume")
    assert resp.status_code == 403
    assert halt.exists(), "brake was released by an unauthenticated request"


# --- the page surface ----------------------------------------------------

def test_approvals_page_shows_state_both_ways(env):
    c, tmp_path, halt = env

    running = c.get("/approvals").get_data(as_text=True)
    assert "RUNNING" in running
    assert "/api/continuous/halt" in running

    _post(c, "/api/continuous/halt")
    halted = c.get("/approvals").get_data(as_text=True)
    assert "HALTED" in halted
    assert "/api/continuous/resume" in halted, (
        "no release affordance while halted — a brake with no release is one "
        "nobody dares use"
    )


# --- resolution parity ---------------------------------------------------

def test_override_is_honoured_and_the_driver_agrees(env_override):
    """AC2. The route and stop-driver.sh:60 must resolve the SAME rule.

    An operator who has set FW_CONTINUOUS_HALT and gets a button writing the
    default path has a brake that reports success and does nothing — the worst
    available outcome, strictly worse than no button.
    """
    c, tmp_path, halt = env_override
    default = tmp_path / ".context" / "working" / ".continuous-halt"
    assert halt != default, "fixture must exercise a distinguishable path"

    _post(c, "/api/continuous/halt")

    assert halt.exists(), "override ignored — wrote to the default instead"
    assert not default.exists(), "wrote the default path despite an override"

    yielded, log = _drive(tmp_path, halt)
    assert yielded and "halt-file present" in log
