# VALUE REVIEW — Data Map C: What do we actually record? (T-3370, GATHERER-C)

Date: 2026-09-16. Scope: read-only survey of `/opt/999-Agentic-Engineering-Framework`. Everything below comes from a
path or a command whose output I saw. Where something is missing I say ABSENT. **Absent does not mean zero.**
I ran no `fw` verbs. Scratch files went to `/tmp/gc-*` only.

---

## TL;DR

- **The record looking back is large and mostly event-level.** The richest sources are git (9,222 commits, 9,146 with a
  `T-NNN` prefix), the dispatch ledger (2,358 rows), reviewer feedback (4,590 events), episodic files (2,887) and
  handovers (1,876 `S-*.md`).
- **Actual token spend is only partly recorded.**
  - Dispatched workers: tokens are recorded for 739 dispatches across 111 tasks, and USD cost for 725 of them
    ($849.61 in total).
  - Main session: a cumulative per-transcript snapshot is kept in handover frontmatter (1,414 handovers). No
    per-task figure is recorded anywhere. The raw transcripts have been evicted before 2026-08-17.
- **"Predicted" value is mostly not a prediction.** 2,099 of the 2,850 completed tasks that carry
  `bvp_scores_proposed` got their first estimate *after* `date_finished`.
- **"Predicted" cost is mostly empty.** Only 733 of 2,886 completed tasks carry `cost_estimate_proposed`, and 559 of
  those 733 are all `no-signal`.
- **Confirmed values do not exist.** `bvp_scores:` and `cost_estimate:` (the confirmed fields) appear on **0** tasks.
- **Operator complaints have no structured record.** `feedback-stream.yaml` holds *reviewer-scanner* events, not
  operator feedback.
- **Best route to a subsystem: files touched by the task's commits.** 1,681 of 2,886 completed tasks can be
  attributed that way. The `components:` field covers 1,206 and tags cover 806. Arc membership (`arc_id`) covers 296.

---

## TASK 1 — Recording inventory

Legend for retention: APPEND = append-only; OVERWRITE = rewritten in place; ROLL = rolling eviction;
GIT = the file is tracked, so git history keeps its old versions.

### 1.1 `.context/` top level

| Signal | Path | Writer | Granularity | Retention | Range | Volume |
|---|---|---|---|---|---|---|
| Dispatch envelope. Fields: task_id, task_type, workflow, worker_kind, model, effort, origin, task_snapshot; for 739 rows also `terminal_event` (usage tokens, cost, duration_ms) | `dispatches.jsonl` | `fw resolver dispatch` / `lib/resolver` (17 code refs) | per dispatch | APPEND, GIT | 2026-05-03 → 2026-09-16 | 2,358 rows, 3.8 MB, 586 distinct tasks |
| Dispatch outcome. Default evaluator: verification_passed, ac_satisfied, ac_total/checked (880 rows). Verdict/rationale/confidence (1,828 rows) | `dispatch-outcomes.jsonl` | `fw outcome backprop`; hook in `update-task.sh` | per dispatch-evaluation event | APPEND | 2026-05-03 → 2026-09-15 | 2,853 rows, 1.2 MB |
| Dispatch payloads: prompt.txt, stream-json | `dispatch-blobs/YYYY-MM/<uuid>/` | dispatcher | per dispatch | APPEND (monthly dirs) | 2026-05 → 2026-09 | 3,093 files, 214 MB |
| Inbox observations. Fields: id, text, captured, context_task, tags, status, promoted_to | `inbox.yaml` | `fw note` / observe agent (10 refs) | per observation | APPEND + status edits | 2026-02-14 → 2026-09-16 | 410 obs (218 pending, 129 dismissed, 60 promoted, 3 resolved) |
| OBS-class concern register. Fields: detected_in, related, fixed_in, observed, root_cause, prevention | `concerns.yaml` | agent (hand-edit) | per concern | APPEND + status edits | observed dates to 2026-09-05 | 24 entries (13 open, 9 resolved) |
| Tier-2 bypasses | `bypass-log.yaml` | git hooks / bypass paths | per bypass | APPEND | 2026-02-13 → 2026-08-23 | 110 entries |
| BVP driver proposals | `bvp-driver-proposals.jsonl` | `fw bvp` driver verbs | per proposal / state change | APPEND | 2026-06-11 → 2026-08-06 | 105 rows |
| BVP weight history | `bvp-weight-history.yaml` | `fw bvp` | per weight change | APPEND | 2026-06-11 (all) | 5 entries |
| BVP auto-promote log | `bvp-auto-promote-log.yaml` | auto-promote (T-1931) | per promotion | APPEND | — | **0 entries** |
| Cron registry (config, not a signal) | `cron-registry.yaml` | human/agent | — | GIT | — | 19.6 KB |

