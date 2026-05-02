# orchestrator-rethink demo — wire-level evidence (T-1669 Step 4/4)

This directory captures the **headline_mechanic** for the
`orchestrator-rethink` arc firing live on the framework dispatch path:

> agent dispatches a task without specifying a model → orchestrator picks
> the model based on task_type and historical success rates → user
> observes the routing decision live on /orchestrator and watches
> per-task-type model preferences shift as the route_cache learns

Captured 2026-05-02 from `192.168.10.107:3000` against
`/var/lib/termlink/route-cache.json` after Steps 1-3 of T-1669 shipped
(commits `3e2108c23`, `f29246d97`, `9cb103cc7`).

Arc: `orchestrator-rethink` (closes as `--demo docs/reports/orchestrator-rethink-demo/`)

## Files

| Artefact | What it shows |
|----------|---------------|
| `cache-00-baseline.json` | Empty `model_stats` — pre-demo state on this host. |
| `cache-01-after-build-seed.json` | After seeding build with `record-outcome`: haiku 6s/1f, opus 1s/3f. |
| `cache-02-after-multi-task-type-seed.json` | After seeding design + inception. 3 task_types, 5 model:type stats. |
| `cache-03-after-real-dispatches.json` | After 3 real `fw termlink dispatch` workers exited. Successes incremented for haiku:build, sonnet:design, opus:inception — proves Step 2 write path fires from real workers, not just direct `record-outcome` calls. |
| `meta-01-build-dispatch.json` | Real worker meta. `model: haiku`, `resolution_source: route_cache`. |
| `meta-01-design-dispatch.json` | Real worker meta. `model: sonnet`, `resolution_source: route_cache`. |
| `meta-01-inception-dispatch.json` | Real worker meta. `model: opus`, `resolution_source: route_cache`. |
| `resolver-trace.txt` | Direct invocation of `_resolve_dispatch_model_and_fallback` for build/design/inception/nonexistent — shows the resolver picking from cache, not env. |
| `screenshot-orchestrator-page.png` | `/orchestrator` rendered with the Learned-routing panel, taken via Playwright. Shows the table operators see. |

## What each step proves

### Step 1 (read path, `3e2108c23`) — proven by `meta-01-*.json`

Each meta.json shows `resolution_source: route_cache` and `fallback_used: true`
without an explicit `--model`. Pre-T-1669, the framework dispatch path
would have returned `env-default` or `none`. Now it consults the cache
first.

### Step 2 (write path, `f29246d97`) — proven by cache-03 vs cache-02

Three real `claude -p` workers were spawned, each across a different
task_type. They exited with code 0. Comparing `cache-02-after-multi-task-type-seed`
to `cache-03-after-real-dispatches`:

```
haiku:build      6s/1f → 7s/1f   (+1 success from real worker)
sonnet:design    4s/0f → 5s/0f   (+1 success from real worker)
opus:inception   5s/1f → 6s/1f   (+1 success from real worker)
```

The framework's `record-outcome` subcommand fired from inside each
worker's `run.sh` after `EXIT_CODE` was captured, atomically updating
`model_stats[<model>:<task_type>]`. No hand-edit of the cache.

### Step 3 (surface, `9cb103cc7`) — proven by `screenshot-orchestrator-page.png`

The Watchtower `/orchestrator` page renders the "Learned routing"
panel with the per-task-type best model and all candidates. This is
what a human operator sees when they ask "what is the orchestrator
doing right now?".

### Step 4 (this directory) — proves the loop

Without Step 4 the previous three could each pass tests and still not
close the loop end-to-end. The artefacts above demonstrate one
continuous flow:

1. Cache is seeded (Step 2 write path: `record-outcome`)
2. Operator opens `/orchestrator`, sees the learned panel (Step 3)
3. Agent runs `fw termlink dispatch` *without* `--model` (Step 1 read path)
4. Resolver picks the highest-success-rate model for the task_type
5. Worker spawns, completes, exits 0
6. Worker's `run.sh` calls back to `fw termlink record-outcome`
7. Cache updates atomically (Step 2 write path again)
8. Operator refreshes `/orchestrator`, sees rates shift (Step 3)

