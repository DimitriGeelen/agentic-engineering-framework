#!/usr/bin/env bats
# T-3111: fw re-execs the AUTHORITY's binary from a linked worktree (R7 leg L2).
#
# The fixture is a REAL `git worktree add`, for the same reason T-3112's was: the
# claim is about git's worktree model — git-dir differs from git-common-dir in a
# linked checkout and collapses in the main one — and a fabricated directory
# layout asserts nothing about that.
#
# THE OBSERVABLE. "Did it re-exec?" is invisible from the outside unless the two
# binaries disagree about something, so the fixture makes them disagree twice:
#
#   1. VERSION differs (AUTHORITY vs REPLICA). `fw --version` reads the file next
#      to whichever binary is running, so the string names the winner.
#   2. `_stub_authority` replaces the AUTHORITY's bin/fw with a script that prints
#      its argv and inherited environment. The REPLICA keeps the real code, so it
#      still does the redirecting — and everything that arrives at the far end is
#      then readable. This is what makes argv-preservation and the FRAMEWORK_ROOT
#      handoff testable at all rather than asserted in prose.
#
# The T-2845 trap gets its own test. Exporting a replica-scoped FRAMEWORK_ROOT
# and exec'ing the authority's binary produces output byte-identical to having
# changed nothing, because fw honours an inherited FRAMEWORK_ROOT over its own
# location (the T-2099 fork-bomb fix). A redirect that moves the binary but not
# the root is a redirect that did nothing, and it LOOKS like it worked.

setup() {
    _FW_ROOT="${FRAMEWORK_ROOT:-/opt/999-Agentic-Engineering-Framework}"
    [ -f "$_FW_ROOT/bin/fw" ] || skip "fw not found"

    TEST_ROOT="$(mktemp -d)"
    MAIN="$TEST_ROOT/main"
    WT="$TEST_ROOT/wt"

    # `.tasks/` is what find_project_root() looks for, so the fixture needs it in
    # BOTH checkouts (it is tracked, so the worktree inherits it) — otherwise
    # PROJECT_ROOT never resolves and the test would exercise a shape no real
    # project has.
    mkdir -p "$MAIN/bin" "$MAIN/lib" "$MAIN/agents" "$MAIN/.context/working" "$MAIN/.tasks"
    echo "keep" > "$MAIN/.tasks/.keep"
    cp "$_FW_ROOT/bin/fw" "$MAIN/bin/fw"
    chmod +x "$MAIN/bin/fw"
    cp "$_FW_ROOT/lib/worktree-identity.sh" \
       "$_FW_ROOT/lib/hook-parity.sh" \
       "$_FW_ROOT/lib/hook_parity.py" "$MAIN/lib/"
    echo "# fixture framework" > "$MAIN/FRAMEWORK.md"
    echo "keep" > "$MAIN/agents/.keep"
    echo "AUTHORITY" > "$MAIN/VERSION"

    git -C "$MAIN" init -q
    git -C "$MAIN" config user.email t@t
    git -C "$MAIN" config user.name t
    git -C "$MAIN" add -A
    git -C "$MAIN" commit -qm init

    git -C "$MAIN" worktree add -q -b wtb "$WT" >/dev/null 2>&1
    echo "REPLICA" > "$WT/VERSION"
    mkdir -p "$WT/.context/working"
}

teardown() {
    [ -n "$TEST_ROOT" ] && rm -rf "$TEST_ROOT"
}

# Run a command with the ambient session's framework env stripped. Without this
# the harness's own CLAUDE_PROJECT_DIR / PROJECT_ROOT / FRAMEWORK_ROOT leak in
# and the fixture resolves against the real repo instead of itself.
_clean() {
    env -u CLAUDE_PROJECT_DIR -u PROJECT_ROOT -u FRAMEWORK_ROOT \
        -u FW_REEXEC_DEPTH -u FW_NO_REEXEC "$@"
}

# Replace the authority's binary with an argv/env reporter. The replica keeps the
# real fw, so the redirect logic under test is unchanged.
_stub_authority() {
    cat > "$MAIN/bin/fw" <<'STUB'
#!/usr/bin/env bash
echo "STUB-AUTHORITY"
echo "ARGC=$#"
for a in "$@"; do echo "ARG=[$a]"; done
echo "FRAMEWORK_ROOT=${FRAMEWORK_ROOT:-}"
echo "PROJECT_ROOT=${PROJECT_ROOT:-}"
echo "FW_REEXEC_DEPTH=${FW_REEXEC_DEPTH:-}"
STUB
    chmod +x "$MAIN/bin/fw"
}

