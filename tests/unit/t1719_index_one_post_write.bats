#!/usr/bin/env bats
# T-1719 A1 — index_one() is the post-write path for arc-002's recall loop.
#
# The AC has two halves and both are pinned here: BEHAVIOUR (a just-written
# document becomes retrievable without a full reindex) and a LATENCY BUDGET
# (<5s on a typical entry). The budget is the whole reason this function
# exists — build_index() is a corpus rebuild measured in hours and
# reindex_incremental() copies the database and swaps it, so neither can sit
# on the path of `fw task update --status work-completed`.
#
# The concurrency contract is the subtle part and gets its own test.
# reindex_incremental() builds on a COPY and os.replace()s it over DB_PATH.
# A write into the live file while that copy is in flight lands on the old
# inode and is discarded by the swap — silently. So index_one takes the same
# advisory lock, non-blocking, and SKIPS when a reindex owns it. Skipping is
# the correct behaviour, not a degradation: the running reindex reads the file
# from disk anyway, so the content is indexed either way. Blocking would stall
# a task close behind a 25-minute rebuild, which is the failure this design
# exists to avoid.
#
# Tests that need a live embedder are skipped when the index is not ready,
# rather than failing — a machine without the corpus built is not a regression.

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    EMB="$FRAMEWORK_ROOT/web/embeddings.py"
}

_py() {
    cd "$FRAMEWORK_ROOT" && python3 -c "
import sys
sys.path.insert(0, 'web')
$1
"
}

@test "t1719: index_one exists and is importable" {
    run _py "import embeddings as e; assert callable(e.index_one); print('ok')"
    [ "$status" -eq 0 ]
    [[ "$output" == *"ok"* ]]
}

@test "t1719: index_one takes the reindex lock, not a private one" {
    # If this drifts to a different lock path, the mutual exclusion with
    # reindex_incremental() silently disappears and the failure mode is a lost
    # write that nothing reports. Pin the shared suffix.
    run grep -c 'reindex.lock' "$EMB"
    [ "$status" -eq 0 ]
    [ "$output" -ge 2 ]  # reindex_incremental + index_one
}

@test "t1719: index_one acquires the lock non-blocking" {
    # LOCK_NB is what turns 'reindex running' into a fast skip instead of a
    # multi-minute stall on a task close.
    run grep -c 'LOCK_EX | fcntl.LOCK_NB' "$EMB"
    [ "$status" -eq 0 ]
    [ "$output" -ge 2 ]
}

@test "t1719: a path outside PROJECT_ROOT is refused, not indexed" {
    run _py "
import embeddings as e
r = e.index_one('/etc/hostname')
assert r.get('skipped') == 'outside-project-root', r
print('ok')
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"ok"* ]]
}

@test "t1719: a missing file is skipped, never raised" {
    # A post-write hook must not be able to fail a task close. Returning a
    # skip reason is the contract; an exception here would propagate into
    # update-task.sh and block completion on an unrelated fault.
    run _py "
import embeddings as e
r = e.index_one('docs/reports/definitely-not-a-real-file-t1719.md')
assert 'skipped' in r, r
print('ok')
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"ok"* ]]
}

@test "t1719: an empty file is skipped rather than indexed as a null chunk" {
    run _py "
import embeddings as e, pathlib, os
p = pathlib.Path(e.PROJECT_ROOT) / '.context' / 'working' / '.t1719-empty-probe.md'
p.parent.mkdir(parents=True, exist_ok=True)
p.write_text('   \n\n')
try:
    r = e.index_one(str(p))
    assert r.get('skipped') == 'empty', r
finally:
    os.unlink(p)
print('ok')
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"ok"* ]]
}

@test "t1719: indexing a document makes it retrievable and stays under the 5s budget" {
    # The AC's headline claim. Skipped (not failed) when no index is built —
    # a machine without the corpus is not a regression.
    #
    # 2026-09-06: the subject used to be this task's own LIVE file — which grew
    # a little on every dispatch (BVP proposals, Evolution entries) until, at
    # 124 chunks, a cold-model run blew the 5s budget the test exists to pin.
    # A latency budget measured against a monotonically growing subject fails
    # eventually by construction and says nothing when it does. The subject is
    # now a FIXED-SIZE synthetic doc (~10 chunks, a representative task-file
    # write), embedded with a per-run nonce so retrieval proves THIS write
    # landed. One warm-up embed absorbs the model-load cost first: the budget
    # is about index_one's own path, not about whether ollama had the model
    # resident before the suite started. Rows and file are cleaned up after.
    run _py "
import embeddings as e, time, os, pathlib
if not e.is_index_ready():
    print('SKIP-no-index')
    raise SystemExit(0)
nonce = 'latencyprobe' + os.urandom(4).hex()
rel = '.context/working/.t1719-latency-probe.md'
fx = pathlib.Path(e.PROJECT_ROOT) / rel
para = ('The quick brown governance gate audits the embedding retrieval loop '
        'for provenance, freshness and recall quality across the corpus. ') * 12
fx.write_text('# Latency probe ' + nonce + '\n\n'
              + '\n\n'.join(f'## Section {i} {nonce}\n\n{para}' for i in range(10)))
try:
    e._embed_single('warm-up ' + nonce)   # model residency is not under test
    t = time.time()
    r = e.index_one(rel)
    elapsed = time.time() - t
    if r.get('skipped') == 'reindex-in-progress':
        print('SKIP-reindex-running')
        raise SystemExit(0)
    assert r.get('indexed_chunks', 0) > 0, r
    assert elapsed < 5.0, ('latency budget exceeded', elapsed, r)
    hits = e.search(nonce, limit=5)
    paths = [h.get('path') for h in (hits.get('results') or [])]
    assert rel in paths, ('written doc not retrievable', paths)
    print('ok', r['indexed_chunks'], int(elapsed*1000))
finally:
    try:
        db = e._get_db()
        e._delete_path_rows(db, rel)
        db.commit()
    except Exception:
        pass
    fx.unlink(missing_ok=True)
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"ok"* || "$output" == *"SKIP-"* ]]
}

@test "t1719: re-indexing the same path replaces its chunks rather than duplicating" {
    # _delete_path_rows runs before insert. Without it every post-write hook
    # fires would multiply that document's chunk count, which degrades recall
    # quality silently — duplicates crowd out other documents in top-k.
    run _py "
import embeddings as e
if not e.is_index_ready():
    print('SKIP-no-index')
    raise SystemExit(0)
target = '.tasks/active/T-1719-embeddings-strategy-v1--slice-1-post-wri.md'
import pathlib
if not (pathlib.Path(e.PROJECT_ROOT) / target).is_file():
    print('SKIP-no-target')
    raise SystemExit(0)
r1 = e.index_one(target)
if r1.get('skipped'):
    print('SKIP-' + str(r1['skipped']))
    raise SystemExit(0)
db = e._get_db()
n1 = db.execute('SELECT COUNT(*) FROM documents WHERE path = ?', (target,)).fetchone()[0]
r2 = e.index_one(target)
if r2.get('skipped'):
    print('SKIP-' + str(r2['skipped']))
    raise SystemExit(0)
db = e._get_db()
n2 = db.execute('SELECT COUNT(*) FROM documents WHERE path = ?', (target,)).fetchone()[0]
assert n1 == n2, ('chunk count grew on re-index', n1, n2)
print('ok', n1, n2)
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"ok"* || "$output" == *"SKIP-"* ]]
}