### 1.2 `.context/` subdirectories

| Signal | Path | Writer | Granularity | Retention | Range | Volume |
|---|---|---|---|---|---|---|
| Daily audit result | `audits/YYYY-MM-DD.yaml` | `agents/audit/audit.sh` | per day (gaps exist) | APPEND (a file per day) | 2026-02-13 → 2026-09-14 | 150 files |
| Cron audit runs | `audits/cron/*.yaml` + `LATEST-CRON.yaml` | cron audit | per run (15-min cadence visible) | ROLL (only the 2026-09-09 → 09-16 window is present) | 2026-09-09 → 2026-09-16 | 1,087 files |
| Reviewer daily Pass-B | `audits/reviewer/*.yaml` | `fw reviewer audit` | per day | APPEND | — | 90 files |
| Unit-suite runs | `audits/unit-suite/*.yaml`, `runs.log` | unit cron | per day | APPEND | 2026-09-08 → 2026-09-16 | 9 files + log |
| Gap closures | `audits/gap-closures.jsonl` | gap close verb | per closure | APPEND | 2026-06-10 | 3 rows |
| Arc weight changes | `audits/arc-scoped-weight-changes.jsonl` | `fw arc set-scoped-weight` | per change | APPEND | 2026-05-21 | 2 rows |
| Full-audit timing, MCP baselines, orchestrator LATEST | `audits/*.yaml` | audit | per run | OVERWRITE | — | 1 file each |
| Result bus envelopes | `bus/results/T-*/`, `bus/blobs/` | `fw bus post` | per result | APPEND (cleared by `fw bus clear`) | — | 61 envelopes + 8 blobs |
| Designer BPMN projects | `designer/projects/*` | designer | per diagram version | APPEND | — | 79 files |
| Episodic summaries. Fields: created/completed, duration_days, updates_count, metrics{wall_clock_minutes, commits, files_changed, lines_added/removed}, artifacts, challenges | `episodic/T-*.yaml` | `fw context generate-episodic` (at completion) | per task | write-once (a few are refreshed) | 2026-02 → 2026-09 | 2,887 files; `metrics.*` present on 2,884 |
| Session handovers. Frontmatter: tasks_touched, tasks_completed, token_* (see §2c), session_turns/commits/failed_tool_calls | `handovers/S-*.md` | `agents/handover/handover.sh` | per handover (≈ per session) | APPEND, GIT | 2026-02-13 → 2026-09-16 | 1,876 `.md` (2,031 files incl. manifests), 103 MB |
| Cross-agent chat archive | `message-archive/*` | TermLink bridge | per conversation | APPEND | — | 327 files, 42 MB (mostly self-test conversations) |
| Host liveness | `monitors/liveness.jsonl` | liveness cron | per minute-ish | APPEND, **stopped** | 2026-05-04 → 2026-08-14 | 10,080 rows |
| Watchtower RSS/cpu | `monitors/watchtower-rss.jsonl` | monitor cron | per 5-min-ish | APPEND | 2026-08-19 → 2026-09-16 | 7,864 rows |
| Pickups | `pickup/{processed,rejected,auto-deferred}` | `fw pickup` | per pickup | APPEND | — | 76 processed, 9 rejected |
| Project memory: learnings (710, all with `task`), decisions (563, all with `task`), assumptions (53, `linked_task`), patterns (19), practices (12), controls (27), directives (4) | `project/*.yaml` | `fw context add-*` | per entry | APPEND, GIT | learnings 2026-04-13 → 09-15; decisions 04-15 → 09-07 | as listed |
| Gap register (G-NNN) | `project/concerns.yaml` | agent / `fw gaps` | per gap | APPEND + edits | 2026-02-14 → 2026-08-16 | 113 entries; `related_task` on 62 |
| Audit time series | `project/metrics-history.yaml` | `audit.sh` | per audit run | ROLL ("30-day rolling retention", header); git keeps 568 versions back to 2026-02-22 | 2026-08-18 → 2026-09-16 | 1,053 entries |
| Scans | `scans/SC-*.yaml`, `LATEST.yaml` | `fw scan` | per scan | APPEND | 2026-02-15 → 2026-09-07 | 374 files |
| Session files | `sessions/S-2026-0407-*.yaml` | session init (early form) | per session | stale | 2026-04-07 only | 4 files |
| User-preference captures | `user-preferences/*` | preference capture | per capture | APPEND | — | 193 files |
| Research/spikes/qa | `research/`, `spikes/`, `qa/` | agents | per task | APPEND | — | 6 / 14 / 8 files |
| Task locks | `locks/T-*` | task writers | per task | residue (0 bytes) | — | 2,505 files |
| Empty dirs | `approvals/`, `circuits/`, `secrets/` | — | — | — | — | 0 files |

