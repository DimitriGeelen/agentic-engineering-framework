#!/usr/bin/env bats
#
# T-3850 — `fw vendor` deleted consumer-local files and overwrote in-file
# patches under .agentic-framework/, silently. ring20-manager lost 7 Watchtower
# blueprints, 6 templates, lib/approval_channel.py and ~40 in-file patches on
# v1.8.0 and rolled back (second incident; first was ring20 T-2019).
#
# Synthetic consumer, FIXTURES ONLY: a tiny git-tracked framework source at v1,
# vendored into a consumer that then adds a local blueprint and template, patches
# an upstream file in place, and edits another. The source moves to v2 (changes
# both edited files, deletes one upstream file). Then the vendor runs again.

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    TMP="$(mktemp -d)"
    SRC="$TMP/src"
    PROJ="$TMP/proj"
    AF="$PROJ/.agentic-framework"

    mkdir -p "$SRC/bin" "$SRC/lib" "$SRC/web/blueprints" "$SRC/web/templates"
    printf '#!/bin/sh\necho stub\n' > "$SRC/bin/fw"; chmod +x "$SRC/bin/fw"
    echo "# framework" > "$SRC/FRAMEWORK.md"
    echo "a v1" > "$SRC/lib/a.sh"
    echo "app v1" > "$SRC/web/app.py"
    echo "core v1" > "$SRC/web/blueprints/core.py"
    echo "<p>base</p>" > "$SRC/web/templates/base.html"
    git -C "$SRC" init -q
    git -C "$SRC" -c user.email=t@example.invalid -c user.name=t add -A
    git -C "$SRC" -c user.email=t@example.invalid -c user.name=t commit -qm v1

    mkdir -p "$PROJ"
    git -C "$PROJ" init -q
    _vendor >/dev/null
    [ -f "$AF/.fw-vendor-stamp.json" ]

    # Consumer-local work.
    echo "local blueprint" > "$AF/web/blueprints/approvals.py"
    echo "<p>ring20</p>" > "$AF/web/templates/ring20_approvals.html"
    printf 'app v1\n# ring20-local: approvals\n' > "$AF/web/app.py"
    echo "a v1 + ring20 edit" > "$AF/lib/a.sh"

    # Upstream moves to v2.
    echo "a v2" > "$SRC/lib/a.sh"
    echo "app v2" > "$SRC/web/app.py"
    git -C "$SRC" rm -q web/blueprints/core.py
    git -C "$SRC" -c user.email=t@example.invalid -c user.name=t commit -qam v2
}

teardown() { rm -rf "$TMP"; }

_vendor() {
    ( cd "$PROJ" && env FRAMEWORK_ROOT="$FRAMEWORK_ROOT" PROJECT_ROOT="$PROJ" \
        "$FRAMEWORK_ROOT/bin/fw" vendor --target "$PROJ" --source "$SRC" "$@" 2>&1 )
}

_manifest() {
    cat > "$PROJ/.fwvendor-preserve.yaml" <<'YAML'
files:
  - web/blueprints/approvals.py
  - path: .agentic-framework/web/templates/ring20_*.html
    reason: ring20 approval UI
  - lib/a.sh
in_file:
  - file: web/app.py
    marker: "ring20-local: approvals"
YAML
}

@test "no manifest: refuses, names every local file, writes nothing" {
    run _vendor
    [ "$status" -ne 0 ]
    echo "$output" | grep -q "LOCAL  web/blueprints/approvals.py  — local-only — would be DELETED"
    echo "$output" | grep -q "LOCAL  web/templates/ring20_approvals.html"
    echo "$output" | grep -q "LOCAL  web/app.py  — edited locally — would be OVERWRITTEN"
    echo "$output" | grep -q "LOCAL  lib/a.sh  — edited locally"
    echo "$output" | grep -q -- "--allow-delete-locals"
    # The upstream deletion is the framework's, not a local file.
    ! echo "$output" | grep -q "LOCAL  web/blueprints/core.py"
    # Nothing written.
    [ -f "$AF/web/blueprints/approvals.py" ]
    grep -q "ring20-local: approvals" "$AF/web/app.py"
    [ -f "$AF/web/blueprints/core.py" ]
    grep -q "a v1 + ring20 edit" "$AF/lib/a.sh"
}

