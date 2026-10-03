#!/usr/bin/env bats
# T-3766 — vendor credential location is a registry fact: `credential:` per backend in
# policy/review-backends.yaml, resolved by `fw review credential`, never printed.
#
# Hermetic: the sandbox gets its own registry copy whose openrouter entry points at a
# temp file holding a FAKE value built at run time. The real /root credential file is
# never read; the boundary-hook pair only feeds command TEXT to the hook.

load ../test_helper

RC="$FRAMEWORK_ROOT/lib/review_cost.py"
BOUNDARY="$FRAMEWORK_ROOT/agents/context/check-project-boundary.sh"
PAID="$FRAMEWORK_ROOT/agents/context/check-paid-backend.sh"
REAL_CRED="/root/.litellm-openrouter.env"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    unset CLAUDECODE FW_SESSION_SCOPED_FOCUS OPENROUTER_API_KEY
    mkdir -p "$PROJECT_ROOT/policy" "$PROJECT_ROOT/.context/working" "$PROJECT_ROOT/.tasks/active"
    cp "$FRAMEWORK_ROOT/policy/review-backends.yaml" "$PROJECT_ROOT/policy/"
    POLICY="$PROJECT_ROOT/policy/review-backends.yaml"
    CRED="$TEST_TEMP_DIR/cred.env"
    # Fake values, assembled so no literal key shape sits in this file.
    FILEVAL="sk-""or-v1-""FILEVALUE$(date +%N)abcdef"
    ENVVAL="sk-""or-v1-""ENVVALUE$(date +%N)ghijkl"
    printf '# litellm\nOTHER=x\nOPENROUTER_API_KEY=%s\n' "$FILEVAL" > "$CRED"
    chmod 600 "$CRED"
    point_openrouter_at "$CRED"
    cd "$PROJECT_ROOT"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

rc() { python3 "$RC" "$@"; }
focus() { printf 'current_task: %s\n' "$1" > "$PROJECT_ROOT/.context/working/focus.yaml"; }
hook_json() { python3 -c 'import json,sys; print(json.dumps({"tool_name":"Bash","tool_input":{"command":sys.argv[1]}}))' "$1"; }

point_openrouter_at() {  # rewrite openrouter's credential.files to the given paths
    python3 - "$POLICY" "$@" <<'PY'
import sys, yaml, re
path, files = sys.argv[1], sys.argv[2:]
s = open(path).read()
block = "      files:\n" + "".join(f"        - {f}\n" for f in files)
s2 = re.sub(r"(      env: OPENROUTER_API_KEY\n)      files:\n(        - .*\n)+", r"\1" + block.replace("\\", "\\\\"), s)
assert s2 != s or all(f in s for f in files)
open(path, "w").write(s2)
yaml.safe_load(open(path))
PY
}

no_value() {  # the fake values never appear in captured output
    [[ "$output" != *"$FILEVAL"* ]] && [[ "$output" != *"$ENVVAL"* ]]
}

# ── registry ──────────────────────────────────────────────────────────────────

@test "seeded registry: every backend records a credential source; openrouter is env-file" {
    run python3 - "$FRAMEWORK_ROOT/policy/review-backends.yaml" <<'PY'
import sys, yaml
bs = yaml.safe_load(open(sys.argv[1]))["backends"]
for b in bs:
    assert b.get("credential"), b["id"]
o = next(b for b in bs if b["id"] == "openrouter")["credential"]
assert o["env"] == "OPENROUTER_API_KEY" and "/root/.litellm-openrouter.env" in o["files"], o
for bid in ("codex", "opencode", "antigravity", "claude-code"):
    c = next(b for b in bs if b["id"] == bid)["credential"]
    assert c["source"] == "cli-login" and c["note"].strip(), bid
PY
    [ "$status" -eq 0 ]
}

