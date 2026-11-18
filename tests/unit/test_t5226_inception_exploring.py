"""T-5226: the Watchtower inception page shows EXPLORING plainly and offers no
decision buttons; the in-process readiness transcription agrees with the shell.

The page is driven through the real Flask route with PROJECT_ROOT pointed at a
tmp project, so the real .tasks/ is never touched. The GO control pins that the
decision form still renders when the recommendation is a verdict — without it,
"never render the form" would pass every EXPLORING assertion.
"""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
os.environ.setdefault("PROJECT_ROOT", str(ROOT))

from web import shared  # noqa: E402

FM = ("---\nid: {id}\nname: \"fixture inception\"\nstatus: started-work\n"
      "workflow_type: inception\nowner: human\nhorizon: now\n---\n\n# {id}: fixture\n\n")
OPEN = ("## Open Questions\n\n- **IW-1: q1**\n  disposition: answered\n  rationale: r\n\n"
        "- **IW-2: q2**\n  disposition:\n\n")
DISPOSED = ("## Open Questions\n\n- **IW-1: q1**\n  disposition: answered\n  rationale: r\n\n"
            "- **IW-2: q2**\n  disposition: deferred\n  rationale: later\n\n")
NONE = "## Open Questions\n\nnothing yet\n\n"


def _rec(verdict: str) -> str:
    return f"## Recommendation\n\n**Recommendation:** {verdict}\n\n**Rationale:** because\n\n## Decision\n\n"


CASES = {
    "exploring-open": OPEN + _rec("EXPLORING"),
    "exploring-disposed": DISPOSED + _rec("EXPLORING"),
    "exploring-none": NONE + _rec("EXPLORING"),
    "exploring-nosection": _rec("EXPLORING"),
    "exploring-bold": DISPOSED + _rec("**EXPLORING**"),
    "exploring-lower": OPEN + _rec("exploring"),
    "exploring-in-comment-only": DISPOSED + "## Recommendation\n\n<!-- **Recommendation:** EXPLORING -->\n\n## Decision\n",
    "go-disposed": DISPOSED + _rec("GO"),
    "defer-open": OPEN + _rec("DEFER"),
}


def _write(tmp: Path, tid: str, body: str) -> Path:
    d = tmp / ".tasks" / "active"
    d.mkdir(parents=True, exist_ok=True)
    p = d / f"{tid}-fixture.md"
    p.write_text(FM.format(id=tid) + body)
    return p


def _shell(path: Path) -> list[dict]:
    script = ('. "$1/lib/inception-readiness.sh"; . "$1/lib/task-audit.sh" 2>/dev/null; '
              'inception_handoff_blockers "$2"')
    r = subprocess.run(["bash", "-c", script, "_", str(ROOT), str(path)],
                       capture_output=True, text=True)
    assert r.returncode == 0, r.stderr
    out = []
    for line in r.stdout.splitlines():
        parts = line.split("\t")
        if len(parts) >= 2 and parts[0]:
            out.append({"kind": parts[0], "detail": parts[1], "fix": parts[2] if len(parts) > 2 else ""})
    return out


@pytest.mark.parametrize("name", sorted(CASES))
def test_transcription_matches_shell(tmp_path, name):
    p = _write(tmp_path, "T-9501", CASES[name])
    assert shared._handoff_blockers_from_text(p.read_text()) == _shell(p)


def test_transcription_is_current():
    """The in-process path is only used while the shell rule hashes to the digest."""
    state = shared._handoff_rule_state()
    assert state is not None and state[1] is True


def test_kinds():
    kinds = {n: [b["kind"] for b in shared._handoff_blockers_from_text(FM.format(id="T-1") + b)]
             for n, b in CASES.items()}
    assert "exploring" in kinds["exploring-open"]
    assert kinds["exploring-disposed"] == ["ready-for-recommendation"]
    assert kinds["exploring-none"] == ["exploring"]
    assert kinds["exploring-nosection"] == ["ready-for-recommendation"]
    assert kinds["exploring-bold"] == ["ready-for-recommendation"]
    assert kinds["go-disposed"] == []
    assert "exploring" not in kinds["defer-open"]
    assert "empty-recommendation" in kinds["exploring-in-comment-only"]


@pytest.fixture
def client(tmp_path, monkeypatch):
    from web.app import app
    from web.blueprints import inception as inc
    monkeypatch.setattr(inc, "PROJECT_ROOT", tmp_path)
    shared._HANDOFF_BLOCKERS_CACHE.clear()
    app.config["TESTING"] = True
    return app.test_client()


def _page(client, tmp_path, tid, body) -> str:
    _write(tmp_path, tid, body)
    r = client.get(f"/inception/{tid}")
    assert r.status_code == 200
    return r.get_data(as_text=True)


def test_page_exploring_open_shows_state_and_no_buttons(client, tmp_path):
    html = _page(client, tmp_path, "T-9511", CASES["exploring-open"])
    assert 'data-testid="inception-exploring"' in html
    assert "EXPLORING" in html and "not ready for decision" in html
    assert 'data-testid="inception-not-ready"' in html
    assert "1 question(s) open" in html
    assert 'name="decision"' not in html
    assert "/inception/T-9511/decide" not in html


def test_page_exploring_disposed_says_ready_for_recommendation_no_buttons(client, tmp_path):
    html = _page(client, tmp_path, "T-9512", CASES["exploring-disposed"])
    assert "ready for a recommendation" in html
    assert 'name="decision"' not in html


def test_page_go_control_still_offers_the_decision(client, tmp_path):
    html = _page(client, tmp_path, "T-9513", CASES["go-disposed"])
    assert 'data-testid="inception-exploring"' not in html
    assert 'name="decision"' in html
    assert "/inception/T-9513/decide" in html
