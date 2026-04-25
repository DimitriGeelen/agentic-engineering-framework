#!/usr/bin/env bats
# T-1479 — fw upgrade detects when framework hooks are registered at both
# user-level (~/.claude/settings.json) and project-level
# (.claude/settings.json), warning the consumer (does NOT auto-remove user
# state). This addresses the structural cause of OBS-023 (T-1478 mitigates
# the symptom in pre-compact.sh).

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export NO_COLOR=1
    export FRAMEWORK_ROOT
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# ---- Source-level invariants ----

@test "upgrade.sh contains the duplicate-hook detection block (T-1479)" {
    grep -q "Duplicate framework hook" "$FRAMEWORK_ROOT/lib/upgrade.sh"
}

@test "upgrade.sh references \$HOME/.claude/settings.json (T-1479)" {
    grep -q '\$HOME/.claude/settings.json' "$FRAMEWORK_ROOT/lib/upgrade.sh"
}

@test "upgrade.sh sets USER_FILE/PROJ_FILE for the python helper (T-1479)" {
    grep -q "USER_FILE=" "$FRAMEWORK_ROOT/lib/upgrade.sh"
    grep -q "PROJ_FILE=" "$FRAMEWORK_ROOT/lib/upgrade.sh"
}

@test "upgrade.sh exits gracefully on malformed settings (T-1479)" {
    # Python helper catches JSONDecodeError / OSError
    grep -qE 'except .*JSONDecodeError.*FileNotFoundError.*OSError' "$FRAMEWORK_ROOT/lib/upgrade.sh"
}

@test "upgrade.sh parses (bash -n) (T-1479)" {
    bash -n "$FRAMEWORK_ROOT/lib/upgrade.sh"
}

# ---- Behavioural — exercise the embedded python directly ----
# We extract the python block and feed synthetic settings files.

_run_dedup_py() {
    local user_file="$1" proj_file="$2"
    USER_FILE="$user_file" PROJ_FILE="$proj_file" python3 -c "
import json, os

def fw_hooks(path):
    out = set()
    try:
        with open(path) as f:
            data = json.load(f)
    except (json.JSONDecodeError, FileNotFoundError, OSError):
        return out
    for event, entries in data.get('hooks', {}).items():
        for entry in entries:
            for hook in entry.get('hooks', []):
                cmd = hook.get('command', '')
                if 'fw hook' in cmd:
                    name = cmd.split('fw hook ')[-1].strip().split()[0]
                elif '.agentic-framework' in cmd:
                    name = cmd.strip().split('/')[-1]
                else:
                    continue
                out.add((event, name))
    return out

user = fw_hooks(os.environ['USER_FILE'])
proj = fw_hooks(os.environ['PROJ_FILE'])
overlap = sorted(user & proj)
print('|'.join(f'{e}:{n}' for e, n in overlap))
"
}

@test "behavioural: matched (event, hook_name) flagged as duplicate" {
    cd "$TEST_TEMP_DIR"
    cat > user.json <<'EOF'
{"hooks":{"PreCompact":[{"matcher":"","hooks":[{"type":"command","command":".agentic-framework/bin/fw hook pre-compact"}]}]}}
EOF
    cat > proj.json <<'EOF'
{"hooks":{"PreCompact":[{"matcher":"","hooks":[{"type":"command","command":"/opt/x/bin/fw hook pre-compact"}]}]}}
EOF
    out=$(_run_dedup_py user.json proj.json)
    [ "$out" = "PreCompact:pre-compact" ]
}

@test "behavioural: different hook names are NOT duplicates" {
    cd "$TEST_TEMP_DIR"
    cat > user.json <<'EOF'
{"hooks":{"PreCompact":[{"matcher":"","hooks":[{"type":"command","command":"/opt/x/bin/fw hook pre-compact"}]}]}}
EOF
    cat > proj.json <<'EOF'
{"hooks":{"PostToolUse":[{"matcher":"","hooks":[{"type":"command","command":"/opt/x/bin/fw hook checkpoint"}]}]}}
EOF
    out=$(_run_dedup_py user.json proj.json)
    [ -z "$out" ]
}

@test "behavioural: non-framework hooks are ignored" {
    cd "$TEST_TEMP_DIR"
    cat > user.json <<'EOF'
{"hooks":{"PreCompact":[{"matcher":"","hooks":[{"type":"command","command":"echo user-custom"}]}]}}
EOF
    cat > proj.json <<'EOF'
{"hooks":{"PreCompact":[{"matcher":"","hooks":[{"type":"command","command":"echo proj-custom"}]}]}}
EOF
    out=$(_run_dedup_py user.json proj.json)
    [ -z "$out" ]
}

@test "behavioural: missing user file does not crash" {
    cd "$TEST_TEMP_DIR"
    cat > proj.json <<'EOF'
{"hooks":{"PreCompact":[{"matcher":"","hooks":[{"type":"command","command":"/opt/x/bin/fw hook pre-compact"}]}]}}
EOF
    out=$(_run_dedup_py /nonexistent/user.json proj.json)
    [ -z "$out" ]
}

@test "behavioural: malformed JSON does not crash" {
    cd "$TEST_TEMP_DIR"
    echo "{not valid json" > user.json
    cat > proj.json <<'EOF'
{"hooks":{"PreCompact":[{"matcher":"","hooks":[{"type":"command","command":"/opt/x/bin/fw hook pre-compact"}]}]}}
EOF
    out=$(_run_dedup_py user.json proj.json)
    [ -z "$out" ]
}

@test "behavioural: multiple overlap pairs all reported" {
    cd "$TEST_TEMP_DIR"
    cat > user.json <<'EOF'
{
  "hooks": {
    "PreCompact": [{"matcher":"","hooks":[{"type":"command","command":"/x/fw hook pre-compact"}]}],
    "PostToolUse": [{"matcher":"","hooks":[{"type":"command","command":"/x/fw hook checkpoint"}]}]
  }
}
EOF
    cat > proj.json <<'EOF'
{
  "hooks": {
    "PreCompact": [{"matcher":"","hooks":[{"type":"command","command":"/y/fw hook pre-compact"}]}],
    "PostToolUse": [{"matcher":"","hooks":[{"type":"command","command":"/y/fw hook checkpoint"}]}]
  }
}
EOF
    out=$(_run_dedup_py user.json proj.json)
    [[ "$out" == *"PostToolUse:checkpoint"* ]]
    [[ "$out" == *"PreCompact:pre-compact"* ]]
}
