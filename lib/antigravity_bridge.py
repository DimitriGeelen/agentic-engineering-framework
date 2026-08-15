#!/usr/bin/env python3
"""
antigravity_bridge.py — Antigravity / OpenGravity CLI Hook Bridge for AEF

Translates Antigravity CLI lifecycle hook payloads (protojson camelCase)
into Claude Code format for AEF hooks (PreToolUse, PostToolUse, Stop),
invokes the target AEF hook script, and formats the output JSON.

Usage:
  python3 antigravity_bridge.py <hook-name>

Supported hook-names:
  - check-active-task
  - check-tier0
  - budget-gate
  - check-fabric-new-file
  - error-watchdog
  - stop-guard
"""

import sys
import os
import json
import subprocess

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
FRAMEWORK_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, ".."))
AGENTS_CONTEXT_DIR = os.path.join(FRAMEWORK_ROOT, "agents", "context")

HOOK_SCRIPTS = {
    "check-active-task": os.path.join(AGENTS_CONTEXT_DIR, "check-active-task.sh"),
    "check-tier0": os.path.join(AGENTS_CONTEXT_DIR, "check-tier0.sh"),
    "budget-gate": os.path.join(AGENTS_CONTEXT_DIR, "budget-gate.sh"),
    "check-fabric-new-file": os.path.join(AGENTS_CONTEXT_DIR, "check-fabric-new-file.sh"),
    "error-watchdog": os.path.join(AGENTS_CONTEXT_DIR, "error-watchdog.sh"),
    "stop-guard": os.path.join(AGENTS_CONTEXT_DIR, "stop-guard.sh"),
}

def translate_antigravity_payload(data):
    """
    Translates Antigravity stdin JSON into Claude Code hook stdin JSON.
    """
    tool_call = data.get("toolCall") or {}
    tool_name = tool_call.get("name", "")
    args = tool_call.get("args") or {}
    
    workspace_paths = data.get("workspacePaths") or []
    cwd = args.get("Cwd") or (workspace_paths[0] if workspace_paths else os.getcwd())

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
    elif tool_name in ("view_file", "list_dir", "grep_search"):
        translated_name = "View"
        translated_input = {"file_path": args.get("AbsolutePath") or args.get("DirectoryPath") or args.get("SearchPath") or ""}
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
        print(json.dumps({"decision": "deny", "reason": "No hook name specified to bridge."}))
        sys.exit(1)

    hook_name = sys.argv[1]
    hook_script = HOOK_SCRIPTS.get(hook_name)
    if not hook_script or not os.path.isfile(hook_script):
        # Allow unrecognized hooks gracefully
        print(json.dumps({"decision": "allow"}))
        sys.exit(0)

    try:
        raw_input = sys.stdin.read()
        if not raw_input.strip():
            print(json.dumps({"decision": "allow"}))
            sys.exit(0)
        data = json.loads(raw_input)
    except Exception as e:
        print(json.dumps({"decision": "allow"}))
        sys.exit(0)

    # Stop hook handling
    if hook_name == "stop-guard":
        # Check if idle or incomplete tasks
        print(json.dumps({"decision": "continue" if data.get("error") else "allow"}))
        sys.exit(0)

    translated_payload, cwd = translate_antigravity_payload(data)

    env = os.environ.copy()
    env["CLAUDECODE"] = "1"
    env["AI_AGENT"] = "antigravity"
    env["PROJECT_ROOT"] = cwd

    try:
        proc = subprocess.run(
            [hook_script],
            input=json.dumps(translated_payload),
            text=True,
            capture_output=True,
            cwd=cwd,
            env=env,
            timeout=15
        )

        stderr_msg = proc.stderr.strip()
        stdout_msg = proc.stdout.strip()

        if proc.returncode == 0:
            print(json.dumps({}))
        elif proc.returncode == 2:
            # Blocked by AEF gate
            reason = stderr_msg or stdout_msg or f"Blocked by AEF {hook_name} policy."
            print(json.dumps({
                "decision": "deny",
                "reason": reason
            }))
        else:
            # Non-standard exit code -> ask user
            reason = stderr_msg or f"AEF hook {hook_name} exited with code {proc.returncode}."
            print(json.dumps({
                "decision": "ask",
                "reason": reason
            }))
    except subprocess.TimeoutExpired:
        print(json.dumps({"decision": "deny", "reason": f"AEF hook {hook_name} timed out."}))
    except Exception as ex:
        print(json.dumps({"decision": "deny", "reason": f"AEF hook bridge error: {str(ex)}"}))

if __name__ == "__main__":
    main()