@test "registry validation refuses a value-looking string in credential (control: a path loads)" {
    run rc list-backends
    [ "$status" -eq 0 ]
    python3 - "$POLICY" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
s = s.replace("env: OPENROUTER_API_KEY", "env: OPENROUTER_API_KEY\n      note: \"" + "sk-" + "or-v1-0123456789abcdef\"", 1)
open(p, "w").write(s)
PY
    run rc list-backends
    [ "$status" -ne 0 ]
    [[ "$output" == *"looks like a credential VALUE"* ]]
}

@test "registry validation refuses a long base64 blob and an unknown credential key" {
    python3 - "$POLICY" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
s = s.replace("env: OPENROUTER_API_KEY", "env: OPENROUTER_API_KEY\n      value: QUJDREVGR0hJSktMTU5PUFFSU1RVVldYWVphYmNkZWZn", 1)
open(p, "w").write(s)
PY
    run rc list-backends
    [ "$status" -ne 0 ]
    [[ "$output" == *"unknown key 'value'"* ]]
    [[ "$output" == *"looks like a credential VALUE"* ]]
}

# ── resolution ────────────────────────────────────────────────────────────────

@test "env set: env wins over the file, value never printed" {
    export OPENROUTER_API_KEY="$ENVVAL"
    run rc credential openrouter --check
    [ "$status" -eq 0 ]
    [[ "$output" == *"resolved from environment \$OPENROUTER_API_KEY"* ]]
    [[ "$output" == *"****"* ]]
    no_value
}

@test "env empty: resolves from the registered file, value never printed" {
    export OPENROUTER_API_KEY=""
    run rc credential openrouter --check
    [ "$status" -eq 0 ]
    [[ "$output" == *"resolved from file $CRED"* ]]
    no_value
}

@test "files are tried in order: a missing first file falls through to the second" {
    point_openrouter_at "$TEST_TEMP_DIR/absent.env" "$CRED"
    run rc credential openrouter --check
    [ "$status" -eq 0 ]
    [[ "$output" == *"from file $CRED"* ]]
}

@test "neither: clear error naming the registry entry (variable, files, registry path)" {
    point_openrouter_at "$TEST_TEMP_DIR/absent.env"
    run rc credential openrouter --check
    [ "$status" -eq 1 ]
    [[ "$output" == *"no value for OPENROUTER_API_KEY"* ]]
    [[ "$output" == *"backend 'openrouter'"* ]]
    [[ "$output" == *"$POLICY"* ]]
    [[ "$output" == *"absent.env"* ]]
}

@test "file without the variable: error does not echo the file's other content" {
    printf 'SOMETHING_ELSE=%s\n' "$FILEVAL" > "$CRED"
    run rc credential openrouter --check
    [ "$status" -eq 1 ]
    no_value
}

@test "file is parsed, never sourced: shell in the file does not run" {
    printf 'touch %s/pwned\nOPENROUTER_API_KEY="%s"\n' "$TEST_TEMP_DIR" "$FILEVAL" > "$CRED"
    run rc credential openrouter --check
    [ "$status" -eq 0 ]
    [ ! -e "$TEST_TEMP_DIR/pwned" ]
    no_value
}

@test "unsafe file refused: world-writable, and symlink (control: 0600 regular file passes)" {
    chmod 666 "$CRED"
    run rc credential openrouter --check
    [ "$status" -eq 1 ]; [[ "$output" == *"group/world-writable"* ]]
    chmod 600 "$CRED"
    ln -s "$CRED" "$TEST_TEMP_DIR/link.env"
    point_openrouter_at "$TEST_TEMP_DIR/link.env"
    run rc credential openrouter --check
    [ "$status" -eq 1 ]; [[ "$output" == *"symlink"* ]]
}

@test "--source must be a registered file (an arbitrary path is refused)" {
    printf 'OPENROUTER_API_KEY=%s\n' "$FILEVAL" > "$TEST_TEMP_DIR/other.env"; chmod 600 "$TEST_TEMP_DIR/other.env"
    run rc credential openrouter --check --source "$TEST_TEMP_DIR/other.env"
    [ "$status" -eq 1 ]; [[ "$output" == *"not a registered credential file"* ]]
    no_value
    run rc credential openrouter --check --source "$CRED"
    [ "$status" -eq 0 ]
}

