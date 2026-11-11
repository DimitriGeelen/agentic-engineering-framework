"""T-5084: the review page said "Task completed" for any work-completed task, including one
still waiting for review in active/ with a Human check open (found by the T-5081 reviewer
judge after an untick). Temp git repo only; no real task file is touched."""
import sys
from pathlib import Path

from flask import Flask

FRAMEWORK_ROOT = Path(__file__).resolve().parents[2]
if str(FRAMEWORK_ROOT) not in sys.path:
    sys.path.insert(0, str(FRAMEWORK_ROOT))
sys.path.insert(0, str(Path(__file__).resolve().parent))

from test_t5081_owner_handback import TASK, git, repo, tick  # noqa: E402,F401
from web.blueprints import review as review_bp  # noqa: E402


def _client(root, monkeypatch):
    monkeypatch.setattr(review_bp, "PROJECT_ROOT", root)
    app = Flask(__name__, template_folder=str(FRAMEWORK_ROOT / "web" / "templates"))
    app.register_blueprint(review_bp.bp)
    app.jinja_env.globals.setdefault("csrf_token", lambda: "t")
    return app.test_client()


def test_waiting_for_review_with_a_check_open_is_with_the_operator(repo, monkeypatch):
    root, tf, client = repo
    html = _client(root, monkeypatch).get("/review/T-9002/acs").get_data(as_text=True)
    assert "A Human check is open: the task is with you." in html
    assert "Task completed" not in html


def test_after_untick_it_says_with_you_not_completed(repo, monkeypatch):
    root, tf, client = repo
    rc = _client(root, monkeypatch)
    tick(client, tf, "First human check")
    tick(client, tf, "Second human check")
    tick(client, tf, "Second human check")
    html = rc.get("/review/T-9002/acs").get_data(as_text=True)
    assert "the task is with you" in html
    assert "Task completed" not in html


def test_a_closed_task_still_shows_completed_and_no_complete_button(repo, monkeypatch):
    # T-2081 contract: a task in completed/ shows the marker, never the Complete button.
    root, tf, client = repo
    done = root / ".tasks" / "completed"
    done.mkdir(parents=True, exist_ok=True)
    text = tf.read_text().replace("- [ ] [REVIEW]", "- [x] [REVIEW]")
    (done / tf.name).write_text(text)
    tf.unlink()
    html = _client(root, monkeypatch).get("/review/T-9002/acs").get_data(as_text=True)
    assert "✓ Task completed." in html
    assert "Complete Task" not in html
    assert "the task is with you" not in html
