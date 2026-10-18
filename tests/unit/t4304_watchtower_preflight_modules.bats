#!/usr/bin/env bats
# T-4304: Watchtower's start pre-flight must check the modules the app imports at
# load, and on a missing one exit 1 with ONE actionable message. Before this, the
# pre-flight checked only `import flask`, so on a clean ubuntu:24.04 the server
# started, died on `import markdown2` (web/blueprints/core.py:6) and printed a
# traceback. Nothing installs the module and PEP 668 blocks a plain pip install.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d -t t4304-XXXXXX)"
    export NO_COLOR=1
    PROJ="$TEST_TEMP_DIR/project"
    STUB="$TEST_TEMP_DIR/stub"
    CALLS="$TEST_TEMP_DIR/calls"
    mkdir -p "$PROJ" "$STUB/bin"
    # markdown2 that cannot import: the same failure as a clean interpreter.
    echo 'raise ImportError("markdown2 blocked by the T-4304 test")' > "$STUB/markdown2.py"
    # sudo and pip record their calls; the pre-flight must never run either.
    for c in sudo pip pip3; do
        printf '#!/bin/bash\necho "%s $*" >> "%s"\nexit 0\n' "$c" "$CALLS" > "$STUB/bin/$c"
        chmod +x "$STUB/bin/$c"
    done
}

teardown() { rm -rf "${TEST_TEMP_DIR:?}"; }

_start() {
    # PROJECT_ROOT points at a temp project so no real .context/ state is touched.
    run env NO_COLOR=1 PROJECT_ROOT="$PROJ" PYTHONPATH="$STUB" \
        PATH="$STUB/bin:$PATH" bash "$FRAMEWORK_ROOT/bin/watchtower.sh" start --port 39041
}

@test "T-4304: start exits 1 when a required module is missing" {
    _start
    [ "$status" -eq 1 ]
}

@test "T-4304: the message names the missing module" {
    _start
    [[ "$output" == *"missing Python module(s): markdown2"* ]]
}

@test "T-4304: the message carries an install command for this machine" {
    _start
    [[ "$output" =~ Install:\ (sudo\ apt-get\ install\ -y\ .*python3-markdown2|python3\ -m\ venv\ .*\ pip\ install\ .*markdown2) ]]
}

@test "T-4304: one error line, no traceback" {
    _start
    [ "$(echo "$output" | grep -c 'Watchtower cannot start')" -eq 1 ]
    [[ "$output" != *Traceback* ]]
}

@test "T-4304: the pre-flight never runs sudo or pip" {
    _start
    [ ! -s "$CALLS" ]
}

@test "T-4304: the required set is the start-path set, not the optional extras" {
    # Optional modules are imported lazily and the app degrades without them
    # (web/embeddings.py, web/search.py are imported inside request handlers).
    # Pinning them out of the required list keeps a missing extra from blocking start.
    run grep -n 'WATCHTOWER_REQUIRED_MODULES=' -A6 "$FRAMEWORK_ROOT/bin/watchtower.sh"
    [ "$status" -eq 0 ]
    [[ "$output" != *ollama* ]]
    [[ "$output" != *sqlite_vec* ]]
    [[ "$output" != *tantivy* ]]
    [[ "$output" == *markdown2* ]]
}
