"""T-4070: Watchtower's toggle-ac endpoint writes the Human-tick provenance row.

Everything runs in a temp git repo with its own task file and ledger; the real
task files and ledger are never touched.
"""
import subprocess
import sys
from pathlib import Path

import pytest
from flask import Flask

FRAMEWORK_ROOT = Path(__file__).resolve().parents[2]
if str(FRAMEWORK_ROOT) not in sys.path:
    sys.path.insert(0, str(FRAMEWORK_ROOT))

from lib import human_ac_ticks  # noqa: E402
from web.blueprints import tasks as tasks_bp  # noqa: E402

TASK = """---
id: T-9001
name: fixture
status: started-work
---

# T-9001

## Acceptance Criteria

### Agent
- [ ] Agent criterion

### Human
- [ ] [REVIEW] Human criterion
  **Steps:** look
  **Expected:** fine

## Verification
"""


def git(root, *args):
    subprocess.run(["git", "-C", str(root), "-c", "user.name=Operator",
                    "-c", "user.email=op@example.com", *args],
                   check=True, capture_output=True)


@pytest.fixture
def repo(tmp_path, monkeypatch):
    root = tmp_path
    (root / ".tasks" / "active").mkdir(parents=True)
    tf = root / ".tasks" / "active" / "T-9001-fixture.md"
    tf.write_text(TASK)
    git(root, "init", "-q")
    git(root, "add", "-A")
    git(root, "commit", "-q", "-m", "T-9001: seed")
    monkeypatch.setattr(tasks_bp, "PROJECT_ROOT", root)
    app = Flask(__name__)
    app.register_blueprint(tasks_bp.bp)
    return root, tf, app.test_client()


def line_of(tf, needle):
    body = tf.read_text().split("---\n", 2)[2]
    return next(i for i, ln in enumerate(body.split("\n")) if needle in ln)


def commit_and_audit(root):
    git(root, "add", "-A")
    git(root, "commit", "-q", "-m", "T-9001: tick")
    return human_ac_ticks.audit(root)


def ledger(root):
    return human_ac_ticks.ledger_rows(root)


def test_human_tick_writes_row_and_passes_detector(repo):
    root, tf, client = repo
    r = client.post("/api/task/T-9001/toggle-ac", data={"line": line_of(tf, "Human criterion")},
                    headers={"X-Request-Id": "req-1"}, environ_base={"REMOTE_ADDR": "10.0.0.7"})
    assert r.status_code == 200 and "checked" in r.get_data(as_text=True)
    rows = ledger(root)
    assert len(rows) == 1
    assert rows[0]["via"] == "watchtower" and rows[0]["task"] == "T-9001"
    assert rows[0]["request_id"] == "req-1" and rows[0]["remote_addr"] == "10.0.0.7"
    rc, lines = commit_and_audit(root)
    assert rc == 0, lines


def test_without_row_the_detector_fails(repo):
    """Control: the same tick with no ledger row is the pre-fix state and FAILs."""
    root, tf, _ = repo
    ok, new_state, _ = tasks_bp._toggle_ac_line(tf, line_of(tf, "Human criterion"))
    assert ok and new_state
    rc, lines = commit_and_audit(root)
    assert rc == 2 and "T-9001" in lines[0]


def test_agent_toggle_writes_no_row(repo):
    root, tf, client = repo
    r = client.post("/api/task/T-9001/toggle-ac", data={"line": line_of(tf, "Agent criterion")})
    assert r.status_code == 200
    assert "- [x] Agent criterion" in tf.read_text()
    assert ledger(root) == []


def test_untick_writes_no_row(repo):
    root, tf, client = repo
    idx = line_of(tf, "Human criterion")
    client.post("/api/task/T-9001/toggle-ac", data={"line": idx})
    client.post("/api/task/T-9001/toggle-ac", data={"line": idx})
    assert "- [ ] [REVIEW] Human criterion" in tf.read_text()
    assert len(ledger(root)) == 1


def test_ledger_write_failure_refuses_the_tick(repo, monkeypatch):
    root, tf, client = repo
    before = tf.read_text()

    def boom(*a, **k):
        raise OSError("disk full")

    monkeypatch.setattr(human_ac_ticks, "record", boom)
    r = client.post("/api/task/T-9001/toggle-ac", data={"line": line_of(tf, "Human criterion")})
    assert r.status_code == 500 and "Tick refused" in r.get_data(as_text=True)
    assert tf.read_text() == before
    assert ledger(root) == []
