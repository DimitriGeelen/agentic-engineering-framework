#!/usr/bin/env bash
# T-2161 (arc-009 horizon-axis-hardening, Slice 2):
# Null the stored `horizon:` field on every file under .tasks/completed/.
#
# Rationale (T-2159 inception Q1=(b), shipped under T-2160):
# Render-time `past` is now derived from `_location == 'completed'`. The stored
# horizon on completed/ files is behaviorally irrelevant — render no longer
# reads it. But ~1828 files carry stale `horizon: now/next/later` from before
# T-1068 invariants existed. YAML hygiene: stored value should not lie.
#
# Idempotent: re-running emits `0 changes` once the corpus is clean.
# Safe: only touches files where `horizon: <something>` exists in YAML
# frontmatter and the value is non-null/non-empty.
#
# Usage:
#   bin/migrate-horizon-null-completed.sh             # run migration
#   bin/migrate-horizon-null-completed.sh --dry-run   # report only, no changes
#
# Output: change count to stdout, file list to stderr.

set -eo pipefail

FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
PROJECT_ROOT="${PROJECT_ROOT:-$FRAMEWORK_ROOT}"
TASKS_DIR="$PROJECT_ROOT/.tasks/completed"

DRY_RUN=0
if [ "${1:-}" = "--dry-run" ]; then
    DRY_RUN=1
fi

if [ ! -d "$TASKS_DIR" ]; then
    echo "ERROR: $TASKS_DIR not found" >&2
    exit 1
fi

# Python does the regex work — bash sed-on-yaml is fragile (escape rules, BSD/GNU
# divergence, frontmatter boundary detection). Python is already a hard dep.
exec python3 - "$TASKS_DIR" "$DRY_RUN" << 'PY'
import re
import sys
from pathlib import Path

tasks_dir = Path(sys.argv[1])
dry_run = sys.argv[2] == '1'

# Match `horizon: <value>` inside frontmatter only. <value> is the rest of the
# line (allowing inline comments via `# ...` — preserved on the new line).
# We replace with `horizon: null` so the frontmatter remains valid YAML.
FRONT_RE = re.compile(r'^(---\n)(.*?)(\n---)', re.DOTALL)
# `[^\S\n]` is HORIZONTAL whitespace only, and the distinction is load-bearing
# (T-3118). This was `\s*`, which includes `\n` — so for the already-correct
#
#     horizon:
#     tags: []
#
# the pattern consumed the newline, matched `tags: []` as horizon's VALUE, and
# rewrote both lines as `horizon: null` — deleting the following line. It also
# meant the "already null" skip almost never fired: 2362 of 2725 completed
# tasks were reported as needing a change when the audit named 21. A migration
# advertised as "only touches files with non-null horizon" would have rewritten
# 87% of the corpus and dropped a frontmatter line from each.
HORIZON_RE = re.compile(r'^(horizon:[^\S\n]*)([^\s#][^\n]*?)([^\S\n]*)(#.*)?$', re.MULTILINE)

changed = 0
skipped_already_null = 0
skipped_no_field = 0
files = sorted(tasks_dir.glob('T-*.md'))

for f in files:
    text = f.read_text()
    fm_match = FRONT_RE.match(text)
    if not fm_match:
        continue
    fm_body = fm_match.group(2)
    h_match = HORIZON_RE.search(fm_body)
    if not h_match:
        skipped_no_field += 1
        continue
    raw_value = h_match.group(2).strip()
    if raw_value in ('', 'null', '~'):
        skipped_already_null += 1
        continue
    # Replace the value with `null`, preserve trailing comment if any
    comment = h_match.group(4) or ''
    suffix = ('  ' + comment) if comment else ''
    new_line = f'horizon: null{suffix}'
    new_fm_body = fm_body[:h_match.start()] + new_line + fm_body[h_match.end():]
    new_text = fm_match.group(1) + new_fm_body + fm_match.group(3) + text[fm_match.end():]
    if new_text == text:
        skipped_already_null += 1
        continue
    if not dry_run:
        f.write_text(new_text)
    sys.stderr.write(f'  {"WOULD CHANGE" if dry_run else "changed"}: {f.name} (was: horizon: {raw_value})\n')
    changed += 1

print(f'{changed} changes' + (' (DRY RUN — no files written)' if dry_run else ''))
print(f'  skipped (already null/absent value):  {skipped_already_null}')
print(f'  skipped (no horizon field):           {skipped_no_field}')
print(f'  total files scanned:                  {len(files)}')
PY
