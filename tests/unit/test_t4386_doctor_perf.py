"""T-4386: `fw doctor` took 3-4 min a run (15 min per doctor bats file). Each
test pins one fixed hot spot to its fast shape, so a regression to the slow
path fails here rather than surfacing as a slow suite. Every test fails against
the pre-fix code (noted per test). Profile: docs/reports/T-4386-doctor-profile.md.
"""
import importlib.util
import json
import os
import subprocess
import sys
import textwrap
import time
from pathlib import Path

import pytest
import yaml

ROOT = Path(__file__).resolve().parents[2]
LIB = ROOT / "lib"


def _load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod


# --- costs current: only the newest transcript is read (was: every one) -----

def _costs_current(jsonl_dir):
    return subprocess.run(
        ["bash", "-c", 'source "$1/lib/colors.sh"; source "$1/lib/costs.sh"; '
                       '_costs_parse_all "$2" current', "_", str(ROOT), str(jsonl_dir)],
        capture_output=True, text=True, timeout=60)


def test_costs_current_reads_only_the_newest_transcript(tmp_path):
    # An older "transcript" that cannot be opened: the pre-fix code parsed every
    # file before picking the newest, and raised on this one.
    old = tmp_path / "aaaa-old.jsonl"
    old.mkdir()
    os.utime(old, (1_000_000, 1_000_000))
    new = tmp_path / "bbbb-new.jsonl"
    rows = [
        {"type": "user", "timestamp": "2026-10-19T00:00:00Z", "message": {"content": "x" * 100}},
        {"timestamp": "2026-10-19T00:00:01Z", "message": {"model": "m", "usage": {
            "input_tokens": 10, "output_tokens": 5,
            "cache_read_input_tokens": 100, "cache_creation_input_tokens": 0}}},
        {"timestamp": "2026-10-19T00:00:02Z", "message": {"model": "<synthetic>", "usage": {
            "input_tokens": 999, "output_tokens": 999}}},
        {"timestamp": "2026-10-19T00:00:03Z", "message": {"model": "m", "usage": {
            "input_tokens": 1, "output_tokens": 1}}},
    ]
    new.write_text("\n".join(json.dumps(r) for r in rows) + "\n")
    r = _costs_current(tmp_path)
    assert r.returncode == 0, r.stderr
    assert "Turns:      2" in r.stdout
    assert "Total:      117 tokens" in r.stdout


# --- resolver stalled: one git log for the whole scan (was: one per task) ----

def _task(tid, status="started-work"):
    return textwrap.dedent(f"""\
        ---
        id: {tid}
        name: "t"
        status: {status}
        workflow_type: build
        owner: agent
        horizon: now
        ---

        # {tid}

        ## Acceptance Criteria

        ### Agent
        - [ ] one
        """)


def test_resolver_stall_scan_runs_one_git_log(tmp_path, monkeypatch):
    repo = tmp_path / "repo"
    active = repo / ".tasks" / "active"
    active.mkdir(parents=True)
    (repo / ".context").mkdir()
    for tid in ("T-9001", "T-9002", "T-9003"):
        (active / f"{tid}-x.md").write_text(_task(tid))
    rows = []
    for tid in ("T-9001", "T-9002", "T-9003"):
        for i in range(5):
            rows.append({"task_id": tid, "ts": f"2026-01-01T00:00:0{i}+00:00",
                         "task_snapshot": {"status": "started-work", "ac_ticked": 0}})
    (repo / ".context" / "dispatches.jsonl").write_text(
        "\n".join(json.dumps(r) for r in rows) + "\n")
    env = dict(os.environ, GIT_AUTHOR_NAME="t", GIT_AUTHOR_EMAIL="t@t",
               GIT_COMMITTER_NAME="t", GIT_COMMITTER_EMAIL="t@t")
    subprocess.run(["git", "init", "-q", str(repo)], check=True, env=env)
    subprocess.run(["git", "-C", str(repo), "commit", "-q", "--allow-empty", "-m",
                    "T-9001: advanced"], check=True, env=env)

    monkeypatch.setenv("PROJECT_ROOT", str(repo))
    monkeypatch.syspath_prepend(str(LIB))
    resolver = _load("resolver_t4386", LIB / "resolver.py")

    calls = []
    real_run = subprocess.run

    def counting_run(cmd, *a, **kw):
        if list(cmd[:2]) == ["git", "log"]:
            calls.append(cmd)
        return real_run(cmd, *a, **kw)

    monkeypatch.setattr(resolver.subprocess, "run", counting_run)
    stalled = resolver._stalled_task_ids(5)
    assert sorted(stalled) == ["T-9002", "T-9003"]   # T-9001 has a commit
    assert len(calls) == 1, f"expected one git log for the scan, got {len(calls)}"

    # The cached active-dir lookup still sees a task that appears afterwards.
    (active / "T-9004-y.md").write_text(_task("T-9004", status="issues"))
    os.utime(active, ns=(time.time_ns() + 10**9,) * 2)
    assert resolver._task_current_snapshot("T-9004") == {"status": "issues", "ac_ticked": 0}
    assert resolver._task_current_snapshot("T-900") is None