Steps 4-7 happen mechanically per dispatch; the operator's only signal
is the panel changing.

## How to reproduce

```bash
# 1. Save your current cache (this demo overwrites it)
cp /var/lib/termlink/route-cache.json /tmp/route-cache.bak

# 2. Reset and seed (or leave existing data — the demo is additive)
echo '{"entries":{},"model_stats":{}}' > /var/lib/termlink/route-cache.json

# 3. Seed varied scenarios via record-outcome
for i in 1 2 3 4 5 6; do bin/fw termlink record-outcome --model haiku  --task-type build     --exit-code 0; done
                          bin/fw termlink record-outcome --model haiku  --task-type build     --exit-code 1
for i in 1 2 3;       do bin/fw termlink record-outcome --model opus   --task-type build     --exit-code 1; done
                          bin/fw termlink record-outcome --model opus   --task-type build     --exit-code 0
for i in 1 2 3 4;     do bin/fw termlink record-outcome --model sonnet --task-type design    --exit-code 0; done
for i in 1 2 3 4 5;   do bin/fw termlink record-outcome --model opus   --task-type inception --exit-code 0; done

# 4. Trace the resolver (no --model, only task_type)
for tt in build design inception; do
  bash -c "source agents/termlink/termlink.sh; _resolve_dispatch_model_and_fallback '' '$tt'"
done

# 5. Real dispatches (no --model, fast prompt)
for tt in build design inception; do
  bin/fw termlink dispatch --task T-1669 --name "demo-${tt}-$$" --task-type "$tt" \
    --prompt "Reply with the single word: ${tt}" --timeout 120
done

# 6. Open /orchestrator and refresh as workers exit
open "$(bin/fw watchtower url)/orchestrator"
```

## Live-update verification (T-1678, 2026-05-02T11:00Z)

Captured at 11:00Z, four hours after the demo above:
`cache-04-2026-05-02-1100Z-still-firing.json`.

Delta vs `cache-03-after-real-dispatches.json`:

```
haiku:build      7s/1f → 8s/1f   (+1 success — last_used 07:15:44Z, after cache-03 captured)
opus:inception   6s/1f → 7s/1f   (+1 success — recorded post-demo)
sonnet:design    5s/0f → 5s/0f   (no new design dispatches in window)
haiku:design     1s/2f → 1s/2f   (unchanged; same as cache-03)
opus:build       1s/3f → 1s/3f   (unchanged; same as cache-03)
```

Two model_stats keys grew their `successes` count (`haiku:build`,
`opus:inception`) WITHOUT manual `record-outcome` calls or hand-edits
between demo capture and 11:00Z. The only code path that increments
those counters is the framework dispatch path's post-worker
`record-outcome` invocation (Step 2 write path, commit `f29246d97`).

Concretely: between 07:14Z (cache-03) and 11:00Z (cache-04) the
orchestrator framework dispatch resolved a build task to haiku,
spawned a worker, observed exit 0, and atomically updated the cache
— and the same for an inception task routed to opus. No human in
the loop. This proves the system continues to fire after the demo
capture, not just at the moment evidence was being gathered.

## Live-test verification (T-1680, 2026-05-02T12:41Z)

End-to-end re-test executed on operator request to confirm the
headline_mechanic still fires on demand. Captured at 12:41Z:
`cache-05-2026-05-02-1241Z-live-test.json`.

Procedure:

1. Pre-test cache snapshot taken (matches `cache-04`).
2. Resolver traced for build/design/inception/nonexistent — predicted
   haiku/sonnet/opus/none, source=`route_cache` for the three known
   types.
3. Three real `fw termlink dispatch` invocations — no `--model`
   flag, only `--task-type`. Worker `meta.json` for each shows
   `resolution_source: route_cache` and the predicted model.
4. All three workers exited 0 (results: `build`, `Design workflow
   loaded. What topic would you like to design?`, `inception`).
5. Cache delta vs pre-test:

```
haiku:build      8s/1f → 9s/1f   (last_used → 12:41:38Z)
sonnet:design    5s/0f → 6s/0f   (last_used → 12:41:53Z)
opus:inception   7s/1f → 8s/1f   (last_used → 12:41:46Z)
```

