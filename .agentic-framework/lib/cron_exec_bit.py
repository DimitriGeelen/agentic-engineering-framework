#!/usr/bin/env python3
"""T-3380: scripts a deployed crontab invokes DIRECTLY must be executable.

Complement of ``lib/exec-bit-drift.sh`` (T-3317). That check compares on-disk
mode against the git index, so its candidate set is exactly "files the index
marks 100755". A file committed 100644 is outside that set entirely — so a cron
line that execs it dies "Permission denied" on every single run while the parity
check prints a confident PASS over the files it *can* see.

Origin: ``agents/monitor/liveness-check.sh`` was committed 100644. Cron invoked
it every minute for 34 days — 13,680 logged failures — and produced no output
the entire time. The one rail that sampled Watchtower liveness was itself dead,
which is why a 5h35m Watchtower outage went unreported. Same family as T-3105
(the audit had no check that it can itself run) and T-3302 (a green line
answering a narrower question than the reader is asking).

Only DIRECT invocation counts. ``python3 foo.py`` and ``bash foo.sh`` run fine
without the bit, and reporting them is a false positive — measured: a first pass
that ignored the interpreter reported 50 broken paths of which exactly 1 was
real. Relative paths are skipped too: a bare ``foo.sh`` after a shell variable
is a fragment, not a path this can resolve.

Usage:  cron_exec_bit.py [--count] <crontab-file> [<crontab-file> ...]
Prints one ``<reason>\\t<path>`` line per broken invocation; empty output means
clean. With ``--count``, prints instead how many directly-invoked scripts were
examined, so a PASS can say what it covered rather than just "clean".
Always exits 0 — the caller decides severity.
"""
import os
import re
import shlex
import sys

# Basenames that mean "the next token is a script argument, not a command".
INTERPRETERS = {
    "bash", "sh", "dash", "zsh", "ksh",
    "python", "python2", "python3", "env",
    "perl", "ruby", "node", "timeout", "nice", "ionice", "flock",
}

# Splits a cron command into independently-executed segments.
_SEGMENT_RE = re.compile(r"&&|\|\||;|\|")
_SCRIPT_RE = re.compile(r"\.(sh|py|pl|rb)$")
# A leading environment assignment, e.g. `FOO=1 /path/script.sh`.
_ASSIGN_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=")


def _command_of(line):
    """Return the command portion of an /etc/cron.d line, or None.

    /etc/cron.d syntax carries a USER field: either
        m h dom mon dow USER cmd...
    or
        @reboot USER cmd...
    """
    stripped = line.strip()
    if not stripped or stripped.startswith("#"):
        return None
    if stripped.startswith("@"):
        parts = stripped.split(None, 2)
        return parts[2] if len(parts) > 2 else None
    parts = stripped.split(None, 6)
    return parts[6] if len(parts) > 6 else None


def direct_invocations(cron_files):
    """Yield each distinct absolute script path a crontab execs directly."""
    seen = set()
    for cron_file in cron_files:
        try:
            with open(cron_file, "r", encoding="utf-8", errors="replace") as fh:
                lines = fh.read().splitlines()
        except OSError:
            continue
        for line in lines:
            command = _command_of(line)
            if not command:
                continue
            for segment in _SEGMENT_RE.split(command):
                segment = segment.strip()
                if not segment:
                    continue
                try:
                    tokens = shlex.split(segment)
                except ValueError:
                    tokens = segment.split()
                # Strip leading `VAR=value` assignment prefixes. Cron lines
                # routinely carry them (`LIVENESS_BOOT_MARKER=1 /path/x.sh`),
                # and without this the assignment IS token[0] and the script is
                # never examined — which would have missed the @reboot leg of
                # the very incident this check exists for. Caught by test 7.
                while tokens and _ASSIGN_RE.match(tokens[0]):
                    tokens.pop(0)
                if not tokens:
                    continue
                candidate = tokens[0]
                # An interpreter in front means the exec bit is irrelevant.
                if os.path.basename(candidate) in INTERPRETERS:
                    continue
                # Only absolute paths are resolvable from here; a bare name
                # following a shell variable is a fragment, not a path.
                if not candidate.startswith("/"):
                    continue
                if not _SCRIPT_RE.search(candidate):
                    continue
                if candidate in seen:
                    continue
                seen.add(candidate)
                yield candidate


def broken_invocations(cron_files):
    """Yield (reason, path) for directly-invoked scripts that cannot run."""
    for path in direct_invocations(cron_files):
        if not os.path.exists(path):
            yield ("MISSING", path)
        elif not os.access(path, os.X_OK):
            yield ("NOEXEC", path)


def main(argv):
    args = argv[1:]
    if args and args[0] == "--count":
        print(sum(1 for _ in direct_invocations(args[1:])))
        return 0
    for reason, path in broken_invocations(args):
        print(f"{reason}\t{path}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
