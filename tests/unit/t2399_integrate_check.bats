#!/usr/bin/env bats
# T-2399: fw integrate check — L2 serialized-integration preflight (read-only).
# Encodes the T-2397 §3.2 un-partitionable-file taxonomy and reports how the
# current worktree branch would integrate onto master:
#   exit 0 ff-ready|clean, 1 auto-resolvable, 2 needs-human, 3 not-on-branch, 4 error.
#
# Tests drive REAL git repos with controlled divergence (zero mocks) + direct
# classify_path() unit checks.

load ../test_helper

INT="$BATS_TEST_DIRNAME/../../lib/integrate.py"

setup() {
    REPO="$(mktemp -d -t fw-t2399-XXXXXX)"
    cd "$REPO"
    git init -q -b master
    git config user.email t@t.local
    git config user.name tester
    mkdir -p .context/working lib
    echo base > lib/foo.sh
    echo base > .context/working/feedback-stream.yaml
    echo base > file.txt
    git add -A
    git commit -qm base
}

teardown() {
    cd /
    rm -rf "$REPO"
}

# Helper: create feature branch, commit a change on it.
_branch_change() {  # $1=branch $2=file $3=text
    git checkout -q -b "$1"
    echo "$3" >> "$2"
    git add -A && git commit -qm "$1-change"
}
_master_change() {  # $1=file $2=text  (returns to previous branch caller handles)
    git checkout -q master
    echo "$2" >> "$1"
    git add -A && git commit -qm "master-change"
}

@test "t1: ff-ready — only the branch is ahead → exit 0 FF-READY" {
    _branch_change feat file.txt b1
    run python3 "$INT" check
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "FF-READY"
}

@test "t2: clean-merge — diverged but disjoint files → exit 0 CLEAN-MERGE" {
    _branch_change feat lib/foo.sh branchcode   # branch touches foo.sh
    _master_change file.txt mastertext          # master touches file.txt (disjoint)
    git checkout -q feat
    run python3 "$INT" check
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "CLEAN-MERGE"
}

@test "t3: auto-resolvable — both sides touch a governance file → exit 1" {
    _branch_change feat .context/working/feedback-stream.yaml branchevt
    _master_change .context/working/feedback-stream.yaml masterevt
    git checkout -q feat
    run python3 "$INT" check
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "AUTO-RESOLVABLE"
    echo "$output" | grep -q "append-union"
    ! echo "$output" | grep -q "NEEDS HUMAN"
}

@test "t4: needs-human — both sides touch real code → exit 2" {
    _branch_change feat lib/foo.sh branchcode
    _master_change lib/foo.sh mastercode
    git checkout -q feat
    run python3 "$INT" check
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "NEEDS-HUMAN"
    echo "$output" | grep -q "git-merge"
}

@test "t5: mixed — governance + real code both-sided → exit 2 (human wins)" {
    git checkout -q -b feat
    echo bcode >> lib/foo.sh
    echo bevt  >> .context/working/feedback-stream.yaml
    git add -A && git commit -qm feat-mixed
    git checkout -q master
    echo mcode >> lib/foo.sh
    echo mevt  >> .context/working/feedback-stream.yaml
    git add -A && git commit -qm master-mixed
    git checkout -q feat
    run python3 "$INT" check
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "git-merge"
    echo "$output" | grep -q "append-union"
}

@test "t6: not-on-a-branch — HEAD is master → exit 3" {
    run python3 "$INT" check
    [ "$status" -eq 3 ]
    echo "$output" | grep -q "nothing to integrate"
}

@test "t7: classify maps each taxonomy class correctly" {
    run python3 "$INT" classify \
        .context/working/.hook-counter \
        .context/project/metrics-history.yaml \
        .context/working/feedback-stream.yaml \
        .context/working/reviewer-overrides.yaml \
        .context/audits/discoveries/LATEST.yaml \
        .context/episodic/T-42.yaml \
        .tasks/completed/T-42-foo.md \
        lib/realcode.sh
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "^.context/working/.hook-counter	regenerate	auto"
    echo "$output" | grep -q "^.context/project/metrics-history.yaml	append-union	auto"
    echo "$output" | grep -q "^.context/working/feedback-stream.yaml	append-union	auto"
    echo "$output" | grep -q "^.context/working/reviewer-overrides.yaml	id-union	auto"
    echo "$output" | grep -q "^.context/audits/discoveries/LATEST.yaml	regenerate	auto"
    echo "$output" | grep -q "^.context/episodic/T-42.yaml	take-existing	auto"
    echo "$output" | grep -q "^.tasks/completed/T-42-foo.md	field-merge	auto"
    echo "$output" | grep -q "^lib/realcode.sh	git-merge	needs-human"
}

@test "t8: custom target ref is honoured" {
    # Make a 'release' branch as the integration target; HEAD diverges on real code.
    git branch release
    _branch_change feat lib/foo.sh branchcode
    git checkout -q release
    echo rel >> lib/foo.sh
    git add -A && git commit -qm release-change
    git checkout -q feat
    run python3 "$INT" check release
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "Target:     release"
}

@test "t9: T-2472 live transients classify auto (not needs-human)" {
    run python3 "$INT" classify \
        .context/working/focus.yaml \
        .context/working/session.yaml \
        .context/working/.session-metrics.yaml \
        .context/working/.budget-status \
        .context/working/watchtower.log \
        .context/working/watchtower.pid \
        .context/working/watchtower.url \
        .context/working/watchtower.port \
        .context/working/.gate-bypass-log.yaml \
        .context/project/decisions.yaml \
        VERSION
    [ "$status" -eq 0 ]
    echo "$output" | grep -qP '^\.context/working/focus\.yaml\tregenerate\tauto\b'
    echo "$output" | grep -qP '^\.context/working/session\.yaml\tregenerate\tauto\b'
    echo "$output" | grep -qP '^\.context/working/\.session-metrics\.yaml\tregenerate\tauto\b'
    echo "$output" | grep -qP '^\.context/working/\.budget-status\tregenerate\tauto\b'
    echo "$output" | grep -qP '^\.context/working/watchtower\.log\tregenerate\tauto\b'
    echo "$output" | grep -qP '^\.context/working/watchtower\.pid\tregenerate\tauto\b'
    echo "$output" | grep -qP '^\.context/working/watchtower\.url\tregenerate\tauto\b'
    echo "$output" | grep -qP '^\.context/working/watchtower\.port\tregenerate\tauto\b'
    echo "$output" | grep -qP '^\.context/working/\.gate-bypass-log\.yaml\tappend-union\tauto\b'
    echo "$output" | grep -qP '^\.context/project/decisions\.yaml\tid-union\tauto\b'
    echo "$output" | grep -qP '^VERSION\ttake-existing\tauto\b'
    # the prior real-code default still classifies needs-human
    echo "$output" | grep -vqP 'needs-human' || true
}

@test "t10: both-sided change to a T-2472 transient (VERSION) → exit 1 auto-resolvable" {
    echo "1.0.0" > VERSION
    git add VERSION && git commit -qm "add VERSION"
    _branch_change feat VERSION 1.0.1   # feat bumps VERSION
    _master_change VERSION 1.0.2        # master bumps VERSION (both-sided)
    git checkout -q feat
    run python3 "$INT" check
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "AUTO-RESOLVABLE"
    ! echo "$output" | grep -q "NEEDS HUMAN"
}
