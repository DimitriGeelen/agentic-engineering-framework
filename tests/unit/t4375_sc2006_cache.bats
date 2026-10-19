#!/usr/bin/env bats
#
# T-4375: the structure-section audit (the pre-push gate) spent ~280 s of its
# ~510 s in check_invariant_suite (`bats tests/lint/`), and ~250 s of that in two
# lint legs that ran real ShellCheck over the whole repo:
#   - no-backticks-in-quoted-strings.bats, SC2006 over every bash source (~69 s),
#     now through tools/shellcheck-sc2006-cached.py, keyed on (version, path, bytes);
#   - bats-silent-skip.bats "fw test lint actually reports a silent-skip section"
#     (~180 s), which asserts wiring and now stubs shellcheck.
# These tests pin the cache's contract: same findings, no rerun on a hit, a rerun
# on any change, and nothing remembered from a shellcheck run that failed.

setup() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    TOOL="$ROOT/tools/shellcheck-sc2006-cached.py"
    W="$BATS_TEST_TMPDIR/w"
    mkdir -p "$W/bin"
    export FW_SC2006_CACHE_DIR="$BATS_TEST_TMPDIR/cache"
    export SC_LOG="$BATS_TEST_TMPDIR/sc.log"
    export SC_RC=""
    # Stub shellcheck: logs each file it is asked about, reports a gcc-format
    # SC2006 line for any file containing a backtick, exits 1 on findings (as
    # shellcheck does) or $SC_RC when set.
    cat > "$W/bin/shellcheck" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "--version" ]; then echo "version: stub-1"; exit 0; fi
shift 4
found=0
for f in "$@"; do
    echo "$f" >> "$SC_LOG"
    if grep -q '`' "$f"; then echo "$f:2:5: note: Use \$(...) notation instead of legacy backticks. [SC2006]"; found=1; fi
done
[ -n "$SC_RC" ] && exit "$SC_RC"
exit "$found"
EOF
    chmod +x "$W/bin/shellcheck"
    export PATH="$W/bin:$PATH"
    cd "$W"
    printf '#!/bin/bash\nx=`date`\n' > bad.sh
    printf '#!/bin/bash\nx=$(date)\n' > good.sh
}

@test "reports the SC2006 finding, and only for the offending file" {
    run python3 "$TOOL" bad.sh good.sh
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '^bad.sh:2:5: .*\[SC2006\]'
    if echo "$output" | grep -q good.sh; then false; fi
}

@test "a cache hit returns the same findings without running shellcheck on the file" {
    run python3 "$TOOL" bad.sh good.sh
    first="$output"
    : > "$SC_LOG"
    run python3 "$TOOL" bad.sh good.sh
    [ "$output" = "$first" ]
    [ ! -s "$SC_LOG" ]
}

@test "changed bytes are a miss: the file is checked again and the new answer wins" {
    run python3 "$TOOL" good.sh
    [ -z "$output" ]
    printf '#!/bin/bash\ny=`id`\n' > good.sh
    : > "$SC_LOG"
    run python3 "$TOOL" good.sh
    grep -qx good.sh "$SC_LOG"
    echo "$output" | grep -q '^good.sh:.*SC2006'
}

@test "a shellcheck run that fails (exit 2) is not remembered" {
    SC_RC=2 run python3 "$TOOL" good.sh
    : > "$SC_LOG"
    run python3 "$TOOL" good.sh
    grep -qx good.sh "$SC_LOG"
}

@test "an empty FW_SC2006_CACHE_DIR disables the cache" {
    FW_SC2006_CACHE_DIR="" run python3 "$TOOL" bad.sh
    : > "$SC_LOG"
    FW_SC2006_CACHE_DIR="" run python3 "$TOOL" bad.sh
    grep -qx bad.sh "$SC_LOG"
    [ ! -d "$BATS_TEST_TMPDIR/cache" ]
}

# ── Human-AC tick audit: git reads batched ───────────────────────────────────
# lib/human_ac_ticks.py ran one `git diff-tree` per commit and one `git show` per
# changed task blob: ~6,500 forks, ~92 s on this repo. Now one diff-tree --stdin and
# one cat-file --batch. Counted through a git wrapper on PATH.

