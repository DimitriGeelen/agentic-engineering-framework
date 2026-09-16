# VALUE REVIEW — Data Availability Map, Layer B (AEF / TermLink / Workflow Designer)

**Task:** T-3370 · **Gatherer:** GATHERER-B · **Date:** 2026-09-16
**Repo:** `/opt/999-Agentic-Engineering-Framework` · **Branch:** `bleeding-edge`
**Mode:** read-only inspection of the live filesystem. No `fw` verb was run (see §Pollution Record).

**Status legend:** `EXISTS` (data is there and readable) · `PARTIAL` (present but incomplete/narrow window/weak schema) · `DESIGNED-ONLY` (schema/spec/fixture exists, no production data) · `ABSENT` (no data — **not** zero usage).

**Counting note.** `.agentic-framework/` at repo root is a *vendored self-copy* of the framework. Every count below deliberately EXCLUDES it, except where stated. A naive `find` over the repo double-counts the corpus (87 tracked `.bpmn` → only 47 are the live corpus).

---

## Summary table

| # | Source | Status |
|---|--------|--------|
| 1 | Task ledger | EXISTS (ledger) / PARTIAL (rework signal) |
| 2 | Arcs | EXISTS / ABSENT (`affects:`/`scope:`) |
| 3 | Handovers + episodic | EXISTS |
| 4 | Upstream reports | PARTIAL |
| 5 | Install findings harness | PARTIAL (tests exist, no findings store) |
| 6 | Component fabric | EXISTS (orphans derivable) |
| 7 | `fw fabric blast-radius` | EXISTS |
| 8 | Capability registry | PARTIAL (no `policy/capabilities.yaml`); prompt-drift ABSENT |
| 9 | Prompts + dispatch templates | EXISTS |
| 10 | Audit logs (`.jsonl`) | PARTIAL |
| 11 | Gate bypass log | EXISTS |
| 12 | Gate first-pass rate | **ABSENT** |
| 13 | `fw audit` history incl. cron | EXISTS (split windows) |
| 14 | Healing events | PARTIAL (patterns only, no event log) |
| 15 | Per-verb invocation counts | **ABSENT** |
| 16 | Token telemetry per task/arc | **ABSENT** (session-level only) |
| 17 | Activity per scope | **ABSENT** (not derivable) |
| 18 | `policy/value-drivers.yaml` | EXISTS |
| 19 | BVP scores confirmed vs proposed | PARTIAL — **0 confirmed**, 3319 proposed |
| 20 | `bvp-realization.jsonl` | **ABSENT** |
| 21 | Estimator override frequency | **ABSENT** (no confirmations to diff against) |
| 22 | TermLink hub append-log / SQLite | EXISTS (retention-truncated) |
| 23 | Subscriber cursors | EXISTS |
| 24 | Presence / heartbeats | EXISTS but NOT history |
| 25 | Worker invocations | EXISTS |
| 26 | Out-of-band bus observer | **DATA GAP** (hub liveness only, not message-level) |
| 27 | Ratified vs draft workflows | PARTIAL — ratification is a *filename convention*, not recorded state |
| 28 | `aef:endpoint` per node | **DESIGNED-ONLY** (test fixtures only; zero in live corpus) |
| 29 | `aef:contextReads` / `aef:artifactsWrites` | **DESIGNED-ONLY** (fixtures only) |
| 30 | Lane + authority + tier | PARTIAL (lane authority + workflow tier default yes; per-node tier no) |
| 31 | Execution traces by node uid | **DESIGNED-ONLY** (`fw workflow run` does not exist) |

---

## AEF — WORK AND ORIGIN

### 1. Task ledger — EXISTS (ledger) / PARTIAL (rework signal)

**Location:** `.tasks/active/`, `.tasks/completed/`
**Window:** `T-001` (created 2026-02-13) → `T-3369` (2026-09-16). Continuous.

| Set | Count (`ls .tasks/<set>/T-*.md \| wc -l`) |
|---|---|
| active | **471** |
| completed | **2886** |

**Rework / reopen signals — PARTIAL, and weak.** There is **no structured rework field**. `reopen_count:` → 0 files. Tasks with `status: issues` right now → **0**. What exists is free-text only, and each is a *prose mention*, not a state transition record:

| Signal (grep over both sets) | Files |
|---|---|
| `supersed*` | 104 |
| `healing` | 93 |
| `rework` | 18 |
| `reopened` | 7 |
| `Retry` | 4 |

**Trustworthiness:** the ledger itself is append-only-by-convention (files move `active/` → `completed/`, git-tracked, so history is recoverable). But the *rework* dimension is self-reported prose. A task that went `started-work → issues → started-work` leaves **no durable trace** once it closes: the `status:` field is overwritten in place, not appended. Rework is therefore **not measurable from the ledger** — only anecdotally greppable.

### 2. Arcs — EXISTS / `affects:` ABSENT

**Location:** `.context/arcs/*.yaml` · **Count: 20**

**Statuses:** `in-progress` **17**, `draft` **3** (`ewcr-arc0-contract-evidence`, `inception-review-loop`, `ladder-trigger-producer`). **Zero** `closed` or `abandoned` arcs on disk.

**Schema (top-level key frequency across all 20):**
`status, slug, name, id, headline_mechanic, description, demo_evidence, decision, created, closed_at, anchor_task` = 20/20 each; `proposed_scoped_drivers` 16; `scoped_drivers` 15; `bvp_scores` 15; `constituent_tasks` **6**; `grill_me` 2; `design_status`/`design_doc`/`agent_close_attempt` 1 each.

**`affects:` / `scope:` → 0 arcs (ABSENT).** No arc declares a scope fence as structured data. Scope lives in `description:` prose and in the anchor task body.

**`bvp_scores:` present on 15 arcs but every one is `{}` (empty map)** — verified by parsing each file. The key exists; the value does not. Cross-check with §19.

**Trustworthiness:** hand-maintained YAML, git-tracked. `constituent_tasks` only on 6/20, so arc↔task membership mostly resolves the other way (via task `arc_id:`, see below) — two half-populated directions, neither authoritative alone.

### 3. Handovers + episodic — EXISTS

| Store | Count | Window |
|---|---|---|
| `.context/handovers/` (all entries) | 2031 | — |
| `.context/handovers/*.md` | **1880** | `S-2026-0213-1926.md` → `S-2026-0916-0549.md` (215 days, unbroken) |
| `.context/episodic/*.yaml` | **2888** | `T-002` (mtime Feb 22 2026) → `T-3364` (Sep 15 22:55) |

