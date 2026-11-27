"""T-5415: which designer maps ship to consumers, decided by the map itself.

Agreed with 832 (their T-1519 / T-1528, designer 0.52.0): a map's
`<aef:workflowMeta scope="framework|project">` says whose it is. `framework` maps
describe AEF's own lifecycles and ship to every vendoring project; `project` maps
(AEF's own development, e.g. aef-github-pr-intake) stay in the repo that holds them.
Absent or any other value = project: an unmarked map never ships by accident.

A map is a directory under .context/designer/projects/<name>/ with meta.json and
v<N>.bpmn files; its scope is read from the highest version listed in meta.json.

    python3 lib/designer_scope.py scope <projects_dir> <name>     -> framework|project
    python3 lib/designer_scope.py stay-home <projects_dir>        -> one name per line
    python3 lib/designer_scope.py mark <projects_dir> <name> <framework|project> [--note TEXT]

`stay-home` is what fw vendor excludes. `mark` writes a NEW version (copy of the
latest with the attribute set, thumbnail copied, meta.json entry appended), the
same shape a designer save produces; it never edits an existing version.
"""
from __future__ import annotations

import json
import re
import shutil
import sys
import time
from pathlib import Path

SCOPES = ("framework", "project")
_META_TAG = re.compile(r"<aef:workflowMeta\b[^>]*?/?>", re.S)
_SCOPE_ATTR = re.compile(r'\sscope\s*=\s*"([^"]*)"')


def latest_version(map_dir: Path) -> int | None:
    try:
        meta = json.loads((map_dir / "meta.json").read_text(encoding="utf-8"))
        return max(int(v["v"]) for v in meta.get("versions") or [])
    except (OSError, ValueError, KeyError, TypeError):
        return None


def scope_of(map_dir: Path) -> str:
    """framework | project for the map's latest version (anything unclear = project)."""
    v = latest_version(map_dir)
    if v is None:
        return "project"
    try:
        text = (map_dir / f"v{v}.bpmn").read_text(encoding="utf-8")
    except OSError:
        return "project"
    tag = _META_TAG.search(text)
    if not tag:
        return "project"
    m = _SCOPE_ATTR.search(tag.group(0))
    return "framework" if m and m.group(1) == "framework" else "project"


def stay_home(projects_dir: Path) -> list[str]:
    """Names of maps fw vendor must not ship (every map that is not framework)."""
    if not projects_dir.is_dir():
        return []
    return sorted(d.name for d in projects_dir.iterdir()
                  if d.is_dir() and scope_of(d) != "framework")


def mark(map_dir: Path, scope: str, note: str = "") -> int:
    """Save a new version of the map with scope set. Returns the new version number."""
    if scope not in SCOPES:
        raise ValueError(f"scope must be one of {SCOPES}, not {scope!r}")
    v = latest_version(map_dir)
    if v is None:
        raise ValueError(f"{map_dir}: no versions in meta.json")
    src = map_dir / f"v{v}.bpmn"
    text = src.read_text(encoding="utf-8")
    tag = _META_TAG.search(text)
    if not tag:
        raise ValueError(f"{src}: no <aef:workflowMeta> element to carry the scope")
    old = tag.group(0)
    if _SCOPE_ATTR.search(old):
        new = _SCOPE_ATTR.sub(f' scope="{scope}"', old, count=1)
    else:
        end = len(old) - (2 if old.endswith("/>") else 1)
        new = old[:end].rstrip() + f' scope="{scope}"' + old[end:]
    if new == old:
        return v
    nv = v + 1
    (map_dir / f"v{nv}.bpmn").write_text(text.replace(old, new, 1), encoding="utf-8")
    png = map_dir / f"v{v}.png"
    if png.exists():
        shutil.copyfile(png, map_dir / f"v{nv}.png")
    meta_path = map_dir / "meta.json"
    meta = json.loads(meta_path.read_text(encoding="utf-8"))
    meta.setdefault("versions", []).append({"v": nv, "note": note, "ts": int(time.time())})
    meta_path.write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8")
    return nv


def main(argv: list[str]) -> int:
    if len(argv) >= 4 and argv[1] == "scope":
        print(scope_of(Path(argv[2]) / argv[3]))
        return 0
    if len(argv) >= 3 and argv[1] == "stay-home":
        for name in stay_home(Path(argv[2])):
            print(name)
        return 0
    if len(argv) >= 5 and argv[1] == "mark":
        note = argv[argv.index("--note") + 1] if "--note" in argv else ""
        print(mark(Path(argv[2]) / argv[3], argv[4], note))
        return 0
    sys.stderr.write(__doc__ or "")
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
