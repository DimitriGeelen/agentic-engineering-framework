#!/usr/bin/env python3
"""Antigravity / OpenGravity session adapter for `fw sessions` (T-2417).

Inspects Antigravity CLI conversations / brain directories and emits canonical
JSONL on stdout per the contract in agents/sessions/SCHEMA.md.
"""
import json
import os
import sys
import time
import subprocess

NOW = int(time.time())

def project_for(cwd):
    if not cwd or not isinstance(cwd, str):
        return "(loose)"
    home = os.path.expanduser("~")
    if cwd in (home, "/tmp", "/var/tmp", "/", "/root"):
        return "(loose)"
    try:
        if not os.path.isdir(cwd):
            return "(loose)"
        result = subprocess.run(
            ["git", "-C", cwd, "rev-parse", "--show-toplevel"],
            capture_output=True,
            text=True,
            timeout=2,
        )
        if result.returncode != 0:
            return "(loose)"
        toplevel = result.stdout.strip()
        return os.path.basename(toplevel) if toplevel else "(loose)"
    except Exception:
        return "(loose)"

def main():
    gemini_dir = os.path.expanduser("~/.gemini/antigravity-cli")
    brain_dir = os.path.join(gemini_dir, "brain")
    
    if not os.path.exists(gemini_dir):
        return 0

    sessions = []
    
    # Check brain directory for active/recent conversations
    if os.path.isdir(brain_dir):
        for entry in os.listdir(brain_dir):
            conv_path = os.path.join(brain_dir, entry)
            if not os.path.isdir(conv_path):
                continue
            
            mtime = int(os.path.getmtime(conv_path))
            age = max(0, NOW - mtime)
            
            cwd = os.getcwd()
            
            out = {
                "provider": "antigravity",
                "project": project_for(cwd),
                "name": f"Session {entry[:8]}",
                "state": "working" if age < 300 else "completed",
                "age_seconds": age,
                "session_id": entry,
                "cwd": cwd
            }
            sys.stdout.write(json.dumps(out, separators=(",", ":")) + "\n")
            
    return 0

if __name__ == "__main__":
    sys.exit(main())
