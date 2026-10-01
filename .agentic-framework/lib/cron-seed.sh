#!/usr/bin/env bash
# lib/cron-seed.sh — T-3673
#
# Framework-owned cron jobs every consumer needs, merged into a consumer's
# .context/cron-registry.yaml by `fw init` (fresh) and `fw upgrade` (existing).
#
# Rules: add a job ONLY when no job with that id exists. Never overwrite, reorder
# or rewrite an existing job — operator edits to a same-id job win. Commands use
# bare `fw`; `fw cron generate` resolves it to the consumer's own fw path. The
# flock name carries the project slug so two consumers on one host never share
# a lock (the AEF registry's slug-less lock names are single-project only).

# cron_seed_ensure_jobs <registry_path> <project_root>
# Prints one line per framework job: "ADDED <id>" or "PRESENT <id>" — only after
# the merged text parsed and was written (T-3680); on failure: ERROR to stderr, no ADDED.
# CRON_SEED_DRY_RUN=1 reports without writing.
# Exit 0 on success, 1 when the registry is missing/unparseable (nothing written).
cron_seed_ensure_jobs() {
    local registry="$1" project_root="$2"
    [ -f "$registry" ] || return 1
    python3 - "$registry" "$project_root" <<'PYEOF'
import os, re, sys
import yaml

registry, project_root = sys.argv[1], sys.argv[2]
slug = re.sub(r'[^a-z0-9_-]', '-', os.path.basename(os.path.abspath(project_root)).lower())

JOBS = [
    {
        "id": "sidecar-sweep-5m",
        "block": f"""\
- id: sidecar-sweep-5m
  name: Sidecar ack-ledger sweep (5 min)
  schedule: '3,8,13,18,23,28,33,38,43,48,53,58 * * * *'
  command: flock -n /var/lock/agentic-cron-sidecar-sweep-5m-{slug}.lock -c 'fw sidecar sweep'
  source_file: agentic-audit.crontab
  origin_task: T-3673
  status: active
  description: "Walks the peer-consult ack ledger and escalates unacked consults (T-3418, T-3673). Without this job unacked consults never escalate."
""",
    },
]

text = open(registry).read()
try:
    data = yaml.safe_load(text) or {}
except Exception as e:
    print(f"ERROR cannot parse {registry}: {e}", file=sys.stderr)
    sys.exit(1)
if not isinstance(data, dict) or not isinstance(data.get("jobs", []) or [], list):
    print(f"ERROR {registry}: 'jobs' is not a list", file=sys.stderr)
    sys.exit(1)
present = {j.get("id") for j in (data.get("jobs") or []) if isinstance(j, dict)}

lines = text.splitlines(keepends=True)
report = []  # T-3680: printed only after the merge parsed (and was written)
for job in JOBS:
    if job["id"] in present:
        report.append(f"PRESENT {job['id']}")
        continue
    idx = next((i for i, l in enumerate(lines) if re.match(r'^jobs:', l)), None)
    if idx is None:
        if lines and not lines[-1].endswith("\n"):
            lines[-1] += "\n"
        lines += ["jobs:\n", job["block"]]
    elif re.match(r'^jobs:\s*(\[\s*\])?\s*(#.*)?$', lines[idx]):
        lines[idx] = "jobs:\n"
        # insert before the next top-level key (or at EOF)
        end = next((i for i in range(idx + 1, len(lines))
                    if re.match(r'^[A-Za-z_]', lines[i])), len(lines))
        if end > idx + 1 and not lines[end - 1].endswith("\n"):
            lines[end - 1] += "\n"
        # T-3676: match the registry's own list-item indent (832 indents 2).
        ind = next((m.group(1) for m in (re.match(r'^(\s*)- ', l) for l in lines[idx + 1:end]) if m), "")
        blk = "".join((ind + l if l.strip() else l) for l in job["block"].splitlines(keepends=True))
        lines[end:end] = [blk]
    else:
        print(f"ERROR {registry}: unsupported 'jobs:' form", file=sys.stderr)
        sys.exit(1)
    present.add(job["id"])
    report.append(f"ADDED {job['id']}")

new = "".join(lines)
if new != text:
    try:
        yaml.safe_load(new)  # never report or write something that does not parse
    except Exception as e:
        print(f"ERROR merged {registry} does not parse, nothing written: {e}", file=sys.stderr)
        sys.exit(1)
    if not os.environ.get("CRON_SEED_DRY_RUN"):
        tmp = registry + ".tmp-seed"
        open(tmp, "w").write(new)
        os.replace(tmp, registry)
for r in report:
    print(r)
PYEOF
}
