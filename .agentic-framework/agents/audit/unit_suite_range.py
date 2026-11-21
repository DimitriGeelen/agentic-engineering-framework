#!/usr/bin/env python3
"""T-5342 (G-138): run the unit test files a pushed commit range touches.

The pre-push ratchet (agents/audit/audit.sh check_unit_suite_report, T-3621)
grades the last nightly report and runs no test. Commits made after that report
pushed with their unit tests never run (2026-11-20: 12 reds pushed unseen, one a
real regression), and the next day the stale report blocked the fix's push.

  select  print the test files for a range, one per line (deterministic, capped)
  run     select, run them within a time budget, write a JSON result the audit
          grades (FAIL / WARN / INFO) and the ratchet reads to clear stale reds

Selection, in this order:
  (a) test files under the suite dir that the range changed (added or modified;
      removed files are ignored);
  (b) test files that name a changed file's basename, as a whole word (fixed
      string, not a regex). Basenames shorter than 5 characters, a fixed list of
      common names (__init__.py, README.md, ...) and basenames named by more than
      a quarter of the suite are skipped: they would select everything.
  Files from (b) are ordered by specificity: the sum, over the changed
  basenames a file names, of 1/(number of test files naming that basename);
  ties by name. The list is capped (default 40); the cut is reported, never silent.

The per-file run mirrors agents/audit/unit-suite.sh _run_one: cwd PROJECT_ROOT,
own TMPDIR, `bats --tap FILE` / `python3 -m pytest FILE -q -rf`, the same env
scrub, plus every GIT_* variable (a pre-push hook exports GIT_DIR and friends;
a test that builds a temp repo would otherwise act on the pushing repo). Red
names use the nightly report's grammar, so they match the baseline.
"""
import argparse
import concurrent.futures
import json
import os
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import time

COMMON = {
    "__init__.py", "__main__.py", "README.md", "readme.md", "CLAUDE.md", "AGENT.md",
    "SKILL.md", "setup.py", "conftest.py", "Makefile", "LICENSE", "VERSION",
    "index.html", "base.html", "main.py", "utils.py", "config.yaml", "LATEST.md",
    "LATEST.yaml", "settings.json", "package.json", "requirements.txt",
}
MIN_BASENAME = 5
COMMON_SHARE = 0.25
TOKEN = re.compile(r"[\w.-]+")
PY_TEST_DEF = re.compile(r"^[ \t]*(async[ \t]+)?def[ \t]+test|^class[ \t]+Test", re.M)


def _git(root, *args):
    r = subprocess.run(["git", "-C", root] + list(args), capture_output=True, text=True,
                       env=_git_env())
    if r.returncode != 0:
        raise RuntimeError("git %s: %s" % (" ".join(args), r.stderr.strip()[:200]))
    return r.stdout


def _git_env():
    # The hook's GIT_DIR / GIT_INDEX_FILE must not redirect `git -C root`.
    return {k: v for k, v in os.environ.items() if not k.startswith("GIT_")}


def is_test_file(path):
    """Mirror of unit-suite.sh _discover_pytest plus *.bats."""
    b = os.path.basename(path)
    if b.endswith(".bats"):
        return True
    if not b.endswith(".py") or b == "conftest.py" or b.startswith("_"):
        return False
    if b.startswith("test_") or b.endswith("_test.py"):
        return True
    try:
        return bool(PY_TEST_DEF.search(open(path, errors="replace").read()))
    except OSError:
        return False


def suite_files(suite_dir):
    try:
        names = sorted(os.listdir(suite_dir))
    except OSError:
        return []
    return [os.path.join(suite_dir, n) for n in names
            if os.path.isfile(os.path.join(suite_dir, n)) and is_test_file(os.path.join(suite_dir, n))]


def changed_files(root, ranges):
    """Paths (relative to root) added or modified in any of the ranges."""
    out = set()
    for r in ranges:
        txt = _git(root, "diff", "--name-only", "--no-renames", "--diff-filter=d", r)
        out.update(l.strip() for l in txt.splitlines() if l.strip())
    return sorted(out)


