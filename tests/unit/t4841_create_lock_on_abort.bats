#!/usr/bin/env bats
# T-4841: an aborted create must release task-id-allocation.
#
# Field report (1409, msg 62898926): a create killed by timeout left child
# processes holding .context/locks/task-id-allocation.lock. The lock is a flock
# on a shell fd; flock locks belong to the open file description, so any child
# that inherited the fd keeps the lock after the parent dies.
#
# Arrange: a `git` stub on PATH that, once, blocks (sleep) when the allocator's
# view scan calls `git rev-parse` inside the locked section. SIGTERM only the
# create-task.sh parent, leave the stub running, and require a second create
# to get the lock without waiting for the orphaned child.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    PROJECT="$TEST_TEMP_DIR/proj"
    mkdir -p "$PROJECT/.tasks/active" "$PROJECT/.tasks/completed" \
             "$PROJECT/.tasks/templates" "$PROJECT/.context/working" \
             "$PROJECT/.context/locks"
    touch "$PROJECT/.framework.yaml"
    cp "$FRAMEWORK_ROOT/.tasks/templates/default.md" "$PROJECT/.tasks/templates/default.md"
    cat > "$PROJECT/.tasks/active/T-100-seed.md" <<EOF
---
id: T-100
name: "Seed"
status: captured
---
EOF
    STUB="$TEST_TEMP_DIR/bin"
    mkdir -p "$STUB"
    REAL_GIT="$(command -v git)"
    # Blocks exactly once, on the rev-parse that fw_task_view_dirs runs inside
    # generate_id (under the lock). mkdir is the atomic "first caller" marker.
    cat > "$STUB/git" <<EOF
#!/bin/bash
case " \$* " in
  *" rev-parse "*)
    if mkdir "$TEST_TEMP_DIR/blocked" 2>/dev/null; then
      echo \$\$ > "$TEST_TEMP_DIR/child.pid"
      sleep 60
    fi ;;
esac
exec "$REAL_GIT" "\$@"
EOF
    chmod +x "$STUB/git"
}

teardown() {
    if [ -f "$TEST_TEMP_DIR/child.pid" ]; then
        kill "$(cat "$TEST_TEMP_DIR/child.pid")" 2>/dev/null || true
        pkill -f "$TEST_TEMP_DIR" 2>/dev/null || true
    fi
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_create() {
    PATH="$STUB:$PATH" PROJECT_ROOT="$PROJECT" TASKS_DIR="$PROJECT/.tasks" \
        "$FRAMEWORK_ROOT/agents/task-create/create-task.sh" \
        --name "$1" --description "abort test" --type build --owner agent
}

@test "T-4841: SIGTERM on the create parent releases task-id-allocation despite a live child" {
    # A simple command, not the _create function: $! must be create-task.sh
    # itself, not a subshell wrapping it. 3>&- keeps bats from waiting on the orphan.
    PATH="$STUB:$PATH" PROJECT_ROOT="$PROJECT" TASKS_DIR="$PROJECT/.tasks" \
        "$FRAMEWORK_ROOT/agents/task-create/create-task.sh" \
        --name "first" --description "abort test" --type build --owner agent \
        >/dev/null 2>&1 </dev/null 3>&- &
    local parent=$!

    # Wait for the child to be running inside the locked section.
    local i
    for i in $(seq 1 100); do
        [ -s "$TEST_TEMP_DIR/child.pid" ] && break
        sleep 0.1
    done
    [ -s "$TEST_TEMP_DIR/child.pid" ]
    local child
    child=$(cat "$TEST_TEMP_DIR/child.pid")

    kill -TERM "$parent"
    wait "$parent" 2>/dev/null || true
    # The orphan must still be alive, otherwise this test proves nothing.
    kill -0 "$child"

    # A second create must get the lock without waiting for the orphan.
    run timeout 15 bash -c "$(declare -f _create); STUB='$STUB' PROJECT='$PROJECT' FRAMEWORK_ROOT='$FRAMEWORK_ROOT' _create second"
    echo "status=$status output=$output" >&2
    [ "$status" -eq 0 ]
    ls "$PROJECT/.tasks/active/" | grep -q -- '-second\.md$'
    # The orphan is still running: the second create did not succeed by outliving it.
    kill -0 "$child"
}

@test "T-4841: a completed create leaves no process holding the lock file" {
    mkdir "$TEST_TEMP_DIR/blocked"   # stub must not block here
    run _create "plain"
    [ "$status" -eq 0 ]
    command -v fuser >/dev/null || skip "fuser not installed"
    # After a normal create nothing may keep the lock fd open.
    ! fuser "$PROJECT/.context/locks/task-id-allocation.lock" 2>/dev/null || false
}
