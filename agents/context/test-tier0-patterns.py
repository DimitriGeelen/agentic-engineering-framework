#!/usr/bin/env python3
"""Test suite for Tier 0 destructive command patterns.
Run: python3 agents/context/test-tier0-patterns.py
"""
import re, sys


def strip_quotes(cmd):
    """Strip quoted string contents to avoid false positives."""
    cmd = re.sub(r"'[^']*'", "''", cmd)
    cmd = re.sub(r'"[^"]*"', '""', cmd)
    return cmd


PATTERNS = [
    (r'\bgit\s+push\b[^;|&]*(-f\b|--force\b|--force-with-lease\b)',
     'FORCE PUSH'),
    (r'\bgit\s+reset\s+--hard\b',
     'HARD RESET'),
    (r'\bgit\s+clean\b[^;|&]*-[a-zA-Z]*f',
     'GIT CLEAN'),
    (r'\bgit\s+(checkout|restore)\s+\.\s*(\s*$|[;&|])',
     'RESTORE ALL'),
    (r'\bgit\s+branch\s+[^;|&]*-D\b',
     'FORCE DELETE BRANCH'),
    (r'\brm\s+[^;|&]*-[a-zA-Z]*[rR][a-zA-Z]*[^;|&]*\s+/(\s|$|;|&|\*)',
     'RM ROOT'),
    (r'\brm\s+[^;|&]*-[a-zA-Z]*[rR][a-zA-Z]*[^;|&]*\s+(~|\\\$HOME)(\s|$|;|&|/)',
     'RM HOME'),
    (r'\brm\s+[^;|&]*-[a-zA-Z]*[rR][a-zA-Z]*[^;|&]*\s+\.\s*($|[;&|])',
     'RM CURRENT DIR'),
    (r'\brm\s+[^;|&]*-[a-zA-Z]*[rR][a-zA-Z]*[^;|&]*\s+\*(\s|$|;|&)',
     'RM WILDCARD'),
    (r'(?i)\bDROP\s+(TABLE|DATABASE|SCHEMA)\b',
     'SQL DROP'),
    (r'(?i)\bTRUNCATE\s+TABLE\b',
     'SQL TRUNCATE'),
    (r'\bdocker\s+system\s+prune\b',
     'DOCKER PRUNE'),
    (r'\bkubectl\s+delete\s+(namespace|ns)\s',
     'K8S NS DELETE'),
]

def check(cmd):
    stripped = strip_quotes(cmd)
    for pattern, desc in PATTERNS:
        if re.search(pattern, stripped):
            return desc
    return "SAFE"


# Commands that SHOULD be blocked
BLOCK_TESTS = [
    "git push --force origin main",
    "git push -f",
    "git push --force-with-lease",
    "git reset --hard HEAD~1",
    "git reset --hard",
    "git clean -fd",
    "git clean -xfd",
    "git branch -D feature",
    "rm -rf /",
    "rm -rf / ",
    "rm -rf /*",
    "rm -rf .",
    "rm -rf *",
    "rm -Rf / && ls",
    "DROP TABLE users",
    "drop database production",
    "TRUNCATE TABLE logs",
    "docker system prune",
    "docker system prune -af",
    "kubectl delete namespace production",
    "kubectl delete ns staging",
]

# Commands that SHOULD be allowed (safe)
ALLOW_TESTS = [
    "git status",
    "git push origin main",
    "git push",
    "git log --oneline -5",
    "git branch -d feature",
    "rm -f temp.txt",
    "rm -rf node_modules",
    "rm -rf /tmp/test-project",
    "rm -rf dist/",
    "rm temp.log",
    "ls -la",
    "docker ps",
    "kubectl get pods",
    "python3 test.py",
    "npm install",
    # False positive prevention — patterns inside quoted strings
    'git commit -m "Detects git push --force and rm -rf /"',
    "git commit -m 'Add DROP TABLE detection'",
    'echo "git reset --hard is dangerous"',
    "echo 'docker system prune removes everything'",
]

passed = 0
failed = 0

print("=== SHOULD BLOCK ===")
for cmd in BLOCK_TESTS:
    result = check(cmd)
    ok = result != "SAFE"
    if ok:
        passed += 1
        print(f"  [PASS] '{cmd}' -> {result}")
    else:
        failed += 1
        print(f"  [FAIL] '{cmd}' -> SAFE (should be blocked)")

print()
print("=== SHOULD ALLOW ===")
for cmd in ALLOW_TESTS:
    result = check(cmd)
    ok = result == "SAFE"
    if ok:
        passed += 1
        print(f"  [PASS] '{cmd}' -> SAFE")
    else:
        failed += 1
        print(f"  [FAIL] '{cmd}' -> {result} (should be SAFE)")

print()
print(f"Results: {passed} passed, {failed} failed")
sys.exit(0 if failed == 0 else 1)
