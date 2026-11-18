#!/usr/bin/env bats
# T-5221 (slice 2 of T-5212): one task-file writer (lib/render_task.py) shared by
# `fw task create` and `fw task create-batch`, and `fw arc instantiate`.
#
# Every test runs in a temporary git repository; nothing here reads or writes this
# repository's .tasks/, counter, ledger or .context/arcs/. Templates come from the frozen
# copies in tests/fixtures/t5221/templates/, so an edit to the live templates never moves
# these byte comparisons.

load ../git_fence

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
FIX="$FRAMEWORK_ROOT/tests/fixtures/t5221"
CREATE_TASK="$FRAMEWORK_ROOT/agents/task-create/create-task.sh"
CREATE_BATCH="$FRAMEWORK_ROOT/agents/task-create/create-batch.sh"
RENDER="$FRAMEWORK_ROOT/lib/render_task.py"
FW="$FRAMEWORK_ROOT/bin/fw"

setup() {
    T="$(mktemp -d "${BATS_RUN_TMPDIR:-/tmp}/t5221.XXXXXX")"
    unset CLAUDECODE FW_ID_CHECK FW_ID_BLOCK_MAX FW_ID_QUARANTINE_GAP _FW_PATHS_DERIVED_BY
    unset FW_ALLOW_EMPTY_RECOMMENDATION FW_INCEPTION_PRE_GATED FW_TASK_ORIGIN
    unset FW_SESSION_SCOPED_FOCUS FW_FOCUS_SESSION_KEY TASKS_DIR CONTEXT_DIR
}