**Trustworthiness:** both append-only (one file per session / per task, never overwritten), git-tracked. Episodic count (2888) ≈ completed tasks (2886) — near 1:1 coverage. Content is **agent-generated self-report** (`fw context generate-episodic` at close); the *existence* of the record is mechanical, the *accuracy* of its narrative is not verified by anything.

### 4. Upstream reports — PARTIAL

**Verb exists:** `bin/fw:6896 upstream)` → `lib/upstream.sh` (`do_upstream_report`, `lib/upstream.sh:175`). It files a GitHub issue on the upstream repo; it does **not** store a report locally.

**Stored data:** `.context/working/.upstream-issues-sent` — **176 bytes, 1 entry**, dated 2026-06-07:
```
2026-06-07T11:50:26Z | https://github.com/.../issues/15 | fw update --rollback claims dual-path coverage but global path lacks rollback
```
Also `docs/upstream-patterns/openclaw` (unrelated — inbound pattern notes, not field reports).

**Trustworthiness:** a **send receipt**, not a report body. It records *that* an issue was filed, with no outcome, no resolution, no response. One entry in 215 days.

### 5. Install findings harness (greenfield install runs) — PARTIAL

**What exists (tests, not a findings store):**
- `tests/integration/fw_onboarding_greenfield.bats`
- `tests/integration/t2922_greenfield_first_inception.bats`
- `tests/unit/t2862_greenfield_first_inception_e2e.bats`
- `tests/unit/t2974_greenfield_operator_prose.bats`
- `tests/unit/upgrade_fresh_machine_simulation.bats` (CLAUDE.md §Consumer-Facing Command Hygiene)

**What does not exist:** any `.context/` store of greenfield-run findings. Findings from real greenfield runs landed as **individual task files** (T-2442, T-2443, T-2703, T-2740, T-2849, T-2851, T-2862, T-2922, T-2956, T-2974) — i.e. the harness output is the task ledger, not a dedicated log. **No run-over-run record exists**: you cannot ask "did install N+1 have fewer findings than install N".

---

## AEF — STRUCTURE

### 6. Component fabric — EXISTS; orphans ARE detectable

**Location:** `.fabric/components/*.yaml` · **Count: 1268** cards, 0 unparsable.
**Card schema:** `id, name, type, subsystem, location, purpose, tags, depends_on, depended_by, created_by, last_enriched, last_verified`.

**Orphan detection — yes, mechanically, from the cards alone:**

| Measure | Count | % of 1268 |
|---|---|---|
| Empty `depended_by` (**no dependents = orphan**) | **807** | 63.6% |
| Empty `depends_on` (leaf/root) | 334 | 26.3% |
| Total `depends_on` edges | 3065 | — |

**Trustworthiness:** cards are generated/enriched, not hand-written, and carry `last_enriched` / `last_verified` — so staleness is itself checkable. **Caveat that matters for any orphan claim:** an empty `depended_by` may mean "genuinely unused" *or* "the depending card was never enriched". The 63.6% figure is an upper bound on orphanage, not a finding. `fw fabric drift` exists to detect exactly this (unregistered / orphaned / stale) but I did not run it.

### 7. `fw fabric blast-radius` — EXISTS

`agents/fabric/fabric.sh:113` — `blast-radius)` → `do_blast_radius`. Documented at `agents/fabric/fabric.sh:11,22,68`. Also consumed as a *concept* by `lib/bvp.sh:17,245,252` (the F8 cost composite reads `cost_estimate.blast_radius`).

The verb exists. Whether its output is *stored* anywhere: no — it is computed on demand, nothing persists it. See §21.

### 8. Capability registry — PARTIAL; prompt-drift report ABSENT

**`policy/capabilities.yaml` → does not exist.** The registry that does exist is `policy/capability-overlay/tool-set.yaml` (9897 b, `last_update: 2026-06-08`, `filed_by: T-2258`, `arc_id: capability-overlay`):

| Class | Entries |
|---|---|
| `read_only` | 16 |
| `agent_authority` | 6 |
| `sovereignty_bound_excluded` | 5 |
| **total** | **27** |

Emitted manifest: `agents/mcp/framework-mcp-manifest.json` (exists).

**Prompt-drift report → ABSENT.** `grep -rn "prompt.drift\|prompt_drift"` across `*.sh`/`*.py`/`*.yaml` (excluding the vendored copy) returns **zero hits**. No such report is produced or stored.

### 9. Prompts + dispatch templates — EXISTS

| Location | Contents |
|---|---|
| `policy/prompts/` | `bvp-driver-session.md` (keystone), `artefact-template.md`, `arc-delivery-session.md`, `landing-mode.md`, `README.md`, `bvp-references/` |
| `agents/dispatch/` | `AGENT.md`, `preamble.md`, `audit.md`, `develop.md`, `enrich.md`, `investigate.md`, `single-host-parallel-demo.sh`, `yield-point.sh` |
| `docs/dispatch-templates/` | `consumer-update-worker.md`, `iw-slice-worker.md`, `iw-spike-worker.md` |
| `.context/working/dispatch-prompts/` | rendered per-task prompts (`T-3073.md`, `T-3075.md`, `T-3076.md`, `T-3077.md`, `T-3080.md`, …) |

**Trustworthiness:** the first three are git-tracked source-of-truth. `.context/working/dispatch-prompts/` is *rendered output* — a partial record (only some dispatches leave a prompt file; 2358 dispatches vs a handful of prompt files). Dispatch rows carry `template_sha` + `prompt_template` (§25), which is the reliable join, not this directory.

---

## AEF — GOVERNANCE BEHAVIOUR

### 10. Audit logs `.context/audits/*.jsonl` — PARTIAL (only two, both tiny)

| File | Lines / size |
|---|---|
| `.context/audits/arc-scoped-weight-changes.jsonl` | 473 b (last write 2026-05-29) |
| `.context/audits/gap-closures.jsonl` | 672 b (last write 2026-06-10) |

Both are **stale by months**. The bulk of audit data is **YAML, not JSONL** — see §13.

**Other JSONL across `.context/` (for completeness, since the review asks about append-logs generally):**

