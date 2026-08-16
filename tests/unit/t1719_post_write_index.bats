#!/usr/bin/env bats
# T-1719 A1 — the post-write index hook, and the boundary of where it may be wired.
#
# CONTEXT THAT CHANGES WHAT THESE TESTS ARE FOR (OBS-292):
# `index-reindex-hourly` (T-3014) already reindexes every write site within an
# hour. So this hook is LATENCY REDUCTION, not coverage. Nothing here is
# load-bearing for correctness — which is exactly why the dominant property under
# test is that it CANNOT FAIL ITS CALLER. It sits on the path of
# `fw task update --status work-completed`; the cost of a missed index is one
# hour of staleness, the cost of a failed close is a blocked human.
#
# The second property under test is the WIRING BOUNDARY. index_one() re-chunks
# and re-embeds a whole file, so hooking it to a large aggregate spends several
# embed batches to add one entry — and `add-decision` runs in a per-decision loop
# at task close (update-task.sh:2251), which would multiply that by N. The
# aggregates are deliberately left to the cron, and these tests fail if someone
# later wires them, because that regression is invisible at runtime: it does not
# break anything, it just makes every task close slower and slower.

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    HELPER="$FRAMEWORK_ROOT/lib/post-write-index.sh"
    EPISODIC="$FRAMEWORK_ROOT/agents/context/lib/episodic.sh"
    PATTERN="$FRAMEWORK_ROOT/agents/context/lib/pattern.sh"
    LEARNING="$FRAMEWORK_ROOT/agents/context/lib/learning.sh"
    DECISION="$FRAMEWORK_ROOT/agents/context/lib/decision.sh"
}

@test "t1719: the helper sources and defines fw_post_write_index" {
    run bash -c ". '$HELPER' && declare -F fw_post_write_index"
    [ "$status" -eq 0 ]
}

@test "t1719: a missing file does not fail the caller" {
    # The whole contract. If this returns non-zero, a task close dies because a
    # file the indexer could not find is not a reason to block a human.
    run bash -c "
        PROJECT_ROOT='$FRAMEWORK_ROOT' . '$HELPER'
        fw_post_write_index '/definitely/not/a/real/path-t1719.yaml'
        echo rc=\$?
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"rc=0"* ]]
}

@test "t1719: an empty target does not fail the caller" {
    run bash -c "
        PROJECT_ROOT='$FRAMEWORK_ROOT' . '$HELPER'
        fw_post_write_index ''
        echo rc=\$?
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"rc=0"* ]]
}

@test "t1719: a project without web/embeddings.py is a silent no-op" {
    # Consumer installs without the embedding extras must not see errors from a
    # subsystem they never installed.
    run bash -c "
        PROJECT_ROOT='$BATS_TEST_TMPDIR' . '$HELPER'
        fw_post_write_index 'anything.yaml'
        echo rc=\$?
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"rc=0"* ]]
}

@test "t1719: FW_POST_WRITE_INDEX=0 disables the hook" {
    # The opt-out has to exist and has to be honoured, or the only way to escape a
    # misbehaving embedder on the close path is to edit framework source.
    run bash -c "
        PROJECT_ROOT='$FRAMEWORK_ROOT' FW_POST_WRITE_INDEX=0 . '$HELPER'
        fw_post_write_index '.context/episodic/does-not-matter.yaml'
        echo rc=\$?
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"rc=0"* ]]
}

@test "t1719: the hook is bounded by a timeout" {
    # A hung embedder must not stall a task close indefinitely. Pin that the
    # timeout is applied at all — without it the fail-silent contract is only
    # true for fast failures, not for hangs, which is the worse case.
    run grep -c 'timeout "\$FW_POST_WRITE_INDEX_TIMEOUT"' "$HELPER"
    [ "$status" -eq 0 ]
    [ "$output" -ge 1 ]
}

@test "t1719: episodic indexes AFTER yaml validation, never before" {
    # Indexing a file that failed to parse would push malformed content into
    # recall — and the validation block immediately above exists precisely to
    # stop that class propagating (T-1631 / G-082).
    validate_line=$(grep -n 'Episodic YAML validation failed' "$EPISODIC" | head -1 | cut -d: -f1)
    index_line=$(grep -n 'fw_post_write_index' "$EPISODIC" | head -1 | cut -d: -f1)
    [ -n "$validate_line" ]
    [ -n "$index_line" ]
    [ "$index_line" -gt "$validate_line" ]
}

@test "t1719: pattern.sh indexes after the file is moved into place" {
    # Indexing the temp file, or indexing before the mv, would index a path that
    # does not survive the call.
    mv_line=$(grep -n 'mv "\$temp_file" "\$patterns_file"' "$PATTERN" | head -1 | cut -d: -f1)
    index_line=$(grep -n 'fw_post_write_index' "$PATTERN" | head -1 | cut -d: -f1)
    [ -n "$mv_line" ]
    [ -n "$index_line" ]
    [ "$index_line" -gt "$mv_line" ]
}

@test "t1719: the large aggregates are NOT wired (OBS-292 boundary)" {
    # learnings.yaml is ~386 chunks and decisions.yaml ~112, written in a
    # per-decision loop at task close. Wiring either means N full re-embeds of the
    # same file in one command, to add one entry each. The hourly cron is the
    # proportionate answer. This regression would be invisible at runtime — it
    # breaks nothing, it just makes every close slower — so it needs a test.
    if [ -f "$LEARNING" ]; then
        run grep -c 'fw_post_write_index' "$LEARNING"
        [ "$output" -eq 0 ]
    fi
    if [ -f "$DECISION" ]; then
        run grep -c 'fw_post_write_index' "$DECISION"
        [ "$output" -eq 0 ]
    fi
}

@test "t1719: indexing a real document is idempotent and inside the latency budget" {
    # Re-indexing must not grow the chunk count: _delete_path_rows runs before
    # insert, and without it every hook fire would multiply that document's
    # chunks and crowd other documents out of top-k.
    run bash -c "
        cd '$FRAMEWORK_ROOT'
        python3 -c \"
import sys; sys.path.insert(0,'web')
import embeddings as e
if not e.is_index_ready(): print('SKIP'); raise SystemExit(0)
print('READY')
\"
    "
    [[ "$output" == *"SKIP"* ]] && skip "no index built"

    target=".context/episodic/T-3038.yaml"
    [ -f "$FRAMEWORK_ROOT/$target" ] || skip "probe episodic not present"

    _count() {
        cd "$FRAMEWORK_ROOT" && python3 -c "
import sys; sys.path.insert(0,'web')
import embeddings as e
db = e._get_db()
print(db.execute('SELECT COUNT(*) FROM documents WHERE path = ?', ('$target',)).fetchone()[0])
"
    }

    n1=$(_count)
    start=$(date +%s)
    bash -c "PROJECT_ROOT='$FRAMEWORK_ROOT' . '$HELPER'; fw_post_write_index '$target'"
    elapsed=$(( $(date +%s) - start ))
    n2=$(_count)

    [ "$n1" -eq "$n2" ]
    [ "$elapsed" -lt 30 ]
}
