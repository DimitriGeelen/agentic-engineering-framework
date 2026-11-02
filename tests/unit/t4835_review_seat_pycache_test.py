"""T-4835 (832 field test F): a review seat that runs Python on an exported module must not void itself.

The seat's Python writes tools/__pycache__/*.pyc into the disposable export; the T-3986 fingerprint
(agents/termlink/termlink.sh _tree_fp) hashes every file, so the seat was voided for a benign side
effect. Fix: cmd_dispatch puts PYTHONDONTWRITEBYTECODE=1 in every review worker's signed env.json.
The fingerprint stays strict. Fakes only: the seat is a stub that runs real python3.
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path

_HERE = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(_HERE))
sys.path.insert(0, str(Path(__file__).resolve().parent))

from lib import verdict_ledger as vl  # noqa: E402
from _review_runtime import hermetic_review_env  # noqa: E402,F401  (autouse)
import t3580_round3_test as r3  # noqa: E402
from t3580_judge_cli_test import TID, repo  # noqa: E402,F401
import t3582_harness_kinds_test as hk  # noqa: E402
from t3582_harness_kinds_test import _brief, _stub_dir, hrepo  # noqa: E402,F401

TERMLINK = _HERE / "agents" / "termlink" / "termlink.sh"

#: the opencode stub, plus what the field seat did: run Python that imports a tracked module.
_PY_SEAT = hk._OPENCODE.replace(
    'mode = os.environ.get("STUB_MODE", "green")',
    'mode = os.environ.get("STUB_MODE", "green")\n'
    'import subprocess\n'
    'subprocess.run([sys.executable, "-c", "import sys; sys.path.insert(0, \'tools\'); import vw"], check=True)\n'
    'if "edit" in os.environ.get("STUB_EDIT", ""):\n'
    '    open("tools/real_edit.txt", "w").write("x")\n', 1)


def _commit_module(root: Path) -> None:
    (root / "tools").mkdir(exist_ok=True)
    (root / "tools" / "vw.py").write_text("VALUE = 1\n")
    env = {**os.environ, "GIT_AUTHOR_NAME": "Operator", "GIT_AUTHOR_EMAIL": "op@x.y",
           "GIT_COMMITTER_NAME": "Operator", "GIT_COMMITTER_EMAIL": "op@x.y"}
    for args in (["add", "tools/vw.py"], ["commit", "-q", "-m", "fixture: a python module"]):
        subprocess.run(["git", "-c", "core.hooksPath=/dev/null", *args], cwd=root, check=True,
                       capture_output=True, env=env)


def _run(root: Path, *, did: str, seat_env: dict, edit: bool = False):
    """cmd_dispatch's review leg with a chosen env.json, then the real run.sh."""
    rev = r3._head(root)
    w = root.parent / f"{root.name}-tl" / did
    w.mkdir(parents=True)
    brief = _brief(root, "opencode", rev)
    (w / "brief.md").write_text(brief.rstrip("\n") + "\n")
    (w / "prompt.md").write_text(vl.review_prompt(brief))
    (w / "task").write_text(TID)
    wb = _stub_dir(root) / "opencode"
    (w / "worker_bin").write_text(f"{wb}\n")
    (w / "worker_kind.txt").write_text("opencode\n")
    (w / "env.json").write_text(json.dumps({
        "FW_SIDECAR_AGENT_ID": did, "FW_REVIEW_REVISION": rev, "FW_REVIEW_WORKER": "1",
        "GIT_AUTHOR_NAME": "fw worker", "GIT_AUTHOR_EMAIL": "w@x.y",
        "GIT_COMMITTER_NAME": "fw worker", "GIT_COMMITTER_EMAIL": "w@x.y", **seat_env}))
    (w / "run.sh").write_text(r3._run_sh())
    r = subprocess.run([sys.executable, str(_HERE / "lib/verdict_ledger.py"), "register-dispatch",
                        "--dispatch-id", did, "--task", TID, "--task-type", "review",
                        "--revision", rev, "--wdir", str(w), "--worker-kind", "opencode",
                        "--worker-bin", str(wb), "--run-id", "", "--seat", ""],
                       cwd=root, env={**os.environ, "PROJECT_ROOT": str(root)},
                       capture_output=True, text=True)
    assert r.returncode == 0, r.stderr
    env = {k: v for k, v in os.environ.items()
           if not k.startswith(("FW_", "GIT_", "PYTHONDONTWRITEBYTECODE"))}
    env.update(PATH=f"{_stub_dir(root)}:{os.environ['PATH']}", STUB_MODE="green",
               STUB_EDIT="edit" if edit else "",
               LEDGER=str(_HERE / "lib/verdict_ledger.py"), WDIR_EXPECTED=str(w),
               _FW_RUNTIME_ENV_CLEAN="1")
    env.pop("PROJECT_ROOT", None)
    with (w.parent / f"{did}.out").open("w") as fh:
        subprocess.run(["bash", str(w / "run.sh"), did, str(root), str(w), "60", "", "review", ""],
                       stdout=fh, stderr=subprocess.STDOUT, env=env, timeout=180)
    return w


