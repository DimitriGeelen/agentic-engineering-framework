#!/usr/bin/env python3
"""Insert a dated entry at the end of a task file's ## Updates section (T-4812).

Writers used to append entries at end of file. Once the close has written
'## Reviewer Verdict' below ## Updates, an EOF append lands outside the section:
the record reads wrong, and the T-4285 closed-record gate (which allows only
appends INSIDE ## Updates) refuses its own documented append route.

Usage:  <entry text on stdin> | python3 lib/task_updates.py append TASK_FILE

The entry is inserted after the last non-blank line of the first '## Updates'
section (the same section the gate bounds), separated by one blank line. With no
'## Updates' section the entry is appended at end of file, as before.
"""
import os
import re
import sys
import tempfile


def insert_entry(text: str, entry: str) -> str:
    entry = entry.strip("\n")
    if not entry:
        return text
    m = re.search(r"^## Updates[ \t]*$", text, re.M)
    if not m:
        return text + ("" if text.endswith("\n") or not text else "\n") + "\n" + entry + "\n"
    nxt = re.search(r"^## ", text[m.end():], re.M)
    hi = m.end() + nxt.start() if nxt else len(text)
    head = text[:hi].rstrip("\n")
    tail = text[hi:]
    out = head + "\n\n" + entry + "\n"
    if tail:
        out += "\n" + tail
    return out


def main(argv: list[str]) -> int:
    if len(argv) != 3 or argv[1] != "append":
        print("usage: task_updates.py append TASK_FILE  (entry on stdin)", file=sys.stderr)
        return 2
    path = argv[2]
    entry = sys.stdin.read()
    with open(path, encoding="utf-8") as f:
        text = f.read()
    new = insert_entry(text, entry)
    if new == text:
        return 0
    d = os.path.dirname(os.path.abspath(path))
    fd, tmp = tempfile.mkstemp(dir=d, prefix=".task_updates.")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(new)
        os.chmod(tmp, os.stat(path).st_mode & 0o7777)
        os.replace(tmp, path)
    except BaseException:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