### 1.3 `.context/working/` (1,726 files, 2.5 GB), grouped by kind

| Kind | Examples | Writer | Retention | Volume / range |
|---|---|---|---|---|
| **Vector index** | `fw-vec-index.db` (+manifest, lock) | recall indexer | OVERWRITE | 2.67 GB — nearly all of `working/` |
| **Episodic-gen logs** | `episodic-gen/T-*.log` | episodic generator | APPEND per task | 1,092 files, 4.3 MB |
| **Reviewer sentinels** | `.reviewed-T-*` | reviewer | per task | 390 files |
| **Worker focus files** | `focus.<name>.yaml`, `focus.tl-<hash>.yaml` | dispatch/worktree focus | residue | 34 + 32 files |
| **Reviewer feedback stream** | `feedback-stream.yaml` (multi-doc YAML) | `lib/reviewer` | APPEND, GIT (334 versions) | 4,590 events, 2026-04-25 → 2026-09-16 (details in §2f) |
| **Gate bypass log (Tier 2)** | `.gate-bypass-log.yaml` | hooks (21 refs) | APPEND. **Not valid UTF-8 at byte 835**, so `yaml.safe_load` fails | 1,208 entries (`- ` lines), 2026-04-12 → 2026-09-08; 1,183 carry `task:` |
| **Recall telemetry** | `recall-telemetry.jsonl` | recall/ask surfaces | APPEND | 1,291 rows, 2026-08-15 → 2026-09-16 (rag 899, semantic 368, hybrid 24; hit 1,215, unavailable 49, miss 27) |
| **"Happiness"** | `happiness.jsonl` (source, task_id, value, reason) | agent | APPEND | 156 rows, 2026-08-16 → 2026-09-07. **All `source: agent`**, only 4 distinct task_ids (incl. `T-0000`) |
| **Continuous-run events** | `continuous-run.jsonl`, `.stop-driver.log`, `.continuous-mode*.yaml` | claude-fw wrapper, `stop-driver.sh` (Stop hook) | APPEND | 90 rows (2026-08-29 → 09-11); stop-driver 421 lines (from 2026-08-26) |
| **Compaction log** | `.compact-log` | PreCompact hook | APPEND | 972 lines, 2026-02-17 → 2026-09-16 |
| **Session quality metrics** | `.session-metrics.yaml` | `agents/context/session-metrics.sh` (called by handover) | OVERWRITE, GIT (257 versions since 2026-04-04) | turns, tool_calls, commits, failed_tool_calls, productive_turns (cumulative + per-session). **No tokens.** |
| **Budget gate state** | `.budget-status`, `.prev-token-reading`, `.session-baseline`, `.budget-gate-counter` | `budget-gate.sh`, `checkpoint.sh` | OVERWRITE, GIT (`.budget-status` 185 versions; `.session-baseline` 9, since 2026-09-07, which records the transcript path) | current tokens only. `.budget-status` still says `session_id S-2026-0907-1917` while `.session-baseline` is from 2026-09-16, so the files are out of sync |
| **Hook telemetry** | `.hook-counter`, `.hook-failure-counter`, `.hook-crashes.log`, `.tool-counter`, `.edit-counter`, `.prompt-counter`, `.commit-counter` | `lib/hook-telemetry.sh` `fw_record_hook_fire` (every `fw hook`) | OVERWRITE, `name=count`. Current `.hook-counter` totals ~160/hook, so it looks per-session. The reset site was not located (**UNVERIFIED**). GIT has 429 versions of `.hook-counter` | per hook name |
| **Loop detect** | `.loop-detect.json` | loop-detect PostToolUse | OVERWRITE (last 4 calls) | 4 entries |
| **Session/focus state** | `session.yaml`, `focus.yaml`, `arc-focus.yaml` | `fw context` | OVERWRITE, GIT (616 / 786 versions) | the git history of `focus.yaml` is a time series of focus switches |
| **Mirror/push/bridge logs** | `.mirror-sync.log` (1.0 MB), `.push-state.json`, `.pickup-bridge.log`, `.publish-learning-bus.log`, `.ff-push-*.log`, `.fleet-*` | mirror cron, push, bridges | APPEND / OVERWRITE | — |
| **Watchtower runtime** | `watchtower.{log,pid,port,url}` | `bin/watchtower.sh` | OVERWRITE | — |
| **Doctor profiling** | `doctor-trace.log` (1.1 MB), `doctor-timing.txt`, `.doctor-profile.txt` | one-off profiling | frozen 2026-08-18 | — |
| **Reviewer overrides** | `reviewer-overrides.yaml` | `fw reviewer override` | APPEND + prune | 99 overrides, all with task_id |
| **Consolidation report** | `consolidation-report.yaml` | learnings consolidation | OVERWRITE | 659 stale / 653 recs (2026-08-17) |
| **Pending cross-host updates** | `pending-updates.yaml` | `fw pending` | APPEND | 12 (2026-04-24 → 08-23) |
| **Verify queue / escalation drift / BPMN promote audit** | `.verify-queue-state.json`, `escalation-drift-LATEST*.yaml`, `.bpmn-promote-audit.jsonl` (93 rows, 2026-07-19 → 09-16) | respective verbs | mixed | — |
| **Ad-hoc task scratch** | `T-*-dispatch-prompt.md`, `.t3080-*.out`, `t3070-*`, `t3123/`, `T-2784-after-run.log` (771 KB) | agents, by hand | residue | ~60 files |
| **Legacy db** | `qa_feedback.db` | — | frozen 2026-02-24 | 12 KB |

