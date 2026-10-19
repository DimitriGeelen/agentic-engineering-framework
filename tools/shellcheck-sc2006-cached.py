#!/usr/bin/env python3
"""T-4375: print shellcheck's SC2006 findings for FILES, caching per file content.

tests/lint/no-backticks-in-quoted-strings.bats (T-3089) asks shellcheck for SC2006
on every tracked bash source. That lint runs inside `check_invariant_suite`, which
is in the structure section the pre-push gate runs, and it took ~69 s of it:
shellcheck alone spends ~52 s on bin/fw and ~35 s on audit.sh. Almost none of
those files change between two pushes, so almost all of that work repeats an
answer that is already known.

The answer for one file is a function of three things only: the shellcheck
version, the path (it is printed in every finding), and the file's bytes. No
`-x`, so no sourced file is read. Those three form the cache key, so a cached
answer is the answer shellcheck would give now. Anything that changes one of
them is a miss and runs shellcheck again.

A result is cached only when shellcheck exited 0 (no findings) or 1 (findings).
Any other exit (could not process a file, killed, bad options) is printed but
never stored: a broken run must not become a remembered clean.

Output: the lines containing "SC2006", exactly as `shellcheck -f gcc -i SC2006
FILES | grep SC2006` prints them (order may differ: the uncached run is parallel,
as it was under `xargs -P 8`). Exit 0 always, as that pipeline's `|| true` did.

Usage:
    tools/shellcheck-sc2006-cached.py FILE...
Cache dir: $FW_SC2006_CACHE_DIR, else ${XDG_CACHE_HOME:-~/.cache}/fw-shellcheck-sc2006
Set FW_SC2006_CACHE_DIR to an empty string to disable the cache.
"""
from __future__ import annotations

import hashlib
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

BATCH = 25
JOBS = 8


def _cache_dir() -> Path | None:
    env = os.environ.get("FW_SC2006_CACHE_DIR")
    if env is not None:
        return Path(env) if env else None
    base = os.environ.get("XDG_CACHE_HOME") or os.path.join(os.path.expanduser("~"), ".cache")
    return Path(base) / "fw-shellcheck-sc2006"


def _key(version: bytes, path: str, content: bytes) -> str:
    h = hashlib.sha256()
    h.update(version)
    h.update(b"\0")
    h.update(path.encode())
    h.update(b"\0")
    h.update(content)
    return h.hexdigest()


def _run_batch(paths: list[str]) -> tuple[int, dict[str, list[str]]]:
    proc = subprocess.run(
        ["shellcheck", "-f", "gcc", "-i", "SC2006", *paths],
        stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True,
    )
    per: dict[str, list[str]] = {p: [] for p in paths}
    for line in proc.stdout.splitlines():
        for p in paths:
            if line.startswith(p + ":"):
                per[p].append(line)
                break
    return proc.returncode, per


def main(argv: list[str]) -> int:
    files = argv[1:]
    if not files:
        return 0
    version = subprocess.run(["shellcheck", "--version"], stdout=subprocess.PIPE,
                             stderr=subprocess.DEVNULL).stdout
    cache = _cache_dir()
    out: list[str] = []
    misses: list[str] = []
    keys: dict[str, str] = {}
    for f in files:
        try:
            content = Path(f).read_bytes()
        except OSError:
            misses.append(f)
            continue
        k = _key(version, f, content)
        keys[f] = k
        hit = cache / k[:2] / k if cache else None
        if hit is not None and hit.is_file():
            out.extend(l for l in hit.read_text().splitlines() if "SC2006" in l)
        else:
            misses.append(f)

    batches = [misses[i:i + BATCH] for i in range(0, len(misses), BATCH)]
    with ThreadPoolExecutor(max_workers=JOBS) as pool:
        for rc, per in pool.map(_run_batch, batches):
            for f, lines in per.items():
                out.extend(l for l in lines if "SC2006" in l)
                if cache is None or rc not in (0, 1) or f not in keys:
                    continue
                k = keys[f]
                d = cache / k[:2]
                try:
                    d.mkdir(parents=True, exist_ok=True)
                    tmp = d / (k + ".tmp.%d" % os.getpid())
                    tmp.write_text("".join(l + "\n" for l in lines))
                    os.replace(tmp, d / k)
                except OSError:
                    pass

    for line in out:
        print(line)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
