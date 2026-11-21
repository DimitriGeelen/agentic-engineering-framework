#!/usr/bin/env python3
"""T-5341 (Risk R-NEW-3): is every committed codex render green backed by a viewing peer?

codex can vote green on a render criterion without opening the screenshots (T-5316). In a
single-seat run such a vote is not checkable (T-5327); in a rung-5 panel attached-only proof
still counts. This read-only check lists every committed verdict row whose seat is codex, whose
outcome is green and whose criterion class is render-surface, and looks at the other seats'
rows in the same run on the same criterion (same run_id and ac). The green is BACKED when at
least one of them is green AND shows a logged view of the images. "Logged view" is
lib/vote_checker's rule, not a new one:

  * a row with a recorded vote check (verdict/1): an image item for that criterion whose
    vote_checker.view_proof is 'logged';
  * an older row with no check: the seat's run record (its dispatch dir) read with
    vote_checker.seat_viewed_images, reduced by vote_checker.logged_views, shows a view of one
    of the row's evidence images (vote_checker.image_viewed is True).

Attached-at-launch proof is not a logged view. A peer whose record cannot be found cannot show
a view. Starts no review dispatch and writes nothing.

Usage: python3 lib/codex_render_backing.py audit [--root DIR] [--json]
  exit 0 = every codex render green is backed (or there are none); 1 = some are not;
  2 = the check could not run.
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from lib import vote_checker  # noqa: E402

VERDICTS = ".context/reviews/verdicts.jsonl"
DISPATCHES = ".context/reviews/review-dispatches.jsonl"
RENDER = "render-surface"
CODEX = "codex"


def seat_of(row: dict) -> str:
    """The seat kind a row's reviewer names: `reviewer-…:codex` → 'codex'."""
    r = str(row.get("reviewer") or "")
    return r.rsplit(":", 1)[1].strip().lower() if ":" in r else ""


def _jsonl(text: str) -> list[dict]:
    out = []
    for line in text.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            v = json.loads(line)
        except ValueError:
            continue
        if isinstance(v, dict):
            out.append(v)
    return out


def committed_rows(root: Path) -> list[dict]:
    """The verdict rows as committed at HEAD (uncommitted rows never count). Raises on a git
    failure other than 'the file is not in HEAD' (then there are no committed rows)."""
    p = subprocess.run(["git", "-C", str(root), "show", f"HEAD:{VERDICTS}"],
                       capture_output=True, text=True)
    if p.returncode != 0:
        err = p.stderr.strip()
        if "does not exist" in err or "exists on disk, but not in" in err:
            return []
        raise RuntimeError(f"git show HEAD:{VERDICTS} failed: {err or p.returncode}")
    return _jsonl(p.stdout)


def wdirs(root: Path) -> dict[str, str]:
    """dispatch id → working dir, from the review-dispatch registry (last one wins)."""
    out: dict[str, str] = {}
    f = Path(root) / DISPATCHES
    if f.is_file():
        for r in _jsonl(f.read_text(encoding="utf-8", errors="replace")):
            if r.get("dispatch_id") and r.get("wdir"):
                out[str(r["dispatch_id"])] = str(r["wdir"])
    return out


def seat_record(root: Path, dispatch_id: str, registry: dict[str, str]) -> Path | None:
    """The seat's dispatch dir: the registry's wdir, else .context/dispatch/<id>, else
    /tmp/tl-dispatch/<id>. None when none exists."""
    if not dispatch_id:
        return None
    for c in (registry.get(dispatch_id), Path(root) / ".context/dispatch" / dispatch_id,
              Path("/tmp/tl-dispatch") / dispatch_id):
        if c and Path(c).is_dir():
            return Path(c)
    return None


def _images(row: dict) -> list[str]:
    return [str(e) for e in (row.get("evidence") or []) if vote_checker._is_image(str(e))]


