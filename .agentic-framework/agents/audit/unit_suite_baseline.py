#!/usr/bin/env python3
"""T-3621 (OBS-587): the unit-suite red BASELINE behind the pre-push ratchet.

The nightly runner (agents/audit/unit-suite.sh) writes
.context/audits/unit-suite/LATEST.yaml. agents/audit/audit.sh
(check_unit_suite_report) reads it. Under the pre-push scope
(`audit.sh --section structure`) a red listed here, and not yet expired, grades
WARN instead of FAIL. Every other scope FAILs on every red. This file only
manages the list.

The list may SHRINK without the operator and may not GROW without them:
  init        write the first baseline from a report. Refuses if a baseline
              already exists on disk or in git HEAD, so deleting the file and
              re-running init cannot grow the list.
  regenerate  drop entries the report shows GREEN, meaning the file finished
              and the test is not in the failed list. Never adds an entry and
              never extends an expiry. An entry whose file did not finish
              (per-file timeout, never reached) is kept: unknown is not green.
  add         add an entry, or re-arm an existing entry's expiry. Refused
              unless --i-am-human is given.
  show        print a summary: entries, triaged versus untriaged, expired.

What this does NOT claim: the baseline is a committed file that any same-user
process can hand-edit. The verbs make the sanctioned path shrink-only. git
history is what shows a hand-edit.
"""
import argparse
import datetime
import glob
import os
import re
import subprocess
import sys
from typing import NoReturn

import yaml

SCHEMA = "unit-suite-baseline-v1"
DEFAULT_DAYS = 14
LEGS = ("bats", "pytest")


def _today():
    return datetime.datetime.now(datetime.timezone.utc).date()


def _die(msg, rc=2) -> NoReturn:
    print("unit-suite-baseline: " + msg, file=sys.stderr)
    sys.exit(rc)


def _load_report(path):
    try:
        d = yaml.safe_load(open(path))
    except Exception as e:  # noqa: BLE001
        _die("report unreadable (%s): %s" % (path, e))
    if not isinstance(d, dict) or not isinstance(d.get("legs"), dict):
        _die("report has no legs: %s" % path)
    return d


def _load_baseline(path):
    try:
        d = yaml.safe_load(open(path))
    except Exception as e:  # noqa: BLE001
        _die("baseline unreadable (%s): %s" % (path, e))
    if not isinstance(d, dict) or not isinstance(d.get("entries"), list):
        _die("baseline has no entries list: %s" % path)
    return d


def _write(path, data):
    tmp = path + ".tmp.%d" % os.getpid()
    with open(tmp, "w") as f:
        f.write("# T-3621 unit-suite red baseline. Managed by agents/audit/unit_suite_baseline.py.\n"
                "# Shrinks via `regenerate`. Growing it needs `add --i-am-human` (operator).\n")
        yaml.safe_dump(data, f, sort_keys=False, allow_unicode=True, width=100)
    os.replace(tmp, path)


def _file_of(leg, name):
    """'x.bats: test' → 'x.bats'; 'tests/unit/x.py::test' → 'x.py'."""
    if leg == "pytest":
        return os.path.basename(name.split("::", 1)[0])
    return name.split(":", 1)[0].strip()


def _stem(f):
    f = os.path.basename(f.strip().strip("`"))
    for ext in (".bats", ".py"):
        if f.endswith(ext):
            f = f[: -len(ext)]
    return f


def _reds(report):
    out = []
    for leg in LEGS:
        for n in (report["legs"].get(leg) or {}).get("failed") or []:
            out.append((leg, str(n)))
    return out


def _unfinished_files(report):
    """Files whose verdict is unknown: per-file timeout or never reached."""
    s = set()
    for leg in LEGS:
        l = report["legs"].get(leg) or {}
        for key in ("files_timed_out", "files_not_run_names"):
            for f in l.get(key) or []:
                s.add((leg, os.path.basename(str(f))))
    return s


def _leg_finished(report, leg):
    """A leg with a run-level error, or a v1 report with no per-file
    completion, cannot prove anything green."""
    l = report["legs"].get(leg) or {}
    if l.get("error") or "files_completed" not in l:
        return False
    if report.get("interrupted"):
        return False
    return True


def _triage_owners(triage_dir):
    """Map a test-file stem to its owning task, read from the verdict tables in
    docs/reports/*-triage.md. The owner is the first task id in the row's
    Action column (the bug or tracking task). With none, the owner is the
    triage task itself (the file named T-NNNN-triage.md)."""
    owners = {}
    for path in sorted(glob.glob(os.path.join(triage_dir, "T-*-triage.md"))):
        m = re.match(r"(T-\d+)", os.path.basename(path))
        own_task = m.group(1) if m else None
        for line in open(path, encoding="utf-8", errors="replace"):
            if not line.startswith("|"):
                continue
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            if len(cells) < 5 or cells[0] in ("File", "") or set(cells[0]) <= set("-: "):
                continue
            action = cells[-1]
            ids = [t for t in re.findall(r"T-\d+", action) if t != own_task]
            owners.setdefault(_stem(cells[0]), ids[0] if ids else own_task)
    return owners


def _in_git_head(path):
    try:
        root = subprocess.run(["git", "-C", os.path.dirname(os.path.abspath(path)),
                               "rev-parse", "--show-toplevel"],
                              capture_output=True, text=True, timeout=10)
        if root.returncode != 0:
            return False
        rel = os.path.relpath(os.path.abspath(path), root.stdout.strip())
        r = subprocess.run(["git", "-C", root.stdout.strip(), "cat-file", "-e", "HEAD:" + rel],
                           capture_output=True, timeout=10)
        return r.returncode == 0
    except Exception:  # noqa: BLE001
        return False