### 1.4 Sinks the code names but that do not exist on disk (ABSENT)

The code references these paths, but none of them exists on disk:
`working/subagent-returns.jsonl`, `working/session-end.log`, `triage-dispositions.jsonl`, `provisions.jsonl`,
`circuits/registry.jsonl`, `govd/{state.json,audit.jsonl,relay-audit.jsonl}`, `audits/arc-abandon.jsonl`,
`audits/arc-bypass.jsonl` (named by CLAUDE.md §ACD), `audits/arc-scoped-driver-{removals,bypass}.jsonl`,
`harvest.log`, `project/{received-learnings,gaps,risks}.yaml`, `working/.bare-path-violations.yaml`,
`working/.revisits-due.txt`, `audits/upgrades.yaml`, `working/{stop-guard,subagent-stop}.log`,
`working/.session-silent-scanner.log`, `working/.subscribe-learnings-bus.log`.
Method: grepped path literals in `bin lib agents web` (`*.sh`, `*.py`), then checked each with `[ -e ]`.
An ABSENT sink means either that the code path never fired or that it writes somewhere else. I did not
distinguish the two (UNVERIFIED).

### 1.5 Hooks (`.claude/settings.json`) and what they write

Every hook runs as `bin/fw hook <name>`, and each fire increments `.hook-counter`
(`lib/hook-telemetry.sh:27`). Beyond that counter:

