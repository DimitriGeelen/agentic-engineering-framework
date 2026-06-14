#!/usr/bin/env bats
# T-2398 (OBS-076): _self_vendor_{libs,agents,web} find must prune node_modules /
# __pycache__ / .git so untracked third-party files don't manufacture phantom
# pre-push drift ("would sync N file(s)").
#
# Origin: 2026-06-14 — `lib/ts/node_modules/**/README.md` (untracked, present in
# main after npm install, absent in fresh worktrees) was counted by
# _self_vendor_libs and blocked every master push via the T-2240 gate, while a
# plain `diff -rq lib .agentic-framework/lib` showed byte-identical trees.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d -t fw-t2398-XXXXXX)"
    export FRAMEWORK_ROOT
    export NO_COLOR=1
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/upgrade.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Build a synthetic fw whose source tree is in sync with its vendored copy EXCEPT
# for untracked junk under node_modules/__pycache__ that must be pruned.
make_syn() {
    local d="$TEST_TEMP_DIR/syn"
    mkdir -p "$d/lib/ts/node_modules/argparse" "$d/lib/__pycache__" \
             "$d/agents/foo/node_modules/pkg" \
             "$d/web/static/node_modules/pkg" \
             "$d/.agentic-framework/lib" "$d/.agentic-framework/agents/foo" \
             "$d/.agentic-framework/web"
    # real tracked sources — vendored copies identical (in sync)
    echo "echo lib"   > "$d/lib/real.sh";    cp "$d/lib/real.sh"   "$d/.agentic-framework/lib/real.sh"
    echo "print('a')" > "$d/agents/foo/a.py"; cp "$d/agents/foo/a.py" "$d/.agentic-framework/agents/foo/a.py"
    echo "echo web"   > "$d/web/w.sh";       cp "$d/web/w.sh"      "$d/.agentic-framework/web/w.sh"
    # untracked junk that MUST be pruned (matched extensions inside excluded dirs)
    echo "# readme"   > "$d/lib/ts/node_modules/argparse/README.md"   # *.md → libs would count it
    echo "x = 1"      > "$d/lib/__pycache__/cached.md"                # *.md inside __pycache__
    echo "# readme"   > "$d/agents/foo/node_modules/pkg/README.md"    # *.md → agents would count
    echo "import x"   > "$d/web/static/node_modules/pkg/setup.py"     # *.py → web would count
    echo "$d"
}

@test "libs: node_modules/__pycache__ pruned → no phantom drift (OBS-076 core)" {
    syn="$(make_syn)"
    FRAMEWORK_ROOT="$syn" run _self_vendor_libs true
    [ "$status" -eq 0 ]
    [[ "$output" != *"would sync"* ]]
}

@test "agents: node_modules pruned → no phantom drift" {
    syn="$(make_syn)"
    FRAMEWORK_ROOT="$syn" run _self_vendor_agents true
    [ "$status" -eq 0 ]
    [[ "$output" != *"would sync"* ]]
}

@test "web: node_modules pruned → no phantom drift" {
    syn="$(make_syn)"
    FRAMEWORK_ROOT="$syn" run _self_vendor_web true
    [ "$status" -eq 0 ]
    [[ "$output" != *"would sync"* ]]
}

@test "positive control: a real lib drift is STILL detected (no over-pruning)" {
    syn="$(make_syn)"
    echo "echo changed" > "$syn/lib/real.sh"   # source now differs from vendored
    FRAMEWORK_ROOT="$syn" run _self_vendor_libs true
    [ "$status" -eq 0 ]
    [[ "$output" == *"would sync 1 file(s) to .agentic-framework/lib/"* ]]
}

@test "positive control: a real NEW lib file under a normal subdir is detected" {
    syn="$(make_syn)"
    mkdir -p "$syn/lib/templates"
    echo "echo new" > "$syn/lib/templates/new.sh"   # not vendored, not in an excluded dir
    FRAMEWORK_ROOT="$syn" run _self_vendor_libs true
    [[ "$output" == *"would sync 1 file(s)"* ]]
}