def cmd_init(a):
    if os.path.exists(a.baseline) or _in_git_head(a.baseline):
        _die("a baseline already exists (%s). init writes the FIRST baseline only; "
             "use `regenerate` to shrink it or `add --i-am-human` to grow it." % a.baseline)
    report = _load_report(a.report)
    owners = _triage_owners(a.triage_dir) if os.path.isdir(a.triage_dir) else {}
    today = _today()
    exp = (today + datetime.timedelta(days=a.days)).isoformat()
    entries = []
    for leg, name in _reds(report):
        f = _file_of(leg, name)
        entries.append({"leg": leg, "name": name, "file": f,
                        "owner": owners.get(_stem(f)) or "untriaged",
                        "added": today.isoformat(), "expires": exp})
    data = {"schema": SCHEMA, "task": "T-3621", "created": today.isoformat(),
            "default_expiry_days": a.days,
            "source_report": {"path": a.report, "finished": str(report.get("finished"))},
            "entries": entries}
    _write(a.baseline, data)
    tri = sum(1 for e in entries if e["owner"] != "untriaged")
    print("baseline written: %s — %d entries (%d triaged, %d untriaged), expires %s"
          % (a.baseline, len(entries), tri, len(entries) - tri, exp))


def cmd_regenerate(a):
    base = _load_baseline(a.baseline)
    report = _load_report(a.report)
    reds = set(_reds(report))
    unfinished = _unfinished_files(report)
    keep, dropped = [], []
    for e in base["entries"]:
        leg, name = e.get("leg"), str(e.get("name"))
        green = ((leg, name) not in reds
                 and _leg_finished(report, leg)
                 and (leg, os.path.basename(str(e.get("file") or _file_of(leg, name)))) not in unfinished)
        (dropped if green else keep).append(e)
    base["entries"] = keep
    base["last_regenerated"] = {"at": _today().isoformat(), "report": a.report,
                                "finished": str(report.get("finished")),
                                "dropped": len(dropped)}
    _write(a.baseline, base)
    print("regenerate: dropped %d green entr%s, kept %d" %
          (len(dropped), "y" if len(dropped) == 1 else "ies", len(keep)))
    for e in dropped:
        print("  dropped: %s: %s" % (e.get("leg"), e.get("name")))


def cmd_add(a):
    if not a.i_am_human:
        _die("adding to the baseline is the operator's call: re-run with --i-am-human. "
             "An agent may only shrink it (`regenerate`). A new red is new breakage — fix it "
             "or file a task (one bug = one task).")
    base = _load_baseline(a.baseline)
    names = list(a.name or [])
    if a.all_new:
        known = {(e.get("leg"), str(e.get("name"))) for e in base["entries"]}
        names += [n for (leg, n) in _reds(_load_report(a.report)) if leg == a.leg and (leg, n) not in known]
    if not names:
        _die("nothing to add: give --name or --all-new")
    exp = (_today() + datetime.timedelta(days=a.days)).isoformat()
    for n in names:
        cur = [e for e in base["entries"] if e.get("leg") == a.leg and str(e.get("name")) == n]
        if cur:
            cur[0]["expires"] = exp
            if a.owner:
                cur[0]["owner"] = a.owner
            cur[0]["added_by"] = "human"
        else:
            base["entries"].append({"leg": a.leg, "name": n, "file": _file_of(a.leg, n),
                                    "owner": a.owner or "untriaged",
                                    "added": _today().isoformat(), "expires": exp,
                                    "added_by": "human"})
    _write(a.baseline, base)
    print("add: %d entr%s, expires %s" % (len(names), "y" if len(names) == 1 else "ies", exp))


def cmd_show(a):
    base = _load_baseline(a.baseline)
    es = base["entries"]
    today = _today()
    tri = sum(1 for e in es if e.get("owner") != "untriaged")
    exp = sum(1 for e in es if datetime.date.fromisoformat(str(e.get("expires"))) < today)
    print("entries=%d triaged=%d untriaged=%d expired=%d" % (len(es), tri, len(es) - tri, exp))


def main():
    root = os.environ.get("PROJECT_ROOT") or os.getcwd()
    ctx = os.path.join(root, ".context", "audits", "unit-suite")
    p = argparse.ArgumentParser(description=(__doc__ or "").split("\n")[0])
    sub = p.add_subparsers(dest="cmd", required=True)

    def common(sp, report=True):
        sp.add_argument("--baseline", default=os.environ.get("FW_UNIT_SUITE_BASELINE")
                        or os.path.join(ctx, "baseline.yaml"))
        if report:
            sp.add_argument("--report", default=os.environ.get("FW_UNIT_SUITE_REPORT")
                            or os.path.join(ctx, "LATEST.yaml"))

    sp = sub.add_parser("init")
    common(sp)
    sp.add_argument("--triage-dir", default=os.path.join(root, "docs", "reports"))
    sp.add_argument("--days", type=int, default=DEFAULT_DAYS)
    sp.set_defaults(fn=cmd_init)

    sp = sub.add_parser("regenerate")
    common(sp)
    sp.set_defaults(fn=cmd_regenerate)

    sp = sub.add_parser("add")
    common(sp)
    sp.add_argument("--i-am-human", action="store_true")
    sp.add_argument("--leg", choices=LEGS, default="bats")
    sp.add_argument("--name", action="append")
    sp.add_argument("--all-new", action="store_true",
                    help="add every red in --report that is not yet baselined")
    sp.add_argument("--owner")
    sp.add_argument("--days", type=int, default=DEFAULT_DAYS)
    sp.set_defaults(fn=cmd_add)

    sp = sub.add_parser("show")
    common(sp, report=False)
    sp.set_defaults(fn=cmd_show)

    a = p.parse_args()
    a.fn(a)


if __name__ == "__main__":
    main()
