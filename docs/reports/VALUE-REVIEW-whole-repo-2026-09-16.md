# VALUE REVIEW — Whole repo — JUDGE report (T-3370)

- **Date:** 2026-09-16 · **Role:** JUDGE (GATHERER → **JUDGE** → HUMAN)
- **Inputs, and the only inputs:** yardstick + datamaps A, B, C + evidence D, E, F (all `docs/reports/VALUE-REVIEW-whole-repo-2026-09-16-*.md`).
- **Status:** a proposal. Nothing here is authorised. Each row needs a separate human approval before it is acted on.
- **Citation form:** `A §14` = datamap-A row 14; `B §19` = datamap-B section 19; `C §2a` = datamap-C Task 2(a); `D §4.1` = evidence-D section 4 item 1; `E Q2` = evidence-E question 2; `F §6` = evidence-F section 6; `Y §3.5` = yardstick §3 contradiction 5.

---

## 1. Verdict in one paragraph

**What the repo carries.** It carries a large governance machine that traces its own history very well:

- 9,222 commits, 100% of sampled subjects carrying a T-ID (A §10, C §1.7);
- 2,886 completed tasks with near-1:1 episodic records (B §3);
- 28 wired hook commands (D §1d);
- a 7,300-line audit, a 10,000-line CLI, and 159 web routes.

**What it cannot see is whether that machine works.**

- It records gate *defeats* but never gate *evaluations*, so "the gate held" and "the gate never fired" look the same (B §12).
- Its Tier-2 audit trail does not parse (C §1.3).
- Its de-facto CI, the nightly unit suite, exited non-zero on every run in its 8-day recorded window. Its pytest leg ran **zero tests** yet reported `failed_count: 0` (A §14).
- The GitHub CI never fires on the development branch (A §18).
- The liveness monitor went silent on 2026-08-14 (A §15, B §24, C §1.2).
- The value-scoring loop has 3,319 machine proposals, **zero** human confirmations and no independent signal (B §19, F §6). 74% of the "predictions" were written after the task had already finished (C §2a).

**Single most consequential finding.** The framework's primary mechanism is structural enforcement: yardstick C1, "not by agent discipline". That mechanism currently cannot show that it is running. This is C2 ("a check that reports success while measuring nothing") sitting at the centre of D2 (Reliability, weight 7) and D1 (Antifragility, weight 9).

One observation makes this urgent rather than theoretical, although it is **not yet proven**:

- Both independent `.hook-counter` snapshots (A §16, B §15) list only hooks matched on `Bash` or `*`.
- None of the roughly 12 hooks matched only on `Write|Edit` appears in either snapshot.
- C §1.5 says every hook fire increments that counter.

Either those write-time gates are not firing, or the counter does not count them. Finding **I1** is a one-edit check that decides which. It should run before any other row in this report is acted on.

## 2. Yardstick used

**⚠ The yardstick is DERIVED and NOT YET OPERATOR-CONFIRMED** (Y header). Every ranking below inherits that status. Rows that depend on a contested line of the yardstick say so.

**Derived purpose (Y §1):** make an AI agent's work traceable, reversible and human-sovereign by structural enforcement rather than agent discipline. It captures:

- the record of what happened (Context Fabric);
- the map of what the work touches (Component Fabric);
- a human decision at exactly the moments that need one.

It *coordinates; it does not execute*. Four consequences bind this report:

- **C1** — Enforcement beats prose.
- **C2** — A silent failure has negative value.
- **C3** — Sovereignty is not an inefficiency.
- **C4** — Missing *execution* capability is out of scope; missing *governance* capability is in scope.

Findings are ranked by the highest-weighted driver they serve or harm. Ties are broken on realized cost (F), never on taste.

| id | name | weight | kind |
|---|---|---|---|
| D1 | Antifragility | 9 | protected |
| D2 | Reliability | 7 | protected |
| F3 | V_PROMPT_QUALITY | 7 | free |
| F1 | V_CONTEXT_FABRIC | 7 | free |
| F-RECALL | Recall Leverage | 6 | free |
| F2 | V_COMPONENT_FABRIC | 6 | free |
| D3 | Usability | 5 | protected |
| F-AUTONOMY | Autonomy / Unattended Operation | 4 | free |
| D4 | Portability | 3 | protected |

**Contested line in the yardstick itself** (B §18, observation 2):

- F3 and F1 carry weight 7, which equals D2. That contradicts the file's own header reasoning, which puts the top free driver at 6.
- The header comment still names the retired F-ORCH as active.

Every row whose rank depends on F3 or F1 outranking F-RECALL or F2 inherits this doubt. The operator should rule on it (Sovereign Q1).

## 3. Method and role separation

**Who did what.**

- **Gatherers A–F** ran as **separate processes** from this judge. Their briefs said: collect facts, do not classify.
  - A: generic data sources.
  - B: AEF, TermLink and Designer data sources.
  - C: what the system records about itself.
  - D: `bin/`, `lib/`, `agents/`, `policy/`.
  - E: web, tests, docs, Designer, TermLink.
  - F: realized cost.
- **The judge** (this report) read only the seven files listed above. It ran no `fw` verbs, did not grep the repo, and opened no source files.
- **Full disclosure of judge I/O beyond reading:** three shell reads.
  1. `wc -c` on the seven files, to budget reading.
  2. `grep -n '^#'` on evidence D, to locate its sections for chunked reading.
  3. One read of `.context/working/focus.yaml`, to confirm the active task. No evidence was drawn from it.
- **The human** decides every row.

**Gatherer pollution, as disclosed by the gatherers themselves.**

- **D:** its sub-agent launches **fired `check-agent-dispatch`** three times, which touched hook counters (D, "Commands run").
- **E:** imported `web.app` in Python (this builds the app but does not start a server). It also ran more `termlink --help` / `list` calls than its brief allowed, all read-only (E, "Commands run").
- **A, B, C, F:** ran no `fw` verbs.
- **Consequence:** the two `.hook-counter` snapshots differ (A: `check-tier0=114`; B: `137`) because counters moved while gathering was under way. That drift is disclosed; it does not affect I1, which rests on *which* hooks appear, not on how many times.

**What the separation means for confidence.**

- Findings corroborated by **two different gatherers**, with at least one measured or observed value, may be HIGH.
- Findings from one gatherer only cap at MEDIUM, even when the fact is trivially re-checkable.
- **Any finding whose verdict depends on usage caps at MEDIUM**, because no per-verb, per-route or per-gate-evaluation usage data exists (A §16, B §15, E header).
- The yardstick's contradictions table is derived from D and B, so it does not count as an independent source.
- Two yardstick citations point outside the evidence set: "OBS-415" and "prior run".
  - OBS-415 is corroborated by D §2, which cites commit 2f120f9e2.
  - "Prior run" is corroborated by C §1.3.

