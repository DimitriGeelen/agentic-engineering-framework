#!/usr/bin/env python3
"""T-5206 — `fw task delegate` reports operator widenings (T-5180) the way the close path
applies them: an act-in-the-world criterion inside an active widening, with a Measured
block, is reviewer-judged under its SD id; without the block it stays operator-only and
names the missing block; anything else a widening does not reach stays operator-only; and
with no widening recorded the report is byte-identical. Nothing is converted or written.
tmp_path projects only — the real standing-delegations ledger is never touched."""
import json
import os
import re
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from lib import delegation_widening as dw  # noqa: E402

TASK = "T-9100"
WORLD = ("- [ ] [REVIEW] Publish the release to the public mirror and confirm consumers pick it up\n"
         "  **Steps:**\n  1. Publish\n  **Expected:** consumers upgrade\n  **If not:** roll back\n")
MEASURED = ("  **Measured:** `curl -s https://mirror.example/releases/latest`\n"
            "  ```\n  v1.9.0\n  ```\n")
TASTE = ("- [ ] [REVIEW] The summary paragraph reads clearly\n"
         "  **Steps:**\n  1. Read it\n  **Expected:** reads as a peer briefing\n  **If not:** note it\n")
PAT = r"Publish"

FM = """---
id: T-9100
name: "fixture"
status: started-work
workflow_type: build
owner: human
created: 2026-01-01T00:00:00Z
last_update: 2026-01-01T00:00:00Z
---

# T-9100: fixture

## Acceptance Criteria

### Agent
- [x] parser handles empty input

### Human
{human}
## Verification
true

## Updates
"""


def _widening(wid="SD-0000abcd", tasks=(TASK,), expires="2099-01-01", by="operator",
               pattern=PAT, cls="act-in-the-world"):
    return {"kind": "widening", "id": wid, "class": cls, "ruling": "R-3800",
            "text": "Yes, you may close the task yourself.", "pattern": pattern,
            "tasks": list(tasks), "expires": expires, "by": by, "ts": "2026-11-16T00:00:00Z"}


def _project(tmp_path, human, rows=()):
    d = tmp_path / ".tasks" / "active"
    d.mkdir(parents=True)
    f = d / f"{TASK}-fixture.md"
    f.write_text(FM.format(human=human))
    if rows:
        led = tmp_path / dw.DELEGATIONS
        led.parent.mkdir(parents=True, exist_ok=True)
        led.write_text("".join(json.dumps(r) + "\n" for r in rows))
    return f


def _delegate(tmp_path, *args):
    env = dict(os.environ, PROJECT_ROOT=str(tmp_path), FRAMEWORK_ROOT=str(ROOT))
    return subprocess.run([sys.executable, str(ROOT / "lib" / "delegation_cli.py"),
                           "delegate", TASK, *args],
                          capture_output=True, text=True, env=env, cwd=str(tmp_path))


def _snapshot(tmp_path):
    return {p: p.read_bytes() for p in sorted(tmp_path.rglob("*")) if p.is_file()}


def _summary(out):
    m = re.search(r"converted (\d+), reviewer-judged (\d+), left human (\d+)", out)
    assert m, out
    return tuple(int(x) for x in m.groups())


def _json(tmp_path):
    r = _delegate(tmp_path, "--dry-run", "--json")
    assert r.returncode == 0, r.stderr
    return json.loads(r.stdout)


# ── widened + Measured → reviewer-judged under the SD id ─────────────────────

@pytest.mark.parametrize("mode", [("--dry-run",), ()])
def test_active_widening_with_measured_is_reviewer_judged(tmp_path, mode):
    f = _project(tmp_path, WORLD + MEASURED, [_widening()])
    before = _snapshot(tmp_path)
    r = _delegate(tmp_path, *mode)
    assert r.returncode == 0, r.stderr
    assert "reviewer-judged under SD-0000abcd (ruling R-3800)" in r.stdout
    assert "stays human" not in r.stdout
    assert _summary(r.stdout) == (0, 1, 0)
    assert "reviewer judge T-9100" in r.stdout
    assert _snapshot(tmp_path) == before, "the report converts and writes nothing"
    assert f.read_text() == FM.format(human=WORLD + MEASURED)


def test_widened_json_record(tmp_path):
    _project(tmp_path, WORLD + MEASURED, [_widening()])
    rec = _json(tmp_path)
    (row,) = rec["refused"]
    assert row["class"] == "act-in-the-world"
    assert row["delegation_class"] == "REVIEWER-JUDGES"
    assert row["widened_by"] == "SD-0000abcd" and row["widening_ruling"] == "R-3800"
    assert rec["reviewer_judgeable"] == [1] and rec["reviewer_judged_count"] == 1
    assert rec["converted"] == [] and rec["owner_after"] == "human"


# ── widened but no Measured block → operator-only, names the missing block ──

