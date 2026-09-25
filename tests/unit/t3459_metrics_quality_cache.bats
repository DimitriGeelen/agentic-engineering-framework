#!/usr/bin/env bats
# T-3459 — `_quality_scores()` in web/blueprints/metrics.py reads and
# frontmatter-parses EVERY task file in the corpus, active and completed.
# Measured: 2.883s of a ~3.1s /metrics request; the other four helpers on that
# route cost 0.21s between them.
#
# It is CACHED, not repointed. The alternative was to read
# shared.get_all_task_metadata(), which already caches task frontmatter — but
# this function computes its own aggregates, and one of them (a body regex for
# an acceptance-criteria heading) has no equivalent in that metadata at all.
# A metrics page reporting different metrics is worse than a slow one, so the
# computation is untouched and only its repetition is removed.
#
# The bug this file most needs to prevent is the one T-3459 fixed in shared.py
# hours earlier: a cache that stored its value and never stamped its timestamp,
# so it was populated and still never read as valid — every request recomputed.
# "Does it cache?" does not catch that; "does it STAMP?" does.
#
# No duration pinned (T-3326): 2.883s and 4.5x are this host's numbers.

load ../test_helper

_py() {
    run python3 - "$@" <<'PYEOF'
import os, sys
sys.path.insert(0, os.environ["FW_ROOT"] + "/web")
sys.path.insert(0, os.environ["FW_ROOT"])
os.environ.setdefault("PROJECT_ROOT", os.environ["FW_ROOT"])
os.environ.setdefault("FRAMEWORK_ROOT", os.environ["FW_ROOT"])
from app import create_app
app = create_app()
with app.app_context():
    from blueprints import metrics as M
    exec(sys.argv[1])
PYEOF
}

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export FW_ROOT="$FRAMEWORK_ROOT"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "the cache carries both a value and its own timestamp" {
    grep -q '_quality_cache = {"value": None, "ts": 0.0}' "$FRAMEWORK_ROOT/web/blueprints/metrics.py"
}

@test "_quality_scores stamps ts after computing, not just the value" {
    # The shared.py sibling bug: stored without stamping, so never read as valid.
    _py '
M._quality_cache["value"] = None; M._quality_cache["ts"] = 0.0
M._quality_scores()
print("STAMPED" if M._quality_cache["ts"] > 0 else "NOT_STAMPED")
'
    [ "$status" -eq 0 ]
    [[ "$output" == *"STAMPED"* ]]
}

@test "a second call inside the TTL is served from cache, not recomputed" {
    # Identity, not equality — a recomputation builds a new tuple.
    _py '
M._quality_cache["value"] = None; M._quality_cache["ts"] = 0.0
a = M._quality_scores(); b = M._quality_scores()
print("CACHED" if a is b else "RECOMPUTED")
'
    [ "$status" -eq 0 ]
    [[ "$output" == *"CACHED"* ]]
}

@test "an expired timestamp forces a recompute" {
    _py '
sentinel = (-1, -1)
M._quality_cache["value"] = sentinel; M._quality_cache["ts"] = 0.0
out = M._quality_scores()
print("STALE_SERVED" if out is sentinel else "RECOMPUTED")
'
    [ "$status" -eq 0 ]
    [[ "$output" == *"RECOMPUTED"* ]]
}

@test "the cached value equals a freshly computed one — caching changed no number" {
    _py '
M._quality_cache["value"] = None; M._quality_cache["ts"] = 0.0
first = M._quality_scores()
M._quality_cache["value"] = None; M._quality_cache["ts"] = 0.0
again = M._quality_scores()
print("EQUAL" if first == again else "DIFFER")
'
    [ "$status" -eq 0 ]
    [[ "$output" == *"EQUAL"* ]]
}

@test "the result is the documented shape: two integer percentages" {
    _py '
M._quality_cache["value"] = None; M._quality_cache["ts"] = 0.0
d, a = M._quality_scores()
ok = isinstance(d, int) and isinstance(a, int) and 0 <= d <= 100 and 0 <= a <= 100
print("SHAPE_OK" if ok else "SHAPE_BAD %r %r" % (d, a))
'
    [ "$status" -eq 0 ]
    [[ "$output" == *"SHAPE_OK"* ]]
}

@test "the empty-corpus path caches too — one return point, no unstamped branch" {
    # The original had an early `return 0, 0` for total == 0. If that path
    # bypassed the store/stamp, an empty corpus would recompute forever and the
    # two exits would drift. Pointing PROJECT_ROOT at an empty dir exercises it.
    _py '
from pathlib import Path
import tempfile
M._quality_cache["value"] = None; M._quality_cache["ts"] = 0.0
M.PROJECT_ROOT = Path(tempfile.mkdtemp())
out = M._quality_scores()
print("ZERO_CACHED" if out == (0, 0) and M._quality_cache["ts"] > 0 else "NOT_CACHED %r" % (out,))
'
    [ "$status" -eq 0 ]
    [[ "$output" == *"ZERO_CACHED"* ]]
}

@test "the TTL matches the window shared.py already uses for task metadata" {
    # Not a magic number: consistency with _TASK_CACHE_TTL is the reason 30 was
    # chosen. If one moves, this says so rather than letting them silently differ.
    run bash -c "grep -oE '_QUALITY_CACHE_TTL = [0-9]+' '$FRAMEWORK_ROOT/web/blueprints/metrics.py' | grep -oE '[0-9]+'"
    [ "$status" -eq 0 ]
    local q="$output"
    run bash -c "grep -oE '_TASK_CACHE_TTL = [0-9]+' '$FRAMEWORK_ROOT/web/shared.py' | grep -oE '[0-9]+'"
    [ "$status" -eq 0 ]
    [ "$q" = "$output" ]
}
