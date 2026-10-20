"""T-4437: external review seats run isolated by default (lib/review_isolation.py).

No external model is called: every seat binary here is a fake shell script written into
the test's tmp dir. The run dirs live under pytest's tmp_path, which is outside any git
work tree on this host; the in-repo refusal is tested against the real repo path.
"""
from __future__ import annotations

import json
import os
import stat
import subprocess
import sys
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "lib"))
import review_cost  # noqa: E402
import review_isolation as ri  # noqa: E402


def _fake(tmp: Path, name: str, body: str) -> str:
    p = tmp / "bin" / name
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text("#!/bin/sh\n" + body + "\n", encoding="utf-8")
    p.chmod(p.stat().st_mode | stat.S_IXUSR)
    return str(p)


def _backend(bid: str, **iso) -> dict:
    block = {"argv": ["{binary}", "--model", "{model}", "{prompt}"], "stdin": "closed",
             "tool_markers": [r"^TOOL\b"]}
    block.update(iso)
    return {"id": bid, "cost_class": "internal", "isolation": block}


@pytest.fixture
def outside(tmp_path, monkeypatch):
    if any((a / ".git").exists() for a in (tmp_path, *tmp_path.parents)):
        pytest.fail("tmp_path is inside a git work tree on this host; the test needs an outside dir")
    monkeypatch.setenv("HOME", str(tmp_path / "home"))  # no real ~/.ssh/config in the leak scan
    return tmp_path


# ── registry ─────────────────────────────────────────────────────────────────

def test_registry_has_isolation_for_the_three_external_seats():
    regs = {b["id"]: b for b in review_cost.load_registry(REPO / "policy" / "review-backends.yaml")}
    for bid in ("claude-code", "codex", "opencode"):
        assert "isolation" in regs[bid], bid
    oc = regs["opencode"]["isolation"]
    assert "--pure" in oc["argv"] and oc["stdin"] == "closed"
    assert oc["tools_off_config"]["env"] == "OPENCODE_CONFIG"
    assert all(v is False for v in oc["tools_off_config"]["content"]["tools"].values())
    cl = regs["claude-code"]["isolation"]["argv"]
    assert cl[cl.index("--tools") + 1] == "" and "--strict-mcp-config" in cl
    cx = regs["codex"]["isolation"]["argv"]
    assert cx[cx.index("--sandbox") + 1] == "read-only" and "{seat_dir}" in cx


@pytest.mark.parametrize("iso,frag", [
    ({"argv": ["claude", "{prompt}"]}, "must start with {binary}"),
    ({"argv": ["{binary}"]}, "must pass {prompt}"),
    ({"argv": ["{binary}", "{oops}", "{prompt}"]}, "unknown placeholder"),
    ({"argv": ["{binary}", "{prompt}"], "stdin": "inherit"}, "stdin must be `closed`"),
    ({"argv": ["{binary}", "{prompt}"], "tools_off_config": {"env": "X", "content": {"tools": {"read": True}}}},
     "every tool to false"),
])
def test_bad_isolation_block_is_refused(iso, frag):
    assert any(frag in e for e in ri.validate_isolation("x", iso))


def test_registry_loader_rejects_a_tools_on_profile(tmp_path):
    src = (REPO / "policy" / "review-backends.yaml").read_text(encoding="utf-8")
    bad = tmp_path / "r.yaml"
    bad.write_text(src.replace("read: false,", "read: true,", 1), encoding="utf-8")
    with pytest.raises(review_cost.CostError, match="every tool to false"):
        review_cost.load_registry(bad)


# ── refusals ─────────────────────────────────────────────────────────────────

def test_run_dir_inside_repo_is_refused_and_nothing_launches(outside):
    marker = outside / "launched"
    b = _backend("fake")
    binary = _fake(outside, "seat", f"touch {marker}")
    with pytest.raises(ri.IsolationError, match="inside the repo"):
        ri.run_panel([b], prompt="p", run_dir=REPO / ".context" / "scratch" / "t4437-x",
                     project_root=REPO, binaries={"fake": binary})
    assert not marker.exists()


def test_symlink_into_repo_is_refused(outside):
    link = outside / "link"
    link.symlink_to(REPO / ".context")
    with pytest.raises(ri.IsolationError, match="inside the repo"):
        ri.check_run_dir(link / "run", REPO)


def test_other_git_work_tree_is_refused(outside):
    (outside / "other" / ".git").mkdir(parents=True)
    with pytest.raises(ri.IsolationError, match="git work tree"):
        ri.check_run_dir(outside / "other" / "sub" / "run", REPO)


def test_backend_without_isolation_block_is_refused(outside):
    with pytest.raises(ri.IsolationError, match="no `isolation:` block"):
        ri.run_panel([{"id": "bare", "cost_class": "internal"}], prompt="p", run_dir=outside / "run",
                     project_root=REPO, binaries={"bare": "/bin/true"})


