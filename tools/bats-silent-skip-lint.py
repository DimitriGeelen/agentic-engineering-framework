#!/usr/bin/env python3
"""T-3217 — make bats skips visible to the P-011 verification idiom.

THE BLIND SPOT. The repo-standard verification line is

    timeout 300 bats <suite> > /tmp/.out 2>&1 && ! grep -q "^not ok" /tmp/.out

A skipped test emits `ok N <name> # skip <reason>`. That is not a `not ok`, so
the gate passes, the report says ok, and nothing distinguishes a suite that ran
from one that declined to. Found while landing T-3213, whose root-guarded
`chmod 500` test skipped on every run that mattered — the suite runs as root —
so the acceptance criterion it covered was measured nowhere while reporting ok.

TWO MODES, BECAUSE THE QUESTION HAS A CHEAP HALF AND AN HONEST HALF.

  static (default)  Flags two guard shapes that cannot be anything but blind.
                    Cheap enough to run on every lint pass. Deliberately narrow.
  --tap FILE        Reports skips that ACTUALLY FIRED in a real run. Zero false
                    positives by construction: it reports facts, not shapes.

WHY THE STATIC MODE IS NARROW ON PURPOSE. Most skips in this corpus are correct
— an optional dependency is absent, a daemon is not running. A detector that
reddens those gets suppressed wholesale and then protects nothing, so the two
flagged shapes are the ones with no legitimate reading:

  UNCONDITIONAL   `skip` with no guard. The test never runs, anywhere, for
                  anyone. Whatever it was written to check is unchecked.
  STANDING        the guard tests a fixed property of the host — `id -u`,
                  $EUID, $CI, uname, $OSTYPE — rather than the presence of
                  something optional. Fixed means: true on every run of a given
                  deployment, or false on every run. It never varies with what
                  is installed, so on the configuration that matters it is a
                  permanent opt-out wearing a conditional's clothes. This is
                  the T-3213 shape exactly.

Everything else is left alone by the static mode and caught, when it matters, by
--tap: a dependency skip is only interesting when it fires, and then it is a
fact about this host rather than a defect in the test.

SCOPE LIMIT, STATED RATHER THAN IMPLIED. The static mode is a line-level scan.
It does not resolve variables, evaluate guards, or follow helper functions, so a
standing-configuration test hidden inside a helper is invisible to it. That is
why --tap exists and why the static list is two shapes and not ten: a scan that
guessed at the rest would produce exactly the noise that gets a lint disabled.
"""

import argparse
import os
import re
import sys

# A `skip` invoked as a command: at the start of a statement, or after a
# separator. Not `skip` inside a string, a test name, or a comment.
SKIP_CALL = re.compile(r'(?:^|\|\||&&|;|\bthen\b)\s*(skip\b.*)$')

# Guard shapes that vary with what is INSTALLED — the legitimate population.
DEPENDENCY = re.compile(
    r'command\s+-v|\bwhich\s|\bdocker\s+(info|ps)|bats_require|'
    r'\bimport\s+\w|-x\s|\bnc\s+-z|\bcurl\b|\bpgrep\b|\bflock\b|\bjq\b',
    re.I,
)

# Guard shapes that are FIXED for a given deployment. `id -u` does not become
# non-root because a package got installed.
STANDING = re.compile(r'\bid\s+-u\b|\$EUID|\bEUID\b|\$CI\b|\buname\b|\$OSTYPE|\bwhoami\b')


def strip_quotes(text):
    r"""Blank out quoted spans, tracking WHICH quote opened each one.

    A regex that removes quoted spans desyncs on an apostrophe inside a
    double-quoted string and mis-parses everything after it (peer
    832-Workflow-designer hit exactly this in their /tmp census). A character
    state machine that remembers the opening quote cannot: inside "..." an
    apostrophe is content.
    """
    out, quote, esc = [], None, False
    for ch in text:
        if esc:
            out.append(' ')
            esc = False
            continue
        if ch == '\\':
            out.append(' ' if quote else ch)
            esc = quote != "'"
            continue
        if quote:
            out.append(' ' if ch != quote else ch)
            if ch == quote:
                quote = None
            continue
        if ch in ('"', "'"):
            quote = ch
        out.append(ch)
    return ''.join(out)


