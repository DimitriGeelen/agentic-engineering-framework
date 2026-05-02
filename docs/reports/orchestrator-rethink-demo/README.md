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

## Closure

This artefact is the wire-level evidence required by §ACD / G-062 to
close the arc. After three pushbacks where the agent recommended
closure on substrate (T-1626, T-1633, T-1641, T-1667 RCA), this is the
first demo that shows the headline_mechanic firing end-to-end.

To close the arc:

```bash
bin/fw arc close orchestrator-rethink \
    --demo docs/reports/orchestrator-rethink-demo/ \
    --decision "shipped — headline mechanic verified live on 2026-05-02 \
                across 3 task_types with 3 real workers"
```
