#!/usr/bin/env python3
"""T-5079 (832 proposal) — a project may declare its own generated release paths in
RELEASE_ARTIFACT_PATHS, so a release commit that names every shipped task does not make
their reviewer verdicts stale. The list exempts paths from a review gate, so it is read
only from .framework.yaml as committed at HEAD, and unsafe entries are ignored + WARNed.

Fixture repos only (the T-3580 round-3 harness, as in t4779); no real task is judged.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))
sys.path.insert(0, str(Path(__file__).resolve().parent))

from lib import verdict_ledger as vl  # noqa: E402
from _review_runtime import hermetic_review_env  # noqa: E402,F401  (autouse)
from t3580_judge_cli_test import TID, _git, _ident, repo  # noqa: E402,F401
from t3580_round3_test import _why, prod  # noqa: E402,F401
from t4779_stale_review_release_test import _reviewed, _task_commit  # noqa: E402

KIT = "docs/authoring-kit/calibration-records/"


def _declare(root, value, commit=True):
    y = root / ".framework.yaml"
    old = y.read_text() if y.exists() else "project_name: fixture\n"
    lines = [ln for ln in old.splitlines() if not ln.startswith("RELEASE_ARTIFACT_PATHS:")]
    y.write_text("\n".join(lines + [f"RELEASE_ARTIFACT_PATHS: {value}"]) + "\n")
    if commit:
        _git(root, "add", ".framework.yaml")
        _git(root, "commit", "-q", "-m", "config: declare release artifacts", env=_ident("Operator"))


def _release(root):
    _task_commit(root, {KIT + "0.29.0.yaml": f"version: 0.29.0\ntasks: [{TID}]\n"})


def test_without_a_declaration_the_generated_file_withdraws(prod):
    # The 832 case as it was: the release adds a generated file outside dist/.
    _reviewed(prod)
    _release(prod)
    assert "stale-review" in _why(prod)


def test_a_declared_artifact_path_does_not_withdraw(prod):
    _declare(prod, KIT)
    _reviewed(prod)
    _release(prod)
    assert _why(prod) == ""


def test_negative_control_source_in_the_same_commit_still_withdraws(prod):
    _declare(prod, KIT)
    _reviewed(prod)
    _task_commit(prod, {KIT + "0.29.0.yaml": "v\n", "notes.md": "notes v2\n"})
    assert "touches notes.md" in _why(prod)


def test_an_uncommitted_declaration_does_not_count(prod):
    _declare(prod, KIT, commit=False)
    _reviewed(prod)
    _release(prod)
    assert "stale-review" in _why(prod)


def test_an_env_var_does_not_count(prod, monkeypatch):
    monkeypatch.setenv("FW_RELEASE_ARTIFACT_PATHS", KIT)
    _reviewed(prod)
    _release(prod)
    assert "stale-review" in _why(prod)


def test_unsafe_entries_are_refused_with_a_reason(prod):
    _declare(prod, "docs/ lib/gen/ /abs/x/ ../up/x/ docs/*/ src/out/ " + KIT + " .tasks/x/ notes")
    ok, bad = vl.declared_release_artifacts(prod)
    assert ok == (KIT,)
    refused = {e for e, _ in bad}
    assert refused == {"docs/", "lib/gen/", "/abs/x/", "../up/x/", "docs/*/", "src/out/", ".tasks/x/", "notes"}


def test_a_refused_entry_exempts_nothing(prod):
    _declare(prod, "docs/")
    _reviewed(prod)
    _task_commit(prod, {"docs/anything.md": "x\n"})
    assert "stale-review" in _why(prod)


def test_audit_shows_accepted_and_warns_refused(prod):
    _declare(prod, KIT + " docs/")
    rc, lines = vl.audit(prod)
    text = "\n".join(lines)
    assert "INFO release artifacts declared" in text and KIT in text
    assert "WARN RELEASE_ARTIFACT_PATHS entry 'docs/' ignored" in text
