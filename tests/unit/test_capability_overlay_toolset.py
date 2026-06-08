#!/usr/bin/env python3
# tests/unit/test_capability_overlay_toolset.py
#
# Validator for policy/capability-overlay/tool-set.yaml.
# T-2258 (arc-010 Slice 1A). Called from the task's ## Verification block.
#
# Checks:
#   1. YAML parses as a dict.
#   2. Three top-level classes present: read_only, agent_authority,
#      sovereignty_bound_excluded.
#   3. Every read_only + agent_authority entry has {name, fw_command, description}.
#   4. Every sovereignty_bound_excluded entry has {name, fw_command, excluded_reason}.
#   5. Every fw_command's first token resolves to a real verb in bin/fw's case
#      dispatcher (handles `verb)` and `verb|-x|--xyz)` multi-pattern forms).
#
# Prints "OK" on success and exits 0; prints "FAIL: ..." on first failure
# (exits 0 with FAIL line so the caller's grep -q "OK" fails cleanly).

import re
import sys
import yaml
from pathlib import Path


def main() -> int:
    root = Path(__file__).resolve().parents[2]
    yaml_path = root / "policy" / "capability-overlay" / "tool-set.yaml"
    fw_path = root / "bin" / "fw"

    if not yaml_path.is_file():
        print(f"FAIL: missing {yaml_path}")
        return 0
    if not fw_path.is_file():
        print(f"FAIL: missing {fw_path}")
        return 0

    try:
        d = yaml.safe_load(yaml_path.read_text())
    except yaml.YAMLError as exc:
        print(f"FAIL: YAML parse error {exc}")
        return 0
    if not isinstance(d, dict):
        print("FAIL: tool-set.yaml is not a dict")
        return 0

    need = {"read_only", "agent_authority", "sovereignty_bound_excluded"}
    missing = need - set(d.keys())
    if missing:
        print(f"FAIL: missing classes {sorted(missing)}")
        return 0

    bad = []
    for cls in ("read_only", "agent_authority"):
        for entry in d.get(cls, []):
            if not (entry.get("name") and entry.get("fw_command") and entry.get("description")):
                bad.append(("missing-field", cls, entry.get("name") or entry))
    for entry in d.get("sovereignty_bound_excluded", []):
        if not (entry.get("name") and entry.get("fw_command") and entry.get("excluded_reason")):
            bad.append(("missing-field-excluded", entry.get("name") or entry))
    if bad:
        print(f"FAIL: missing required fields {bad[:3]}")
        return 0

    verbs: set[str] = set()
    pat = re.compile(r"^\s+([a-z][a-z0-9_-]+(?:\|[-a-zA-Z0-9_]+)*)\)\s*$")
    for line in fw_path.read_text().splitlines():
        m = pat.match(line)
        if not m:
            continue
        for token in m.group(1).split("|"):
            if re.match(r"^[a-z][a-z0-9_-]+$", token):
                verbs.add(token)

    unresolved = []
    for cls in ("read_only", "agent_authority", "sovereignty_bound_excluded"):
        for entry in d.get(cls, []):
            fw_cmd = (entry.get("fw_command") or "").split()
            first = fw_cmd[0] if fw_cmd else ""
            if first and first not in verbs:
                unresolved.append((entry.get("name"), first))
    if unresolved:
        print(f"FAIL: unresolved verbs {unresolved}")
        return 0

    print("OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