def test_widening_without_measured_stays_operator_only(tmp_path):
    _project(tmp_path, WORLD, [_widening()])
    r = _delegate(tmp_path, "--dry-run")
    assert r.returncode == 0, r.stderr
    assert "stays human" in r.stdout and "reviewer-judged under" not in r.stdout
    assert "SD-0000abcd (ruling R-3800) covers it, but the criterion has no Measured block" in r.stdout
    assert "**Measured:** <command>" in r.stdout
    assert _summary(r.stdout) == (0, 0, 1)
    (row,) = _json(tmp_path)["refused"]
    assert row["delegation_class"] == "OPERATOR-ONLY" and "widened_by" not in row
    assert "no Measured block" in row["widening"]


# ── widenings that do not reach the criterion → operator-only ───────────────

@pytest.mark.parametrize("rows,why", [
    ([_widening(expires="2020-01-01")], "expired 2020-01-01"),
    ([_widening(), {"kind": "revoke", "id": "SD-0000abcd", "ts": "2026-11-17T00:00:00Z"}],
     "revoked 2026-11-17"),
    ([_widening(by="agent-override")], "agent-override"),
    ([_widening(tasks=("T-9999",))], "T-9100 is outside SD-0000abcd's task list"),
    ([_widening(pattern="Deploy")], "does not match"),
])
def test_widening_not_reaching_stays_operator_only(tmp_path, rows, why):
    _project(tmp_path, WORLD + MEASURED, rows)
    r = _delegate(tmp_path, "--dry-run")
    assert r.returncode == 0, r.stderr
    assert "stays human" in r.stdout and "reviewer-judged under" not in r.stdout
    assert why in r.stdout
    assert _summary(r.stdout) == (0, 0, 1)
    (row,) = _json(tmp_path)["refused"]
    assert row["delegation_class"] == "OPERATOR-ONLY" and "widened_by" not in row


def test_report_agrees_with_active_widening(tmp_path):
    """One decision point: the report's verdict is exactly active_widening's."""
    from lib.delegation import human_criteria
    f = _project(tmp_path, WORLD + MEASURED, [_widening()])
    text = f.read_text()
    w, why = dw.active_widening(tmp_path, TASK, text, human_criteria(text)[0])
    (row,) = _json(tmp_path)["refused"]
    assert w is not None and why == "" and row["widened_by"] == w["id"]


# ── no widening recorded → byte-identical output ────────────────────────────

BASELINE = ("import sys; sys.path.insert(0, sys.argv[1]); from lib import delegation_cli as d; "
            "d._widenings = lambda *a, **k: {}; sys.exit(d.main(sys.argv[2:]))")


def _baseline(tmp_path, *args):
    """The same CLI with the widening lookup removed: the pre-T-5206 report."""
    env = dict(os.environ, PROJECT_ROOT=str(tmp_path), FRAMEWORK_ROOT=str(ROOT))
    return subprocess.run([sys.executable, "-c", BASELINE, str(ROOT), "delegate", TASK, *args],
                          capture_output=True, text=True, env=env, cwd=str(tmp_path))


@pytest.mark.parametrize("args", [("--dry-run",), ("--dry-run", "--json"), ()])
@pytest.mark.parametrize("ledger", [(), ({"kind": "grant", "id": "SD-0000beef", "class": "taste",
                                          "ts": "2026-11-16T00:00:00Z"},)])
def test_no_widenings_output_unchanged(tmp_path, args, ledger):
    """No ledger, or a ledger holding only a grant: byte-identical to the baseline."""
    a, b = tmp_path / "a", tmp_path / "b"
    a.mkdir()
    b.mkdir()
    human = WORLD + MEASURED + TASTE
    _project(a, human, ledger)
    _project(b, human, ledger)
    before = _snapshot(a)
    ra, rb = _delegate(a, *args), _baseline(b, *args)
    assert ra.returncode == rb.returncode == 0, ra.stderr + rb.stderr
    norm = lambda s: re.sub(r'"ts": "[^"]*"', '"ts": "X"', s)  # noqa: E731  (wall clock)
    assert norm(ra.stdout) == norm(rb.stdout)
    assert "widening" not in ra.stdout
    assert _snapshot(a) == before


# ── summary counts agree with the per-criterion lines ───────────────────────

def test_summary_counts_agree_with_lines(tmp_path):
    human = WORLD + MEASURED + TASTE + WORLD
    _project(tmp_path, human, [_widening()])
    r = _delegate(tmp_path, "--dry-run")
    assert r.returncode == 0, r.stderr
    lines = [ln for ln in r.stdout.splitlines() if re.match(r"\s+AC#\d", ln)]
    assert len(lines) == 3
    judged = sum("reviewer-judged" in ln for ln in lines)
    human_left = sum("stays human" in ln for ln in lines)
    conv = sum("→ REVIEWER" in ln for ln in lines)
    assert (conv, judged, human_left) == _summary(r.stdout) == (0, 2, 1)
    rec = _json(tmp_path)
    assert rec["reviewer_judged_count"] == judged
    assert len(rec["refused"]) - rec["reviewer_judged_count"] == human_left