def view_logged(row: dict, root: Path, registry: dict[str, str]) -> tuple[bool, str]:
    """(True, how) when the row shows a logged view of its images; (False, why) otherwise."""
    check = row.get("check")
    if isinstance(check, dict) and isinstance(check.get("criteria"), dict):
        c = check["criteria"].get(str(row.get("ac"))) or {}
        imgs = [it for it in (c.get("items") or []) if isinstance(it, dict)
                and it.get("kind") == "image"]
        proofs = [vote_checker.view_proof(it) for it in imgs]
        if "logged" in proofs:
            return True, "logged view in the recorded vote check"
        if not imgs:
            return False, "its vote check cites no image"
        if proofs and all(p == "attached" for p in proofs):
            return False, "attached-only proof"
        return False, "its vote check shows no view of the images"
    rec = seat_record(root, str(row.get("dispatch_id") or ""), registry)
    if rec is None:
        return False, "its run record is not on disk (cannot show a view)"
    views = vote_checker.seat_viewed_images(rec)
    if views is None:
        return False, "its run record cannot tell what it opened"
    lv = vote_checker.logged_views(views)
    imgs = _images(row)
    if any(vote_checker.image_viewed(lv, img, None, imgs) is True for img in imgs):
        return True, "logged view in its run record"
    if any(vote_checker.image_viewed(views, img, None, imgs) is True for img in imgs):
        return False, "attached-only proof"
    return False, "its run record shows no view of the images"


def analyse(rows: list[dict], root: Path, registry: dict[str, str] | None = None) -> dict:
    """{'count', 'backed', 'unbacked': [{task, ac, id, run_id, why}], 'greens': [...]}"""
    registry = wdirs(root) if registry is None else registry
    greens = [r for r in rows if seat_of(r) == CODEX and r.get("outcome") == "green"
              and r.get("criterion_class") == RENDER]
    out = {"count": len(greens), "backed": 0, "unbacked": [], "not_counting": [], "greens": []}
    for g in greens:
        peers = [r for r in rows if r is not g and r.get("run_id") and r.get("run_id") == g.get("run_id")
                 and str(r.get("ac")) == str(g.get("ac")) and seat_of(r) not in ("", CODEX)]
        entry = {"task": g.get("task"), "ac": g.get("ac"), "id": g.get("id"),
                 "run_id": g.get("run_id"), "rung": g.get("rung")}
        whys = []
        backer = None
        for p in peers:
            if p.get("outcome") != "green":
                whys.append(f"{seat_of(p)} voted {p.get('outcome')}")
                continue
            ok, how = view_logged(p, root, registry)
            if ok:
                backer = f"{seat_of(p)} ({how})"
                break
            whys.append(f"{seat_of(p)} green but {how}")
        if backer:
            out["backed"] += 1
            entry["backed_by"] = backer
        else:
            entry["why"] = "; ".join(whys) if whys else "no peer seat in the run"
            ok, reasons = vote_checker.checkable(g, render=True)
            if not ok and any(vote_checker.ATTACHED_ONLY in r for r in reasons):
                # T-5341: a vote T-5327 already refuses to count closes nothing, so it is
                # reported, not WARNed — a WARN that can never clear teaches people to skip it.
                entry["why"] += " (the vote is not checkable and does not count, T-5327)"
                entry["counts"] = False
                out["not_counting"].append(entry)
            else:
                out["unbacked"].append(entry)
        out["greens"].append(entry)
    return out


def report_lines(res: dict) -> list[str]:
    lines = [f"UNBACKED {u['task']} AC{u['ac']} ({u['id']}, {u['run_id']}): {u['why']}"
             for u in res["unbacked"]]
    tail = f"codex render greens: {res['count']}, backed by a viewing peer: {res['backed']}"
    if res.get("not_counting"):
        tail += f", not counted (not checkable, T-5327): {len(res['not_counting'])}"
    lines.append(tail)
    return lines


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=(__doc__ or "").split("\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    a = sub.add_parser("audit")
    a.add_argument("--root", default=os.environ.get("PROJECT_ROOT") or ".")
    a.add_argument("--json", action="store_true")
    args = ap.parse_args(argv)
    try:
        root = Path(args.root).resolve()
        res = analyse(committed_rows(root), root)
    except Exception as e:  # noqa: BLE001 — never a silent pass
        print(f"ERROR {type(e).__name__}: {e}")
        return 2
    if args.json:
        print(json.dumps(res, indent=1))
    else:
        print("\n".join(report_lines(res)))
    return 0 if not res["unbacked"] else 1


if __name__ == "__main__":
    sys.exit(main())