@test "Human-AC tick audit: git forks do not grow with commits, and a tick still FAILs" {
    local R="$BATS_TEST_TMPDIR/repo" real_git
    real_git="$(command -v git)"
    mkdir -p "$R/.tasks/active" "$BATS_TEST_TMPDIR/gw"
    git -C "$R" init -q
    git -C "$R" config user.email op@example.com
    git -C "$R" config user.name Operator
    local f="$R/.tasks/active/T-9999-x.md" i
    for i in $(seq 1 25); do
        printf -- '---\nid: T-9999\n---\n## Acceptance Criteria\n### Human\n- [ ] Criterion\n\nrev %s\n' "$i" > "$f"
        git -C "$R" add -A && git -C "$R" commit -qm "T-9999: rev $i"
    done
    sed -i 's/- \[ \] Criterion/- [x] Criterion/' "$f"
    git -C "$R" commit -qam "T-9999: tick"
    printf '#!/bin/sh\necho x >> "%s/gitcalls"\nexec "%s" "$@"\n' "$BATS_TEST_TMPDIR" "$real_git" > "$BATS_TEST_TMPDIR/gw/git"
    chmod +x "$BATS_TEST_TMPDIR/gw/git"
    PATH="$BATS_TEST_TMPDIR/gw:$PATH" PROJECT_ROOT="$R" run python3 "$ROOT/lib/human_ac_ticks.py" audit --since 2000-01-01
    [ "$status" -eq 2 ]
    [[ "$output" == *"FAIL T-9999"* ]]
    local calls
    calls=$(wc -l < "$BATS_TEST_TMPDIR/gitcalls")
    echo "git invocations: $calls" >&2
    [ "$calls" -le 10 ]
}

# ── BVP coherence pass (audit.sh structure section): frontmatter parsed once ──
# It parsed every task's frontmatter for the arc index and again per arc driver
# (~40 s). Now: one parse per file, and files whose only arc_id is a comment line
# are not parsed for the index. The findings must be what they were.

_bvp_coherence() {
    awk '/^bvp_coherence_findings=\$\(python3 - /{p=1; next} p && /^PY$/{exit} p' \
        "$ROOT/agents/audit/audit.sh" > "$BATS_TEST_TMPDIR/coh.py"
    python3 "$BATS_TEST_TMPDIR/coh.py" "$1" 4 1 0.7
}

@test "BVP coherence: findings unchanged on a fixture (quoted key, arc-NNN, comment-only, bad YAML)" {
    local F="$BATS_TEST_TMPDIR/proj"
    mkdir -p "$F/.context/arcs" "$F/.tasks/active" "$F/.tasks/completed"
    printf 'id: arc-900\nslug: demo\nstatus: in-progress\nscoped_drivers:\n  - name: determinism\n    weight: 5\nbvp_scores:\n  D2: 5\n' > "$F/.context/arcs/demo.yaml"
    local i
    for i in 1 2 3; do
        printf -- '---\nid: T-90%s\narc_id: demo\nbvp_scores:\n  determinism: 0\n  D2: 1\n---\nbody\n' "$i" > "$F/.tasks/active/T-90$i-x.md"
    done
    printf -- '---\nid: T-904\n"arc_id": arc-900\nbvp_scores: {determinism: 1, D2: 4}\n---\n' > "$F/.tasks/completed/T-904-x.md"
    printf -- '---\nid: T-905\n# arc_id: demo\nbvp_scores: {determinism: 0, D2: 0}\n---\n' > "$F/.tasks/completed/T-905-x.md"
    printf -- '---\nid: T-906\narc_id: demo\nbad: [unclosed\n---\n' > "$F/.tasks/completed/T-906-x.md"
    run _bvp_coherence "$F"
    [ "$status" -eq 0 ]
    [ "$(printf '%s\n' "$output" | sort)" = "$(printf 'demo|D2|5|3|4|0.75\ndemo|determinism|5|4|4|1.00')" ]
}

@test "BVP coherence: each task's frontmatter is parsed once per run" {
    grep -q '_FM_CACHE\[path\] = fm' "$ROOT/agents/audit/audit.sh"
}

@test "the lint legs that cost the pre-push audit ~250 s use the cheap path" {
    grep -q 'tools/shellcheck-sc2006-cached.py' "$ROOT/tests/lint/no-backticks-in-quoted-strings.bats"
    grep -q 'BATS_TEST_TMPDIR/bin/shellcheck' "$ROOT/tests/lint/bats-silent-skip.bats"
}
