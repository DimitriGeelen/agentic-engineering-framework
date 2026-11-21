"""T-5315 — risk-matrix review split (T-5310 GO).

* `risk_register.py --matrix` parses a filled matrix: arithmetic, range and
  actor-name errors, and the list of risks that need operator acceptance;
* the two criteria the template gives to copy route the way the split needs:
  the matrix check REVIEWER-JUDGES, the risk acceptance OPERATOR-ONLY — read
  through the same classifier `fw task delegate --dry-run` uses.
"""

import json
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
for p in (ROOT / "lib", ROOT):
    if str(p) not in sys.path:
        sys.path.insert(0, str(p))

import risk_register as rr  # noqa: E402
from lib import delegation  # noqa: E402

TEMPLATE = ROOT / ".tasks" / "templates" / "risk-matrix.md"

SUMMARY_HEAD = (
    "| # | Risk | Domain | How to detect the door is open | How to detect it happening "
    "| Impact | Likelihood | Exists anyway (baseline)? | Introduced by the change? | Key mitigation |\n"
    "|---|------|--------|------|------|-------:|-----------:|------|------|------|\n"
)
ACTOR_HEAD = (
    "| # | Actor | How | L | I | Score | Mitigated L × I | Mitigated score |\n"
    "|---|-------|-----|--:|--:|------:|-----------------|----------------:|\n"
)


def _matrix(summary_rows, risks):
    """risks: {n: [actor row strings]}"""
    out = ["# Risk matrix — test", "", "## Summary", "", SUMMARY_HEAD + "\n".join(summary_rows), ""]
    for n, rows in risks.items():
        out += [f"### Risk {n} — r{n}", "", ACTOR_HEAD + "\n".join(rows), ""]
    return "\n".join(out) + "\n"


def _srow(n, name, i, l, introduced):
    return f"| {n} | {name} | d | x | y | {i} | {l} | yes | {introduced} | m |"


CLEAN = _matrix(
    [_srow(1, "prompt injection", 4, 3, "no, reduced"),
     _srow(2, "sandbox escape", 4, 2, "NEW")],
    {1: ["| 1.1 | own-agent-unintentional | planted text | 3 | 4 | 12 | 2 × 2 | 4 |",
         "| 1.2 | intruder | on node | 2 | 5 | 10 | 1 x 5 | 5 |",
         "| 1.3 | provider-host | | | | | | |"],
     2: ["| 2.1 | outsider-intentional | breakout | 2 | 4 | 8 | 1 × 4 | 4 |"]},
)


def test_clean_matrix():
    res = rr.parse_matrix(CLEAN)
    assert res["errors"] == []
    assert [r["risk"] for r in res["risks"]] == [1, 2]
    assert res["risks"][0]["worst_score"] == 12 and res["risks"][0]["worst_mitigated"] == 5
    assert res["needs_operator_acceptance"] == []


def test_blank_template_parses_with_no_errors():
    res = rr.parse_matrix(TEMPLATE.read_text())
    assert res["errors"] == [] and res["risks"] == []


def test_arithmetic_errors():
    text = _matrix(
        [_srow(1, "r", 4, 3, "no")],
        {1: ["| 1.1 | own-agent-unintentional | h | 3 | 4 | 11 | 2 × 2 | 5 |",
             "| 1.2 | intruder | h | 6 | 2 | 12 | | |"]},
    )
    errs = rr.parse_matrix(text)["errors"]
    assert any("score '11' is not L x I = 12" in e for e in errs), errs
    assert any("mitigated score '5' is not mitigated L x I = 4" in e for e in errs), errs
    assert any("L must be an integer 1-5, got '6'" in e for e in errs), errs


def test_unknown_actor_and_missing_actor_table():
    text = _matrix(
        [_srow(1, "r", 2, 2, "no"), _srow(2, "orphan", 2, 2, "no")],
        {1: ["| 1.1 | hacker | h | 2 | 2 | 4 | | |"]},
    )
    errs = rr.parse_matrix(text)["errors"]
    assert any("actor 'hacker' is not one of" in e for e in errs), errs
    assert any("summary risk 2 (orphan) has no filled '### Risk 2' actor table" in e
               for e in errs), errs


def test_acceptance_list():
    text = _matrix(
        [_srow(1, "new at mitigated 6", 3, 3, "NEW"),
         _srow(2, "not new at 12", 4, 3, "no"),
         _srow(3, "any 15", 5, 3, "no, reduced"),
         _srow(4, "partly new, mitigated 4", 4, 3, "PARTLY NEW (scale)")],
        {1: ["| 1.1 | own-agent-unintentional | h | 3 | 3 | 9 | 2 × 3 | 6 |"],
         2: ["| 2.1 | human-unintentional | h | 3 | 4 | 12 | | |"],
         3: ["| 3.1 | intruder | h | 3 | 5 | 15 | 1 × 2 | 2 |"],
         4: ["| 4.1 | provider-host | h | 3 | 4 | 12 | 2 × 2 | 4 |"]},
    )
    res = rr.parse_matrix(text)
    assert res["errors"] == []
    listed = {r["risk"]: r["reasons"] for r in res["needs_operator_acceptance"]}
    assert set(listed) == {1, 3}
    assert "NEW and still 6 after mitigation" in listed[1]
    assert "scores 15 (high)" in listed[3]


def test_cli_exit_codes(tmp_path):
    good = tmp_path / "good.md"
    good.write_text(CLEAN)
    bad = tmp_path / "bad.md"
    bad.write_text(_matrix([_srow(1, "r", 2, 2, "no")],
                           {1: ["| 1.1 | hacker | h | 2 | 2 | 4 | | |"]}))
    run = lambda *a: subprocess.run([sys.executable, str(ROOT / "lib" / "risk_register.py"), *a],
                                    capture_output=True, text=True)
    r = run("--matrix", str(good), "--json")
    assert r.returncode == 0, r.stderr
    assert json.loads(r.stdout)["errors"] == []
    assert run("--matrix", str(bad)).returncode == 1
    assert run("--matrix", str(tmp_path / "missing.md")).returncode == 2


def _template_criteria() -> str:
    m = re.search(r"## Criteria to copy into the task.*?```markdown\n(.*?)```",
                  TEMPLATE.read_text(), re.DOTALL)
    assert m, "template lacks the 'Criteria to copy into the task' block"
    return m.group(1)


def test_template_criteria_route_reviewer_then_operator(tmp_path):
    task = tmp_path / "T-9999-fixture.md"
    task.write_text(
        "---\nid: T-9999\nname: fixture\nstatus: started-work\nworkflow_type: build\n"
        "owner: human\n---\n\n# T-9999\n\n## Acceptance Criteria\n\n### Agent\n"
        "- [x] done\n\n### Human\n" + _template_criteria() + "\n## Verification\n"
    )
    tc = delegation.classify_task(task, render_surface=False)
    classes = [cl.delegation_class for _, cl in tc.rows]
    assert classes == [delegation.REVIEWER_JUDGES, delegation.OPERATOR_ONLY], \
        [(c.title[:40], cl.cls, cl.reason) for c, cl in tc.rows]
    assert tc.rows[1][1].cls == "operator-marked"