def _setup(root: Path) -> None:
    _commit_module(root)
    (_stub_dir(root) / "opencode").write_text(_PY_SEAT)
    (_stub_dir(root) / "opencode").chmod(0o755)


class TestPycacheDoesNotVoidTheSeat:
    def test_reproduction_without_the_env_var_the_seat_is_voided(self, hrepo):
        _setup(hrepo)
        w = _run(hrepo, did="judge-t-9200-r1-opencode-pyvoid00001", seat_env={})
        assert "modified the export it reviewed" in (w / "stderr.log").read_text()

    def test_with_the_signed_env_var_a_python_running_seat_stays_green(self, hrepo):
        _setup(hrepo)
        w = _run(hrepo, did="judge-t-9200-r1-opencode-pyfine00001",
                 seat_env={"PYTHONDONTWRITEBYTECODE": "1"})
        assert "modified the export it reviewed" not in (w / "stderr.log").read_text()
        assert (w / "exit_code").read_text().strip() == "0"

    def test_a_real_edit_still_voids_even_with_the_env_var(self, hrepo):
        _setup(hrepo)
        w = _run(hrepo, did="judge-t-9200-r1-opencode-pyedit00001",
                 seat_env={"PYTHONDONTWRITEBYTECODE": "1"}, edit=True)
        assert "modified the export it reviewed" in (w / "stderr.log").read_text()
        assert (w / "exit_code").read_text().strip() != "0"


class TestDispatcherSetsIt:
    def test_cmd_dispatch_puts_it_in_every_review_env_json(self):
        src = TERMLINK.read_text()
        block = src[src.index('if [ "$task_type" = "review" ]; then\n        local -a _env_keys'):]
        block = block[:block.index('rm -f "$wdir/env.sh"')]
        assert re.search(r"PYTHONDONTWRITEBYTECODE", block), "env.json writer must set it"

    def test_the_fingerprint_stays_strict_no_pyc_exclusion(self):
        src = TERMLINK.read_text()
        line = next(ln for ln in src.splitlines() if "_tree_fp() {" in ln)
        assert "pycache" not in line and "*.pyc" not in line


class TestVoidNamesWhatChanged:
    """T-4978 (ring20): a voided seat's cause was a guess (`__pycache__`?) because the check only
    compared one hash of the whole tree. The void now lists each changed path; the hash is unchanged."""

    def test_a_voided_seat_names_the_added_file(self, hrepo):
        _setup(hrepo)
        w = _run(hrepo, did="judge-t-9200-r1-opencode-pyname00001",
                 seat_env={"PYTHONDONTWRITEBYTECODE": "1"}, edit=True)
        log = (w / "stderr.log").read_text()
        assert "modified the export it reviewed" in log
        assert "export added: ./tools/real_edit.txt" in log

    def test_a_clean_seat_lists_nothing(self, hrepo):
        _setup(hrepo)
        w = _run(hrepo, did="judge-t-9200-r1-opencode-pyclean0001",
                 seat_env={"PYTHONDONTWRITEBYTECODE": "1"})
        assert "export added:" not in (w / "stderr.log").read_text()


def test_harness_brief_says_run_project_code_from_a_copy():
    """T-4978 (ring20 msg 2f1752c5): the app wrote its SQLite state under its own code root, inside
    the export. The brief now tells every harness seat to run project code from a copy in $TMPDIR."""
    for kind in ("codex", "opencode"):
        b = _brief(Path("."), kind, "abc")
        assert "Never run it in place" in b and 'cp -a . "$TMPDIR/run"' in b
    assert "Never run it in place" not in _brief(Path("."), "claude", "abc")


def _normaliser() -> str:
    src = TERMLINK.read_text()
    start = src.index("# Normalise every harness to one result.md")
    head = src.index("<<'PYEOF'", start)
    body = src[src.index("\n", head) + 1:]
    return body[:body.index("\nPYEOF")]