| File | Lines | Window |
|---|---|---|
| `.context/dispatches.jsonl` | 2358 | 2026-05-03 → 2026-09-16 |
| `.context/dispatch-outcomes.jsonl` | 2853 | 2026-05-03 → 2026-09-15 |
| `.context/monitors/liveness.jsonl` | 10080 | 2026-05-04 → 2026-08-14 (**capped ring — see §24**) |
| `.context/monitors/watchtower-rss.jsonl` | 7798 | from 2026-08-19 |
| `.context/working/recall-telemetry.jsonl` | 1289 | from 2026-08-15 |
| `.context/working/.bpmn-promote-audit.jsonl` | 93 | from 2026-07-19 |
| `.context/working/happiness.jsonl` | 156 | from 2026-08-16 |
| `.context/working/continuous-run.jsonl` | 90 | 2026-08-29 → 2026-09-11 |
| `.context/bvp-driver-proposals.jsonl` | (present) | — |

### 11. `.context/working/.gate-bypass-log.yaml` — EXISTS

**Size:** 373 815 b · **Entries: 1174** (`grep -c "^- timestamp:"`)
**Window:** `2026-04-12T11:02:43Z` → `2026-09-08T21:24:27Z` (149 days). **Note the log has not been written since 2026-09-08** — 8 days silent as of this review.

**Top 5 by flag:**

| Flag | Count | Share |
|---|---|---|
| `FW_SWITCH_FOCUS=1` | 774 | 65.9% |
| `--skip-sovereignty` | 172 | 14.6% |
| `--switch-focus` | 167 | 14.2% |
| `--skip-render-review` | 32 | 2.7% |
| `--skip-verification` | 11 | 0.9% |

(tail: `--skip-acceptance-criteria` 9, `--skip-rca` 7, `--scope-reduction-acknowledged` 1, `--i-am-human` 1. Flags sum to 1174.)

**By caller (which gate was bypassed):**

| Caller | Count |
|---|---|
| `check-active-task focus-drift` | 941 (80.2%) |
| `check_human_sovereignty` | 172 |
| `run_verification_commands` | 11 |
| `check_rca_for_bugfix` | 7 |
| `partial_complete_recheck` | 6 |
| `check_acceptance_criteria` | 3 |
| others (incl. 4 long-rationale `check_render_surface_human_ac` / `check_task_pair_acd` entries) | 6 |

**One gate (focus-drift) accounts for 4 in 5 bypasses.** Its two mechanisms (`FW_SWITCH_FOCUS=1` env + `--switch-focus` flag) together are 941/1174 = 80.2%.

**Trustworthiness — critical:** this is a **bypass** log, not a **gate** log. It records only the cases where an agent *successfully went around* a gate. It cannot report blocks that held, blocks the agent worked around by a route the hook's regex didn't match (the documented T-1890 failure mode), or blocks that never fired. **A channel cannot report its own failures** — this one reports only its own defeats. Append-only, git-tracked.

### 12. Gate first-pass rate — **ABSENT**

Not derivable from any log in this repo.

**Why, specifically.** Computing "what fraction of gate encounters passed on the first attempt" requires a denominator: *every* gate evaluation, pass and fail. What is written is only the numerator's complement — successful bypasses (§11). Checked and found nothing:
- `agents/context/check-active-task.sh` writes to `.gate-bypass-log.yaml` at lines 682, 852, 1008 — **all three are bypass-path writes**. No block-path write exists.
- `lib/inception.sh:130` and `lib/rail-identity.sh:210` — same file, same bypass-only semantics.
- `.context/working/.hook-counter` counts hook *invocations* by name (see §15) but carries **no pass/fail split**.
- No `.jsonl`/`.log` under `.context/working/` records a gate refusal as a typed event.

**ABSENT means no data — not a 100% first-pass rate.**

### 13. `fw audit` history incl. cron — EXISTS, three stores, three very different windows

| Store | Files | Window | Cadence |
|---|---|---|---|
| `.context/audits/YYYY-MM-DD.yaml` | ~155 | **2026-02-13 → 2026-09-14** (214 days) | daily |
| `.context/audits/cron/YYYY-MM-DD-HHMM.yaml` | **1144** + `LATEST-CRON.yaml` | **2026-09-08 0605 → 2026-09-16 0600** (only **8 days**) | ~5 min |
| `.context/audits/reviewer/YYYY-MM-DD.yaml` | **90** | 2026-04-25 → 2026-09-16 | daily |
| `.context/audits/unit-suite/` | 9 + `runs.log` (18 lines) | **2026-09-08 → 2026-09-16** (8 days) | nightly |

Also: `discoveries/LATEST.yaml`, `unclosed-satisfied/`, `go-scope-unpropagated/`, `orchestrator-LATEST.yaml`, `full-audit-timing.yaml`, `framework-mcp-baseline.yaml`, `orchestrator-mcp-baseline.yaml`.

**Trustworthiness — two distinct hazards:**
1. **Cron audit history is 8 days deep, not 7 months.** High-frequency, short retention. Any trend question over months must use the daily YAMLs, which have gaps (no files for most of May, mid-Jun through early Jul is sparse).
2. **`LATEST*.yaml` files are OVERWRITTEN, not appended** — `LATEST-CRON.yaml`, `discoveries/LATEST.yaml`, `unit-suite/LATEST.yaml`, `orchestrator-LATEST.yaml`, `escalation-drift-LATEST.yaml`. They are snapshots. All five show as `M` in this session's `git status`. **Never treat a `LATEST` file as history.**

**Reviewer audit is the richest single artefact** — `.context/audits/reviewer/2026-09-16.yaml` scanned **2886 tasks**: `PASS 2051 / CONCERN 815 / FAIL 20 / needs_human 94`, with per-pattern fire counts (`l387-sigpipe-risk` 513, `AC-verify-mismatch` 475, `empty-output-success` 125, `disposition-incomplete` 79, `mock-only-integration` 67, `decaying-task-path-ref` 65, `tautology` 3). 90 such daily snapshots exist → **this one IS a genuine time series.**

### 14. Healing events — PARTIAL (patterns store only; no event log)

**What exists:** `.context/project/patterns.yaml` — **19 pattern entries** (`FP-001` …), each with `pattern`, `description`, `learned_from: T-XXX`, `date_learned`, `mitigation`, `escalation_step` (A/B/C/D). Earliest `2026-02-13`.

**What does not exist:** any `.context/healing*` store. `ls .context/healing* .context/project/healing*` → nothing. `fw healing diagnose|resolve` writes its *outcome* into the task file and (on resolve) into `patterns.yaml`/`learnings.yaml`; it does **not** append a per-event record.

**Consequence:** the count of healing *episodes* is unrecoverable. 19 patterns is a count of *distilled lessons*, not of healing events — and §1 showed 0 tasks currently at `status: issues` with no historical transition record. `healing` appears as prose in 93 task files, which is the only (unreliable, self-reported) proxy.