| Hook | Event | Writes |
|---|---|---|
| budget-gate | Pre Write/Edit/Bash | `.budget-status`, `.budget-gate-counter`, `.prev-token-reading` |
| checkpoint | Post * | `.budget-status` fallback; auto-handover; `.restart-requested` |
| check-active-task, check-tier0, check-arc-id, check-inception-*, check-human-ac-tick, check-heredoc-cmd-sub, check-worktree-governance-write, check-onboarding-gate, check-active-completed-dup, check-project-boundary | Pre | on bypass: `.gate-bypass-log.yaml` (otherwise block only) |
| loop-detect | Post * | `.loop-detect.json` |
| error-watchdog | Post Bash | UNVERIFIED (not traced) |
| audit-task-tools, check-dispatch, check-agent-dispatch, check-fabric-new-file, check-settings-edit, commit-cadence, check-rail-mcp-label, block-* | Pre/Post | UNVERIFIED beyond the counter |
| pre-compact | PreCompact | `.compact-log`, `.pre-compact.*`, emergency handover |
| post-compact-resume | SessionStart | reads mainly |
| stop-driver.sh | Stop | `.stop-driver.log` |

### 1.6 Task frontmatter fields in use (parsed YAML, not template text)

| Field | Completed (2,886): present / populated | Active (471): present / populated |
|---|---|---|
| bvp_scores_proposed | 2,850 / 2,850 | 469 / 469 |
| cost_estimate_proposed | 733 / 733 | 405 / 405 |
| **bvp_scores** (confirmed) | **0** | **0** |
| **cost_estimate** (confirmed) | **0** | **0** |
| components | 2,664 / 1,206 | 470 / 215 |
| tags | 2,853 / 806 | 471 / 205 |
| related_tasks | 2,800 / 564 | 471 / 185 |
| arc_id | 296 / 296 | 139 / 139 |
| target_blast_radius, voi_score | 456 / 456 | 32 / 32 |
| date_finished | 2,886 / 2,867 | 471 / 265 |
| horizon | 2,769 / **0** | 471 / 469 |
| priority, agents (legacy) | 53 / 53 | — |
| inception_decisions / unlocks_inception_decision | 8 / 6 | — / 6 |

Workflow mix in completed: build 2,098, inception 457, test 151, refactor 149, specification 18, design 12,
decommission 1.

### 1.7 Git

- 9,222 commits, 2026-02-13 → 2026-09-16. 9,146 subjects start with `T-NNN`; 48 subjects contain no task ID.
- About 2,006 commits are handover-type (subject contains "handover"). I excluded them from effort counts.
- Trailers:
  - `Co-Authored-By:` 3,916.
  - Free-form "trailers" by convention (`Fix:` 158, `Tests:` 92, `Recommendation:` 74, `Origin:` 48, `Arc:` 18,
    `Regression:` 20, `Symptom:` 15). These are not structured or enforced.
