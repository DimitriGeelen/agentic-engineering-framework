#!/usr/bin/env bats
# T-5403: the operator wires hooks (operator ruling 2026-11-24, "a"). An agent's Write/Edit that
# changes the hook wiring of .claude/settings.json is refused, Bash writes to the file are
# refused, and `fw hook-wiring propose` prepares the change as an operator runme.
# Hermetic: every settings file is a fixture under a temp dir.

load ../git_fence  # T-3610: fw init in a fixture must never reach a repo above the temp dir

setup() {
    FRAMEWORK_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    export FRAMEWORK_ROOT
    PROJ="$(mktemp -d)"
    mkdir -p "$PROJ/.claude" "$PROJ/.context/project"
    cat > "$PROJ/.claude/settings.json" <<'JSON'
{
  "permissions": {"allow": ["Bash(ls:*)"]},
  "hooks": {
    "PreToolUse": [
      {"matcher": "Bash", "hooks": [{"type": "command", "command": "fw hook check-tier0"}]}
    ]
  }
}
JSON
    S="$PROJ/.claude/settings.json"
}

teardown() {
    rm -rf "$PROJ" 2>/dev/null || { sleep 1; rm -rf "$PROJ" 2>/dev/null || true; }
}

# feed a payload to the gate under agent control
_gate() {   # json
    printf '%s' "$1" | CLAUDECODE=1 PROJECT_ROOT="$PROJ" python3 "$FRAMEWORK_ROOT/lib/hook_wiring.py" check
}

_write() {  # path content
    python3 -c 'import json,sys; print(json.dumps({"tool_name":"Write","tool_input":{"file_path":sys.argv[1],"content":sys.argv[2]}}))' "$1" "$2"
}

_edit() {   # path old new
    python3 -c 'import json,sys; print(json.dumps({"tool_name":"Edit","tool_input":{"file_path":sys.argv[1],"old_string":sys.argv[2],"new_string":sys.argv[3]}}))' "$1" "$2" "$3"
}

_bash() {   # command [cwd]
    python3 -c 'import json,sys; print(json.dumps({"tool_name":"Bash","tool_input":{"command":sys.argv[1]},"cwd":sys.argv[2]}))' "$1" "${2:-$PROJ}"
}

# ── Write/Edit leg ──

@test "T-5403: a Write that adds a hook is refused, and the message names the ruling and the proposer" {
    run _gate "$(_write "$S" '{"hooks":{"PreToolUse":[{"matcher":"","hooks":[{"type":"command","command":"evil"}]}]}}')"
    [ "$status" -eq 2 ]
    [[ "$output" == *"HOOK WIRING CHANGE BLOCKED"* ]]
    [[ "$output" == *"operator wires hooks, 2026-11-24, T-5403"* ]]
    [[ "$output" == *"hook-wiring propose --event PreToolUse"* ]]
    [[ "$output" == *"cd "* ]]
}

@test "T-5403: an Edit that removes a hook is refused" {
    run _gate "$(_edit "$S" '"command": "fw hook check-tier0"' '"command": "true"')"
    [ "$status" -eq 2 ]
    [[ "$output" == *"the edit changes hooks"* ]]
}

@test "T-5403: an Edit that leaves the hooks unchanged (permissions only) passes" {
    run _gate "$(_edit "$S" '"Bash(ls:*)"' '"Bash(ls:*)", "Bash(cat:*)"')"
    [ "$status" -eq 0 ]
}

@test "T-5403: a Write that sets disableAllHooks is refused (it switches every gate off)" {
    content=$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); d["disableAllHooks"]=True; print(json.dumps(d))' "$S")
    run _gate "$(_write "$S" "$content")"
    [ "$status" -eq 2 ]
    [[ "$output" == *"disableAllHooks"* ]]
}

@test "T-5403: a result that does not parse is refused (fail closed)" {
    run _gate "$(_edit "$S" '"permissions"' '"permissions" ,,')"
    [ "$status" -eq 2 ]
    [[ "$output" == *"does not parse"* ]]
}

@test "T-5403: settings.local.json is guarded too" {
    run _gate "$(_write "$PROJ/.claude/settings.local.json" '{"hooks":{"Stop":[]}}')"
    [ "$status" -eq 2 ]
}

