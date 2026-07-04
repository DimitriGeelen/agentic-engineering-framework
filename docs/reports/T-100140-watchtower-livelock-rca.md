# T-100140 — Watchtower slow/unresponsive: RCA + structural remediation

**Date:** 2026-07-04 · **Operator report:** "the dashboard has become really slow and not responsive to links anymore"

## Symptom

Watchtower (port 3004) stopped completing requests between 09:41 and 10:46; by 12:34 every
route timed out (curl code 000 at 20s). Process alive: PID 1144147, **140% CPU, 157 threads,
3.9GB RSS**, up 1d15h. Access log showed the last completed request at 09:41.

## Evidence trail

1. **Thread census** (py-spy dump, 135 threads): 50 threads in `/graduation` →
   `discovery._build_application_index` (`read_text` over the corpus), ~50 in `/` →
   `_get_approval_qr`/`get_all_task_metadata`, ~37 in `/approvals` →
   `_load_close_ready_arcs` → per-task `_read_task_meta`. All inside pathlib
   `open`/`read_text`/glob + PyYAML scanner frames.
2. **Request profile** (py-spy record during a live `/` request): **98.2% inside
   `get_all_task_metadata` → `parse_frontmatter` → `yaml.safe_load`**.
3. **Measured rebuild:** 2514 task files, 9.9s full re-parse on an *idle* host —
   against a **30s TTL**. Every TTL expiry re-parsed the entire corpus.
4. **Monitoring:** `liveness-check.sh` (1-min cron) logged `watchtower: stopped` for
   3+ hours. The RSS sampler logged `state: up` (process alive). Nothing acted.

## Root cause (5-whys)

1. Requests timed out → all 135 worker threads thrashed the GIL re-parsing YAML.
2. Why re-parsing? `get_all_task_metadata`'s 30s-TTL cache rebuilds by **re-parsing
   every task file from scratch** — it never used the per-file `mtime_cached_get`
   helper (T-2109) that sits 40 lines above it in the same module.
3. Why now? The corpus grew past the tipping point (~2.5k files after the T-100xxx
   sweep) where rebuild time (≈10s idle, ≈30s+ under load) **exceeded the TTL**, so
   every request paid a full rebuild. Concurrent host load (bats suite spawning full
   audits + a qemu emulator at 148%) pushed it over.
4. Why did it snowball? No single-flight lock: every request past the TTL rebuilt
   **concurrently** (cache stampede), and the threaded Werkzeug dev server accepts
   unbounded threads — pollers retrying every 30-60s accumulated 135 stuck threads.
5. Why undetected/unhealed? Liveness monitoring is **detection-only** — no watchdog
   acts on consecutive probe failures. And `watchtower.sh restart` would have failed
   anyway: it lost the running port (deleted with the triple, then defaulted to 3000
   which a foreign service holds → refused to start).

## Structural remediation (all shipped in this task)

| # | Fix | File | Effect |
|---|-----|------|--------|
| 1 | Per-file mtime cache for corpus rebuild | `web/shared.py` | TTL rebuild 9.4s → **0.05s** |
| 2 | Single-flight + stale-serve on `_task_cache`, `_app_index_cache`, `_qr_cache` | `web/shared.py`, `web/blueprints/{discovery,core}.py` | stampede impossible; concurrent callers get the stale snapshot instantly |
| 3 | `_read_task_meta` via shared cache; `_resolve_constituents` uses cached membership wrapper | `web/blueprints/arcs.py` | `/approvals` 13.6s → **0.8s** (was hundreds of YAML parses/render) |
| 4 | libyaml `CSafeLoader` (11× faster) + mtime cache in `load_yaml`/`load_scan` (deepcopy-on-return, errors re-surface per T-403) | `web/shared.py` | learnings.yaml 0.61s → 7ms warm; cold restart 9.4s → 1.8s |
| 5 | `watchtower.sh restart` preserves the running port | `bin/watchtower.sh` | watchdog/operator restart can't strand the server on a foreign default port |
| 6 | Liveness watchdog: pid-file present + 3 consecutive probe failures → auto `restart`, logged to liveness.jsonl; opt-out `WATCHTOWER_WATCHDOG=0` | `agents/monitor/liveness-check.sh` | next hang self-heals within ~3 min instead of waiting for the operator to notice |

## Measured outcome (4 rounds spanning TTL expiries, incl. cold start)

| Route | During outage | After |
|-------|---------------|-------|
| `/` | timeout (>20s) | 0.29–1.2s |
| `/approvals` | 4.9–13.6s | 0.78–0.98s |
| `/tasks` | 10–16s | 0.10–1.7s |
| `/graduation` | 2.9s+ (50-thread pile-up) | 0.05–1.2s |
| `/arcs` | 0.8–1.8s | 0.06–0.74s |

## Prevention (distinct from the fixes)

- `tests/unit/test_task_cache_t100140.py` — pins per-file rebuild, single-flight
  stale-serve, mutation-safety, error re-surfacing.
- `tests/unit/liveness_watchdog.bats` — pins the self-heal contract (threshold,
  pid-file guard, opt-out, counter reset).
- Watchdog closes the detection→remediation gap for the whole class, independent
  of which endpoint regresses next.

## Related / deferred

- **T-1611 (gunicorn swap)** remains the deeper fix for unbounded thread-per-request;
  this task removed the trigger (per-request corpus parse), T-1611 removes the
  amplifier. Left open.
- `_scan_tasks_by_tag` (arcs.py) still full-parses the corpus per call — low-traffic
  path, same class; follow-up candidate.
- OBS-082: hourly cron `audit --emit-tasks` stole interactive session focus
  (created T-100141 as `started-work` + rewrote focus.yaml) — separate defect found
  during this work.