@test "manifest: nothing lost, every change reported" {
    _manifest
    run _vendor
    [ "$status" -eq 0 ]
    # files: local-only survive
    grep -q "local blueprint" "$AF/web/blueprints/approvals.py"
    grep -q "ring20" "$AF/web/templates/ring20_approvals.html"
    # files: upstream file keeps local content, upstream change is named
    grep -q "a v1 + ring20 edit" "$AF/lib/a.sh"
    echo "$output" | grep -q "KEPT-LOCAL  lib/a.sh  — UPSTREAM CHANGED it"
    # in_file: upstream taken, missing marker named by file + marker, copy kept
    grep -q "app v2" "$AF/web/app.py"
    echo "$output" | grep -q 'MARKER MISSING  web/app.py: "ring20-local: approvals"'
    backup=$(ls -d "$PROJ"/.context/working/vendor-backup/*)
    grep -q "ring20-local: approvals" "$backup/web/app.py"
    # upstream deletion still happens, and is not reported as local
    [ ! -e "$AF/web/blueprints/core.py" ]
    ! echo "$output" | grep -q "LOCAL  web/blueprints/core.py"
}

@test "manifest: in_file marker carried upstream is reported present" {
    _manifest
    printf 'app v2\n# ring20-local: approvals\n' > "$SRC/web/app.py"
    git -C "$SRC" -c user.email=t@example.invalid -c user.name=t commit -qam v2b
    run _vendor
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "IN-FILE   1/1 marker(s) present after vendor"
    ! echo "$output" | grep -q "MARKER MISSING"
}

@test "--allow-delete-locals: proceeds, logs Tier-2, keeps a copy" {
    run _vendor --allow-delete-locals
    [ "$status" -eq 0 ]
    [ ! -e "$AF/web/blueprints/approvals.py" ]
    grep -q "app v2" "$AF/web/app.py"
    grep -q "gate: vendor-delete-locals" "$PROJ/.context/working/.gate-bypass-log.yaml"
    backup=$(ls -d "$PROJ"/.context/working/vendor-backup/*)
    grep -q "local blueprint" "$backup/web/blueprints/approvals.py"
    grep -q "ring20-local: approvals" "$backup/web/app.py"
}

@test "no stamp yet: local-only judged by source git history; stamp written" {
    rm -f "$AF/.fw-vendor-stamp.json"
    git -C "$PROJ" init -q 2>/dev/null || true
    run _vendor
    [ "$status" -ne 0 ]
    echo "$output" | grep -q "no vendor stamp yet"
    echo "$output" | grep -q "LOCAL  web/blueprints/approvals.py"
    # core.py was in the source's history -> upstream-deleted, not local
    ! echo "$output" | grep -q "LOCAL  web/blueprints/core.py"
    # edits are undetectable without a stamp: not claimed
    ! echo "$output" | grep -q "LOCAL  web/app.py"
    _manifest
    run _vendor
    [ "$status" -eq 0 ]
    [ -f "$AF/.fw-vendor-stamp.json" ]
    python3 -c "import json,sys; d=json.load(open('$AF/.fw-vendor-stamp.json')); sys.exit(0 if 'web/app.py' in d['files'] else 1)"
}

@test "--dry-run reports without writing or refusing" {
    run _vendor --dry-run
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "LOCAL  web/blueprints/approvals.py"
    [ -f "$AF/web/blueprints/approvals.py" ]
}

@test "fallback parser (no PyYAML) reads the manifest shape the same as PyYAML" {
    python3 -c "import yaml" 2>/dev/null || skip "PyYAML absent: parity needs a reference"
    run python3 - "$FRAMEWORK_ROOT/lib" <<'PY'
import sys, yaml
sys.path.insert(0, sys.argv[1])
import vendor_preserve as v
t = """files:
  - web/a.py
  - path: .agentic-framework/web/t_*.html
    reason: x
in_file:
  - file: web/app.py
    marker: "m1"
  - file: lib/n.sh
    markers:
      - "m2"
      - m3
  - file: lib/o.sh
    markers: ["m4", m5]
"""
sys.exit(0 if v._mini_yaml(t) == yaml.safe_load(t) else 1)
PY
    [ "$status" -eq 0 ]
}

@test "T-3851: a preserved local file is not judged by the visibility check" {
    _manifest
    # The consumer keeps its local blueprint out of git; that is its business,
    # not a vendored file going missing from clones.
    printf '%s\n' '.agentic-framework/web/blueprints/approvals.py' > "$PROJ/.gitignore"
    run _vendor
    [ "$status" -eq 0 ] || { echo "$output"; false; }
    [ -f "$AF/web/blueprints/approvals.py" ]
    ! echo "$output" | grep -q "invisible to git"
}
