"""T-4844 (832 msg 36c65b40, be.38 test F): the opencode review seat exited 0 with no verdict.

run.sh launches opencode with cwd = the export and TMPDIR = SEAT_TMP ($WDIR/tmp), which is outside
the export. opencode's built-in `plan` agent has `external_directory "*" -> ask`, and headless
`opencode run` rejects every `ask`, so the seat could not use its temp dir. Fix: cmd_dispatch puts
OPENCODE_CONFIG_CONTENT (one allowance, SEAT_TMP only) in the opencode seat's signed env.json, and
a seat that exits 0 without a verdict is recorded as `no-verdict` (completion, stderr.log,
close_state) and reported that way by `fw reviewer judge`.

The stub below applies opencode's external_directory rule; one test checks the same config
against the real installed opencode (`opencode debug agent plan`, no model call).
"""
from __future__ import annotations

import fnmatch
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

_HERE = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(_HERE))
sys.path.insert(0, str(Path(__file__).resolve().parent))

from lib import verdict_ledger as vl  # noqa: E402
from lib.reviewer import judge_cli  # noqa: E402
from _review_runtime import hermetic_review_env  # noqa: E402,F401  (autouse)
import t3852_unavailable_seat_test as ut  # noqa: E402
from t3852_unavailable_seat_test import wdirs  # noqa: E402,F401
from t3580_judge_cli_test import TID, repo  # noqa: E402,F401
import t3582_harness_kinds_test as hk  # noqa: E402
from t3582_harness_kinds_test import _stub_dir, hrepo  # noqa: E402,F401
import t4835_review_seat_pycache_test as pc  # noqa: E402

TERMLINK = _HERE / "agents" / "termlink" / "termlink.sh"

#: The opencode stub plus opencode's external_directory rule: a path outside the cwd (the export)
#: is refused unless OPENCODE_CONFIG_CONTENT's agent.plan.permission.external_directory allows it.
#: Like the field seat, a seat that cannot use its TMPDIR gives up: exit 0, no verdict printed.
_PERM_SEAT = hk._OPENCODE.replace(
    'mode = os.environ.get("STUB_MODE", "green")',
    'mode = os.environ.get("STUB_MODE", "green")\n'
    'if a == ["--version"]:\n'   # T-4843's binary/version probe, not a seat run
    '    print("1.18.31")\n'
    '    sys.exit(0)\n'
    'import fnmatch\n'
    'def _allowed(path):\n'
    '    path = os.path.realpath(path)\n'
    '    if path == os.getcwd() or path.startswith(os.getcwd() + "/"):\n'
    '        return True\n'
    '    cfg = json.loads(os.environ.get("OPENCODE_CONFIG_CONTENT") or "{}")\n'
    '    rules = (((cfg.get("agent") or {}).get("plan") or {}).get("permission") or {}).get("external_directory") or {}\n'
    '    return any(v == "allow" and fnmatch.fnmatchcase(path, os.path.realpath(k.rstrip("*").rstrip("/")) + ("/*" if k.endswith("/*") else ""))\n'
    '               for k, v in rules.items())\n'
    'tmp_file = os.path.join(os.environ.get("TMPDIR", "/nonexistent"), "scratch.txt")\n'
    'outside = os.environ["STUB_OUTSIDE"]\n'
    'perm = {"tmpdir": _allowed(tmp_file), "outside": _allowed(outside)}\n'
    'if perm["tmpdir"]:\n'
    '    open(tmp_file, "w").write("x")\n'
    'if perm["outside"]:\n'
    '    open(outside, "w").write("x")\n'
    'open(w + ".perm", "w").write(json.dumps(perm))\n'
    'if not perm["tmpdir"]:\n'
    '    print(json.dumps({"type": "text", "sessionID": "ses_1", "part": {"type": "text", "text":\n'
    '          "The permission to access the temp directory was rejected; I cannot run the checks."}}))\n'
    '    sys.exit(0)\n', 1)


def _setup(root: Path) -> None:
    (_stub_dir(root) / "opencode").write_text(_PERM_SEAT)
    (_stub_dir(root) / "opencode").chmod(0o755)


def _run(root: Path, did: str, *, with_config: bool, outside: Path):
    os.environ["STUB_OUTSIDE"] = str(outside)
    try:
        w = root.parent / f"{root.name}-tl" / did
        seat_env = {"PYTHONDONTWRITEBYTECODE": "1"}
        if with_config:
            seat_env["OPENCODE_CONFIG_CONTENT"] = vl.opencode_seat_config(str(w / "tmp"))
        return pc._run(root, did=did, seat_env=seat_env)
    finally:
        os.environ.pop("STUB_OUTSIDE", None)


def _completion(w: Path) -> dict:
    return json.loads((w / "completion.json").read_text())


class TestTheSeatCanUseItsTemp:
    def test_reproduction_without_the_allowance_the_seat_ends_with_no_verdict(self, hrepo, tmp_path):
        _setup(hrepo)
        w = _run(hrepo, "judge-t-9200-r1-opencode-notmp000001", with_config=False,
                 outside=tmp_path / "outside.txt")
        perm = json.loads(Path(str(w) + ".perm").read_text())
        assert perm == {"tmpdir": False, "outside": False}, perm
        assert (w / "exit_code").read_text().strip() == "0"
        # loud, not merely `incomplete`
        assert _completion(w)["seat_state"] == "no-verdict"
        assert "NO-VERDICT" in (w / "stderr.log").read_text()
        assert (w / "close_state").read_text().strip() == "no-verdict"

    def test_with_the_allowance_the_seat_writes_its_temp_only_and_records_a_verdict(self, hrepo, tmp_path):
        _setup(hrepo)
        out = tmp_path / "outside.txt"
        w = _run(hrepo, "judge-t-9200-r1-opencode-tmpok000001", with_config=True, outside=out)
        perm = json.loads(Path(str(w) + ".perm").read_text())
        assert perm == {"tmpdir": True, "outside": False}, perm
        assert not out.exists()
        assert (w / "tmp" / "scratch.txt").is_file()
        err = (w / "stderr.log").read_text()
        assert "modified the export it reviewed" not in err, err[-2000:]
        assert "NO-VERDICT" not in err
        assert _completion(w)["seat_state"] == "verdict", _completion(w)
        assert (w / "close_state").read_text().strip() != "no-verdict"


