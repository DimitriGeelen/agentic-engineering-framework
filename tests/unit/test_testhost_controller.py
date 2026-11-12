"""T-5009 phase 3: fw testhost controller against the stub hypervisor.

Every test uses a throwaway git repo (or, for the end-to-end case, this repo's own HEAD with
base HEAD~1), a private state dir and a private stub pool. Nothing reaches the network: the
"GitHub remote" for --pr is a local bare repo.
"""
import importlib.util
import json
import os
import subprocess
import sys
import textwrap
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("testhost", ROOT / "lib" / "testhost.py")
assert SPEC and SPEC.loader
testhost = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(testhost)

GIT_ENV = {"GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@invalid", "GIT_COMMITTER_NAME": "t",
           "GIT_COMMITTER_EMAIL": "t@invalid", "GIT_CONFIG_NOSYSTEM": "1"}


def git(repo, *args):
    p = subprocess.run(["git", "-c", "core.hooksPath=/dev/null", *args], cwd=str(repo),
                       env=dict(os.environ, **GIT_ENV), capture_output=True, text=True)
    assert p.returncode == 0, p.stderr
    return p.stdout.strip()


def write(repo, rel, text):
    f = Path(repo) / rel
    f.parent.mkdir(parents=True, exist_ok=True)
    f.write_text(textwrap.dedent(text))


@pytest.fixture
def env(tmp_path, monkeypatch):
    """A fixture repo with a passing tests/lint, a bare 'github' remote, private dirs."""
    repo = tmp_path / "repo"
    repo.mkdir()
    git(repo, "init", "-q", "-b", "main")
    write(repo, "tests/lint/ok.bats", """\
        #!/usr/bin/env bats
        @test "lint ok" { true; }
        """)
    write(repo, "README", "base\n")
    git(repo, "add", "-A")
    git(repo, "commit", "-q", "-m", "base")
    remote = tmp_path / "remote.git"
    git(tmp_path, "init", "-q", "--bare", str(remote))
    git(repo, "remote", "add", "gh", str(remote))
    monkeypatch.setenv("PROJECT_ROOT", str(repo))
    monkeypatch.setenv("FRAMEWORK_ROOT", str(ROOT))
    monkeypatch.setenv("FW_TESTHOST_DIR", str(tmp_path / "state"))
    monkeypatch.setenv("TESTHOST_STUB_POOL", str(tmp_path / "pool"))
    monkeypatch.setenv("FW_TESTHOST_GIT_REMOTE", "gh")
    monkeypatch.delenv("TESTHOST_STUB_GUEST", raising=False)
    monkeypatch.delenv("FW_TESTHOST_TIMEOUT", raising=False)
    monkeypatch.delenv("FW_TESTHOST_SERIAL_CAP_BYTES", raising=False)
    return {"repo": repo, "remote": remote, "tmp": tmp_path, "pool": tmp_path / "pool",
            "state": tmp_path / "state", "mp": monkeypatch}


def change(e, name, body, pr=None):
    """Commit a changed bats test on a branch off main; optionally publish it as pull/N/head."""
    repo = e["repo"]
    git(repo, "checkout", "-q", "-B", f"b-{name}", "main")
    write(repo, f"tests/unit/{name}.bats", f"""\
        #!/usr/bin/env bats
        @test "{name}" {{ {body}; }}
        """)
    git(repo, "add", "-A")
    git(repo, "commit", "-q", "-m", name)
    sha = git(repo, "rev-parse", "HEAD")
    git(repo, "checkout", "-q", "main")
    if pr is not None:
        git(repo, "push", "-q", "gh", f"{sha}:refs/pull/{pr}/head")
    return sha


def guest(e, name, script):
    f = e["tmp"] / f"{name}.sh"
    f.write_text("#!/usr/bin/env bash\n" + textwrap.dedent(script))
    f.chmod(0o755)
    e["mp"].setenv("TESTHOST_STUB_GUEST", f"bash {f}")
    return f


def pool_empty(e):
    return not any(p.name.startswith("vm-") for p in e["pool"].iterdir())


