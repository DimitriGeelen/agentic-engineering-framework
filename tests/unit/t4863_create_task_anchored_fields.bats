#!/usr/bin/env bats
# T-4863 — create-task.sh must set exactly its frontmatter keys. Text in the
# name or description that looks like a frontmatter line is never rewritten.
#
# Origin: ring20-dashboard (msg 17bebede, their patch 0018 / T-2020). The
# templates were filled by plain str.replace AFTER name and description were
# inserted: 'owner:' (count=1) hit an 'owner:' inside the name instead of the
# key, leaving the key empty (T-4787's empty owner); 'status: captured' and
# 'horizon: now' had no count, so every copy in the description was rewritten.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
CREATE_TASK="$FRAMEWORK_ROOT/agents/task-create/create-task.sh"

NAME_TXT='Fix owner: field and status: captured with horizon: now'
DESC_TXT='Body says owner: someone, status: captured and horizon: now.
created: yesterday
workflow_type: none tags: [] related_tasks: []'

setup() {
    export TEST_DIR="$BATS_TEST_TMPDIR/t4863"
    mkdir -p "$TEST_DIR/active" "$TEST_DIR/completed" "$TEST_DIR/templates"
    cp "$FRAMEWORK_ROOT/.tasks/templates/default.md" "$TEST_DIR/templates/"
    cp "$FRAMEWORK_ROOT/.tasks/templates/inception.md" "$TEST_DIR/templates/"
    export TASKS_DIR="$TEST_DIR"
    export PROJECT_ROOT="$FRAMEWORK_ROOT"
    # Sandbox CONTEXT_DIR: --start writes focus (T-2832).
    export CONTEXT_DIR="$TEST_DIR/.context"
    mkdir -p "$CONTEXT_DIR/working" "$CONTEXT_DIR/project" "$CONTEXT_DIR/episodic"
    unset CLAUDECODE FW_ALLOW_EMPTY_RECOMMENDATION FW_INCEPTION_PRE_GATED
    unset FW_SESSION_SCOPED_FOCUS FW_FOCUS_SESSION_KEY
}

# Asserts frontmatter keys and that name/description round-trip unchanged.
check_file() {
    local f="$1" want_status="$2" want_horizon="$3" want_type="$4"
    WANT_NAME="$NAME_TXT" WANT_DESC="$DESC_TXT" python3 - "$f" "$want_status" "$want_horizon" "$want_type" <<'PY'
import os, sys, yaml
path, st, hz, wt = sys.argv[1:5]
text = open(path).read()
fm = yaml.safe_load(text.split('---\n', 2)[1])
errs = []
def want(k, v):
    if fm.get(k) != v:
        errs.append(f'{k}: got {fm.get(k)!r}, want {v!r}')
want('owner', 'agent')
want('status', st)
want('horizon', hz)
want('workflow_type', wt)
want('name', os.environ['WANT_NAME'])
want('tags', ['t4863'])
want('related_tasks', [])
if not str(fm.get('created', '')).startswith('20'):
    errs.append(f"created: got {fm.get('created')!r}")
# folded scalar: single newlines fold to spaces
want('description', os.environ['WANT_DESC'].replace('\n', ' ') + '\n')
if errs:
    print('\n'.join(errs)); sys.exit(1)
PY
}

@test "T-4863: default template — frontmatter keys set, name/description untouched (horizon later)" {
    run "$CREATE_TASK" --name "$NAME_TXT" --description "$DESC_TXT" \
        --type build --owner agent --horizon later --tags t4863
    [ "$status" -eq 0 ]
    f=$(ls "$TEST_DIR/active/T-"*.md | head -1)
    run check_file "$f" captured later build
    echo "$output"
    [ "$status" -eq 0 ]
}

@test "T-4863: default template — --start sets status without rewriting the body" {
    run "$CREATE_TASK" --name "$NAME_TXT" --description "$DESC_TXT" \
        --type build --owner agent --tags t4863 --start
    [ "$status" -eq 0 ]
    f=$(ls "$TEST_DIR/active/T-"*.md | head -1)
    run check_file "$f" started-work now build
    echo "$output"
    [ "$status" -eq 0 ]
}

@test "T-4863: inception template — frontmatter keys set, name/description untouched" {
    run "$CREATE_TASK" --name "$NAME_TXT" --description "$DESC_TXT" \
        --type inception --owner agent --horizon later --tags t4863
    [ "$status" -eq 0 ]
    f=$(ls "$TEST_DIR/active/T-"*.md | head -1)
    run check_file "$f" captured later inception
    echo "$output"
    [ "$status" -eq 0 ]
}
