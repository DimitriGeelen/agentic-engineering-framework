#!/usr/bin/env bats
# T-3459 — `get_episodic_tags()` shared one timestamp with
# `get_all_task_metadata()`, and that single `ts` was wrong in both directions.
#
#   * get_episodic_tags() stored its result but never stamped `ts`, so unless the
#     other function had run inside the TTL, the freshness check failed and the
#     whole .context/episodic/ corpus was re-parsed on the very next request.
#   * and when get_all_task_metadata() DID stamp `ts`, a `tags` computed
#     arbitrarily long ago started reading as fresh, with nothing to recompute
#     it — stale data served for as long as the other function kept being called.
#
# One timestamp for two independently-populated entries cannot be right: stamped
# by both, each makes the other look fresh; stamped by one, the other never
# caches. Both halves were live.
#
# Guards the PROPERTY (the entry carries and honours its own stamp), never a
# duration — TTL seconds and corpus counts both rot (T-3326).

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "the tags entry has its own timestamp key, separate from ts" {
    grep -q '"tags_ts": 0' "$FRAMEWORK_ROOT/web/shared.py"
}

@test "the freshness check reads tags_ts, not the shared ts" {
    # The regression is exactly this line reverting to `ts`.
    run grep -c 'now - _task_cache\["tags_ts"\]) < _TASK_CACHE_TTL' "$FRAMEWORK_ROOT/web/shared.py"
    [ "$output" = "1" ]
}

@test "get_episodic_tags stamps tags_ts after computing" {
    # Storing a value without stamping it is the original bug: the cache is
    # populated and still never reads as valid.
    run python3 -c "
import sys; sys.path.insert(0, '$FRAMEWORK_ROOT/web')
import shared
shared._task_cache['tags'] = None
shared._task_cache['tags_ts'] = 0
shared.get_episodic_tags()
print('STAMPED' if shared._task_cache['tags_ts'] > 0 else 'NOT_STAMPED')
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"STAMPED"* ]]
}

@test "a second call inside the TTL is served from cache, not recomputed" {
    # Identity, not equality: a recomputation would build a new dict.
    run python3 -c "
import sys; sys.path.insert(0, '$FRAMEWORK_ROOT/web')
import shared
shared._task_cache['tags'] = None
shared._task_cache['tags_ts'] = 0
a = shared.get_episodic_tags()
b = shared.get_episodic_tags()
print('CACHED' if a is b else 'RECOMPUTED')
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"CACHED"* ]]
}

@test "refreshing the task-metadata stamp does NOT make stale tags read as fresh" {
    # The second half of the bug. Stamping `ts` used to satisfy the tags
    # freshness check, serving a tags dict that nothing had recomputed.
    run python3 -c "
import sys; sys.path.insert(0, '$FRAMEWORK_ROOT/web')
import shared, time
sentinel = {'T-SENTINEL': ['stale']}
shared._task_cache['tags'] = sentinel
shared._task_cache['tags_ts'] = 0          # tags are stale
shared._task_cache['ts'] = time.monotonic() # but the OTHER entry is fresh
out = shared.get_episodic_tags()
print('STALE_SERVED' if out is sentinel else 'RECOMPUTED')
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"RECOMPUTED"* ]]
}

@test "an expired tags_ts forces a recompute" {
    run python3 -c "
import sys; sys.path.insert(0, '$FRAMEWORK_ROOT/web')
import shared
sentinel = {'T-SENTINEL': ['expired']}
shared._task_cache['tags'] = sentinel
shared._task_cache['tags_ts'] = 0
out = shared.get_episodic_tags()
print('STALE_SERVED' if out is sentinel else 'RECOMPUTED')
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"RECOMPUTED"* ]]
}

@test "the cached value is equal to a freshly computed one (caching changed no data)" {
    run python3 -c "
import sys; sys.path.insert(0, '$FRAMEWORK_ROOT/web')
import shared
shared._task_cache['tags'] = None; shared._task_cache['tags_ts'] = 0
fresh = dict(shared.get_episodic_tags())
shared._task_cache['tags'] = None; shared._task_cache['tags_ts'] = 0
again = dict(shared.get_episodic_tags())
print('EQUAL' if fresh == again else 'DIFFER')
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"EQUAL"* ]]
}