def rows(e):
    return [json.loads(x) for x in (e["state"] / "runs.jsonl").read_text().splitlines()]


def test_passing_pr_is_passed(env):
    change(env, "good", "true", pr=7)
    row = testhost.run(pr=7, base="main")
    assert row["state"] == "passed", row
    assert row["pr"] == 7 and row["backend"] == "stub"
    res = json.loads((env["state"] / row["run_id"] / "result.json").read_text())
    assert [p["name"] for p in res["phases"]] == ["lint", "changed"]
    serial = (env["state"] / row["run_id"] / "serial.log").read_text()
    assert "== PHASE changed end rc=0" in serial
    assert "ok 1 good" in serial
    assert pool_empty(env)
    assert git(env["repo"], "rev-parse", "refs/testhost/pr-7")


def test_failing_changed_bats_is_failed(env):
    sha = change(env, "bad", "false")
    row = testhost.run(commit=sha, base="main")
    assert row["state"] == "failed", row
    res = json.loads((env["state"] / row["run_id"] / "result.json").read_text())
    assert {p["name"]: p["rc"] for p in res["phases"]} == {"lint": 0, "changed": 1}
    assert pool_empty(env)


def test_timeout_stops_and_empties_pool(env):
    sha = change(env, "good", "true")
    guest(env, "sleeper", 'echo booting; sleep 60\n')
    row = testhost.run(commit=sha, base="main", timeout=3)
    assert row["state"] == "timeout", row
    assert row["seconds"] < 20
    assert pool_empty(env)
    assert "booting" in (env["state"] / row["run_id"] / "serial.log").read_text()


@pytest.mark.parametrize("name,script,reason", [
    ("noresult", 'echo "no result"\n', "no result.json"),
    ("oversized", 'head -c 70000 /dev/zero | tr "\\0" a > "$2/result.json"\n', "larger than"),
    ("badschema", 'echo \'{"version":1,"status":"passed","phases":[],"started":"x","finished":"y",'
                  '"extra":"../../etc"}\' > "$2/result.json"\n', "schema"),
    ("liar", 'echo \'{"version":1,"status":"passed","phases":[{"name":"lint","rc":1,"seconds":1}],'
             '"started":"2026-01-01T00:00:00Z","finished":"2026-01-01T00:00:01Z"}\' > "$2/result.json"\n',
     "claims passed"),
    ("symlink", 'ln -s /etc/hostname "$2/result.json"\n', "no result.json"),  # reader drops it
])
def test_bad_or_missing_result_is_infra_error(env, name, script, reason):
    sha = change(env, "good", "true")
    guest(env, name, script)
    row = testhost.run(commit=sha, base="main")
    assert row["state"] == "infra-error", row
    assert reason in row["reason"]
    assert not (env["state"] / row["run_id"] / "result.json").exists()
    assert pool_empty(env)


def test_serial_is_sanitised_and_truncated(env, monkeypatch):
    sha = change(env, "good", "true")
    cap = 4096
    monkeypatch.setenv("FW_TESTHOST_SERIAL_CAP_BYTES", str(cap))
    # each line ~60 bytes incl. escapes; 2x the cap of raw output
    guest(env, "ansi", f"""\
        for i in $(seq 1 {2 * cap // 40}); do
          printf '\\033[31mred\\033[0m \\033]0;title\\007bell\\a cr\\r nul-free %05d\\n' "$i"
        done
        """)
    row = testhost.run(commit=sha, base="main")
    log = (env["state"] / row["run_id"] / "serial.log").read_bytes()
    assert row["truncated"] is True
    assert row["serial_bytes"] >= 2 * cap
    assert f"[testhost: serial log truncated at {cap} bytes]".encode() in log
    assert len(log) <= cap + 100
    assert b"\x1b" not in log and b"\x07" not in log and b"\r" not in log
    assert b"red bell cr nul-free 00001" in log
    assert row["state"] == "infra-error"   # this guest wrote no result
    assert pool_empty(env)