## 4. Data map summary

**Tally.** Rows from A (20) and B (31), each counted once by its primary status:

| Status | A | B | Total |
|---|---:|---:|---:|
| EXISTS | 3 | 13 | **16** |
| PARTIAL | 11 | 8 | **19** |
| DESIGNED-ONLY | 0 | 3 (§28, §29, §31) | **3** |
| ABSENT | 6 | 7 (§12, §15, §16, §17, §20, §21, §26) | **13** |

**Mixed B rows.** Three B rows hide an ABSENT inside an EXISTS or PARTIAL primary status:

- §1: rework signal;
- §2: arc `affects:`;
- §8: prompt-drift report.

**Structural absences added by C:**

- confirmed `bvp_scores:` / `cost_estimate:` (0 tasks);
- per-task main-session tokens;
- a healing event log;
- a structured operator-complaint record;
- "produced-by" bug attribution;
- about 20 sinks that code names but that do not exist on disk (C §1.4).

**The sentence that matters.** There is no per-verb, per-route or per-gate-evaluation record, and no validated value record. So **this review cannot conclude that any verb, route or gate is unused or ineffective, nor that any piece of work delivered value**. Every DELETE below therefore rests on one of these grounds instead:

- the item serves no driver;
- a live mechanism supersedes it;
- its staleness is measured.

Every usage-dependent call is INVESTIGATE.

**Where the review can stand firmly:**

- git-derived cost (F);
- commit→task traceability (A §10);
- the dispatch ledger (B §25);
- recall telemetry (C §1.3). This is the **only** real usage counter in the repo: 1,291 queries in one month.

---

## 5. Findings — DELETE (ranked, most consequential first)

**Size:** S = under a day; M = 1–3 sessions; L = multi-session. **Reversibility:** every row below is git-revertable unless it says otherwise.

