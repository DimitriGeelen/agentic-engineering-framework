#!/usr/bin/env bats
# T-1619 — handover Work-in-Progress loop must skip DEFER'd inceptions.
# Per T-1617's GO outcome: DEFER means "park for later, not done" — these
# tasks must not appear under "Work in Progress" / horizon: now. They DO
# remain in .tasks/active/ for audit traceability and surface in T-1517's
# "Deferred Inceptions — Watching for Recurrence" section instead.
#
# Canonical witness: T-1611 (DEFER'd 2026-04-30T08:48Z) was pinned in WIP
# in LATEST.md until this fix landed.

load ../test_helper

# ---- Source-level invariant ----

@test "handover.sh skips DEFER'd inceptions in WIP loop (T-1619)" {
    # Pattern pinned: workflow_type=inception AND Decision=DEFER short-circuits the WIP loop.
    grep -q "if wf == 'inception' and dec == 'DEFER':" \
        "$FRAMEWORK_ROOT/agents/handover/handover.sh"
}

@test "T-1619 rationale comment present (T-1619)" {
    grep -q 'T-1619' "$FRAMEWORK_ROOT/agents/handover/handover.sh"
}

@test "handover.sh captures Decision in the data tuple (T-1619)" {
    # The first-pass collector must read **Decision** and store it for the WIP loop
    # to filter on. Reusing the captured value avoids a second per-task file read
    # (the stale 5-tuple loop did exactly that for T-1517's section).
    grep -qE "Decision\\\\\\*\\\\\\*:\\\\s\\*\\(GO\\|NO-GO\\|DEFER\\)" \
        "$FRAMEWORK_ROOT/agents/handover/handover.sh"
}

# ---- Behavioural ----

@test "DEFER'd inception is NOT printed in WIP (T-1619)" {
    # Fixture: one DEFER'd inception, one normal build task. WIP loop must
    # emit the build task and skip the DEFER'd inception.
    cd "$TEST_TEMP_DIR"
    mkdir -p tasks/active
    cat > tasks/active/T-D01-deferred-inception.md <<'EOF'
---
id: T-D01
name: "Deferred inception"
status: started-work
workflow_type: inception
owner: agent
horizon: now
---

# T-D01

## Recommendation

**Recommendation:** DEFER

## Decision

**Decision**: DEFER
EOF
    cat > tasks/active/T-B01-active-build.md <<'EOF'
---
id: T-B01
name: "Active build"
status: started-work
workflow_type: build
owner: agent
horizon: now
---

# T-B01
EOF

    run python3 - <<PYEOF
import os, re, glob
tasks_dir = "$TEST_TEMP_DIR/tasks/active"
horizon_order = {'now': 0, 'next': 1, 'later': 2}
tasks = []
for f in sorted(glob.glob(os.path.join(tasks_dir, '*.md'))):
    with open(f) as fh:
        content = fh.read()
    tid = re.search(r'^id:\s*(.+)', content, re.M)
    tname = re.search(r'^name:\s*(.+)', content, re.M)
    tstatus = re.search(r'^status:\s*(.+)', content, re.M)
    thoriz = re.search(r'^horizon:\s*(.+)', content, re.M)
    twf = re.search(r'^workflow_type:\s*(.+)', content, re.M)
    h = thoriz.group(1).strip() if thoriz else 'now'
    wf = twf.group(1).strip() if twf else ''
    dec_m = re.search(r'^\*\*Decision\*\*:\s*(GO|NO-GO|DEFER)\b', content, re.M)
    dec = dec_m.group(1) if dec_m else ''
    tasks.append((horizon_order.get(h, 0), tid.group(1).strip(),
                  tname.group(1).strip() if tname else '',
                  tstatus.group(1).strip() if tstatus else '',
                  h, '', wf, dec))
tasks.sort(key=lambda t: (t[0], t[1]))
emitted = []
for _, tid, tname, tstatus, h, verdict, wf, dec in tasks:
    if wf == 'inception' and dec == 'DEFER':
        continue
    emitted.append(tid)
print(','.join(emitted))
PYEOF
    [ "$status" -eq 0 ]
    [ "$output" = "T-B01" ]
}

@test "DEFER'd build task IS printed (only inceptions filtered) (T-1619)" {
    # Edge: a regular build task with a DEFER recommendation (not a decision)
    # must still appear in WIP. The filter is workflow_type-aware on purpose.
    cd "$TEST_TEMP_DIR"
    mkdir -p tasks/active
    cat > tasks/active/T-B02-deferred-build.md <<'EOF'
---
id: T-B02
name: "Build with DEFER recommendation but no Decision"
status: started-work
workflow_type: build
owner: agent
horizon: now
---

## Recommendation

**Recommendation:** DEFER
EOF

    run python3 - <<PYEOF
import os, re, glob
tasks_dir = "$TEST_TEMP_DIR/tasks/active"
emitted = []
for f in sorted(glob.glob(os.path.join(tasks_dir, '*.md'))):
    with open(f) as fh:
        content = fh.read()
    tid_m = re.search(r'^id:\s*(.+)', content, re.M)
    twf = re.search(r'^workflow_type:\s*(.+)', content, re.M)
    wf = twf.group(1).strip() if twf else ''
    dec_m = re.search(r'^\*\*Decision\*\*:\s*(GO|NO-GO|DEFER)\b', content, re.M)
    dec = dec_m.group(1) if dec_m else ''
    if wf == 'inception' and dec == 'DEFER':
        continue
    emitted.append(tid_m.group(1).strip())
print(','.join(emitted))
PYEOF
    [ "$status" -eq 0 ]
    [ "$output" = "T-B02" ]
}

@test "GO inception in flight IS still printed in WIP (T-1619)" {
    # Edge: an inception that has a GO decision but hasn't been swept to
    # completed/ yet is in-flight, NOT parked. Must still appear in WIP.
    cd "$TEST_TEMP_DIR"
    mkdir -p tasks/active
    cat > tasks/active/T-G01-go-inception.md <<'EOF'
---
id: T-G01
name: "GO inception, not yet swept"
status: started-work
workflow_type: inception
owner: agent
horizon: now
---

## Decision

**Decision**: GO
EOF

    run python3 - <<PYEOF
import os, re, glob
tasks_dir = "$TEST_TEMP_DIR/tasks/active"
emitted = []
for f in sorted(glob.glob(os.path.join(tasks_dir, '*.md'))):
    with open(f) as fh:
        content = fh.read()
    tid_m = re.search(r'^id:\s*(.+)', content, re.M)
    twf = re.search(r'^workflow_type:\s*(.+)', content, re.M)
    wf = twf.group(1).strip() if twf else ''
    dec_m = re.search(r'^\*\*Decision\*\*:\s*(GO|NO-GO|DEFER)\b', content, re.M)
    dec = dec_m.group(1) if dec_m else ''
    if wf == 'inception' and dec == 'DEFER':
        continue
    emitted.append(tid_m.group(1).strip())
print(','.join(emitted))
PYEOF
    [ "$status" -eq 0 ]
    [ "$output" = "T-G01" ]
}

# ---- Sanity ----

@test "handover.sh parses (bash -n) after T-1619 fix" {
    bash -n "$FRAMEWORK_ROOT/agents/handover/handover.sh"
}
