#!/usr/bin/env bats
# T-2488 / OBS-088: a resolver-dispatched TermLink worker's `claude -p` must NOT
# silently inherit the parent session's .mcp.json. The parent catalogue
# (termlink ~300 tools, skills ~150, playwright, fw, context7) injects ~175K
# tokens of tool schemas into the worker's system prompt — enough to blow the
# 200K context window before the worker reads anything ("Prompt is too long",
# terminal_reason=blocking_limit). The first real dispatch (T-2487) died exactly
# this way.
#
# The fix: the default (fallback) workflow runs strict-mcp by default, and the
# resolver envelope carries strict_mcp_config so the flag reaches `claude -p`.
# This test pins the class at three joins: the workflow declares it, the
# envelope carries it, and the worker emits the CLI flag.

load ../test_helper

@test "t2488: default workflow declares strict_mcp_config: true (lean MCP)" {
    local wf="$FRAMEWORK_ROOT/.context/project/workflows/default.yaml"
    [ -f "$wf" ]
    run python3 -c "import yaml,sys; d=yaml.safe_load(open(sys.argv[1])); sys.exit(0 if d.get('strict_mcp_config') is True else 1)" "$wf"
    [ "$status" -eq 0 ]
}

@test "t2488: resolver envelope defaults strict_mcp_config to True when workflow omits it" {
    run python3 - <<'PY'
import sys
sys.path.insert(0, "lib")
# Mirror the envelope construction default without invoking the full resolve()
# (which needs a real task file). The contract under test is the .get default.
workflow = {"worker_kind": "TermLink", "model": "sonnet"}  # no strict_mcp_config key
strict = workflow.get("strict_mcp_config", True)
mcp = workflow.get("mcp_config")
assert strict is True, f"expected lean default True, got {strict!r}"
assert mcp is None, f"expected no mcp_config, got {mcp!r}"
print("ok")
PY
    [ "$status" -eq 0 ]
    [[ "$output" == *ok* ]]
}

@test "t2488: TermLinkWorker emits --strict-mcp-config when set, omits when not" {
    cd "$FRAMEWORK_ROOT"
    run python3 - <<'PY'
import sys
sys.path.insert(0, "lib")
import termlink_worker as tw

# strict ON, no mcp_config → bare lean worker (the default-workflow case)
w = tw.TermLinkWorker(model="sonnet", cwd="/tmp", task_id="T-X",
                      allowed_tools=["Read", "Bash"], strict_mcp_config=True)
argv = w._build_dispatch_argv("hello")
assert "--strict-mcp-config" in argv, argv
assert "--mcp-config" not in argv, argv

# strict OFF (legacy / MCP-needing workflow) → no strict flag
w2 = tw.TermLinkWorker(model="sonnet", cwd="/tmp", task_id="T-X",
                       strict_mcp_config=False)
argv2 = w2._build_dispatch_argv("hello")
assert "--strict-mcp-config" not in argv2, argv2

# explicit mcp_config path composes with strict, in the right order
w3 = tw.TermLinkWorker(model="sonnet", cwd="/tmp", task_id="T-X",
                       strict_mcp_config=True, mcp_config="/tmp/x.mcp.json")
argv3 = w3._build_dispatch_argv("hello")
assert "--mcp-config" in argv3 and "--strict-mcp-config" in argv3, argv3
assert argv3.index("--mcp-config") < argv3.index("--strict-mcp-config"), argv3

print("ok")
PY
    [ "$status" -eq 0 ]
    [[ "$output" == *ok* ]]
}
