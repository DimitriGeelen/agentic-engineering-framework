"""Hook-set extraction and comparison — ONE definition, every caller (T-3112/T-3113).

The question "does this replica carry the hooks the authority carries?" is asked
of three different subjects by three different callers:

  1. `fw doctor` Consumer Projects   — 31 vendored consumers          (T-616)
  2. `fw doctor` Worktrees           — linked worktrees               (T-3112, R7 L3)
  3. `fw upgrade` step 5 hook-gap    — the target's own settings.json (T-2912)

Until T-3113 each caller carried its own inline copy of `extract_hooks`. T-3112
consolidated callers 1 and 2 into lib/hook-parity.sh and asserted "bin/fw holds
zero copies" — which was true, and still left a third copy sitting in
lib/upgrade.sh that the assertion did not look at. That is the drift class the
consolidation exists to prevent, caught one leg later by an AC that happened to
grep a second file.

So the predicate lives here, in python, and every caller imports it — the same
shape as lib/hook_portability.py, whose call sites already carry the note
"one module, two call sites (L-399: a contract shipped on one side only is how
this class recurs)".

TWO PARSE POLICIES, DELIBERATELY BOTH:

  strict=False (default) — a file that will not parse yields an EMPTY set.
      Caller 3 wants this. In `fw upgrade`, an unparseable consumer settings.json
      makes `missing = authority - {}` = everything, which sets needs_regen and
      regenerates the file. Regenerating a broken settings.json is the correct
      response, and it is the behaviour that shipped in T-2912.

  strict=True — a file that will not parse yields None.
      Callers 1 and 2 want this. A doctor check must never render `missing 34:`
      for a file it simply failed to read; that is a diagnosis, not a
      measurement. None becomes the distinct verdict `parse-error`.

Collapsing the two would silently change one caller's behaviour, which is why
the flag exists rather than a single "obvious" policy.
"""

import json
import sys


def extract_hooks(path, strict=False):
    """Return the set of (event, hook_name) pairs declared in a settings.json.

    A hook's NAME is the `fw hook <name>` argument when present, else the last
    path segment of the command. That normalisation is what lets an authority
    and a replica be compared across different absolute checkout paths — the
    same hook invoked as `$CLAUDE_PROJECT_DIR/bin/fw hook check-active-task` and
    as `/opt/x/.agentic-framework/bin/fw hook check-active-task` is one hook.

    Returns None on parse failure when strict=True, else an empty set.
    """
    hooks = set()
    try:
        with open(path) as f:
            data = json.load(f)
        for event, entries in (data.get('hooks') or {}).items():
            for entry in entries:
                for hook in entry.get('hooks', []):
                    cmd = hook.get('command', '')
                    if 'fw hook' in cmd:
                        name = cmd.split('fw hook ')[-1].strip()
                    else:
                        name = cmd.strip().split('/')[-1]
                    hooks.add((event, name))
    except (json.JSONDecodeError, FileNotFoundError, AttributeError, TypeError):
        if strict:
            return None
    return hooks


def delta(authority_path, replica_path):
    """One-line verdict comparing a replica against an authority.

      ok N/M                    replica carries every authority hook
      missing K: name1, name2   replica lacks K of them
      parse-error               a file exists but did not parse

    The comparison is ONE-DIRECTIONAL: authority minus replica. A replica
    carrying EXTRA hooks is not drift — a consumer or worktree may legitimately
    add project-local hooks, and flagging those makes the check noisy enough to
    be ignored, which is how a check stops being read. Under-enforcement is the
    failure mode with teeth.
    """
    auth = extract_hooks(authority_path, strict=True)
    repl = extract_hooks(replica_path, strict=True)
    if auth is None or repl is None:
        return 'parse-error'
    missing = auth - repl
    if missing:
        return 'missing %d: %s' % (len(missing), ', '.join(n for _, n in sorted(missing)))
    return 'ok %d/%d' % (len(repl), len(auth))


if __name__ == '__main__':
    # Usage: hook_parity.py delta <authority> <replica>
    if len(sys.argv) == 4 and sys.argv[1] == 'delta':
        print(delta(sys.argv[2], sys.argv[3]))
    else:
        sys.stderr.write('usage: hook_parity.py delta <authority> <replica>\n')
        sys.exit(64)