---

## AEF — USAGE

### 15. Per-verb invocation counts — **ABSENT**

**This is the answer the review flagged as important. There is no per-verb counter anywhere. I looked and did not guess.**

Every counter under `.context/working/` was read directly:

| File | Content (verbatim) | Granularity |
|---|---|---|
| `.hook-counter` | `error-watchdog=60`, `check-tier0=137`, `budget-gate=134`, `check-active-task=127`, `loop-detect=121`, `audit-task-tools=81`, `check-project-boundary=65`, `checkpoint=62`, `post-compact-resume=2` | **per-HOOK, not per-verb** |
| `.hook-failure-counter` | `bogus-hook-name-for-T1628=19`, `...=1` | test residue |
| `.tool-counter` | `73` | single scalar |
| `.prompt-counter` | `3` | single scalar |
| `.commit-counter` | `0` | single scalar |
| `.budget-gate-counter` | `36` | single scalar |

`.hook-counter` is the closest thing that exists, and it counts **PreToolUse hook firings by hook name** — orthogonal to `fw` verbs. `grep -rn "invocation\|verb_count\|usage_count"` over `lib/*.sh` and `agents/audit/*.sh` → zero hits. `fw metrics` computes task/audit aggregates, not verb usage.

**So: for the question "which `fw` verbs are actually used, and how often" — there is NO DATA. Not zero usage. No data.** Any claim about verb usage in this review must come from a source other than telemetry (e.g. git history of call sites, or the dispatch corpus), and must say so.

The scalar counters are also **reset-prone**: `.commit-counter` reads `0` and `.edit-counter` shows as **deleted** (`D`) in this session's `git status` — these are session-scoped state files, not cumulative history.

### 16. Token telemetry per task/arc — **ABSENT** (session-level only)

**`.context/working/.session-metrics.yaml`** — what it actually contains (read in full):
- Header: `# Extracted from: dadae3c3-...jsonl`, `# Turn offset: 1251`
- Cumulative: `turns: 1369`, `tool_calls: 594`, `commits: 35`, `commits_per_turn: 0.0256`, `first_commit_turn: 96`, `failed_tool_calls: 48`, `failed_tool_call_rate: 0.0808`, `edit_bursts: 1`, `productive_turns: 490`, `research_turns: 0`, `productive_turns_ratio: 0.3579`, `edit_retry_files: 7`
- Per-session (since turn 1251): `session_turns: 118`, `session_commits: 6`, … `session_productive_turns_ratio: 0.3051`

**No token field at all**, and **no task_id or arc_id**. It is turn/tool/commit counts for ONE session transcript.

**`.context/project/metrics-history.yaml`** — `# 30-day rolling retention`, **1053 entries**, `2026-08-18T00:04:09Z → 2026-09-16T04:04:39Z` (29 days, matches the stated retention). Per entry: `timestamp, pass, warn, fail, active_tasks, completed_tasks, velocity, traceability_pct, episodic_quality_pct, open_gaps`. **Project-level audit rollup. No tokens, no task, no arc.**

**`fw costs`** (`lib/costs.sh:2,4,6,48`) parses `~/.claude/projects/<dir>/*.jsonl` **live** — it reads the raw Claude Code transcripts and **persists nothing** into the repo. There is no `.context/` store of token usage.

**Verdict:** token cost per task or per arc is **ABSENT**. It is not stored, and it is not reconstructible from anything in the repo — the transcripts it would need live outside version control, are not keyed by task, and `.session-metrics.yaml` is overwritten each run (shows `M` in `git status`).

### 17. Activity per scope (tokens/tasks touching a subsystem) — **ABSENT** as asked; PARTIAL half-measure available

