#!/usr/bin/env bats
# T-2473 — fw integrate run: true per-class UNION at both-sided conflicts.
#
# Replaces the T-2471 MVP's blanket `checkout --ours` (which dropped the master
# side's entries) with real union resolution. Each test drives a GENUINE git
# conflict on a union-class file through `integrate run master` and asserts BOTH
# sides' entries survive in the merged result — not ours-truncated.
#
# Conflict is forced by having ours AND theirs both modify a shared anchor line
# (guaranteed git conflict) AND each append its own distinct entry.

setup() {
    FRAMEWORK_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    INTEGRATE="$FRAMEWORK_ROOT/lib/integrate.py"

    export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
    export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

    ROOT="$(mktemp -d)"
    REPO="$ROOT/repo"
    git init -q -b master "$REPO"
    cd "$REPO"
    mkdir -p .context/project .context/working .tasks/active lib

    # vendor-refresh stub: a harmless no-op so cmd_run never shells the real fw.
    printf '#!/bin/bash\nexit 0\n' > "$ROOT/noop-fw"
    chmod +x "$ROOT/noop-fw"
    export FW_BIN="$ROOT/noop-fw"
    unset FRAMEWORK_ROOT_ENV 2>/dev/null || true

    echo realcode > lib/foo.sh    # a stable real file so the repo isn't union-only
    git add -A && git commit -q -m base-init
}

teardown() {
    cd /
    [ -n "$ROOT" ] && rm -rf "$ROOT" 2>/dev/null || true
}

@test "id-union: decisions.yaml keeps D-001(ours) + D-100(ours) + D-200(theirs)" {
    cat > .context/project/decisions.yaml <<'EOF'
# Project Decisions
decisions:
  - id: D-001
    rationale: base
EOF
    git add -A && git commit -q -m base
    # ours: change D-001 rationale (anchor) + add D-100
    cat > .context/project/decisions.yaml <<'EOF'
# Project Decisions
decisions:
  - id: D-001
    rationale: ours
  - id: D-100
    rationale: ours-new
EOF
    git checkout -q -b feat && git commit -qam ours
    git checkout -q master
    cat > .context/project/decisions.yaml <<'EOF'
# Project Decisions
decisions:
  - id: D-001
    rationale: theirs
  - id: D-200
    rationale: theirs-new
EOF
    git commit -qam theirs
    git checkout -q feat

    run python3 "$INTEGRATE" run master
    [ "$status" -eq 0 ]
    [[ "$output" == *"union-merged [id-union]"* ]]
    ids="$(python3 -c "import yaml; print(sorted(d['id'] for d in yaml.safe_load(open('.context/project/decisions.yaml'))['decisions']))")"
    [[ "$ids" == *"D-001"* && "$ids" == *"D-100"* && "$ids" == *"D-200"* ]]
    # same-id collision keeps ours
    grep -A1 'id: D-001' .context/project/decisions.yaml | grep -q 'ours'
}

@test "append-union list: .gate-bypass-log.yaml keeps both sides' entries" {
    cat > .context/working/.gate-bypass-log.yaml <<'EOF'
- timestamp: t0
  reason: base
EOF
    git add -A && git commit -q -m base
    cat > .context/working/.gate-bypass-log.yaml <<'EOF'
- timestamp: t0
  reason: ours
- timestamp: t1
  reason: ours-B
EOF
    git checkout -q -b feat && git commit -qam ours
    git checkout -q master
    cat > .context/working/.gate-bypass-log.yaml <<'EOF'
- timestamp: t0
  reason: theirs
- timestamp: t2
  reason: theirs-C
EOF
    git commit -qam theirs
    git checkout -q feat

    run python3 "$INTEGRATE" run master
    [ "$status" -eq 0 ]
    [[ "$output" == *"union-merged [append-union]"* ]]
    grep -q 'ours-B' .context/working/.gate-bypass-log.yaml
    grep -q 'theirs-C' .context/working/.gate-bypass-log.yaml
}

