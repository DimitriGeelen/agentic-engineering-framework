"""T-5333 (G-137): a cited image is not viewed because a DIFFERENT file with the same basename was.

Before T-5333 `seat_viewed_images` keyed every attached/viewed image by its basename, so with
21 cited PNGs where the first (`a/screen.png`, attached) and the last (`b/screen.png`, over the
attachment cap) share a name, the unattached one read as viewed. Keys are now the path the
record gives; a basename-only view (bare name, a seat copy) counts only when that basename is
unique among the cited images, and is None (cannot tell) when it is not.
"""

import json
import struct
import sys
import zlib
from pathlib import Path

_HERE = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(_HERE))

from lib import review_seat_evidence as rse  # noqa: E402
from lib import vote_checker as vc  # noqa: E402

DID = "judge-t-9333-r3-4bca74fc9fa4"
A = ".context/working/judge-evidence/a/screen.png"
B = ".context/working/judge-evidence/b/screen.png"


def _png(value: int) -> bytes:
    def chunk(kind, data):
        return (struct.pack(">I", len(data)) + kind + data
                + struct.pack(">I", zlib.crc32(kind + data) & 0xffffffff))
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 1, 1, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(bytes([0, value, 0, 0]))) + chunk(b"IEND", b""))


def _codex_case(tmp_path):
    rels = [A] + [f".context/working/judge-evidence/a/shot{i}.png" for i in range(19)] + [B]
    tree = tmp_path / "tree"
    for i, rel in enumerate(rels):
        p = tree / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_bytes(_png(i))
    m = rse.image_manifest(rels, tree)
    d = tmp_path / DID
    d.mkdir()
    rse.write_manifest(d / rse.MANIFEST_NAME, m)
    return m, d


def _claude_record(d: Path, read_paths):
    d.mkdir(parents=True, exist_ok=True)
    ev: list = [{"type": "system", "subtype": "init"}]
    for p in read_paths:
        ev.append({"type": "assistant", "message": {"content": [
            {"type": "tool_use", "name": "Read", "input": {"file_path": p}}]}})
    ev.append({"type": "result", "subtype": "success"})
    (d / "result.jsonl").write_text("\n".join(json.dumps(e) for e in ev) + "\n")
    return d


def test_codex_same_basename_other_dir_is_not_viewed(tmp_path):
    m, d = _codex_case(tmp_path)
    assert len(m["attached"]) == 20 and m["not_attached"][0]["path"] == B
    views = vc.seat_viewed_images(d)
    assert views is not None
    over = m["not_attached"][0]
    assert over["sha256"] not in views["__attached_sha256__"]
    assert vc.image_viewed(views, B, over["sha256"]) is False
    assert vc.image_viewed(views, A, m["attached"][0]["sha256"]) is True
    assert vc.image_viewed(views, A) is True                     # by path, no hash
    assert B in views["__cited_paths__"]


def test_the_same_file_viewed_by_path_is_viewed(tmp_path):
    _, d = _codex_case(tmp_path)
    _claude_record(d, [f"/x/{DID}/tree/{B}"])
    views = vc.seat_viewed_images(d)
    assert vc.image_viewed(views, B) is True


def test_a_view_of_the_other_path_does_not_count(tmp_path):
    d = _claude_record(tmp_path / DID, [f"/x/tree/{A}"])
    views = vc.seat_viewed_images(d)
    assert vc.image_viewed(views, A, cited=[A, B]) is True
    assert vc.image_viewed(views, B, cited=[A, B]) is False


def test_ambiguous_basename_only_view_is_cannot_tell(tmp_path):
    d = _claude_record(tmp_path / DID, ["/tmp/copied/screen.png"])
    views = vc.seat_viewed_images(d)
    assert vc.image_viewed(views, A, cited=[A, B]) is None
    assert vc.image_viewed(views, B, cited=[A, B]) is None
    # unique basename: the old basename behaviour holds
    assert vc.image_viewed(views, A, cited=[A]) is True


def test_own_dispatch_copy_still_matches(tmp_path):
    copy = f"/x/.context/reviews/evidence/T-9333/screen-{DID}.png"
    d = _claude_record(tmp_path / DID, [copy])
    views = vc.seat_viewed_images(d)
    assert vc.image_viewed(views, A, cited=[A]) is True
    # a copy name carries no source directory: with two same-named cited images, cannot tell
    assert vc.image_viewed(views, A, cited=[A, B]) is None
    other = "judge-t-9333-r3-000000000000"
    d2 = _claude_record(tmp_path / "x" / DID, [f"/x/screen-{other}.png"])
    assert vc.image_viewed(vc.seat_viewed_images(d2), A, cited=[A]) is False
