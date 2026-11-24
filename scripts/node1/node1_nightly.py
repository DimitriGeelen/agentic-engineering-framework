#!/usr/bin/env python3
"""scripts/node1/node1_nightly.py — T-5392: the nightly unit-suite run on node1.

This project's ring20 adapter: it lives under scripts/, which `fw vendor` does not ship,
so nothing here reaches a consumer. Wrapped by scripts/node1/node1-nightly.sh (overlap lock, cron entry
`node1-unit-suite-nightly`). Contract: docs/reports/T-5069-node1-unit-suite-spec.md §7;
trial and full run: §8, §9.

One run:
  1. list the unit test files exactly as agents/audit/unit-suite.sh does (tests/unit/*.bats
     plus its pytest discovery) and drop the ones in scripts/node1/node1-incompatible.txt (or --exclude-file);
  2. read node1's feed health (pool:feed on node1's hub, field health.state). Nothing is
     sent while it is not `healthy` or the feed is stale: hold, re-check every
     NODE1_HOLD_POLL_S, and give up for the night after NODE1_HOLD_MAX_S with the reason
     written to the report;
  3. build the bundle of HEAD (`bin/fw test bundle`, lib/test-bundle.sh) into
     .context/scratch/node1-bundles/ with node1's 64 MB stage cap, and stage it once
     through the relay (pool:stage; falls back to `pool-client ref-put`, as in the trial);
  4. submit one job per file with `pool-client submit-cmd` (entry aef2.bats / aef2.pytest,
     env aef-unit-2, ref repo.bundle=<sha>), never more than NODE1_MAX_OPEN open;
  5. collect every result (`pool-client wait`, which unpacks unit.log) or name its absence;
  6. write .context/audits/unit-suite/node1/<UTC date>.yaml and LATEST.yaml: counts
     (discovered, excluded, submitted, passed, failed, timed out, not collected, not sent)
     and the failing files, each marked NEW unless it is on the exclusion list; the run
     status (complete | incomplete) and the exclusion file used, with its sha256.

--dry-run lists what would be sent and touches nothing on the network.

Exit: 0 run complete, no NEW failure; 1 run complete with NEW failures; 2 setup error
(nothing sent); 3 run incomplete: some file was not sent or its result not collected
(an unhealthy feed, the wall-clock cap, a refused submit). An incomplete run is never
green, whatever its failures. The report is written for 1, 3 and setup errors after
selection.
"""
from __future__ import annotations

import argparse
import base64
import datetime as dt
import hashlib
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path
from typing import Callable, Dict, Iterable, List, Optional, Sequence, Tuple

HERE = Path(__file__).resolve().parent
DEFAULT_EXCLUDE = HERE / "node1-incompatible.txt"

CFG_DEFAULTS = {
    "NODE1_POOL_HUB": "ring20-management",      # termlink hub profile of ring20's relay (pool:in/out/stage)
    "NODE1_FEED_HUB": "node1-pool",             # termlink hub profile of node1 itself (pool:feed)
    "NODE1_CLIENT": "999-Agentic-Engineering-Framework",
    "NODE1_ENTRY_BATS": "aef2.bats",
    "NODE1_ENTRY_PYTEST": "aef2.pytest",
    "NODE1_ENV": "aef-unit-2",
    "NODE1_MAX_OPEN": "12",
    "NODE1_HOLD_POLL_S": "300",
    "NODE1_HOLD_MAX_S": "10800",
    "NODE1_POLL_S": "30",
    "NODE1_MAX_WALL_S": "72000",                # the whole run; then remaining jobs are "not collected"
    "NODE1_STAGE_TIMEOUT_S": "1200",
    "NODE1_BUNDLE_MAX_MB": "64",                # node1's stage limit (T-5069)
    "POOL_CLIENT": "/usr/local/bin/pool-client",
    "TERMLINK": "termlink",
}