HEREDOC_OPEN = re.compile(r"<<-?\s*[\"']?([A-Za-z_][A-Za-z0-9_]*)[\"']?")


def _heredoc_delim(line):
    """The delimiter this line opens a heredoc with, or None.

    Three guards, each added because it produced a real false positive
    (T-3217, measured on this corpus):
      * comments — `# ... $(... <<TAG ... TAG)` in a file header opened a
        heredoc that never closed and blinded the scanner for the whole file;
      * quoted arguments — `run has_write_pattern "cat <<EOF > f"` and
        `awk "/python3 << 'PYEOF'/"` are strings ABOUT heredocs, not heredocs;
      * unterminated delimiters — see the caller's lookahead.

    This is the shape peer 832 named at chat-arc @804: a character scan standing
    in for shell structure, so an argument that MENTIONS a thing is treated as
    an action on it. It is written down here because this detector reproduced
    the defect within an hour of that message.
    """
    if line.strip().startswith('#'):
        return None
    m = HEREDOC_OPEN.search(strip_quotes(line))
    return m.group(1) if m else None


def logical_lines(raw):
    r"""(lineno, text, in_heredoc) with backslash continuations joined.

    Continuations are joined and re-anchored to the line the GUARD is on, so
    `cmd || \` / `skip "..."` classifies against the guard rather than reading
    as unconditional.
    """
    out = []
    heredoc = None
    buf, buf_no = '', None
    for i, line in enumerate(raw, 1):
        if heredoc is not None:
            if line.strip() == heredoc:
                heredoc = None
            out.append((i, line, True))
            continue

        joined = (buf + ' ' + line.strip()) if buf else line
        if line.rstrip().endswith('\\'):
            if buf_no is None:
                buf_no = i
            buf = joined.rstrip()[:-1]
            continue
        out.append((buf_no or i, joined, False))
        buf, buf_no = '', None

        d = _heredoc_delim(line)
        # Only enter heredoc mode if the delimiter is actually closed later.
        # An unterminated one means we misread the line, and believing it would
        # blind the scanner for the rest of the file — silently, which is the
        # exact failure class this tool exists to report.
        if d and any(l.strip() == d for l in raw[i:]):
            heredoc = d
    if buf:
        out.append((buf_no, buf, False))
    return out


def scan(path):
    """Yield (lineno, classification, source line) for each skip call site."""
    try:
        raw = open(path, encoding='utf-8', errors='replace').read().splitlines()
    except OSError as e:
        print(f'{path}: cannot read: {e}', file=sys.stderr)
        return

    if_stack = []
    for lineno, line, in_heredoc in logical_lines(raw):
        stripped = line.strip()
        if in_heredoc or stripped.startswith('#'):
            continue

        for m in re.finditer(r'(?:^|;|\bthen\b)\s*(?:el)?if\s+(.*?)(?:;\s*then\b|$)',
                             line):
            if_stack.append(m.group(1))
        for _ in re.finditer(r'(?:^|;)\s*fi\b', line):
            if if_stack:
                if_stack.pop()

        m = SKIP_CALL.search(line)
        if not m:
            continue
        stmt = m.group(1)
        # `skip = ...` / `skip=...` is an assignment, not the bats verb.
        if re.match(r'skip\s*=', stmt):
            continue

        guard = line[: line.rindex(stmt)].strip()
        enclosing = ' '.join(if_stack)
        cond = guard + ' ' + enclosing
        if not guard and not enclosing:
            kind = 'UNCONDITIONAL'
        elif STANDING.search(cond):
            kind = 'STANDING'
        elif DEPENDENCY.search(cond):
            kind = 'DEPENDENCY'
        else:
            kind = 'OTHER'
        yield lineno, kind, stripped


FLAGGED = ('UNCONDITIONAL', 'STANDING')