# --- port3000: no regex over a whole file (was: HIT_RE.search(text)) --------

def test_port3000_hit_test_matches_hit_re_and_never_scans_whole_text(tmp_path, monkeypatch):
    mod = _load("p3k_t4386", ROOT / "tools" / "port3000_hygiene.py")
    samples = ["", ":3000", "x localhost:3000 y", "127.0.0.1:3000", "0.0.0.0:3000",
               "http://localhost:30001", "localhost:30001 then 0.0.0.0:3000",
               "host:3000", "0.0.0.0:3000x", "a\nlocalhost:3000\n", "ocalhost:3000"]
    for s in samples:
        assert mod._has_hit(s) == bool(mod.HIT_RE.search(s)), s

    seen = []
    real = mod.HIT_RE

    class Spy:
        def search(self, s, *a):
            seen.append(s)
            return real.search(s, *a)

    monkeypatch.setattr(mod, "HIT_RE", Spy())
    f = tmp_path / "x.md"
    f.write_text("intro\n" * 50 + "see localhost:3000/tasks\n" + "outro\n" * 50)
    hits = mod.scan_file(f, tmp_path)
    assert len(hits) == 1 and hits[0].line == 51
    assert seen and all("\n" not in s for s in seen), "HIT_RE ran over the whole file"


# --- hook exercise: probes run concurrently (was: one after another) -------

def test_hook_exercise_runs_probes_concurrently(tmp_path):
    claude = tmp_path / ".claude"
    claude.mkdir()
    hooks = [{"hooks": [{"type": "command", "command": "sleep 1"}]} for _ in range(6)]
    (claude / "settings.json").write_text(json.dumps({"hooks": {"PreToolUse": hooks}}))
    t0 = time.monotonic()
    r = subprocess.run([sys.executable, str(LIB / "doctor-hook-exercise.py")],
                       env=dict(os.environ, SETTINGS_FILE=str(claude / "settings.json")),
                       capture_output=True, text=True, timeout=60)
    elapsed = time.monotonic() - t0
    assert r.stdout.splitlines()[0] == "6|0|0"
    assert elapsed < 4.5, f"6 one-second probes took {elapsed:.1f}s — run serially?"


# --- plugin-audit: one classifier process for all files ---------------------

def test_plugin_audit_classifies_files_in_one_batch(tmp_path):
    aware = tmp_path / "a.md"
    aware.write_text("Run fw work-on first.\n")
    bypass = tmp_path / "b.md"
    bypass.write_text("EXTREMELY IMPORTANT: do it.\n")
    silent = tmp_path / "c.md"
    silent.write_text("Nothing here.\n")
    r = subprocess.run(
        ["bash", "-c", 'eval "$(sed -n "/^classify_files()/,/^}/p" "$1")"; shift; classify_files "$@"',
         "_", str(ROOT / "agents" / "audit" / "plugin-audit.sh"),
         str(aware), str(bypass), str(silent), str(tmp_path / "missing.md")],
        capture_output=True, text=True, timeout=60)
    assert r.stdout.split() == ["AWARE", "BYPASSING", "SILENT", "SILENT"], r.stderr


# --- task debt: one process, same count as the bash loop it replaced -------

