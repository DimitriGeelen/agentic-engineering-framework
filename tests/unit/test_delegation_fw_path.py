#!/usr/bin/env python3
"""T-4250 — delegation output names the project-correct fw path.

A vendored consumer has only .agentic-framework/bin/fw, so a literal `bin/fw`
verification line exits 127 and P-011 refuses every delegated close.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from lib import delegation_cli  # noqa: E402

BARE = re.compile(r"(?<![\w./-])bin/fw")


def _layout(tmp_path, monkeypatch, *rels):
    for rel in rels:
        p = tmp_path / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text("#!/bin/sh\n")
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))


def test_vendored_consumer_uses_vendored_path(tmp_path, monkeypatch):
    _layout(tmp_path, monkeypatch, ".agentic-framework/bin/fw")
    line = delegation_cli.verification_line("T-1")
    assert line.startswith(".agentic-framework/bin/fw reviewer T-1 ")
    assert not BARE.search(line)
    assert delegation_cli._fw() == ".agentic-framework/bin/fw"


def test_framework_repo_keeps_bin_fw(tmp_path, monkeypatch):
    _layout(tmp_path, monkeypatch, "bin/fw")
    assert delegation_cli.verification_line("T-1").startswith("bin/fw reviewer T-1 ")


def test_consumer_with_tracked_shim_keeps_bin_fw(tmp_path, monkeypatch):
    _layout(tmp_path, monkeypatch, "bin/fw", ".agentic-framework/bin/fw")
    assert delegation_cli._fw() == "bin/fw"
