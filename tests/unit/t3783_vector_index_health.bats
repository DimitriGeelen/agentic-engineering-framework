#!/usr/bin/env bats
# T-3783: the vector-index health check (lib/vector_index_health.py) — one
# predicate behind fw doctor / fw audit / handover / reindex cron / recall banner.
#
# Hermetic: every test builds a temp project with its own small sqlite index and
# manifest, and a temp FRAMEWORK_ROOT whose web.embeddings is a stand-in that
# runs a real query against that fixture DB (the canary goes through
# _semantic_search on VECTOR_DB_PATH, same as the real module). The live 2.5 GB
# index is never touched.

ROOT="${BATS_TEST_DIRNAME}/../.."
CHECK="$ROOT/lib/vector_index_health.py"

setup() {
    TMPD="$(mktemp -d)"
    P="$TMPD/proj"; F="$TMPD/fw"
    mkdir -p "$P/.tasks/active" "$P/.tasks/completed" "$P/.context/working" "$P/.context/project" "$F/web"
    printf -- '---\nid: T-001\n---\n' > "$P/.tasks/active/T-001-alpha.md"
    printf -- '---\nid: T-002\n---\n' > "$P/.tasks/completed/T-002-beta.md"
    printf 'learnings:\n- id: L-001\n  learning: first\n' > "$P/.context/project/learnings.yaml"
    cat > "$P/.context/cron-registry.yaml" <<'YAML'
jobs:
- id: index-reindex-hourly
  schedule: 20 * * * *
  command: fw index reindex
  status: active
YAML
    # Fake framework: the real canary module, and an embeddings module whose
    # _semantic_search really queries the fixture DB (word-overlap ranking).
    cp "$ROOT/web/canary.py" "$F/web/canary.py"
    : > "$F/web/__init__.py"
    cat > "$F/web/embeddings.py" <<'PY'
import os, re, sqlite3
from pathlib import Path
DB_PATH = Path(os.environ["VECTOR_DB_PATH"])
CALLS = Path(os.environ["VECTOR_DB_PATH"] + ".searched")
def _words(t): return set(re.findall(r"[a-z]{4,}", t.lower()))
def _semantic_search(query, limit=20):
    CALLS.write_text(query)
    db = sqlite3.connect(str(DB_PATH))
    q = _words(query); best = {}
    for path, text in db.execute("SELECT path, chunk_text FROM documents"):
        w = _words(text)
        s = len(q & w) / (len(w) ** 0.5 or 1)
        best[path] = max(best.get(path, 0), s)
    ranked = sorted(best, key=lambda p: -best[p])[:limit]
    return {"results": [{"path": p} for p in ranked if best[p] > 0]}
PY
    TOKEN="FWCANARY-123"
    unset VECTOR_DB_PATH FW_RECALL_TELEMETRY_PATH NTFY_ENABLED
    export FW_INDEX_CANARY_TIMEOUT=30
}
teardown() { rm -rf "$TMPD"; }

