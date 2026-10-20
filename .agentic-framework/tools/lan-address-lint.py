#!/usr/bin/env python3
"""T-4516: refuse RFC1918 (LAN) addresses in shipped framework paths.

The framework ships to consumers (vendored `.agentic-framework/`) and to a public
mirror. A private address such as a 192.168.x.y host in a shipped file publishes
the operator's network layout and, worse, hands consumers a default that only
resolves on one LAN. 832 scrubbed theirs (their T-1239) for the same reason.

Scope: tracked files (git ls-files) under the shipped paths below. Historical
records (docs/reports, docs/research, ...) are exempted through the allowlist,
not through the scope, so every exemption carries a written reason.

Allowlist: policy/lan-address-allowlist.yaml

    entries:
      - path: "docs/reports/**"          # fnmatch glob against the repo path
        reason: "historical records"     # required, non-empty
        address: "<the address>"         # optional: exempt only this address

Usage:
    tools/lan-address-lint.py [--root DIR] [--allowlist FILE] [--json] [FILE ...]

With FILE arguments only those files are scanned (still scope-filtered).
Exit 0 when clean, 1 when an unallowed address is found, 2 on bad usage or an
invalid allowlist.
"""
from __future__ import annotations

import argparse
import fnmatch
import json
import os
import re
import subprocess
import sys

SHIPPED_PATHS = ("lib", "agents", "bin", "web", "policy", "tools", "docs",
                 "templates", ".tasks/templates")

_OCTET = r"(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)"
# 10/8, 172.16/12, 192.168/16. Not preceded by a word char or dot (so version
# strings like v10.1.2.3 and longer dotted runs do not match), not followed by
# a further digit or `.digit`.
RFC1918 = re.compile(
    r"(?<![\w.])(?:"
    rf"10\.{_OCTET}\.{_OCTET}\.{_OCTET}"
    rf"|172\.(?:1[6-9]|2\d|3[01])\.{_OCTET}\.{_OCTET}"
    rf"|192\.168\.{_OCTET}\.{_OCTET}"
    r")(?![\d]|\.\d)"
)


def in_scope(path: str) -> bool:
    return any(path == p or path.startswith(p + "/") for p in SHIPPED_PATHS)


def load_allowlist(path: str) -> list[dict]:
    if not os.path.exists(path):
        return []
    import yaml  # local import: only needed when an allowlist exists
    with open(path, encoding="utf-8") as fh:
        data = yaml.safe_load(fh) or {}
    entries = data.get("entries") or []
    if not isinstance(entries, list):
        raise ValueError("entries must be a list")
    for i, e in enumerate(entries):
        if not isinstance(e, dict) or not str(e.get("path") or "").strip():
            raise ValueError(f"entry {i}: missing path")
        if not str(e.get("reason") or "").strip():
            raise ValueError(f"entry {i} ({e.get('path')}): missing reason")
    return entries


def allowed(path: str, address: str, entries: list[dict]) -> bool:
    for e in entries:
        if not fnmatch.fnmatch(path, e["path"]):
            continue
        if e.get("address") and str(e["address"]) != address:
            continue
        return True
    return False


def tracked_files(root: str) -> list[str]:
    out = subprocess.run(["git", "-C", root, "ls-files", "-z", "--", *SHIPPED_PATHS],
                         capture_output=True, check=True)
    return [p for p in out.stdout.decode("utf-8", "replace").split("\0") if p]


def scan(root: str, files: list[str], entries: list[dict]) -> list[dict]:
    findings = []
    for rel in files:
        if not in_scope(rel):
            continue
        full = os.path.join(root, rel)
        try:
            with open(full, "rb") as fh:
                blob = fh.read()
        except OSError:
            continue
        if b"\0" in blob[:8192]:
            continue  # binary
        text = blob.decode("utf-8", "replace")
        for lineno, line in enumerate(text.splitlines(), 1):
            for m in RFC1918.finditer(line):
                if not allowed(rel, m.group(0), entries):
                    findings.append({"path": rel, "line": lineno, "address": m.group(0)})
    return findings


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description="Refuse RFC1918 addresses in shipped paths (T-4516).")
    ap.add_argument("--root", default=None)
    ap.add_argument("--allowlist", default=None)
    ap.add_argument("--json", action="store_true")
    ap.add_argument("files", nargs="*")
    args = ap.parse_args(argv)

    root = os.path.abspath(args.root or os.path.join(os.path.dirname(__file__), ".."))
    allow_path = args.allowlist or os.path.join(root, "policy", "lan-address-allowlist.yaml")
    try:
        entries = load_allowlist(allow_path)
    except Exception as exc:  # noqa: BLE001 — any parse/shape error is a usage error
        print(f"lan-address-lint: invalid allowlist {allow_path}: {exc}", file=sys.stderr)
        return 2

    if args.files:
        files = [os.path.relpath(os.path.abspath(f), root) for f in args.files]
    else:
        files = tracked_files(root)
    findings = scan(root, files, entries)

    if args.json:
        print(json.dumps({"findings": findings}, indent=2))
    elif findings:
        for f in findings:
            print(f"{f['path']}:{f['line']}: RFC1918 address {f['address']}")
        print(f"\nlan-address-lint: {len(findings)} LAN address(es) in shipped paths. "
              "Use a placeholder (<host>, hub.example.lan, 203.0.113.x) or resolve it at "
              "runtime; if it is a justified record, add an entry with a reason to "
              f"{os.path.relpath(allow_path, root)} (T-4516).", file=sys.stderr)
    else:
        print("lan-address-lint: clean")
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
