#!/usr/bin/env python3
"""Parse the YAML frontmatter of every task file in .tasks/{active,completed}/.

Used by verification (P-011) on tasks that touch frontmatter shape — the underlying
invariant the BVP estimator (T-1922) was tripping over when duplicate keys snuck in.

Exit 0 iff every frontmatter parses. Prints `FAIL <path>: <error>` for each
parse failure and exits 1.

Origin: T-2149 — T-2116 had duplicate `components:` keys, breaking
`fw bvp estimate all --dry-run`. The estimator's --dry-run is the wrong
verification command (reviewer correctly flags `--dry-run` as skip-as-pass);
this script tests the underlying invariant directly.
"""
import glob
import sys

import yaml


def main() -> int:
    errors = 0
    paths = sorted(
        glob.glob(".tasks/active/T-*.md") + glob.glob(".tasks/completed/T-*.md")
    )
    for f in paths:
        try:
            yaml.safe_load(open(f).read().split("---", 2)[1])
        except Exception as e:
            print(f"FAIL {f}: {e}")
            errors += 1
    if errors:
        print(f"\n{errors} frontmatter parse failure(s) across {len(paths)} task files.")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
