#!/usr/bin/env bash
# provision.sh — Provision Antigravity / OpenGravity (AGY) provider package in target project
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

TARGET_DIR="${1:-$(pwd)}"
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

echo "=== Provisioning AEF Antigravity Provider Package ==="
echo "Target Project: $TARGET_DIR"
echo "Framework Root: $FRAMEWORK_ROOT"

AGENTS_DIR="$TARGET_DIR/.agents"
mkdir -p "$AGENTS_DIR"

# 1. Symlink .agentic-framework inside .agents for seamless relative resolution
if [ -d "$TARGET_DIR/.agentic-framework" ]; then
    ln -sfn ../.agentic-framework "$AGENTS_DIR/.agentic-framework"
else
    ln -sfn "$FRAMEWORK_ROOT" "$AGENTS_DIR/.agentic-framework"
fi

# 2. Generate .agents/mcp_config.json
MCP_CONFIG_FILE="$AGENTS_DIR/mcp_config.json"
cat << JSONEOF > "$MCP_CONFIG_FILE"
{
  "mcpServers": {
    "framework": {
      "command": "python3",
      "args": ["$FRAMEWORK_ROOT/tools/framework_mcp_server.py"]
    }
  }
}
JSONEOF
echo "  [OK] Generated $MCP_CONFIG_FILE"

# 3. Generate .agents/hooks.json
HOOKS_CONFIG_FILE="$AGENTS_DIR/hooks.json"
cat << JSONEOF > "$HOOKS_CONFIG_FILE"
{
  "aef-check-active-task": {
    "PreToolUse": [
      {
        "matcher": "run_command|write_to_file|replace_file_content",
        "hooks": [
          {
            "type": "command",
            "command": "python3 .agentic-framework/lib/antigravity_bridge.py check-active-task",
            "timeout": 15
          }
        ]
      }
    ]
  },
  "aef-check-tier0": {
    "PreToolUse": [
      {
        "matcher": "run_command",
        "hooks": [
          {
            "type": "command",
            "command": "python3 .agentic-framework/lib/antigravity_bridge.py check-tier0",
            "timeout": 15
          }
        ]
      }
    ]
  },
  "aef-budget-gate": {
    "PreToolUse": [
      {
        "matcher": "run_command|write_to_file|replace_file_content",
        "hooks": [
          {
            "type": "command",
            "command": "python3 .agentic-framework/lib/antigravity_bridge.py budget-gate",
            "timeout": 15
          }
        ]
      }
    ]
  },
  "aef-fabric-new-file": {
    "PostToolUse": [
      {
        "matcher": "write_to_file",
        "hooks": [
          {
            "type": "command",
            "command": "python3 .agentic-framework/lib/antigravity_bridge.py check-fabric-new-file",
            "timeout": 15
          }
        ]
      }
    ]
  },
  "aef-error-watchdog": {
    "PostToolUse": [
      {
        "matcher": "run_command|write_to_file|replace_file_content",
        "hooks": [
          {
            "type": "command",
            "command": "python3 .agentic-framework/lib/antigravity_bridge.py error-watchdog",
            "timeout": 15
          }
        ]
      }
    ]
  }
}
JSONEOF
echo "  [OK] Generated $HOOKS_CONFIG_FILE"

# 4. Provision Antigravity Skill: aef-assistant
SKILL_DIR="$AGENTS_DIR/skills/aef-assistant"
mkdir -p "$SKILL_DIR"

if [ -f "$FRAMEWORK_ROOT/templates/antigravity/aef-assistant/SKILL.md" ]; then
    cp "$FRAMEWORK_ROOT/templates/antigravity/aef-assistant/SKILL.md" "$SKILL_DIR/SKILL.md"
fi
echo "  [OK] Provisioned skill in $SKILL_DIR"

# 5. Provision top-level Authority Model (AGENTS.md & GEMINI.md)
if [ -f "$TARGET_DIR/CLAUDE.md" ]; then
    ln -sfn CLAUDE.md "$TARGET_DIR/AGENTS.md"
    ln -sfn CLAUDE.md "$TARGET_DIR/GEMINI.md"
    echo "  [OK] Linked AGENTS.md and GEMINI.md -> CLAUDE.md"
elif [ -f "$TARGET_DIR/AGENTS.md" ]; then
    ln -sfn AGENTS.md "$TARGET_DIR/GEMINI.md"
    echo "  [OK] Linked GEMINI.md -> AGENTS.md"
fi

# 6. Ensure project bin/fw shortcut exists
mkdir -p "$TARGET_DIR/bin"
if [ -f "$TARGET_DIR/.agentic-framework/bin/fw" ]; then
    ln -sfn ../.agentic-framework/bin/fw "$TARGET_DIR/bin/fw"
else
    ln -sfn "$FRAMEWORK_ROOT/bin/fw" "$TARGET_DIR/bin/fw"
fi
echo "  [OK] Linked bin/fw shortcut"

echo "=== Provisioning Complete! ==="