class TestTheAllowanceIsExactlySeatTmp:
    def test_the_config_names_only_seat_tmp(self):
        cfg = json.loads(vl.opencode_seat_config("/x/w/tmp"))
        assert cfg == {"agent": {"plan": {"permission": {"external_directory": {
            "/x/w/tmp": "allow", "/x/w/tmp/*": "allow"}}}}}, cfg

    def test_the_ledger_accepts_the_exact_value_for_its_wdir(self, tmp_path):
        (tmp_path / "env.json").write_text(json.dumps(
            {"OPENCODE_CONFIG_CONTENT": vl.opencode_seat_config(str(tmp_path / "tmp"))}))
        assert vl._env_fault(tmp_path) == ""

    @pytest.mark.parametrize("other", ["/", "/etc", "{wdir}", "{wdir}/tree"])
    def test_the_ledger_refuses_any_other_allowance(self, tmp_path, other):
        (tmp_path / "env.json").write_text(json.dumps(
            {"OPENCODE_CONFIG_CONTENT": vl.opencode_seat_config(other.format(wdir=tmp_path))}))
        assert "OPENCODE_CONFIG_CONTENT" in vl._env_fault(tmp_path)

    def test_the_dispatcher_writes_it_for_the_opencode_kind_only(self):
        src = TERMLINK.read_text()
        block = src[src.index('printf \'export FW_REVIEW_WORKER=%q\\n\''):]
        block = block[:block.index("# T-3038")]
        assert '"$worker_kind" = "opencode"' in block, block
        assert "opencode-seat-config" in block and "OPENCODE_CONFIG_CONTENT" in block, block
        assert '"$wdir/tmp"' in block, block

    def test_run_sh_seat_tmp_is_the_same_path(self):
        assert 'SEAT_TMP="$WDIR/tmp"' in TERMLINK.read_text()

    @pytest.mark.skipif(shutil.which("opencode") is None, reason="opencode not installed")
    def test_the_real_opencode_plan_agent_takes_exactly_this_allowance(self, tmp_path):
        tree, seat_tmp = tmp_path / "tree", tmp_path / "tmp"
        tree.mkdir()
        seat_tmp.mkdir()
        env = {**os.environ, "TMPDIR": str(seat_tmp), "OPENCODE_DISABLE_PROJECT_CONFIG": "1"}

        def ext_rules(extra: dict) -> list[tuple[str, str]]:
            r = subprocess.run(["opencode", "debug", "agent", "plan"], cwd=tree, env={**env, **extra},
                               capture_output=True, text=True, timeout=120)
            assert r.returncode == 0, r.stderr[-500:]
            perms = json.loads(r.stdout)["permission"]
            return [(p["pattern"], p["action"]) for p in perms if p["permission"] == "external_directory"]

        before = ext_rules({})
        after = ext_rules({"OPENCODE_CONFIG_CONTENT": vl.opencode_seat_config(str(seat_tmp))})
        added = [r for r in after if r not in before]
        assert sorted(added) == sorted([(str(seat_tmp), "allow"), (f"{seat_tmp}/*", "allow")]), added
        assert ("*", "ask") in after   # everything else outside the export is still refused
        # and the last matching rule for a SEAT_TMP path is the allowance
        hit = [a for p, a in after if fnmatch.fnmatchcase(f"{seat_tmp}/x", p)]
        assert hit and hit[-1] == "allow", after


class TestJudgeNamesNoVerdict:
    def test_a_no_verdict_completion_is_reported_as_no_verdict(self, wdirs):
        ut._dead_seat(wdirs, "judge-nv-1", exit_code=0)
        (wdirs / "judge-nv-1" / "completion.json").write_text(json.dumps({"seat_state": "no-verdict"}))
        assert judge_cli._unavailable_reason("judge-nv-1") == "no-verdict (exit 0)"

    def test_the_close_state_marker_alone_is_enough(self, wdirs):
        ut._dead_seat(wdirs, "judge-nv-2", exit_code=0)
        (wdirs / "judge-nv-2" / "close_state").write_text("no-verdict\n")
        assert judge_cli._unavailable_reason("judge-nv-2") == "no-verdict (exit 0)"

    def test_a_known_cause_is_kept_beside_it(self, wdirs):
        ut._dead_seat(wdirs, "judge-nv-3", exit_code=0)
        (wdirs / "judge-nv-3" / "close_state").write_text("no-verdict\n")
        (wdirs / "judge-nv-3" / "stderr.log").write_text("tool was auto-denied\n")
        assert judge_cli._unavailable_reason("judge-nv-3") == \
            "no-verdict: tool permission auto-denied (headless) (exit 0)"

    def test_control_no_marker_stays_a_bare_exit(self, wdirs):
        ut._dead_seat(wdirs, "judge-nv-4", exit_code=0)
        assert judge_cli._unavailable_reason("judge-nv-4") == "exit 0"
