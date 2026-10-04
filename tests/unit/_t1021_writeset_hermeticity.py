"""Content-addressed hermeticity for a probe's declared write-set (T-552).

A probe that runs the real `fw audit` against this repository must not leave the tree dirtier
than it found it, or every later verdict in the session is ambiguous. `_t525` has asserted that
since T-527. What this module changes is the COMPARAND.

The first form (T-533) diffed `git status --porcelain` across the run, scoped to
`.context/audits` and excluding `cron/`. The scope was right and is kept. The comparand was
wrong in both directions, measured 2026-08-17:

  * **Blind.** Porcelain reports status LETTERS, not content. A file that is already dirty
    stays ` M` however many times it is rewritten. Measured: appending to
    `.context/audits/2026-08-16.yaml` changed its digest (f42311649879 -> 47b2499bdbf7) and
    left the porcelain output byte-identical. Both files the audit actually writes are in that
    state on every run after the first of the day, so the assertion was passing on silence.
    It also could not see a rewrite of an uncommitted HISTORICAL audit, which is the class the
    immutable-historical-record rule exists to protect.

  * **Red once a day.** The first audit of any day CREATES `.context/audits/<today>.yaml`.
    That adds a `??` line, so before != after and the leg failed — on a write the subject is
    supposed to perform. This is what turned the instrument sweep rc=1 on 2026-08-17 while
    `_t525` standalone was 8/8 minutes later (OBS-273).

So: compare digests, and judge them against an ALLOW-LIST of the paths the subject is supposed
to write. Both halves are load-bearing. Digests without an allow-list are red every morning;
an allow-list without digests is the blindness above wearing a new name.

The allow-list is derived from measurement, not from reading the audit's source: two
consecutive `fw audit` runs touched exactly `.context/audits/<today>.yaml` and
`.context/audits/discoveries/LATEST.yaml`, and nothing else among the write-set's 46 files.

Kept in its own module rather than inline in `_t525` so that
`tools/_t552-writeset-hermeticity-teeth.py` can drive the verdict over synthetic states
without paying a 61-second audit run to test a pure function — and because this is the second
repair to the same assertion, so the next probe that needs it should not copy it.
"""

import datetime
import hashlib
import os

CRON = os.path.join("cron", "")


def today_iso():
    """The date the daily audit report is named for, read at call time.

    Read twice by the caller — once before the run and once after — because a probe that takes
    a minute can straddle midnight, and on that run the audit legitimately writes TOMORROW's
    report. Allowing the union of the two observed dates covers it without permitting a report
    for an arbitrary date, which is what a looser rule like "any ISO date" would do.
    """
    return datetime.date.today().isoformat()


def snapshot(repo, subdir, exclude_subdir=CRON):
    """Map every file under `repo/subdir` to a digest of its bytes.

    Paths are returned repo-relative so violations read the way `git status` does. Files that
    vanish between the walk and the read are skipped rather than raising: the point of the
    snapshot is to compare two observations, and an unreadable path is reported by its absence
    from one side, which the verdict below already treats as a change.
    """
    base = os.path.join(repo, subdir)
    state = {}
    for dirpath, _dirnames, filenames in os.walk(base):
        rel_dir = os.path.relpath(dirpath, base)
        if rel_dir != "." and (rel_dir + os.sep).startswith(exclude_subdir):
            continue
        for name in filenames:
            path = os.path.join(dirpath, name)
            try:
                with open(path, "rb") as fh:
                    state[os.path.relpath(path, repo)] = hashlib.sha256(fh.read()).hexdigest()
            except OSError:
                continue
    return state


def declared_writes_observed(before, after, allowed):
    """The declared outputs that actually moved during the run.

    Hermeticity is a negative claim, and a negative claim is satisfied by silence (T-524): a
    run in which the subject wrote NOTHING has an empty violation list and looks identical to a
    run in which it behaved. `_t525` runs a real `fw audit`, whose report carries a timestamp
    and therefore always moves, so the caller can require this to be non-empty and turn "the
    audit did not run at all" from a green into a red.
    """
    return sorted(p for p in allowed if before.get(p) != after.get(p))


def write_set_violations(before, after, allowed):
    """Every change to the write-set that the subject was not entitled to make.

    `allowed` is the set of repo-relative paths the subject documents as its output. For those,
    a create or a modify is the subject doing its job; a DELETE is still a violation, because
    nothing about writing today's report entitles a run to remove a report.

    Returns a list of human-readable strings, empty when the run was hermetic. A list rather
    than a bool so the failure message can name the path — a hermeticity leg that says only
    "something changed" costs an investigation to localise, which is exactly what T-526 was.
    """
    violations = []
    for path in sorted(set(before) | set(after)):
        was, now = before.get(path), after.get(path)
        if was == now:
            continue
        if now is None:
            violations.append("DELETED  %s" % path)
        elif path in allowed:
            continue
        elif was is None:
            violations.append("CREATED  %s (not in the subject's declared write-set)" % path)
        else:
            violations.append("MODIFIED %s (%s -> %s)" % (path, was[:12], now[:12]))
    return violations
