#!/usr/bin/env bats
# T-3516 (OBS-546): pin the ctl-arc-membership-python-import audit check.
#
# Sibling of audit_ctl_arc_tag_only_pattern.bats (T-1881), which requires the
# literal token `grep` and so cannot see a Python reinvention. This check
# inverts to an import allowlist for the Python half: a file that iterates
# the task corpus AND references `arc_id` within a 60-line window, without
# importing the canonical `arc_membership` module, is flagged.
#
# Verifies that:
#   1. A clean tree (canonical import present) -> PASS
#   2. A synthetic reinvention (corpus iteration + arc_id, no import) -> FAIL
#   3. A comment-only mention of the pattern does NOT trip the check
#      (the T-3502 false-positive class this design exists to avoid)
#   4. A file with corpus iteration and arc_id far apart (>60 lines, no
#      import) is NOT flagged (the estimator.py-shaped false-positive risk)
#   5. lib/arc_membership.py itself (canonical) is exempt

load ../test_helper

setup() {
    PROJECT_ROOT="$(mktemp -d)"
    guard_project_root
    export PROJECT_ROOT
    mkdir -p "$PROJECT_ROOT/lib" "$PROJECT_ROOT/web/blueprints" \
             "$PROJECT_ROOT/agents/foo" "$PROJECT_ROOT/tests/unit" \
             "$PROJECT_ROOT/lib/migrations" "$PROJECT_ROOT/docs"

    # Canonical file — allowlisted even though it obviously contains both
    # signals; the check must not scan it at all.
    cat > "$PROJECT_ROOT/lib/arc_membership.py" <<'EOF'
def scan_tasks_by_arc_membership(project_root):
    for sub in ("active", "completed"):
        for md in (project_root / ".tasks" / sub).glob("T-*.md"):
            arc_id = None
EOF

    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    export REPO_ROOT
}

teardown() {
    [ -n "${PROJECT_ROOT:-}" ] && [ -d "$PROJECT_ROOT" ] && rm -rf "$PROJECT_ROOT"
}

# Helper: run the SHIPPED check block against the synthetic PROJECT_ROOT.
# T-4380: the Python scanner is cut out of agents/audit/audit.sh (between the
# heredoc that fills arc_py_import_findings and its closing PY line); this file
# used to carry a copy of it, which stayed green when the shipped WINDOW was
# changed to 0. The block prints "scanned=N" and "FINDING <path>" lines; they are
# folded here into the PASS / "FAIL n" + findings shape the tests assert on.
run_check() {
    local block="$PROJECT_ROOT/.ctl-arc-membership-block.py"
    awk '/^    arc_py_import_findings=\$\(python3 - /{f=1; next} f && /^PY$/{exit} f' \
        "$REPO_ROOT/agents/audit/audit.sh" > "$block"
    [ -s "$block" ] || { echo "extraction empty - did the block move?" >&2; return 1; }
    grep -q 'WINDOW' "$block" || { echo "extraction lost the window logic" >&2; return 1; }
    python3 "$block" "$PROJECT_ROOT" | awk '
        /^FINDING /{n++; f[n]=substr($0,9)}
        END{ if (n) { print "FAIL " n; for (i=1;i<=n;i++) print f[i] } else print "PASS" }'
}

@test "clean tree (canonical file only) emits PASS" {
    run run_check
    [ "$status" -eq 0 ]
    [ "$output" = "PASS" ]
}

@test "synthetic reinvention (corpus iteration + arc_id, no import) triggers FAIL" {
    cat > "$PROJECT_ROOT/web/blueprints/reinvent.py" <<'EOF'
from pathlib import Path

def scan_bad(project_root):
    by_arc = {}
    for sub in ("active", "completed"):
        for md in (Path(project_root) / ".tasks" / sub).glob("T-*.md"):
            text = md.read_text()
            arc_id = None
            for line in text.splitlines():
                if line.startswith("arc_id:"):
                    arc_id = line.split(":", 1)[1].strip()
            if arc_id:
                by_arc.setdefault(arc_id, []).append(md.name)
    return by_arc
EOF
    run run_check
    [ "$status" -eq 0 ]
    [[ "$output" == FAIL* ]]
    [[ "$output" == *"reinvent.py"* ]]
}

@test "file that imports the canonical helper is exempt regardless of local text" {
    cat > "$PROJECT_ROOT/web/blueprints/delegates.py" <<'EOF'
from pathlib import Path
from lib.arc_membership import scan_tasks_by_arc_membership

def wrapper(project_root):
    for sub in ("active", "completed"):
        for md in (Path(project_root) / ".tasks" / sub).glob("T-*.md"):
            pass
    return scan_tasks_by_arc_membership(project_root)
EOF
    run run_check
    [ "$output" = "PASS" ]
}

@test "comment-only mention of the pattern does not trip the check" {
    cat > "$PROJECT_ROOT/web/blueprints/comment_only.py" <<'EOF'
# This module does not touch arc_id derivation directly. See
# lib/arc_membership.py scan_tasks_by_arc_membership for the canonical
# scan of .tasks/active and .tasks/completed by arc_id.

def unrelated():
    return 42
EOF
    run run_check
    [ "$output" = "PASS" ]
}

@test "corpus iteration and arc_id far apart (>60 lines, no import) is not flagged" {
    {
        echo "def iterate_corpus(project_root):"
        echo "    for md in (project_root / '.tasks' / 'active').glob('T-*.md'):"
        echo "        pass"
        for i in $(seq 1 80); do echo "    # padding line $i"; done
        echo ""
        echo "def unrelated_arc_id_lookup(arc_id):"
        echo "    return arc_id"
    } > "$PROJECT_ROOT/agents/foo/farapart.py"
    run run_check
    [ "$output" = "PASS" ]
}

@test "lib/arc_membership.py itself is exempt (canonical site)" {
    # Already created in setup — verifies PASS state holds.
    run run_check
    [ "$output" = "PASS" ]
}
