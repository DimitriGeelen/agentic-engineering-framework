#!/usr/bin/env bats
# T-2896: the Watchtower signing key must be gitignored in the projects the
# framework GENERATES, not only in the framework's own repo.
#
# web/app.py:_resolve_secret_key writes PROJECT_ROOT/.context/working/.fw-secret-key
# (secrets.token_hex(32), chmod 0600). chmod is a filesystem control and says
# nothing to git. This repo's own .gitignore has carried the path since before the
# key existed; the two .gitignore files the framework WRITES for consumers did not,
# so every project created by `fw init` published its signing key the moment it
# committed .context/working/. Reported by 832 (rail 498) from their own tree:
# tracked for two months, pushed to origin and to a public mirror.
#
# These tests assert BEHAVIOUR (`git check-ignore` in a real repo), never the text
# of the emitted file. A grep for ".fw-secret-key" passes on a pattern that does
# not actually match anything — e.g. one anchored to the wrong depth. Each test
# that expects "ignored" is paired with a control that must come back "not ignored",
# so a green run cannot be produced by a probe that answers "ignored" to everything.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    cd "$TEST_TEMP_DIR"
    git init -q .
}

teardown() {
    cd /
    rm -rf "$TEST_TEMP_DIR"
}

# Extract a quoted heredoc body from a shell source file, by delimiter.
# Derives the expectation from the emitter at test time — pinning a copy of the
# text here would let the two drift apart silently, which is the whole defect class.
extract_heredoc() {
    local file="$1" delim="$2"
    awk -v d="$delim" '
        $0 ~ ("<<[[:space:]]*'\''" d "'\''[[:space:]]*$") { grab=1; next }
        grab && $0 == d { grab=0 }
        grab { print }
    ' "$file"
}

# --- positive control: the probe can say "not ignored" -----------------------

@test "secret-key-gitignore: with NO gitignore the key is NOT ignored (probe control)" {
    mkdir -p .context/working
    touch .context/working/.fw-secret-key

    run git check-ignore -q .context/working/.fw-secret-key
    [ "$status" -ne 0 ]      # not ignored — so a later "ignored" result means something
}

# --- lib/init.sh: the consumer's own .context/working/.gitignore -------------

@test "secret-key-gitignore: fw init's working .gitignore ignores the key (T-2896)" {
    mkdir -p .context/working
    extract_heredoc "$FRAMEWORK_ROOT/lib/init.sh" WGIT > .context/working/.gitignore
    [ -s .context/working/.gitignore ]   # extraction worked; empty would pass vacuously

    touch .context/working/.fw-secret-key
    run git check-ignore -q .context/working/.fw-secret-key
    [ "$status" -eq 0 ]
}

@test "secret-key-gitignore: fw init's working .gitignore does NOT ignore ordinary state" {
    mkdir -p .context/working
    extract_heredoc "$FRAMEWORK_ROOT/lib/init.sh" WGIT > .context/working/.gitignore

    # concerns.yaml, learnings, handovers are tracked project memory by design —
    # a rule broad enough to swallow them would be a different bug.
    touch .context/working/feedback-stream.yaml
    run git check-ignore -q .context/working/feedback-stream.yaml
    [ "$status" -ne 0 ]
}

# --- bin/fw: the vendored .agentic-framework/.gitignore ---------------------

@test "secret-key-gitignore: fw vendor's .gitignore ignores the key (T-2896)" {
    mkdir -p .agentic-framework/.context/working
    extract_heredoc "$FRAMEWORK_ROOT/bin/fw" GITIGNORE > .agentic-framework/.gitignore
    [ -s .agentic-framework/.gitignore ]

    touch .agentic-framework/.context/working/.fw-secret-key
    run git check-ignore -q .agentic-framework/.context/working/.fw-secret-key
    [ "$status" -eq 0 ]
}

# --- the depth property, which is what an anchored pattern gets wrong -------

@test "secret-key-gitignore: both patterns are unanchored so they match at any depth" {
    # 832 held two keys — one at their PROJECT_ROOT and one under
    # .agentic-framework/.context/working/, already untracked-but-committable.
    # A pattern written as `.context/working/.fw-secret-key` (this repo's own
    # .gitignore:48 form) contains a slash, which git anchors to the .gitignore's
    # own directory — it covers the first and silently misses the second.
    for src_delim in "lib/init.sh WGIT" "bin/fw GITIGNORE"; do
        set -- $src_delim
        line=$(extract_heredoc "$FRAMEWORK_ROOT/$1" "$2" | grep -F 'fw-secret-key' | grep -v '^#')
        [ -n "$line" ] || { echo "no fw-secret-key rule in $1"; false; }
        case "$line" in
            */*) echo "anchored pattern in $1: '$line' — will miss nested copies"; false ;;
        esac
    done
}

@test "secret-key-gitignore: vendored rule catches a key nested arbitrarily deep" {
    mkdir -p .agentic-framework/a/b/c/.context/working
    extract_heredoc "$FRAMEWORK_ROOT/bin/fw" GITIGNORE > .agentic-framework/.gitignore

    touch .agentic-framework/a/b/c/.context/working/.fw-secret-key
    run git check-ignore -q .agentic-framework/a/b/c/.context/working/.fw-secret-key
    [ "$status" -eq 0 ]

    # control at the same depth — the rule is specific, not a blanket ignore
    touch .agentic-framework/a/b/c/.context/working/session.yaml
    run git check-ignore -q .agentic-framework/a/b/c/.context/working/session.yaml
    [ "$status" -ne 0 ]
}

# --- this repo stays clean --------------------------------------------------

@test "secret-key-gitignore: no .fw-secret-key is tracked in this repo" {
    cd "$FRAMEWORK_ROOT"
    run bash -c "git ls-files | grep -c 'fw-secret-key' || true"
    [ "$(echo "$output" | tr -d '[:space:]')" = "0" ]
}
