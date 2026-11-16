"""T-5178: the screenshots a harness seat cites are frozen as per-dispatch copies, as a claude seat
makes them (T-4514). Citing the shared captures broke the row's evidence hash as soon as the next
run of the task re-captured the same page (V-20261116-2647c78a, V-20261116-b36dd239)."""
import hashlib
import inspect
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from lib import verdict_ledger as vl  # noqa: E402

DID = "judge-t-9-r5-antigravity-abc123"
CAP = ".context/working/judge-evidence/T-9/01-page.png"
VIS = ".context/visual/T-9/state@1024.png"


def _sha(p: Path) -> str:
    return hashlib.sha256(p.read_bytes()).hexdigest()


def _setup(root: Path):
    for rel, data in ((CAP, b"capture-v1"), (VIS, b"visual-v1")):
        (root / rel).parent.mkdir(parents=True, exist_ok=True)
        (root / rel).write_bytes(data)


def test_copies_are_per_dispatch_and_identical(tmp_path):
    _setup(tmp_path)
    out = vl._freeze_seat_evidence(tmp_path, "T-9", DID, [CAP, VIS])
    assert out == [f"{vl.REPORT_DIR}/T-9/01-page-{DID}.png", f"{vl.REPORT_DIR}/T-9/state@1024-{DID}.png"]
    for src, dst in zip((CAP, VIS), out):
        assert _sha(tmp_path / src) == _sha(tmp_path / dst)     # sha256-matched checks still pass


def test_copy_survives_the_original_being_overwritten(tmp_path):
    _setup(tmp_path)
    copy = tmp_path / vl._freeze_seat_evidence(tmp_path, "T-9", DID, [CAP])[0]
    before = _sha(copy)
    (tmp_path / CAP).write_bytes(b"capture-v2-from-the-next-run")
    assert _sha(copy) == before


def test_an_existing_copy_is_never_overwritten(tmp_path):
    _setup(tmp_path)
    dst = tmp_path / vl._freeze_seat_evidence(tmp_path, "T-9", DID, [CAP])[0]
    dst.write_bytes(b"already-recorded")
    (tmp_path / CAP).write_bytes(b"newer")
    vl._freeze_seat_evidence(tmp_path, "T-9", DID, [CAP])
    assert dst.read_bytes() == b"already-recorded"


def test_runtime_records_and_commits_the_frozen_copies():
    src = inspect.getsource(vl._record_for_worker_locked)
    seen_at = src.index("_seat_named_screenshots(")
    freeze_at = src.index("_freeze_seat_evidence(")
    record_at = src.index("record(task, ac")
    assert seen_at < freeze_at < record_at
    assert "touched.extend(seen)" in src
