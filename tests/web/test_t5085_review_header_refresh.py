"""T-5085: the review page header (status badge, Owner line) stayed as it was at page load
after a tick, contradicting the hand-back note, and labelled a task awaiting review as
'work-completed'. Temp git repo only; no real task file is touched."""
import sys
from pathlib import Path

FRAMEWORK_ROOT = Path(__file__).resolve().parents[2]
if str(FRAMEWORK_ROOT) not in sys.path:
    sys.path.insert(0, str(FRAMEWORK_ROOT))
sys.path.insert(0, str(Path(__file__).resolve().parent))

from test_t5081_owner_handback import repo, tick  # noqa: E402,F401
from test_t5084_review_completed_state import _client  # noqa: E402


def test_fragment_refreshes_header_owner_and_label_after_the_last_tick(repo, monkeypatch):
    root, tf, client = repo
    rc = _client(root, monkeypatch)
    tick(client, tf, "First human check")
    tick(client, tf, "Second human check")
    html = rc.get("/review/T-9002/acs").get_data(as_text=True)
    assert '<span id="review-owner" hx-swap-oob="true">Owner: agent</span>' in html
    assert 'id="review-status" hx-swap-oob="true"' in html and ">awaiting review</span>" in html


def test_fragment_refreshes_owner_back_to_human_after_untick(repo, monkeypatch):
    root, tf, client = repo
    rc = _client(root, monkeypatch)
    tick(client, tf, "First human check")
    tick(client, tf, "Second human check")
    tick(client, tf, "Second human check")
    html = rc.get("/review/T-9002/acs").get_data(as_text=True)
    assert '<span id="review-owner" hx-swap-oob="true">Owner: human</span>' in html


def test_full_page_renders_the_header_once_without_oob_copies(repo, monkeypatch):
    root, tf, client = repo
    html = _client(root, monkeypatch).get("/review/T-9002").get_data(as_text=True)
    assert html.count('id="review-owner"') == 1
    assert html.count('id="review-status"') == 1
    assert "hx-swap-oob" not in html
    assert ">awaiting review</span>" in html


def test_a_closed_task_keeps_the_work_completed_label(repo, monkeypatch):
    root, tf, client = repo
    done = root / ".tasks" / "completed"
    done.mkdir(parents=True, exist_ok=True)
    (done / tf.name).write_text(tf.read_text().replace("- [ ] [REVIEW]", "- [x] [REVIEW]"))
    tf.unlink()
    html = _client(root, monkeypatch).get("/review/T-9002/acs").get_data(as_text=True)
    assert ">work-completed</span>" in html
    assert "awaiting review" not in html
