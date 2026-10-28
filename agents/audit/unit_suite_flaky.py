#!/usr/bin/env python3
"""T-4875 (T-4866): retry a first-time red file once before the ratchet blocks.

The nightly runner (agents/audit/unit-suite.sh) calls this twice from _finish:

  plan    after the run: which files hold a NEW red, meaning a red not listed
          in the ratchet baseline (.context/audits/unit-suite/baseline.yaml).
          Prints one "<leg>\t<path>" line per file to retry. Prints nothing,
          and records why, when there is no readable baseline (the audit fails
          closed on every red then, so a retry could not change the grade), or
          when more files hold a NEW red than the cap allows (many new reds at
          once read as real breakage, not a flake).
  record  after the retries: a file whose retry finished and passed is a
          SUSPECTED FLAKE. Its first-run reds go to <results>/flaky.json (the
          report's `suspected_flaky` and `flake_retry`) and one row per red is
          appended to the flake log (flakes.jsonl beside the report). A retry
          that fails, times out or skips (fast tier: not determined) downgrades
          nothing.

The first run's reds stay in the report's `failed` list either way: a flake is
a red. Only the pre-push grade reads `suspected_flaky` (WARN instead of FAIL);
every other audit scope FAILs on it, so it is investigated, never dropped.
"""
import argparse
import datetime
import glob
import json
import os
import re
import shutil
import sys

import yaml

LEGS = ("bats", "pytest")


def _reds_of(leg, name, out, st, rc):
    """The red names one file contributes to the report's `failed` list.
    Mirrors _leg() in unit-suite.sh _finish, so names match the baseline."""
    reds = []
    if leg == "bats":
        reds = ["%s: %s" % (name, re.sub(r"^not ok \d+ ", "", l).strip())
                for l in out.splitlines() if l.startswith("not ok ")]
    else:
        reds = [l.split(" - ")[0].split(None, 1)[1].strip()
                for l in out.splitlines()
                if l.startswith(("FAILED ", "ERROR ")) and len(l.split(None, 1)) > 1]
    if st == "done" and rc != 0 and not reds:
        if leg == "pytest" and rc == 5:
            reds.append("%s: collected no tests (pytest exit 5)" % name)
        else:
            reds.append("%s: exited rc=%d with no failing test recorded" % (name, rc))
    return reds


def _meta(path):
    try:
        st, rc, secs = (open(path).read().split() + ["", "0", "0"])[:3]
        return st, int(rc), int(secs)
    except (OSError, ValueError):
        return "", 0, 0


def _first_run_reds(results):
    """[(leg, file basename, [red names])] for every file with a red."""
    out = []
    for leg in LEGS:
        for meta in sorted(glob.glob(os.path.join(results, leg, "*.meta"))):
            name = os.path.basename(meta)[:-len(".meta")]
            st, rc, _ = _meta(meta)
            if st == "not-run":
                continue
            try:
                text = open(meta[:-len(".meta")] + ".out", errors="replace").read()
            except OSError:
                text = ""
            reds = _reds_of(leg, name, text, st, rc)
            if reds:
                out.append((leg, name, reds))
    return out


def _baseline_keys(path):
    """(leg, name) of every baseline entry, or None when there is no readable
    baseline. Expired entries count as baselined here: they FAIL either way."""
    try:
        b = yaml.safe_load(open(path))
    except Exception:  # noqa: BLE001
        return None
    ents = b.get("entries") if isinstance(b, dict) else None
    if not isinstance(ents, list):
        return None
    return {(e.get("leg"), str(e.get("name"))) for e in ents if isinstance(e, dict)}


def cmd_plan(a):
    plan = {"max": a.max, "new_red_files": [], "retried": False, "reason": ""}
    base = _baseline_keys(a.baseline)
    if a.interrupted:
        plan["reason"] = "run interrupted: no retry"
    elif base is None:
        plan["reason"] = "no readable baseline at %s: every red FAILs, no retry" % a.baseline
    else:
        for leg, name, reds in _first_run_reds(a.results):
            new = [r for r in reds if (leg, r) not in base]
            if new:
                plan["new_red_files"].append({"leg": leg, "file": name, "new_reds": new})
        n = len(plan["new_red_files"])
        if n == 0:
            plan["reason"] = "no NEW red"
        elif a.max <= 0:
            plan["reason"] = "retry disabled (UNIT_SUITE_FLAKE_RETRY_MAX=%d)" % a.max
        elif n > a.max:
            plan["reason"] = ("%d file(s) with a NEW red, over the retry cap of %d: none retried"
                              % (n, a.max))
        else:
            plan["retried"] = True
    with open(os.path.join(a.results, "flake-plan.json"), "w") as fh:
        json.dump(plan, fh)
    if plan["retried"]:
        files = {}
        for leg in LEGS:
            for p in a.files.get(leg, []):
                files[(leg, os.path.basename(p))] = p
        for f in plan["new_red_files"]:
            p = files.get((f["leg"], f["file"]))
            if p:
                print("%s\t%s" % (f["leg"], p))
    return 0


