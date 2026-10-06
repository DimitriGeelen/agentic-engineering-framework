"""T-3963: `fw task classify-ac` — one ruleset for consumers, on text, without a task file.

832 re-implemented the delegation predicate to route checks before a task existed, so the
two copies could drift. The verb is a thin CLI over lib.delegation.classify; these tests pin
that its answer IS classify()'s answer, not a parallel one.
"""
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from lib.delegation import classify, parse_criteria  # noqa: E402

FORCE = "- [ ] [REVIEW] Push with git push --force to origin master"
TASTE = "- [ ] [REVIEW] Layout reads clean and the tone feels right"
DETERMINISTIC = ("- [ ] [REVIEW] Config parses\n  **Steps:**\n  1. Run `python3 -c \"import yaml\"`\n"
                 "  **Expected:** exit 0\n  **If not:** fix\n")


def _cli(*args, stdin=None):
    r = subprocess.run([str(ROOT / "bin/fw"), "task", "classify-ac", *args], input=stdin,
                       capture_output=True, text=True, cwd=ROOT, timeout=60)
    assert r.returncode == 0, r.stderr
    return json.loads(r.stdout)


def _direct(text):
    crit = parse_criteria("## Acceptance Criteria\n\n### Human\n" + text + "\n")[0]
    k = classify(crit)
    return k.cls, k.delegation_class


def test_cli_equals_classify_for_three_classes():
    for text, want in ((FORCE, "OPERATOR-ONLY"), (TASTE, "REVIEWER-JUDGES"),
                       (DETERMINISTIC, "REVIEWER-CLOSEABLE")):
        row = _cli("--text", text, "--json")[0]
        assert (row["class"], row["delegation_class"]) == _direct(text)
        assert row["delegation_class"] == want, row


def test_stdin_and_a_full_section_are_accepted():
    rows = _cli("--json", stdin=DETERMINISTIC)
    assert rows[0]["subhead"] == "Human"
    full = "## Acceptance Criteria\n\n### Agent\n- [ ] tests pass\n\n### Human\n" + TASTE + "\n"
    rows = _cli("--json", stdin=full)
    assert [r["subhead"] for r in rows] == ["Agent", "Human"]


def test_no_criterion_is_an_error():
    r = subprocess.run([str(ROOT / "bin/fw"), "task", "classify-ac", "--text", "just prose"],
                       capture_output=True, text=True, cwd=ROOT, timeout=60)
    assert r.returncode == 2 and "no '- [ ]' criterion" in r.stderr


def test_consumer_template_carries_the_guidance():
    t = (ROOT / "lib/templates/claude-project.md").read_text(encoding="utf-8")
    assert "### AC Classification Guidance" in t
    assert "fw task classify-ac" in t and "lib/delegation.py" in t
