#!/usr/bin/env bats
load ../git_fence  # T-3610: git discovery must not escape a fixture into a repo above the temp dir
# T-4720 — a re-vendor must not rewrite files whose content did not change.
#
# do_vendor (bin/fw) copied with `rsync -a`, whose quick check is size+mtime.
# A vendor source is a fresh checkout or clone, so every file's mtime differs,
# every file was rewritten, and each got the source's new mtime. The running
# Watchtower's currency check (lib/watchtower-staleness.sh: web/ mtimes vs the
# process start) then reported STALE after every `fw upgrade`, with nothing
# changed. The cp fallback (rm -rf + cp -r) did the same.
#
# The sources here are git-archive copies of the framework (never the working
# tree), touched to "now" the way a fresh clone is. The consumer's vendored
# web/ is backdated after the first vendor, so any rewrite shows as a moved
# mtime. The bin/fw under test is the working tree's.

load ../test_helper

FW_BIN="$FRAMEWORK_ROOT/bin/fw"

# A framework copy built from git, touched to now (a fresh clone's mtimes).
_archive_fw() {
    local out="$1" p
    local -a paths=()
    for p in bin lib agents web docs policy .tasks/templates .tasks/workflow metrics.sh \
             .secret-scan-patterns .secret-scan-allowlist status-transitions.yaml tools \
             .context/designer/projects FRAMEWORK.md; do
        git -C "$FRAMEWORK_ROOT" cat-file -e "HEAD:$p" 2>/dev/null && paths+=("$p")
    done
    mkdir -p "$out"
    git -C "$FRAMEWORK_ROOT" archive HEAD "${paths[@]}" | tar -x -C "$out"
    find "$out" -exec touch {} +
}

_web_mtimes() {
    (cd "$1/.agentic-framework/web" && find . -type f -printf '%P %T@\n' | LC_ALL=C sort)
}

# Same farm as vendor_exclude_anchoring.bats: every PATH executable but rsync.
# Built once per file (it is ~10 s of symlinks).
setup_file() {
    _make_no_rsync_path >/dev/null
}

_make_no_rsync_path() {
    local farm="$BATS_FILE_TMPDIR/no-rsync-bin"
    [ -d "$farm" ] && { echo "$farm"; return 0; }
    mkdir -p "$farm"
    local dir bin name
    local IFS=':'
    for dir in $PATH; do
        [ -d "$dir" ] || continue
        for bin in "$dir"/*; do
            [ -x "$bin" ] && [ -f "$bin" ] || continue
            name=$(basename "$bin")
            [ "$name" = "rsync" ] && continue
            [ -e "$farm/$name" ] && continue
            ln -s "$bin" "$farm/$name" 2>/dev/null || true
        done
    done
    echo "$farm"
}

# $1 = PATH to run fw vendor under. Vendors, re-vendors with no change, then
# with one changed web/ file, checking mtimes and watchtower_stale_sources.
_exercise() {
    local vpath="$1"
    local c="$TEST_TEMP_DIR/consumer" s1="$TEST_TEMP_DIR/src1" s2="$TEST_TEMP_DIR/src2"
    mkdir -p "$c"
    git -C "$c" init -q
    _archive_fw "$s1"

    PATH="$vpath" run timeout 600 "$FW_BIN" vendor --target "$c" --source "$s1"
    [ "$status" -eq 0 ] || { echo "$output" | tail -20; false; }
    local web="$c/.agentic-framework/web"
    [ -f "$web/app.py" ]

    # Vendored long ago, before the Watchtower started.
    find "$web" -type f -exec touch -d '@1000000000' {} +
    local before
    before="$(_web_mtimes "$c")"
    [ -n "$before" ]

    # A Watchtower stand-in that started after the vendor.
    sleep 300 &
    local wt_pid=$!
    sleep 2

    # Fresh clone, same content: nothing may be written.
    _archive_fw "$s2"
    PATH="$vpath" run timeout 600 "$FW_BIN" vendor --target "$c" --source "$s2"
    [ "$status" -eq 0 ] || { kill "$wt_pid"; echo "$output" | tail -20; false; }
    local after
    after="$(_web_mtimes "$c")"
    if [ "$before" != "$after" ]; then
        kill "$wt_pid"
        diff <(echo "$before") <(echo "$after") | head -10
        false
    fi

    source "$FRAMEWORK_ROOT/lib/watchtower-staleness.sh"
    export FW_WATCHTOWER_STALE_TOLERANCE=0
    run watchtower_stale_sources "$wt_pid" "$web"
    [ "$status" -eq 1 ] || { kill "$wt_pid"; echo "no-op re-vendor read as stale: $output"; false; }
    [ -z "$output" ] || { kill "$wt_pid"; false; }

    # One real change: only that file moves, and the check names it.
    echo "# T-4720 changed" >> "$s2/web/app.py"
    PATH="$vpath" run timeout 600 "$FW_BIN" vendor --target "$c" --source "$s2"
    [ "$status" -eq 0 ] || { kill "$wt_pid"; echo "$output" | tail -20; false; }
    local moved
    moved="$(diff <(echo "$before") <(_web_mtimes "$c") | grep '^>' | awk '{print $2}')"
    [ "$moved" = "app.py" ] || { kill "$wt_pid"; echo "moved: $moved"; false; }
    grep -q "T-4720 changed" "$web/app.py" || { kill "$wt_pid"; false; }

    run watchtower_stale_sources "$wt_pid" "$web"
    kill "$wt_pid" 2>/dev/null || true
    [ "$status" -eq 0 ]
    [ "$output" = "$web/app.py" ]
}

@test "T-4720: rsync branch — no-op re-vendor touches no web/ file; one change moves only its mtime and reads stale" {
    command -v rsync >/dev/null || skip "rsync not available"
    _exercise "$PATH"
}

@test "T-4720: cp fallback (rsync hidden) — no-op re-vendor touches no web/ file; one change moves only its mtime and reads stale" {
    local farm
    farm="$(_make_no_rsync_path)"
    if PATH="$farm" command -v rsync >/dev/null 2>&1; then false; fi
    _exercise "$farm"
}

@test "T-4720: cp fallback mirrors deletions, additions and exec-bit changes" {
    local farm s="$TEST_TEMP_DIR/s" d="$TEST_TEMP_DIR/d"
    farm="$(_make_no_rsync_path)"
    mkdir -p "$s/web/sub" "$d"
    echo "# fixture" > "$s/FRAMEWORK.md"
    echo keep > "$s/web/keep.py"
    echo gone > "$s/web/sub/gone.py"
    echo run > "$s/web/run.sh"
    PATH="$farm" run "$FW_BIN" vendor --target "$d" --source "$s"
    [ "$status" -eq 0 ]
    local v="$d/.agentic-framework/web"
    [ -f "$v/sub/gone.py" ]
    [ ! -x "$v/run.sh" ]

    rm -rf "$s/web/sub"
    echo new > "$s/web/new.py"
    chmod +x "$s/web/run.sh"
    PATH="$farm" run "$FW_BIN" vendor --target "$d" --source "$s"
    [ "$status" -eq 0 ]
    [ ! -e "$v/sub" ]
    [ -f "$v/new.py" ]
    [ -x "$v/run.sh" ]
    [ "$(cat "$v/keep.py")" = keep ]
}