def cfg(name: str) -> str:
    return os.environ.get(name) or CFG_DEFAULTS[name]


# ── pure parts (tests/unit/test_t5392_node1_nightly.py) ─────────────────────────────

PYTEST_DEF = re.compile(r"^[ \t]*(async[ \t]+)?def[ \t]+test|^class[ \t]+Test", re.M)


def discover(suite_dir: Path, root: Path) -> List[str]:
    """The files unit-suite.sh runs when untiered: *.bats, plus pytest's own names
    (test_*.py, *_test.py) and any other module defining a test; never conftest.py or _*.py."""
    out = [p for p in sorted(suite_dir.glob("*.bats")) if p.is_file()]
    for p in sorted(suite_dir.glob("*.py")):
        b = p.name
        if not p.is_file() or b == "conftest.py" or b.startswith("_"):
            continue
        if b.startswith("test_") or b.endswith("_test.py"):
            out.append(p)
        else:
            try:
                if PYTEST_DEF.search(p.read_text(errors="replace")):
                    out.append(p)
            except OSError:
                continue
    return sorted(str(p.relative_to(root)) for p in out)


def load_exclusions(path: Path) -> List[str]:
    """One repo-relative path per line; `#` starts a comment; blank lines ignored."""
    items: List[str] = []
    for line in path.read_text().splitlines():
        line = line.split("#", 1)[0].strip()
        if line and line not in items:
            items.append(line)
    return items


def select(files: Sequence[str], excluded: Iterable[str], only: Optional[Sequence[str]] = None,
           limit: Optional[int] = None, include_excluded: bool = False) -> Tuple[List[str], List[str]]:
    """(to_send, excluded_hits). `only` narrows to the named files (in corpus order);
    `limit` keeps the first N. Excluded files are counted even when --files names them."""
    ex = set(excluded)
    pool = list(files)
    if only:
        want = set(only)
        pool = [f for f in pool if f in want]
    hits = [f for f in pool if f in ex]
    send = pool if include_excluded else [f for f in pool if f not in ex]
    if limit is not None:
        send = send[:limit]
    return send, hits


def parse_ts(s: str) -> Optional[float]:
    try:
        return dt.datetime.strptime(s, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=dt.timezone.utc).timestamp()
    except (TypeError, ValueError):
        return None


def feed_health(doc: Optional[dict], now: float) -> Tuple[bool, str]:
    """node1's pool:feed document → (healthy, reason). Healthy only when health.state is
    `healthy` AND the document is no older than its own stale_after_s (default 180)."""
    if not isinstance(doc, dict):
        return False, "no feed document"
    gen = parse_ts(doc.get("generated_at", ""))
    stale = doc.get("stale_after_s") or 180
    if gen is None:
        return False, "feed has no generated_at"
    age = now - gen
    if age > float(stale):
        return False, f"feed stale: generated {int(age)}s ago (stale after {stale}s)"
    h = doc.get("health")
    if not isinstance(h, dict):
        h = {}
    state = h.get("state")
    if state != "healthy":
        reasons = "; ".join(str(r) for r in (h.get("reasons") or []))[:300]
        return False, f"health.state={state}" + (f" ({reasons})" if reasons else "")
    return True, "healthy"


def grade(exit_code: Optional[int], log: Optional[str]) -> Tuple[str, str]:
    """A collected job → (passed|failed|timeout, detail), graded as unit-suite.sh grades:
    bats `not ok` lines, pytest `FAILED` lines; exit 124 = per-file cap hit (not green)."""
    log = log or ""
    notok = len(re.findall(r"^not ok ", log, re.M))
    failed = len(re.findall(r"^FAILED ", log, re.M))
    m = re.findall(r"^aef-run-unit: exit (\d+)\s*$", log, re.M)
    ec = int(m[-1]) if m else exit_code
    if ec == 124:
        return "timeout", "per-file cap hit (exit 124)"
    if ec == 0 and not notok and not failed:
        return "passed", ""
    parts = [f"exit {ec}"]
    if notok:
        parts.append(f"{notok} not ok")
    if failed:
        parts.append(f"{failed} FAILED")
    return "failed", ", ".join(parts)