teardown() {
    local r
    for r in "$T"/*/; do git -C "$r" worktree prune 2>/dev/null || true; done
    rm -rf "$T"
}

# _repo NAME — a fresh project at $T/NAME with the frozen templates, committed.
_repo() {
    local R="$T/$1"
    mkdir -p "$R/.tasks/active" "$R/.tasks/completed" "$R/.tasks/templates" \
             "$R/.context/working" "$R/.context/locks" "$R/.context/arcs/templates"
    cp "$FIX/templates/"*.md "$R/.tasks/templates/"
    cp "$FIX/municipality-scan.yaml" "$R/.context/arcs/templates/"
    : > "$R/.tasks/active/.gitkeep"; : > "$R/.tasks/completed/.gitkeep"
    git -C "$R" init -q
    git -C "$R" add -A
    git -C "$R" -c user.email=t@t -c user.name=t commit -qm seed
}

_use() {  # point the tools at project $T/NAME
    export PROJECT_ROOT="$T/$1" TASKS_DIR="$T/$1/.tasks" CONTEXT_DIR="$T/$1/.context"
}

# _norm FILE ROOT — the file with its own id, created timestamp and project root replaced.
_norm() {
    local f="$1" id ts
    id="$(basename "$f" | grep -oE '^T-[0-9]+')"
    ts="$(grep -m1 '^created:' "$f" | sed 's/^created: //')"
    python3 "$FIX/norm.py" "$f" "$id" "$ts" "$2"
}

# 13 entries covering the rendering edges: quotes and colons in names, multi-line
# descriptions holding frontmatter-looking lines, list and string tags, related ids,
# every horizon and four workflow types.
_spec13() {
    python3 - "$1" <<'EOF'
import json, sys
types = ['build', 'test', 'refactor', 'design']
hz = ['now', 'next', 'later']
with open(sys.argv[1], 'w') as fh:
    for i in range(1, 14):
        e = {
            'name': f'Step {i}: the "owner: x" case\'s {{braces}} ü',
            'description': f'Paragraph {i}: status: captured here.\n\nowner: human inside\n\n\\back "q"',
            'type': types[i % 4], 'owner': 'human' if i % 5 == 0 else 'agent',
            'horizon': hz[i % 3],
        }
        if i % 2:
            e['tags'] = ['scan', f' t{i} ']
        else:
            e['tags'] = f'a{i}, b ,c'
        if i % 3 == 0:
            e['related'] = ['T-900', 'T-901']
        fh.write(json.dumps(e, ensure_ascii=False) + '\n')
EOF
}

# ── one writer ─────────────────────────────────────────────────────────────────────────

@test "create-task output is byte-identical to the pre-T-5221 goldens (default, refactor+start, inception, inline fallback)" {
    run bash "$FIX/gen.sh" "$T/out"
    [ "$status" -eq 0 ]
    ! grep -q '^FAIL' <<<"$output" || false
    run diff -r "$FIX/golden" "$T/out"
    echo "$output"
    [ "$status" -eq 0 ]
}

@test "rendering lives in one module: create-task and create-batch both call lib/render_task.py, create-task writes no task file itself" {
    grep -q 'lib/render_task.py" write-one' "$CREATE_TASK"
    grep -q 'lib/render_task.py" write-batch' "$CREATE_BATCH"
    # The three old inline writers are gone.
    ! grep -q "open(e\['TC_FILEPATH'\], 'w')" "$CREATE_TASK" || false
    ! grep -q 'cat > "\$FILEPATH"' "$CREATE_TASK" || false
    ! grep -q 'TC_TEMPLATE=' "$CREATE_TASK" || false
    # And the shared rules are one file.
    grep -q 'task-create-rules.sh' "$CREATE_TASK"
    grep -q 'task-create-rules.sh' "$CREATE_BATCH"
}

@test "shared libraries load cold under set -euo pipefail" {
    run bash -c "set -euo pipefail; source '$FRAMEWORK_ROOT/lib/task-create-rules.sh'; task_rule_name 'Real name'; task_rule_fields 'Real name' build now agent; if task_rule_fields 'x' bogus now agent 2>/dev/null; then exit 9; fi; echo OK"
    [ "$status" -eq 0 ]; [[ "$output" == *OK* ]]
    _repo cold; _use cold
    run bash -c "set -euo pipefail; source '$FRAMEWORK_ROOT/lib/idalloc.sh'; fw_id_allocate 2 cold >/dev/null; fw_id_ledger_created T-001 T-002; echo OK"
    [ "$status" -eq 0 ]; [[ "$output" == *OK* ]]
    [ "$(grep -c '"event":"created"' "$T/cold/.tasks/.id-ledger.jsonl")" -eq 2 ]
}

@test "the writer refuses to overwrite an existing task file (exclusive link)" {
    _repo ex
    printf 'keep\n' > "$T/ex/.tasks/active/T-005-same-name.md"
    run python3 "$RENDER" write-one --tasks-dir "$T/ex/.tasks" --framework-root "$FRAMEWORK_ROOT" \
        --id T-005 --name "Same name" --description d --type build --owner agent --horizon now --status captured
    [ "$status" -eq 1 ]
    [[ "$output" == *"already exists"* ]]
    [ "$(cat "$T/ex/.tasks/active/T-005-same-name.md")" = keep ]
    # no temp file left (.writing/ itself stays, holding only its own .gitignore)
    [ -z "$(ls -A "$T/ex/.tasks/.writing" 2>/dev/null | grep -vx '.gitignore')" ]
}

# ── create-batch ───────────────────────────────────────────────────────────────────────

@test "create-batch: 13 entries are byte-identical to 13 single creates (apart from id and timestamp), one reservation" {
    _spec13 "$T/spec.jsonl"
    _repo single; _use single
    local -a f=()
    while IFS= read -r -d '' x; do f+=("$x"); done < <(python3 "$RENDER" parse-spec "$T/spec.jsonl")
    for ((k = 0; k < 13; k++)); do
        b=$((k * 8))
        bash "$CREATE_TASK" --name "${f[b]}" --description "${f[b+1]}" --type "${f[b+2]}" \
            --owner "${f[b+3]}" --horizon "${f[b+4]}" --tags "${f[b+5]}" --related "${f[b+6]}" \
            </dev/null >/dev/null
    done
    _repo batch; _use batch
    run bash "$CREATE_BATCH" --spec "$T/spec.jsonl" --purpose "test:13"
    echo "$output"
    [ "$status" -eq 0 ]
    mapfile -t S < <(ls "$T/single/.tasks/active/"T-*.md)
    mapfile -t B < <(ls "$T/batch/.tasks/active/"T-*.md)
    [ "${#S[@]}" -eq 13 ]; [ "${#B[@]}" -eq 13 ]
    for ((k = 0; k < 13; k++)); do
        [ "$(basename "${S[k]}")" = "$(basename "${B[k]}")" ]
        diff <(_norm "${S[k]}" "$T/single") <(_norm "${B[k]}" "$T/batch")
    done
    # Exactly one reservation for the batch, 13 ids, then 13 created rows.
    L="$T/batch/.tasks/.id-ledger.jsonl"
    [ "$(grep -c '"event":"reserve"' "$L")" -eq 1 ]
    grep -q '"event":"reserve","first":1,"last":13,"n":13,"purpose":"test:13"' "$L"
    [ "$(grep -c '"event":"created"' "$L")" -eq 13 ]
    [ "$(cat "$T/batch/.tasks/.id-highwater")" = 13 ]
    run "$FW" task id reconcile
    [ "$status" -eq 0 ]; [[ "$output" == *"no findings"* ]]
}

@test "create-batch: one invalid entry refuses the whole batch before any id is reserved" {
    _spec13 "$T/spec.jsonl"
    printf '%s\n' '{"name":"Bad owner entry","description":"d","type":"build","owner":"nobody"}' >> "$T/spec.jsonl"
    printf '%s\n' '{"name":"todo","description":"d","type":"build","owner":"agent"}' >> "$T/spec.jsonl"
    _repo v; _use v
    run bash "$CREATE_BATCH" --spec "$T/spec.jsonl" --purpose p
    [ "$status" -eq 1 ]
    [[ "$output" == *"entry 14 (Bad owner entry)"*"Invalid owner 'nobody'"* ]]
    [[ "$output" == *"entry 15 (todo)"*"template placeholder"* ]]
    [[ "$output" == *"2 of 15 entries invalid; no id reserved"* ]]
    [ ! -e "$T/v/.tasks/.id-ledger.jsonl" ]
    [ ! -e "$T/v/.tasks/.id-highwater" ]
    [ -z "$(ls "$T/v/.tasks/active/" | grep '^T-')" ]
}

@test "create-batch: inception entries, start/origin keys and --start/--origin flags are refused" {
    _repo r; _use r
    printf '%s\n' '{"name":"Explore the caching question","description":"d","type":"inception","owner":"agent"}' > "$T/inc.jsonl"
    run bash "$CREATE_BATCH" --spec "$T/inc.jsonl" --purpose p
    [ "$status" -eq 1 ]; [[ "$output" == *"inception tasks are refused in a batch"* ]]
    for key in '"start":true' '"origin":"peer:x"' '"recommendation":"GO"' '"status":"started-work"'; do
        printf '{"name":"Real name here","description":"d","type":"build","owner":"agent",%s}\n' "$key" > "$T/k.jsonl"
        run bash "$CREATE_BATCH" --spec "$T/k.jsonl" --purpose p
        [ "$status" -eq 2 ]; [[ "$output" == *"not allowed in a batch"* ]]
    done
    printf '%s\n' '{"name":"Real name here","description":"d","type":"build","owner":"agent"}' > "$T/ok.jsonl"
    for flag in --start --origin; do
        run bash "$CREATE_BATCH" --spec "$T/ok.jsonl" --purpose p $flag
        [ "$status" -eq 2 ]; [[ "$output" == *"refused in a batch"* ]]
    done
    [ ! -e "$T/r/.tasks/.id-ledger.jsonl" ]
    # The valid spec still goes through, through the fw router.
    run "$FW" task create-batch --spec "$T/ok.jsonl" --purpose p
    [ "$status" -eq 0 ]
    ls "$T/r/.tasks/active/"T-001-real-name-here.md
}

@test "create-batch: a batch killed mid-write leaves no partial file and no reissued id; reconcile reports the incomplete reservation" {
    _spec13 "$T/spec.jsonl"
    _repo k; _use k
    FW_RENDER_TEST_DELAY=0.4 setsid bash "$CREATE_BATCH" --spec "$T/spec.jsonl" --purpose kill-test \
        > "$T/kill.out" 2>&1 &
    local pid=$!
    for _ in $(seq 1 100); do
        [ "$(ls "$T/k/.tasks/active/" | grep -c '^T-')" -ge 3 ] && break
        sleep 0.05
    done
    kill -9 -- "-$pid" 2>/dev/null || kill -9 "$pid"
    wait "$pid" 2>/dev/null || true
    mapfile -t W < <(ls "$T/k/.tasks/active/"T-*.md)
    [ "${#W[@]}" -ge 3 ]; [ "${#W[@]}" -lt 13 ]
    # Every file that exists is complete: identical (normalised) to a full single render.
    for f in "${W[@]}"; do
        tail -n 4 "$f" | grep -q -- '- \*\*Context:\*\* Initial task creation'
        python3 -c "import re,sys,yaml; t=open(sys.argv[1]).read(); yaml.safe_load(re.match(r'---\n(.*?)\n---\n', t, re.S).group(1))" "$f"
    done
    # No temp file masquerades as a task file.
    [ -z "$(find "$T/k/.tasks" -name 'T-*.md' -path '*.writing*')" ]
    # The reservation stands: the next id comes after it, never inside it.
    run bash "$CREATE_TASK" --name "After the kill" --description d --type build --owner agent </dev/null
    [ "$status" -eq 0 ]
    ls "$T/k/.tasks/active/"T-014-after-the-kill.md
    run "$FW" task id reconcile --json
    [ "$status" -eq 0 ]
    python3 - "$output" "${#W[@]}" <<'EOF'
import json, sys
r = json.loads(sys.argv[1]); written = int(sys.argv[2])
inc = [f for f in r['findings'] if f['code'] == 'incomplete-reservation']
assert inc, r
res = inc[0]['reservations'][0]
assert res['purpose'] == 'kill-test', res
print(res)
EOF
    # A later batch sweeps the dead writer's temp file.
    printf '%s\n' '{"name":"Sweeper task","description":"d","type":"build","owner":"agent"}' > "$T/one.jsonl"
    run bash "$CREATE_BATCH" --spec "$T/one.jsonl" --purpose sweep
    [ "$status" -eq 0 ]
    # (.writing/ stays — review 3 — holding only its own .gitignore)
    [ -z "$(ls -A "$T/k/.tasks/.writing" | grep -vx '.gitignore')" ]
}

@test "create-batch: arc_id must resolve to an arc; --dry-run reserves and writes nothing" {
    _repo a; _use a
    printf '%s\n' '{"name":"Member of no arc","description":"d","type":"build","owner":"agent","arc_id":"ghost"}' > "$T/g.jsonl"
    run bash "$CREATE_BATCH" --spec "$T/g.jsonl" --purpose p
    [ "$status" -eq 1 ]; [[ "$output" == *"arc_id 'ghost' does not resolve"* ]]
    run bash "$CREATE_BATCH" --spec "$T/g.jsonl" --purpose p --new-arc ghost --dry-run
    [ "$status" -eq 0 ]; [[ "$output" == *"would reserve 1 id"* ]]
    [ ! -e "$T/a/.tasks/.id-ledger.jsonl" ]
    [ -z "$(ls "$T/a/.tasks/active/" | grep '^T-')" ]
}

# ── fw arc instantiate ─────────────────────────────────────────────────────────────────

@test "arc instantiate: --dry-run writes nothing" {
    _repo d; _use d
    # bin/fw itself counts verbs in .context/working on every call; what instantiate could
    # write is the task view, the counter and ledger, and the arcs directory.
    ( cd "$T/d" && find .tasks .context/arcs -print | sort ) > "$T/before"
    run "$FW" arc instantiate municipality-scan --param municipality=oslo --dry-run
    echo "$output"
    [ "$status" -eq 0 ]
    [[ "$output" == *"would reserve 13 id(s) for 'arc:scan-oslo'"* ]]
    [[ "$output" == *"nothing written"* ]]
    ( cd "$T/d" && find .tasks .context/arcs -print | sort ) > "$T/after"
    diff "$T/before" "$T/after"
}

@test "arc instantiate: one call creates the arc and its 13 tasks, members by arc_id, anchored, one reservation; audit structure has no FAIL" {
    _repo i; _use i
    run "$FW" arc instantiate municipality-scan --param municipality=oslo --param region=north
    echo "$output"
    [ "$status" -eq 0 ]
    A="$T/i/.context/arcs/scan-oslo.yaml"
    python3 - "$A" <<'EOF'
import sys, yaml
a = yaml.safe_load(open(sys.argv[1]))
assert a['slug'] == 'scan-oslo' and a['id'] == 'arc-001', a
assert a['name'] == 'Municipality scan: oslo' and a['status'] == 'in-progress', a
assert a['anchor_task'] == 'T-001', a
assert 'north' in a['description'], a
EOF
    mapfile -t F < <(ls "$T/i/.tasks/active/"T-*.md)
    [ "${#F[@]}" -eq 13 ]
    for f in "${F[@]}"; do
        grep -q '^arc_id: scan-oslo$' "$f"
        grep -q '^tags: \[scan, north\]$' "$f"
        grep -q 'Literal braces: {not-a-param}' "$f"
        ! grep -q '{municipality}' "$f" || false
    done
    L="$T/i/.tasks/.id-ledger.jsonl"
    [ "$(grep -c '"event":"reserve"' "$L")" -eq 1 ]
    grep -q '"purpose":"arc:scan-oslo"' "$L"
    # The arc's membership scan sees all 13.
    run "$FW" arc show scan-oslo
    [ "$status" -eq 0 ]
    [ "$(grep -cE 'T-0(0[1-9]|1[0-3])' <<<"$output")" -ge 13 ]
    # fw audit structure: no FAIL at all in a fresh project holding only this arc.
    git -C "$T/i" add -A && git -C "$T/i" -c user.email=t@t -c user.name=t commit -qm "T-001: instantiate"
    "$FW" audit --section structure > "$T/audit.out" 2>&1 || true
    cat "$T/audit.out"
    grep -q 'structure\|Structure\|STRUCTURE' "$T/audit.out"
    ! grep -q '\[FAIL\]' "$T/audit.out"
}

@test "arc instantiate: an existing arc, an unknown or missing parameter, and an invalid task all refuse before anything is written" {
    _repo e; _use e
    run "$FW" arc instantiate municipality-scan --param municipalty=oslo
    [ "$status" -eq 2 ]
    [[ "$output" == *'declares no parameter "municipalty"'* ]]
    [[ "$output" == *'parameter "municipality" is required'* ]]
    [[ "$output" != *"is not a declared parameter"* ]]
    sed 's/owner: agent/owner: nobody/' "$FIX/municipality-scan.yaml" > "$T/bad-owner.yaml"
    run "$FW" arc instantiate "$T/bad-owner.yaml" --param municipality=oslo
    [ "$status" -ne 0 ]; [[ "$output" == *"Invalid owner 'nobody'"* ]]
    [ ! -e "$T/e/.context/arcs/scan-oslo.yaml" ]
    [ ! -e "$T/e/.tasks/.id-ledger.jsonl" ]
    run "$FW" arc instantiate municipality-scan --param municipality=oslo
    [ "$status" -eq 0 ]
    run "$FW" arc instantiate municipality-scan --param municipality=oslo
    [ "$status" -eq 1 ]; [[ "$output" == *"already exists"* ]]
    [ "$(ls "$T/e/.tasks/active/" | grep -c '^T-')" -eq 13 ]
}

@test "timing: one arc plus 13 tasks in a repo with 24 worktrees takes under 3 s" {
    _repo p
    local i
    for i in $(seq 1 30); do printf -- '---\nid: T-%03d\n---\n' "$i" > "$T/p/.tasks/completed/T-$(printf %03d "$i")-seed.md"; done
    git -C "$T/p" add -A && git -C "$T/p" -c user.email=t@t -c user.name=t commit -qm seed30
    for i in $(seq 1 24); do git -C "$T/p" worktree add -q "$T/p-wt$i" -b "wt$i" 2>/dev/null; done
    [ "$(git -C "$T/p" worktree list | wc -l)" -eq 25 ]
    _use p
    local t0 t1 ms
    t0=$(date +%s%N)
    run "$FW" arc instantiate municipality-scan --param municipality=oslo
    t1=$(date +%s%N)
    [ "$status" -eq 0 ]
    ms=$(( (t1 - t0) / 1000000 ))
    echo "# arc + 13 tasks, 25 views: ${ms} ms" >&3
    [ "$(ls "$T/p/.tasks/active/" | grep -c '^T-0[34]')" -eq 13 ]
    [ "$ms" -lt 3000 ]
    for i in $(seq 1 24); do git -C "$T/p" worktree remove --force "$T/p-wt$i" 2>/dev/null || true; done
}

# ── independent review fixes (docs/reports/T-5221-independent-review.md) ───────────────

@test "review 1: exclusive write falls back when link() is unsupported (EPERM/ENOTSUP/EXDEV/EMLINK/ENOSYS), still never overwrites" {
    run python3 - "$FRAMEWORK_ROOT/lib" "$T" <<'EOF'
import errno, os, sys
sys.path.insert(0, sys.argv[1])
import render_task as rt
d = sys.argv[2]
real_link = os.link
for code in sorted({errno.EPERM, errno.ENOTSUP, errno.EOPNOTSUPP, errno.EXDEV, errno.EMLINK, errno.ENOSYS}):
    def nolink(a, b, code=code):
        raise OSError(code, os.strerror(code))
    os.link = nolink
    p = os.path.join(d, f'T-{code}-x.md')
    rt.write_exclusive(p, 'body\n', os.path.join(d, '.writing'))
    assert open(p).read() == 'body\n', code
    try:
        rt.write_exclusive(p, 'other\n', os.path.join(d, '.writing'))
        raise SystemExit(f'overwrote under errno {code}')
    except FileExistsError:
        pass
    assert open(p).read() == 'body\n', code
# a write error in the fallback leaves no file under the final name
os.link = lambda a, b: (_ for _ in ()).throw(OSError(errno.EPERM, 'no links'))
class Boom:
    def __init__(self, fd): self.fd = fd
    def __enter__(self): return self
    def __exit__(self, *a): os.close(self.fd)
    def write(self, s): raise OSError(errno.ENOSPC, 'disk full')
rt.os.fdopen = lambda fd, *a, **k: Boom(fd)
p = os.path.join(d, 'T-999-full.md')
try:
    rt.write_exclusive(p, 'x' * 10, os.path.join(d, '.writing'))
    raise SystemExit('no error raised')
except OSError as exc:
    assert exc.errno == errno.ENOSPC, exc
assert not os.path.exists(p), 'partial file left under the final name'
os.link = real_link
print('OK')
EOF
    echo "$output"
    [ "$status" -eq 0 ]; [[ "$output" == *OK* ]]
}

@test "review 2: parameter values that are not plain YAML are quoted, a comma does not split a tag, frontmatter always parses" {
    _repo q; _use q
    run "$FW" arc instantiate municipality-scan --param municipality=oslo --param "region=west], a, b # c: 'd"
    echo "$output"
    [ "$status" -eq 0 ]
    mapfile -t F < <(ls "$T/q/.tasks/active/"T-*.md)
    [ "${#F[@]}" -eq 13 ]
    python3 - "${F[@]}" <<'EOF'
import sys, yaml
for f in sys.argv[1:]:
    fm = open(f).read().split('---\n')[1]
    d = yaml.safe_load(fm)
    assert d['tags'] == ['scan', "west], a, b # c: 'd"], (f, d['tags'])
EOF
    # create-batch: list items keep their commas; a string stays a comma list (create-task's form)
    printf '%s\n' '{"name":"List tag","description":"d","type":"build","owner":"agent","tags":["k: v","a, b","@x","#h"]}' \
                  '{"name":"String tags","description":"d","type":"build","owner":"agent","tags":"a, b"}' > "$T/q.jsonl"
    run bash "$CREATE_BATCH" --spec "$T/q.jsonl" --purpose p
    echo "$output"
    [ "$status" -eq 0 ]
    python3 - "$T/q/.tasks/active" <<'EOF'
import glob, sys, yaml
got = {}
for f in glob.glob(sys.argv[1] + '/T-*.md'):
    d = yaml.safe_load(open(f).read().split('---\n')[1])
    got[d['name']] = d['tags']
assert got['List tag'] == ['k: v', 'a, b', '@x', '#h'], got['List tag']
assert got['String tags'] == ['a', 'b'], got['String tags']
EOF
}

@test "review 2: the writer refuses to report success for a file whose frontmatter does not parse" {
    _repo y
    printf -- '---\nid: T-XXX\nname: x\nstatus: captured\nworkflow_type: build\nowner: agent\nhorizon: now\ntags: []\nrelated_tasks: []\nbroken: [unclosed\ncreated: x\nlast_update: x\ndescription: x\n---\n\n# T-XXX: [Task Name]\n' > "$T/y/.tasks/templates/default.md"
    run python3 "$RENDER" write-one --tasks-dir "$T/y/.tasks" --framework-root "$T/y" \
        --id T-007 --name "Bad template" --description d --type build --owner agent --horizon now --status captured
    echo "$output"
    [ "$status" -ne 0 ]
    [[ "$output" == *"frontmatter"* ]]
    [ -z "$(ls "$T/y/.tasks/active/" | grep '^T-007')" ]
}

@test "review 3: the writer never removes .tasks/.writing/ (no rmdir racing a concurrent makedirs)" {
    _repo w
    run python3 - "$FRAMEWORK_ROOT/lib" "$T/w/.tasks" <<'EOF'
import os, sys
sys.path.insert(0, sys.argv[1])
import render_task as rt
def no_rmdir(p, *a, **k):
    raise AssertionError(f'rmdir({p}) called')
rt.os.rmdir = no_rmdir
rt.write_entries([{'id': 'T-001', 'name': 'n', 'description': 'd', 'type': 'build', 'owner': 'agent',
                   'horizon': 'now', 'status': 'captured', 'tags': '', 'related': ''}],
                 sys.argv[2], sys.argv[2])
assert os.path.isdir(os.path.join(sys.argv[2], '.writing'))
print('OK')
EOF
    echo "$output"
    [ "$status" -eq 0 ]; [[ "$output" == *OK* ]]
}

@test "review 4: the anchor is set without GNU sed -i, and reported only when set" {
    _repo s; _use s
    mkdir -p "$T/bin"
    # A sed that refuses -i, as BSD sed effectively does for GNU's form.
    printf '#!/bin/bash\nfor a in "$@"; do case "$a" in -i|-i*) echo "sed: -i refused (BSD)" >&2; exit 1;; esac; done\nexec %s "$@"\n' "$(command -v sed)" > "$T/bin/sed"
    chmod +x "$T/bin/sed"
    PATH="$T/bin:$PATH" run "$FW" arc instantiate municipality-scan --param municipality=oslo
    echo "$output"
    [ "$status" -eq 0 ]
    python3 -c "import yaml,sys; a=yaml.safe_load(open(sys.argv[1])); assert a['anchor_task']=='T-001', a['anchor_task']" "$T/s/.context/arcs/scan-oslo.yaml"
    [[ "$output" == *"anchor_task: T-001"* ]]
}

@test "review 7: .tasks/.writing/ is gitignored" {
    git -C "$FRAMEWORK_ROOT" check-ignore -q .tasks/.writing/123-abcd.T-1-x.md
}

@test "review 10: create-batch refuses an arc_id with a path component" {
    _repo pc; _use pc
    local up=".."
    for a in templates/municipality-scan "$up/arcs/templates/municipality-scan"; do
        printf '{"name":"Path arc","description":"d","type":"build","owner":"agent","arc_id":"%s"}\n' "$a" > "$T/pc.jsonl"
        run bash "$CREATE_BATCH" --spec "$T/pc.jsonl" --purpose p
        echo "$output"
        [ "$status" -eq 1 ]
        [[ "$output" == *"does not resolve"* ]]
    done
    [ -z "$(ls "$T/pc/.tasks/active/" | grep '^T-')" ]
}

@test "review 11: an arc rolled back by instantiate does not free its arc-NNN for reuse" {
    _repo rb; _use rb
    : > "$T/rb/.tasks/.writing"   # a file where the writer's temp dir goes: every write fails
    run "$FW" arc instantiate municipality-scan --param municipality=oslo
    echo "$output"
    [ "$status" -ne 0 ]
    [[ "$output" == *"removed again"* ]]
    [ ! -e "$T/rb/.context/arcs/scan-oslo.yaml" ]
    rm -f "$T/rb/.tasks/.writing"
    run "$FW" arc instantiate municipality-scan --param municipality=bergen
    echo "$output"
    [ "$status" -eq 0 ]
    python3 -c "import yaml,sys; a=yaml.safe_load(open(sys.argv[1])); assert a['id']=='arc-002', a['id']" "$T/rb/.context/arcs/scan-bergen.yaml"
}
