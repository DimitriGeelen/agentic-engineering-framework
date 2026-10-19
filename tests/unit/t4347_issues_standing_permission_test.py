"""T-4347: ISSUES_DECISIONS_STANDING_PERMISSION — decision comments without per-comment approval.
Reuses the T-4077 fake-gh fixtures; no network."""
import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).parent))
from t4077_issues_comment_test import calls, env, rows, run  # noqa: F401,E402

REF = "standing-permission:operator-2026-10-19"
KEY = "FW_ISSUES_DECISIONS_STANDING_PERMISSION"
DECISIONS = [("accepted", ["--task", "T-1"]), ("needs-info", ["--text", "q"]),
             ("duplicate", ["--text", "T-9"]), ("not-planned", ["--text", "r"])]


@pytest.mark.parametrize("stage,extra", DECISIONS)
def test_key_0_refuses_without_approval(env, stage, extra, tmp_path):
    e, stub, ledger = env
    # An empty env value falls back to .framework.yaml: point it at a project
    # with none, not at this checkout (which sets the key to 1).
    proj = tmp_path / "proj"
    proj.mkdir()
    for v in ("0", ""):
        r = run(dict(e, PROJECT_ROOT=str(proj), **{KEY: v}), "comment", "86", "--stage", stage, *extra)
        assert r.returncode != 0 and "--approved-by-operator" in r.stderr
    assert not (stub / "body.txt").exists() and rows(ledger) == []


@pytest.mark.parametrize("stage,extra", DECISIONS)
def test_key_1_posts_and_records_provenance(env, stage, extra):
    e, stub, ledger = env
    r = run(dict(e, **{KEY: "1"}, CLAUDECODE="1"), "comment", "86", "--stage", stage, *extra)
    assert r.returncode == 0, r.stderr
    row = rows(ledger)[-1]
    assert row["stage"] == stage and row["approved_by"] == REF
    assert "personally looks at every issue" in (stub / "body.txt").read_text()
    # idempotent per (issue, stage)
    before = len(calls(stub))
    assert "already posted" in run(dict(e, **{KEY: "1"}), "comment", "86", "--stage", stage, *extra).stdout
    assert len(calls(stub)) == before


def test_key_from_framework_yaml(env, tmp_path):
    e, stub, ledger = env
    root = tmp_path / "proj"
    root.mkdir()
    (root / ".framework.yaml").write_text("ISSUES_DECISIONS_STANDING_PERMISSION: 1  # ruling\n")
    e = dict(e, PROJECT_ROOT=str(root))
    e.pop(KEY, None)
    assert run(e, "comment", "86", "--stage", "accepted", "--task", "T-1").returncode == 0
    assert rows(ledger)[-1]["approved_by"] == REF
    assert run(dict(e, **{KEY: "0"}), "comment", "87", "--stage", "accepted", "--task", "T-1").returncode != 0


def test_explicit_approval_path_unchanged_and_template_stage_has_no_provenance(env):
    e, stub, ledger = env
    e = dict(e, **{KEY: "1"})
    assert run(e, "comment", "86", "--stage", "accepted", "--task", "T-1",
               "--approved-by-operator", "op-ok").returncode == 0
    assert run(e, "comment", "87", "--stage", "in-progress", "--task", "T-1").returncode == 0
    assert "approved_by" not in rows(ledger)[0] and "approved_by" not in rows(ledger)[1]
