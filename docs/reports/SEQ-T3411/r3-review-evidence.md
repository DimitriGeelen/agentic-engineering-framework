# VALUE REVIEW — Round 3 evidence file (T-3411, seq:T-3411)

Facts only, no classification. Cited by `r3-review.md` §6.

| ID | Source | Status | Data point | Window | Kind |
|---|---|---|---|---|---|
| E0 | `date -u` | measured | Session start: `2026-09-22T07:58:40Z` | instant | structure |
| E1 | `git status -sb` | measured | `bleeding-edge...origin/bleeding-edge [ahead 1]` — down from round 2's end-state ("2 remain local-only") to 1 | live | structure |
| E2 | `git log origin/bleeding-edge..HEAD --oneline` | measured | Single unpushed commit: `38326625e T-3411: SEQ round 2 procAsFit handback — 3 tasks closed, 2 commits blocked on push contention` | live | structure |
| E3 | Recent-commits banner (session start) | measured | `21060b659 T-3419: sync vendored copies...` and `24718eb14 T-3419: close...` both present in the 5-commit tail shown at session start, consistent with them now being on origin | live | structure |
| E4 | `.context/working/focus.yaml` read BEFORE this worker called `fw context focus` | measured, direct read | `current_task: T-3418` (a real, unrelated, concurrently-active task) — third consecutive round this worker observed the shared-focus fallback pointing at a different foreign task (round 2 saw `T-3414`) | instant, pre-mutation | friction |
| E5 | `ls .context/working/focus.*.yaml` | measured | No `focus.seq-t3411-r3-review.yaml` existed before this worker ran `fw context focus`; round 1's and round 2's own session-local focus files (`focus.seq-t3411-r1-procasfit.yaml`, `focus.seq-t3411-r2-review.yaml`, `focus.seq-t3411-r2-procasfit.yaml`) exist and are each named per-worker, confirming the fallback is a spawn-time gap (no file yet), not a naming bug | live | friction |
| E6 | `grep -n "zzz-default" CLAUDE.md` | measured | No match (exit 1) — clean | instant | structure |
| E7 | `python3 -c "yaml.safe_load(...)"` on `.context/working/.gate-bypass-log.yaml` | measured, independent re-parse | Parses OK, 1212 entries (round 2 cited 1211 — +1, consistent with one new Tier-2 bypass since round 2, see E13) | instant | structure |
| E8 | `.context/audits/unit-suite/runs.log` tail | measured | New cron cycle since round 2: `2026-09-22T01:03:01Z START ... 2026-09-22T03:03:01Z DONE runner_exit=1 bats_rc=124 pytest_rc=124` — same failure signature as the prior two cycles (`2026-09-20`, `2026-09-21`, both also `bats_rc=124 pytest_rc=124`) | crosses round 2's named re-check boundary (round 2 expected the next cycle at `2026-09-23T03:03Z`; the actual next cycle ran a day earlier, at `2026-09-22T03:03Z`, because the cron is daily and round 2 miscounted from its own clock) | usage/friction |
| E9 | `.context/audits/2026-09-22.yaml` mtime + content grep | measured | File mtime `09:57:54 +0200` (≈ session-concurrent, later than round 2's cited `06:32:21Z` run); `grep -i "hook.write.blind"` → no match | live, fresher than round 2's citation | structure |
| E10 | `find .tasks -iname "*T-3416*"` + status grep | measured | `status: work-completed` — matches procAsFit handback's claim (diagnosis-only close) | live | structure |
| E11 | `find .tasks -iname "*T-3302*"` + status/owner grep | measured | `status: started-work`, `owner: human` — unchanged across all 3 rounds | live | structure |
| E12 | `find .tasks -iname "*T-3414*"` + AC/status grep | measured | File still at `.tasks/active/T-3414-...md`. All 4 Agent ACs read `[x]` (ticked), including "The push that was blocked now succeeds — `8bd9b13ec..551c22595`..." — but `status: started-work`, never transitioned to `work-completed` despite complete work | live | friction |
| E13 | `termlink channel snapshot seq:T-3411 --as-of <now-ms>` | measured, direct hub read | 9 rows total, rows [0]-[7] match rounds 1-2 exactly (dispatched/complete pairs for review+procasfit); row **[8]: `round=3 step=review worker=seq-t3411-r3-review status=dispatched result=docs/reports/SEQ-T3411/r3-review.md ts=2026-09-22T07:58:01Z`** — this worker's own dispatch, schema-correct, observed one round earlier than round 2 recommended spot-checking | live | structure |
| E14 | `fw sidecar inbox` (checked 2×: session start, pre-write) | measured | `no pending consults on sidecar:seq-t3411-r3-review` both times — third consecutive round with zero inbound consults on any of the 3 review-worker addresses tried so far | live | usage |
| E15 | `fw sidecar status` (new command, T-3417, not available in rounds 1-2) | measured, but self-reported (tool's own help text: "never asks the hub") | `messages total: 6 pending: 0`; `ack ledger: STORED 0 INJECTED_NOW 6 INJECTED_LATER 0 UNKNOWN 0`; `inbox cursors:` shows every one of the 5 sequence-worker addresses (`r1-review`, `r1-procasfit`, `r2-review`, `r2-procasfit`, `r3-review`) at cursor `@0` — none has ever received a delivered envelope. The "6 messages total" matches round 2's E9 finding (T-3407's own acceptance demo), not new organic traffic | live, but same self-reporting caveat Ground Rules flag ("a channel cannot report its own failures" — this reads local outbox/ledger, not an independent hub-side count) | usage |
| E16 | `find .tasks -iname "*T-3417*"` + status grep | measured | `status: started-work` — the observer command exists and runs, but the task that built it is not yet closed | live | structure |
| E17 | `grep -n "zzz-default" .agentic-framework/docs/generated/components/{lib-tasks,web-blueprints-tasks,web-templates-tasks}.md` | measured | All 3 files still contain the stale `zzz-default.md` reference | live | structure |
| E18 | Same grep against main-repo `docs/generated/components/*.md` (non-vendored) | measured | Zero matches — clean, confirming the fix landed in the live/authoritative copy | live | structure |
| E19 | `stat -c '%y'` on both copies of `lib-tasks.md` | measured | Main-repo copy: `2026-09-22 09:41:48` (regenerated this morning, session-concurrent). Vendored `.agentic-framework/` copy: `2026-08-14 08:22:31` — over 5 weeks stale, unrelated to T-3419's activity | instant | structure |
| E20 | `bin/fw vendor self --check` | measured | `Self-vendor: vendored .agentic-framework/ in sync with source` — reports clean despite E17-E19's content/mtime drift | instant | friction |
| E21 | `grep -n "Vendored-path-touching" -A8 CLAUDE.md` | measured, direct source read | Gate's declared scope: `bin/fw`, `lib/`, `agents/`, `policy/`, `web/`, `.tasks/templates/` — **`docs/generated/` is not named**, so E17-E20 is an acknowledged scope gap, not a gate miss | instant | structure |
| E22 | `grep -n "zzz-default" agents/audit/audit.sh .agentic-framework/agents/audit/audit.sh` and same for `lib/templates/claude-project.md` | measured | Zero matches in either main or vendored copy for both files — these two (in-scope) vendored-path fixes from T-3419 are confirmed clean and in sync | instant | structure |

## Non-use diagnosis — Δ4 (sidecar delivery observability), carried forward

| Reading | Evidence found this round |
|---|---|
| A BROKEN | No evidence of failed delivery attempts; nothing errors when exercised |
| B NEVER WIRED | Does not apply — the mechanism is proven reachable (T-3407's own demo, round 2's E9) |
| C UNDISCOVERABLE | Does not apply — the channel is documented in the driver prompt and used correctly by this very sequence |
| D UNMEASURED | **Still the best-fit reading.** T-3417 (E15, E16) is a real, partial step toward instrumentation, but self-reads local state only — an independent hub-side drop counter still does not exist. Organic (non-demo, non-sequence-internal) cross-agent traffic to any of these 5 addresses remains unobserved after 3 rounds |
| E NOT WANTED | No positive reason found; contradicted by T-3417's existence (someone is actively building instrumentation for this channel) |

**Reading: D (unmeasured), trending toward resolution** — T-3417 is the concrete ADD instance round 1/2 called for, in progress, not yet complete, and not yet independent of the channel's own bookkeeping.
