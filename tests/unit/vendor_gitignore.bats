#!/usr/bin/env bats
# Regression: fw vendor must write a .gitignore inside the vendored
# .agentic-framework/ directory so runtime-generated __pycache__/.pyc
# files do not leak into the consumer's git index (T-1323).
#
# Origin: termlink T-1130 pickup (P-038) → T-1321 inception (GO) → T-1323 build.

load ../test_helper

@test "vendored framework includes a .gitignore" {
    PROJECT="$TEST_TEMP_DIR/consumer"
    mkdir -p "$PROJECT"
    cd "$PROJECT"
    # Vendor from the real framework root to a fresh consumer dir.
    PROJECT_ROOT="$PROJECT" run "$FRAMEWORK_ROOT/bin/fw" vendor --target "$PROJECT" --source "$FRAMEWORK_ROOT"
    [ "$status" -eq 0 ] || {
        echo "vendor output:"
        echo "$output"
        return 1
    }
    [ -f "$PROJECT/.agentic-framework/.gitignore" ]
}

@test "vendored .gitignore contains __pycache__ and *.pyc" {
    PROJECT="$TEST_TEMP_DIR/consumer"
    mkdir -p "$PROJECT"
    cd "$PROJECT"
    PROJECT_ROOT="$PROJECT" run "$FRAMEWORK_ROOT/bin/fw" vendor --target "$PROJECT" --source "$FRAMEWORK_ROOT"
    [ "$status" -eq 0 ]
    local content
    content=$(cat "$PROJECT/.agentic-framework/.gitignore")
    [[ "$content" == *"__pycache__/"* ]]
    [[ "$content" == *"*.pyc"* ]]
}

@test "vendor output mentions .gitignore creation" {
    PROJECT="$TEST_TEMP_DIR/consumer"
    mkdir -p "$PROJECT"
    cd "$PROJECT"
    PROJECT_ROOT="$PROJECT" run "$FRAMEWORK_ROOT/bin/fw" vendor --target "$PROJECT" --source "$FRAMEWORK_ROOT"
    [ "$status" -eq 0 ]
    [[ "$output" == *".gitignore"* ]]
}

@test "git inside the vendored dir would ignore a freshly-created __pycache__" {
    PROJECT="$TEST_TEMP_DIR/consumer"
    mkdir -p "$PROJECT"
    cd "$PROJECT"
    PROJECT_ROOT="$PROJECT" run "$FRAMEWORK_ROOT/bin/fw" vendor --target "$PROJECT" --source "$FRAMEWORK_ROOT"
    [ "$status" -eq 0 ]

    # Initialize git so check-ignore can resolve.
    git -C "$PROJECT/.agentic-framework" init -q
    mkdir -p "$PROJECT/.agentic-framework/web/__pycache__"
    : > "$PROJECT/.agentic-framework/web/__pycache__/app.cpython-310.pyc"

    # check-ignore exits 0 if the path is ignored.
    run git -C "$PROJECT/.agentic-framework" check-ignore -q web/__pycache__/app.cpython-310.pyc
    [ "$status" -eq 0 ]
}
