"""T-3853 — the delegation classifier reads only what the criterion's producer wrote.

ring20 G-225: 'authorize' in a reviewer escalation note (written by the framework, under the
criterion) made a layout check operator-only, and no command cleared a resolved escalation.
"""
import json
import os
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from lib import verdict_ledger as vl  # noqa: E402
from lib.delegation import OPERATOR_ONLY, classify, human_criteria  # noqa: E402

TASK = "T-9853"
ESCALATION = ("  **Reviewer escalation (V-0001, rv, rung 1):** the operator must authorize "
              "this sovereignty change before it is published")
VERDICT = ("  **Reviewer verdict:** green V-0002 — rv (rung 1), digest abc; dispatch d; "
           "evidence: deploy-notes.md; ledger x")


def _crit(*body, title="[REVIEW] The review page layout is tidy"):
    text = ("---\nid: T-9999\nworkflow_type: build\nowner: human\n---\n\n"
            "## Acceptance Criteria\n\n### Human\n"
            + "\n".join([f"- [ ] {title}", *body]) + "\n\n## Verification\n")
    (c,) = human_criteria(text)
    return c


BODY = ("  **Steps:**\n  1. Open the page", "  **Expected:** it looks right",
        "  **If not:** note it")


@pytest.mark.parametrize("note", [ESCALATION, VERDICT])
def test_framework_annotation_does_not_change_the_class(note):
    plain = classify(_crit(*BODY))
    annotated = classify(_crit(*BODY, note))
    assert annotated.cls == plain.cls
    assert annotated.delegation_class != OPERATOR_ONLY


def test_annotation_without_if_not_does_not_leak_into_expected():
    c = _crit("  **Steps:**\n  1. Open the page", "  **Expected:** it looks right", ESCALATION)
    assert "authorize" not in c.expected
    assert classify(c).delegation_class != OPERATOR_ONLY


def test_producer_risk_words_still_route_operator_only():
    c = _crit("  **Steps:**\n  1. authorize the token in the browser",
              "  **Expected:** it works", "  **If not:** retry")
    assert classify(c).cls == "act-in-the-world"


def test_body_text_keeps_the_annotation_for_verbatim_moves():
    c = _crit(*BODY, ESCALATION)
    assert ESCALATION in c.body_text
    assert ESCALATION not in c.producer_text


# ── operator command: resolve-escalation ────────────────────────────────────


def _task(root, *body):
    d = root / ".tasks" / "active"
    d.mkdir(parents=True, exist_ok=True)
    f = d / f"{TASK}-fixture.md"
    f.write_text(
        f"---\nid: {TASK}\nname: \"fixture\"\nstatus: started-work\nworkflow_type: build\n"
        f"owner: human\nhorizon: now\n---\n\n## Acceptance Criteria\n\n### Agent\n- [x] built\n\n"
        f"### Human\n- [ ] [REVIEW] The review page layout is tidy\n" + "\n".join(body)
        + "\n\n## Verification\n\n## Updates\n")
    return f


@pytest.fixture()
def root(tmp_path, monkeypatch):
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    return tmp_path


def test_resolve_removes_note_and_logs(root):
    f = _task(root, *BODY, ESCALATION)
    res = vl.resolve_escalation(TASK, 1, "operator answered it in chat", root=root)
    assert res["verdict_ids"] == ["V-0001"]
    text = f.read_text()
    assert "Reviewer escalation" not in text
    assert "**If not:** note it" in text and "owner: human" in text and "- [ ] [REVIEW]" in text
    rows = [json.loads(x) for x in (root / vl.APPLIED).read_text().splitlines()]
    assert rows[-1]["kind"] == "escalation-resolved" and rows[-1]["ac"] == 1
    assert rows[-1]["reason"] == "operator answered it in chat"


def test_resolve_refuses_without_note_or_reason(root):
    _task(root, *BODY)
    with pytest.raises(vl.VerdictRefused, match="no reviewer escalation"):
        vl.resolve_escalation(TASK, 1, "why", root=root)
    with pytest.raises(vl.VerdictRefused, match="reason"):
        vl.resolve_escalation(TASK, 1, "  ", root=root)


def _cli(root, *args, human=False):
    env = {**os.environ, "PROJECT_ROOT": str(root), "CLAUDECODE": "1"}
    return subprocess.run([sys.executable, "-m", "lib.verdict_ledger", "resolve-escalation",
                           TASK, "--ac", "1", "--reason", "done", *(["--i-am-human"] if human else []),
                           *args], cwd=ROOT, env=env, capture_output=True, text=True)


def test_cli_refuses_agents_and_accepts_operator(root):
    f = _task(root, *BODY, ESCALATION)
    cp = _cli(root)
    assert cp.returncode == 1 and "operator action" in cp.stderr
    assert "Reviewer escalation" in f.read_text()
    cp = _cli(root, human=True)
    assert cp.returncode == 0, cp.stderr
    assert "Reviewer escalation" not in f.read_text()
