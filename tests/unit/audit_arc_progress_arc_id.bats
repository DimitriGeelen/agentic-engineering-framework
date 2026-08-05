#!/usr/bin/env bats
# T-1875 (T-NEW-11): audit arc-progress fallback unions arc_id frontmatter
# with legacy arc:<slug> tag scan.
#
# The fallback at agents/audit/audit.sh:~3619 fires when an arc's
# constituent_tasks: [] is empty. T-1813 introduced it as a tag-only scan;
# this slice adds arc_id: frontmatter as an equally-valid membership signal
# (canonical source-of-truth post-T-1850 migration).
#
# Strategy: this test exercises a self-contained python block whose regex +
# scan logic mirrors the production block, against a synthetic .tasks/ tree.
# That pins the regex/union behavior independent of the full audit run.

setup() {
    export PROJECT_ROOT="$(mktemp -d)"
    guard_project_root
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.tasks/completed"
    export ARC_SLUG="test-arc"
    export ARC_ID="arc-777"

    # Task A: arc_id (slug form) only
    cat > "$PROJECT_ROOT/.tasks/active/T-8001-a.md" <<'MD'
---
id: T-8001
status: started-work
tags: [unrelated]
arc_id: test-arc
---
MD

    # Task B: arc_id (arc-NNN form) only
    cat > "$PROJECT_ROOT/.tasks/active/T-8002-b.md" <<'MD'
---
id: T-8002
status: started-work
arc_id: arc-777
---
MD

    # Task C: legacy tag only
    cat > "$PROJECT_ROOT/.tasks/active/T-8003-c.md" <<'MD'
---
id: T-8003
status: started-work
tags: [arc:test-arc]
---
MD

    # Task D: both (must not double-count)
    cat > "$PROJECT_ROOT/.tasks/completed/T-8004-d.md" <<'MD'
---
id: T-8004
status: work-completed
tags: [arc:test-arc]
arc_id: test-arc
---
MD

    # Task E: unrelated arc
    cat > "$PROJECT_ROOT/.tasks/active/T-8005-e.md" <<'MD'
---
id: T-8005
status: started-work
tags: [arc:other]
arc_id: other
---
MD
}

teardown() {
    rm -rf "$PROJECT_ROOT"
}

# Helper that mirrors audit.sh:3619+ — keep in lockstep with production block.
_scan() {
    python3 - "$PROJECT_ROOT" "$ARC_SLUG" "$ARC_ID" <<'PY'
import re, sys, os, glob
project_root, arc_slug, arc_id = sys.argv[1], sys.argv[2], sys.argv[3]
tag_pattern = f"arc:{arc_slug}"
arc_id_re = re.compile(
    rf'^\s*arc_id:\s*["\']?({re.escape(arc_slug)}|{re.escape(arc_id)})["\']?\s*$',
    re.MULTILINE,
)
seen = set()
for d in ("active", "completed"):
    for f in glob.glob(os.path.join(project_root, ".tasks", d, "T-*.md")):
        with open(f) as fh:
            tt = fh.read()
        matched = False
        tags_m = re.search(r'^tags:\s*(.*?)$', tt, re.MULTILINE)
        if tags_m and tag_pattern in tags_m.group(1):
            matched = True
        if not matched and arc_id_re.search(tt):
            matched = True
        if matched:
            id_m = re.search(r'^id:\s*(T-\d+)', tt, re.MULTILINE)
            if id_m:
                seen.add(id_m.group(1))
for tid in sorted(seen):
    print(tid)
PY
}

@test "audit fallback finds arc_id (slug form) only task" {
    run _scan
    [ "$status" -eq 0 ]
    [[ "$output" == *"T-8001"* ]]
}

@test "audit fallback finds arc_id (arc-NNN form) only task" {
    run _scan
    [ "$status" -eq 0 ]
    [[ "$output" == *"T-8002"* ]]
}

@test "audit fallback finds legacy arc:<slug> tag-only task" {
    run _scan
    [ "$status" -eq 0 ]
    [[ "$output" == *"T-8003"* ]]
}

@test "audit fallback does not double-count tasks set in both forms" {
    run _scan
    [ "$status" -eq 0 ]
    [[ "$output" == *"T-8004"* ]]
    local count
    count=$(printf '%s\n' "$output" | grep -c "^T-8004$")
    [ "$count" -eq 1 ]
}

@test "audit fallback excludes unrelated-arc tasks" {
    run _scan
    [ "$status" -eq 0 ]
    [[ "$output" != *"T-8005"* ]]
}

@test "audit fallback returns sorted output across active+completed" {
    run _scan
    [ "$status" -eq 0 ]
    local sorted
    sorted=$(printf '%s\n' "$output" | sort)
    [ "$output" = "$sorted" ]
}

@test "audit fallback tolerates quoted arc_id value" {
    cat > "$PROJECT_ROOT/.tasks/active/T-8006-q.md" <<'MD'
---
id: T-8006
arc_id: "test-arc"
---
MD
    run _scan
    [ "$status" -eq 0 ]
    [[ "$output" == *"T-8006"* ]]
}

@test "production audit.sh contains the union regex" {
    FRAMEWORK_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    grep -q "arc_id_re" "${FRAMEWORK_ROOT}/agents/audit/audit.sh"
    grep -q "re.escape(arc_slug)" "${FRAMEWORK_ROOT}/agents/audit/audit.sh"
}
