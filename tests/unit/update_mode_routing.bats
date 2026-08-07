#!/usr/bin/env bats
# T-2853 — `fw update` must route by what the framework copy IS, not by which
# branch happens to be tested first.
#
# A global install (~/.agentic-framework, a `git clone`) has the same LAYOUT as a
# consumer's vendored copy: a directory of that name beside a project root, with
# a VERSION file. The vendored branch was tested first, matched the global
# install, and demanded `upstream_repo` — a key install.sh never writes, because
# the clone's own `origin` is already the answer. The git-based update branch
# (`_do_update_git`) was unreachable for it.
#
# T-2854/D-377: `_do_update_git` and its dispatch are gone — global installs
# have no producer since T-2800, so there is nothing left to update in place
# via `git reset --hard`. A framework copy shaped like a git clone is now
# residue, and `fw update` refuses it rather than routing anywhere. The
# discriminator that used to pick a branch (`.git` inside the framework copy)
# now picks refuse-vs-vendored.

setup_file() {
    FW_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export FW_ROOT
}

setup() {
    FX="$(mktemp -d)"
    RED=""; GREEN=""; YELLOW=""; BOLD=""; NC=""
    export RED GREEN YELLOW BOLD NC
    FW_VERSION="0.0.0"; export FW_VERSION
}

teardown() {
    [ -n "${FX:-}" ] && [ -d "$FX" ] && rm -rf "$FX"
    return 0
}

# Build a framework copy at $1/.agentic-framework. $2 = "clone" | "vendored".
_make_copy() {
    local root="$1" kind="$2"
    mkdir -p "$root/.agentic-framework"
    echo "1.2.3" > "$root/.agentic-framework/VERSION"
    [ "$kind" = "clone" ] && mkdir -p "$root/.agentic-framework/.git"
    return 0
}

# Source the real do_update, then replace the vendored terminal handler with a
# probe so routing is observable without network or mutation.
_route() {
    local project_root="$1" framework_root="$2"
    (
        # shellcheck source=/dev/null
        source "$FW_ROOT/lib/update.sh"
        _do_update_vendored() { echo "ROUTE=vendored"; }
        PROJECT_ROOT="$project_root" FRAMEWORK_ROOT="$framework_root" do_update --check
    )
}

@test "the probe harness can observe the vendored route (anti-vacuity)" {
    # If _route silently produced nothing, every assertion below would be
    # comparing "" against a substring and could pass for the wrong reason.
    _make_copy "$FX" vendored
    run _route "$FX" "$FX/.agentic-framework"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    [[ "$output" == ROUTE=* ]]
}

@test "GLOBAL INSTALL residue (framework copy is a git clone) is refused, not routed" {
    # T-2854: pre-fix, this routed to _do_update_git (git reset --hard) and
    # demanded upstream_repo instead. There is no branch left to route to —
    # a git-clone-shaped copy falls through to the no-vendored-framework
    # refusal, same as no copy at all.
    _make_copy "$FX" clone
    run _route "$FX" "$FX/.agentic-framework"
    [ "$status" -ne 0 ]
    [[ "$output" == *"No vendored framework"* ]]
    [[ "$output" != *"ROUTE="* ]]
}

@test "NEGATIVE CONTROL: a vendored consumer still routes to vendored" {
    # A fix that simply preferred the git path would break every consumer —
    # and would run `git reset --hard` where a re-vendor was intended.
    _make_copy "$FX" vendored
    run _route "$FX" "$FX/.agentic-framework"
    [ "$status" -eq 0 ]
    [[ "$output" == *"ROUTE=vendored"* ]]
}

@test "REGRESSION GUARD: framework repo (own .git, vendored copy) stays vendored" {
    # Near-miss during the T-2853 fix: keying the discriminator on
    # $FRAMEWORK_ROOT/.git instead of $vendored_dir/.git would route the
    # framework repo itself to the refusal branch (pre-T-2854: to
    # _do_update_git, which ran `git reset --hard` over a live working tree).
    # Here FRAMEWORK_ROOT is the checkout and DOES have .git, while its vendored
    # copy does not — the shape that distinguishes the two.
    _make_copy "$FX" vendored
    mkdir -p "$FX/.git"
    run _route "$FX" "$FX"
    [ "$status" -eq 0 ]
    [[ "$output" == *"ROUTE=vendored"* ]]
}

@test "the missing-upstream_repo error names an ABSOLUTE path" {
    # It used to say only ".framework.yaml". The file it means sits beside the
    # project root, which need not be anywhere near the operator's cwd — so the
    # instruction was unfollowable and got retried verbatim three times.
    _make_copy "$FX" vendored
    run bash -c "
        source '$FW_ROOT/lib/update.sh'
        RED=''; GREEN=''; YELLOW=''; BOLD=''; NC=''
        PROJECT_ROOT='$FX' FRAMEWORK_ROOT='$FX/.agentic-framework' do_update --check 2>&1
    "
    [ "$status" -ne 0 ]
    [[ "$output" == *"$FX/.framework.yaml"* ]]
}