def test_destroy_runs_when_controller_raises_mid_run(env):
    sha = change(env, "good", "true")
    guest(env, "sleeper", "sleep 60\n")
    seen = {}

    def boom(backend, vm_id):
        seen["vm"] = vm_id
        assert backend.list_pool() == [vm_id]
        raise RuntimeError("controller fault mid-run")

    row = testhost.run(commit=sha, base="main", on_started=boom)
    assert seen["vm"]
    assert row["state"] == "infra-error" and "controller fault" in row["reason"]
    assert pool_empty(env)


def test_destroy_runs_on_ctrl_c(env):
    sha = change(env, "good", "true")
    guest(env, "sleeper", "sleep 60\n")

    def interrupt(_b, _v):
        raise KeyboardInterrupt

    row = testhost.run(commit=sha, base="main", on_started=interrupt)
    assert row["state"] == "infra-error" and "interrupted" in row["reason"]
    assert pool_empty(env)


def test_leftover_vm_in_pool_is_infra_error(env):
    sha = change(env, "good", "true")
    stray = env["pool"] / "vm-000000000000"
    stray.mkdir(parents=True)
    row = testhost.run(commit=sha, base="main")
    assert row["state"] == "infra-error"
    assert "pool not empty" in row["reason"] and "vm-000000000000" in row["reason"]


def test_proxmox_backend_refuses_until_configured(env):
    # T-5098: phase 4 exists now; with no TESTHOST_PVE_* configuration it still refuses.
    with pytest.raises(testhost.TesthostError, match="not configured: missing TESTHOST_PVE_URL"):
        testhost.get_backend("proxmox")


def test_cli_list_and_watch(env):
    sha = change(env, "good", "true")
    p = subprocess.run([sys.executable, str(ROOT / "lib" / "testhost.py"), "run", "--commit", sha,
                        "--base", "main", "--json"], capture_output=True, text=True)
    assert p.returncode == 0, p.stderr
    row = json.loads(p.stdout)
    out = subprocess.run([sys.executable, str(ROOT / "lib" / "testhost.py"), "list"],
                         capture_output=True, text=True).stdout
    assert row["run_id"] in out and "passed" in out
    w = subprocess.run([sys.executable, str(ROOT / "lib" / "testhost.py"), "watch",
                        row["run_id"]], capture_output=True, text=True, timeout=30)
    assert w.returncode == 0 and "== PHASE lint end rc=0" in w.stdout
    assert "state passed" in w.stdout


def test_commit_head_of_this_repo_end_to_end(tmp_path, monkeypatch):
    """`fw testhost run --commit HEAD --base HEAD~1` on this repo: pr-checks.sh through the stub."""
    if subprocess.run(["git", "-C", str(ROOT), "rev-parse", "--verify", "HEAD~1"],
                      capture_output=True).returncode != 0:
        pytest.fail("this repo has no HEAD~1 to use as a base")
    state, pool = tmp_path / "state", tmp_path / "pool"
    e = dict(os.environ, PROJECT_ROOT=str(ROOT), FRAMEWORK_ROOT=str(ROOT),
             FW_TESTHOST_DIR=str(state), TESTHOST_STUB_POOL=str(pool))
    e.pop("TESTHOST_STUB_GUEST", None)
    p = subprocess.run([str(ROOT / "bin" / "fw"), "testhost", "run", "--commit", "HEAD",
                        "--base", "HEAD~1", "--backend", "stub", "--json"],
                       env=e, capture_output=True, text=True, timeout=900)
    row = json.loads(p.stdout.strip().splitlines()[-1])
    assert row["state"] in ("passed", "failed"), row      # a verdict, not an infra failure
    assert p.returncode == testhost.EXIT_CODES[row["state"]]
    runs = [json.loads(x) for x in (state / "runs.jsonl").read_text().splitlines()]
    assert runs[-1]["run_id"] == row["run_id"]
    assert "== PHASE lint start ==" in (state / row["run_id"] / "serial.log").read_text()
    assert not any(x.name.startswith("vm-") for x in pool.iterdir())
