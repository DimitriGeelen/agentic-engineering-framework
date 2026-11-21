"""T-5324 (G-137): a seat's view of one evidence image must not count as a view of another.

`_stem_match` exists so a seat's copy `<stem>-<dispatch id>.png` matches the cited image. Before
T-5324 it accepted ANY `-<suffix>`, so viewing `01-file-scripts-agent-listeners.png` counted as
viewing `01-file-scripts-agent.png`. The suffix must now be the review dispatch id
(`<name>-<12 hex>`, agents/termlink/termlink.sh), and exactly the seat's own id when its record
names it. Images the codex manifest lists as not attached (over the cap) are never attached.
"""

import hashlib
import json
import sys
from pathlib import Path

_HERE = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(_HERE))

from lib import review_seat_evidence as rse  # noqa: E402
from lib import vote_checker as vc  # noqa: E402

DID = "judge-t-9324-r3-0123456789ab"
OTHER_DID = "judge-t-9324-r3-ba9876543210"
SHOT = ".context/working/judge-evidence/T-9324/01-file-scripts-agent.png"
LONGER = ".context/working/judge-evidence/T-9324/01-file-scripts-agent-listeners.png"


def _claude_record(d: Path, read_paths):
    d.mkdir(parents=True, exist_ok=True)
    ev: list = [{"type": "system", "subtype": "init"}]
    for p in read_paths:
        ev.append({"type": "assistant", "message": {"content": [
            {"type": "tool_use", "name": "Read", "input": {"file_path": p}}]}})
    ev.append({"type": "result", "subtype": "success"})
    (d / "result.jsonl").write_text("\n".join(json.dumps(e) for e in ev) + "\n")
    return d


# ── _stem_match ──────────────────────────────────────────────────────────────────────────────

def test_prefix_sharing_evidence_images_do_not_match_either_direction():
    assert not vc._stem_match(LONGER, SHOT)
    assert not vc._stem_match(SHOT, LONGER)
    assert not vc._stem_match("x-foo.png", "x.png")
    assert not vc._stem_match("x.png", "x-foo.png")


def test_prefix_sharing_image_with_a_dispatch_suffix_does_not_match_with_known_id():
    copy_of_longer = f"01-file-scripts-agent-listeners-{DID}.png"
    assert not vc._stem_match(copy_of_longer, SHOT, DID)
    assert not vc._stem_match(SHOT, copy_of_longer, DID)


def test_a_real_seat_copy_matches_both_directions():
    copy = f"01-file-scripts-agent-{DID}.png"
    assert vc._stem_match(copy, SHOT)
    assert vc._stem_match(SHOT, copy)
    assert vc._stem_match(copy, SHOT, DID)
    assert vc._stem_match(SHOT, copy, DID)
    assert vc._stem_match(SHOT, SHOT)


def test_another_dispatch_copy_does_not_match_when_the_seat_id_is_known():
    assert not vc._stem_match(f"01-file-scripts-agent-{OTHER_DID}.png", SHOT, DID)


# ── image_viewed through a seat record ───────────────────────────────────────────────────────

def test_viewing_the_longer_image_is_not_viewing_the_shorter(tmp_path):
    d = _claude_record(tmp_path / DID, [f"/t/{LONGER}"])
    views = vc.seat_viewed_images(d)
    assert views["__dispatch_id__"] == DID
    assert vc.image_viewed(views, SHOT) is False
    assert vc.image_viewed(views, LONGER) is True


def test_viewing_the_seat_copy_is_viewing_the_cited_image(tmp_path):
    d = _claude_record(tmp_path / DID, [f"/x/.context/reviews/evidence/T-9324/01-file-scripts-agent-{DID}.png"])
    assert vc.image_viewed(vc.seat_viewed_images(d), SHOT) is True


def test_content_hash_match_still_counts():
    sha = hashlib.sha256(b"pixels").hexdigest()
    views = {"__attached_sha256__": [sha], "unrelated.png": True}
    assert vc.image_viewed(views, f"renamed-{DID}.png", sha) is True
    assert vc.image_viewed(views, "renamed.png", hashlib.sha256(b"other").hexdigest()) is False


# ── the attachment cap ───────────────────────────────────────────────────────────────────────

def _png(p: Path, payload: bytes):
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_bytes(b"\x89PNG\r\n\x1a\n" + payload)


def test_an_image_over_the_cap_is_not_attached_or_viewed(tmp_path):
    tree = tmp_path / "tree"
    rels = [f".context/working/judge-evidence/T-9324/{i:02d}-shot.png" for i in range(3)]
    for i, r in enumerate(rels):
        _png(tree / r, bytes([i]) * 16)
    m = rse.image_manifest(rels, tree, cap=2)
    assert len(m["attached"]) == 2 and len(m["not_attached"]) == 1
    wdir = tmp_path / DID
    wdir.mkdir()
    rse.write_manifest(wdir / rse.MANIFEST_NAME, m)
    views = vc.seat_viewed_images(wdir)
    over = m["not_attached"][0]
    assert all(a["path"] != over["path"] for a in vc.attached_images(wdir))
    assert over["sha256"] not in views["__attached_sha256__"]
    assert vc.image_viewed(views, over["path"], over["sha256"]) is False
    assert vc.image_viewed(views, rels[0]) is True


def test_a_malformed_manifest_listing_an_image_both_ways_does_not_attach_it(tmp_path):
    wdir = tmp_path / DID
    wdir.mkdir()
    ent = {"path": ".context/working/judge-evidence/T-9324/09-shot.png", "sha256": "ab" * 32}
    (wdir / rse.MANIFEST_NAME).write_text(json.dumps(
        {"schema": 1, "attached": [ent], "not_attached": [{**ent, "why": "over the cap of 1"}]}))
    views = vc.seat_viewed_images(wdir)
    assert vc.attached_images(wdir) == []
    assert vc.image_viewed(views, ent["path"], ent["sha256"]) is False
