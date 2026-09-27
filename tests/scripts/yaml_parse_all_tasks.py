#!/usr/bin/env python3
"""Verify every .tasks/{active,completed}/*.md frontmatter parses as YAML.

Used as a verification gate by T-1469 (block-style components emit fix) and
referenced by future tasks that touch task-file YAML emit.

Exit non-zero if any file fails to parse.
"""
from __future__ import annotations
import pathlib
import sys

import yaml


def main() -> int:
    root = pathlib.Path(__file__).resolve().parents[2]
    files = list((root / ".tasks/active").glob("*.md")) + list(
        (root / ".tasks/completed").glob("*.md")
    )
    errs = 0
    for p in files:
        txt = p.read_text()
        if not txt.startswith("---"):
            continue
        try:
            yaml.safe_load(txt.split("---", 2)[1])
        except Exception as e:  # noqa: BLE001 — surface every parse error
            print(f"PARSE ERROR {p.relative_to(root)}: {str(e)[:100]}")
            errs += 1
    print(f"Checked {len(files)} task files; {errs} parse errors")
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main())