def select(root, suite_dir, ranges, cap=40):
    root = os.path.abspath(root)
    suite_dir = os.path.abspath(suite_dir)
    tests = suite_files(suite_dir)
    changed = changed_files(root, ranges)
    test_set = set(tests)
    direct = []
    for c in changed:
        p = os.path.join(root, c)
        if p in test_set:
            direct.append(p)
    # Inverted index: whole-word tokens of each test file. A token is a run of
    # [A-Za-z0-9_.-] with trailing dots/dashes stripped, so
    # "agents/audit/audit.sh." yields "audit.sh" and "githooks.sh" does not
    # yield "hooks.sh".
    index = {}
    for t in tests:
        try:
            text = open(t, errors="replace").read()
        except OSError:
            continue
        for tok in set(TOKEN.findall(text)):
            index.setdefault(tok.rstrip(".-"), set()).add(t)
    direct_set = set(direct)
    bases, skipped = [], []
    for c in changed:
        b = os.path.basename(c)
        if b in bases or b in skipped:
            continue
        if len(b) < MIN_BASENAME or b in COMMON:
            skipped.append(b)
            continue
        bases.append(b)
    hits, weight = {}, {}
    for b in bases:
        matched = [t for t in index.get(b, ()) if t not in direct_set]
        if tests and len(matched) > max(10, COMMON_SHARE * len(tests)):
            skipped.append(b)
            continue
        for t in matched:
            hits.setdefault(t, []).append(b)
            # a basename few tests name says more about each of them
            weight[t] = weight.get(t, 0.0) + 1.0 / len(matched)
    named = sorted(hits, key=lambda t: (-round(weight[t], 9), os.path.basename(t)))
    ordered = sorted(direct, key=os.path.basename) + named
    return {
        "ranges": list(ranges),
        "changed": len(changed),
        "files": ordered[:cap],
        "cut": [os.path.relpath(t, root) for t in ordered[cap:]],
        "direct": len(direct),
        "named": len(named),
        "why": {os.path.relpath(t, root): (["changed"] if t in direct else sorted(hits.get(t, [])))
                for t in ordered[:cap]},
        "skipped_basenames": sorted(skipped),
    }


# ── running ────────────────────────────────────────────────────────────────

SCRUB_PREFIX = ("FW_UNIT_SUITE_", "CLAUDE_", "FW_SIDECAR_", "FW_CLAUDE_FW_", "GIT_")
SCRUB_EXACT = {"CLAUDECODE", "TERMLINK_SESSION_ID", "PROJECT_ROOT", "FW_DISPATCHED_WORKER",
               "FW_FOCUS_SESSION_KEY", "FW_SESSION_SCOPED_FOCUS", "FW_PUSH_RANGE",
               "BATS_TEST_FILENAME", "PYTEST_CURRENT_TEST"}


def child_env(tmp):
    env = {k: v for k, v in os.environ.items()
           if k not in SCRUB_EXACT and not k.startswith(SCRUB_PREFIX)}
    env.update(TMPDIR=tmp, BATS_TMPDIR=tmp, FW_WATCHTOWER_ENSURE="0", FW_DOCTOR_SMOKE="0",
               FW_DOCTOR_HOOK_EXERCISE="0", FW_VERB_TELEMETRY="0",
               # a test that runs the pre-push audit must not recurse into this
               FW_PREPUSH_RANGE_TEST_BUDGET="0", PY_COLORS="0", NO_COLOR="1",
               PYTHONDONTWRITEBYTECODE="1")
    env.pop("FORCE_COLOR", None)
    return env


def reds_of(leg, name, out, st, rc):
    """Same names the nightly report records (unit_suite_flaky._reds_of)."""
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


