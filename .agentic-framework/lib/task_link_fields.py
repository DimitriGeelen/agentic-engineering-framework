#!/usr/bin/env python3
"""T-4192: append-only setters for related_tasks / unlocks_inception_decision.

`fw task update T-XXX --related T-YYY[,..] --unlocks T-AAA:decision-id[,..]`
routes here. Both fields were hand-edit only, so the GO-scope close gate
(related_tasks) and the inception-decision trace (unlocks_inception_decision)
could not be satisfied through the CLI (832 OBS-453, their T-1150).

Usage:
    task_link_fields.py validate <task-file> <project-root> <related-csv> <unlocks-csv>
    task_link_fields.py apply    <task-file> <project-root> <related-csv> <unlocks-csv>

validate: exit 1 with one line per unresolved id on stderr; writes nothing.
apply:    validates again, then appends (dedup, existing entries kept, order
          preserved) and prints one line per field that changed.
"""

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from inception_decisions import validate_unlocks_references  # noqa: E402

_TASK_ID_RE = re.compile(r"^T-\d+$")
_FM_RE = re.compile(r"\A---\n(.*?\n)---\n", re.DOTALL)


def _split(csv):
    return [s.strip() for s in csv.split(",") if s.strip()]


def _task_exists(task_id, root):
    for sub in ("active", "completed"):
        d = root / ".tasks" / sub
        if d.is_dir() and any(d.glob(f"{task_id}-*.md")):
            return True
    return False


def validate(self_id, root, related, unlocks):
    errors = []
    for tid in related:
        if not _TASK_ID_RE.match(tid):
            errors.append(f"--related '{tid}': malformed (expected T-XXX)")
        elif tid == self_id:
            errors.append(f"--related '{tid}': a task cannot be related to itself")
        elif not _task_exists(tid, root):
            errors.append(f"--related '{tid}': task not found in .tasks/{{active,completed}}/")
    errors.extend(validate_unlocks_references(unlocks, root))
    return errors


def _field_span(fm, key):
    """(start, end, values) of `key:` in frontmatter text, flow or block list."""
    m = re.search(rf"^{key}:[ \t]*(\[[^\]\n]*\])?[ \t]*\n((?:[ \t]+-[ \t]+.*\n)*)",
                  fm, re.MULTILINE)
    if not m:
        return None
    values = []
    if m.group(1):
        values = [v.strip().strip("'\"") for v in m.group(1)[1:-1].split(",") if v.strip()]
    for line in m.group(2).splitlines():
        v = line.strip()[1:].strip().strip("'\"")
        if v:
            values.append(v)
    return m.start(), m.end(), values


def _set_field(fm, key, additions, anchor_keys):
    span = _field_span(fm, key)
    existing = span[2] if span else []
    combined = list(dict.fromkeys(existing + additions))
    added = [v for v in combined if v not in existing]
    if not added:
        return fm, []
    line = f"{key}: [{', '.join(combined)}]\n"
    if span:
        return fm[:span[0]] + line + fm[span[1]:], added
    for anchor in anchor_keys:
        a = re.search(rf"^{anchor}:.*\n(?:[ \t]+-.*\n)*", fm, re.MULTILINE)
        if a:
            return fm[:a.end()] + line + fm[a.end():], added
    return fm + line, added


def main(argv):
    if len(argv) != 6 or argv[1] not in ("validate", "apply"):
        print(__doc__, file=sys.stderr)
        return 2
    mode, task_file, root = argv[1], Path(argv[2]), Path(argv[3])
    related, unlocks = _split(argv[4]), _split(argv[5])
    self_id = re.match(r"(T-\d+)", task_file.name)
    errors = validate(self_id.group(1) if self_id else "", root, related, unlocks)
    if errors:
        for e in errors:
            print(f"ERROR: {e}", file=sys.stderr)
        return 1
    if mode == "validate":
        return 0

    content = task_file.read_text()
    m = _FM_RE.match(content)
    if not m:
        print(f"ERROR: {task_file} has no YAML frontmatter", file=sys.stderr)
        return 1
    fm = m.group(1)
    fm, added_rel = _set_field(fm, "related_tasks", related, ["components", "tags", "owner"])
    fm, added_unl = _set_field(fm, "unlocks_inception_decision", unlocks,
                               ["related_tasks", "components", "tags", "owner"])
    if added_rel or added_unl:
        task_file.write_text("---\n" + fm + "---\n" + content[m.end():])
    if added_rel:
        print(f"related_tasks: +{', '.join(added_rel)}")
    if added_unl:
        print(f"unlocks_inception_decision: +{', '.join(added_unl)}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