def cmd_record(a):
    try:
        plan = json.load(open(os.path.join(a.results, "flake-plan.json")))
    except (OSError, ValueError):
        plan = {"max": 0, "new_red_files": [], "retried": False, "reason": "no retry plan"}
    retried, flaky, rows = [], [], []
    now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    for f in plan.get("new_red_files") or []:
        if not plan.get("retried"):
            break
        leg, name = f["leg"], f["file"]
        meta = os.path.join(a.results, "retry", leg, name + ".meta")
        if not os.path.exists(meta):
            retried.append({"leg": leg, "file": name, "retry": "not run"})
            continue
        st, rc, secs = _meta(meta)
        passed = st == "done" and rc == 0
        result = "pass" if passed else ("%s rc=%d" % (st, rc))
        first_out = os.path.join(a.failures_dir, leg, name + ".out") if a.failures_dir else ""
        retry_out = ""
        if a.failures_dir:
            # Keep the retry's own output beside the first run's (T-4058 dir).
            dst = os.path.join(a.report_dir, a.failures_dir, "retry", leg)
            try:
                os.makedirs(dst, exist_ok=True)
                shutil.copy(os.path.join(a.results, "retry", leg, name + ".out"), dst)
                retry_out = os.path.join(a.failures_dir, "retry", leg, name + ".out")
            except OSError:
                pass
        retried.append({"leg": leg, "file": name, "retry": result, "seconds": secs})
        if not passed:
            continue
        for red in f["new_reds"]:
            flaky.append({"leg": leg, "name": red, "file": name,
                          "first_output": first_out, "retry_output": retry_out})
            rows.append({"ts": now, "run_started": a.started, "commit": a.commit or None,
                         "leg": leg, "name": red, "file": name, "retry": "pass",
                         "first_output": first_out, "retry_output": retry_out,
                         "report_dir": a.report_dir})
    if rows:
        try:
            with open(a.log, "a") as fh:
                for r in rows:
                    fh.write(json.dumps(r, sort_keys=True) + "\n")
        except OSError as e:
            print("unit-suite: WARN flake log not written (%s): %s" % (a.log, e), file=sys.stderr)
    with open(os.path.join(a.results, "flaky.json"), "w") as fh:
        json.dump({"flake_retry": {"max": plan.get("max"), "retried": retried,
                                   "candidates": len(plan.get("new_red_files") or []),
                                   "reason": plan.get("reason") or "",
                                   "log": a.log},
                   "suspected_flaky": flaky}, fh)
    return 0


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sub = p.add_subparsers(dest="cmd", required=True)
    pl = sub.add_parser("plan")
    pl.add_argument("--results", required=True)
    pl.add_argument("--baseline", required=True)
    pl.add_argument("--max", type=int, default=5)
    pl.add_argument("--interrupted", action="store_true")
    pl.add_argument("--bats-list", default="", help="file holding the leg's paths, one per line")
    pl.add_argument("--pytest-list", default="")
    rc = sub.add_parser("record")
    rc.add_argument("--results", required=True)
    rc.add_argument("--report-dir", required=True)
    rc.add_argument("--failures-dir", default="", help="relative to the report dir (T-4058)")
    rc.add_argument("--started", default="")
    rc.add_argument("--commit", default="")
    rc.add_argument("--log", required=True)
    a = p.parse_args()
    if a.cmd == "plan":
        a.files = {}
        for leg, path in (("bats", a.bats_list), ("pytest", a.pytest_list)):
            try:
                a.files[leg] = [l.strip() for l in open(path) if l.strip()] if path else []
            except OSError:
                a.files[leg] = []
        return cmd_plan(a)
    return cmd_record(a)


if __name__ == "__main__":
    sys.exit(main())