def run_one(root, path, cap):
    leg = "bats" if path.endswith(".bats") else "pytest"
    name = os.path.basename(path)
    tmp = tempfile.mkdtemp(prefix="fw-rangetest-")
    if leg == "bats":
        cmd = ["bats", "--tap", path]
    else:
        cmd = [sys.executable, "-m", "pytest", path, "-q", "-rf", "-p", "no:cacheprovider",
               "--color=no"]
    t0 = time.time()
    st, rc, out = "done", 0, ""
    try:
        p = subprocess.Popen(cmd, cwd=root, env=child_env(tmp), stdin=subprocess.DEVNULL,
                             stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                             errors="replace", start_new_session=True)
        try:
            out, _ = p.communicate(timeout=max(1, cap))
            rc = p.returncode
        except subprocess.TimeoutExpired:
            for sig in (signal.SIGTERM, signal.SIGKILL):
                try:
                    os.killpg(p.pid, sig)
                except OSError:
                    pass
                try:
                    out, _ = p.communicate(timeout=10)
                    break
                except subprocess.TimeoutExpired:
                    continue
            st, rc = "timeout", 124
    except OSError as e:
        st, rc, out = "error", 127, str(e)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    if leg == "pytest" and rc == 5 and re.search(r"^(=+ )?[0-9]+ skipped( in |, )", out or "", re.M):
        rc = 0
    reds = reds_of(leg, name, out or "", st, rc) if st == "done" else []
    if st == "error":
        reds = ["%s: could not start (%s)" % (name, (out or "").strip()[:120])]
    return {"file": os.path.relpath(path, root), "leg": leg, "name": name, "status": st,
            "rc": rc, "seconds": round(time.time() - t0, 1), "reds": reds,
            "passed": st == "done" and rc == 0, "tail": (out or "").splitlines()[-15:]}


def run(root, suite_dir, ranges, budget, cap=40, jobs=4, file_timeout=900):
    sel = select(root, suite_dir, ranges, cap)
    deadline = time.time() + budget
    results, not_run = [], []
    files = list(sel["files"])
    have = {"bats": shutil.which("bats") is not None}

    def work(path):
        left = deadline - time.time()
        if left < 1:
            return {"file": os.path.relpath(path, root), "status": "not-run"}
        if path.endswith(".bats") and not have["bats"]:
            return {"file": os.path.relpath(path, root), "status": "not-run",
                    "why": "bats not installed"}
        r = run_one(root, path, min(file_timeout, int(left)))
        # T-4875 convention: a red file gets one retry while budget remains; a
        # pass on the retry is a suspected flake (WARN), not a pass.
        if r["reds"] and deadline - time.time() > 5:
            r2 = run_one(root, path, min(file_timeout, int(deadline - time.time())))
            r["retry"] = "pass" if r2["passed"] else "%s rc=%d" % (r2["status"], r2["rc"])
        return r

    with concurrent.futures.ThreadPoolExecutor(max_workers=max(1, jobs)) as ex:
        for r in ex.map(work, files):
            if r["status"] == "not-run":
                not_run.append(r["file"])
            else:
                results.append(r)
    sel["files"] = [os.path.relpath(f, root) for f in sel["files"]]
    sel.update(budget=budget, results=results, not_run=not_run,
               timed_out=[r["file"] for r in results if r["status"] == "timeout"])
    return sel


def _baseline(path):
    """{(leg, name): unexpired?} or None when there is no readable baseline."""
    import datetime
    try:
        import yaml
        b = yaml.safe_load(open(path))
    except Exception:  # noqa: BLE001
        return None
    ents = b.get("entries") if isinstance(b, dict) else None
    if not isinstance(ents, list):
        return None
    today = datetime.datetime.now(datetime.timezone.utc).date()
    out = {}
    for e in ents:
        if not isinstance(e, dict):
            continue
        try:
            ok = datetime.date.fromisoformat(str(e.get("expires"))) >= today
        except Exception:  # noqa: BLE001
            ok = False
        out[(e.get("leg"), str(e.get("name")))] = ok
    return out