def test_a_harness_error_event_is_named_on_stderr(tmp_path):
    """T-4978: codex's 'usage limit' lived only in result.jsonl; the run showed exit 1 and an empty
    result. The normaliser now prints each error event to stderr, which run.sh appends to the log."""
    events = [{"type": "thread.started"},
              {"type": "error", "message": "You've hit your usage limit."},
              {"type": "turn.failed", "error": {"message": "You've hit your usage limit."}}]
    (tmp_path / "result.jsonl").write_text("\n".join(json.dumps(e) for e in events) + "\n")
    r = subprocess.run([sys.executable, "-", str(tmp_path), "codex"], input=_normaliser(),
                       capture_output=True, text=True)
    assert r.returncode == 0, r.stderr
    assert r.stderr.count("HARNESS ERROR (codex): You've hit your usage limit.") == 1


def test_a_clean_run_prints_no_harness_error(tmp_path):
    (tmp_path / "result.jsonl").write_text(json.dumps({"type": "text", "part": {"text": "ok"}}) + "\n")
    r = subprocess.run([sys.executable, "-", str(tmp_path), "opencode"], input=_normaliser(),
                       capture_output=True, text=True)
    assert r.returncode == 0 and "HARNESS ERROR" not in r.stderr
    assert (tmp_path / "result.md").read_text().strip() == "ok"


#: T-4999 (ring20 msg e49375be): a seat that records its environment and, like ring20's app, writes
#: to "$PROJECT_ROOT/data/state". Before the fix PROJECT_ROOT named the LIVE project.
_ENV_SEAT = hk._OPENCODE.replace(
    'mode = os.environ.get("STUB_MODE", "green")',
    'mode = os.environ.get("STUB_MODE", "green")\n'
    # the runtime's `--version` probe runs the binary with the run's own env; a real seat binary
    # writes nothing there, so the stub acts only when it runs as the seat
    'if a != ["--version"]:\n'
    '    open(os.path.join(os.environ["TMPDIR"], "seat-env.json"), "w").write(json.dumps('
    '{k: os.environ.get(k) for k in ("PROJECT_ROOT", "FRAMEWORK_ROOT")}))\n'
    'if a != ["--version"] and os.environ.get("STUB_EDIT") == "live":\n'
    '    d = os.path.join(os.environ["PROJECT_ROOT"], "data", "state")\n'
    '    os.makedirs(d, exist_ok=True)\n'
    '    open(os.path.join(d, "acks.json"), "w").write("[1]")\n', 1)


class TestSeatNeverSeesTheLiveProject:
    def _setup_env_seat(self, root):
        _commit_module(root)
        (_stub_dir(root) / "opencode").write_text(_ENV_SEAT)
        (_stub_dir(root) / "opencode").chmod(0o755)

    def test_seat_project_root_is_its_export_and_framework_root_is_unset(self, hrepo):
        self._setup_env_seat(hrepo)
        w = _run(hrepo, did="judge-t-9200-r1-opencode-envseat00001",
                 seat_env={"PYTHONDONTWRITEBYTECODE": "1"})
        env = json.loads((w / "tmp" / "seat-env.json").read_text())
        assert env["PROJECT_ROOT"] == str(w / "tree")
        assert env["FRAMEWORK_ROOT"] is None

    def test_an_app_writing_under_project_root_never_reaches_the_live_project(self, hrepo):
        self._setup_env_seat(hrepo)
        w2 = _run_live_edit(hrepo, did="judge-t-9200-r1-opencode-envlive00002")
        assert not (hrepo / "data").exists()                       # live project untouched
        log = (w2 / "stderr.log").read_text()
        assert "modified the export it reviewed" in log             # the write landed in the export
        assert (w2 / "exit_code").read_text().strip() != "0"


def _run_live_edit(root, did):
    """`_run` with STUB_EDIT=live for the seat."""
    import unittest.mock as um
    real = subprocess.run

    def run(cmd, *a, **kw):
        if isinstance(cmd, list) and cmd[:1] == ["bash"] and kw.get("env"):
            kw["env"] = {**kw["env"], "STUB_EDIT": "live"}
        return real(cmd, *a, **kw)
    with um.patch.object(subprocess, "run", run):
        return _run(root, did=did, seat_env={"PYTHONDONTWRITEBYTECODE": "1"})