@test "redirect fires: fw run from a linked worktree reports the AUTHORITY version" {
    run _clean bash -c "cd '$WT' && ./bin/fw --version 2>&1 | head -1"
    [ "$status" -eq 0 ]
    [[ "$output" == *AUTHORITY* ]]
    [[ "$output" != *REPLICA* ]]
}

@test "escape hatch: FW_NO_REEXEC=1 from the worktree runs the REPLICA's own fw" {
    # The paired negative for the test above. Together they prove the exec
    # happened rather than that both sides happen to print the same string.
    run _clean env FW_NO_REEXEC=1 bash -c "cd '$WT' && ./bin/fw --version 2>&1 | head -1"
    [ "$status" -eq 0 ]
    [[ "$output" == *REPLICA* ]]
}

@test "escape hatch writes a Tier-2 bypass entry naming replica and authority" {
    _clean env FW_NO_REEXEC=1 bash -c "cd '$WT' && ./bin/fw --version" >/dev/null 2>&1 || true
    local log="$WT/.context/working/.gate-bypass-log.yaml"
    [ -f "$log" ]
    run cat "$log"
    [[ "$output" == *"FW_NO_REEXEC=1"* ]]
    [[ "$output" == *"T-3111"* ]]
    [[ "$output" == *"$WT"* ]]
}

@test "main checkout: no redirect is pending, so the escape hatch logs nothing" {
    # The falsifiable form of "unaffected". FW_NO_REEXEC only writes when a
    # redirect was actually about to happen, so an empty log from the main
    # checkout is evidence the detection did not fire there.
    _clean env FW_NO_REEXEC=1 bash -c "cd '$MAIN' && ./bin/fw --version" >/dev/null 2>&1 || true
    [ ! -f "$MAIN/.context/working/.gate-bypass-log.yaml" ]
}

@test "main checkout: output identical with and without the escape hatch" {
    local a b
    a=$(_clean bash -c "cd '$MAIN' && ./bin/fw --version 2>&1")
    b=$(_clean env FW_NO_REEXEC=1 bash -c "cd '$MAIN' && ./bin/fw --version 2>&1")
    [ "$a" = "$b" ]
    [[ "$a" == *AUTHORITY* ]]
}

@test "loop guard: FW_REEXEC_DEPTH already set means no bounce" {
    # This is what the authority's own fw sees after the exec. If it redirected
    # again the pair would ping-pong forever; the replica running unredirected
    # here is the same code path, so REPLICA is the correct answer.
    run _clean env FW_REEXEC_DEPTH=1 bash -c "cd '$WT' && ./bin/fw --version 2>&1 | head -1"
    [ "$status" -eq 0 ]
    [[ "$output" == *REPLICA* ]]
}

@test "the sentinel is exported to the authority, so it cannot bounce at any depth" {
    _stub_authority
    run _clean bash -c "cd '$WT' && ./bin/fw --version"
    [ "$status" -eq 0 ]
    [[ "$output" == *"STUB-AUTHORITY"* ]]
    [[ "$output" == *"FW_REEXEC_DEPTH=1"* ]]
}

@test "FRAMEWORK_ROOT lands on the authority, not the replica" {
    _stub_authority
    run _clean bash -c "cd '$WT' && ./bin/fw doctor"
    [ "$status" -eq 0 ]
    [[ "$output" == *"FRAMEWORK_ROOT=$MAIN"* ]]
}

@test "T-2845 trap: an inherited replica-scoped FRAMEWORK_ROOT is overridden" {
    # The failure this pins is silent by construction: fw honours an inherited
    # FRAMEWORK_ROOT over its own location, so a redirect that moves the binary
    # while leaving the replica's root exported loads the replica's libraries
    # from the authority's binary — and prints exactly what doing nothing prints.
    _stub_authority
    run _clean env FRAMEWORK_ROOT="$WT" bash -c "cd '$WT' && ./bin/fw doctor"
    [ "$status" -eq 0 ]
    [[ "$output" == *"FRAMEWORK_ROOT=$MAIN"* ]]
    [[ "$output" != *"FRAMEWORK_ROOT=$WT"* ]]
}