- Tracked `.context/working/*` files turn git into a **time-series store** for overwritten state: `focus.yaml`
  (786 versions), `session.yaml` (616), `metrics-history.yaml` (568), `.hook-counter` (429),
  `.session-metrics.yaml` (257), `.budget-status` (185).
- Anomaly: `T-012` has 375 non-handover commits and `T-1687` has 156. The T-012 count is probably ID reuse from the
  early era (UNVERIFIED).

### 1.8 Outside the repo (host only)

- `~/.claude/projects/-opt-999-Agentic-Engineering-Framework/`: 300 transcript `.jsonl` files, 530 MB. The oldest
  surviving file is from **2026-08-17**, so earlier transcripts have been evicted by the Claude Code host.
- `fw costs` (`lib/costs.sh:6`) reads these files live and persists nothing itself.

---

## TASK 2 — Realized-value join feasibility

### (a) Predicted value: `bvp_scores_proposed`

- **Available per task.** Present on 2,850/2,886 completed and 469/471 active tasks.
- Shape: a list of `{ts, estimator, scores{D1..D4,[F*]}, rationale, rubric_sha}`.
- All 6,746 entries come from `bvp-estimator-v1-heuristic`.
- **Not a forward prediction for most tasks:**
  - First estimate came *after* `date_finished` on 2,099 tasks.
  - Came before it on 732.
  - No usable date on 19.
- In the latest entry, 779 tasks have every driver as `no-signal`; 2,071 have at least one signal.
- Confirmed `bvp_scores`: **ABSENT (0 tasks)**.

### (b) Predicted cost: `cost_estimate_proposed`

- **Available per task, sparsely.** Present on 733/2,886 completed and 405/471 active tasks.
- On completed tasks the estimate predates finish in 707 cases (so it *is* forward-looking) and postdates it in 20.
- 559 of the 733 are all `no-signal`, leaving **174** completed tasks with a non-default cost prediction.
- Confirmed `cost_estimate`: **ABSENT (0)**.

### (c) Actual tokens

- **Dispatched workers: available per dispatch, and so per task.**
  - `dispatches.jsonl` `terminal_event.usage.*`, `modelUsage.*.costUSD`, `total_cost_usd`, `duration_ms`.
  - Tokens on 739 rows; cost on 725 rows, totalling $849.61.
  - Covers 111 distinct tasks, 2026-06-25 → 2026-09-05.
  - By worker: TermLink 719, ollama-thin-loop 14, ollama-loop 6.
  - The other 1,619 dispatches (ollama `ask` / escalation-triage, and earlier TermLink runs) have no usage.
- **Main (parent) session: per session, cumulative, and not attributable to a task.**
  - Handover frontmatter `token_usage` / `token_input` / `token_cache_read` / `token_cache_create` / `token_output`
    appear on 1,414 of 1,876 handovers (2026-04-03 → 2026-09-16).
  - The value comes from `costs_main current` (`agents/handover/handover.sh:618-628`). It is **cumulative for the
    current transcript**, e.g. `258.8M tokens, 1369 turns`, and it grows across successive handovers.
  - Per-session deltas would need the transcript identity. Handovers do not record it. `.session-baseline` does,
    but it is overwritten and has only 9 git versions (since 2026-09-07).
- **Other files checked:**
  - `.session-metrics.yaml`: turns, tool calls, commits only. **No tokens.**
  - `metrics-history.yaml`: audit counts only. **No tokens.**
  - `dispatch-outcomes.jsonl`: **no tokens.**
  - `episodic/*.yaml`: 131 files mention "token" in text, but there is no token field.
- **Per-task main-session tokens: ABSENT.** The raw transcripts that could be re-mined survive only from 2026-08-17.

### (d) Actual effort and rework

- **Commits per task (git, excluding handover commits):** available per task. 2,701 of 2,886 completed tasks have at
  least one commit. Median 2, p90 4, max 375 (T-012 anomaly).
