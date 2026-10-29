"""T-4904: task ids in a task page's raw body are links to their task pages."""

import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO))

from web.blueprints.tasks import _link_task_body, _link_task_ids  # noqa: E402

BODY = """## Context

**Background / trigger:** reported in T-4890 after T-4884.

## Acceptance Criteria

### Agent
- [ ] fix it like T-4778 did

### Human
- [ ] [REVIEW] check T-4870

## Verification

grep -q x .tasks/active/T-12-x.md

## Updates
- closed alongside T-4902 <script>alert(1)</script>
"""


def test_ids_are_linked_in_every_section():
    html = _link_task_body(BODY)
    for tid in ("T-4890", "T-4884", "T-4778", "T-4870", "T-4902"):
        assert f'<a href="/tasks/{tid}">{tid}</a>' in html, tid


def test_html_in_the_body_stays_escaped():
    html = _link_task_body(BODY)
    assert "<script>" not in html
    assert "&lt;script&gt;" in html


def test_a_path_holding_a_task_id_is_not_split():
    html = _link_task_body(BODY)
    assert '<a href="/tasks/T-12">' not in html


def test_ids_inside_an_existing_link_are_left_alone():
    html = '<a href="/tasks/T-5">T-5</a> and T-6'
    out = _link_task_ids(html)
    assert out.count('<a href="/tasks/T-5">') == 1
    assert '<a href="/tasks/T-6">T-6</a>' in out


def test_text_is_unchanged_apart_from_the_links():
    import re
    html = _link_task_body(BODY)
    plain = re.sub(r"<[^>]+>", "", html).replace("&lt;", "<").replace("&gt;", ">")
    assert plain == BODY
