"""T-2768 (T-2757 IW-4): the /designer placeholder names a source + LAN precondition."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from web.blueprints.designer import _placeholder  # noqa: E402


def _body(pin):
    return _placeholder(pin).get_data(as_text=True)


def test_placeholder_names_every_source_and_lan_precondition():
    body = _body({
        "version": "9.9.9",
        "sha256": "a" * 64,
        "source_origin": "ssh://git@lan-host.example:6611/workflow-designer",
    })
    assert "fw designer install" in body
    assert "fw designer sync --from-tag" in body
    assert "ssh://git@lan-host.example:6611/workflow-designer" in body
    assert "LAN" in body
    assert "reachable from this host" in body
    assert "fw designer sync --from &lt;file&gt;" in body


def test_placeholder_without_origin_names_the_gap_and_escapes():
    body = _body({"version": "9.9.9", "sha256": "a" * 64})
    assert "source_origin unset" in body
    assert "&lt;source_origin unset" in body
