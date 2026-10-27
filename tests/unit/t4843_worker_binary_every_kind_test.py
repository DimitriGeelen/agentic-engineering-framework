"""T-4843 (832 msg 36c65b40, be.38 test E): every worker kind records which binary ran and its version.

Only the claude branch of run.sh wrote `worker binary: <path> (<version>)`; a codex or opencode
review seat left worker_bin and nothing else, so a stale harness binary was invisible after the
fact. These drive the REAL run.sh (t3582's harness `_launch`) with stub seats that answer
`--version`, and check stderr.log and meta.json. Fakes only.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

_HERE = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(_HERE))
sys.path.insert(0, str(Path(__file__).resolve().parent))

from _review_runtime import hermetic_review_env  # noqa: E402,F401  (autouse)
import t3580_round3_test as r3  # noqa: E402
from t3580_judge_cli_test import TID, repo  # noqa: E402,F401
import t3582_harness_kinds_test as hk  # noqa: E402
from t3582_harness_kinds_test import _brief, _stub_dir, hrepo  # noqa: E402,F401

VERSIONS = {"codex": "codex-cli 9.9.43", "opencode": "1.18.43"}


def _versioned(kind: str, root: Path) -> None:
    """Give the committed stub seat a --version answer (the seat itself is unchanged)."""
    stub = _stub_dir(root) / kind
    body = stub.read_text().replace(
        "a = sys.argv[1:]\n",
        f"a = sys.argv[1:]\nif a == ['--version']:\n    print({VERSIONS[kind]!r}); sys.exit(0)\n", 1)
    stub.write_text(body)


def _meta(w: Path) -> None:
    (w / "meta.json").write_text(json.dumps({"name": w.name, "project": "x", "status": "running"}, indent=2))


@pytest.mark.parametrize("kind", ["codex", "opencode"])
def test_a_harness_seat_records_its_binary_and_version(hrepo, kind):
    _versioned(kind, hrepo)
    rev = r3._head(hrepo)
    w, out, _rc = hk._launch(hrepo, did=f"judge-t-9200-r1-{kind}-wbver00001", kind=kind,
                             brief=_brief(hrepo, kind, rev), revision=rev, before_run=_meta)
    log = (w / "stderr.log").read_text()
    wb = str(_stub_dir(hrepo) / kind)
    assert f"worker binary: {wb} ({VERSIONS[kind]})" in log, out + log
    meta = json.loads((w / "meta.json").read_text())
    assert meta.get("worker_bin") == wb, meta
    assert meta.get("worker_version") == VERSIONS[kind], meta
    # The seat still ran and its completion was still signed: recording is not a launch gate.
    assert (w / "exit_code").read_text().strip() == "0", out + log
    assert (w / "finalised").read_text().startswith("signed:"), out + log
