#!/usr/bin/env python3
"""Vector-index (semantic recall) health — ONE predicate for doctor, audit,
handover, the reindex cron and the recall/ask banner. T-3783.

Why this exists: semantic recall froze for ~2 months in 47 of 49 projects on
.107 and nothing failed loudly. The hourly reindex job was never seeded into
consumers, `fw index reindex` exited 0 when it could not import web/, doctor
said "Cron registry in sync" (true: registry and crontab both lacked the job),
and index age was at most a WARN. Every one of those was a check answering a
question next to the one that mattered. This module asks the question itself:
can this project's index answer a query right now, and is it current?

Checks (any FAIL makes the verdict FAIL):
  index     the index file exists, opens read-only, and has documents
  manifest  the corpus manifest exists, parses, and carries finished_at +
            canary_token (a missing manifest is FAIL, never "unknown")
  import    web.embeddings imports exactly the way `fw index reindex` imports
            it: cwd=PROJECT_ROOT, PYTHONPATH=FRAMEWORK_ROOT
  age       manifest finished_at no older than INDEX_MAX_AGE_HOURS
  lag       task ids / learning ids on disk that the index has never seen,
            no more than INDEX_MAX_LAG of either
  canary    a semantic search for the manifest's canary probe returns the
            canary document as top hit — through the real search code, against
            this index (skipped only with --no-canary, and then reported SKIP)
  cron      .context/cron-registry.yaml has an active index-reindex-hourly job
WARN-only:
  usage     recall queries that could not run, as a share of the window
  disk      orphan build/reindex scratch beside the index (dead owner pid), and
            free space below what the next reindex needs: a full copy of the
            index plus max(20%, 500 MB) (T-3860 — the copy filled a disk)

Stdlib only — so it runs, and FAILs, exactly where web/ cannot be imported.
Never raises: a health check that crashes reports nothing.

Usage:
  vector_index_health.py [--project-root P] [--framework-root F]
                         [--no-canary] [--json] [--record] [--banner]
Exit: 0 OK, 1 WARN, 2 FAIL (also printed as the first line in text mode).
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import re
import sqlite3
import subprocess
import sys
import time
from pathlib import Path

REQUIRED_JOB = "index-reindex-hourly"
STATE_NAME = "vector-index-health.json"

# Defaults mirror lib/config.sh FW_CONFIG_REGISTRY; the bash wrapper passes the
# resolved values in the environment.
DEFAULT_MAX_AGE_HOURS = 24.0
DEFAULT_MAX_LAG = 50
DEFAULT_FAIL_PCT = 10.0
USAGE_WINDOW_DAYS = 7.0
USAGE_MIN_ROWS = 10

REMEDY_REINDEX = "fw index reindex"
REMEDY_UPGRADE = "fw upgrade   (re-seeds the cron job and the vendored web/)"


def _env_num(name: str, default: float) -> float:
    try:
        v = float(os.environ.get(name, "") or default)
        # NaN/Infinity would crash int() or disable a limit (review round 3).
        return v if (math.isfinite(v) and v >= 0) else default
    except ValueError:
        return default


def _valid_ts(v, now: float) -> bool:
    """A real build time: a finite positive number, not in the future.
    NaN / Infinity / a far-future stamp would otherwise read as "fresh"."""
    return (isinstance(v, (int, float)) and not isinstance(v, bool)
            and math.isfinite(v) and 0 < v <= now + 3600)


def _check(name, verdict, message, hint=""):
    return {"check": name, "verdict": verdict, "message": message, "hint": hint}


def db_path(project_root: Path) -> Path:
    # Same resolution as web/config.py Config.VECTOR_DB_PATH.
    override = os.environ.get("VECTOR_DB_PATH")
    if override:
        return Path(override)
    return project_root / ".context" / "working" / "fw-vec-index.db"


def read_manifest(path: Path):
    p = Path(str(path) + ".manifest.json")
    try:
        data = json.loads(p.read_text())
    except Exception:  # noqa: BLE001 — absent/corrupt both mean "no manifest"
        return None
    return data if isinstance(data, dict) else None


def _open_ro(path: Path):
    return sqlite3.connect(f"file:{path}?mode=ro", uri=True, timeout=10)


def check_index(path: Path):
    if not path.exists():
        return _check("index", "FAIL", f"vector index missing ({path})",
                      f"Build it: {REMEDY_REINDEX}")
    try:
        db = _open_ro(path)
        try:
            n = db.execute("SELECT COUNT(*) FROM documents").fetchone()[0]
        finally:
            db.close()
    except Exception as exc:  # noqa: BLE001
        return _check("index", "FAIL",
                      f"vector index unopenable ({type(exc).__name__}: {str(exc)[:80]})",
                      f"Rebuild it: mv {path} {path}.broken && {REMEDY_REINDEX}")
    if not n:
        return _check("index", "FAIL", "vector index has 0 documents",
                      f"Rebuild it: {REMEDY_REINDEX}")
    return _check("index", "OK", f"vector index opens ({n} chunks)")


def project_initialized_at(project_root: Path):
    """Epoch of `initialized_at:` in .framework.yaml (written once by fw init), or None."""
    try:
        text = (project_root / ".framework.yaml").read_text(errors="replace")
    except OSError:
        return None
    m = re.search(r"^initialized_at:\s*['\"]?([0-9T:+\-.Z]+)", text, re.M)
    if not m:
        return None
    try:
        from datetime import datetime
        return datetime.fromisoformat(m.group(1).replace("Z", "+00:00")).timestamp()
    except ValueError:
        return None


def check_manifest(manifest, now: float | None = None):
    now = time.time() if now is None else now
    if manifest is None:
        return _check("manifest", "FAIL",
                      "vector index has no readable manifest — age and canary unknowable",
                      f"Write one: {REMEDY_REINDEX}")
    fin = manifest.get("finished_at")
    if not _valid_ts(fin, now):
        return _check("manifest", "FAIL", "manifest has no valid finished_at",
                      f"Rewrite it: {REMEDY_REINDEX}")
    if not str(manifest.get("canary_token") or "").strip():
        return _check("manifest", "FAIL", "manifest has no canary_token",
                      f"Replant canaries: {REMEDY_REINDEX}")
    return _check("manifest", "OK", "manifest present")


def check_age(manifest, max_age_hours: float, now: float):
    fin = (manifest or {}).get("finished_at")
    if not _valid_ts(fin, now):
        return _check("age", "FAIL", "vector index age unknown (no manifest finished_at)",
                      f"Run: {REMEDY_REINDEX}")
    hours = (now - float(fin or 0)) / 3600.0
    if hours > max_age_hours:
        return _check("age", "FAIL",
                      f"vector index {hours / 24:.1f} days old "
                      f"(limit {max_age_hours:g}h — the hourly reindex is not running)",
                      f"Run: {REMEDY_REINDEX}; then check the cron job: fw cron status")
    return _check("age", "OK", f"vector index {hours:.1f}h old (limit {max_age_hours:g}h)")


_TASK_RE = re.compile(r"(?:^|/)(T-\d+)[-.]")
_LEARN_RE = re.compile(r"\bid:\s*(L-\d+)\b")


def _disk_task_ids(project_root: Path) -> set:
    ids = set()
    for sub in ("active", "completed"):
        d = project_root / ".tasks" / sub
        if d.is_dir():
            for f in d.glob("T-*.md"):
                m = _TASK_RE.search(f.name)
                if m:
                    ids.add(m.group(1))
    return ids


def check_lag(path: Path, project_root: Path, max_lag: int):
    """Count source items on disk that the index has never seen.

    A count of ids, not a max id: task ids are not dense (T-100xxx exists), and
    a max comparison would let one indexed outlier hide hundreds of missing ones.
    """
    try:
        db = _open_ro(path)
        try:
            indexed_paths = [r[0] for r in db.execute(
                "SELECT DISTINCT path FROM documents WHERE path LIKE '.tasks/%'")]
            learn_chunks = [r[0] for r in db.execute(
                "SELECT chunk_text FROM documents WHERE path = ?",
                (".context/project/learnings.yaml",))]
            try:
                state = {r[0]: (r[1], r[2]) for r in db.execute(
                    "SELECT path, content_hash, mtime FROM file_state")}
            except sqlite3.Error:
                state = {}   # index predates file_state: everything counts as drift
        finally:
            db.close()
    except Exception as exc:  # noqa: BLE001
        return _check("lag", "FAIL", f"index lag unmeasurable ({type(exc).__name__})",
                      f"Rebuild it: {REMEDY_REINDEX}")

    indexed_tasks = {m.group(1) for p in indexed_paths for m in [_TASK_RE.search(p)] if m}
    missing_tasks = _disk_task_ids(project_root) - indexed_tasks

    learn_file = project_root / ".context" / "project" / "learnings.yaml"
    try:
        disk_learn = set(_LEARN_RE.findall(learn_file.read_text(errors="replace")))
    except OSError:
        disk_learn = set()
    indexed_learn = set(_LEARN_RE.findall("\n".join(learn_chunks)))
    missing_learn = disk_learn - indexed_learn

    drift = _source_drift(project_root, state)

    detail = (f"{len(missing_tasks)} task(s), {len(missing_learn)} learning(s) not in the index; "
              f"{drift} source file(s) new or changed since indexed")
    if len(missing_tasks) > max_lag or len(missing_learn) > max_lag or drift > max_lag:
        return _check("lag", "FAIL", f"vector index lags the corpus: {detail} (limit {max_lag})",
                      f"Run: {REMEDY_REINDEX}")
    return _check("lag", "OK", detail)


# The authored sources recall is for: tasks, learnings/decisions/patterns,
# episodics, reports. A subset of web/search_utils.py AUTHORED_DIRS with the
# same INDEXED_SUFFIXES, so a file counted here is one the reindex would index.
DRIFT_DIRS = ((".tasks",), (".context", "episodic"), (".context", "project"), ("docs", "reports"))
DRIFT_SUFFIXES = (".md", ".yaml", ".yml")


def _source_drift(project_root: Path, state: dict) -> int:
    """Files that are new, or whose content changed, since the index saw them.

    Catches what id counts cannot: an edited decision, a new episodic or report,
    a rewritten learning. Every file is hashed the way the indexer hashes it —
    no mtime shortcut, because a restored/copied file can carry a changed body
    under an old timestamp (review round 2). Measured: ~8k files / 64 MB in
    0.8s on AEF.
    """
    n = 0
    for parts in DRIFT_DIRS:
        d = project_root.joinpath(*parts)
        if not d.is_dir():
            continue
        for f in d.rglob("*"):
            if f.suffix not in DRIFT_SUFFIXES or not f.is_file():
                continue
            seen = state.get(f.relative_to(project_root).as_posix())
            if seen is None:
                n += 1
                continue
            try:
                h = hashlib.sha256(f.read_text(errors="replace")
                                   .encode("utf-8", errors="replace")).hexdigest()
            except (OSError, ValueError, TypeError):
                n += 1
                continue
            n += h != seen[0]
    # Deleted sources the index still serves are drift too (review round 3):
    # recall would keep answering from content that no longer exists.
    prefixes = tuple("/".join(parts) + "/" for parts in DRIFT_DIRS)
    for rel in state:
        if (rel.startswith(prefixes) and rel.endswith(DRIFT_SUFFIXES)
                and not (project_root / rel).is_file()):
            n += 1
    return n


def check_token(path: Path, token: str):
    """The manifest's canary token must be IN the index. verify_canaries checks
    canary paths, which are identical in every build, so an index and a manifest
    from different builds would otherwise pass."""
    if not token:
        return _check("token", "FAIL", "no canary token to look for", f"Run: {REMEDY_REINDEX}")
    try:
        db = _open_ro(path)
        try:
            hit = db.execute(
                "SELECT 1 FROM documents WHERE path LIKE '__fwcanary__/%' "
                "AND instr(chunk_text, ?) > 0 LIMIT 1", (token,)).fetchone()
        finally:
            db.close()
    except Exception as exc:  # noqa: BLE001
        return _check("token", "FAIL", f"canary token unreadable ({type(exc).__name__})",
                      f"Rebuild it: {REMEDY_REINDEX}")
    if not hit:
        return _check("token", "FAIL",
                      f"manifest canary {token} is not in the index — manifest and index "
                      "are from different builds", f"Run: {REMEDY_REINDEX}")
    return _check("token", "OK", f"canary {token} planted in the index")


# Runs in a child exactly as `fw index reindex` does (bin/fw: cd PROJECT_ROOT,
# PYTHONPATH=FRAMEWORK_ROOT). The canary goes through web.embeddings'
# _semantic_search — the real embed + sqlite-vec KNN path — against the same
# DB_PATH, without writing a recall-telemetry row (a health probe is not usage).
_CHILD = r'''
import json, sys
try:
    import web.embeddings as E
    from web.canary import verify_canaries
except Exception as exc:
    print(json.dumps({"import": False, "detail": f"{type(exc).__name__}: {str(exc)[:160]}"}))
    sys.exit(0)
out = {"import": True, "db_path": str(E.DB_PATH)}
if sys.argv[1] == "canary":
    try:
        res = verify_canaries(E._semantic_search, sys.argv[2])
        out["canaries"] = [{"name": r.name, "ok": r.ok, "detail": r.detail} for r in res]
    except Exception as exc:
        out["canaries"] = [{"name": "canary", "ok": False,
                            "detail": f"raised {type(exc).__name__}: {str(exc)[:160]}"}]
print(json.dumps(out))
'''


def run_child(project_root: Path, framework_root: Path, mode: str, token: str,
              path: Path, timeout: float):
    env = dict(os.environ)
    env["PYTHONPATH"] = str(framework_root) + (
        os.pathsep + env["PYTHONPATH"] if env.get("PYTHONPATH") else "")
    env["PROJECT_ROOT"] = str(project_root)
    env["VECTOR_DB_PATH"] = str(path)
    try:
        p = subprocess.run([sys.executable, "-c", _CHILD, mode, token],
                           cwd=str(project_root), env=env, capture_output=True,
                           text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return {"import": None, "timeout": True}
    except Exception as exc:  # noqa: BLE001
        return {"import": False, "detail": f"spawn failed: {exc}"}
    for line in reversed(p.stdout.strip().splitlines()):
        try:
            return json.loads(line)
        except ValueError:
            continue
    return {"import": False, "detail": (p.stderr.strip().splitlines() or ["no output"])[-1][:160]}


def check_import(child):
    if child.get("timeout"):
        return _check("import", "FAIL", "web.embeddings import timed out",
                      "Check the python env: python3 -c 'import web.embeddings'")
    if not child.get("import"):
        return _check("import", "FAIL",
                      f"web.embeddings not importable the way fw index reindex imports it "
                      f"({child.get('detail', '?')})",
                      f"Reindex cannot run. Fix the install: {REMEDY_UPGRADE}; "
                      f"deps: pip install -r <framework>/web/requirements.txt")
    return _check("import", "OK", "web.embeddings importable from the reindex path")


def check_canary(child, token: str):
    if child.get("timeout"):
        return _check("canary", "FAIL", "canary query timed out (embedder unreachable?)",
                      "Check the embed path: fw doctor (ollama/embed lines)")
    cans = child.get("canaries")
    if not cans:
        return _check("canary", "FAIL", "canary query did not run",
                      "Check the embed path: fw doctor")
    bad = [c for c in cans if not c.get("ok")]
    if bad:
        return _check("canary", "FAIL",
                      "canary query failed: " + "; ".join(
                          f"{c.get('name')}: {c.get('detail')}" for c in bad)[:240],
                      f"If the embedder is up, the index is stale or broken: {REMEDY_REINDEX}")
    return _check("canary", "OK", f"canary {token} retrieved as top hit")


def check_cron(project_root: Path):
    reg = project_root / ".context" / "cron-registry.yaml"
    try:
        text = reg.read_text()
    except OSError:
        return _check("cron", "FAIL", f"no cron registry — {REQUIRED_JOB} cannot be scheduled",
                      f"Seed it: {REMEDY_UPGRADE}, then: fw cron install")
    # Parse with yaml when available; fall back to a block scan (stdlib only).
    jobs = None
    try:
        import yaml  # noqa: PLC0415
        data = yaml.safe_load(text) or {}
        jobs = [j for j in (data.get("jobs") or []) if isinstance(j, dict)]
    except Exception:  # noqa: BLE001
        jobs = None
    if jobs is None:
        m = re.search(r"-\s*id:\s*['\"]?" + re.escape(REQUIRED_JOB) + r"['\"]?\s*\n((?:[ \t]+\S.*\n?)*)", text)
        jobs = []
        if m:
            st = re.search(r"status:\s*(\S+)", m.group(1))
            jobs = [{"id": REQUIRED_JOB, "status": st.group(1) if st else "active"}]
    job = next((j for j in jobs if j.get("id") == REQUIRED_JOB), None)
    if job is None:
        return _check("cron", "FAIL",
                      f"cron registry lacks {REQUIRED_JOB} — the index will never be refreshed",
                      f"Seed it: {REMEDY_UPGRADE}, then: fw cron install")
    status = str(job.get("status", "active")).strip("'\"").lower()
    if status != "active":
        return _check("cron", "FAIL", f"{REQUIRED_JOB} is {status}, not active",
                      f"Resume it: fw cron resume {REQUIRED_JOB}")
    return _check("cron", "OK", f"{REQUIRED_JOB} scheduled")


def check_usage(path: Path, fail_pct: float, now: float):
    tel = Path(os.environ.get("FW_RECALL_TELEMETRY_PATH") or (path.parent / "recall-telemetry.jsonl"))
    cutoff = now - USAGE_WINDOW_DAYS * 86400
    rows = bad = 0
    try:
        with open(tel, errors="replace") as fh:
            for line in fh:
                try:
                    r = json.loads(line)
                    t = time.mktime(time.strptime(r.get("ts", ""), "%Y-%m-%dT%H:%M:%SZ")) - time.timezone
                except Exception:  # noqa: BLE001
                    continue
                if t < cutoff:
                    continue
                rows += 1
                bad += r.get("outcome") == "unavailable"
    except OSError:
        return _check("usage", "OK", "recall usage: no telemetry yet")
    if rows >= USAGE_MIN_ROWS and 100.0 * bad / rows > fail_pct:
        return _check("usage", "WARN",
                      f"recall: {bad} of {rows} queries in {USAGE_WINDOW_DAYS:g}d could not run "
                      f"({100.0 * bad / rows:.0f}% > {fail_pct:g}%)",
                      "The embed path fails mid-query: fw doctor (ollama/embed lines)")
    return _check("usage", "OK", f"recall: {bad} of {rows} queries in {USAGE_WINDOW_DAYS:g}d could not run")


# T-3860: mirrors web/embeddings.py (_SCRATCH_RE, required_free_bytes). Kept
# here rather than imported because this module must run where web/ cannot.
DISK_MARGIN_FRACTION = 0.20
DISK_MARGIN_MIN_BYTES = 500 * 1024 * 1024
_SCRATCH_RE = re.compile(
    r"^\.(?:reindex\.(?P<rpid>\d+)\.tmp|(?:(?P<bpid>\d+)\.)?building)(?:[.-].*)?$")


def _disk_free(path: Path) -> int:
    import shutil
    return shutil.disk_usage(str(path)).free


def _pid_alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    except OSError:
        return False
    return True


def _human(n: int) -> str:
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if n < 1024 or unit == "TB":
            return f"{n:.0f} {unit}" if unit == "B" else f"{n:.1f} {unit}"
        n /= 1024
    return f"{n} B"


def check_disk(path: Path):
    """Orphan scratch + headroom for the next reindex. WARN-only, never raises."""
    problems, hints = [], []
    try:
        orphans = []
        if path.parent.is_dir():
            for p in path.parent.iterdir():
                if not p.name.startswith(path.name):
                    continue
                m = _SCRATCH_RE.match(p.name[len(path.name):])
                if not m:
                    continue
                pid = m.group("rpid") or m.group("bpid")
                if pid and _pid_alive(int(pid)):
                    continue  # a live build/reindex owns it
                try:
                    orphans.append((p.name, p.stat().st_size))
                except OSError:
                    continue
        if orphans:
            total = sum(b for _, b in orphans)
            listing = ", ".join(f"{n} ({_human(b)})" for n, b in orphans[:5])
            problems.append(f"{len(orphans)} orphan index scratch file(s), {_human(total)}: {listing}")
            hints.append(f"The next {REMEDY_REINDEX} sweeps them; or delete them from {path.parent}")
        if path.exists():
            size = path.stat().st_size
            resume = Path(str(path) + ".reindex.resume")
            copying = not resume.exists()
            margin = max(int(size * DISK_MARGIN_FRACTION), DISK_MARGIN_MIN_BYTES)
            need = (size if copying else 0) + margin
            free = _disk_free(path.parent)
            if free < need:
                problems.append(f"free space {_human(free)} < {_human(need)} the next reindex needs "
                                f"(index {_human(size)}{' copy' if copying else ''} + margin {_human(margin)})")
                hints.append(f"Free space on {path.parent}; the reindex refuses rather than fill the disk")
    except Exception as exc:  # noqa: BLE001
        return _check("disk", "WARN", f"disk check failed ({type(exc).__name__}: {str(exc)[:80]})")
    if problems:
        return _check("disk", "WARN", "; ".join(problems), "; ".join(hints))
    return _check("disk", "OK", "no orphan index scratch; free space covers the next reindex")


def evaluate(project_root: Path, framework_root: Path, canary: bool = True,
             now: float | None = None) -> dict:
    now = time.time() if now is None else now
    max_age = _env_num("FW_INDEX_MAX_AGE_HOURS", DEFAULT_MAX_AGE_HOURS)
    max_lag = int(_env_num("FW_INDEX_MAX_LAG", DEFAULT_MAX_LAG))
    fail_pct = _env_num("FW_RECALL_FAIL_PCT_WARN", DEFAULT_FAIL_PCT)
    timeout = _env_num("FW_INDEX_CANARY_TIMEOUT", 90)

    path = db_path(project_root)
    manifest = read_manifest(path)
    checks = []

    # T-3747: a project initialized less than INDEX_MAX_AGE_HOURS ago whose index was
    # never built (no file, no manifest) is "not built yet", not broken: the hourly
    # reindex has not had its window, and the age check already tolerates an index
    # that old. WARN, not FAIL. The cron check below still FAILs when nothing is
    # scheduled to build it, and an index that existed and vanished still FAILs.
    init_at = project_initialized_at(project_root)
    if (manifest is None and not path.exists() and init_at is not None
            and 0 <= now - init_at < max_age * 3600):
        checks.append(_check(
            "index", "WARN",
            f"vector index not built yet (project initialized {(now - init_at) / 3600:.1f}h ago, "
            f"limit {max_age:g}h)", f"Build it now: {REMEDY_REINDEX}"))
        checks.append(check_cron(project_root))
        verdicts = [c["verdict"] for c in checks]
        status = "FAIL" if "FAIL" in verdicts else "WARN"
        return {"status": status, "full": canary, "ts": now,
                "project_root": str(project_root), "checks": checks}
    idx = check_index(path)
    checks.append(idx)
    man = check_manifest(manifest, now)
    checks.append(man)
    token = str((manifest or {}).get("canary_token") or "")

    # The canary only runs against a non-empty index: web.embeddings._get_db()
    # falls through to a FULL rebuild when the index is missing or empty, and a
    # health probe must never start a multi-hour build.
    mode = "canary" if (canary and idx["verdict"] == "OK" and man["verdict"] == "OK") else "import"
    child = run_child(project_root, framework_root, mode, token, path, timeout)
    checks.append(check_import(child))
    checks.append(check_age(manifest, max_age, now))
    checks.append(check_lag(path, project_root, max_lag) if idx["verdict"] == "OK"
                  else _check("lag", "FAIL", "index lag unmeasurable (no usable index)",
                              f"Build it: {REMEDY_REINDEX}"))
    if not canary:
        checks.append(_check("canary", "SKIP", "canary not run (fast mode)"))
    elif mode != "canary":
        checks.append(_check("canary", "FAIL", "canary cannot run (no usable index/manifest)",
                             f"Build it: {REMEDY_REINDEX}"))
    elif not child.get("import") and not child.get("timeout"):
        checks.append(_check("canary", "FAIL", "canary cannot run (web.embeddings unimportable)",
                             REMEDY_UPGRADE))
    else:
        checks.append(check_canary(child, token))
    checks.append(check_token(path, token) if idx["verdict"] == "OK"
                  else _check("token", "FAIL", "canary token unverifiable (no usable index)",
                              f"Build it: {REMEDY_REINDEX}"))
    checks.append(check_cron(project_root))
    checks.append(check_usage(path, fail_pct, now))
    checks.append(check_disk(path))

    verdicts = [c["verdict"] for c in checks]
    status = "FAIL" if "FAIL" in verdicts else ("WARN" if "WARN" in verdicts else "OK")
    return {"status": status, "full": canary, "ts": now,
            "project_root": str(project_root), "checks": checks}


def record(result: dict, project_root: Path) -> bool:
    """Persist the verdict; return True exactly when it turned red.

    "Turned red" = this FAIL follows a non-FAIL (or no prior record), so the
    operator push fires once per transition, not on every run. Only full runs
    record: a fast run cannot see the canary and must not flip red to green.

    The read-compare-write runs under an exclusive flock, so two overlapping
    runs (the cron reindex and a doctor) cannot both claim one transition. When
    the state cannot be written, no transition is claimed: an unwritable state
    would otherwise re-push on every run, and the red is still shown by
    doctor/audit/handover. The push itself is fw_notify's fire-and-forget; a
    lost push is not retried while the state stays red (by design: once per
    transition, never per run).
    """
    import fcntl  # noqa: PLC0415 — POSIX only, as is the framework
    wdir = project_root / ".context" / "working"
    state = wdir / STATE_NAME
    try:
        wdir.mkdir(parents=True, exist_ok=True)
        lock = open(wdir / (STATE_NAME + ".lock"), "a")
    except OSError:
        return False
    with lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            stored = json.loads(state.read_text())
            prev, prev_ts = stored.get("status"), float(stored.get("ts") or 0)
        except Exception:  # noqa: BLE001
            prev, prev_ts = None, 0.0
        # An observation older than the recorded one is discarded: a slow OK
        # finishing after a newer FAIL must not overwrite it (that would make
        # the next FAIL a second, false "transition" — review round 2).
        if float(result.get("ts") or 0) < prev_ts:
            return False
        turned_red = result["status"] == "FAIL" and prev != "FAIL"
        try:
            tmp = state.with_suffix(f".json.tmp.{os.getpid()}")
            tmp.write_text(json.dumps({
                "status": result["status"], "ts": result["ts"], "previous": prev,
                "reasons": [c["message"] for c in result["checks"] if c["verdict"] == "FAIL"],
            }, indent=2))
            tmp.replace(state)
        except OSError:
            return False
    return turned_red


def banner(result: dict, project_root: Path) -> str:
    """One stderr line for fw recall / fw ask, or "" when recall is healthy.

    Fast runs cannot see the canary, so a red verdict recorded by the last full
    run (doctor/audit/reindex) is honoured too.
    """
    reasons = [c for c in result["checks"] if c["verdict"] == "FAIL"]
    if not reasons:
        try:
            st = json.loads((project_root / ".context" / "working" / STATE_NAME).read_text())
            if st.get("status") == "FAIL" and st.get("reasons"):
                return ("semantic recall degraded: " + st["reasons"][0]
                        + " — results may be missing; fix: " + REMEDY_REINDEX)
        except Exception:  # noqa: BLE001
            pass
        return ""
    first = reasons[0]
    fix = first["hint"].split(": ", 1)[-1] if first["hint"] else REMEDY_REINDEX
    return (f"semantic recall degraded: {first['message']} — results may be missing; "
            f"fix: {fix}")


def degraded_banner(project_root, framework_root, embed_error: str | None = None) -> str:
    """The fw recall / fw ask banner: "" when healthy, else one loud line.

    `embed_error` is the caller's own failure on THIS query (the semantic path
    raised and the caller fell back) — reported first, because it is certain.
    Otherwise the fast predicate runs (no canary) plus the last full verdict.
    Never raises.
    """
    if embed_error:
        return ("semantic recall degraded: embed path failed for this query ("
                + str(embed_error)[:160] + ") — results may be missing; fix: fw doctor")
    try:
        pr, fr = Path(project_root), Path(framework_root)
        return banner(evaluate(pr, fr, canary=False), pr)
    except Exception as exc:  # noqa: BLE001
        return f"semantic recall degraded: health check crashed ({exc}) — results may be missing; fix: fw doctor"


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Vector-index (semantic recall) health (T-3783)")
    ap.add_argument("--project-root", default=os.environ.get("PROJECT_ROOT") or os.getcwd())
    ap.add_argument("--framework-root", default=os.environ.get("FRAMEWORK_ROOT")
                    or str(Path(__file__).resolve().parent.parent))
    ap.add_argument("--no-canary", action="store_true")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--record", action="store_true",
                    help="persist the verdict; prints TURNED_RED when it just went red")
    ap.add_argument("--banner", action="store_true",
                    help="print only the degraded-recall banner (stderr) and exit 0")
    a = ap.parse_args(argv)
    pr, fr = Path(a.project_root).resolve(), Path(a.framework_root).resolve()
    try:
        res = evaluate(pr, fr, canary=not a.no_canary)
    except Exception as exc:  # noqa: BLE001 — never silent
        # A crash is a red verdict like any other: a full run records it and
        # can push (review round 3 — it used to set full=False and stay silent).
        res = {"status": "FAIL", "full": not a.no_canary, "ts": time.time(), "project_root": str(pr),
               "checks": [_check("check", "FAIL", f"vector index check crashed: {exc}",
                                 "Report it; run: fw doctor")]}
    if a.banner:
        line = banner(res, pr)
        if line:
            print(line, file=sys.stderr)
        return 0
    turned = record(res, pr) if (a.record and res.get("full")) else False
    if a.json:
        res["turned_red"] = turned
        print(json.dumps(res))
    else:
        print(res["status"])
        for c in res["checks"]:
            print(f"{c['verdict']}|{c['check']}: {c['message']}|{c['hint']}")
        if turned:
            print("TURNED_RED")
    return {"OK": 0, "WARN": 1}.get(res["status"], 2)


if __name__ == "__main__":
    sys.exit(main())
