#!/usr/bin/env python3
"""T-1873 — episodic corpus parse-check.

Walks .context/episodic/*.yaml and reports any that fail yaml.safe_load.
Exits 0 when the corpus is clean, 1 when any artefact rejects.

Used as a Verification gate command for T-1873 and as standalone audit
("am I sitting on more L-392 victims?"). The substrate fix prevents new
ones; this check catches regressions or pre-existing rot.
"""
from __future__ import annotations
import glob
import sys
import yaml


def main() -> int:
    bad: list[tuple[str, str]] = []
    ok = 0
    for path in sorted(glob.glob(".context/episodic/*.yaml")):
        try:
            with open(path) as fh:
                yaml.safe_load(fh)
            ok += 1
        except Exception as exc:
            bad.append((path, str(exc).split("\n")[0]))

    print(f"episodic corpus: {ok} OK, {len(bad)} FAIL")
    for path, err in bad:
        print(f"  FAIL {path}: {err}")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
