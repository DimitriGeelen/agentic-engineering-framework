"""T-4096: /approvals and `fw review-queue` put every task in the same group.

One fixture corpus (ready build task, waiting build task, undecided inception that ALSO
carries an unticked Human criterion, partial-complete task with a reviewer-judged
criterion); the page loaders and the CLI must agree per task id.
"""

import os
import re
import subprocess
import sys
from pathlib import Path

import pytest

sys.path.insert(0, ".")

from web import shared  # noqa: E402

FW_ROOT = Path(__file__).resolve().parents[2]

DETERMINISTIC = """- [ ] [RUBBER-STAMP] Run it
  **Steps:**
  1. Run `ls /tmp`
  **Expected:** output contains `tmp`
  **If not:** fix it
"""
TASTE = """- [ ] [REVIEW] Tone reads clearly
  **Steps:**
  1. Read it
  **Expected:** reads clearly, tone is right
  **If not:** note paragraphs
"""
REC = "## Recommendation\n\n**Recommendation:** GO\n**Rationale:** evidence is complete and sufficient.\n"


def _task(tid, agent, human, wf="build", extra=""):
    return f"""---
id: {tid}
name: "fixture {tid}"
status: started-work
workflow_type: {wf}
owner: agent
created: 2026-10-01T00:00:00Z
last_update: 2026-10-01T00:00:00Z
---

# {tid}

## Acceptance Criteria

### Agent
{agent}
### Human
{human}
## Verification
true

{extra}
"""


CORPUS = {
    "T-9201": _task("T-9201", "- [x] done\n", DETERMINISTIC),
    "T-9202": _task("T-9202", "- [x] a\n- [ ] b\n", DETERMINISTIC),
    "T-9203": _task("T-9203", "- [x] done\n", DETERMINISTIC, wf="inception", extra=REC),
    "T-9204": _task("T-9204", "- [x] done\n", TASTE),
}
EXPECTED = {"T-9201": "ready", "T-9202": "waiting", "T-9203": "decisions", "T-9204": "waiting"}


@pytest.fixture
def proj(tmp_path, monkeypatch):
    act = tmp_path / ".tasks" / "active"
    act.mkdir(parents=True)
    for tid, text in CORPUS.items():
        (act / f"{tid}-fixture.md").write_text(text)
    subprocess.run(["git", "init", "-q", str(tmp_path)], check=True)
    subprocess.run(["git", "-C", str(tmp_path), "-c", "user.name=t", "-c", "user.email=t@t",
                    "commit", "-q", "--allow-empty", "-m", "init"], check=True)
    monkeypatch.setattr(shared, "PROJECT_ROOT", tmp_path)
    shared._READINESS_CACHE.clear()
    shared._LEDGER_CACHE.clear()
    return tmp_path


def _page_groups(proj, monkeypatch):
    from web.app import app
    from web.blueprints import approvals as ap

    monkeypatch.setattr(ap, "PROJECT_ROOT", proj)
    metas = []
    for p in sorted((proj / ".tasks" / "active").glob("T-*.md")):
        fm, _ = shared.parse_frontmatter(p.read_text())
        metas.append(dict(fm, _location="active", _path=str(p)))
    monkeypatch.setattr(ap, "_task_meta", lambda: metas)
    monkeypatch.setattr(ap, "_load_assumptions", lambda: [], raising=False)
    import web.blueprints.inception as inc
    monkeypatch.setattr(inc, "_load_assumptions", lambda: [])
    out = {}  # id -> set of groups it is shown in; one group per task is the contract
    with app.test_request_context("/approvals"):
        for t in ap._load_pending_human_acs():
            out.setdefault(t["task_id"], set()).add(
                "ready" if t["readiness"] == "ready" else "waiting")
        for t in ap._load_pending_go_decisions():
            out.setdefault(t["task_id"], set()).add("decisions")
    return {k: ("/".join(sorted(v))) for k, v in out.items()}


def _cli_groups(proj):
    env = dict(os.environ, PROJECT_ROOT=str(proj), FW_LIB_DIR=str(FW_ROOT / "lib"))
    fw = str(FW_ROOT / "bin" / "fw")
    ready = subprocess.run([fw, "review-queue", "--ids"], cwd=proj, env=env,
                           capture_output=True, text=True, timeout=180).stdout.split()
    both = subprocess.run([fw, "review-queue", "--ids", "--include-waiting"], cwd=proj, env=env,
                          capture_output=True, text=True, timeout=180).stdout.split()
    full = subprocess.run([fw, "review-queue"], cwd=proj, env=env,
                          capture_output=True, text=True, timeout=180).stdout
    full = re.sub(r"\x1b\[[0-9;]*m", "", full)
    dec = re.search(r"DECISIONS.*?(?=\n[A-Z]{4,}[^\n]*\(\d+\)|\Z)", full, re.S)
    out = {t: "ready" for t in ready}
    out.update({t: "waiting" for t in both if t not in out})
    decided = set(re.findall(r"T-\d+", dec.group(0))) if dec else set()
    return out, decided


def test_shared_function_groups_fixture_corpus(proj):
    g = shared.review_queue_groups(proj)
    got = {t: k for k, ids in g.items() for t in ids}
    assert got == EXPECTED


def test_page_equals_cli_per_task_id(proj, monkeypatch):
    page = _page_groups(proj, monkeypatch)
    cli, cli_decisions = _cli_groups(proj)
    cli.update({t: "decisions" for t in cli_decisions})
    assert page == EXPECTED
    assert cli == EXPECTED