- **Episodic `metrics`** (wall_clock_minutes, commits, files_changed, lines ±): available per task on 2,884 of 2,887
  episodic files. `duration_days` is on 2,884.
- **Task age:** `created` and `date_finished` are available on 2,867 completed tasks.
- **Status transitions** (`status: X → Y` lines in the task body): available per task.
  - Distribution: 0 transitions 67, 1 → 1,857, 2 → 860, 3 → 66, 4+ → 36.
  - Only **6** completed tasks ever passed through `issues`.
  - Only **2** were reopened (`work-completed → …`).
  - The `issues` state is barely used, so it is not a usable rework signal.
- **Sessions touching a task:**
  - Handover `tasks_touched` appears on 1,844 handovers, and 1,936 completed tasks appear in at least one.
  - The median is **15 sessions** (max 188), which is implausible for median-2-commit tasks. The field appears to
    list every task file modified in the session tree, including bulk syncs. **Noisy; do not trust it as effort
    without cleaning.**

### (e) Remediation

- **`## RCA` sections:** 1,173 completed tasks have one; 502 contain more than 200 characters of non-comment text.
  Available per task.
- **Healing events:**
  - No healing event log exists as a file (**ABSENT**).
  - `project/patterns.yaml` holds 19 patterns with `learned_from`.
  - The `issues` status that triggers healing appears in only 6 tasks.
- **Cause links:**
  - Explicit phrasing ("regression from / caused by / introduced by / broke by T-NNN") appears in only **14**
    completed tasks.
  - Looser `origin`-style T-refs appear in 1,019, but those mix design lineage with cause.
  - `related_tasks` is populated on 564.
  - Cause is **not structurally available**. It exists only as free text.
- **Registers:** `project/concerns.yaml` (113 gaps) has `related_task` on 62, `resolved_by_task` on 7 and
  `follow_up_task` on 14. `concerns.yaml` (24 OBS-class entries) has `detected_in` on 24 and `fixed_in` on 7.

### (f) Operator complaints

- **`feedback-stream.yaml` is not operator feedback.** It holds 4,590 reviewer-scanner events: scan_emitted 2,167,
  verdict_recorded 2,167, override_applied 125, recommendation_claims_verdict 116, auto_tick 12, override_expired 2,
  rendering_concern 1. They cover 1,421 distinct tasks, 2026-04-25 → 2026-09-16. Verdicts: PASS 1,416,
  CONCERN 715, FAIL 36. This is available per task as *automated quality signal*.
- **`happiness.jsonl`:** every row is agent-sourced, and there are only 4 task IDs. It is not operator signal.
- **Operator pushback in task bodies:** phrase grep found 65 completed tasks. Phrases used: "pushback",
  "operator said/asked/noted/flagged/objected", "user/operator/human caught", "user/operator feedback",
  "operator pushed back", "human corrected", "corrected by …".
  - This is free text: **low recall, unstructured, per task only.**
- **No structured operator-complaint record exists (ABSENT).** Other partial proxies: 110 Tier-2 entries in
  `bypass-log.yaml` and `user-preferences/` (193 captures, not examined in depth).

### (g) Bugs and issues produced

- **Bug-class tasks:** 549 completed tasks match bug/fix/error/regression/broken/crash in their name or tags
  (regex; approximate).
  - Their link back to the *causing* task is free text only; see the 14 explicit cause links in (e).
- **`inbox.yaml` (410 observations):**
  - Has `context_task` on 381. This is the task **in focus when the observation was captured**, not necessarily
    its cause.
  - 406 of 410 mention some T-ID in text.
  - `promoted_to` is set on 64.
- **`concerns.yaml` (24):** `detected_in` is on all 24 (the task where the problem was *seen*); `related` is a T-ID
  list on 22.
  - These are **per task where seen**, not per task that caused it.
- **Summary:** "produced-by" attribution is **NOT AVAILABLE** structurally. "Seen-during" is available.

### Availability matrix

