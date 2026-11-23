#!/usr/bin/env bats
# T-3513: blast_radius falls back to paths NAMED in the task body, resolved
# through the component fabric — and unknown stays unknown (None), never 0.
#
# Hermetic: a fixture project with its own .fabric/components graph (incl. a
# cycle). Never anchored to the live fabric, whose size changes weekly (T-3326).

setup() {
    FRAMEWORK_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    export FRAMEWORK_ROOT
    FIX="$BATS_TEST_TMPDIR/proj"
    mkdir -p "$FIX/lib" "$FIX/.fabric/components"
    for f in a b c d nocard; do echo x > "$FIX/lib/$f.py"; done
    # Graph (depended_by edges): a -> b -> c -> a (cycle); d is a leaf.
    # c's edge back to a is written by card id, b's by location, to cover both.
    cat > "$FIX/.fabric/components/a.yaml" <<'EOF'
id: C-A
name: a
location: lib/a.py
depended_by:
- target: lib/b.py
  type: uses_by
EOF
    cat > "$FIX/.fabric/components/b.yaml" <<'EOF'
id: C-B
name: b
location: lib/b.py
depended_by:
- target: C-C
  type: uses_by
EOF
    cat > "$FIX/.fabric/components/c.yaml" <<'EOF'
id: C-C
name: c
location: lib/c.py
depended_by:
- target: C-A
  type: uses_by
EOF
    cat > "$FIX/.fabric/components/d.yaml" <<'EOF'
id: C-D
name: d
location: lib/d.py
depended_by: []
EOF
    # A card whose file does not exist: must not count.
    cat > "$FIX/.fabric/components/ghost.yaml" <<'EOF'
id: C-G
name: ghost
location: lib/ghost.py
depended_by: []
EOF
}

# score <fm-json> <body-file> → prints "<value>|<evidence>"
score() {
    PROJECT_ROOT="$FIX" python3 - "$FRAMEWORK_ROOT" "$1" "$2" <<'PY'
import json, sys
sys.path.insert(0, sys.argv[1] + "/agents/termlink/bvp-estimator")
import estimator as E
fm = json.loads(sys.argv[2])
body = open(sys.argv[3]).read()
v, ev = E.score_blast_radius(fm, body, [])
print(f"{v}|{ev[0]}")
PY
}

body() { printf '%s\n' "$1" > "$BATS_TEST_TMPDIR/body.md"; echo "$BATS_TEST_TMPDIR/body.md"; }

@test "named path with dependents: cards + transitive depended_by, cycle-safe" {
    run score '{}' "$(body 'Fix the bug in `lib/a.py` before release.')"
    [ "$status" -eq 0 ]
    [ "$output" = "3|→3 (1-fabric-paths, 2-dependents)" ]
}

@test "bare path and leaf card both count; each card once" {
    run score '{}' "$(body 'Touches lib/d.py and lib/a.py, and again lib/a.py.')"
    [ "$status" -eq 0 ]
    [ "$output" = "5|→5 (2-fabric-paths, 2-dependents)" ]
}

@test "named path without a card is unknown (None), never 0" {
    run score '{}' "$(body 'Edit lib/nocard.py and lib/ghost.py.')"
    [ "$status" -eq 0 ]
    [ "$output" = "None|→? (no-components-no-fabric-paths-UNMEASURED-not-zero)" ]
}

@test "no paths at all is unknown (None), never 0" {
    run score '{}' "$(body 'A task that names no file.')"
    [ "$status" -eq 0 ]
    [ "$output" = "None|→? (no-components-no-fabric-paths-UNMEASURED-not-zero)" ]
}

@test "template comments, globs, URLs and framework-state paths are ignored" {
    run score '{}' "$(body '<!-- see lib/a.py -->
# Verification comment naming lib/b.py
Glob lib/*.py, url https://example.com/lib/c.py, state .tasks/lib/d.py')"
    [ "$status" -eq 0 ]
    [ "$output" = "None|→? (no-components-no-fabric-paths-UNMEASURED-not-zero)" ]
}

@test "components present: scores exactly as before, fabric leg not reached" {
    run score '{"components": ["x"]}' "$(body 'Fix lib/a.py.')"
    [ "$status" -eq 0 ]
    [ "$output" = "1|→1 (single-component)" ]
}

@test "write_set present: scores exactly as before, fabric leg not reached" {
    run score '{"write_set": ["lib/d.py"]}' "$(body 'Fix lib/a.py.')"
    [ "$status" -eq 0 ]
    [ "$output" = "1|→1 (1-write-set-paths)" ]
}
