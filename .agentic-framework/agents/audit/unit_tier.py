#!/usr/bin/env python3
"""T-4377: the tests/unit tier manifest (fast | slow | perf).

The unit suite is split into tiers so the pre-push ratchet grades a hermetic,
fast subset and the nightly run covers everything:

  fast  files whose MEASURED trailing median is <= the threshold and that no
        report in the window timed out. Graded by the pre-push ratchet. A skip
        in this tier is "not determined", like a timeout (unit-suite.sh).
  slow  everything else: unmeasured files, long files, and files that time out.
        Run by the nightly suite only.
  perf  wall-clock budget assertions (hook telemetry race, t1719 latency). They
        are red under load by construction, so they run serially, alone.

Membership is declared in tests/unit/tiers.yaml, a committed file. `select`
derives it from the dated reports; `check` refuses a manifest that leaves a
discovered file unassigned, assigns one twice, or names a file that is gone.
The runner (agents/audit/unit-suite.sh) reads it through `files` and refuses
to run when `check` fails.

Discovery matches unit-suite.sh: every *.bats, and for *.py the pytest rule
(test_*.py / *_test.py always, any other module that defines a test) with
conftest.py and _-prefixed helpers excluded.

Usage:
  unit_tier.py check  [--dir DIR]
  unit_tier.py files  --tier fast|slow|perf [--dir DIR]
  unit_tier.py select [--dir DIR] [--reports DIR] [--window N] [--max-median S] [--write]

Exit: 0 ok, 1 manifest invalid (check), 2 manifest missing or unreadable.
"""
import argparse
import glob
import os
import re
import statistics
import sys

import yaml

SCHEMA = "unit-tier-manifest-v1"
TIERS = ("fast", "slow", "perf")
MANIFEST = "tiers.yaml"
# Seeds for the perf tier on first `select`. Each is a wall-clock budget assertion
# (a latency or race bound), not a duration: the duration rule cannot place them.
PERF_SEED = [
    "hook_telemetry.bats",
    "hook_telemetry_race.bats",
    "t1719_index_one_post_write.bats",
    "t1719_post_write_index.bats",
]
DEFAULT_WINDOW = 7
DEFAULT_MAX_MEDIAN = 8  # 30 s measured 4,614 file-s (budget 2,400); 8 s measures 2,194
FAST_BUDGET_FILE_SECONDS = 2400

_PY_TEST_DEF = re.compile(r"^[ \t]*(async[ \t]+)?def[ \t]+test|^class[ \t]+Test", re.M)


def _framework_root():
    return os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))


def discover(suite_dir):
    """Basenames of every test file the runner would run in suite_dir, sorted."""
    names = []
    for f in sorted(glob.glob(os.path.join(suite_dir, "*.bats"))):
        names.append(os.path.basename(f))
    for f in sorted(glob.glob(os.path.join(suite_dir, "*.py"))):
        b = os.path.basename(f)
        if b == "conftest.py" or b.startswith("_"):
            continue
        if re.match(r"(test_.*|.*_test)\.py$", b):
            names.append(b)
            continue
        try:
            with open(f, errors="replace") as fh:
                if _PY_TEST_DEF.search(fh.read()):
                    names.append(b)
        except OSError:
            continue
    return names


def load_manifest(suite_dir):
    path = os.path.join(suite_dir, MANIFEST)
    if not os.path.isfile(path):
        return None
    with open(path) as fh:
        data = yaml.safe_load(fh) or {}
    return data


def assignments(data):
    """(basename -> [tiers it is listed under]) from a parsed manifest."""
    seen = {}
    for tier in TIERS:
        for name in (data.get(tier) or []):
            seen.setdefault(str(name), []).append(tier)
    return seen


def check(suite_dir):
    """Return (problems, counts). problems is empty when the manifest is valid."""
    data = load_manifest(suite_dir)
    if data is None:
        return ["no %s in %s" % (MANIFEST, suite_dir)], {}
    problems = []
    if data.get("schema") != SCHEMA:
        problems.append("schema must be %s (got %r)" % (SCHEMA, data.get("schema")))
    unknown = sorted(k for k in data if k not in TIERS + ("schema", "fast_max_median_seconds",
                                                          "fast_file_timeout_seconds", "rule"))
    for k in unknown:
        problems.append("unknown key %r" % k)
    seen = assignments(data)
    found = discover(suite_dir)
    for name in found:
        tiers = seen.get(name, [])
        if not tiers:
            problems.append("unassigned: %s" % name)
        elif len(tiers) > 1:
            problems.append("assigned to more than one tier: %s (%s)" % (name, ", ".join(tiers)))
    for name in sorted(seen):
        if name not in found:
            problems.append("stale: %s is listed but not discovered" % name)
    counts = {t: sum(1 for n in found if t in seen.get(n, [])) for t in TIERS}
    return problems, counts


def files_for(suite_dir, tier):
    """Discovered files (basenames) that the manifest assigns to tier."""
    problems, _ = check(suite_dir)
    if problems:
        raise SystemExit("unit_tier: manifest invalid: " + "; ".join(problems))
    seen = assignments(load_manifest(suite_dir))
    return [n for n in discover(suite_dir) if tier in seen.get(n, [])]


