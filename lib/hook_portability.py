#!/usr/bin/env python3
"""Single source of truth for "is this hook command host-portable?" (T-2709).

Origin: T-2704 RCA (docs/reports/T-2704-hook-path-portability.md).

A framework hook command in .claude/settings.json is HOST-PORTABLE iff it reaches
`fw` through the ``${CLAUDE_PROJECT_DIR}`` placeholder, which Claude Code expands to
the project root before the hook runs. That is absolute *after expansion*, so it keeps
T-1364/T-1504's CWD-drift protection while resolving on any host.

A command that hardcodes a literal absolute filesystem path
(``/opt/999-Agentic-Engineering-Framework/bin/fw hook X``) is the defect this module
detects: it resolves only on the host that generated it, and fails toward *no
enforcement*, silently, everywhere else.

WHY THIS FILE EXISTS AT ALL (L-399 producer/consumer parity):
    Two independent surfaces need this predicate —
      * ``bin/fw`` doctor Check 6  — must stop printing "all portable" when it is not
      * ``lib/upgrade.sh`` step 5  — must FIRE the regenerate trigger on a consumer
        still carrying the old absolute form, otherwise the fixed generator is never
        invoked on any existing consumer and the fix reaches nobody (T-2704 §5.1)
    Both previously carried their own copy of a *different, older* predicate
    (``'/agents/context/' in cmd or 'PROJECT_ROOT=' in cmd`` — the pre-T-496 defect
    shape) and were structurally blind to the current one. Shipping the new predicate
    into one site only is exactly how this class recurs, so it lives here once and both
    call sites consume this module's output.

CLI:
    python3 lib/hook_portability.py <settings.json>
        -> prints "<fw_total>|<nonportable>|<foreign>|<detail>" on stdout, exit 0.
           Unreadable / malformed input yields "0|0|0|<reason>" (fail-quiet: neither
           call site should hard-error on a consumer's broken settings.json — doctor
           and upgrade each have their own reporting for that).
"""

import json
import re
import sys

# Framework hook = dispatches through `fw hook <name>`. Anything else is a
# project-local registration (`fw hook-enable --script /abs/path.sh`) which is
# legitimately absolute and MUST NOT be flagged — a framework invariant must not
# block a consumer from wiring its own hooks.
_FW_HOOK_RE = re.compile(r"(^|/)fw\s+hook\s")

# Accept both spellings, with an optional leading quote: shell form may legitimately
# be written "$CLAUDE_PROJECT_DIR"/bin/fw.
_PLACEHOLDER_RE = re.compile(r'^"?\$\{?CLAUDE_PROJECT_DIR\}?')


def hook_exe(cmd):
    """First token that is not an ENV=value prefix — i.e. the fw path."""
    for tok in cmd.split():
        if "=" not in tok.split("/")[0]:
            return tok
    return ""


def is_nonportable(cmd):
    """True iff `cmd` is a framework hook whose fw path is a literal absolute path.

    Bare-relative commands are NOT reported here. They are a different defect
    (structurally broken from any subdir) already detected by lib/upgrade.sh's
    T-1627 check; conflating the two would blur two distinct remediations.
    """
    cmd = (cmd or "").strip()
    if not cmd or not _FW_HOOK_RE.search(cmd):
        return False
    exe = hook_exe(cmd)
    if _PLACEHOLDER_RE.match(exe):
        return False
    return exe.startswith("/")


def scan(path):
    """-> (fw_total, nonportable_list, foreign_count) over a settings.json."""
    with open(path) as fh:
        data = json.load(fh)

    fw_total = 0
    foreign = 0
    offenders = []

    for event, entries in (data.get("hooks") or {}).items():
        for entry in entries or []:
            for hook in entry.get("hooks") or []:
                cmd = (hook.get("command") or "").strip()
                if not cmd:
                    continue
                if not _FW_HOOK_RE.search(cmd):
                    foreign += 1
                    continue
                fw_total += 1
                if is_nonportable(cmd):
                    offenders.append("{}: {}".format(event, cmd))

    return fw_total, offenders, foreign


def main(argv):
    if len(argv) != 2:
        print("0|0|0|usage: hook_portability.py <settings.json>")
        return 0
    try:
        fw_total, offenders, foreign = scan(argv[1])
    except FileNotFoundError:
        print("0|0|0|settings.json not found")
        return 0
    except (json.JSONDecodeError, OSError, TypeError, AttributeError) as exc:
        print("0|0|0|unreadable: {}".format(exc))
        return 0
    print("{}|{}|{}|{}".format(fw_total, len(offenders), foreign, " ;; ".join(offenders)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
