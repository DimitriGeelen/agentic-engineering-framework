"""T-5241 (G-134): HTML-comment lines in `## Open Questions` never count.

Python leg of tests/unit/t5241_open_questions_comments.bats. Same fixtures, built
from the real inception template's Open Questions comment; each case asserts the
expected blocker kinds AND that `web.shared._handoff_blockers_from_text` gives
exactly the shell predicate's answer (parity, as in test_t5198_handoff_blockers).
"""
import os
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
os.environ.setdefault("PROJECT_ROOT", str(ROOT))

from web import shared  # noqa: E402

_SHELL = ('. "$1/lib/inception-readiness.sh" || exit 3; '
          '. "$1/lib/task-audit.sh" 2>/dev/null || true; '
          'inception_handoff_blockers "$2"')


def _template_oq() -> str:
    lines, flag = [], False
    for ln in (ROOT / ".tasks/templates/inception.md").read_text(encoding="utf-8").split("\n"):
        if ln.startswith("## Open Questions"):
            flag = True
            continue
        if ln.startswith("## "):
            flag = False
        if flag:
            lines.append(ln)
    return "\n".join(lines).strip("\n")


def _fixture(questions: str) -> str:
    return ("---\nid: T-9001\nname: \"fixture\"\nstatus: started-work\n"
            "workflow_type: inception\nowner: human\nhorizon: now\n---\n\n"
            "# T-9001: fixture\n\n## Problem Statement\n\nx\n\n"
            f"## Open Questions\n\n{_template_oq()}\n\n{questions}\n\n"
            "## Recommendation\n\n**Recommendation:** EXPLORING\n\n**Rationale:** still exploring\n")


CASES = {
    "template-only": ("", ["exploring"], "no Open Questions filed yet"),
    "disposed": ("- **IW-1: real question**\n  disposition: answered\n  rationale: evidence",
                 ["ready-for-recommendation"], "every question is disposed"),
    "open": ("- **IW-1: real question**", ["undisposed-question", "exploring"],
             "1 question(s) open"),
    "inline": ("<!-- - **IW-9: hidden** disposition: answered rationale: x -->\n"
               "- **IW-1: talks about the <!-- marker in prose**",
               ["undisposed-question", "exploring"], "1 question(s) open"),
    "comment-disposition": ("- **IW-1: real question**\n<!--\n  disposition: answered\n"
                            "  rationale: hidden\n-->",
                            ["undisposed-question", "exploring"],
                            "IW-1 disposition=false rationale=false"),
}


def _shell(path: Path) -> list[dict]:
    r = subprocess.run(["bash", "-c", _SHELL, "_", str(ROOT), str(path)],
                       capture_output=True, text=True)
    assert r.returncode == 0, r.stderr
    out = []
    for line in r.stdout.split("\n"):
        parts = line.split("\t")
        if len(parts) >= 2 and parts[0]:
            out.append({"kind": parts[0], "detail": parts[1],
                        "fix": parts[2] if len(parts) > 2 else ""})
    return out


@pytest.mark.parametrize("name", sorted(CASES))
def test_case_kinds_and_parity(name, tmp_path):
    questions, kinds, needle = CASES[name]
    p = tmp_path / f"{name}.md"
    p.write_text(_fixture(questions), encoding="utf-8")
    py = shared._handoff_blockers_from_text(p.read_text(encoding="utf-8"))
    assert [b["kind"] for b in py] == kinds
    assert any(needle in b["detail"] for b in py), py
    assert py == _shell(p)


def test_open_questions_helper_drops_template_comment():
    lines = _fixture("- **IW-1: real**").split("\n")
    oq = shared._hb_open_questions(lines)
    assert [ln for ln in oq if "IW-" in ln] == ["- **IW-1: real**"]