@pytest.mark.parametrize("text,kind", [
    ("reach it at 192.168.10.4 now", "IPv4 address"),
    ("ssh into build01.lan first", "internal hostname"),
    ("see nas.home.arpa", "internal hostname"),
])
def test_bundle_with_host_detail_is_refused(outside, text, kind):
    with pytest.raises(ri.IsolationError, match=kind):
        ri.run_panel([_backend("fake")], prompt=text, run_dir=outside / "run", project_root=REPO,
                     binaries={"fake": "/bin/true"})


def test_ssh_alias_is_a_leak(outside):
    (outside / "home" / ".ssh").mkdir(parents=True)
    (outside / "home" / ".ssh" / "config").write_text("Host ringmaster\n  User x\n", encoding="utf-8")
    assert ri.find_leaks("deploy to ringmaster tonight")
    assert not ri.find_leaks("version 1.8.12 shipped; see T-4435")


# ── the run ──────────────────────────────────────────────────────────────────

def test_seats_are_isolated_sequential_and_blind_to_each_other(outside):
    # Each fake seat records its cwd, stdin, env and what it can see of the other seat's output.
    out = outside / "results-final"
    probe = ('echo "cwd=$(pwd)"; echo "files=$(ls -A | tr "\\n" " ")"; '
             'if [ -t 0 ]; then echo stdin=tty; else echo "stdin=$(cat | wc -c)"; fi; '
             'echo "proj=${PROJECT_ROOT:-none} oc=${OPENCODE_CONFIG:-none}"; '
             f'echo "others=$(ls {out} 2>/dev/null | tr "\\n" " ")"; '
             'echo "args=$*"')
    a = _backend("seat-a", tools_off_config={"env": "OPENCODE_CONFIG",
                                             "content": {"tools": {"*": False, "read": False}}})
    a["model"] = "m-1"
    b = _backend("seat-b")
    bins = {"seat-a": _fake(outside, "a", probe), "seat-b": _fake(outside, "b", probe)}
    r = ri.run_panel([a, b], prompt="review this", run_dir=outside / "run", project_root=REPO,
                     out_dir=out, binaries=bins)
    ta = (out / "seat-a.md").read_text()
    tb = (out / "seat-b.md").read_text()
    assert f"cwd={outside / 'run' / 'seats' / 'seat-a'}" in ta
    assert "files=bundle.md " in ta and "files=bundle.md " in tb      # bundle only
    assert "stdin=0" in ta                                              # closed (/dev/null)
    assert "proj=none" in ta                                            # parent env not leaked
    assert "args=--model m-1 review this" in ta and "args=review this\n" in tb  # no model: flag dropped
    cfg = json.loads(Path(ta.split("oc=")[1].split()[0]).read_text())
    assert cfg["tools"] == {"*": False, "read": False}
    assert "oc=none" in tb
    assert "others=\n" in tb                                             # seat-a's review not visible yet
    assert not (outside / "run" / "results").exists()
    assert [s["label"] for s in r["seats"]] == ["independent", "independent"]


def test_seat_output_is_written_only_after_all_seats_finish(outside):
    out = outside / "out"
    spy = f'ls {out} 2>/dev/null | tr "\\n" " "'
    bins = {"s1": _fake(outside, "s1", "echo first"), "s2": _fake(outside, "s2", f'echo "seen=$({spy})"')}
    ri.run_panel([_backend("s1"), _backend("s2")], prompt="p", run_dir=outside / "run",
                 project_root=REPO, out_dir=out, binaries=bins)
    assert (out / "s2.md").read_text().strip() == "seen="


def test_tool_use_marks_a_seat_non_independent(outside):
    bins = {"clean": _fake(outside, "c", "echo verdict: agree"),
            "dirty": _fake(outside, "d", "echo 'TOOL read lib/spawn.py'; echo verdict"),
            "writer": _fake(outside, "w", "echo notes > scratch.txt; echo verdict")}
    r = ri.run_panel([_backend(k) for k in bins], prompt="p", run_dir=outside / "run",
                     project_root=REPO, binaries=bins)
    labels = {s["backend"]: s["label"] for s in r["seats"]}
    assert labels == {"clean": "independent", "dirty": "non-independent", "writer": "non-independent"}
    rec = json.loads((Path(r["out_dir"]) / "independence.json").read_text())
    assert {x["backend"]: x["seat_files_written"] for x in rec}["writer"] == ["scratch.txt"]


def test_cli_refuses_in_repo_run_dir_with_exit_2(tmp_path):
    p = subprocess.run([sys.executable, str(REPO / "lib" / "review_cost.py"), "isolated-run",
                        "--task", "T-4437", "--backends", "opencode", "--prompt-file", str(REPO / "FRAMEWORK.md"),
                        "--bundle", str(REPO / "FRAMEWORK.md"), "--run-dir", str(REPO / ".context" / "scratch" / "t4437-cli"),
                        "--dry-run"], capture_output=True, text=True,
                       env={**os.environ, "PROJECT_ROOT": str(REPO), "HOME": str(tmp_path)})
    assert p.returncode == 2 and "inside the repo" in p.stderr
    assert not (REPO / ".context" / "scratch" / "t4437-cli").exists()
