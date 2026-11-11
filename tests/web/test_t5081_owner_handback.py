"""T-5081 (832 proposal, operator decision 2026-11-11): the operator's tick of the last open
Human criterion in Watchtower hands the task back to the agent, the same rule a reviewer's
green applies; unticking a Human box on a task waiting for review hands it back to the
operator. Temp git repo only, like test_t4070; no real task file is touched."""
import subprocess
import sys
from pathlib import Path

import pytest
from flask import Flask

FRAMEWORK_ROOT = Path(__file__).resolve().parents[2]
if str(FRAMEWORK_ROOT) not in sys.path:
    sys.path.insert(0, str(FRAMEWORK_ROOT))

from lib import delegation  # noqa: E402
from lib import human_ac_ticks  # noqa: E402
from web.blueprints import tasks as tasks_bp  # noqa: E402

TASK = """---
id: T-9002
name: fixture
status: work-completed
owner: human
---

# T-9002

## Acceptance Criteria

### Agent
- [x] Agent criterion

### Human
- [ ] [REVIEW] First human check
  **Steps:** look
  **Expected:** fine
- [ ] [REVIEW] Second human check
  **Steps:** look
  **Expected:** fine

## Verification
"""


def git(root, *args):
    subprocess.run(["git", "-C", str(root), "-c", "user.name=Operator",
                    "-c", "user.email=op@example.com", *args], check=True, capture_output=True)


@pytest.fixture
def repo(tmp_path, monkeypatch):
    root = tmp_path
    (root / ".tasks" / "active").mkdir(parents=True)
    tf = root / ".tasks" / "active" / "T-9002-fixture.md"
    tf.write_text(TASK)
    git(root, "init", "-q")
    git(root, "add", "-A")
    git(root, "commit", "-q", "-m", "T-9002: seed")
    monkeypatch.setattr(tasks_bp, "PROJECT_ROOT", root)
    app = Flask(__name__)
    app.register_blueprint(tasks_bp.bp)
    return root, tf, app.test_client()


def line_of(tf, needle):
    body = tf.read_text().split("---\n", 2)[2]
    return next(i for i, ln in enumerate(body.split("\n")) if needle in ln)


def tick(client, tf, needle):
    return client.post("/api/task/T-9002/toggle-ac", data={"line": line_of(tf, needle)})


def owner(tf):
    return delegation.frontmatter(tf.read_text()).get("owner")


def test_ticking_one_of_two_changes_nothing(repo):
    _, tf, client = repo
    r = tick(client, tf, "First human check")
    assert r.status_code == 200
    assert owner(tf) == "human"


def test_ticking_the_last_open_human_box_hands_back_to_agent(repo):
    _, tf, client = repo
    tick(client, tf, "First human check")
    r = tick(client, tf, "Second human check")
    assert r.status_code == 200
    assert owner(tf) == "agent"
    assert "handed back to the agent" in r.get_data(as_text=True)


def test_unticking_after_the_handback_returns_it_to_the_operator(repo):
    _, tf, client = repo
    tick(client, tf, "First human check")
    tick(client, tf, "Second human check")
    assert owner(tf) == "agent"
    r = tick(client, tf, "Second human check")
    assert owner(tf) == "human"
    assert "back with you" in r.get_data(as_text=True)


def test_agent_boxes_do_not_trigger_it(repo):
    _, tf, client = repo
    tf.write_text(tf.read_text().replace("- [ ] [REVIEW] First", "- [x] [REVIEW] First")
                  .replace("- [ ] [REVIEW] Second", "- [x] [REVIEW] Second")
                  .replace("- [x] Agent criterion", "- [ ] Agent criterion"))
    tick(client, tf, "Agent criterion")
    assert owner(tf) == "human"


def test_no_provenance_row_means_no_tick_and_no_handback(repo, monkeypatch):
    _, tf, client = repo
    tick(client, tf, "First human check")

    def boom(*a, **k):
        raise OSError("disk full")
    monkeypatch.setattr(human_ac_ticks, "record", boom)
    r = tick(client, tf, "Second human check")
    assert r.status_code == 500
    assert owner(tf) == "human"
    assert "- [ ] [REVIEW] Second human check" in tf.read_text()


def test_review_page_fragment_shows_the_handback(repo, monkeypatch):
    # The /review page discards the tick response (hx-swap="none") and reloads /review/<id>/acs,
    # so the note there comes from task state, not from the response (found by the screenshot).
    root, tf, client = repo
    from web.blueprints import review as review_bp
    monkeypatch.setattr(review_bp, "PROJECT_ROOT", root)
    app = Flask(__name__, template_folder=str(FRAMEWORK_ROOT / "web" / "templates"))
    app.register_blueprint(review_bp.bp)
    app.jinja_env.globals.setdefault("csrf_token", lambda: "t")
    rc = app.test_client()
    assert "handed back to the agent" not in rc.get("/review/T-9002/acs").get_data(as_text=True)
    tick(client, tf, "First human check")
    tick(client, tf, "Second human check")
    html = rc.get("/review/T-9002/acs").get_data(as_text=True)
    assert "Every Human check is ticked: handed back to the agent to close." in html
    tick(client, tf, "Second human check")
    assert "handed back to the agent" not in rc.get("/review/T-9002/acs").get_data(as_text=True)


def test_one_rule_for_both_paths():
    src = (FRAMEWORK_ROOT / "lib" / "verdict_ledger.py").read_text()
    assert "owner_handback(new_text" in src
    assert 'elif owner == "human" and not still_open' not in src
    t = "---\nowner: human\n---\n\n## Acceptance Criteria\n\n### Human\n- [{}] a\n\n## Verification\n"
    assert delegation.owner_handback(t.format("x")) == "agent"
    assert delegation.owner_handback(t.format(" ")) is None
    assert delegation.owner_handback(t.format(" ").replace("owner: human", "owner: agent"),
                                     reopened=True) == "human"