| Signal | Per task | Per arc | Per area | Coverage |
|---|---|---|---|---|
| (a) predicted value | YES (mostly retrospective) | via arc_id (296) | via route in Task 3 | 2,850/2,886; only 732 forward-looking |
| (b) predicted cost | YES (sparse) | via arc_id (107 completed have both) | via Task 3 | 733/2,886; 174 non-default |
| (c) actual tokens | workers only | workers only | workers only | 111 tasks / 739 dispatches; main session ABSENT per task |
| (d) effort/rework | YES (commits, episodic metrics, age) | via arc_id | via Task 3 | 2,701–2,884; issues/reopen too rare to use |
| (e) remediation | RCA yes; cause link free text | — | — | RCA 1,173 (502 substantive); cause 14 explicit |
| (f) operator complaints | free text only | — | — | 65 phrase hits; reviewer stream 1,421 tasks is machine signal |
| (g) bugs produced | seen-during only | — | — | inbox 381 context_task; concerns 24 detected_in |

---

## TASK 3 — Attributing tasks to subsystems

| Route | Coverage (completed, 2,886) | Quality |
|---|---|---|
| **Files touched by the task's non-handover commits** (`git log --name-only`, subject `^T-NNN`). Excludes `.tasks/ .context/ docs/ .fabric/ tests/ .agentic-framework/ VERSION` | **1,681** attributable (2,324 if tests/docs count). 522 of the 1,681 span more than one subsystem. Another 377 tasks have commits touching only `.tasks/` / `.context/` | Best. Mechanical and reproducible. Dominant area counts: lib 330, web 295, bin 206, agents/context 164, agents/audit 135, agents/task-create 76, tools 65, CLAUDE.md 56, agents/git 42, policy 33, agents/termlink 31, agents/fabric 26, lib/reviewer 20 |
| `components:` field | 1,206 populated | Paths plus fabric IDs (`C-004`); 805 entries are `tests/…`. Set only at work-completed (per CLAUDE.md) |
| `.fabric/components/*.yaml` `subsystem:` (to map files to named subsystems) | 1,268 cards; **534 are `unknown`** | Useful as a lookup table, but 42% unknown |
| `tags` | 806 populated, 778 distinct tags | Inconsistent vocabulary (governance 71, pickup 71, watchtower 69, termlink 33, bvp 30, fabric 21) |
| `arc_id` | 296 (orchestrator-rethink 105, arc-grooming 34, value-prioritisation 32, continuous-run 23, …); 21 distinct values | Thematic, not structural; low coverage. `arc:*` tags also exist (e.g. `arc:continuous-run` 27); total not counted |

**Winner: git commit file paths**, optionally mapped through fabric `subsystem:` where it is known. Caveats:

- Tasks predating the `T-NNN:` subject convention are not covered.
- 185 completed tasks have no commit.
- Multi-area tasks need a split rule, e.g. dominant area or fractional attribution.
- Designer and BVP do not appear as top-level path areas. They live under `lib/`, `agents/` and `web/`, so they
  need a finer path map (for example `lib/bvp*`, `agents/designer`, `agents/bpmn` 9).

---

## Method notes and caveats

- Parsers were Python and PyYAML. `feedback-stream.yaml` is multi-document and needs `safe_load_all`.
  `.gate-bypass-log.yaml` is not valid UTF-8, so I counted its entries by grep.
- Status transitions were counted from `status: X → Y` lines. My first regex undercounted, and I corrected it; the
  figures above are the corrected ones.
- "Bug-class" and "pushback" counts are regex estimates over the whole corpus, not sampled. Treat them as
  approximate.
- The dispatch figures in CLAUDE.md (1,339 dispatches / 1,838 outcomes) are stale; the files now hold 2,358 / 2,853.

## VERBS I RAN

None. No `fw` verbs were run. Only `git log/show/rev-list`, `ls/find/du/wc/grep/sed/head/tail` and Python readers.
