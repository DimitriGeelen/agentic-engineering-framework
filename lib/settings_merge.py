#!/usr/bin/env python3
"""T-2710 — carry non-template config forward across a settings.json regenerate.

`generate_claude_code_config` (lib/init.sh) writes .claude/settings.json from a
fixed heredoc template. With force=true it overwrites unconditionally, so any
hook added later via `fw hook-enable` — six of them in this repo — is silently
deleted, taking six live governance gates down with no message.

This helper runs immediately after the template is written and merges the
previous file back over it:

  * framework hooks whose name the template does NOT define  -> carried forward
  * framework hooks the template DOES define                 -> template wins
  * top-level keys the template does not emit                -> carried forward

"Template wins" is deliberate and load-bearing: it is what lets a path fix
(T-2709's ${CLAUDE_PROJECT_DIR} rewrite) still propagate to consumers on
upgrade. A merge that preferred the on-disk copy would freeze every consumer
at whatever it was initialised with.

Only *framework* hooks are carried (command matches `fw hook <name>`). Foreign
hooks from other tooling are still dropped — that is T-677's explicit decision
("project-specific hooks from other systems are not compatible"), and this
helper deliberately does not reverse it.

Usage:  settings_merge.py <new-settings.json> <previous-snapshot.json>
Output: one "  CARRIED  <event>  <name>" line per preserved item (stdout).
Exit:   0 on success (including nothing-to-carry), 1 on unreadable input.
"""
import json
import os
import re
import sys
import tempfile

# `<anything>/fw hook <name>` or bare `fw hook <name>`. The \b keeps it from
# matching a binary merely ENDING in fw (e.g. "myfw hook x").
_FW_HOOK = re.compile(r"\bfw\s+hook\s+([A-Za-z0-9_-]+)")


def hook_name(command: str) -> str:
    """Framework hook name in a command string, or '' if not a framework hook."""
    m = _FW_HOOK.search(command or "")
    return m.group(1) if m else ""


def collect_names(doc: dict) -> set:
    """Every framework hook name present in a settings document."""
    names = set()
    for entries in (doc.get("hooks") or {}).values():
        for entry in entries or []:
            for hook in entry.get("hooks") or []:
                n = hook_name(hook.get("command", ""))
                if n:
                    names.add(n)
    return names


def merge(new_doc: dict, prev_doc: dict):
    """Fold prev_doc's non-template content into new_doc. Returns carried list."""
    carried = []
    template_names = collect_names(new_doc)
    hooks = new_doc.setdefault("hooks", {})

    for event, entries in (prev_doc.get("hooks") or {}).items():
        for entry in entries or []:
            keep = [
                h
                for h in (entry.get("hooks") or [])
                if hook_name(h.get("command", ""))
                and hook_name(h.get("command", "")) not in template_names
            ]
            if not keep:
                continue
            # Append as its own entry rather than folding into an existing
            # matcher group: Claude Code allows repeated matchers (the live
            # file already has several "Write|Edit|Bash" entries), and a fresh
            # entry cannot disturb the template's own ordering.
            hooks.setdefault(event, []).append(
                {"matcher": entry.get("matcher", ""), "hooks": keep}
            )
            for h in keep:
                carried.append((event, hook_name(h.get("command", ""))))

    # Top-level keys the template does not own (permissions, env, model, ...).
    # Same defect, same fix: the template is not a complete description of the
    # file, so it must not be treated as one.
    for key, value in prev_doc.items():
        if key != "hooks" and key not in new_doc:
            new_doc[key] = value
            carried.append(("(top-level)", key))

    return carried


def write_atomic(path: str, doc: dict) -> None:
    """temp + os.replace (L-493): never leave a half-written settings.json."""
    d = os.path.dirname(os.path.abspath(path)) or "."
    fd, tmp = tempfile.mkstemp(dir=d, prefix=".settings-merge-", suffix=".json")
    try:
        with os.fdopen(fd, "w") as f:
            json.dump(doc, f, indent=2)
            f.write("\n")
        os.replace(tmp, path)
    except BaseException:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise


def main(argv) -> int:
    if len(argv) != 3:
        print("usage: settings_merge.py <new-settings> <prev-snapshot>",
              file=sys.stderr)
        return 1
    new_path, prev_path = argv[1], argv[2]
    try:
        with open(new_path) as f:
            new_doc = json.load(f)
        with open(prev_path) as f:
            prev_doc = json.load(f)
    except (OSError, json.JSONDecodeError) as e:
        # Loud, not silent: a failure here means hooks were about to be lost.
        print(f"settings_merge: cannot merge ({e})", file=sys.stderr)
        return 1

    carried = merge(new_doc, prev_doc)
    if carried:
        write_atomic(new_path, new_doc)
        for event, name in carried:
            print(f"  CARRIED  {event}  {name}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
