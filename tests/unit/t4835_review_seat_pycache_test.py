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