# build_index [age_hours] [with_canary=1] [extra_tasks=0]
build_index() {
    local age="${1:-0}" canary="${2:-1}"
    ( cd "$F" && AGE="$age" CAN="$canary" TOKEN="$TOKEN" PROOT="$P" DB="$P/.context/working/fw-vec-index.db" python3 - <<'PY'
import json, os, sqlite3, time
from web.canary import all_canaries
db = sqlite3.connect(os.environ["DB"])
db.execute("CREATE TABLE documents (id INTEGER PRIMARY KEY, path TEXT, title TEXT, category TEXT, task_id TEXT, chunk_index INT, chunk_text TEXT)")
rows = [(".tasks/active/T-001-alpha.md", "alpha task about widgets"),
        (".tasks/completed/T-002-beta.md", "beta task about gadgets"),
        (".context/project/learnings.yaml", "learnings:\n- id: L-001\n  learning: first")]
if os.environ["CAN"] == "1":
    rows += [(d.path, d.text) for d in all_canaries(os.environ["TOKEN"])]
for p, t in rows:
    db.execute("INSERT INTO documents (path,title,category,chunk_text) VALUES (?,?,?,?)", (p, p, "x", t))
# file_state as the indexer writes it: every source file on disk, hashed.
import hashlib, pathlib
db.execute("CREATE TABLE file_state (path TEXT PRIMARY KEY, content_hash TEXT, mtime REAL, updated_at REAL)")
root = pathlib.Path(os.environ["PROOT"])
for f in root.rglob("*"):
    if f.is_file() and f.suffix in (".md", ".yaml", ".yml") and "/working/" not in str(f):
        h = hashlib.sha256(f.read_text(errors="replace").encode("utf-8", errors="replace")).hexdigest()
        db.execute("INSERT INTO file_state VALUES (?,?,?,?)",
                   (f.relative_to(root).as_posix(), h, f.stat().st_mtime, time.time()))
db.commit()
fin = time.time() - float(os.environ["AGE"]) * 3600
json.dump({"finished_at": fin, "canary_token": os.environ["TOKEN"], "num_docs": len(rows)},
          open(os.environ["DB"] + ".manifest.json", "w"))
PY
    )
}

check() { python3 "$CHECK" --project-root "$P" --framework-root "$F" "$@"; }

@test "fresh fixture is green, and the canary really ran a search on the fixture index" {
    build_index 0
    run check
    echo "$output"
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "OK" ]
    [[ "$output" == *"OK|canary: canary FWCANARY-123 retrieved as top hit"* ]]
    [ -f "$P/.context/working/fw-vec-index.db.searched" ]
}

@test "stale manifest is red" {
    build_index 48
    run check
    [ "$status" -eq 2 ]
    [[ "$output" == *"FAIL|age: vector index 2.0 days old"* ]]
}

@test "age limit is configurable" {
    build_index 48
    FW_INDEX_MAX_AGE_HOURS=72 run check
    [ "$status" -eq 0 ]
}

@test "missing index is red, and no search is attempted (would trigger a full rebuild)" {
    run check
    [ "$status" -eq 2 ]
    [[ "$output" == *"FAIL|index: vector index missing"* ]]
    [[ "$output" == *"FAIL|manifest:"* ]]
    [[ "$output" == *"FAIL|canary: canary cannot run"* ]]
    [ ! -f "$P/.context/working/fw-vec-index.db.searched" ]
}

@test "missing manifest is red, never unknown" {
    build_index 0
    rm "$P/.context/working/fw-vec-index.db.manifest.json"
    run check
    [ "$status" -eq 2 ]
    [[ "$output" == *"FAIL|manifest: vector index has no readable manifest"* ]]
    [[ "$output" == *"FAIL|age:"* ]]
}

@test "empty manifest ({}) is red" {
    build_index 0
    echo '{}' > "$P/.context/working/fw-vec-index.db.manifest.json"
    run check
    [ "$status" -eq 2 ]
    [[ "$output" == *"FAIL|manifest: manifest has no valid finished_at"* ]]
}

@test "empty index (0 documents) is red" {
    build_index 0
    python3 -c "import sqlite3,sys; d=sqlite3.connect(sys.argv[1]); d.execute('DELETE FROM documents'); d.commit()" "$P/.context/working/fw-vec-index.db"
    run check
    [ "$status" -eq 2 ]
    [[ "$output" == *"FAIL|index: vector index has 0 documents"* ]]
}

@test "import failure is red (web.embeddings unimportable from the reindex path)" {
    build_index 0
    run python3 "$CHECK" --project-root "$P" --framework-root "$TMPD/empty-fw"
    [ "$status" -eq 2 ]
    [[ "$output" == *"FAIL|import: web.embeddings not importable the way fw index reindex imports it"* ]]
    [[ "$output" == *"FAIL|canary:"* ]]
}