@test "T-5403: other files pass untouched (a settings.json outside .claude, any other file)" {
    mkdir -p "$PROJ/.vscode"
    run _gate "$(_write "$PROJ/.vscode/settings.json" '{"hooks":1}')"
    [ "$status" -eq 0 ]
    run _gate "$(_write "$PROJ/notes.md" 'hooks')"
    [ "$status" -eq 0 ]
}

# ── Bash leg ──

@test "T-5403: Bash writes to the settings file are refused (redirect, sed -i, python -c, tee, cp)" {
    for c in 'echo {} > .claude/settings.json' \
             'sed -i "s/check-tier0/x/" .claude/settings.json' \
             "python3 -c \"open('.claude/settings.json','w').write('{}')\"" \
             'echo {} | tee .claude/settings.local.json' \
             'cp /tmp/other.json .claude/settings.json'; do
        run _gate "$(_bash "$c")"
        [ "$status" -eq 2 ] || { echo "not refused: $c"; return 1; }
    done
    run _gate "$(_bash 'echo {} > settings.json' "$PROJ/.claude")"
    [ "$status" -eq 2 ]
}

@test "T-5403: fw hook-enable typed by an agent is refused; --dry-run passes" {
    run _gate "$(_bash 'bin/fw hook-enable --name x --event PreToolUse --matcher Bash')"
    [ "$status" -eq 2 ]
    [[ "$output" == *"hook-enable writes hook wiring"* ]]
    run _gate "$(_bash 'bash bin/hook-enable.sh --name x --event PreToolUse --matcher Bash')"
    [ "$status" -eq 2 ]
    run _gate "$(_bash 'bin/fw hook-enable --name x --event PreToolUse --matcher Bash --dry-run')"
    [ "$status" -eq 0 ]
}

@test "T-5403: reads and the framework writers pass (cat, grep, git add, fw init, fw upgrade, fw enforcement baseline)" {
    for c in 'cat .claude/settings.json' 'grep -c hook .claude/settings.json' \
             'git add .claude/settings.json' \
             'bin/fw init /tmp/x' 'bin/fw upgrade /tmp/x' 'bin/fw enforcement baseline' \
             '.agentic-framework/bin/fw upgrade' 'ls -la'; do
        run _gate "$(_bash "$c")"
        [ "$status" -eq 0 ] || { echo "refused: $c :: $output"; return 1; }
    done
}

@test "T-5403: the hook wrapper refuses through fw hook and fails closed only on settings payloads" {
    run bash -c "printf '%s' '$(_write "$S" '{}')' | CLAUDECODE=1 PROJECT_ROOT='$PROJ' '$FRAMEWORK_ROOT/agents/context/check-hook-wiring.sh'"
    [ "$status" -eq 2 ]
    empty="$(mktemp -d)"
    run bash -c "printf '%s' '$(_write "$S" '{}')' | FRAMEWORK_ROOT='$empty' bash '$FRAMEWORK_ROOT/agents/context/check-hook-wiring.sh'"
    [ "$status" -eq 2 ]
    [[ "$output" == *"fail closed"* ]]
    run bash -c "printf '%s' '$(_bash 'ls')' | FRAMEWORK_ROOT='$empty' bash '$FRAMEWORK_ROOT/agents/context/check-hook-wiring.sh'"
    [ "$status" -eq 0 ]
    rmdir "$empty"
}

# ── fw init delivers the hook ──

@test "T-5403: fw init writes check-hook-wiring (Write|Edit|Bash) into a new project's settings" {
    tgt="$(mktemp -d)"
    run "$FRAMEWORK_ROOT/bin/fw" init "$tgt" --provider claude
    [ "$status" -eq 0 ]
    python3 - "$tgt/.claude/settings.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
hits = [e["matcher"] for e in d["hooks"]["PreToolUse"]
        for h in e["hooks"] if h["command"].endswith("hook check-hook-wiring")]
assert hits == ["Write|Edit|Bash"], hits
PY
    rm -rf "$tgt" 2>/dev/null || { sleep 1; rm -rf "$tgt" 2>/dev/null || true; }
}

# ── proposer + operator apply ──

