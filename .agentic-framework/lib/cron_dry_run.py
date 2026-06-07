#!/usr/bin/env python3
"""T-1944 — Cron registry → generated dry-run helper.

Re-runs the same generation logic that `fw cron generate` writes to
`.context/cron/agentic-audit.crontab`, but to stdout instead of the
file. Bash callers content-diff against the on-disk source to detect
registry → generated drift (the third leg of the three-step sync
chain registry → generated → deployed, T-1942/T-1943).

Extracted from inline heredocs in `bin/fw` (do_doctor) and
`agents/audit/audit.sh` to satisfy L-332 / L-408: "any Python
helper >10 lines goes in lib/*.py and is invoked as
python3 $FW_LIB_DIR/helper.py — the bash side stays parse-safe".

Both prior inline-heredoc sites emitted a cosmetic
"warning: command substitution: 1 unterminated here-document"
on every bash invocation and (twice in T-1942 alone) bit the agent
with self-locking bin/fw parse errors when an edit lost the closing
`)`. Routing through a real file eliminates both.

Args:
  argv[1]  project_root   — consumer (or framework) repo root
  argv[2]  registry_file  — path to .context/cron-registry.yaml
  argv[3]  fw_path        — absolute path to bin/fw (for `fw` resolution
                            in cron command lines)

Output: the full generated crontab text to stdout (no trailing newline
beyond what the joined `lines` carry, matching the on-disk file shape).

Exit codes:
  0  always on the happy path. Callers detect drift via stdout diff.
  2  argv shape wrong.
  3  registry file missing or yaml parse error.
"""
import os
import re
import sys
import yaml


def main() -> int:
    if len(sys.argv) != 4:
        print(f"usage: {sys.argv[0]} <project_root> <registry_file> <fw_path>",
              file=sys.stderr)
        return 2
    project_root, registry_file, fw_path = sys.argv[1], sys.argv[2], sys.argv[3]
    try:
        with open(registry_file) as f:
            data = yaml.safe_load(f) or {}
    except (OSError, yaml.YAMLError) as exc:
        print(f"cron-dry-run: cannot load {registry_file}: {exc}",
              file=sys.stderr)
        return 3
    jobs = data.get("jobs", []) or []
    slug = re.sub(r"[^a-z0-9_-]", "-", os.path.basename(project_root).lower())
    cron_source = os.path.join(project_root, ".context", "cron",
                               "agentic-audit.crontab")
    cron_install = f"/etc/cron.d/agentic-audit-{slug}"
    lines = [
        "# Agentic Engineering Framework — Scheduled Jobs (managed by cron-registry.yaml)",
        f"# Source of truth: {cron_source} (git-tracked)",
        f"# Installed to: {cron_install}",
        f"# Project: {project_root}",
        "SHELL=/bin/bash",
        "PATH=/usr/local/bin:/usr/bin:/bin",
        "",
    ]
    for job in jobs:
        schedule = job.get("schedule", "")
        command = job.get("command", "")
        name = job.get("name", "")
        status = job.get("status", "active")
        if "fw " in command:
            resolved = re.sub(r"\bfw\b", f'"{fw_path}"', command)
            resolved = (f'cd "{project_root}" && '
                        f'PROJECT_ROOT="{project_root}" {resolved}')
        else:
            resolved = f'cd "{project_root}" && {command}'
        if "2>&1 | logger" not in resolved and "2>/dev/null" not in resolved:
            resolved += " 2>&1 | logger -t agentic-cron"
        elif "2>/dev/null" in resolved:
            resolved = resolved.replace("2>/dev/null",
                                        "2>&1 | logger -t agentic-cron")
        lines.append(f"# {name}")
        if status == "paused":
            lines.append(f"# PAUSED: {schedule} root {resolved}")
        else:
            lines.append(f"{schedule} root {resolved}")
        lines.append("")
    sys.stdout.write("\n".join(lines))
    return 0


if __name__ == "__main__":
    sys.exit(main())