@test "canary miss is red" {
    build_index 0 0
    run check
    [ "$status" -eq 2 ]
    [[ "$output" == *"FAIL|canary: canary query failed"* ]]
}

@test "missing index-reindex-hourly job is red; a paused one too" {
    build_index 0
    printf 'jobs:\n- id: other\n  command: "true"\n' > "$P/.context/cron-registry.yaml"
    run check --no-canary
    [ "$status" -eq 2 ]
    [[ "$output" == *"FAIL|cron: cron registry lacks index-reindex-hourly"* ]]
    sed -i 's/^jobs:/jobs:\n- id: index-reindex-hourly\n  status: paused/' "$P/.context/cron-registry.yaml"
    run check --no-canary
    [[ "$output" == *"FAIL|cron: index-reindex-hourly is paused"* ]]
}

@test "lag beyond the limit is red" {
    build_index 0
    for i in $(seq 10 14); do printf 'x\n' > "$P/.tasks/active/T-0$i-new.md"; done
    FW_INDEX_MAX_LAG=3 run check --no-canary
    [ "$status" -eq 2 ]
    [[ "$output" == *"FAIL|lag: vector index lags the corpus: 5 task(s)"* ]]
    FW_INDEX_MAX_LAG=10 run check --no-canary
    [ "$status" -eq 0 ]
}

@test "recall failure rate above threshold WARNs" {
    build_index 0
    ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    for i in $(seq 1 8); do echo "{\"ts\":\"$ts\",\"outcome\":\"hit\"}"; done > "$P/.context/working/recall-telemetry.jsonl"
    for i in $(seq 1 4); do echo "{\"ts\":\"$ts\",\"outcome\":\"unavailable\"}"; done >> "$P/.context/working/recall-telemetry.jsonl"
    run check --no-canary
    [ "$status" -eq 1 ]
    [[ "$output" == *"WARN|usage: recall: 4 of 12 queries"* ]]
}

