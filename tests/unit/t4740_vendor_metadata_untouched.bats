#!/usr/bin/env bats
load ../git_fence  # T-3610: git discovery must not escape a fixture into a repo above the temp dir
# T-4740 — a re-vendor must not rewrite the pinned designer build or the vendor
# metadata files when their content did not change.
#
# T-4720 made do_vendor's include copy write only changed files. The writers
# outside that loop still wrote every run: the pinned designer build (rm -f +
# cp + chmod 0444), VERSION, .fw-not-a-project, .gitignore, .upstream,
# FRAMEWORK.md, and .fw-vendor-stamp.json (whose written_at changed every run,
# so its bytes always differed). ring20 be.17 saw the designer build rewritten
# by a second no-op upgrade.
#
# The source is a small fixture repo (FRAMEWORK.md, a designer pin and its
# build, an origin remote for .upstream). After the first vendor every watched
# file is backdated, so any rewrite shows as a moved mtime.

load ../test_helper

FW_BIN="$FRAMEWORK_ROOT/bin/fw"
WATCHED=(vendor/designer/aef-workflow-designer-v1.html .fw-vendor-stamp.json VERSION
         FRAMEWORK.md .gitignore .upstream .fw-not-a-project)

_mk_source() {
    local s="$1"
    mkdir -p "$s/policy" "$s/vendor/designer"
    echo "# fixture framework" > "$s/FRAMEWORK.md"
    echo 'vendored_path: "vendor/designer/aef-workflow-designer-v1.html"' > "$s/policy/designer-pin.yaml"
    echo "<html>v1</html>" > "$s/vendor/designer/aef-workflow-designer-v1.html"
    git -C "$s" init -q
    git -C "$s" remote add origin https://example.invalid/aef-t4740.git
    git -C "$s" add -A
    git -C "$s" -c user.name=t -c user.email=t@t commit -qm fixture
}

_mtimes() {
    local f
    for f in "${WATCHED[@]}"; do
        printf '%s %s\n' "$f" "$(stat -c %Y "$1/.agentic-framework/$f")"
    done
}

_backdate() {
    local f
    for f in "${WATCHED[@]}"; do
        touch -d '@1000000000' "$1/.agentic-framework/$f"
    done
}

_vendor() {
    run timeout 600 "$FW_BIN" vendor --target "$1" --source "$2"
    [ "$status" -eq 0 ] || { echo "$output" | tail -20; false; }
}

# Files whose mtime moved since $2 (a _mtimes snapshot).
_moved() {
    diff <(echo "$2") <(_mtimes "$1") | grep '^>' | awk '{print $2}' | LC_ALL=C sort | tr '\n' ' '
}

@test "T-4740: no-op re-vendor leaves the designer build and all six metadata files untouched" {
    local c="$TEST_TEMP_DIR/consumer" s="$TEST_TEMP_DIR/src"
    mkdir -p "$c"; git -C "$c" init -q
    _mk_source "$s"
    _vendor "$c" "$s"
    local f
    for f in "${WATCHED[@]}"; do [ -f "$c/.agentic-framework/$f" ] || { echo "missing $f"; false; }; done
    local stamp_before
    stamp_before="$(cat "$c/.agentic-framework/.fw-vendor-stamp.json")"
    _backdate "$c"
    local before
    before="$(_mtimes "$c")"

    _vendor "$c" "$s"
    local moved
    moved="$(_moved "$c" "$before")"
    [ -z "$moved" ] || { echo "rewritten by a no-op re-vendor: $moved"; false; }
    [ "$(cat "$c/.agentic-framework/.fw-vendor-stamp.json")" = "$stamp_before" ]
    # The designer build stays read-only.
    [ "$(stat -c %a "$c/.agentic-framework/vendor/designer/aef-workflow-designer-v1.html")" = 444 ]
}

@test "T-4740: a real change still rewrites the affected file and only that file" {
    local c="$TEST_TEMP_DIR/consumer" s="$TEST_TEMP_DIR/src" v
    mkdir -p "$c"; git -C "$c" init -q
    _mk_source "$s"
    _vendor "$c" "$s"
    v="$c/.agentic-framework"
    local before moved

    # Designer build content changes under the same pin: build + stamp move.
    _backdate "$c"; before="$(_mtimes "$c")"
    echo "<html>v1 rebuilt</html>" > "$s/vendor/designer/aef-workflow-designer-v1.html"
    _vendor "$c" "$s"
    moved="$(_moved "$c" "$before")"
    [ "$moved" = ".fw-vendor-stamp.json vendor/designer/aef-workflow-designer-v1.html " ] || { echo "moved: $moved"; false; }
    grep -q "v1 rebuilt" "$v/vendor/designer/aef-workflow-designer-v1.html"
    [ "$(stat -c %a "$v/vendor/designer/aef-workflow-designer-v1.html")" = 444 ]

    # Upstream URL changes: .upstream and the stamp (which digests it) move.
    _backdate "$c"; before="$(_mtimes "$c")"
    git -C "$s" remote set-url origin https://example.invalid/aef-t4740-moved.git
    _vendor "$c" "$s"
    moved="$(_moved "$c" "$before")"
    [ "$moved" = ".fw-vendor-stamp.json .upstream " ] || { echo "moved: $moved"; false; }
    grep -q "aef-t4740-moved" "$v/.upstream"

    # FRAMEWORK.md changes: it and the stamp move.
    _backdate "$c"; before="$(_mtimes "$c")"
    echo "# fixture framework, edited" > "$s/FRAMEWORK.md"
    _vendor "$c" "$s"
    moved="$(_moved "$c" "$before")"
    [ "$moved" = ".fw-vendor-stamp.json FRAMEWORK.md " ] || { echo "moved: $moved"; false; }

    # A drifted generated file (VERSION, .gitignore, sentinel) is restored.
    echo stale > "$v/VERSION"
    echo stale > "$v/.gitignore"
    echo stale > "$v/.fw-not-a-project"
    _vendor "$c" "$s"
    ! grep -qx stale "$v/VERSION" || false
    grep -q '__pycache__/' "$v/.gitignore"
    grep -q 'T-1841' "$v/.fw-not-a-project"

    # Pin bump: the new build lands, the superseded one is pruned.
    echo "<html>v2</html>" > "$s/vendor/designer/aef-workflow-designer-v2.html"
    echo 'vendored_path: "vendor/designer/aef-workflow-designer-v2.html"' > "$s/policy/designer-pin.yaml"
    _vendor "$c" "$s"
    [ -f "$v/vendor/designer/aef-workflow-designer-v2.html" ]
    [ ! -e "$v/vendor/designer/aef-workflow-designer-v1.html" ]
}
