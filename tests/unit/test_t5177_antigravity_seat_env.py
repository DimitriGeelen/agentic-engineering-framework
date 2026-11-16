"""T-5177 (operator 2026-11-16, option 1): the antigravity review seat runs through
`sudo -n -u dimitri-mint-dev -H …`, and sudo's env_reset dropped the TMPDIR and
PYTHONDONTWRITEBYTECODE the other seats get (T-4835). The seat ran Python in place, its .pyc files
changed the export, and the strict T-3986 fingerprint voided it. The launch now passes both through
/usr/bin/env inside sudo; the fingerprint stays strict.
"""
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
TERMLINK = ROOT / "agents/termlink/termlink.sh"
SEAT_USER = "dimitri-mint-dev"
PREFIX = ["/usr/bin/sudo", "-n", "-u", SEAT_USER, "-H", "/usr/bin/env"]


def _antigravity_line() -> str:
    return next(ln for ln in TERMLINK.read_text().splitlines()
                if "sudo -n -u dimitri-mint-dev" in ln and "--mode plan --sandbox" in ln)


def test_launch_passes_both_settings_inside_sudo():
    line = _antigravity_line()
    assert '/usr/bin/sudo -n -u dimitri-mint-dev -H /usr/bin/env TMPDIR="$SEAT_TMP" PYTHONDONTWRITEBYTECODE=1 "$WORKER_BIN"' in line


def test_fingerprint_stays_strict():
    line = next(ln for ln in TERMLINK.read_text().splitlines() if "_tree_list() {" in ln)
    assert "pycache" not in line and ".pyc" not in line


def _can_sudo_as_seat_user() -> bool:
    if not Path("/usr/bin/sudo").exists():
        return False
    try:
        return subprocess.run(["/usr/bin/sudo", "-n", "-u", SEAT_USER, "true"],
                              capture_output=True, timeout=10).returncode == 0
    except (OSError, subprocess.SubprocessError):
        return False


@pytest.mark.skipif(not _can_sudo_as_seat_user(), reason="host has no sudo route to the antigravity seat user")
def test_python_import_through_the_seat_form_leaves_the_export_unchanged():
    # the seat user cannot enter pytest's tmp_path (under root's private dir), as in the runtime
    # the run dir lives under /tmp/tl-dispatch; build the tree under /tmp directly
    import tempfile
    tmp_path = Path(tempfile.mkdtemp(prefix="t5177-", dir="/tmp"))
    try:
        _check(tmp_path)
    finally:
        shutil.rmtree(tmp_path, ignore_errors=True)


def _check(tmp_path: Path):
    tree, seat_tmp = tmp_path / "tree", tmp_path / "tmp"
    (tree / "pkg").mkdir(parents=True)
    (tree / "pkg/__init__.py").write_text("")
    (tree / "pkg/mod.py").write_text("X = 1\n")
    seat_tmp.mkdir()
    for p in (tmp_path, tree, tree / "pkg", seat_tmp):
        p.chmod(0o1777 if p == seat_tmp else 0o777)   # the seat user may write, as in the runtime
    before = sorted(str(p.relative_to(tree)) for p in tree.rglob("*"))
    r = subprocess.run(PREFIX + [f"TMPDIR={seat_tmp}", "PYTHONDONTWRITEBYTECODE=1",
                                 shutil.which("python3") or "/usr/bin/python3", "-c",
                                 "import tempfile, pkg.mod; print(tempfile.gettempdir())"],
                       cwd=str(tree), capture_output=True, text=True, timeout=60)
    assert r.returncode == 0, r.stderr
    assert r.stdout.strip() == str(seat_tmp)
    after = sorted(str(p.relative_to(tree)) for p in tree.rglob("*"))
    assert after == before, f"the seat's Python wrote into the export: {set(after) - set(before)}"
