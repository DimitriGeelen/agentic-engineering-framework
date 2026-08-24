#!/usr/bin/env bats
# T-3070 — regression pin for the schedule half of the audit-lock contention
# class. Every cron job whose command invokes `fw audit` (full or
# --section-scoped) contends for the SAME internal flock
# (.context/locks/audit.lock, set in agents/audit/audit.sh) regardless of the
# job's own distinct /var/lock/agentic-cron-*.lock. Two such jobs sharing an
# exact cron-field match (all 5 fields intersect) are guaranteed to race for
# that lock at the same wall-clock minute — the loser gets exit 75 with no
# retry, so a losing full-daily run silently produces no report for the day.
#
# Origin: full-daily (0 8 * * *) exactly collided with traceability-hourly
# (0 * * * *) every day at 8:00 before this fix (T-3070); structural-30m had
# the same class of bug against traceability-hourly/oe-hourly, fixed earlier
# by offsetting to :05/:35 (see the schedule's own description field).
#
# This test expands each job's 5 cron fields into value sets (minute/hour/
# day-of-month/month/day-of-week) and flags any pair of `fw audit`-invoking
# active jobs whose sets intersect on all 5 fields — i.e. any pair that CAN
# fire in the same absolute minute, not just ones observed colliding so far.

setup() {
    FW_ROOT="$BATS_TEST_DIRNAME/../.."
    REGISTRY="$FW_ROOT/.context/cron-registry.yaml"
}

@test "no two active fw-audit cron jobs can fire in the same absolute minute" {
    [ -f "$REGISTRY" ] || skip "no cron-registry.yaml in this checkout"

    python3 - "$REGISTRY" << 'PYEOF'
import sys, re
import yaml

def expand_field(field, lo, hi):
    vals = set()
    for part in field.split(','):
        step = 1
        if '/' in part:
            part, step_s = part.split('/', 1)
            step = int(step_s)
        if part == '*':
            rng = range(lo, hi + 1)
        elif '-' in part:
            a, b = part.split('-', 1)
            rng = range(int(a), int(b) + 1)
        else:
            rng = range(int(part), int(part) + 1)
        vals.update(v for v in rng if (v - lo) % step == 0)
    return vals

def expand_schedule(schedule):
    fields = schedule.split()
    if len(fields) != 5:
        return None  # non-standard (e.g. @reboot) — not a collision candidate
    minute, hour, dom, month, dow = fields
    dow_vals = expand_field(dow, 0, 7)
    dow_vals = {0 if v == 7 else v for v in dow_vals}  # 7 == Sunday == 0
    return (
        expand_field(minute, 0, 59),
        expand_field(hour, 0, 23),
        expand_field(dom, 1, 31),
        expand_field(month, 1, 12),
        dow_vals,
    )

def collides(a, b):
    sa, sb = expand_schedule(a), expand_schedule(b)
    if sa is None or sb is None:
        return False
    return all(x & y for x, y in zip(sa, sb))

with open(sys.argv[1]) as f:
    reg = yaml.safe_load(f)

jobs = [
    j for j in reg.get('jobs', [])
    if j.get('status') == 'active' and re.search(r'\bfw audit\b', j.get('command', ''))
]

collisions = []
for i in range(len(jobs)):
    for k in range(i + 1, len(jobs)):
        a, b = jobs[i], jobs[k]
        if collides(a['schedule'], b['schedule']):
            collisions.append((a['id'], a['schedule'], b['id'], b['schedule']))

if collisions:
    for aid, asch, bid, bsch in collisions:
        print(f"COLLISION: {aid} ({asch}) vs {bid} ({bsch}) can fire the same minute")
    sys.exit(1)

print(f"OK: {len(jobs)} fw-audit cron job(s) checked, no schedule collisions")
PYEOF
}