- **Token side: ABSENT.** Follows directly from §16 — no per-task tokens exist, so no per-subsystem tokens can exist.
- **Task side: PARTIAL, and only via an indirect join.** `.fabric/components/*.yaml` carries `subsystem:` on all 1268 cards, and dispatch rows carry `worker_writes` — but only **72 of 2358** dispatches (3.1%) have that field. Task files carry no `components:` until the `work-completed` transition (CLAUDE.md §BVP), and `write_set:` frontmatter is declared by **0 of 3357** tasks (consistent with CLAUDE.md §Execution Model item 4's "0 of 3032"). The only reliable path is mining `git log --stat` per task ID — real work, outside a data-availability map.

**Recorded as ABSENT for the metric as specified.**

---

## AEF — VALUE

### 18. `policy/value-drivers.yaml` — EXISTS. Drivers and weights, VERBATIM.

`version: 3`. Quoted exactly as on disk.

**Protected drivers (D1–D4) — the Constitutional Directives, not removable:**

```yaml
protected_drivers:
  - id: D1
    name: Antifragility
    weight: 9
  - id: D2
    name: Reliability
    weight: 7
  - id: D3
    name: Usability
    weight: 5
  - id: D4
    name: Portability
    weight: 3
```

**Free drivers — as they actually appear in the file:**

```yaml
free_drivers:
  - id: F-RECALL
    name: Recall Leverage
    weight: 6                       # below D2(7); near-top but must not rival D1
  - id: F-AUTONOMY
    name: Autonomy / Unattended Operation
    weight: 4                     # below Orchestration; the most safety-sensitive axis
  - id: F3
    name: V_PROMPT_QUALITY
    weight: 7
    protected: false
  - id: F1
    name: V_CONTEXT_FABRIC
    weight: 7
    protected: false
  - id: F2
    name: V_COMPONENT_FABRIC
    weight: 6
    protected: false
```

**Retired:** `F-ORCH` / *Orchestration Leverage* / `weight: 5` — commented out 2026-07-07 (T-2511), definition preserved verbatim in-file, marked REVERSIBLE.

**Auto-promotion block, verbatim:**
```yaml
auto_promote:
  enabled: false
  bvp_norm_min: 0.85    # only top-band value
  cost_max: 1           # only lowest-cost band
  max_concurrent: 1     # at most one auto-promoted item in flight
```

**Inception scoring exception:** `enabled: true`; cost substitution `target_blast_radius` range `[0,9]`, fallback `components-count`; value substitution `voi_score` range `[0.0,1.0]` scaled to `[0,5]`, `fallback_score: 2`; estimator `agents/termlink/bvp-estimator/estimator.py::_score_inception_voi`.

**Two structural observations, stated as fact, not judgement:**
1. **The free-driver cap is exceeded.** The file's own header states `Cap of 5 free (9 total)` and `add-one-drop-one when full`. Five are active (F-RECALL, F-AUTONOMY, F3, F1, F2) — at the cap exactly.
2. **The file's stated ordering does not match its contents.** The header comment says *"v3 activates two: F-RECALL … and F-ORCH"*; F-ORCH is retired and three more (F3/F1/F2, from T-2305) were appended **after** the `auto_promote` section header comment, so `auto_promote:` is textually separated from the comment block introducing it. `F3` (weight 7) is also listed before `F1`, and F3/F1 at weight **7 equal D2 (Reliability)** and exceed the 6 the header's reasoning assigns to the top free driver. Recorded as a fact about the yardstick, since everything downstream ranks against it.

### 19. BVP scores per task — PARTIAL, and lopsided: **0 confirmed vs 3319 proposed**

Counted with `grep -E "^[[:space:]]*bvp_scores:"` (uncommented, any indent) and `grep -l "^bvp_scores_proposed:"`:

| Field | active | completed | **total** |
|---|---:|---:|---:|
| `bvp_scores:` (**CONFIRMED** — human, via `fw bvp confirm`) | **0** | **0** | **0** |
| `bvp_scores_proposed:` (estimator worker) | 469 | 2850 | **3319** |
| `cost_estimate:` (confirmed) | 0 | 0 | **0** |
| `cost_estimate_proposed:` | — | — | **1138** |
| `arc_id:` non-empty | — | — | **435** |

The 1293 files matching `^#\s*bvp_scores:` are **template comment lines** (`# bvp_scores:  # confirmed per-driver scores…`), not data — this is the trap that makes a naive grep report ~1300 confirmed scores. Verified by reading the block in `.tasks/active/T-3369-*.md`: the commented template line sits directly above the live `cost_estimate_proposed:` / `bvp_scores_proposed:` entries.

**Arcs: 15 of 20 carry a `bvp_scores:` key, and all 15 are `{}`** (parsed per file, §2).

**So: the sovereignty boundary described in CLAUDE.md — `bvp_scores:` "set only by `fw bvp confirm`" — has been exercised ZERO times across 3357 tasks and 20 arcs.** Proposed scores from `bvp-estimator-v1-heuristic` (e.g. T-3369: `D1:4 D2:4 D3:3 D4:2 F-RECALL:2`, ts 2026-09-15) are the only value data that exists.

**Trustworthiness:** proposals are machine-generated by a heuristic estimator on a 15-min cron sweep (`bvp-estimator-sweep-15m`, `bvp-cost-estimator-sweep-15m`) — mechanical and consistent, but **entirely unvalidated against human judgement**, because no human judgement was ever recorded. The estimator is scoring in a closed loop.

### 20. Realization log `.context/audits/bvp-realization.jsonl` — **ABSENT**

`ls` → `No such file or directory`. Not present anywhere under `.context/audits/` (full directory listing taken; only `arc-scoped-weight-changes.jsonl` and `gap-closures.jsonl` exist as JSONL there, §10).

There is `.context/bvp-driver-proposals.jsonl` at `.context/` root — that is *driver* proposals, a different thing from value *realization*.

**No record of predicted-vs-delivered value exists.**

### 21. Estimator override frequency — **ABSENT**, and structurally so

An override is `bvp_scores:` (human) differing from `bvp_scores_proposed:` (estimator). Per §19, `bvp_scores:` is populated on **0 tasks**. The difference is therefore undefined on every task in the corpus — there is no denominator and no numerator.

This also disables the `v2-delta` mechanic CLAUDE.md describes (proposals persist when they differ by ≥2 from `bvp_scores:` on any driver) and the `estimator-fidelity` scoped driver on arc `value-prioritisation`, whose stated rationale is *"measuring how well the BVP heuristic estimator's scores agree with human-confirmed scores"* — the quantity it exists to measure has never had an input.

---

## TERMLINK

### 22. Topic append-log / hub SQLite — EXISTS (retention-truncated)

**Location:** `/var/lib/termlink/bus/` (outside the repo) · **Total 29 MB**
- `meta.db` — **557 056 b** SQLite index
- `topics/` — **28 MB**, **37** `<sha256>.log` append-log files
- `artifacts/` — empty

**`meta.db` tables (schema read via `PRAGMA table_info`, read-only URI):**

| Table | Columns | Rows |
|---|---|---|
| `topics` | `name, retention_kind, retention_value, created_at` | **39** |
| `offsets` | `topic, next_offset` | 39 |
| `records` | `topic, offset, byte_pos, length, ts_unix_ms` | **3928** |
| `cursors` | `subscriber_id, topic, last_offset` | **1** |
| `claims` | `claim_id, topic, offset, claimed_by, claimed_at, claimed_until` | 2 |
| `schema_version` | — | 1 |

**Traffic per topic — and the retention gap it exposes:**

| Topic | rows in `records` | `next_offset` (lifetime) | **lost to retention** |
|---|---:|---:|---:|
| `agent-presence` | 1057 | **44196** | **43 139 (97.6%)** |
| `health:ring20-fedprobe` | 1355 | 1355 | 0 |
| `agent-chat-arc` | 1002 | 1428 | 426 |
| `channel:learnings` | 176 | 176 | 0 |
| `framework:pickup` | 124 | 124 | 0 |
| `dm:61e262f0…:9219671e…` | 83 | 83 | 0 |
| `dm:9219671e…:d1993c2c…` | 27 | 27 | 0 |
| `broadcast:global` | 16 | 16 | 0 |

**Trustworthiness — the headline caveat.** `next_offset` is the lifetime monotonic counter; `records` is what survives retention. For `agent-presence`, **97.6% of all messages ever posted are gone**. Any "traffic" figure read off `records` is a *retained-window* figure, not a lifetime one — and the two differ by 40× on the busiest topic. `topics.retention_kind`/`retention_value` are per-topic, so the window is not even uniform across topics. **39 topics in `topics` but only 37 `.log` files on disk** — two topics have an index row and no log.

### 23. Subscriber cursors / offsets — EXISTS

Two stores, and they disagree in scale:
- **`meta.db:cursors`** — **1 row**. Hub-side durable cursor.
- **`~/.termlink/cursors.json`** (624 b, mtime 2026-08-26) — **11 entries**, client-side. Verbatim sample: `"agent-chat-arc::d1993c2c3ec44c94": 1611`, `"dm:9219671e28054458:d1993c2c3ec44c94::d1993c2c3ec44c94": 44`, `"smoke:t2146::d1993c2c3ec44c94": 4`, `"t-1358-inbox-1777360315::d1993c2c3ec44c94": 3`, plus 7 more.
- **`meta.db:offsets`** — 39 rows, the per-topic write head (not a subscriber position).

**Trustworthiness:** `cursors.json` is an **overwritten JSON blob**, not a log — it holds current position only, no read history, and is 3 weeks stale. Note `agent-chat-arc` client cursor is **1611** while the hub's `next_offset` for that topic is **1428** — the client cursor exceeds the hub's current head, consistent with a hub-side reset or re-creation. Flagged as an inconsistency, not interpreted.

### 24. Presence / heartbeats — EXISTS, but **NOT history** (as the brief anticipated)

- **`agent-presence` topic** — 1057 retained of 44196 lifetime (§22). Presence is by nature a *current-state* signal; the retained window is a keyhole.
- **`.context/monitors/liveness.jsonl`** — **10080 lines**, first ts `2026-05-04T08:31:01+02:00`, last ts `2026-08-14T21:29:59+02:00`. Written by cron `liveness-1m` (*"Pings TermLink hub, counts Claude Code processes, and checks Watchtower"*). Fields: `ts, host, boot, termlink_hub, termlink_hub_detail, claude_instances, fw_agent_session, fw_agent_id, watchtower`.

  **10080 = exactly 7 days × 1440 min.** This is a **fixed-size ring buffer**, not an archive — despite spanning May→Aug in its first/last lines, which is itself the tell that old lines are being evicted from the head. Treat as a 7-day window at best; the May-dated first line is an unevicted straggler, not evidence of May coverage.
- **`.context/monitors/liveness-latest.yaml`, `watchtower-rss-latest.yaml`** — overwritten snapshots (both `M` in `git status`).
- **`.context/monitors/watchtower-rss.jsonl`** — 7798 lines from `2026-08-19`, fields `timestamp, host, state, detail`.

**Recorded as instructed: presence/heartbeat data resets and evicts. It answers "is it up now", never "was it up then".**

### 25. Worker invocations — EXISTS (the strongest dataset in this map)

**`.context/dispatches.jsonl`** — **2358 lines, 2358 unique `dispatch_id`, 0 malformed.**
Window: `2026-05-03T12:53:46Z → 2026-09-16T03:09:54Z`. **2308 of 2358 (97.9%) carry `ts`**; 50 do not.

**Fields (dominant schema, 916 rows):**
`dispatch_id, ts, schema_version, task_id, task_type, workflow_id, workflow_sha, workflow_resolved_via, prompt_template, prompt_strategy, template_sha, variant_id, model, effort, worker_kind, parent_dispatch_id, blob_dir, origin, task_snapshot, outcome`

**8 distinct key-sets — the schema evolved and was never backfilled:**

| Rows | Distinguishing keys |
|---:|---|
| 916 | + `origin`, `task_snapshot` |
| 616 | + `events_count`, `terminal_event` |
| 609 | base 18-key form |
| 68 | + `origin`, `task_snapshot`, `events_count`, `terminal_event`, **`worker_writes`** |
| 55 | + `origin`, `task_snapshot`, `events_count`, `terminal_event` |
| 39 | + `events_count` |
| 35 | **`dispatch_id, outcome, task_id` only** (3 keys — degenerate) |
| 15 | `dispatch_id, outcome, task_completion_outcome, task_id` (degenerate) |

Field coverage: `origin` **1044/2358** (44.3%), `task_snapshot` **1044** (44.3%), `worker_writes` **72** (3.1%).

**Distributions:**

| `worker_kind` | n | | `task_type` | n |
|---|---:|---|---|---:|
| ollama-direct | 790 | | ask | 790 |
| TermLink | 768 | | default | 768 |
| ollama-loop | 682 | | escalation-triage | 674 |
| *(absent)* | 104 | | *(absent)* | 104 |
| ollama-thin-loop | 14 | | ollama-research | 20 |
| | | | prompt-triage | 2 |

**Inline `outcome` on the dispatch row:** `pending` **1575** (66.8%), `success` 725, `error` 58.

**`.context/dispatch-outcomes.jsonl`** — **2853 lines, 0 malformed, single uniform schema** (`dispatch_id, ts, schema_version, task_id, outcome`), window `2026-05-03T13:02:20Z → 2026-09-15T20:54:57Z`. Nested `outcome` object carries `verification_passed, ac_satisfied, ac_total, ac_checked, verification_failed_commands, notes, evaluator`.

**Join result (computed):**

| Measure | Value |
|---|---|
| Dispatch rows | 2358 |
| Outcome rows | 2853 |
| Unique `dispatch_id` in outcomes | **1593** |
| **Dispatches WITH ≥1 matching outcome** | **1593 = 67.6%** |
| **Dispatches with NO outcome** | **765 = 32.4%** |
| Orphan outcomes (no matching dispatch) | **0** |

So **~1.8 outcome events per dispatch** for those that have any (2853/1593) — outcomes are re-emitted on re-evaluation — while **a third of all dispatches never produced one**.

**Trustworthiness:** append-only, git-tracked, referentially clean (0 orphans). Two real caveats: (a) the inline `outcome: pending` on 1575 dispatch rows is **stale in-place state**, not a verdict — the authoritative verdict is the separate outcomes file; (b) the 50 dispatches with **no `ts`** and the 50 degenerate 3-/4-key rows cannot be placed in time or attributed to a workflow.

### 26. Discarded posts, silent drops, crashes — **DATA GAP (confirmed, explicit)**

**No out-of-band observer of the bus exists.** Verified:
- `.context/monitors/` contains exactly `liveness.jsonl`, `liveness-latest.yaml`, `watchtower-rss.jsonl`, `watchtower-rss-latest.yaml`. Nothing else monitors anything.
- The one candidate, cron `liveness-1m`, observes **the hub PROCESS** (`termlink_hub: running|stopped`) and process counts — **not messages**. It cannot distinguish "hub up, message silently dropped" from "hub up, message delivered".
- `meta.db` has no drop/reject/error table. Its five tables are `topics, offsets, records, cursors, claims` — all success-path bookkeeping. A record that was never written leaves no row.
- `.context/bus/` (the AEF-side result ledger, 300 K: `blobs/`, `inbox/`, `results/`, `handler.log`) is likewise a success-path store.

**Recorded as a DATA GAP.** The bus can report only what it successfully accepted. Per the brief's own principle — **a channel cannot report its own failures** — discarded posts, silent drops, and worker crashes are **structurally invisible** here. The §22 retention finding compounds it: even successfully-accepted messages are evicted (97.6% on `agent-presence`), so absence of a record is doubly uninformative — it may mean never-sent, dropped, or simply aged out.

Corroborating evidence that drops occur and are not logged: CLAUDE.md §Cross-Agent Communication Protocol states *"`ok:true` = hub accepted, NOT delivered. Files silently lost to event-only sessions"* and cites session S-2026-0412 (two push messages, zero response, no error anywhere). The failure mode is known and documented in prose; **no telemetry captures it**.

---

## WORKFLOW DESIGNER

### 27. Ratified vs draft workflows — PARTIAL; ratification is a **naming convention**, not recorded state

**Count correction first.** 87 `.bpmn` files are git-tracked, but they are not all corpus:

| Location | Files | What it is |
|---|---:|---|
| `.context/designer/projects/` | **47** | **the live corpus** |
| `.agentic-framework/.context/designer/projects/` | 13 | vendored self-copy — **not** the corpus |
| `tests/fixtures/bpmn/` | 17 | test fixtures |
| `tests/fixtures/aef-bpmn/` | 6 | test fixtures |
| `tests/fixtures/832/`, `832-outbound/` | 4 | test fixtures |

The 47 live files are **16 projects × multiple versions** (e.g. `draft-knowledge-leveling` has v1–v8).

**Ratified vs draft — by prefix, 8 / 8:**

| `aef-*` (ratified by convention) | latest v | | `draft-*` | latest v |
|---|---:|---|---|---:|
| aef-audit-cron | 1 | | draft-arc-lifecycle | 4 |
| aef-dispatch-loop | 3 | | draft-continuous-run-loop | 5 |
| aef-existing-project-onboarding | 1 | | draft-exception-handling | 3 |
| aef-greenfield-onboarding | 2 | | draft-inception-readiness | 2 |
| aef-inception-flow | 1 | | draft-knowledge-leveling | 8 |
| aef-session-lifecycle | 1 | | draft-t2584-scratch | 1 |
| aef-task-lifecycle | 3 | | draft-task-creation | 5 |
| aef-tier0-escalation | 1 | | draft-trigger-handling | 6 |

**Where ratification is recorded: NOWHERE, as data.**
- `.context/designer/registry.yaml` — contains only `ghosts:` and `claims:`. `grep -ic ratified` → **0**.
- Every `meta.json` (all 16 read) carries **only** `{id, title, versions[], latest, updated, uuid}`. **No `status`, `ratified`, `state`, `stage`, or `authority` field exists on any project.**
- `grep -ril ratified .context/designer/` → 3 `.bpmn` files (`aef-inception-flow/v1`, `aef-greenfield-onboarding/v1`, `draft-trigger-handling/v1`) — matches are **prose inside node documentation**, and one is a `draft-*` project, so the word does not track the prefix.

**Verdict: "RATIFIED" is inferable only from the filename prefix.** It is not a recorded, queryable, or gate-enforceable property. `policy/designer-pin.yaml` pins the *editor build* (v0.11.0, sha256 `4f20b146…`) — that is tooling provenance, not workflow ratification.

**`versions[]` in `meta.json` IS real history** — each entry has `v`, `note`, `ts` (e.g. aef-task-lifecycle v3: *"T-2863: restore doc comment lost on the v1→v2 UI save (T-2682 / G-071 class)"*). Append-only, and the richest designer metadata that exists.

### 28. `aef:endpoint` per node — **DESIGNED-ONLY. Zero in the live corpus.**

**Exhaustive attribute census over all 47 live corpus files** (`grep -roh 'aef:[a-zA-Z]*' .context/designer/projects/`):

| Attribute/element | Occurrences |
|---|---:|
| `aef:uid` | 1328 |
| `aef:position` | 631 |
| `aef:meta` | 565 |
| `aef:anchors` | 157 |
| `aef:laneMeta` | 117 |
| `aef:workflowMeta` | 47 |
| `aef:eventDef` | 21 |
| `aef:routingHint` | 17 |
| `aef:loopDetour` | 17 |
| `aef:link` | 17 |
| `aef:description` | 15 |
| `aef:constituent` | 9 |
| `aef:forceStraight` | 6 |
| `aef:constituents` | 6 |
| `aef:state` | 1 |
| **`aef:endpoint`** | **0** |

`grep -rl "endpoint" --include="*.bpmn"` across the whole repo returns **4 files, all test fixtures**:

| Fixture | `endpoint` hits |
|---|---:|
| `tests/fixtures/aef-bpmn/dispatch-loop.bpmn` | 10 |
| `tests/fixtures/bpmn/resume-status-canonical.bpmn` | 8 |
| `tests/fixtures/aef-bpmn/session-handover.bpmn` | 7 |
| `tests/fixtures/832/pair-draft-3.bpmn` | 4 |
| **total** | **29 elements / 58 tag occurrences** |

Form is a child **element**, not an attribute (which is why an attribute-shaped grep finds nothing):
```xml
<aef:endpoint>agents/dispatch/skills/scope.md</aef:endpoint>
<aef:endpoint>fw budget gate --reserve 40000</aef:endpoint>
<aef:endpoint>fw dispatch sub --skill explore --deliverable ${deliverables[0]}</aef:endpoint>
```

**Do endpoints point at files that EXIST? — the question does not apply to the live corpus, because the live corpus has no endpoints.** For the fixture sample: the values are a **mix of file paths and CLI command strings with `${}` template variables** (`fw budget gate --reserve 40000`, `fw dispatch sub --skill explore --deliverable ${deliverables[0]}`) — the majority are not paths at all and are not resolvable to a file by construction. `fw budget gate` and `fw dispatch sub` are not verbs in `bin/fw`. **Dangle-rate is UNVERIFIED as a corpus metric and meaningless as a fixture metric** — a fixture is not expected to resolve.

**This is the single largest designed-vs-built gap in Layer B: the node→implementation binding is specified in fixtures and absent from every ratified workflow.**

### 29. `aef:contextReads` / `aef:artifactsWrites` — **DESIGNED-ONLY** (fixtures only)

Repo-wide: **`contextReads` 9 occurrences, `artifactsWrites` 9** — all inside the same 4 test fixtures as §28. **Zero in `.context/designer/projects/`** (absent from the 15-row census above).

Form, from `tests/fixtures/aef-bpmn/dispatch-loop.bpmn`:
```xml
<aef:contextReads paths=".tasks/active/${task_id}.md"/>
<aef:contextReads paths=".context/working/.budget-status"/>
<aef:contextReads paths=".context/bus/dispatch-${run_id}/, .context/bus/blobs/"/>
<aef:contextReads paths=".context/working/dispatch-${run_id}/"/>
```

The schema is designed (typed, templated, comma-separated multi-path). **No ratified workflow carries it.** Note this is exactly the data that would make §17 (activity per scope) and `fw write-set check` work — the declared read/write sets exist as a fixture design and nowhere in production. Consistent with CLAUDE.md §Execution Model: *"No task in the corpus declares `write_set:` frontmatter — 0 of 3032."*

### 30. Lane + authority + tier — PARTIAL (two of three, at the wrong granularity for one)

**Present:**
- **Lane + authority — YES, per lane.** `aef:laneMeta` × **117**, carrying authority verbatim:
  ```xml
  <aef:laneMeta abbr="agt" authority="initiative" height="324.47…"/>
  <aef:laneMeta abbr="hum" authority="sovereignty" height="88"/>
  ```
  These map directly onto CLAUDE.md's Authority Model (Human→sovereignty, Agent→initiative).
- **Tier — YES, per WORKFLOW, as a default only.** `aef:workflowMeta` × **47**, every one carrying `tier_default`:
  ```xml
  <aef:workflowMeta id="aef-audit-cron" version="1" schemaVersion="2" title="…" tier_default="1"/>
  <aef:workflowMeta id="aef-dispatch-loop" version="2" schemaVersion="2" title="…" tier_default="1"/>
  ```

**Absent:** **per-node tier.** `grep -roh 'aef:\(lane\|authority\|tier\|endpoint\|contextReads\|artifactsWrites\|uid\)="[^"]*"'` → **0** — i.e. no node carries a `tier=` attribute of its own. Tier is a workflow-level default that no node overrides. A Tier-0 step inside a `tier_default="1"` workflow is **not expressible** in the live corpus.

**Node identity IS strong:** `aef:uid` × 1328 across 47 files gives every node a stable id — which is precisely what an execution trace would join on (§31).

### 31. Execution traces by node uid — **DESIGNED-ONLY**

**`fw workflow` does not exist.** `grep -nE '^\s*workflow\)' bin/fw` → no match. The dispatcher's case block (`bin/fw:6034-6060`) routes `fabric)`, `designer)`, `bpmn)`, `corpus)` — there is no `workflow)` arm and no `run` subverb on any of them:

| Verb | Routes to | What it does |
|---|---|---|
| `fw designer` | `agents/designer/designer.sh` | vendors + serves the pinned editor build (T-2521) |
| `fw bpmn` | `agents/bpmn/bpmn.sh` | *forward compiler* — BPMN diagram → **AEF task skeletons** (T-2533) |
| `fw corpus` | `tools/corpus_spec.py` / `corpus_lint.py` / `corpus_explain.py` | authoring, linting, explanation |

Supporting tools: `tools/corpus_conformance.py`, `corpus_overlay.py`, `corpus_explain.py`, `corpus_lint.py`, `corpus_spec.py`. **All static** — they author, lint, diff and explain diagrams. None execute one.

**The closest thing to a trace is `.context/working/.bpmn-promote-audit.jsonl` — 93 lines, from 2026-07-19**, and it records *compilation*, not execution:
```json
{"action":"created","sha":"b94d7c4a01e01f57","source_diagram":"two-lane-sample.bpmn","task_id":"T-700","ts":"2026-07-19T08:47:20Z","uid":"u-compile-002"}
```
Note it carries a `uid` — but `u-compile-002` is a **compile-step id**, not an `aef:uid` from the diagram. It cannot be joined to the 1328 node uids in the corpus.

**Verdict: DESIGNED-ONLY.** Node identity exists (1328 uids), lane authority exists, workflow tier defaults exist — every ingredient for a trace schema is in place. **Nothing ever runs a workflow, so no trace has ever been emitted.** There is no runtime, so there is no runtime data — and per the brief's rule, that is ABSENT-by-design, not zero executions.

---

## Cross-cutting trustworthiness notes

1. **Overwritten-not-appended (never treat as history):** all `*LATEST*.yaml` (`LATEST-CRON.yaml`, `discoveries/LATEST.yaml`, `unit-suite/LATEST.yaml`, `orchestrator-LATEST.yaml`, `escalation-drift-LATEST.yaml`, `liveness-latest.yaml`, `watchtower-rss-latest.yaml`), `.session-metrics.yaml`, `~/.termlink/cursors.json`, `.budget-status`, `focus.yaml`, `session.yaml`. Every one of these shows `M` in this session's `git status`.
2. **Reset/evict-prone:** all `.context/working/.*-counter` scalars (`.commit-counter` currently `0`; `.edit-counter` currently **deleted**); `liveness.jsonl` (fixed 10080-line ring = 7 days); TermLink `records` (97.6% evicted on the busiest topic); `metrics-history.yaml` (explicit 30-day retention); `.context/audits/cron/` (8-day window).
3. **Self-report only — cannot report their own failure:** `.gate-bypass-log.yaml` (logs defeats, never holds); episodic summaries (agent-authored at close); task prose rework signals; the entire TermLink bus w.r.t. drops (§26); `.upstream-issues-sent` (send receipt, no outcome).
4. **Schema drift never backfilled:** `dispatches.jsonl` has 8 key-sets; `origin`/`task_snapshot` on 44.3%, `worker_writes` on 3.1%; 50 rows lack `ts` entirely. Any longitudinal dispatch analysis must state which schema generation it covers.
5. **The vendored `.agentic-framework/` self-copy inflates every naive repo-wide count** (BPMN 87→47 live; every `docs/generated/components/` path appears twice). All counts in this document exclude it unless stated.
6. **Two independent value-data dead ends converge:** §19 (0 confirmed BVP scores), §20 (no realization log), §21 (override frequency undefined). Value *prediction* data is abundant (3319 proposals); value *validation* data does not exist in any form.

---

## VERBS I RAN (pollution record)

**Zero `fw` verbs were executed.** Per the brief's preference, everything above came from direct filesystem inspection — `ls`, `find`, `grep`, `wc`, `head`, `tail`, `cat`, `du`, `git ls-files`, `python3` (`yaml.safe_load`, `json.loads`, and `sqlite3` opened **read-only** via `file:…?mode=ro` URI).

No `fw` counter, no usage telemetry, no audit cadence, and no TermLink state was perturbed by this review. The single SQLite connection to `/var/lib/termlink/bus/meta.db` was read-only and wrote nothing (no WAL/journal side-effects).

**Files written by this review: exactly one** — this document.