def static_mode(paths, census):
    counts = {}
    rows = []
    for p in paths:
        for lineno, kind, src in scan(p):
            counts[kind] = counts.get(kind, 0) + 1
            rows.append((p, lineno, kind, src))

    bad = [r for r in rows if r[2] in FLAGGED]

    if census:
        for p, lineno, kind, src in rows:
            print(f'{kind:<14} {p}:{lineno}: {src}')
        print()
        print(f'total call sites: {len(rows)} across '
              f'{len({r[0] for r in rows})} file(s)')
        for k in ('DEPENDENCY', 'OTHER', 'STANDING', 'UNCONDITIONAL'):
            print(f'  {k:<14} {counts.get(k, 0)}')
        return 0

    if not rows:
        # A scan that examined nothing must not read as clean.
        print('bats-silent-skip-lint: no skip call sites found in the given '
              'paths — check the paths, this is not a pass', file=sys.stderr)
        return 2

    for p, lineno, kind, src in bad:
        why = ('never runs, for anyone' if kind == 'UNCONDITIONAL'
               else 'guard is fixed for a deployment, not a dependency probe')
        print(f'{p}:{lineno}: silent skip [{kind}] — {why}')
        print(f'    {src}')
    print()
    print(f'silent-skip lint: {len(bad)} silent, '
          f'{counts.get("DEPENDENCY", 0)} dependency, '
          f'{counts.get("OTHER", 0)} other, of {len(rows)} call site(s)')
    return 1 if bad else 0


TAP_SKIP = re.compile(r'^ok\s+\d+\s+(.*?)\s*#\s*skip\b\s*(.*)$', re.I)

# In TAP mode the only evidence available is the skip's REASON TEXT — the guard
# that produced it is not in the output. So this is a separate vocabulary from
# DEPENDENCY (which reads guard SHAPE), and it is deliberately generous: a
# missing dependency is the legitimate case, and mislabelling one as a defect is
# what gets the tool switched off. The cost of the generosity is that a lazily
# worded silent skip reads as a dependency here — which the static mode catches
# from the other side, on the guard.
REASON_DEPENDENCY = re.compile(
    r'not (available|installed|present|found|on PATH)|unavailable|unreachable|'
    r'no such|missing|too old|not running|\bdocker\b|\bdaemon\b',
    re.I,
)


def tap_mode(tap_path):
    stream = sys.stdin if tap_path == '-' else open(tap_path, encoding='utf-8',
                                                    errors='replace')
    fired, total_ok = [], 0
    for line in stream:
        if line.startswith('ok '):
            total_ok += 1
        m = TAP_SKIP.match(line.rstrip())
        if m:
            fired.append((m.group(1), m.group(2)))

    if total_ok == 0:
        print('bats-silent-skip-lint: TAP contained no `ok` lines — nothing was '
              'run, so this is not a pass', file=sys.stderr)
        return 2

    if not fired:
        print(f'silent-skip: 0 of {total_ok} passing test(s) were skipped')
        return 0

    dep = [f for f in fired if REASON_DEPENDENCY.search(f[1])]
    other = [f for f in fired if f not in dep]
    for name, reason in other:
        print(f'FIRED SKIP: {name}  — {reason or "(no reason given)"}')
    for name, reason in dep:
        print(f'  (dependency) {name} — {reason}')
    print()
    print(f'silent-skip: {len(fired)} of {total_ok} passing test(s) reported ok '
          f'WITHOUT RUNNING ({len(other)} non-dependency, {len(dep)} dependency)')
    return 1 if other else 0


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('paths', nargs='*', help='.bats files to scan')
    ap.add_argument('--tap', metavar='FILE',
                    help="TAP output from a real run ('-' for stdin)")
    ap.add_argument('--census', action='store_true',
                    help='print every call site with its classification')
    a = ap.parse_args()

    if a.tap:
        return tap_mode(a.tap)
    if not a.paths:
        ap.error('give .bats paths, or --tap FILE')
    files = []
    for p in a.paths:
        if os.path.isdir(p):
            for root, _, names in os.walk(p):
                files += [os.path.join(root, n) for n in sorted(names)
                          if n.endswith('.bats')]
        else:
            files.append(p)
    return static_mode(sorted(files), a.census)


if __name__ == '__main__':
    sys.exit(main())