_OLD_LOOP = r'''
cutoff="$2"; stale_count=0
for tf in "$1"/*.md; do
    [ -f "$tf" ] || continue
    lu=$(grep '^last_update:' "$tf" 2>/dev/null | head -1 | sed 's/last_update: *//' | tr -d '"' || true)
    if [ -n "$lu" ]; then
        lu_epoch=$(date -d "${lu}" +%s 2>/dev/null || echo 0)
        if [ "$lu_epoch" -gt 0 ] && [ "$lu_epoch" -lt "$cutoff" ]; then
            stale_count=$((stale_count + 1))
        fi
    fi
done
echo "$stale_count"
'''


def test_task_debt_matches_the_replaced_bash_loop(tmp_path):
    d = tmp_path / "active"
    d.mkdir()
    values = {
        "T-1-a.md": "last_update: 2026-01-01T00:00:00Z",          # stale
        "T-2-a.md": 'last_update: "2026-01-02T00:00:00Z"',        # stale
        "T-3-a.md": "last_update: '2026-01-03T00:00:00Z'",        # date -d rejects it
        "T-4-a.md": "last_update: 2026-10-30T00:00:00Z",          # recent
        "T-5-a.md": "name: no timestamp",                         # body line below: stale
        "T-6-a.md": "last_update: not a date",
    }
    for name, line in values.items():
        (d / name).write_text(f"---\nid: x\n{line}\n---\nlast_update: 2020-01-01T00:00:00Z\n")
    cutoff = "1790000000"   # 2026-09-21
    old = subprocess.run(["bash", "-c", _OLD_LOOP, "_", str(d), cutoff],
                         capture_output=True, text=True, timeout=60).stdout.strip()
    new = subprocess.run([sys.executable, str(LIB / "task_debt.py"), str(d), cutoff],
                         capture_output=True, text=True, timeout=60).stdout.strip()
    # T-4430 broke parity on purpose: the loop skipped T-3 (single quotes), T-5
    # (frontmatter has no last_update) and T-6 (unparseable) as if fresh. Now
    # T-3 parses as stale and T-5/T-6 count as unparsed debt.
    assert old == "3"
    assert new == "5"


# --- underpopulated cards: libyaml loader -----------------------------------

@pytest.mark.skipif(not yaml.__with_libyaml__, reason="libyaml not installed")
def test_underpopulated_scan_uses_libyaml():
    mod = _load("underpop_t4386", ROOT / "agents" / "fabric" / "lib" / "underpopulated.py")
    assert mod._SafeLoader is yaml.CSafeLoader


# --- design register: owner lookups load per id (was: every task parsed) ----

def test_register_violations_does_not_index_the_whole_corpus(tmp_path, monkeypatch):
    monkeypatch.syspath_prepend(str(LIB))
    dr = _load("design_register_t4386", LIB / "design_register.py")

    def boom(*a, **k):
        raise AssertionError("register_violations parsed every task (task_index)")

    monkeypatch.setattr(dr, "task_index", boom)
    (tmp_path / ".tasks" / "active").mkdir(parents=True)
    assert dr.register_violations(tmp_path) == []


# --- vector index health: lag scan overlaps the canary child ---------------

def test_vector_index_lag_scan_overlaps_the_child(tmp_path, monkeypatch):
    vih = _load("vih_t4386", LIB / "vector_index_health.py")
    ok = lambda name: vih._check(name, "OK", name)  # noqa: E731
    monkeypatch.setattr(vih, "check_index", lambda p: ok("index"))
    monkeypatch.setattr(vih, "check_manifest", lambda m, n: ok("manifest"))
    monkeypatch.setattr(vih, "read_manifest", lambda p: {"canary_token": "T"})

    def slow_child(*a, **k):
        time.sleep(1.0)
        return {"import": True, "canaries": []}

    def slow_lag(*a, **k):
        time.sleep(1.0)
        return ok("lag")

    monkeypatch.setattr(vih, "run_child", slow_child)
    monkeypatch.setattr(vih, "check_lag", slow_lag)
    for name in ("check_age", "check_token", "check_usage", "check_disk",
                 "check_cron", "check_import", "check_canary"):
        monkeypatch.setattr(vih, name, lambda *a, _n=name, **k: ok(_n))
    t0 = time.monotonic()
    res = vih.evaluate(tmp_path, ROOT, canary=True)
    elapsed = time.monotonic() - t0
    names = [c["check"] for c in res["checks"]]
    assert names.index("check_import") < names.index("check_age") < names.index("lag")
    assert elapsed < 1.8, f"child and lag ran back to back ({elapsed:.1f}s)"
