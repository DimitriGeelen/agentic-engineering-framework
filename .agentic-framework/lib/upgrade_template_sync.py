#!/usr/bin/env python3
"""T-3955 / T-3956: never overwrite a consumer's own version of a template-owned file.

`fw upgrade` step 7 (.claude/commands/resume.md) and step 7b (the doorbell+mail toolkit:
.claude/commands/*.md, scripts/*.sh) treated ANY difference from the template as drift and
replaced the consumer's file (.bak beside it). That cannot tell a stale stock copy (update
it) from a deliberately customised one, or from a NEWER one — 010-termlink is the origin of
the toolkit, and upgrading to 1.8.3 replaced 15 of its files with older copies plus its
customised /resume. Same class as T-3850 (fw vendor), and the same answer: a stamp of what
the framework last wrote, and a manifest a consumer can use to claim files.

Decision per file (one line printed: STATUS <rel> — reason):
  OK          identical to the template (the stamp is refreshed)
  CREATED     missing → written
  UPDATED     equal to the hash the framework last wrote → a stock copy → replaced
  KEPT        anything else, including "no stamp yet" → left alone; the template is written
              beside it as <file>.upstream for the operator to compare
  PRESERVED   listed under `project_files:` in .fwvendor-preserve.yaml → left alone; .upstream
  WOULD-*     --dry-run: what would happen; nothing is written

Usage: upgrade_template_sync.py <target_dir> <template_src> <rel_dst> [--dry-run] [--exec]
"""
from __future__ import annotations

import fnmatch
import hashlib
import json
import os
import shutil
import sys
from pathlib import Path

STAMP = ".context/upgrade-template-stamp.json"
MANIFEST = ".fwvendor-preserve.yaml"


def _sha(p: Path) -> str:
    return hashlib.sha256(p.read_bytes()).hexdigest()


def _stamp(target: Path) -> dict:
    try:
        return json.loads((target / STAMP).read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}


def _write_stamp(target: Path, rel: str, sha: str) -> None:
    st = _stamp(target)
    if st.get(rel) == sha:
        return
    st[rel] = sha
    p = target / STAMP
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(st, indent=1, sort_keys=True) + "\n", encoding="utf-8")


def _preserved(target: Path, rel: str) -> bool:
    p = target / MANIFEST
    if not p.is_file():
        return False
    try:
        import yaml
        data = yaml.safe_load(p.read_text(encoding="utf-8")) or {}
    except Exception:
        return False
    for it in (data.get("project_files") or []) if isinstance(data, dict) else []:
        pat = it.get("path") if isinstance(it, dict) else it
        if pat and fnmatch.fnmatch(rel, str(pat).lstrip("./")):
            return True
    return False


def decide(target: Path, src: Path, rel: str, dry: bool, executable: bool) -> tuple[str, str]:
    dst = target / rel
    tsha = _sha(src)
    pre = "WOULD-" if dry else ""

    def write(to: Path) -> None:
        if dry:
            return
        to.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(src, to)
        if executable:
            os.chmod(to, 0o755)

    if not dst.exists():
        write(dst)
        if not dry:
            _write_stamp(target, rel, tsha)
        return pre + "CREATED", "from template"
    dsha = _sha(dst)
    if dsha == tsha:
        if not dry:
            _write_stamp(target, rel, tsha)
        return "OK", "matches template"
    upstream = dst.with_name(dst.name + ".upstream")
    if _preserved(target, rel):
        write(upstream)
        return pre + "PRESERVED", f"listed in {MANIFEST} project_files; template at {upstream.name}"
    last = _stamp(target).get(rel)
    if last and last == dsha:
        write(dst)
        if not dry:
            _write_stamp(target, rel, tsha)
        return pre + "UPDATED", "stock copy (unchanged since the framework wrote it)"
    write(upstream)
    why = "differs from what the framework last wrote" if last else "no record of what the framework wrote"
    return pre + "KEPT", f"customised or newer ({why}); template at {upstream.name} — compare, then copy it over to accept"


def main(argv: list[str]) -> int:
    flags = {a for a in argv if a.startswith("--")}
    args = [a for a in argv if not a.startswith("--")]
    if len(args) != 3:
        print(__doc__.strip().splitlines()[-1], file=sys.stderr)
        return 2
    target, src, rel = Path(args[0]), Path(args[1]), args[2]
    status, why = decide(target, src, rel, "--dry-run" in flags, "--exec" in flags)
    print(f"{status} {rel} — {why}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