def slug(path: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", Path(path).name.lower()).strip("-")


def job_name(run_id: str, path: str) -> str:
    return f"aef-n1-{run_id}-{slug(path)}"[:100]


def build_report(*, run_id: str, commit: str, bundle_sha: str, discovered: int,
                 excluded: Sequence[str], exclusions: Iterable[str], to_send: Sequence[str],
                 outcomes: Dict[str, dict], not_sent: Dict[str, str], holds: List[dict],
                 started: str, finished: str, gave_up: Optional[str],
                 exclude_file: str = "", exclude_sha256: str = "") -> dict:
    """outcomes: file → {status: passed|failed|timeout|not-collected, detail, name}.
    A failed or timed-out file not on the exclusion list is NEW. status is `incomplete`
    when any file was not sent or not collected: such a run is never green."""
    ex = set(exclusions)
    failures = []
    counts = {"discovered": discovered, "excluded": len(excluded), "submitted": 0, "passed": 0,
              "failed": 0, "timeout": 0, "not_collected": 0, "not_sent": len(not_sent), "new_failures": 0}
    not_collected = []
    for f in to_send:
        if f in not_sent:
            continue
        counts["submitted"] += 1
        o = outcomes.get(f) or {"status": "not-collected", "detail": "no result"}
        st = o["status"]
        if st == "passed":
            counts["passed"] += 1
        elif st in ("failed", "timeout"):
            counts[st] += 1
            new = f not in ex
            counts["new_failures"] += int(new)
            failures.append({"file": f, "status": st, "detail": o.get("detail", ""), "new": new,
                             "job": o.get("name", "")})
        else:
            counts["not_collected"] += 1
            not_collected.append({"file": f, "reason": o.get("detail", "no result"), "job": o.get("name", "")})
    incomplete = bool(counts["not_sent"] or counts["not_collected"])
    return {
        "schema": "aef.node1-unit-suite/1",
        "task": "T-5392",
        "status": "incomplete" if incomplete else "complete",
        "run_id": run_id,
        "started": started,
        "finished": finished,
        "commit": commit,
        "bundle_sha256": bundle_sha,
        "counts": counts,
        "failures": failures,
        "not_collected": not_collected,
        "not_sent": [{"file": f, "reason": r} for f, r in not_sent.items()],
        "health_holds": holds,
        "gave_up": gave_up,
        "excluded_list": exclude_file,
        "excluded_list_sha256": exclude_sha256,
    }


def file_sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def display_path(path: Path, root: Path) -> str:
    """Repo-relative when the file is inside the repo, else absolute."""
    p = path.resolve()
    try:
        return str(p.relative_to(root.resolve()))
    except ValueError:
        return str(p)


def exit_code(report: dict, setup_error: bool) -> int:
    """2 setup error; 3 incomplete (never green); 1 NEW failures; 0 complete and clean."""
    if setup_error:
        return 2
    if report["status"] == "incomplete":
        return 3
    return 1 if report["counts"]["new_failures"] else 0


def write_atomic(path: Path, text: str) -> None:
    """Same-dir temp + os.replace: a reader never sees a half-written report (L-493)."""
    tmp = path.with_name(f".{path.name}.{os.getpid()}-{os.urandom(4).hex()}.tmp")
    tmp.write_text(text)
    os.replace(tmp, path)


def to_yaml(doc: dict) -> str:
    try:
        import yaml  # type: ignore
        return yaml.safe_dump(doc, sort_keys=False, default_flow_style=False, allow_unicode=True)
    except ImportError:                         # JSON is valid YAML
        return json.dumps(doc, indent=1) + "\n"


# ── side effects ────────────────────────────────────────────────────────────────────

Runner = Callable[..., subprocess.CompletedProcess]


def default_runner(cmd: Sequence[str], input: Optional[str] = None, timeout: int = 120) -> subprocess.CompletedProcess:
    try:
        return subprocess.run(list(cmd), input=input, capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return subprocess.CompletedProcess(list(cmd), 124, "", f"timeout after {timeout}s")
    except OSError as e:
        return subprocess.CompletedProcess(list(cmd), 127, "", str(e))


class Node1Run:
    def __init__(self, root: Path, run: Runner = default_runner, sleep=time.sleep, now=time.time,
                 log=lambda m: print(m, flush=True)):
        self.root, self.run, self.sleep, self.now, self.log = root, run, sleep, now, log
        self.state = root / ".context/scratch/node1-pool-state"
        self.bundles = root / ".context/scratch/node1-bundles"
        self.report_dir = root / ".context/audits/unit-suite/node1"

    # -- pool-client / termlink
    def pc(self, *args: str, timeout: int = 180) -> subprocess.CompletedProcess:
        return self.run([cfg("POOL_CLIENT"), "--hub", cfg("NODE1_POOL_HUB"), "--state", str(self.state),
                         "--window", cfg("NODE1_MAX_OPEN"), *args], timeout=timeout)

    def read_feed(self) -> Optional[dict]:
        r = self.run([cfg("TERMLINK"), "channel", "subscribe", "pool:feed", "--hub", cfg("NODE1_FEED_HUB"),
                      "--json", "--tail", "1"], timeout=60)
        if r.returncode != 0:
            return None
        for line in reversed((r.stdout or "").splitlines()):
            try:
                return json.loads(base64.b64decode(json.loads(line)["payload_b64"]))
            except (ValueError, KeyError, TypeError):
                continue
        return None

    def health(self) -> Tuple[bool, str]:
        return feed_health(self.read_feed(), self.now())

    def wait_healthy(self, holds: List[dict], deadline: float) -> Optional[str]:
        """None when healthy; else the reason it gave up. Every hold is logged."""
        ok, why = self.health()
        if ok:
            return None
        hold = {"since": iso(self.now()), "reason": why}
        holds.append(hold)
        self.log(f"node1 feed not healthy ({why}); holding")
        give_up = min(deadline, self.now() + int(cfg("NODE1_HOLD_MAX_S")))
        while self.now() < give_up:
            self.sleep(int(cfg("NODE1_HOLD_POLL_S")))
            ok, why = self.health()
            if ok:
                hold["until"] = iso(self.now())
                self.log("node1 feed healthy again; resuming")
                return None
            hold["reason"] = why
        hold["gave_up"] = iso(self.now())
        return f"feed not healthy for {int(cfg('NODE1_HOLD_MAX_S'))}s: {why}"

    def drain(self) -> None:
        """Read pool:out until the cursor stops moving (pool-client reads 200 per call)."""
        cur_p = self.state / "cursor"
        for _ in range(50):
            before = cur_p.read_text().strip() if cur_p.exists() else ""
            self.pc("status", timeout=180)
            after = cur_p.read_text().strip() if cur_p.exists() else ""
            if after == before:
                return

    def build_bundle(self) -> Tuple[str, Path, str]:
        """Into .context/scratch/node1-bundles/ (the folder the relay copies from), under
        node1's stage cap: both are node1's, so they are passed here, not defaulted in
        lib/test-bundle.sh."""
        head = git_head(self.root)
        if head == "unknown":
            raise SetupError("cannot resolve HEAD")
        out = self.bundles / f"aef-unit-suite-{head[:12]}.bundle"
        r = self.run([str(self.root / "bin/fw"), "test", "bundle", "--ref", head, "--out", str(out),
                      "--max-mb", cfg("NODE1_BUNDLE_MAX_MB")], timeout=900)
        if r.returncode != 0:
            raise SetupError(f"bundle build failed: {(r.stderr or r.stdout).strip()[:300]}")
        f = dict(re.findall(r"^(\w+):\s+(\S+)", r.stdout, re.M))
        if not f.get("sha256") or not f.get("file"):
            raise SetupError(f"bundle build printed no sha256/file: {r.stdout[:300]}")
        return f["sha256"], Path(f["file"]), f.get("source_ref", "")

    def prune_bundles(self, keep: Path, n: int = 3) -> None:
        olds = sorted(self.bundles.glob("aef-unit-suite-*.bundle"), key=lambda p: p.stat().st_mtime, reverse=True)
        for p in [p for p in olds if p != keep][n - 1:]:
            p.unlink(missing_ok=True)

    def stage(self, path: Path, sha: str) -> str:
        """pool:stage through the relay (it copies from .context/scratch/node1-bundles/);
        on refusal or no answer, ref-put as in the trial. Returns how it was staged."""
        req = f"aef-{sha[:12]}-{int(self.now())}"
        doc = {"schema": "ring20.pool.stage/1", "path": str(path), "size": path.stat().st_size,
               "sha256": sha, "request": req, "client": cfg("NODE1_CLIENT")}
        r = self.run([cfg("TERMLINK"), "channel", "post", "pool:stage", "--hub", cfg("NODE1_POOL_HUB"),
                      "--msg-type", "stage", "--json"], input=json.dumps(doc), timeout=120)
        why = f"post failed: {(r.stderr or r.stdout).strip()[:200]}" if r.returncode != 0 else ""
        deadline = self.now() + int(cfg("NODE1_STAGE_TIMEOUT_S"))
        while not why and self.now() < deadline:
            res = self._stage_result(req)
            if res is not None:
                if res.get("ok") and res.get("sha256") == sha:
                    return "pool:stage"
                why = f"stage refused: {str(res.get('detail') or res)[:200]}"
                break
            self.sleep(15)
        else:
            why = why or "no pool:stage-out answer"
        self.log(f"pool:stage did not stage the bundle ({why}); falling back to ref-put")
        r = self.pc("ref-put", str(path), timeout=3600)
        if r.returncode != 0:
            raise SetupError(f"staging failed: {why}; ref-put: {(r.stderr or r.stdout).strip()[:200]}")
        return "ref-put"

    def _stage_result(self, req: str) -> Optional[dict]:
        r = self.run([cfg("TERMLINK"), "channel", "subscribe", "pool:stage-out", "--hub", cfg("NODE1_POOL_HUB"),
                      "--json", "--tail", "200"], timeout=60)
        for line in (r.stdout or "").splitlines():
            try:
                d = json.loads(base64.b64decode(json.loads(line)["payload_b64"]))
            except (ValueError, KeyError, TypeError):
                continue
            if isinstance(d, dict) and d.get("request") == req:
                return d
        return None

    def collect_one(self, name: str, out_dir: Path) -> Optional[dict]:
        """None while the result has not arrived; else {status, detail, name}."""
        if not (self.state / "results" / f"{name}.json").exists():
            return None
        self.pc("wait", name, "--timeout", "5", "--dir", str(out_dir), timeout=60)
        d = out_dir / name
        try:
            doc = json.loads((d / "pool-result.json").read_text())
        except (OSError, ValueError):
            doc = {}
        log_p = d / "unit.log"
        if not log_p.exists():
            return {"status": "not-collected", "name": name,
                    "detail": f"no unit.log (outcome={doc.get('outcome')}, exit_code={doc.get('exit_code')})"}
        try:
            ec = int((d / "exit_code").read_text().strip())
        except (OSError, ValueError):
            ec = None
        st, detail = grade(ec, log_p.read_text(errors="replace"))
        return {"status": st, "detail": detail, "name": name}


class SetupError(RuntimeError):
    pass


def iso(t: float) -> str:
    return dt.datetime.fromtimestamp(t, dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def git_head(root: Path) -> str:
    r = default_runner(["git", "-C", str(root), "rev-parse", "HEAD"], timeout=30)
    return r.stdout.strip() if r.returncode == 0 else "unknown"


def submit_and_collect(nr: Node1Run, to_send: List[str], run_id: str, sha: str, jobs_dir: Path,
                       out_dir: Path, holds: List[dict], deadline: float
                       ) -> Tuple[Dict[str, dict], Dict[str, str], Optional[str]]:
    outcomes: Dict[str, dict] = {}
    not_sent: Dict[str, str] = {}
    open_: Dict[str, str] = {}                 # name → file
    queue = list(to_send)
    gave_up: Optional[str] = None
    max_open = int(cfg("NODE1_MAX_OPEN"))
    while queue or open_:
        if nr.now() >= deadline:
            for f in queue:
                not_sent[f] = "run wall-clock cap reached before sending"
            for name, f in open_.items():
                outcomes[f] = {"status": "not-collected", "name": name,
                               "detail": "no result before the run's wall-clock cap"}
            break
        if queue and len(open_) < max_open and not gave_up:
            gave_up = nr.wait_healthy(holds, deadline)
            if gave_up:
                for f in queue:
                    not_sent[f] = gave_up
                queue = []
        while queue and len(open_) < max_open and not gave_up:
            f = queue.pop(0)
            name = job_name(run_id, f)
            jd = jobs_dir / name
            jd.mkdir(parents=True, exist_ok=True)
            (jd / "target.txt").write_text(f + "\n")
            entry = cfg("NODE1_ENTRY_BATS") if f.endswith(".bats") else cfg("NODE1_ENTRY_PYTEST")
            r = nr.pc("submit-cmd", str(jd), "--client", cfg("NODE1_CLIENT"), "--entry", entry,
                      "--env", cfg("NODE1_ENV"), "--name", name, "--unit", f"aef-nightly-{sha[:12]}",
                      "--step", "n1", "--task", "T-5392", "--ref", f"repo.bundle={sha}", timeout=180)
            if r.returncode == 3:                # window full (pool-client's own count): retry later
                queue.insert(0, f)
                break
            if r.returncode != 0:
                not_sent[f] = f"submit-cmd exit {r.returncode}: {(r.stderr or r.stdout).strip()[:200]}"
                continue
            open_[name] = f
        if open_:
            nr.drain()
            for name in list(open_):
                o = nr.collect_one(name, out_dir)
                if o is not None:
                    outcomes[open_.pop(name)] = o
        if open_ or (queue and not gave_up):
            nr.sleep(int(cfg("NODE1_POLL_S")))
    return outcomes, not_sent, gave_up


def main(argv: Optional[Sequence[str]] = None) -> int:
    ap = argparse.ArgumentParser(description=(__doc__ or "").split("\n")[0])
    ap.add_argument("--dry-run", action="store_true", help="list what would be sent; no network, no writes")
    ap.add_argument("--files", help="comma-separated repo paths: send only these")
    ap.add_argument("--limit", type=int, help="send at most N files (e.g. a small proof run)")
    ap.add_argument("--include-excluded", action="store_true", help="also send files on the exclusion list")
    ap.add_argument("--exclude-file", default=str(DEFAULT_EXCLUDE))
    ap.add_argument("--health", action="store_true", help="print node1's feed health and exit (0 healthy, 1 not)")
    o = ap.parse_args(argv)
    root = Path(os.environ.get("PROJECT_ROOT") or HERE.parent.parent).resolve()

    nr = Node1Run(root)
    if o.health:
        ok, why = nr.health()
        print(f"node1 feed: {why}")
        return 0 if ok else 1

    exclude_path = Path(o.exclude_file)
    try:
        exclusions = load_exclusions(exclude_path)
        exclude_sha = file_sha256(exclude_path)
    except OSError as e:
        print(f"node1-nightly: cannot read the exclusion list {o.exclude_file}: {e}", file=sys.stderr)
        return 2
    files = discover(root / "tests/unit", root)
    only = [s.strip() for s in o.files.split(",")] if o.files else None
    to_send, excluded = select(files, exclusions, only, o.limit, o.include_excluded)
    if only:
        missing = sorted(set(only) - set(files))
        if missing:
            print(f"node1-nightly: not unit test files: {', '.join(missing)}", file=sys.stderr)
            return 2
    nb = sum(f.endswith(".bats") for f in to_send)
    print(f"node1-nightly: discovered={len(files)} excluded={len(excluded)} to_send={len(to_send)} "
          f"(bats={nb} pytest={len(to_send) - nb})")
    print(f"node1-nightly: exclusion list {display_path(exclude_path, root)} sha256 {exclude_sha[:12]}")
    if o.dry_run:
        for f in to_send:
            print(f"  would send  {f}")
        return 0

    started_t = nr.now()
    started = iso(started_t)
    run_id = dt.datetime.fromtimestamp(started_t, dt.timezone.utc).strftime("%Y%m%d%H%M")
    deadline = started_t + int(cfg("NODE1_MAX_WALL_S"))
    work = root / ".context/scratch/node1-nightly" / run_id
    holds: List[dict] = []
    commit = git_head(root)
    sha = ""
    outcomes: Dict[str, dict] = {}
    not_sent: Dict[str, str] = {}
    gave_up: Optional[str] = None
    setup_error = False
    try:
        gave_up = nr.wait_healthy(holds, deadline)
        if gave_up:
            not_sent = {f: gave_up for f in to_send}
        else:
            sha, path, src = nr.build_bundle()
            commit = src or commit
            nr.prune_bundles(path)
            how = nr.stage(path, sha)
            nr.log(f"bundle {path.name} sha256 {sha[:12]} staged via {how}")
            outcomes, not_sent, gave_up = submit_and_collect(nr, to_send, run_id, sha, work / "jobs",
                                                             work / "results", holds, deadline)
    except SetupError as e:
        print(f"node1-nightly: SETUP ERROR — {e}", file=sys.stderr)
        not_sent = {f: f"setup error: {e}" for f in to_send}
        gave_up = f"setup error: {e}"
        setup_error = True

    report = build_report(run_id=run_id, commit=commit, bundle_sha=sha, discovered=len(files),
                          excluded=excluded, exclusions=exclusions, to_send=to_send, outcomes=outcomes,
                          not_sent=not_sent, holds=holds, started=started, finished=iso(nr.now()),
                          gave_up=gave_up, exclude_file=display_path(exclude_path, root),
                          exclude_sha256=exclude_sha)
    nr.report_dir.mkdir(parents=True, exist_ok=True)
    text = to_yaml(report)
    dated = nr.report_dir / f"{started[:10]}.yaml"
    if dated.exists():
        dated = nr.report_dir / f"{run_id}.yaml"
    write_atomic(dated, text)
    write_atomic(nr.report_dir / "LATEST.yaml", text)
    c = report["counts"]
    line = (f"{started} run={run_id} status={report['status']} commit={commit[:12]} " + " ".join(f"{k}={v}" for k, v in c.items())
            + (f" gave_up={gave_up!r}" if gave_up else ""))
    with open(nr.report_dir / "runs.log", "a") as fh:
        fh.write(line + "\n")
    print(line)
    print(f"report: {dated.relative_to(root)}")
    for fl in report["failures"]:
        print(f"  {'NEW ' if fl['new'] else 'known'} {fl['status']:7} {fl['file']}  {fl['detail']}")
    rc = exit_code(report, setup_error)
    if report["status"] == "incomplete":
        print(f"node1-nightly: INCOMPLETE — not_sent={c['not_sent']} not_collected={c['not_collected']}; "
              f"this run is not green (exit {rc})")
    return rc


if __name__ == "__main__":
    sys.exit(main())
