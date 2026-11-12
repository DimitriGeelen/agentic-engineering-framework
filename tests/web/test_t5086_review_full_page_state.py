"""T-5086: a fresh load of /review/<id> showed no state note until the 5-second poll, because
only the fragment route computed the task state. Both routes now share one helper.
Temp git repo only; no real task file is touched."""
import sys
from pathlib import Path

FRAMEWORK_ROOT = Path(__file__).resolve().parents[2]
if str(FRAMEWORK_ROOT) not in sys.path:
    sys.path.insert(0, str(FRAMEWORK_ROOT))
sys.path.insert(0, str(Path(__file__).resolve().parent))

from test_t5081_owner_handback import repo, tick  # noqa: E402,F401
from test_t5084_review_completed_state import _client  # noqa: E402


def test_full_page_shows_with_you_on_first_load(repo, monkeypatch):
    root, tf, client = repo
    html = _client(root, monkeypatch).get("/review/T-9002").get_data(as_text=True)
    assert "A Human check is open: the task is with you." in html
    assert "Task completed" not in html


def test_full_page_shows_the_handback_on_first_load(repo, monkeypatch):
    root, tf, client = repo
    tick(client, tf, "First human check")
    tick(client, tf, "Second human check")
    html = _client(root, monkeypatch).get("/review/T-9002").get_data(as_text=True)
    assert "Every Human check is ticked: handed back to the agent to close." in html
    assert "Owner: agent" in html


def test_both_routes_use_the_one_helper():
    src = (FRAMEWORK_ROOT / "web" / "blueprints" / "review.py").read_text()
    assert src.count("**_task_state(task_file, fm, total_count, all_checked)") == 2
    assert "task_completed=task_completed" not in src