| # | item | evidence ref | counter-evidence | driver | confidence | size | reversibility | risk-if-wrong | pre-registered expected effect |
|---|---|---|---|---|---|---|---|---|---|
| X1 | **Retrospective BVP scoring of already-finished tasks** (the estimator leg that writes `bvp_scores_proposed` onto tasks after `date_finished`) | C §2a (2,099 of 2,850 first estimates are after finish); F §6 (no independent signal: ρ≈0.05–0.10 within body-length terciles); B §19 (0 confirmations, closed loop) | The 2,099 may be a **one-off backfill**, not an ongoing leg. No evidence file names a consumer of scores on completed tasks, but none rules one out. **Contested yardstick line:** the README names "value scoring" as a product feature (Y §3.2). | Harms **D2** via C2: output shaped like a prediction that is not one | MEDIUM (facts measured by C and F; the verdict depends on a contested yardstick line and on an unenumerated consumer set) | M | Re-enable the leg | Loses a proposal series that F-style honesty checks could reuse. The 732 forward-looking entries are unaffected. | Within 7 days: 0 new `bvp_scores_proposed` entries with `ts > date_finished`. `fw bvp` default ranking over active tasks is byte-identical before and after (diff). |
| X2 | `agents/context/check-visual-verification.sh` (+ `.AGENT.md`): an **unwired** commit-time gate requiring an image on css/html commits, adopted from project 025 | D §1d, D §4.1 (NOT-WIRED), D §3a (0 test files, 3 commits, last 2026-06-23) | It checks a different artefact (an image) from the live render gate. A human might want both. It is also one of the four gates in Y §3.1. | **D2** (an untested gate is a liability if wired). Superseded for the same surface by the wired P-013 render gate (`render_surface.sh`, `human_review_state.py`, D §1b/§1c). | MEDIUM (single gatherer; supersession inferred from D's descriptions) | S | Revert | A css/html regression slips past with no image evidence. P-013's `[REVIEW]` Human AC still applies. | Count of NOT-WIRED gate files in `agents/context/` falls by 1. No change in `render_surface` gate refusals on render-touching tasks over the next 30 days. |
| X3 | `fw gpu recover` + `agents/gpu-recover/` (kills the largest non-ollama VRAM consumer) | D §1a, D §1e, D §3c (0 test files), D §3a (1 commit, 2026-04-25) | 4 code refs and 77 `.context` refs suggest it was used operationally. No usage data exists. | **Serves no driver**: it is host maintenance, outside "coordinates, does not execute" (C4). It also harms **D2**: a process-killing verb whose command string does not spell the kill, so Tier-0 is blind to it (CLAUDE.md T-2742 scope; UNVERIFIED for this verb). | MEDIUM (usage data absent) | S | Revert; or re-home in host tooling | The operator loses a GPU-recovery convenience. Mitigation: move it, don't drop it. | `fw gpu` returns "unknown command" (or a pointer to its new home). The verb count in `bin/fw` falls from 99 to 98. |
| X4 | `fw orchestrator improve`: a **stub that only echoes** | D §1a | CLAUDE.md documents it as a reserved v2 namespace. | Harms **D3/D2**: a documented affordance that does nothing (C1: prose standing in for capability) | MEDIUM | S | Revert | The namespace is lost; trivial to re-add when v2 exists. | `fw orchestrator improve` exits non-zero with "not implemented". The Quick Reference no longer lists it. |
| X5 | Dead scalar counters `.context/working/.commit-counter` (last written 2026-02-18) and `.prompt-counter` (last written 2026-05-15) | A §16 (mtimes), B §15 (values `0` / `3`) | C §1.5 lists them under hook telemetry, so a reader may exist. **Pre-delete check:** confirm there are no readers. | Harms **D2** via C2: they read as current usage and are 4–7 months stale | MEDIUM (A and B agree on the values; readers not enumerated) | S | Revert | A dormant reader gets an empty value. | Neither file exists. `fw doctor` / `fw metrics` output is unchanged apart from any line that printed them. |
| X6 | `bin/integrate-go-live.sh`: a one-shot with `REPO=/opt/999…` and `TASK_REF=T-2481` hardcoded | D §1a, D §3a (3 commits, 2026-06-24→25), D §4.7 | 1 code ref and 2 test files name it. | **Serves no driver** once its one-shot has run. It harms **D4** (hardcoded host path; Y §3.10). | MEDIUM (whether the one-shot is complete is inferred from the hardcoded task ref) | S | Revert | A re-run of the T-2481 landing is needed and the script is gone (it is in git history). | Its 2 tests are retired together with their subject. The hardcoded-path count in D §4.7 falls by 1. |
| X7 | `lib/setup.sh`: interactive wizard; `fw setup` already routes to `init.sh` | D §1a (`setup` is a deprecated alias), D §1b | **13 test files name it** (D §3a). They may test the alias rather than the file. `self-audit.sh:115` checks that it exists. | **Serves no driver** (superseded by `lib/init.sh`, D3) | MEDIUM | S | Revert | Tests fail if they source it directly; they must be retargeted, **not deleted blind**. | `fw setup` still prints its notice and runs init. No test that exercises the alias goes red. The self-audit existence check is updated in the same change. |
| X8 | Three never-rendered templates: `_stale_tasks_items.html`, `_work_queue_items.html`, `_partials/ask_answer_card.html` | E Q2 (neither rendered nor included; a grep for dynamic names found none) | A dynamically built name could evade the scan (E Q2 limitation). | **Serves no driver** (D3 noise) | MEDIUM | S | Revert | A page fails with `TemplateNotFound`. The Playwright all-routes test would catch it. | Template count goes from 84 to 81. `fw test playwright` all-routes stays green. |
| X9 | Uncalled code: `_date_relative` (compat.sh), `_watchtower_open` (watchtower.sh), `lib/first-run.sh` (no sourcing caller), `lib/runtime.sh` (only tests source it) | D §1b, D §3a | first-run.sh has 1 test and runtime.sh has tests. Dynamic sourcing was not ruled out. | **Serves no driver** | LOW–MEDIUM | S | Revert | An onboarding walkthrough someone runs by hand disappears. | `shellcheck` / bats stay green. There are 2 fewer `lib/` files. |
| X10 | Working-state residue: 2,505 zero-byte `.context/locks/T-*`; 66 stale `focus.<worker>.yaml`; ~60 ad-hoc scratch files (e.g. `T-2784-after-run.log`, 771 KB); frozen `doctor-trace.log` (1.1 MB); `qa_feedback.db` (frozen Feb); 4 stale `sessions/S-2026-0407-*`; scratch map `draft-t2584-scratch` | C §1.2, C §1.3; E Q5, B §27 (scratch draft) | Lock files may be kept by design under `flock` semantics. Tracking status of the residue is not stated. | **Serves no driver** (D3 noise). The scratch draft also triggers the audit's stale-draft INFO. | MEDIUM (locks LOW) | S | Revert if tracked; otherwise not reversible, so **archive before deleting** | A worker that still references its focus file loses it. | `.context/working/` file count falls by ≥150. The audit's stale-draft INFO for `t2584` disappears. |

## 6. Findings — REFACTOR (ranked)

| # | item | evidence ref | counter-evidence | driver | confidence | size | reversibility | risk-if-wrong | pre-registered expected effect |
|---|---|---|---|---|---|---|---|---|---|
| R1 | **`update-task.sh` close-gate chain (2,564 lines)**: extract each gate into a module behind a small registry that emits a typed event per evaluation (pass / block / bypass). This is the enabling half of G1. | D §1e, D §4.9 (size); F §3 (Task system: 249.6 fractional commits, **31.9% RCA density**, #3 highest); B §12 (no gate-evaluation record) | High churn may reflect a deliberate evolution of the gates rather than the file's shape. RCA is charged to touched files, not causing files (F §5). | **D2**, D1 | HIGH (D size and F cost are independent and measured) | L | Revert | Gate semantics drift during extraction. **Mitigation:** the existing update-task bats suite must stay green unchanged, with no test edits. | Task-system RCA density over the next 60 tasks touching it is ≤ 25%. Every gate evaluation produces one event line (see G1). |
| R2 | **`bin/fw` (10,032 lines; `do_doctor` ~1,300 lines inline)**: move inline verb bodies and doctor rails into `lib/`, one file per rail | D §1a, D §4.9, A §20; F §3 (Core CLI is #1 by cost: 1,073 fractional commits, 26.7% RCA) | Core CLI cost is inflated by pre-convention history and T-012 ID reuse (F §5). | **D2**, D3 | HIGH (D and F independent, measured) | L | Revert | Path-resolution regressions for consumers. `upgrade_fresh_machine_simulation.bats` must stay green. | `bin/fw` is under 5,000 lines. Fractional commits to `bin/fw` per month fall. `fw doctor` output is byte-identical on a fixed fixture. |
| R3 | **`agents/audit/audit.sh` (7,300 lines, 35 checks)**: one file per section, plus a thin runner | D §1e, D §4.9; F §3 (Audit is 6th by cost, **30.9% RCA density**) | Same attribution caveat as R1. | **D2** | HIGH | L | Revert | Checks are silently dropped in the split. **Guard:** check count before equals check count after, asserted by a test. | Check inventory is unchanged (35). Audit RCA density over the next 60 touching tasks is ≤ 25%. |
| R4 | **Component Fabric reverse edges**: compute `depended_by` from `depends_on` instead of storing it; reject non-file targets such as `C-008` | A §1 (461/1,268 cards have `depended_by`; `C-008` used as a target), B §6 (807 empty = the same fact, counted independently), C §3 (subsystem `unknown` on 42%) | An empty `depended_by` may be deliberate for leaf components, but inversion is exact by construction. | **F2**, D2 | HIGH (A and B agree on the measured value) | M | Revert | Tools that write `depended_by` by hand conflict with the computed value. | Inverse-edge parity reaches 100% (for every A→B edge, B lists A). Cards with empty `depended_by` fall from 807 to below 334 (the leaf count). |
| R5 | **Healing loop → RCA/learnings path.** The `issues`→healing path is almost unused, while the RCA gate and learnings are live. Re-point healing diagnosis to run at the RCA gate, and write its resolution into `learnings.yaml`. | C §2d (6 tasks ever passed through `issues`), B §14 (no event log), A §19 (`patterns.yaml` last written 2026-04-08), C §2e (502 substantive RCAs; learnings 710, live) | Manual `fw healing` invocations are **unknown** (no verb counter). The healing design serves D1. | **D1** | MEDIUM (usage of manual calls is absent) | M | Revert | A working manual diagnosis habit is disrupted. | Within 30 days, ≥1 healing suggestion is attached to a bug-class RCA. `patterns.yaml` gains ≥1 entry. |
| R6 | **Focus-drift bypasses (80% of the Tier-2 log)**: make an explicit focus switch a first-class logged event on its own stream, so the Tier-2 log carries only real overrides. **The gate still blocks undeclared drift.** | B §11 (941/1,174 = 80.2%; `--skip-sovereignty` at 172 is buried beneath them) | A gate bypassed this often may be miscalibrated in a way that needs different treatment. | **D2** (C2: noise consumes the attention real overrides need) | MEDIUM | M | Revert | If implemented as a gate weakening rather than a re-labelling, drift goes unblocked. **Constraint:** the block path is unchanged. | The Tier-2 log's share of focus-drift entries falls from 80% to under 10%. The count of focus-drift *blocks* is unchanged (needs G1). |
| R7 | **Test hygiene.** (a) Move tests that live in `agents/` into `tests/`: `test-tier0-patterns.py`, 6 stub tests, `test_docgen.py`, `revisit-at-preservation-test.sh`. (b) Stop tests writing into live `.hook-failure-counter`. | D §1d, D §1e, D §4.8 (invisible to `fw test` / unit-suite; UNVERIFIED whether any runner globs them); B §15 (`bogus-hook-name-for-T1628=19` in the live counter) | A runner glob may already pick them up. | **D2** (the Tier-0 regex suite guards a Tier-0 gate) | MEDIUM | S | Revert | The moved tests go red on first real run. That is a finding, not a regression. | `fw test unit` collects the Tier-0 pattern tests. The live `.hook-failure-counter` has no `bogus-*` keys after a full suite run. |
| R8 | **Dispatch hook matchers.** `check-dispatch.sh` is matched on `Task\|TaskOutput`, but the harness tool is `Agent`. The blocking half, `check-dispatch-pre.sh`, is unwired. | D §1d, D §4.2; B §15 (`check-dispatch` absent from the hook counter; `check-agent-dispatch` also absent in that snapshot, though D says it fired) | UNVERIFIED whether `Task` still fires in current Claude Code. The absence from the counter may just reflect a session without dispatches. | **D2**, F-AUTONOMY | MEDIUM | S | Revert | Over-matching on `Agent` duplicates warnings. | After one Agent dispatch, `.hook-counter` shows `check-dispatch≥1`. |
| R9 | **Dispatch ledger hygiene.** Stop writing an inline `outcome: pending` that is never updated. Stamp `schema_version` and `ts` on every row. | B §25 (1,575 stale `pending`; 8 key-sets; 50 rows without `ts`; 32.4% of dispatches with no outcome), C §1.1 (2,853 outcome rows, separate file) | Readers of the inline field would break. | **D2** (stale in-place state is C2) | HIGH (B and C measured) | S | Revert | Watchtower `/orchestrator` or `fw orchestrator status` reads the inline field. | New dispatch rows carry no inline `outcome`. 100% of new rows have `ts` and `schema_version`. |
| R10 | **Merge duplicates:** fw-shim / fw-router; `update.sh` / `upgrade.sh`; `_version_lt` / `release_version_lt`; `_sed_i` in `compat.sh` and `paths.sh`. **Split** `dispatch.sh` (SSH send vs Agent-gate approval). | D §1a, D §1b, D §4.5 | fw-shim is referenced by `upgrade.sh` and may exist in consumer installs (D §1b). `update.sh` has rollback semantics. | **D3**, D4 | MEDIUM | M | Revert | Old consumer shims break. The fresh-machine simulation must stay green. | One shim and one updater remain. Duplicate-function count is 0. `upgrade_fresh_machine_simulation.bats` is green. |
| R11 | **Loop detector off Node.** `loop-detect.sh` fails open when node or dist is missing. `lib/ts` holds only 2 utilities, and `node_modules` is untracked. | D §1c, D §4.3 | The committed `dist` works wherever node exists. | **D2** (a silent fail-open), D4 | MEDIUM | S | Revert | Behaviour differs between the TS and Python versions. | On a host without node, the loop detector still fires on a synthetic 4-repeat input. `fw build` has no remaining callers or is removed. |
| R12 | **Hardcoded host paths → config:** `notify.sh` (`/opt/150-skills-manager`), `fw deploy` (`/opt/claude-shared-toolkit`), cron commands (`/opt/999…`) | D §1a, D §1b, D §4.7; Y §3.10 | Host-local ops may deliberately live only on this host. | **D4** | MEDIUM | S | Revert | Existing cron lines break until regenerated (cron chain drift, CLAUDE.md L-364). | `git grep '/opt/'` over `bin lib agents` returns only config defaults. `fw doctor` reports "Cron registry in sync". |
| R13 | **Arc membership, single source.** Make `arc_id:` authoritative and derive `constituent_tasks` (populated on 6/20). Drop the 15 empty `bvp_scores: {}` keys on arcs. | B §2, C §3 | Some tools may read `constituent_tasks`. | **D3**, D2 | MEDIUM | S | Revert | Arc views lose members that are listed only in `constituent_tasks`. | Every arc's member list equals its `arc_id:` scan. Arc YAMLs contain 0 empty `bvp_scores`. |
| R14 | **Registers:** `.context/concerns.yaml` (24 OBS) vs `.context/project/concerns.yaml` (113 G) vs `inbox.yaml` (410 obs, 218 pending). Declare one authority per kind, and add a `component:` field. | A §17, C §1.1, C §1.2, C §2g | The two concerns files may serve deliberately different kinds (OBS vs G). | **D2**, D3 | MEDIUM | M | Revert | Watchtower `/gaps` points at the wrong file. | A documented authority exists for each register. ≥80% of new entries carry `component:`. |
| R15 | **Tracked, overwritten state files → append-only logs.** Covers `focus.yaml` (786 versions), `.hook-counter` (429), `.budget-status` (185), `.session-metrics.yaml` (257). This keeps the time series without per-commit noise. | C §1.7, A §6 (`.context` churn 27,781 touches, 30× source), B cross-cutting 1 | Git history of these files *is* the only time series today. **Do not untrack before an append log exists.** | **D2**, D3 | MEDIUM | M | Revert | The time series is lost if done in the wrong order. | `git status` on an idle session shows ≤3 modified `.context/working/*` files. The equivalent history can be read from the logs. |
| R16 | **Designer bundle recommits.** Each version recommitted a 9–11K-line HTML bundle (97,523 raw lines). Pin by sha instead of recommitting. | F §3 footnote 3; B §27 (`policy/designer-pin.yaml` already pins build and sha) | Consumers vendor the bundle from the repo (B §27), so it must remain obtainable. | **D4**, D3 (cost) | MEDIUM | S | Revert | A consumer install cannot fetch the bundle offline. | The next Designer version bump adds under 100 lines to git. The pin check in `fw doctor` still passes. |
| R17 | **Handover `tasks_touched`**: record only tasks with a commit or edit in the session | C §2d (median 15 sessions per task against median 2 commits; "noisy, do not trust") | Bulk-sync visibility may be intentional. | **F1** | MEDIUM | S | Revert | Resume loses peripheral context. | Median sessions-per-task over the next 100 handovers is ≤ 3. |
| R18 | **Prose truthfulness.** Fix dead references in 8/74 evergreen docs, including **`CLAUDE.md:459` → nonexistent `zzz-default.md`**, which is loaded into every session. Move 2026-02 plan docs to an archive path. Correct hook headers that claim wiring that does not exist (`session-silent-scanner` "cron every 15 min"; `subscribe-learnings` "recommended cron"). | E Q3; D §4.4; F §3 (root docs are #4 by cost, with 4.8% RCA) | Historical docs have record value (F1). **Archive, do not delete.** | **F3** (every session reads CLAUDE.md), D3, C1 | MEDIUM | S | Revert | None material. | Evergreen dead-reference count goes from 8 to 0. No hook header claims a schedule absent from `cron-registry.yaml`. |
| R19 | **`docs/generated/components/`** (1,275 files) is regenerated daily from fabric cards whose `purpose:` is 59% `TODO`. Skip TODO cards, and decide whether generated output should be tracked. | A §1, A §20, D §1e (daily cron), B cross-cutting 5 (counted twice via the vendored copy) | Watchtower or docs readers may rely on complete coverage (not evidenced either way). | **F2**, D3 | MEDIUM | S | Revert | A component page 404s for TODO cards. | Tracked generated files fall by about 740. Daily regeneration changes only cards whose source changed. |
| R20 | **`policy/value-drivers.yaml` header text** contradicts its contents (F-ORCH named active; the F3/F1 weight reasoning). Text fix only; **the weights are Sovereign** (Q1). | B §18 observation 2 | The header is historical narrative. | All rankings (F3, F1) | MEDIUM | S | Revert | None. | Header comments match the active driver list. The audit retire_when rail output is unchanged. |
| R21 | **`happiness.jsonl`** is named like operator sentiment but is 100% agent-written, across 4 task IDs (one of them `T-0000`). Relabel it as agent self-report or stop writing it. | C §1.3, C §2f | It may be a deliberate continuous-run experiment (its window overlaps continuous-run). | **D2** (C2: a misleading channel) | MEDIUM | S | Revert | An experiment loses its sink. | The file is renamed or dormant. No consumer reads it as operator signal. |

## 7. Findings — ADD (ranked)

Instrumentation ADDs are ranked separately in §9. They are not repeated here.

| # | item | evidence ref | counter-evidence | driver | confidence | size | reversibility | risk-if-wrong | pre-registered expected effect |
|---|---|---|---|---|---|---|---|---|---|
| A1 | **Make the nightly suite honest.** Give the pytest leg a budget it can finish in. Treat "0 tests executed" as a **failure**. Surface the red. | A §14 (every run in the 8-day window exits non-zero; pytest `files: 202, tests: 0, exit 124, failed_count 0`; 13 named bats failures), A §18 (this suite *is* the de-facto CI), C §1.2 | Timeouts may be host-load-specific. | **D2**, D1 | MEDIUM (observed, one gatherer; the window is corroborated by B §13) | M | Revert | A longer suite collides with other crons. | Within 14 days: pytest `tests > 0` on every nightly run. `runner_exit=0` on ≥1 run, or each red is triaged to a task. |
| A2 | **Repair the Tier-2 audit trail.** Fix the writer's encoding, repair `.gate-bypass-log.yaml` (invalid UTF-8 at byte 835), and add a parse check to the audit. Also explain why it has been silent since 2026-09-08. | C §1.3, B §11 (counted by grep; silent 8 days), Y §3.5 | The silence may simply mean no bypasses happened. | **D2** ("auditable execution") | HIGH (B and C independently measured) | S | Revert | None: this is a repair. | `yaml.safe_load` succeeds. The audit fails if it stops parsing. The silence is explained, as either a writer defect or a genuine absence. |
| A3 | **Fail loud on a missing hook script.** `fw hook` exits 0 when the script is absent. Increment `.hook-failure-counter` and have `fw doctor` WARN. **Do not block**, to avoid bricking sessions. | D §1a, D §4.3 | Fail-open may be a deliberate availability choice. This row keeps the fail-open and adds visibility. | **D2** (C2: a gate that vanishes silently) | MEDIUM | S | Revert | Noise if a hook name is misspelt in a test. | Renaming one hook script in a sandbox produces a doctor WARN naming it. |
| A4 | **Forward-looking touch set at task creation.** Predict `components`/`write_set` at creation (from fabric search or name heuristics, labelled *predicted*). This makes quadrant selection, `fw write-set check` and blast-radius cost computable before work starts. | Y §3.4 (OBS-415: 85% of ranked tasks have no cost), B §17 (`write_set:` declared by 0 of 3,357 tasks), D §2 (blast radius is advisory; no gate consumes it), C §1.6 (`components` set only at completion) | Predicted touch sets may be wrong, and a wrong prediction may mislead scheduling. Label them clearly and never gate on them. | **F2**, F-AUTONOMY | MEDIUM | M | Revert | Scheduling decisions rest on bad predictions. | `fw bvp --quadrant hv-lc` reports ≤ 30% no-known-cost (from 85%). `fw write-set check` exits non-2 for ≥ 50% of active pairs. |
| A5 | **Schedule `revisit-due-scan.sh`.** `handover.sh:811` reads `.revisits-due.txt`, but nothing writes it. | D §1d, D §4.4 (no registry entry); C §1.4 (`working/.revisits-due.txt` ABSENT) | The scan may have been retired deliberately while the reader was forgotten. If so, remove the reader instead (operator's call). | **D2** (C2: the handover reads a file that never exists) | HIGH (D wiring and C absent-sink agree) | S | Revert | A daily scan adds cron load. | `.revisits-due.txt` exists and is ≤ 24 h old. `fw doctor` reports cron in sync. |
| A6 | **Wire the consumer half of learnings-over-bus** (`subscribe-learnings-from-bus.sh`), or stop publishing. 176 learnings are published to `channel:learnings` and none is consumed. | D §1b, D §4.4 (no caller, no cron); C §1.4 (`project/received-learnings.yaml` ABSENT); B §22 (176 records) | Consumption may happen in *other* projects' installs. | **F-RECALL** | HIGH (D, C and B agree) | S | Revert | Duplicate or noisy learnings arrive from other projects. | `received-learnings.yaml` exists and grows. Watchtower's reader shows entries. |
| A7 | **Restart the liveness monitor and alarm on staleness for every monitor stream.** `liveness.jsonl` last wrote 2026-08-14. | A §15, B §24, C §1.2 (all three independent) | B reads the file as a 10,080-line ring, so first/last timestamps mislead. The last timestamp is still 5 weeks old. | **D2**, F-AUTONOMY | HIGH | S | Revert | Alert noise. | A liveness row from the last 5 minutes exists. The audit fails when any `monitors/*.jsonl` is >1 h stale. |
| A8 | **Wire `check-inception-recommendation`** (T-2205, "Producer 4"; its `.py` is already imported by `lib/review.sh`). **Wiring edits `.claude/settings.json` and needs operator approval** (Q4). | D §1d, D §4.1; Y §3.1 | An hourly cron backstop already exists. A write-time block may be friction without added catch. | **D2** (C1) | MEDIUM | S | Revert the settings edit | False blocks on inception saves. | The hourly retrofit cron injects 0 DEFER stubs over 14 days, because the gate catches them at write time. |
| A9 | **Wire `check-task-ac-structure`** (T-2420: refuses a `### Human` section placed after an intervening `## `, which would corrupt P-010 counting). Operator approval required (Q4). | D §1d, D §4.1 | Unwired for 3 months with no flagged incident. Absence of an incident report is not evidence of no incident. | **D2** | MEDIUM | S | Revert | False blocks on legitimate layouts. | 0 tasks in `active/` match the malformed pattern after 30 days (static-scan count). |
| A10 | **GitHub CI on the development branch.** `test.yml` triggers only on `main`/`master`, and development is on `bleeding-edge`. | A §18 | A red CI on every push may be noisy until A1 lands. CI run history is UNVERIFIED. | **D2** | MEDIUM | S | Revert | CI minutes and noise. | ≥1 CI run on a `bleeding-edge` push within 7 days. |
| A11 | **Learning distillation.** `patterns.yaml` has been stale since 2026-04-08. The consolidation report (659 stale / 653 recommendations, 2026-08-17) is unacted. Schedule and surface consolidate/promote review. | A §19, C §1.3 (report), C §1.2 (learnings 710, patterns 19, practices 12) | Promotion is a human-judgement step. **Surface it; do not auto-promote** (C3). | **F-RECALL**, F1 | MEDIUM | S | Revert | Review burden on the operator. | The consolidation report is regenerated ≤ 7 days old. ≥1 promotion decision is recorded per month. |
| A12 | **Dead-session capture.** The SessionEnd leg is deliberately unwired (T-1459), so nothing covers a session that dies without Stop or PreCompact. | D §2, D §1d | The deliberate non-registration may have a reason that no evidence file states. **Operator ruling needed.** | **F1**, D1 | MEDIUM | M | Revert | Duplicate handovers. | For a killed test session, a recovery handover exists within 15 minutes. |
| A13 | **Doc path-existence lint** over evergreen docs. E's method is a ready specification. Today the only doc-drift rail is fw-verbs ↔ CLAUDE.md. | A §20, E Q3 | False positives on illustrative paths (E cleared 9 by hand), so an allowlist is needed. | **D3**, F3 | MEDIUM | S | Revert | Lint noise. | The lint runs in `fw test lint` and flags the 8 docs from E Q3 until R18 fixes them. |

## 8. Findings — INVESTIGATE (ranked by what they block)

| # | item | what is unknown | the one check that would settle it | what it blocks |
|---|---|---|---|---|
| I1 | **Do the ~12 hooks matched only on `Write\|Edit` actually fire?** (`check-arc-id`, `check-human-ac-tick`, `check-inception-*`, `check-onboarding-gate`, `check-heredoc-cmd-sub`, `check-worktree-governance-write`, `check-active-completed-dup`, `check-fabric-new-file`, `commit-cadence`, `check-settings-edit`) | Both counter snapshots (A §16, B §15) list only hooks matched on `Bash` or `*`. C §1.5 says every fire increments the counter; the reset site is UNVERIFIED. | Under a scratch task, copy `.hook-counter`, perform **one** Edit on a task file, and diff. The keys for those hooks either appear or they do not. | Every claim that write-time governance is live (Y C1). Also R1 and G1 design. **Run this first.** |
| I2 | **172 `--skip-sovereignty` bypasses** (B §11): were they human-authorised? | Actor and rationale per entry. The file does not parse (A2). | Extract the 172 entries by grep and tabulate actor / `CLAUDECODE` / rationale fields. | Sovereign Q3. This directly tests the Authority Model. |
| I3 | **Is the budget gate reading the current session?** `.budget-status` says `S-2026-0907-1917` while `.session-baseline` is from 2026-09-16 (C §1.3). | Whether the context-exhaustion gate is watching a stale transcript. | After one Bash call, check whether `.budget-status` session_id and timestamp updated to the current session. | Trust in the only gate protecting uncommitted work at context exhaustion (D2). |
| I4 | **Does `continuous-driver` deliver anything?** It relies on `termlink inject`, which G-097 says exits 0 and delivers nothing into a live TUI (E Q6). `continuous-run.jsonl` stops on 2026-09-11 (C §1.3). | Whether a 10-minute cron is a silent no-op. | Over 7 days, join driver cron fires to `continuous-run.jsonl` / `.stop-driver.log` turn events. | F-AUTONOMY claims; a DELETE or REFACTOR of the driver. |
| I5 | **govd (arc-013):** holder daemon, relay and policies (7 files, 1 commit each, 2026-06-18) | Whether the privileged daemon has ever run. The `govd/{state.json,audit.jsonl,relay-audit.jsonl}` sinks are ABSENT (C §1.4, D §1c, D §1e). | Check the process list and systemd units for govd, and search the host for its state directory. | A DELETE or ADD on a **privileged** surface (D2). |
| I6 | **arc-020 `aef_*`** (7 modules, 9 days old; `aef_repo_source` imported only by tests; `provisions.jsonl` and `circuits/registry.jsonl` ABSENT; `.context/circuits/` empty) | Whether the arc is in flight or stalled. | Read the arc-020 anchor task's status and horizon. | Any judgement on these modules; premature now. |
| I7 | **Is the bare-path chat regression still occurring?** (unwired `chat-bare-path-scan/-warn`, T-2183) | Recurrence rate since `review-batch` shipped. | Count bare `/review/T-` strings in assistant turns across the 300 surviving transcripts (C §1.8). | Wire (ADD) vs DELETE for the fourth unwired gate (Y §3.1). |
| I8 | **12 orphan Watchtower routes**, 3 with zero references anywhere (`/api/bvp/driver/propose`, `/api/fleet/status`, `/approvals/continuous-state`) (E Q1) | External or JS callers. The repo has no request log. | 30 days of route access log (G3). | DELETE of up to 12 routes. |
| I9 | **Reviewer detector precision.** `l387-sigpipe-risk` fired 513×, `AC-verify-mismatch` 475×, CONCERN on 28% of tasks, 99 overrides (B §13, C §1.3). | Whether the top detectors are signal or noise. Reviewer RCA density is 31.8% (F). | Hand-label 20 random fires of each of the top 2 detectors. | Retuning (never deletion without precision data). Also the static_scan.py split. |
| I10 | **`bus-handler.sh`**: unwired (D §1d), yet `.context/bus/handler.log` was written 2026-06-02 (A §15) | What ran it. | `systemctl list-units --type=path` plus the crontab, searched for bus-handler. | Delete vs document. |
| I11 | **Antigravity integration** (`antigravity_steps.py`, `subagent_dispatch.py`: 0 code loaders; `antigravity_bridge.py`: 1; 3 weeks old) | Whether the AGY provider is in use on any host. | Run `fw sessions` for antigravity on the fleet (operator). | D4 portability claim; DELETE of 2 files. |
| I12 | **The tracked `.agentic-framework/` self-copy** (6,659 churn touches/12mo; doubles every count; holds only 8 of 16 designer maps) | What consumes a *tracked* self-copy. | Grep tests and doctor for execution via `.agentic-framework/bin/fw`. | Halving review noise; `vendor self` ordering cost (CLAUDE.md OBS-250). |
| I13 | **Migrations still needed?** `migrate-horizon-null-completed.sh` looks done (C §1.6: horizon populated on 0 completed tasks) but the audit names it (D §3a). `arc-id-migration.sh` looks **not** done (`arc:*` tags still present, C §3). | Whether the audit invokes the script as a check. Remaining tags. | Read the audit call site; count `arc:` tags on tasks lacking `arc_id`. | DELETE of both, or running the second. |
| I14 | **Low-reference verbs with absent sinks:** `fw triage` (`triage-dispositions.jsonl` ABSENT), `fw peer` (0 tests, no cron), `fw prompt` (0 tests) (D §3b, D §3c, C §1.4) | Invocation frequency. | 30 days of the per-verb counter (G2). | DELETE of 3 verbs. |
| I15 | **tools/ and scripts/ one-offs:** `escalation-scan-v0.py` vs `-v0.5.py`, `g064/065/066-readiness.py`, task-ID probe scripts; `scripts/` (12) vs `lib/templates/scripts/` (12) (A §19) | Callers; whether the two script sets are copies. `tools/` was inventoried by no gatherer. | `git grep` each basename, and `diff -r scripts lib/templates/scripts`. | DELETE of accreted one-offs (Tools is #5 by cost, F §3). |
| I16 | **TermLink cursor anomaly:** client cursor 1,611 > hub head 1,428 on `agent-chat-arc`; 39 topics but 37 log files (B §22, B §23) | Hub reset or re-creation history. | Hub restart log and topic creation timestamps. **Home the fix in the TermLink repo** (gap homing). | Trust in cross-agent message delivery (D2). |

## 9. Data gaps as ADD candidates in their own right (ranked by what they unlock)

| rank | missing measurement | evidence | driver | what it unlocks | size | confidence the gap is real |
|---|---|---|---|---|---|---|
| G1 | **Gate evaluation events** (every gate: pass / block / bypass, with task and caller). Emitted by R1's registry and by the hook runner. | B §12, Y §3.6, A §16 (counter has no pass/fail split) | D2, D1 | Effectiveness of all ~16 wired PreToolUse gates and every close gate; focus-drift calibration (R6); I1 made permanent; the only honest basis for any gate DELETE. | M | HIGH (B, plus A's counter structure) |
| G2 | **Per-`fw`-verb invocation counter** (prospective, in `bin/fw`) | A §16, B §15, D header, Y §3.9 | D2, D3 | Usage-based DELETE/KEEP for 99 verbs (83 with no cron reference); lifts the MEDIUM cap on about 40 zero-code-reference items; settles I14. | S | HIGH (A and B) |
| G3 | **Watchtower request and error log** (persistent, surviving restarts) | A §15 (29-line log truncated on restart; no traceback store), E header (no per-route usage) | D2 | 12 orphan routes (I8); 84 templates; value of the #2 cost centre (F §3: Watchtower, 514 fractional commits). | S | HIGH (A and E) |
| G4 | **Per-session token delta + transcript id in handover; per-task attribution** | B §16, C §2c (cumulative-only figure; transcripts evicted before 2026-08-17; only 46% of worker $ attributable, F §5) | F1, D2 | Real cost per subsystem (F measures commits, not tokens); an honest BVP cost check; context-budget policy evidence. | S | HIGH (B and C) |
| G5 | **Structured `caused_by:` on bug-class tasks (at the RCA gate) + append-only status transitions** | C §2e and §2g (14 explicit cause links; produced-by NOT AVAILABLE), B §1 (status overwritten in place; 0 reopen fields) | **D1** | "Which subsystem *creates* bugs", as opposed to which one gets touched while fixing them (F §5 caveat); a real rework rate; the healing loop's evidence base. | S | HIGH (B and C) |
| G6 | **Wired-but-never-fired detector** (audit rail: code-declared sinks absent on disk) | C §1.4 (~20 sinks), corroborating D §4.4 | D2 | Generalises A5, A6, I5, I6 and I10 into a standing check; C2 coverage. | S | MEDIUM |
| G7 | **Operator-feedback record** (structured pushback / correction events) | C §2f (none; 65 free-text hits; `happiness` is agent-sourced) | D1 | Whether sovereignty moments were hit or missed. This is the purpose clause "force a human decision at exactly the moments…". | S | HIGH (C, plus the B §3 self-report caveat) |
| G8 | **Value realization / confirmation** (`bvp-realization.jsonl`; any `fw bvp confirm` use) | B §19–21, C §2a, F §6 | Depends on Q2 | Whether BVP measures anything. **Only if the operator keeps BVP (Q2).** | S | HIGH |
| G9 | **Test durations, per-test history (flakes), code coverage** | A §12 (coverage ABSENT; `pytest-cov` not installed), A §14 (no durations, no flake tracking; skipped tests unnamed) | D2 | A1 budgeting; test REFACTORs; "is X untested" claims (today only grep-derived, A §13). | M | HIGH (A, plus the E Q4 limits) |
| G10 | **Complexity / duplication reports** (radon, jscpd; shellcheck report exists as a tool but has never been run) | A §2–§4, A §7 | D3 | Hotspot ranking; turning R2, R3 and R10 from size-driven into measured. | S | HIGH |
| G11 | **Bus drop / reject observer** (home: TermLink repo) | B §26, B §22 (97.6% of `agent-presence` evicted) | D2 | Delivery reliability for pickup, learnings and peer. | M | HIGH (B, plus the documented `ok:true ≠ delivered`) |
| G12 | **Workflow execution traces by node uid** | B §31 (DESIGNED-ONLY; no runtime) | Depends on Q5 | Only relevant if the operator chooses executable workflows (Q5). **Do not build ahead of that decision.** | L | HIGH |

**Unlock order:** G1 and G2 lift the most decisions (all gates, all verbs), and G2 is the cheapest. G3 and G5 follow.

## 10. Contradictions carried forward (Y §3), with verdicts

| # | contradiction | verdict | basis |
|---|---|---|---|
| 1 | Four built write-time gates are unwired | **Defect**, resolved per gate: A8 and A9 wire (ADD); X2 deletes (superseded); I7 decides the fourth. | D §4.1; C1 |
| 2 | 0 confirmed BVP scores | **Needs operator ruling** (Q2). It is a defect *if* value scoring remains a product claim. | B §19 |
| 3 | BVP predictions carry no independent signal | **Defect** (C2: it looks like a measurement and is not one). Measured. | F §6, C §2a |
| 4 | Quadrant selection is not executable | **Defect** in the Mandate's selection rule; A4 is the structural fix. **Needs an operator ruling** on what replaces it meanwhile. | Y §3.4, D §2 |
| 5 | Tier-2 audit trail does not parse | **Defect** (A2). | C §1.3 |
| 6 | Gate first-pass rate is ABSENT | **Defect** (G1). The most consequential gap. | B §12 |
| 7 | No out-of-band bus observer | **Defect**, homed in the TermLink repo (G11). | B §26 |
| 8 | `aef:endpoint` has zero occurrences; ratification is a filename prefix | **Acceptable today** if Designer is declared documentation or modelling only: nothing gates on ratification, and only vendoring keys on the prefix (E Q5). A **defect** if executable governance is the goal. **Needs operator ruling** (Q5). | B §27–31, E Q5 |
| 9 | No per-verb usage counter | **Defect** (G2). | A §16, B §15 |
| 10 | Hardcoded host paths | **Defect**, small, D4 (R12, X6). | D §4.7 |
| 11 | Recall and Designer engines sit outside the governance dirs | **Acceptable.** This is an artefact of review scope, not of the product. Recall is the one capability with real usage telemetry (1,291 queries/month, 94% hit rate, C §1.3). | D §2, D §4.6 |
| 12 | Handover has the highest RCA density | **Acceptable / not a finding.** n = 12.1 fractional tasks, about 4.5 RCAs (F §3 small-sample flag). Revisit when n ≥ 30. | F §3, F §4 |

## 11. What was NOT reviewed, and why

- **`tools/`, `scripts/`, `deploy/`, `install.sh`, `vendor/`, `.github/`:** no gatherer inventoried them file by file. D's scope excluded them. E read `tools/` only for Designer call sites. F charges them 303 fractional commits (#5 cost), so a large cost centre is **unjudged** beyond I15.
- **Behaviour of `web/` Python:** E inventoried routes, templates and assets, not blueprint logic or the recall engine (`web/embeddings`, `web/ask`). The 2.67 GB vector index (C §1.3) was not assessed for cost or benefit.
- **Security posture** (Watchtower `FW_SECRET_KEY` fallback and Werkzeug-in-production warnings, A §15; `secret-scan`; `.context/secrets/`): out of scope for every brief. **Not** asserted safe.
- **The T-2621 map-vs-code conformance rail:** E flagged it as lib/agents scope; D did not inspect it.
- **Per-verb churn:** UNVERIFIED (D method; it would need `git log -L`).
- **Content quality of the test suite:** only skips, orphans and self-referential lints were checked (E Q4). The 13 failing bats tests are named in A's source file but not listed in the evidence, so they were not judged individually.
- **Contents of git hooks** (`agents/git/lib/hooks.sh`, 1,389 lines): inventoried only.
- **The TermLink repo itself, consumer projects, and OneDev / GitHub CI history:** unreachable or out of scope (A §17, A §18).
- **`.claude/commands` skills** beyond D §1c's propagation note.
- **Budget:** all seven files were read in full, including every §3a row of D. Nothing was skipped for budget. D's per-row data was used selectively: rows not cited here were judged **KEEP by default**, with no finding.

## 12. Sovereign questions for the operator (priority order)

1. **Confirm or amend the yardstick.** It is derived, not confirmed. In particular: should F3 and F1 (weight 7) really equal D2 and outrank F-RECALL and F2? Every ranking above moves with this answer (§2; B §18).
2. **Is value scoring still a product capability?** The facts: 7 months, 3,319 machine proposals, 0 human confirmations, no independent signal, 85% of ranked tasks uncostable. Choose one:
   - a. Invest: confirm a sample of scores and add realization logging (G8, A4).
   - b. Retire the estimator sweeps and drop "value scoring" from the README.
   - c. Keep as is, knowingly.

   X1 is contingent on this answer.
3. **The 172 `--skip-sovereignty` bypasses** (after I2): were these your authorisations? If not, that is a sovereignty breach, not an efficiency question.
4. **Approve individual `.claude/settings.json` edits:**
   - wire A8 (`check-inception-recommendation`);
   - wire A9 (`check-task-ac-structure`);
   - the R8 matcher change;
   - A12 (SessionEnd capture). This last one reverses a deliberate T-1459 decision.
5. **Designer direction:** executable workflows (endpoints, runtime, traces: G12), or documentation and modelling only? This decides contradiction 8 and whether ratification must become recorded state.
6. **17 in-progress arcs, none ever closed or abandoned** (B §2). Arc closure is yours (C3). An arc-by-arc review is overdue by the data.
7. **Review backlog.** 265 active tasks carry `date_finished` (C §1.6). The *inferred* reading is that these are partial-complete tasks awaiting your Human ACs. That is not an inefficiency, but it is the size of the queue waiting on you.
8. **Keep or retire whole subsystems after investigation:** govd / arc-013 (I5), arc-020 (I6), Antigravity (I11).
9. **Host-specific ops verbs inside a portable framework:** `fw gpu` (X3) and `fw deploy` (R12). Re-home them, or keep them?
10. **Instrumentation cost.** G1 and G2 add a write to every hook and every command. Approve the principle before any build task is filed.