def _v2_reports(reports_dir):
    out = []
    for path in sorted(glob.glob(os.path.join(reports_dir, "????-??-??.yaml"))):
        try:
            with open(path) as fh:
                d = yaml.safe_load(fh) or {}
        except (OSError, yaml.YAMLError):
            continue
        if d.get("schema") == "unit-suite-report-v2":
            out.append((os.path.basename(path), d))
    return out


def measure(reports_dir, window):
    """name -> (median seconds or None, timed_out_in_window). Trailing window of
    schema-v2 dated reports; a file absent from every report has no median."""
    recent = _v2_reports(reports_dir)[-window:]
    samples, timed = {}, set()
    for _, d in recent:
        for leg in ("bats", "pytest"):
            lg = (d.get("legs") or {}).get(leg) or {}
            for name, secs in (lg.get("file_durations") or {}).items():
                samples.setdefault(name, []).append(float(secs))
            for t in (lg.get("files_timed_out") or []):
                timed.add(str(t).split(" (")[0])
    stats = {}
    for name, vals in samples.items():
        stats[name] = (statistics.median(vals), name in timed)
    for name in timed:
        stats.setdefault(name, (None, True))
    return stats, len(recent)


def select(suite_dir, reports_dir, window, max_median):
    prior = load_manifest(suite_dir)
    perf = list((prior or {}).get("perf") or PERF_SEED)
    stats, used = measure(reports_dir, window)
    fast, slow, rows = [], [], []
    for name in discover(suite_dir):
        median, timed_out = stats.get(name, (None, False))
        if name in perf:
            tier, why = "perf", "declared wall-clock budget"
        elif median is None:
            tier, why = "slow", "unmeasured"
        elif timed_out:
            tier, why = "slow", "timed out in window"
        elif median <= max_median:
            tier, why = "fast", "median %.1fs" % median
        else:
            tier, why = "slow", "median %.1fs" % median
        if tier == "fast":
            fast.append(name)
        elif tier == "slow":
            slow.append(name)
        rows.append((tier, name, why))
    fast_total = sum(stats[n][0] for n in fast)
    manifest = {
        "schema": SCHEMA,
        "rule": ("fast: trailing median <= fast_max_median_seconds and never timed out in the window; "
                 "perf: declared wall-clock budget; slow: everything else (unmeasured included)"),
        "fast_max_median_seconds": max_median,
        "fast_file_timeout_seconds": 120,
        "fast": fast,
        "slow": slow,
        "perf": perf,
    }
    return manifest, rows, fast_total, used


def main(argv):
    ap = argparse.ArgumentParser(description="tests/unit tier manifest (T-4377)")
    sub = ap.add_subparsers(dest="cmd", required=True)
    default_dir = os.path.join(_framework_root(), "tests", "unit")
    default_reports = os.path.join(os.environ.get("PROJECT_ROOT") or _framework_root(),
                                   ".context", "audits", "unit-suite")
    p_check = sub.add_parser("check")
    p_check.add_argument("--dir", default=default_dir)
    p_files = sub.add_parser("files")
    p_files.add_argument("--dir", default=default_dir)
    p_files.add_argument("--tier", required=True, choices=TIERS)
    p_sel = sub.add_parser("select")
    p_sel.add_argument("--dir", default=default_dir)
    p_sel.add_argument("--reports", default=default_reports)
    p_sel.add_argument("--window", type=int, default=DEFAULT_WINDOW)
    p_sel.add_argument("--max-median", type=float, default=DEFAULT_MAX_MEDIAN)
    p_sel.add_argument("--write", action="store_true")
    args = ap.parse_args(argv)

    if args.cmd == "check":
        problems, counts = check(args.dir)
        if problems:
            for p in problems:
                print("FAIL %s" % p)
            return 1
        print("ok: %s" % "  ".join("%s=%d" % (t, counts[t]) for t in TIERS))
        return 0
    if args.cmd == "files":
        if load_manifest(args.dir) is None:
            print("unit_tier: no %s in %s" % (MANIFEST, args.dir), file=sys.stderr)
            return 2
        for n in files_for(args.dir, args.tier):
            print(os.path.join(args.dir, n))
        return 0
    manifest, rows, fast_total, used = select(args.dir, args.reports, args.window,
                                              args.max_median)
    for tier, name, why in sorted(rows, key=lambda r: (r[0], r[1])):
        print("%-5s %-44s %s" % (tier, name, why))
    print("selected: fast=%d slow=%d perf=%d; reports used=%d; fast median sum=%.0f s "
          "(budget %d s)" % (len(manifest["fast"]), len(manifest["slow"]), len(manifest["perf"]),
                             used, fast_total, FAST_BUDGET_FILE_SECONDS))
    if args.write:
        path = os.path.join(args.dir, MANIFEST)
        header = ("# tests/unit/tiers.yaml — T-4377. Generated by `unit_tier.py select --write`\n"
                  "# from the dated unit-suite reports; checked by `unit_tier.py check`.\n"
                  "# Do not hand-edit tier membership: re-measure and regenerate.\n")
        with open(path, "w") as fh:
            fh.write(header)
            yaml.safe_dump(manifest, fh, sort_keys=False, default_flow_style=False)
        print("wrote %s" % path)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