@test "T-5403: propose writes a runme with the apply line and prints one bash line" {
    run env PROJECT_ROOT="$PROJ" python3 "$FRAMEWORK_ROOT/lib/hook_wiring.py" propose \
        --event PreToolUse --matcher 'Write|Edit' --command 'fw hook check-new' --name hw-test
    [ "$status" -eq 0 ]
    [[ "$output" == *"bash $PROJ/.context/runme/hw-test/runme.sh"* ]]
    grep -q "hook_wiring.py apply" "$PROJ/.context/runme/hw-test/runme.sh"
    grep -q -- "--baseline $PROJ/.context/project/enforcement-baseline.sha256" "$PROJ/.context/runme/hw-test/runme.sh"
    # proposing changes nothing yet
    ! grep -q check-new "$S" || false
}

@test "T-5403: running the runme applies the change to the fixture settings and refreshes the baseline" {
    env PROJECT_ROOT="$PROJ" python3 "$FRAMEWORK_ROOT/lib/hook_wiring.py" propose \
        --event PreToolUse --matcher 'Write|Edit' --command 'fw hook check-new' --name hw-run >/dev/null
    # The operator's terminal: no agent env, and no Claude ancestor (setsid -f reparents the run).
    env -u CLAUDECODE -u AI_AGENT -u CLAUDE_CODE_ENTRYPOINT setsid -f bash "$PROJ/.context/runme/hw-run/runme.sh" </dev/null >/dev/null 2>&1
    for _ in $(seq 1 100); do grep -q "RUNME EXIT" "$PROJ/.context/runme/hw-run/run.log" 2>/dev/null && break; sleep 0.1; done
    grep -q "RUNME EXIT 0" "$PROJ/.context/runme/hw-run/run.log"
    python3 - "$S" "$PROJ/.context/project/enforcement-baseline.sha256" <<'PY'
import hashlib, json, sys
d = json.load(open(sys.argv[1]))
cmds = [(e["matcher"], h["command"]) for e in d["hooks"]["PreToolUse"] for h in e["hooks"]]
assert ("Write|Edit", "fw hook check-new") in cmds, cmds
assert ("Bash", "fw hook check-tier0") in cmds, cmds
assert d["permissions"] == {"allow": ["Bash(ls:*)"]}
want = hashlib.sha256(json.dumps(d["hooks"], sort_keys=True).encode()).hexdigest()
assert open(sys.argv[2]).read().strip() == want
PY
}

@test "T-5403: apply refuses under agent control: env, and the process-ancestry check with env cleared" {
    a=(apply --settings "$S" --baseline "$PROJ/b.sha" --event PreToolUse --matcher X --command y)
    run env CLAUDECODE=1 python3 "$FRAMEWORK_ROOT/lib/hook_wiring.py" "${a[@]}"
    [ "$status" -eq 1 ]
    [[ "$output" == *"REFUSED"* ]]
    run env -u CLAUDECODE -u AI_AGENT -u CLAUDE_CODE_ENTRYPOINT \
        bash -c "exec -a claude bash -c 'python3 \"$FRAMEWORK_ROOT/lib/hook_wiring.py\" apply --settings \"$S\" --baseline \"$PROJ/b.sha\" --event PreToolUse --matcher X --command y'"
    [[ "$output" == *"REFUSED"* ]]
    ! grep -q '"y"' "$S" || false
    [ ! -e "$PROJ/b.sha" ]
}

@test "T-5403: change_settings adds once, removes cleanly" {
    run env FRAMEWORK_ROOT="$FRAMEWORK_ROOT" python3 - <<'PY'
import os, sys
sys.path.insert(0, os.environ["FRAMEWORK_ROOT"] + "/lib")
import hook_wiring as h
d = {"hooks": {"PreToolUse": [{"matcher": "Bash", "hooks": [{"type": "command", "command": "a"}]}]}}
assert h.change_settings(d, "PreToolUse", "Bash", "b", False)
assert not h.change_settings(d, "PreToolUse", "Bash", "b", False)        # idempotent
assert [x["command"] for x in d["hooks"]["PreToolUse"][0]["hooks"]] == ["a", "b"]
assert h.change_settings(d, "Stop", "", "c", False)
assert h.change_settings(d, "Stop", "", "c", True) and "Stop" not in d["hooks"]
assert h.change_settings(d, "PreToolUse", "Bash", "a", True)
assert not h.change_settings(d, "PreToolUse", "Bash", "zzz", True)
print("ok")
PY
    [ "$status" -eq 0 ]
    [[ "$output" == *ok* ]]
}
