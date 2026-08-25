#!/usr/bin/env python3
"""
antigravity_bridge.py — Antigravity / OpenGravity CLI Hook Bridge for AEF

Translates Antigravity CLI lifecycle hook payloads (protojson camelCase)
into Claude Code format for AEF hooks (PreToolUse, PostToolUse, Stop),
invokes the target AEF hook script, and formats the output JSON per the
Antigravity Hook Protocol specification.

Events:
  - PreToolUse:  requires {"decision": "allow" | "deny" | "ask", "reason": "..."}
  - PostToolUse: requires {}
  - Stop:        requires {"decision": "allow" | "continue", "reason": "..."}

Usage:
  python3 antigravity_bridge.py <hook-name>
"""

import sys
import os
import json
import subprocess

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
FRAMEWORK_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, ".."))
AGENTS_CONTEXT_DIR = os.path.join(FRAMEWORK_ROOT, "agents", "context")

PRE_TOOL_HOOKS = {"check-active-task", "check-tier0", "budget-gate", "block-plan-mode"}
POST_TOOL_HOOKS = {"check-fabric-new-file", "error-watchdog", "checkpoint", "check-dispatch"}
STOP_HOOKS = {"stop-guard"}

HOOK_SCRIPTS = {
    "check-active-task": os.path.join(AGENTS_CONTEXT_DIR, "check-active-task.sh"),
    "check-tier0": os.path.join(AGENTS_CONTEXT_DIR, "check-tier0.sh"),
    "budget-gate": os.path.join(AGENTS_CONTEXT_DIR, "budget-gate.sh"),
    "check-fabric-new-file": os.path.join(AGENTS_CONTEXT_DIR, "check-fabric-new-file.sh"),
    "error-watchdog": os.path.join(AGENTS_CONTEXT_DIR, "error-watchdog.sh"),
    "stop-guard": os.path.join(AGENTS_CONTEXT_DIR, "stop-guard.sh"),
}

def find_project_root(start_dir):
    """Walks upwards to locate the project root containing .agentic-framework or .framework.yaml."""
    curr = os.path.abspath(start_dir)
    while curr != os.path.dirname(curr):
        if os.path.exists(os.path.join(curr, ".framework.yaml")) or \
           os.path.exists(os.path.join(curr, ".tasks")) or \
           os.path.exists(os.path.join(curr, ".agentic-framework")):
            return curr
        curr = os.path.dirname(curr)
    return os.path.abspath(start_dir)

def translate_antigravity_payload(data, default_cwd):
    """Translates Antigravity JSON into Claude Code hook JSON."""
    tool_call = data.get("toolCall") or {}
    tool_name = tool_call.get("name", "")
    args = tool_call.get("args") or {}

    workspace_paths = data.get("workspacePaths") or []
    candidate_cwd = args.get("Cwd") or (workspace_paths[0] if workspace_paths else default_cwd)
    cwd = find_project_root(candidate_cwd)

    # Tool mapping
    if tool_name == "run_command":
        translated_name = "Bash"
        translated_input = {"command": args.get("CommandLine", "")}
    elif tool_name == "write_to_file":
        translated_name = "Write"
        translated_input = {
            "file_path": args.get("TargetFile", ""),
            "content": args.get("CodeContent", "")
        }
    elif tool_name == "replace_file_content":
        translated_name = "Edit"
        translated_input = {
            "file_path": args.get("TargetFile", ""),
            "target_content": args.get("TargetContent", ""),
            "replacement_content": args.get("ReplacementContent", "")
        }
    elif tool_name in ("view_file", "list_dir", "grep_search", "find_by_name"):
        translated_name = "View"
        translated_input = {
            "file_path": args.get("AbsolutePath") or args.get("DirectoryPath") or args.get("SearchPath") or ""
        }
    else:
        translated_name = tool_name
        translated_input = args

    return {
        "tool_name": translated_name,
        "tool_input": translated_input,
        "cwd": cwd,
        "raw_antigravity": {
            "conversationId": data.get("conversationId"),
            "stepIdx": data.get("stepIdx"),
            "modelName": data.get("modelName"),
            "error": data.get("error")
        }
    }, cwd

def main():
    if len(sys.argv) < 2:
        print(json.dumps({"decision": "deny", "reason": "No hook name specified."}))
        sys.exit(1)

    hook_name = sys.argv[1]
    is_pre_tool = hook_name in PRE_TOOL_HOOKS
    is_stop = hook_name in STOP_HOOKS

    hook_script = HOOK_SCRIPTS.get(hook_name)
    if not hook_script or not os.path.isfile(hook_script):
        # Graceful allow for unconfigured/unsupported hooks
        if is_pre_tool or is_stop:
            print(json.dumps({"decision": "allow"}))
        else:
            print(json.dumps({}))
        sys.exit(0)

    try:
        raw_input = sys.stdin.read()
        data = json.loads(raw_input) if raw_input.strip() else {}
    except Exception:
        data = {}

    initial_cwd = os.getcwd()
    translated_payload, project_root = translate_antigravity_payload(data, initial_cwd)

    # Stop hook guard
    if is_stop:
        # If stop hook script exists, execute it, otherwise allow
        if not os.path.isfile(hook_script):
            print(json.dumps({"decision": "allow"}))
            sys.exit(0)

    env = os.environ.copy()
    env["CLAUDECODE"] = "1"
    env["AI_AGENT"] = "antigravity"
    env["PROJECT_ROOT"] = project_root

    try:
        proc = subprocess.run(
            [hook_script],
            input=json.dumps(translated_payload),
            text=True,
            capture_output=True,
            cwd=project_root,
            env=env,
            timeout=15
        )

        stderr_msg = proc.stderr.strip()
        stdout_msg = proc.stdout.strip()

        if proc.returncode == 0:
            if is_pre_tool or is_stop:
                print(json.dumps({"decision": "allow"}))
            else:
                print(json.dumps({}))
        elif proc.returncode == 2:
            # Policy denial / Task-first or Tier-0 violation
            reason = stderr_msg or stdout_msg or f"Blocked by AEF {hook_name} policy."
            if is_stop:
                print(json.dumps({"decision": "continue", "reason": reason}))
            else:
                print(json.dumps({"decision": "deny", "reason": reason}))
        else:
            reason = stderr_msg or stdout_msg or f"AEF hook {hook_name} returned code {proc.returncode}"
            if is_pre_tool:
                print(json.dumps({"decision": "ask", "reason": reason}))
            elif is_stop:
                print(json.dumps({"decision": "continue", "reason": reason}))
            else:
                print(json.dumps({}))
    except subprocess.TimeoutExpired:
        if is_pre_tool:
            print(json.dumps({"decision": "deny", "reason": f"AEF hook {hook_name} timed out."}))
        else:
            print(json.dumps({}))
    except Exception as ex:
        if is_pre_tool:
            print(json.dumps({"decision": "deny", "reason": f"AEF hook bridge error: {str(ex)}"}))
        else:
            print(json.dumps({}))

if __name__ == "__main__":
    main()
