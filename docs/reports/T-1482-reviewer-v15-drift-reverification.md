# T-1482 — Reviewer v1.5 Drift Re-verification: Sandbox Isolation Strategy

**Status:** inception (exploration in progress)
**Parent arc:** T-1442 (I-A) → T-1443 (I-B) → T-1445 v1.0 → ... → T-1450 v1.5a → **T-1482 v1.5 (this)**
**Related:** T-1447 v1.2 (Layer 3 audit cron — extension point), T-1449 v1.4 (TTL'd overrides — fallback when re-verify fires false positives)

## 1. Why this exists

T-1445 v1.0 ships a **static-scan validator** — pattern-match across task body. Today's gap: a verification block that passed at completion time can silently rot. Three failure modes:

1. **Library drift** — `python3 -c "import yaml; yaml.safe_load(...)"` worked at completion; six months later the YAML file was edited and now parses as a list instead of a dict. Static scan can't see this.
2. **Tool drift** — `bin/fw doctor` exit code changes meaning when checks are added/removed. Past PASS may be today's stale.
3. **Suppressed failures rotting in plain sight** — T-1086 has `bin/fw doctor >/dev/null 2>&1 || true`. v1.0 already FAILs this via `swallowed-errors`. v1.5 should also re-run and report what doctor *currently* says.

Drift detection is the only way to discover these without manual sweep. It's also the highest-blast-radius reviewer feature: re-executing 1358+ historical commands in-place would corrupt working memory.

## 2. The four candidate strategies

| # | Strategy | Isolation | Latency | Side-effect risk | Portability |
|---|----------|-----------|---------|------------------|-------------|
| A | **git worktree** | Filesystem-snapshot of repo state, separate working dir | ~50ms setup | Medium — same `~/.claude`, same env, can still hit network | Excellent (git is required anyway) |
| B | **Diff detection (no re-execution)** | None needed | <5ms per task | Zero — pure read | Excellent |
| C | **Container (docker/podman)** | Strong (FS, network, processes) | 500ms+ setup | Low | **Violates portability directive** — adds runtime dep |
| D | **Restricted subprocess** (custom `HOME`, scrubbed `PATH`, `unshare --mount`) | Partial (FS via overlay, env scrubbed) | ~20ms setup | Medium-low | Linux-only (loses macOS) |

## 3. Spike outcomes (to be filled)

### Spike 1 — Verification block audit (50-task random sample) ✅

**Method:** Sampled 50 random completed tasks. Extracted `## Verification` block. Heuristic-classified each command line; assigned each task its worst-case category.

**Results:**

| Category | Count | % of 50 | % of tasks-with-verification (40) |
|----------|-------|---------|-----------------------------------|
| read-only (safe to re-run anywhere) | 20 | 40.0% | 50.0% |
| state-touching (need worktree isolation) | 7 | 14.0% | 17.5% |
| network-dependent (need stub or skip) | 8 | 16.0% | 20.0% |
| time-dependent | 1 | 2.0% | 2.5% |
| unclassified (heuristic gap) | 4 | 8.0% | 10.0% |
| no verification block at all | 10 | 20.0% | — |

**Key finding:** **~50% of verification blocks are read-only** (safe to re-run with no isolation). **~20% are state-touching** (need worktree). **~20% are network-dependent** (Watchtower curls, port checks) — need either a "skip if network unavailable" flag or a localhost stub. The "no verification block" 20% are silently un-checkable today; v1.5 should flag these.

**Hypothesis revision:** Pre-spike estimate was 60-75% read-only / 15-25% state-touching. Reality: 50/17.5 — meaningfully more state-touching than expected, mostly because `bin/fw audit`, `bin/fw doctor`, and `bin/fw metrics` mutate `.context/audits/` and got classified state-touching.

### Spike 2 — Worktree prototype ✅

**Method:** Two patterns benchmarked.

**Pattern A — fresh worktree per task:**
```
Avg setup:    1086ms
Avg run:       209ms
Avg teardown:  210ms
Per-task:     1506ms
```
Projection for 1358 tasks: 34min serial, 8min parallel-4.

**Pattern B — reuse one worktree, checkout per task:**
```
Initial setup: 1074ms (one-time)
Cold checkout: ~290ms (first cross to a new branch/range)
Warm checkout:  ~20ms (sequential commits)
Verification:   ~210ms (read-only example)
Avg per-task:  339ms
```
Projection for 1358 tasks: **7min serial, 2min parallel-4.**

**Conclusion:** Pattern B (reuse) is ~78% faster than Pattern A. Both fit the <10min audit-cron budget; pattern B has comfortable headroom for slow verifications (`bin/fw audit` runs ~5-10s on its own).

### Spike 3 — Diff detection (analytical, no prototype) ✅

**Resolved without code:** diff-detection's coverage gap is structural, not measurable.

| Drift type | Caught by file-hash diff? |
|------------|--------------------------|
| YAML file edited (parsed differently) | ✅ if file referenced in command |
| Tool semantics changed (`bin/fw doctor` checks added) | ❌ — `bin/fw` itself unchanged, but it sources `lib/`+`agents/` |
| Verification only checks parse, content meaning shifted | ⚠️ caught at file level, but verdict is "file changed" not "verification fails" |
| File renamed/moved | ❌ — hash lookup miss, treats as deletion |
| Bug fixed in tool, was always broken | ❌ — never picks up |

**Conclusion:** diff-detection is a **fast signal**, not a verdict. Useful as **Pass A** to flag "candidates for deep re-check" before running expensive Pass B. NOT a substitute for execution.

### Spike 4 — Restricted subprocess ❌

Disqualified at the constraint level: `unshare --mount` is Linux-only. Loses macOS portability. Not pursued.

## 4. Decision matrix (post-spike)

| Criterion | Weight | A: Worktree (reuse) | B: Diff-only | C: Container | D: Subprocess |
|-----------|--------|---------------------|--------------|--------------|---------------|
| Portability | High | ✅ git is required anyway | ✅ | ❌ runtime dep | ❌ Linux-only |
| Latency (1358 tasks) | Medium | ✅ 7min serial / 2min p4 | ✅ <30s | ❌ ~20min+ | n/a |
| Drift coverage | High | ✅ semantic + structural | ⚠️ ~40% (file-hash) | ✅ semantic + structural | n/a |
| Side-effect risk | High | ⚠️ shares ~/.claude, network | ✅ zero | ✅ low | n/a |
| Implementation cost | Medium | ⚠️ checkout-routing + hook gating | ✅ already have hashes | ❌ runtime + image mgmt | n/a |
| **Verdict** | | **PRIMARY** | **TIER (signal)** | DISQUALIFIED | DISQUALIFIED |

**Decision: hybrid A+B with B as signal layer over A.**

- **Pass A (cheap, every reviewer invocation):** diff-detection — hash files referenced in `## Verification`, compare against hash recorded in `## Reviewer Verdict`. If unchanged: skip Pass B for this task. If changed: queue for Pass B.
- **Pass B (audit cron / on-demand):** worktree-with-reuse — checkout each queued task's `date_finished` SHA in a single shared worktree, run verification commands with `FW_REVIEWER_REVERIFY=1` env (hooks short-circuit on this), capture exit codes, write to verdict.

**Network-dependent commands (20% of corpus):** classify at v1.5-build-time via the same heuristic from Spike 1; either skip with `[SKIPPED: network]` annotation in verdict, or run with `--network-stub` flag that points network calls at a localhost echo server. Default: skip (safer).

**State-touching (~17.5%):** worktree provides FS isolation but NOT process/network isolation. Acceptable for the framework's own state because worktree's `.context/` is separate; not acceptable for `~/.claude/` writes (shared). Will hard-block any verification command that writes to `$HOME` outside the worktree (regex pre-flight).

## 5. Dialogue Log

*(populated as conversations happen — per CLAUDE.md C-001 extension)*

### 2026-04-25 — inception scope set
Agent created inception under autonomous directive. Scope deliberately narrow: pick the isolation strategy, **not** build v1.5 itself. Build is a separate task once GO recorded.

## 6. Open questions

1. **What does "drift" actually mean in the corpus?** Need historical data on how often a passing verification has subsequently broken. Spike 1 may surface this.
2. **Should drift detection run on completion (instant feedback) or on a cron (efficiency)?** Probably both — Pass A on completion is sub-second per task; Pass B audit re-runs over the whole corpus weekly.
3. **What does v1.5 do when drift is detected?** Default to FAIL on the verdict; no auto-revert. The override mechanism (T-1449) handles known-broken tasks where the human accepts the rot.
4. **Pickup vs new task at decode time?** Drift FAILs need to surface somewhere — handover queue? Watchtower /reviewer page? `fw reviewer drift` CLI?

## 7. Recommendation

**Recommendation: GO** — Hybrid two-pass: diff-detection signal (Pass A) over worktree-with-reuse re-execution (Pass B). Disqualify container and restricted-subprocess.

**Rationale:**
- **Pass A alone** (diff-only) misses ~60% of meaningful drift (tool semantics, semantic shifts, file moves). Insufficient as a verdict.
- **Pass B alone** (worktree-only) is fast enough (7min serial / 2min parallel-4) but wasteful — re-runs unchanged tasks unnecessarily. Pass A as a gate cuts that further.
- **Hybrid** matches the corpus shape: ~50% read-only (Pass A reads hashes only — instant), ~17.5% state-touching (Pass B worktree handles), ~20% network (skip-with-annotation in v1.5; stub in v1.6+).
- Container (C) violates portability directive. Subprocess (D) loses macOS.

**Evidence:**
- Spike 1: 50-task sample showed 50% read-only, 17.5% state-touching, 20% network-dependent — hybrid matches the shape
- Spike 2 (reuse pattern): 339ms avg per task → 7min serial / 2min parallel-4 for 1358-task corpus, well within 10min audit-cron budget
- Spike 3 (analytical): file-hash diff catches ~40% of drift types — useful as signal, insufficient as verdict
- Spike 4: subprocess Linux-only — disqualified at constraint level

**Out-of-scope for v1.5 (deferred):**
- Network-stub server for re-running curl-based verifications (v1.6 if Pass A skipping proves too lossy)
- Per-task on-demand re-verify button in Watchtower UI (v1.6)
- Auto-quarantine of drifted tasks (v2.x — needs sovereignty model first)
- Verification block linter to push more tasks into "read-only" category (separate refactor task)

**The Human AC asks one question:** Does the hybrid Pass A + Pass B design feel right? If yes → record GO, then create a build task for v1.5 implementation. If no → drop a counter-proposal in `## Decisions`.

## 8. v1.5 Build Task (post-GO sketch)

To be created as a separate task after GO. Likely shape:
- `lib/reviewer/drift.py` — Pass A diff-detection (hash file refs, compare against verdict-stored hashes)
- `lib/reviewer/reverify.py` — Pass B worktree orchestration (single shared worktree, checkout-per-task, exit-code capture)
- Network/state heuristic classifier at hook-into-update-task.sh time (record category in initial verdict)
- `bin/fw reviewer drift T-XXX` — manual invocation
- `bin/fw reviewer audit --pass-b` — full re-execution audit (cron-friendly)
- 4-6 unit test suites + 1 integration test using a sandboxed worktree
- Verdict format extension: `## Reviewer Verdict (v1.5)` adds `pass_a_drift`, `pass_b_reverify` sections

