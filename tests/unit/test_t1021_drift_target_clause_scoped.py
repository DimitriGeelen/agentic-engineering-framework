#!/usr/bin/env python3
"""T-1005 (re-applies T-639 on 1.7.740): the focus-drift target comes from a clause that IS the
command, never from a quoted fixture, an echo or a heredoc body. Behavioural probe of
_fw_extract_drift_target, extracted from check-active-task.sh (the hook runs top-level code).
Replaces _t639, whose mutation targets a function name 1.7.740 does not have."""
import os, subprocess, sys
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
# the framework repo itself (FRAMEWORK.md at root), else a vendored consumer
FW = ROOT if os.path.isfile(os.path.join(ROOT, "FRAMEWORK.md")) else os.path.join(ROOT, ".agentic-framework")
HOOK = os.path.join(FW, "agents/context/check-active-task.sh")
LIB = os.path.join(FW, "agents/context/lib/safe-commands.sh")
src = open(HOOK).read()
# pull the two functions out of the hook (it runs top-level code, so it cannot be sourced)
def fn(name):
    if name + '() {' not in src:  # helper absent (pre-fix tree): score what exists
        return ''
    a = src.index(name + '() {'); b = src.index('\n}\n', a) + 3
    return src[a:b]
lib_fns = fn('_fw_drift_target_in_clause') + fn('_fw_extract_drift_target')
cases = [
    ('fw task update T-1 --status issues', 'T-1'),
    ('/opt/p/.agentic-framework/bin/fw task update T-42 --status work-completed', 'T-42'),
    ('fw context add-learning "x" --task T-7', 'T-7'),
    ('git commit -m "T-9: real commit"', 'T-9'),
    ("git commit -m 'T-9: single quoted'", 'T-9'),
    ('git add -A && git commit -m "T-3: x"', 'T-3'),
    ('FW_SWITCH_FOCUS=1 git commit -m "T-4: x"', 'T-4'),
    ('cd /x && git commit -m "T-5: y"', 'T-5'),
    # T-1023: the commit form CLAUDE.md mandates. Quote-stripping fw clauses (37865ec7) hid its
    # -m message, so the drift gate stopped seeing which task a framework commit targets.
    ('fw git commit -m "T-12: x"', 'T-12'),
    ('.agentic-framework/bin/fw git commit -m "T-12: x"', 'T-12'),
    ('FW_SWITCH_FOCUS=1 .agentic-framework/bin/fw git commit -m "T-13: y"', 'T-13'),
    ('.agentic-framework/bin/fw note "said fw task update T-9 --status x"', ''),
    ('echo "the form is: git commit -m \\"T-1: msg\\""', ''),
    ('echo "next run fw task update T-1 --status issues"', ''),
    ('bash tools/probe.sh " git commit -m \\"T-1: fixture\\""', ''),
    ('grep -c " fw task update T-1" tools/t.sh', ''),
    ("python3 - <<'EOF'\ngit commit -m \"T-1: y\"\nEOF", ''),
    ('git commit -m "T-9: supersedes the approach in T-1: see notes"', 'T-9'),
]
fails = 0
for cmd, want in cases:
    script = 'source "%s"; %s _fw_extract_drift_target "$1"' % (LIB, lib_fns)
    got = subprocess.run(['bash', '-c', script, '_', cmd], capture_output=True, text=True).stdout.strip()
    ok = got == want
    fails += not ok
    print('%-4s %-60s got=%-5s want=%s' % ('PASS' if ok else 'FAIL', cmd.replace('\n', '\\n')[:60], got, want))
print('drift target: %d/%d' % (len(cases) - fails, len(cases)))
sys.exit(1 if fails else 0)
