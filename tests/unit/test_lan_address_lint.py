"""T-4516: tools/lan-address-lint.py refuses RFC1918 addresses in shipped paths.

The last test runs the lint over the real tree, so a new LAN address in a
shipped path turns the unit suite red (and the unit-suite audit with it).
"""
import importlib.util
import json
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
LINT = ROOT / "tools" / "lan-address-lint.py"

_spec = importlib.util.spec_from_file_location("lan_address_lint", LINT)
assert _spec is not None and _spec.loader is not None
lint = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(lint)

# Built from parts so this file never carries a literal the lint would flag.
A10 = ".".join(["10", "1", "2", "3"])
A172 = ".".join(["172", "20", "0", "9"])
A192 = ".".join(["192", "168", "10", "107"])


def _run(root, *args):
    return subprocess.run([sys.executable, str(LINT), "--root", str(root), *args],
                          capture_output=True, text=True)


@pytest.fixture
def repo(tmp_path):
    subprocess.run(["git", "init", "-q", str(tmp_path)], check=True)
    (tmp_path / "lib").mkdir()
    (tmp_path / "policy").mkdir()
    (tmp_path / "tests").mkdir()
    return tmp_path


def _add(repo, rel, text):
    p = repo / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text)
    subprocess.run(["git", "-C", str(repo), "add", rel], check=True)


@pytest.mark.parametrize("addr", [A10, A172, A192])
def test_detects_each_rfc1918_range(addr):
    assert lint.RFC1918.search(f"curl http://{addr}:3000/x")


@pytest.mark.parametrize("text", [
    "172.32.0.1",          # outside 172.16/12
    "172.15.0.1",
    "192.169.1.1",         # outside 192.168/16
    "8.8.8.8",
    "203.0.113.5",         # TEST-NET-3 placeholder
    "v10.2.3.4",           # version string
    "1.10.2.3.4",          # longer dotted run
    "10.2.3.4.5",
    "10.256.0.1",          # invalid octet
])
def test_ignores_non_lan_and_version_strings(text):
    assert not lint.RFC1918.search(text)


def test_flags_shipped_path_and_exits_1(repo):
    _add(repo, "lib/x.sh", f"HOST={A192}\n")
    r = _run(repo, "--json")
    assert r.returncode == 1
    found = json.loads(r.stdout)["findings"]
    assert found == [{"path": "lib/x.sh", "line": 1, "address": A192}]


def test_out_of_scope_paths_are_not_scanned(repo):
    _add(repo, "tests/fixture.txt", f"{A10}\n")
    _add(repo, ".context/handovers/LATEST.md", f"{A10}\n")
    r = _run(repo)
    assert r.returncode == 0, r.stdout + r.stderr


def test_allowlist_suppresses_by_path_and_address(repo):
    _add(repo, "lib/x.sh", f"A={A192}\nB={A10}\n")
    (repo / "policy" / "lan-address-allowlist.yaml").write_text(
        f'entries:\n  - path: "lib/x.sh"\n    address: "{A192}"\n    reason: "test"\n')
    r = _run(repo, "--json")
    assert r.returncode == 1
    assert [f["address"] for f in json.loads(r.stdout)["findings"]] == [A10]


def test_allowlist_entry_without_reason_is_refused(repo):
    _add(repo, "lib/x.sh", "clean\n")
    (repo / "policy" / "lan-address-allowlist.yaml").write_text(
        'entries:\n  - path: "lib/*"\n')
    r = _run(repo)
    assert r.returncode == 2
    assert "reason" in r.stderr


def test_real_tree_is_clean():
    r = _run(ROOT)
    assert r.returncode == 0, r.stdout + r.stderr