@test "append-union map: metrics-history.yaml dedupes by timestamp, keeps both new" {
    cat > .context/project/metrics-history.yaml <<'EOF'
# metrics
entries:
- timestamp: '2026-06-01T00:00:00Z'
  pass: 0
EOF
    git add -A && git commit -q -m base
    cat > .context/project/metrics-history.yaml <<'EOF'
# metrics
entries:
- timestamp: '2026-06-01T00:00:00Z'
  pass: 1
- timestamp: '2026-06-02T00:00:00Z'
  pass: 2
EOF
    git checkout -q -b feat && git commit -qam ours
    git checkout -q master
    cat > .context/project/metrics-history.yaml <<'EOF'
# metrics
entries:
- timestamp: '2026-06-01T00:00:00Z'
  pass: 9
- timestamp: '2026-06-03T00:00:00Z'
  pass: 3
EOF
    git commit -qam theirs
    git checkout -q feat

    run python3 "$INTEGRATE" run master
    [ "$status" -eq 0 ]
    ts="$(python3 -c "import yaml; print([e['timestamp'] for e in yaml.safe_load(open('.context/project/metrics-history.yaml'))['entries']])")"
    [[ "$ts" == *"2026-06-02T00:00:00Z"* && "$ts" == *"2026-06-03T00:00:00Z"* ]]
    # the shared timestamp appears exactly once (deduped)
    [ "$(grep -c '2026-06-01T00:00:00Z' .context/project/metrics-history.yaml)" -eq 1 ]
}

@test "append-union stream: feedback-stream.yaml unions docs from both sides" {
    cat > .context/working/feedback-stream.yaml <<'EOF'
# stream
---
kind: base
scan_id: R-0
EOF
    git add -A && git commit -q -m base
    cat > .context/working/feedback-stream.yaml <<'EOF'
# stream
---
kind: ours
scan_id: R-1
EOF
    git checkout -q -b feat && git commit -qam ours
    git checkout -q master
    cat > .context/working/feedback-stream.yaml <<'EOF'
# stream
---
kind: theirs
scan_id: R-2
EOF
    git commit -qam theirs
    git checkout -q feat

    run python3 "$INTEGRATE" run master
    [ "$status" -eq 0 ]
    grep -q 'scan_id: R-1' .context/working/feedback-stream.yaml
    grep -q 'scan_id: R-2' .context/working/feedback-stream.yaml
}

@test "field-merge: task .md frontmatter — higher last_update wins, body=ours" {
    cat > .tasks/active/T-9-demo.md <<'EOF'
---
id: T-9
status: started-work
last_update: 2026-06-01T00:00:00Z
owner: agent
---
BODY-BASE
EOF
    git add -A && git commit -q -m base
    cat > .tasks/active/T-9-demo.md <<'EOF'
---
id: T-9
status: started-work
last_update: 2026-06-01T12:00:00Z
owner: agent
---
BODY-OURS
EOF
    git checkout -q -b feat && git commit -qam ours
    git checkout -q master
    cat > .tasks/active/T-9-demo.md <<'EOF'
---
id: T-9
status: work-completed
last_update: 2026-06-02T00:00:00Z
---
BODY-THEIRS
EOF
    git commit -qam theirs
    git checkout -q feat

    run python3 "$INTEGRATE" run master
    [ "$status" -eq 0 ]
    [[ "$output" == *"union-merged [field-merge]"* ]]
    # theirs had the higher last_update → its status wins the collision
    grep -q 'status: work-completed' .tasks/active/T-9-demo.md
    # field unique to ours is retained
    grep -q 'owner: agent' .tasks/active/T-9-demo.md
    # body always comes from the branch (ours)
    grep -q 'BODY-OURS' .tasks/active/T-9-demo.md
    if grep -q 'BODY-THEIRS' .tasks/active/T-9-demo.md; then false; fi
    # ISO Z timestamp preserved (not reformatted to a datetime)
    grep -q '2026-06-02T00:00:00Z' .tasks/active/T-9-demo.md
}

@test "real-code conflict still ABORTS (union does not touch git-merge class)" {
    # both sides change lib/foo.sh (real code) — must refuse, target untouched
    git checkout -q -b feat
    echo ours > lib/foo.sh && git commit -qam ours
    git checkout -q master
    echo theirs > lib/foo.sh && git commit -qam theirs
    git checkout -q feat
    before="$(git rev-parse HEAD)"

    run python3 "$INTEGRATE" run master
    [ "$status" -eq 2 ]
    # no merge commit was created on feat
    [ "$(git rev-parse HEAD)" = "$before" ]
}