@test "PROJECT_ROOT does NOT move to the authority" {
    # Deliberate: the worktree is still the project the operator stands in.
    # Moving it would silently redirect `fw git commit` to master's tree.
    _stub_authority
    run _clean bash -c "cd '$WT' && ./bin/fw doctor"
    [ "$status" -eq 0 ]
    [[ "$output" == *"PROJECT_ROOT=$WT"* ]]
}

@test "argv survives the exec intact, including arguments containing spaces" {
    _stub_authority
    run _clean bash -c "cd '$WT' && ./bin/fw task update 'T-1 two words' --note 'a b'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"ARGC=5"* ]]
    [[ "$output" == *"ARG=[task]"* ]]
    [[ "$output" == *"ARG=[T-1 two words]"* ]]
    [[ "$output" == *"ARG=[--note]"* ]]
    [[ "$output" == *"ARG=[a b]"* ]]
}

@test "the replica's binary invoked from outside the worktree still redirects" {
    # PROJECT_ROOT resolves to the main checkout here, so only the second subject
    # (the binary's own tree) can catch this. It is the shape that actually
    # happens: an August session running .claude/worktrees/x/bin/fw by path.
    _stub_authority
    run _clean bash -c "cd '$MAIN' && '$WT/bin/fw' --version"
    [ "$status" -eq 0 ]
    [[ "$output" == *"STUB-AUTHORITY"* ]]
}

@test "a worktree whose checkout predates the redirect is untouched (honest limit)" {
    # L2 is future-facing by construction: the redirect must already be in the
    # replica's own bin/fw to fire. Documented as a limit rather than discovered
    # as a bug — this is why L1 (the shared pre-commit hook) is the keystone.
    grep -v '_fw_reexec_authority "$@"' "$MAIN/bin/fw" > "$WT/bin/fw.old"
    mv "$WT/bin/fw.old" "$WT/bin/fw"
    chmod +x "$WT/bin/fw"
    run _clean bash -c "cd '$WT' && ./bin/fw --version 2>&1 | head -1"
    [[ "$output" == *REPLICA* ]]
}

@test "the linked-worktree predicate is defined exactly once, repo-wide" {
    # T-3113's lesson applied at the point of writing rather than one leg later:
    # an invariant that names a file cannot see a copy in a file it does not
    # name. Scan for definitions, list the files, assert the list. bin/fw's
    # doctor held an inline copy until this task; lib/paths.sh now sources the
    # shared definition rather than carrying its own.
    run bash -c "cd '$_FW_ROOT' && grep -rl '^fw_is_linked_worktree()' --include='*.sh' --include='*.py' --include='fw' . 2>/dev/null | grep -v '\.agentic-framework/' | grep -v '\.claude/worktrees/' | sort"
    [ "$output" = "./lib/worktree-identity.sh" ]
}

@test "lib/paths.sh still exposes fw_is_linked_worktree to everything that sources it" {
    run bash -c "FRAMEWORK_ROOT='$_FW_ROOT' PROJECT_ROOT='$_FW_ROOT' source '$_FW_ROOT/lib/paths.sh' && type -t fw_is_linked_worktree"
    [ "$status" -eq 0 ]
    [ "$output" = "function" ]
}

@test "the predicate is subdirectory-safe: <main>/bin is not a linked worktree" {
    # git answers the two halves in different forms from a SUBDIRECTORY —
    # --git-dir absolute, --git-common-dir relative — so a naive string compare
    # calls every subdirectory of the main checkout a worktree. L2 is the first
    # caller to pass a subdirectory ($FW_BIN_DIR), which is how this surfaced.
    source "$_FW_ROOT/lib/worktree-identity.sh"
    run fw_is_linked_worktree "$MAIN/bin"
    [ "$status" -eq 1 ]
    run fw_is_linked_worktree "$MAIN"
    [ "$status" -eq 1 ]
    run fw_is_linked_worktree "$WT/bin"
    [ "$status" -eq 0 ]
    run fw_is_linked_worktree "$WT"
    [ "$status" -eq 0 ]
}
