"""Copy the evidence a review brief cites into a harness seat's export (T-4933).

A harness reviewer (codex, opencode, antigravity) runs inside `$WDIR/tree`, a `git archive`
export of the reviewed revision that excludes `.context/` (T-3582). The brief names its
screenshots by `.context/...` paths, so inside the export they did not exist, and opencode
refuses reads outside its working directory: every render judge ended with no verdict.

This copies exactly the files the brief cites, from the two evidence areas only, to the
same relative path inside the export. run.sh runs it after the export and BEFORE the
export is fingerprinted, so the unchanged-export check (T-3986) still covers them.

    python3 lib/review_seat_evidence.py <brief.md> <project_dir> <tree> [--manifest <file>]
    python3 lib/review_seat_evidence.py --codex-args <manifest>

T-5309: codex never chose to open the screenshots in judge runs (T-5289), so the runtime
attaches them at launch instead (`codex exec -i <file>`). `--manifest` writes the copied
images (path inside the export, sha256) and which of them are attached — at most
MAX_ATTACHED, in brief order; the rest are listed as not attached. `--codex-args` prints the
`-i <file>` argv for the attached ones, NUL-separated, for run.sh to read with mapfile.
The checker (lib/vote_checker.py) counts an image matched by content hash in this manifest
as viewed: an attached image is in the seat's initial prompt by construction.
"""

from __future__ import annotations

import hashlib
import json
import os
import re
import shutil
import sys
from pathlib import Path

#: The evidence areas `fw reviewer judge` cites; nothing else under `.context/` is copied.
AREAS = (".context/working/judge-evidence/", ".context/visual/")
_CITED_RE = re.compile(r"`(\.context/[^`\s]+)`")
#: Images codex accepts on `-i` (its image loader decodes these).
IMAGE_EXTS = (".png", ".jpg", ".jpeg", ".gif", ".webp")
#: At most this many images are attached (argv and the model's context are both finite).
MAX_ATTACHED = 20
MANIFEST_NAME = "attached-images.json"


def cited(brief: str) -> list[str]:
    out: list[str] = []
    for rel in _CITED_RE.findall(brief):
        if rel.startswith(AREAS) and ".." not in Path(rel).parts and rel not in out:
            out.append(rel)
    return out


def copy_cited(brief: str, project: Path, tree: Path) -> list[str]:
    """Copy each cited evidence file; returns the relative paths copied.

    A path that is not a regular file, or that resolves outside its evidence area
    (a symlink out), is skipped."""
    project = project.resolve()
    copied = []
    for rel in cited(brief):
        src = project / rel
        area = next(a for a in AREAS if rel.startswith(a))
        try:
            real = src.resolve(strict=True)
        except OSError:
            continue
        if not real.is_file() or not str(real).startswith(str(project / area)):
            continue
        dst = tree / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(real, dst)
        os.chmod(dst, 0o644)
        copied.append(rel)
    return copied


def image_manifest(copied: list[str], tree: Path, cap: int = MAX_ATTACHED) -> dict:
    """The images among `copied` (relative paths inside `tree`), each with its sha256; the
    first `cap` are attached, the rest are named as not attached. A path holding a comma is
    never attached: codex splits `-i` values on commas."""
    attached, not_attached = [], []
    for rel in copied:
        if not rel.lower().endswith(IMAGE_EXTS):
            continue
        f = tree / rel
        try:
            sha = hashlib.sha256(f.read_bytes()).hexdigest()
        except OSError:
            continue
        ent = {"path": rel, "file": str(f), "sha256": sha}
        if len(attached) < cap and "," not in str(f):
            attached.append(ent)
        else:
            not_attached.append({**ent, "why": "comma in path" if "," in str(f)
                                 else f"over the cap of {cap}"})
    return {"schema": 1, "task": "T-5309", "how": "codex exec -i", "cap": cap,
            "attached": attached, "not_attached": not_attached}


def write_manifest(path: Path, manifest: dict) -> None:
    tmp = f"{path}.tmp.{os.getpid()}-{os.urandom(4).hex()}"
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, indent=1)
        fh.write("\n")
    os.replace(tmp, path)


def codex_image_argv(manifest: dict) -> list[str]:
    """`-i <file>` for every attached image, in manifest order."""
    out: list[str] = []
    for ent in manifest.get("attached") or []:
        f = str(ent.get("file") or "")
        if f:
            out += ["-i", f]
    return out


def main(argv: list[str]) -> int:
    if len(argv) == 2 and argv[0] == "--codex-args":
        try:
            manifest = json.loads(Path(argv[1]).read_text(encoding="utf-8"))
        except (OSError, ValueError):
            return 0                       # no manifest: nothing attached
        sys.stdout.write("".join(a + "\0" for a in codex_image_argv(manifest)))
        return 0
    manifest_out = None
    if len(argv) == 5 and argv[3] == "--manifest":
        manifest_out = Path(argv[4])
        argv = argv[:3]
    if len(argv) != 3:
        print("usage: review_seat_evidence.py <brief.md> <project_dir> <tree> [--manifest <file>]",
              file=sys.stderr)
        return 2
    brief, project, tree = Path(argv[0]), Path(argv[1]), Path(argv[2])
    copied = copy_cited(brief.read_text(errors="replace"), project, tree)
    print(f"review-seat-evidence: copied {len(copied)} cited file(s) into the export")
    if manifest_out is not None:
        m = image_manifest(copied, tree)
        write_manifest(manifest_out, m)
        print(f"review-seat-evidence: {len(m['attached'])} image(s) to attach, "
              f"{len(m['not_attached'])} not attached (T-5309)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
