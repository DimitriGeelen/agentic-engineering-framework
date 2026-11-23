"""T-3156: vendored executables must stay executable.

Two layers:

1. Hermetic (producer): `fw vendor self`'s copy helpers decided whether to copy a
   file on CONTENT alone (`diff -q` / `cmp -s`). A source whose only change was
   its exec bit (T-3051 chmod'ed agents/handover/discard-manifest.sh 644 -> 755
   with no content change) was never re-copied, so the vendored copy stayed 644
   while `--check` and `git status` both reported clean. These tests run the real
   helpers from lib/upgrade.sh against a throwaway FRAMEWORK_ROOT.

2. Repo state (marked): every tracked `.agentic-framework/X` whose source `X` is
   also tracked carries the same git mode, and the vendored bin/fw is 100755.
   `git status` cannot see this class: the wrong mode IS the recorded mode.
"""
import os
import shutil
import stat
import subprocess
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[2]
UPGRADE_SH = REPO / "lib" / "upgrade.sh"

# (helper, source subdir) for every helper that propagates the exec bit.
HELPERS = [
    ("_self_vendor_libs", "lib"),
    ("_self_vendor_agents", "agents"),
    ("_self_vendor_web", "web"),
    ("_self_vendor_tools", "tools"),
    ("_self_vendor_shim", "bin"),
]


def _is_exec(p: Path) -> bool:
    return bool(p.stat().st_mode & stat.S_IXUSR)


def _run_helper(root: Path, helper: str, dry_run: str) -> subprocess.CompletedProcess:
    script = (
        f'FRAMEWORK_ROOT="{root}"; GREEN=""; YELLOW=""; NC=""; RED=""; '
        f'FW_VENDOR_ALL=1; source "{UPGRADE_SH}"; {helper} {dry_run}'
    )
    return subprocess.run(
        ["bash", "-c", script], capture_output=True, text=True, cwd=root, timeout=60
    )


def _fixture(tmp_path: Path, subdir: str, src_exec: bool, dst_exec: bool):
    root = tmp_path / "fw"
    name = "probe.sh" if subdir != "tools" else "probe.py"
    src = root / subdir / name
    dst = root / ".agentic-framework" / subdir / name
    for p, ex in ((src, src_exec), (dst, dst_exec)):
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text("#!/usr/bin/env bash\necho ok\n")
        p.chmod(0o755 if ex else 0o644)
    return root, src, dst


@pytest.mark.parametrize("helper,subdir", HELPERS)
def test_mode_only_drift_is_detected_and_synced(tmp_path, helper, subdir):
    root, _, dst = _fixture(tmp_path, subdir, src_exec=True, dst_exec=False)
    dry = _run_helper(root, helper, "true")
    assert dry.returncode == 0, dry.stderr
    assert "would sync" in dry.stdout, (
        f"{helper}: same content, source 755 / vendored 644 must be reported as drift "
        f"(--check is the dry run). stdout={dry.stdout!r}"
    )
    real = _run_helper(root, helper, "false")
    assert real.returncode == 0, real.stderr
    assert _is_exec(dst), f"{helper}: vendored copy still not executable after sync"


@pytest.mark.parametrize("helper,subdir", HELPERS)
def test_exec_bit_removed_at_source_is_removed_in_copy(tmp_path, helper, subdir):
    root, _, dst = _fixture(tmp_path, subdir, src_exec=False, dst_exec=True)
    real = _run_helper(root, helper, "false")
    assert real.returncode == 0, real.stderr
    assert not _is_exec(dst), f"{helper}: vendored copy kept an exec bit the source dropped"


@pytest.mark.parametrize("helper,subdir", HELPERS)
def test_in_sync_tree_reports_nothing(tmp_path, helper, subdir):
    root, _, _ = _fixture(tmp_path, subdir, src_exec=True, dst_exec=True)
    dry = _run_helper(root, helper, "true")
    assert "would sync" not in dry.stdout


# ── Repo state ───────────────────────────────────────────────────────────────

def _tracked_modes():
    if shutil.which("git") is None or not (REPO / ".git").exists():
        pytest.skip("not a git checkout")
    out = subprocess.run(
        ["git", "-C", str(REPO), "ls-files", "-s"], capture_output=True, text=True, check=True
    ).stdout
    modes = {}
    for line in out.splitlines():
        meta, path = line.split("\t", 1)
        modes[path] = meta.split()[0]
    return modes


# Repo-state check (reads this checkout's git index, not a fixture).
def test_repo_vendored_modes_match_source():
    modes = _tracked_modes()
    prefix = ".agentic-framework/"
    mismatched = [
        f"{p} {m} (source {modes[p[len(prefix):]]})"
        for p, m in modes.items()
        if p.startswith(prefix) and p[len(prefix):] in modes and modes[p[len(prefix):]] != m
    ]
    assert not mismatched, "vendored mode differs from source:\n" + "\n".join(mismatched)


# Repo-state check (reads this checkout's git index, not a fixture).
def test_repo_vendored_fw_is_executable():
    modes = _tracked_modes()
    assert modes.get(".agentic-framework/bin/fw") == "100755"
    assert os.access(REPO / ".agentic-framework" / "bin" / "fw", os.X_OK)