def grade(res, baseline_path):
    """One '|'-separated line for audit.sh. A red not in the unexpired
    baseline is NEW (FAIL) unless its file passed the one retry (flaky, WARN);
    a baselined red is WARN. Files not run or killed at the budget are named."""
    base = _baseline(baseline_path)
    new, based, flaky, passed = [], [], [], []
    for r in res.get("results") or []:
        if r.get("passed"):
            passed.append(r["name"])
            continue
        for red in r.get("reds") or []:
            key = (r["leg"], red)
            if base is not None and base.get(key):
                based.append(red)
            elif r.get("retry") == "pass":
                flaky.append(red)
            else:
                new.append("%s (%s)" % (red, r["file"]) if not red.startswith(r["name"]) else red)
    unrun = list(res.get("not_run") or []) + list(res.get("timed_out") or [])

    def b(xs, n=25):
        xs = list(xs)
        return "; ".join(xs[:n] + (["... +%d more" % (len(xs) - n)] if len(xs) > n else [])).replace("|", "/")
    return "|".join(str(x) for x in (
        "error" if res.get("error") else "ok", len(res.get("files") or []),
        len(res.get("results") or []) - len(res.get("timed_out") or []), len(passed),
        len(new), b(new), len(based), b(based), len(flaky), b(flaky), len(unrun), b(unrun),
        len(res.get("cut") or []), b(res.get("cut") or [], 10),
        (res.get("error") or "").replace("|", "/").replace("\n", " "),
        ",".join(sorted(passed)), int(res.get("changed") or 0),
        "yes" if base is not None else "no"))


def default_range(root):
    try:
        _git(root, "rev-parse", "--verify", "-q", "@{upstream}")
        return ["@{upstream}..HEAD"]
    except RuntimeError:
        return []


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("cmd", choices=("select", "run", "grade"))
    p.add_argument("--result", default="", help="grade: the run's JSON result")
    p.add_argument("--baseline", default="", help="grade: the ratchet baseline")
    p.add_argument("--root", default=os.environ.get("PROJECT_ROOT") or os.getcwd())
    p.add_argument("--suite-dir", default="")
    p.add_argument("--range", action="append", default=[],
                   help="git range A..B; repeatable; default @{upstream}..HEAD")
    p.add_argument("--max", type=int, default=40)
    p.add_argument("--budget", type=int, default=120)
    p.add_argument("--jobs", type=int, default=min(4, os.cpu_count() or 1))
    p.add_argument("--file-timeout", type=int, default=900)
    p.add_argument("--out", default="", help="write the JSON result here (run)")
    a = p.parse_args()
    if a.cmd == "grade":
        try:
            res = json.load(open(a.result))
        except (OSError, ValueError) as e:
            res = {"error": "result unreadable: %s" % e}
        print(grade(res, a.baseline))
        return 0
    root = os.path.abspath(a.root)
    suite = a.suite_dir or os.path.join(root, "tests", "unit")
    ranges = [r for r in a.range if r.strip()] or default_range(root)
    try:
        if not ranges:
            res = {"ranges": [], "changed": 0, "files": [], "cut": [], "results": [],
                   "not_run": [], "timed_out": [], "error": "no range and no upstream"}
        elif a.cmd == "select":
            res = select(root, suite, ranges, a.max)
            for f in res["files"]:
                print(os.path.relpath(f, root))
            return 0
        else:
            res = run(root, suite, ranges, a.budget, a.max, a.jobs, a.file_timeout)
    except RuntimeError as e:
        res = {"ranges": ranges, "changed": 0, "files": [], "cut": [], "results": [],
               "not_run": [], "timed_out": [], "error": str(e)}
    if a.cmd == "select":
        print("error: %s" % res.get("error", "unknown"), file=sys.stderr)
        return 2
    txt = json.dumps(res, indent=1, sort_keys=True)
    if a.out:
        with open(a.out, "w") as fh:
            fh.write(txt)
    else:
        print(txt)
    return 0


if __name__ == "__main__":
    sys.exit(main())