@test "operator push fires once per transition to red, not every run" {
    build_index 48
    cat > "$TMPD/disp.py" <<PY
import sys; open("$TMPD/pushes", "a").write(" ".join(sys.argv[1:]) + "\n")
PY
    run bash -c "export FRAMEWORK_ROOT='$ROOT' PROJECT_ROOT='$P' NTFY_ENABLED=true SKILLS_DISPATCHER='$TMPD/disp.py'
        source '$ROOT/lib/vector-index-health.sh'
        # framework root is the real one here, so point the child at the fake web/
        vector_index_health() { _vih_env; python3 '$CHECK' --project-root '$P' --framework-root '$F' --record > '$TMPD/out' || true
            grep -qx TURNED_RED '$TMPD/out' && _vih_notify_red \"\$(cat '$TMPD/out')\"; return 0; }
        vector_index_health; vector_index_health; sleep 2"
    [ "$(grep -c 'Semantic recall RED' "$TMPD/pushes")" -eq 1 ]
    grep -q "days old" "$TMPD/pushes"
    # back to green, then red again: a second transition, a second push
    build_index_fresh() { rm -f "$P/.context/working/fw-vec-index.db"*; build_index "$1"; }
    build_index_fresh 0
    python3 "$CHECK" --project-root "$P" --framework-root "$F" --record >/dev/null
    build_index_fresh 48
    run python3 "$CHECK" --project-root "$P" --framework-root "$F" --record
    [[ "$output" == *"TURNED_RED"* ]]
    run python3 "$CHECK" --project-root "$P" --framework-root "$F" --record
    [[ "$output" != *"TURNED_RED"* ]]
}

@test "wrapper: fw_notify path really fires from vector_index_health on transition" {
    build_index 0
    printf 'jobs: []\n' > "$P/.context/cron-registry.yaml"   # red without needing the fake web/
    cat > "$TMPD/disp.py" <<PY
import sys; open("$TMPD/pushes", "a").write(" ".join(sys.argv[1:]) + "\n")
PY
    run bash -c "export FRAMEWORK_ROOT='$ROOT' PROJECT_ROOT='$P' NTFY_ENABLED=true SKILLS_DISPATCHER='$TMPD/disp.py'
        source '$ROOT/lib/vector-index-health.sh'; vector_index_health --no-canary >/dev/null; vector_index_health; vector_index_health; sleep 2"
    [ "$(grep -c 'Semantic recall RED' "$TMPD/pushes")" -eq 1 ]
}

@test "banner: present when degraded, absent when healthy, embed error reported first" {
    build_index 0
    run python3 -c "
import importlib.util, sys
s = importlib.util.spec_from_file_location('v', '$CHECK'); m = importlib.util.module_from_spec(s); s.loader.exec_module(m)
print('HEALTHY=[' + m.degraded_banner('$P', '$F') + ']')
print('EMBED=[' + m.degraded_banner('$P', '$F', 'ModuleNotFoundError: web') + ']')
"
    [[ "$output" == *"HEALTHY=[]"* ]]
    [[ "$output" == *"EMBED=[semantic recall degraded: embed path failed for this query (ModuleNotFoundError: web)"* ]]
    rm -f "$P/.context/working/fw-vec-index.db"; build_index 48
    run python3 "$CHECK" --project-root "$P" --framework-root "$F" --banner
    [ "$status" -eq 0 ]
    [[ "$output" == *"semantic recall degraded: vector index 2.0 days old"*"results may be missing; fix: fw index reindex"* ]]
}

@test "banner honours a red verdict recorded by the last full run (canary miss)" {
    build_index 0 0
    python3 "$CHECK" --project-root "$P" --framework-root "$F" --record >/dev/null || true
    run python3 "$CHECK" --project-root "$P" --framework-root "$F" --banner
    [[ "$output" == *"semantic recall degraded: canary query failed"* ]]
}

@test "fw recall prints the banner on stderr when the index is degraded" {
    run bash -c "cd '$P' && PROJECT_ROOT='$P' FRAMEWORK_ROOT='$ROOT' timeout 120 python3 '$ROOT/agents/context/lib/memory-recall.py' --query 'widgets' 2>&1 >/dev/null"
    [[ "$output" == *"semantic recall degraded:"* ]]
    run bash -c "cd '$P' && PROJECT_ROOT='$P' FRAMEWORK_ROOT='$ROOT' FW_RECALL_NO_BANNER=1 timeout 120 python3 '$ROOT/agents/context/lib/memory-recall.py' --query 'widgets' 2>&1 >/dev/null"
    [[ "$output" != *"semantic recall degraded:"* ]]
}

@test "wiring: doctor, audit corpus-health, handover and reindex all call the shared check" {
    grep -q 'lib/vector-index-health.sh' "$ROOT/bin/fw"
    sed -n '/^            reindex)$/,/^                ;;$/p' "$ROOT/bin/fw" | grep -q 'vector_index_health >&2'
    sed -n '/should_run_section "corpus-health"/,/SECTION 4/p' "$ROOT/agents/audit/audit.sh" | grep -q 'FAIL) fail "Vector index'
    grep -q 'vector_index_health_summary' "$ROOT/agents/handover/handover.sh"
    grep -q 'VECIDX_LINE' "$ROOT/agents/handover/handover.sh"
    grep -q 'degraded_banner' "$ROOT/lib/ask.py"
}

@test "config keys exist in both registries" {
    for k in INDEX_MAX_AGE_HOURS INDEX_MAX_LAG RECALL_FAIL_PCT_WARN; do
        grep -q "\"$k|" "$ROOT/lib/config.sh"
        grep -q "(\"$k\"" "$ROOT/web/blueprints/config.py"
    done
}

# --- review round 1 (codex): the gaps it found, each pinned red ---

@test "NaN, Infinity and future finished_at are red, never fresh" {
    build_index 0
    m="$P/.context/working/fw-vec-index.db.manifest.json"
    for v in NaN Infinity 99999999999; do
        python3 -c "import json,sys; d=json.load(open(sys.argv[1])); d['finished_at']=float('$v'); json.dump(d, open(sys.argv[1],'w'))" "$m"
        run check --no-canary
        [ "$status" -eq 2 ]
        [[ "$output" == *"FAIL|manifest: manifest has no valid finished_at"* ]]
        [[ "$output" == *"FAIL|age:"* ]]
    done
}

@test "manifest from a different build than the index (token not planted) is red" {
    build_index 0
    TOKEN="FWCANARY-999" ; m="$P/.context/working/fw-vec-index.db.manifest.json"
    python3 -c "import json,sys; d=json.load(open(sys.argv[1])); d['canary_token']='FWCANARY-999'; json.dump(d, open(sys.argv[1],'w'))" "$m"
    run check
    [ "$status" -eq 2 ]
    [[ "$output" == *"FAIL|token: manifest canary FWCANARY-999 is not in the index"* ]]
}

@test "content drift (edited decisions, new reports/episodics) beyond the limit is red" {
    build_index 0
    run check --no-canary
    [[ "$output" == *"0 source file(s) new or changed"* ]]
    mkdir -p "$P/docs/reports" "$P/.context/episodic"
    for i in 1 2 3; do echo "r$i" > "$P/docs/reports/T-00$i-r.md"; echo "e: $i" > "$P/.context/episodic/T-00$i.yaml"; done
    sleep 1; printf 'decisions:\n- id: D-001\n  changed: yes\n' > "$P/.context/project/decisions.yaml"
    printf 'learnings:\n- id: L-001\n  learning: edited\n' > "$P/.context/project/learnings.yaml"
    FW_INDEX_MAX_LAG=5 run check --no-canary
    [ "$status" -eq 2 ]
    [[ "$output" == *"FAIL|lag: vector index lags the corpus: 0 task(s), 0 learning(s) not in the index; 8 source file(s) new or changed"* ]]
    # a touch without a content change is not drift
    build_index_fresh() { rm -f "$P/.context/working/fw-vec-index.db"*; build_index 0; }
    build_index_fresh; sleep 1; touch "$P/.context/project/learnings.yaml"
    run check --no-canary
    [[ "$output" == *"; 0 source file(s) new or changed"* ]]
}

@test "concurrent recorders claim one transition, not two" {
    build_index 48
    run python3 - "$CHECK" "$P" "$F" <<'PY'
import importlib.util, sys, threading
s = importlib.util.spec_from_file_location("v", sys.argv[1]); m = importlib.util.module_from_spec(s); s.loader.exec_module(m)
from pathlib import Path
res = m.evaluate(Path(sys.argv[2]), Path(sys.argv[3]), canary=False)
assert res["status"] == "FAIL"
out, start = [], threading.Barrier(8)
def go():
    start.wait(); out.append(m.record(res, Path(sys.argv[2])))
ts = [threading.Thread(target=go) for _ in range(8)]
[t.start() for t in ts]; [t.join() for t in ts]
print("CLAIMS", sum(out))
PY
    [[ "$output" == *"CLAIMS 1"* ]]
}

@test "an unwritable state claims no transition (no push storm)" {
    build_index 48
    run python3 -c "
import importlib.util, sys
from pathlib import Path
s = importlib.util.spec_from_file_location('v', '$CHECK'); m = importlib.util.module_from_spec(s); s.loader.exec_module(m)
res = {'status': 'FAIL', 'ts': 0, 'checks': []}
print('CLAIM', m.record(res, Path('/proc/nonexistent-project')))
"
    [[ "$output" == *"CLAIM False"* ]]
}

# --- review round 2 (codex) ---

@test "changed content under a preserved (old) timestamp still counts as drift" {
    build_index 0
    f="$P/.context/project/learnings.yaml"
    old=$(stat -c %Y "$f")
    printf 'learnings:\n- id: L-001\n  learning: silently restored\n' > "$f"
    touch -d "@$((old - 3600))" "$f"
    FW_INDEX_MAX_LAG=0 run check --no-canary
    [ "$status" -eq 2 ]
    [[ "$output" == *"; 1 source file(s) new or changed"* ]]
}

@test "an older OK finishing after a newer FAIL does not overwrite it (no false second transition)" {
    build_index 0
    run python3 - "$CHECK" "$P" <<'PY'
import importlib.util, sys
from pathlib import Path
s = importlib.util.spec_from_file_location("v", sys.argv[1]); m = importlib.util.module_from_spec(s); s.loader.exec_module(m)
P = Path(sys.argv[2])
ok_old = {"status": "OK", "ts": 100.0, "checks": []}
fail_new = {"status": "FAIL", "ts": 200.0, "checks": []}
fail_newer = {"status": "FAIL", "ts": 300.0, "checks": []}
print("A", m.record(fail_new, P))     # turns red: True
print("B", m.record(ok_old, P))       # stale observation: discarded
print("C", m.record(fail_newer, P))   # still red: no second push
PY
    [[ "$output" == *"A True"* ]]
    [[ "$output" == *"B False"* ]]
    [[ "$output" == *"C False"* ]]
}

# --- review round 3 (codex) ---

@test "deleted sources the index still serves count as drift" {
    mkdir -p "$P/docs/reports"
    for i in 1 2 3; do echo "r$i" > "$P/docs/reports/T-00$i-r.md"; done
    build_index 0
    rm "$P/docs/reports/"*.md
    FW_INDEX_MAX_LAG=2 run check --no-canary
    [ "$status" -eq 2 ]
    [[ "$output" == *"; 3 source file(s) new or changed"* ]]
}

@test "non-finite config values fall back to defaults instead of crashing or disabling a limit" {
    build_index 48
    FW_INDEX_MAX_LAG=Infinity FW_INDEX_MAX_AGE_HOURS=NaN run check --no-canary
    [ "$status" -eq 2 ]
    [[ "$output" == *"FAIL|age: vector index 2.0 days old (limit 24h"* ]]
    [[ "$output" != *"crashed"* ]]
}

@test "a crash in a full run is recorded and claims the transition (push path)" {
    build_index 0
    run python3 - "$CHECK" "$P" "$F" <<'PY'
import importlib.util, sys, io, contextlib
s = importlib.util.spec_from_file_location("v", sys.argv[1]); m = importlib.util.module_from_spec(s); s.loader.exec_module(m)
def boom(*a, **k): raise RuntimeError("injected")
m.evaluate = boom
buf = io.StringIO()
with contextlib.redirect_stdout(buf):
    rc = m.main(["--project-root", sys.argv[2], "--framework-root", sys.argv[3], "--record"])
print("RC", rc); print(buf.getvalue())
PY
    [[ "$output" == *"RC 2"* ]]
    [[ "$output" == *"FAIL|check: vector index check crashed: injected"* ]]
    [[ "$output" == *"TURNED_RED"* ]]
}

@test "T-3783 final review: a checker that cannot start is recorded and pushed once on the transition" {
    local root="$BATS_TEST_TMPDIR/startfail"; mkdir -p "$root/.context/working" "$BATS_TEST_TMPDIR/bin"
    printf '#!/bin/sh\nexit 1\n' > "$BATS_TEST_TMPDIR/bin/python3"; chmod +x "$BATS_TEST_TMPDIR/bin/python3"
    run bash -c "
        export PATH='$BATS_TEST_TMPDIR/bin':\$PATH FRAMEWORK_ROOT='$BATS_TEST_DIRNAME/../..' PROJECT_ROOT='$root'
        source '$BATS_TEST_DIRNAME/../../lib/vector-index-health.sh'
        n=0; fw_notify() { n=\$((n+1)); }
        vector_index_health >/dev/null; vector_index_health >/dev/null
        echo notified=\$n"
    [[ "$output" == *"notified=1"* ]]
    grep -q '"status": "FAIL"' "$root/.context/working/vector-index-health.json"
}
