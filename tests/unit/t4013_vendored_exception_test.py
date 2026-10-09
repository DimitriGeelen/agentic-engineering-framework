"""T-4013 (T-4010 decision leg 1): in a consumer that does not track .agentic-framework/, the judge
trusts a vendored judge-relevant file only when its bytes match an operator-approved exception in
.framework.yaml AS COMMITTED at the reviewed revision. Everything else stays untrusted."""
from __future__ import annotations

import hashlib
import json
import subprocess
import sys
from pathlib import Path

import pytest

FW_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(FW_ROOT))

from lib import verdict_ledger as vl  # noqa: E402

KINDS = 'DISPATCH_WORKER_KINDS="claude ollama-loop"\n'
REL = Path("agents/termlink/termlink.sh")


def _git(root, *a):
    subprocess.run(["git", "-C", str(root), *a], check=True, capture_output=True, text=True)


@pytest.fixture
def consumer(tmp_path, monkeypatch):
    root = tmp_path / "consumer"
    (root / ".agentic-framework" / "lib").mkdir(parents=True)
    (root / ".agentic-framework" / REL).parent.mkdir(parents=True)
    (root / ".agentic-framework" / REL).write_text(KINDS)
    (root / ".gitignore").write_text(".agentic-framework/\n")
    (root / ".framework.yaml").write_text("project_name: consumer\n")
    _git(root, "init", "-q")
    _git(root, "-c", "user.name=t", "-c", "user.email=t@t", "add", "-A")
    _git(root, "-c", "user.name=t", "-c", "user.email=t@t", "commit", "-qm", "init")
    # the ledger runs from the consumer's vendored copy, so the framework is inside the project
    monkeypatch.setattr(vl, "_HERE", root / ".agentic-framework" / "lib")
    return root


def _commit(root, msg="pin"):
    _git(root, "-c", "user.name=t", "-c", "user.email=t@t", "commit", "-qam", msg)


def _approve(root, reason="approved for test"):
    return vl.approve_exception(root, REL, reason, "operator:t")


def test_untracked_vendored_copy_is_untrusted_and_the_fix_is_named(consumer):
    text, why = vl._committed_blob(consumer, "", REL)
    assert text == "" and "no approved exception" in why and "exception-approve" in why
    assert vl.launchable_kinds(consumer) == set()


def test_uncommitted_approval_counts_for_nothing(consumer):
    _approve(consumer)
    assert vl.launchable_kinds(consumer) == set()


def test_committed_approval_trusts_exactly_those_bytes(consumer):
    ent = _approve(consumer)
    assert ent["sha256"] == hashlib.sha256(KINDS.encode()).hexdigest()
    _commit(consumer)
    text, where = vl._committed_blob(consumer, "", REL)
    assert text == KINDS and "approved exception" in where
    assert vl.launchable_kinds(consumer) == {"claude", "ollama-loop"}


def test_an_edit_after_approval_is_refused(consumer):
    _approve(consumer)
    _commit(consumer)
    (consumer / ".agentic-framework" / REL).write_text('DISPATCH_WORKER_KINDS="claude mine"\n')
    text, why = vl._committed_blob(consumer, "", REL)
    assert text == "" and "differs from the approved exception" in why
    assert vl.launchable_kinds(consumer) == set()


def test_an_approval_is_read_at_the_reviewed_revision(consumer):
    _git(consumer, "rev-parse", "HEAD")
    before = subprocess.run(["git", "-C", str(consumer), "rev-parse", "HEAD"],
                            capture_output=True, text=True).stdout.strip()
    _approve(consumer)
    _commit(consumer)
    assert vl.launchable_kinds(consumer, before) == set()
    assert vl.launchable_kinds(consumer, "HEAD") == {"claude", "ollama-loop"}


def test_malformed_or_foreign_entries_refuse(consumer):
    good = hashlib.sha256(KINDS.encode()).hexdigest()
    for bad in ([{"path": "bin/fw", "sha256": good, "approved_by": "x"}],
                [{"path": str(REL), "sha256": "nothex", "approved_by": "x"}],
                [{"path": str(REL), "sha256": good}],
                [{"path": str(REL), "sha256": good, "approved_by": "x"}] * 2,
                "not-a-list"):
        (consumer / ".framework.yaml").write_text("project_name: consumer\nvendored_exceptions: "
                                                  + json.dumps(bad) + "\n")
        _commit(consumer, "bad")
        assert vl.launchable_kinds(consumer) == set(), bad


def test_a_symlink_out_of_the_project_is_not_the_consumers_copy(consumer, tmp_path):
    outside = tmp_path / "elsewhere.sh"
    outside.write_text(KINDS)
    p = consumer / ".agentic-framework" / REL
    p.unlink()
    p.symlink_to(outside)
    with pytest.raises(vl.VerdictRefused):
        _approve(consumer)
    assert vl._committed_blob(consumer, "", REL)[0] == ""


def test_approve_refuses_a_file_that_is_not_judge_relevant(consumer):
    with pytest.raises(vl.VerdictRefused):
        vl.approve_exception(consumer, Path("bin/fw"), "x", "operator:t")


def test_reapproval_replaces_the_entry_and_keeps_the_rest_of_the_file(consumer):
    (consumer / ".framework.yaml").write_text("project_name: consumer\n# keep me\nversion: 1.8.8\n")
    _approve(consumer)
    (consumer / ".agentic-framework" / REL).write_text('DISPATCH_WORKER_KINDS="claude"\n')
    _approve(consumer, "second")
    text = (consumer / ".framework.yaml").read_text()
    assert "# keep me" in text and "version: 1.8.8" in text
    assert text.count("vendored_exceptions:") == 1 and text.count(vl._EXC_COMMENT) == 1
    import yaml
    ents = yaml.safe_load(text)["vendored_exceptions"]
    assert len(ents) == 1 and ents[0]["reason"] == "second"


def test_cli_approve_is_operator_only(consumer, monkeypatch):
    monkeypatch.setattr(vl, "_root", lambda: consumer)
    monkeypatch.setenv("CLAUDECODE", "1")
    assert vl._cli(["exception-approve", str(REL), "--reason", "x"]) == 1
    assert "vendored_exceptions" not in (consumer / ".framework.yaml").read_text()


def test_cli_check_reports_untrusted_then_approved(consumer, monkeypatch, capsys):
    monkeypatch.setattr(vl, "_root", lambda: consumer)
    assert vl._cli(["exception-check"]) == 1
    assert "untrusted" in capsys.readouterr().out
    monkeypatch.delenv("CLAUDECODE", raising=False)
    assert vl._cli(["exception-approve", str(REL), "--reason", "x"]) == 0
    _commit(consumer)
    vl._cli(["exception-check"])
    out = capsys.readouterr().out
    assert "approved-exception  agents/termlink/termlink.sh" in out