@test "cli-login backend reports what authenticates; --exec refuses (nothing to inject)" {
    run rc credential codex --check
    [ "$status" -eq 0 ]; [[ "$output" == *"cli-login"* ]]
    run rc credential codex --exec -- true
    [ "$status" -eq 1 ]
}

@test "uncommitted credential-block edit is refused when the registry is git-tracked" {
    git -C "$PROJECT_ROOT" init -q
    git -C "$PROJECT_ROOT" -c user.email=t@t -c user.name=t add policy/review-backends.yaml
    git -C "$PROJECT_ROOT" -c user.email=t@t -c user.name=t commit -q -m fixture
    run rc credential openrouter --check
    [ "$status" -eq 0 ]
    point_openrouter_at "$TEST_TEMP_DIR/elsewhere.env"
    run rc credential openrouter --check
    [ "$status" -eq 1 ]; [[ "$output" == *"uncommitted change to the credential block of openrouter"* ]]
}

# ── --exec and the paid guard ────────────────────────────────────────────────

@test "--exec on paid openrouter without an approved proposal is refused (resolver and hook)" {
    focus T-9999
    run rc credential openrouter --exec -- true
    [ "$status" -eq 1 ]; [[ "$output" == *"needs an approved, unused proposal"* ]]
    run bash -c "$(printf '%q' "$PAID") <<<'$(hook_json "bin/fw review credential openrouter --exec -- python3 x.py")'"
    [ "$status" -eq 2 ]
    # control: --check is not a paid call
    run bash -c "$(printf '%q' "$PAID") <<<'$(hook_json "bin/fw review credential openrouter --check")'"
    [ "$status" -eq 0 ]
}

@test "--exec with an approved proposal runs the command with the variable set, output masked" {
    focus T-9999
    run rc propose --task T-9999 --backend openrouter --why "fixture" --estimate-cost 1
    pid="$(echo "$output" | grep -o 'RP-[A-Za-z0-9-]*' | head -1)"
    run rc approve "$pid" --i-am-human --reason fixture
    [ "$status" -eq 0 ]
    run rc credential openrouter --exec -- sh -c 'test -n "$OPENROUTER_API_KEY" && printenv OPENROUTER_API_KEY && printenv OPENROUTER_API_KEY >&2'
    [ "$status" -eq 0 ]
    [[ "$output" == *"****"* ]]
    no_value
}

# ── boundary hook pair ───────────────────────────────────────────────────────

@test "boundary: cat of the registered file stays blocked; the resolver naming it is allowed" {
    point_openrouter_at "$REAL_CRED"
    run bash -c "$(printf '%q' "$BOUNDARY") <<<'$(hook_json "cat $REAL_CRED")'"
    [ "$status" -eq 2 ]
    run bash -c "$(printf '%q' "$BOUNDARY") <<<'$(hook_json "bin/fw review credential openrouter --check --source $REAL_CRED")'"
    [ "$status" -eq 0 ]
}

@test "boundary: exemption does not widen — sibling segment, substitution, write, unregistered path" {
    point_openrouter_at "$REAL_CRED"
    for c in "bin/fw review credential openrouter --check --source $REAL_CRED && cat $REAL_CRED" \
             "bin/fw review credential openrouter --check --source \$( cat $REAL_CRED )" \
             "bin/fw review credential openrouter --check --source $REAL_CRED > $REAL_CRED" \
             "bin/fw review credential openrouter --check $REAL_CRED" \
             "bin/fw review credential openrouter --check --source /root/.ssh/id_rsa"; do
        run bash -c "$(printf '%q' "$BOUNDARY") <<<'$(hook_json "$c")'"
        [ "$status" -eq 2 ] || { echo "not blocked: $c"; false; }
    done
}

@test "boundary: a path not registered in the registry is not exempt even as --source" {
    point_openrouter_at "$CRED"
    run bash -c "$(printf '%q' "$BOUNDARY") <<<'$(hook_json "bin/fw review credential openrouter --check --source $REAL_CRED")'"
    [ "$status" -eq 2 ]
}