6. `/orchestrator` re-fetched: rendered success rates now
   `haiku 90% (build)`, `sonnet 100% (design)`, `opus 89%
   (inception)`. These are the new cache values rendered live (9/10,
   6/6, 8/9 round-trip through the success_rate template formula).

This is the headline_mechanic firing in one continuous flow on
demand, with the resolver picking the right model from history, the
worker exiting clean, the record-outcome callback updating the
atomic cache file, and the operator surface reflecting the new
state — without any cached page load or stale snapshot in between.

**Known observability gap discovered during this run:** worker
`meta.json` is written at spawn time with `status: running` and
never updated post-exit by `run.sh`. Authoritative exit state lives
in `$WDIR/exit_code` + `$WDIR/finished_at` (and the cache
post-update). Filed as follow-up — does not affect the headline
mechanic, only the dispatch_status CLI surface.

## Failure-path verification (T-1682, 2026-05-02T14:32Z)

T-1680 verified the success path. T-1682 verifies the failure
path — that timeouts and non-zero exits are recorded as failures
in the cache, and the surface re-renders the lower success rate.
Captured as `cache-06-2026-05-02-1432Z-failure-path.json`.

Procedure:

1. Pre-test cache (= cache-05): `haiku:build 9s/1f` (90%).
2. Single `fw termlink dispatch` invocation, build task_type, no
   `--model`, `--timeout 3` with a deliberately verbose prompt that
   cannot finish in 3s. Resolver picks haiku as before
   (`resolution_source: route_cache`).
3. Watchdog SIGTERM kills the claude subprocess at the 3s mark
   (TIMEOUT marker in stderr.log). `exit_code` file = 143.
4. `run.sh` calls `record-outcome --model haiku --task-type build
   --exit-code 143` — non-zero, recorded as a failure.
5. Cache delta vs pre-test:

```
haiku:build      9s/1f → 9s/2f   (last_used → 14:32:30Z, success rate 90% → 82%)
```

6. `/orchestrator` re-fetched: rendered success rate for haiku in
   the build row drops from 90% to 82% (`grep -c "82%"` returns 2,
   one per occurrence in the panel).

This proves the cache writes failures symmetrically to successes,
the surface reflects the new rate immediately, and the
preferences-shift half of the §ACD headline_mechanic ("watch
per-task-type model preferences shift as the route_cache learns")
fires end-to-end in both directions.

Resolver still picks haiku for build post-failure (haiku 82%
> opus 25%) — no model-swap event yet. Displacement would need
many more haiku failures or many opus successes; that is a
separate test of the "best model can change" property, captured
as future work if it ever matters operationally.

## Closure status — OPEN (5th-incident, see G-064)

This artefact captures wire-level evidence that the substrate works
when invoked. It does NOT capture evidence that the substrate is
invoked in the framework's normal operation. Every cache row in this
demo was populated by synthetic verification dispatches (T-1669,
T-1680, T-1682, T-1681 patch verification). Zero cron jobs and zero
framework subsystems autonomously call `fw termlink dispatch`. The
dispatch preamble is documentation; nothing in everyday workflow
acts on it.

This is the §ACD substrate-vs-deliverable conflation in its
cleanest form. The arc shipped a tool. Nothing uses the tool except
the agent, manually, while running tests on the tool.

The user pattern-matched this on 2026-05-02 ("we again are missing
on essential") — the 5th-incident self-application failure on this
arc (after T-1626, T-1633, T-1641 reconsideration, T-1667 RCA,
T-1670 4th-incident). Default-to-OPEN per §ACD applies.

**The gap is registered as G-064** in
`.context/project/concerns.yaml` with three candidate consumer paths
(audit refactor / cron health-check / opt-in `--via-orchestrator`
flag). Pick one, ship it, let it run for a week of real workload,
then re-evaluate closure.

`fw arc close orchestrator-rethink` is intentionally NOT documented
here. Closure belongs to the human (T-1671 gate) AND requires
evidence of autonomous consumption — neither this README nor any
future agent-only verification cycle satisfies that bar.
