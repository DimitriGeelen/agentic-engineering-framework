---
id: T-3391
name: "Autonomous run 2026-09-19: top-down BVP selection, second pass — score-through-the-scorer"
description: >
  Autonomous run 2026-09-19: top-down BVP selection, second pass — score-through-the-scorer

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
# demo_target: true               # T-2286: optional — marks task as reserved for an orchestrated demo
#                                 # worker (e.g. arc-010 HM-A dispatches via mcp__fw__work_on). When set,
#                                 # `fw work-on T-XXX` refuses unless --i-am-demo-orchestrator (CLI) or
#                                 # FW_I_AM_DEMO_ORCHESTRATOR=1 (env) is passed. Prevents the parent
#                                 # session from consuming the captured→started-work transition the demo
#                                 # worker expects to drive. Origin OBS-057.
created: 2026-09-19T15:59:56Z
last_update: 2026-09-19T16:24:08Z
date_finished: 2026-09-19T16:24:08Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── BVP scoring fields (T-1918, arc-006). See docs/reports/T-1915-bvp-inception.md for semantics. ──
# bvp_scores:                     # confirmed per-driver scores 0-5, set by `fw bvp confirm` (T-1924).
#                                 # Sovereignty boundary — only set after human or agent confirmation.
#                                 # Shape: {D1: <int 0-5>, D2: <int 0-5>, D3: <int 0-5>, D4: <int 0-5>, [<free-driver-id>: <int>]...}
# bvp_scores_proposed:            # estimator-proposed scores (T-1922 worker). Persists when ≥2 delta
#                                 # from bvp_scores: on any driver (M3 v2-delta). Shape: list of timestamped entries.
# cost_estimate:                  # F8 composite: 0.6×blast_radius + 0.3×tier + 0.1×effort.
#                                 # Q2 fallback: T-shirt S/M/L/XL mapped to 2/4/6/8 when blast_radius is not yet computable.
cost_estimate_proposed:
  - ts: '2026-09-19T16:15:09Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=319,acs=7)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-19T16:15:19Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3391: Autonomous run 2026-09-19: top-down BVP selection, second pass — score-through-the-scorer

## Context

Second autonomous run under the operator's mandate (top-down selection: project
objectives → arc → task by BVP quadrant → AC-required activities; verb gates
only; scored-before-started; Sovereign questions surfaced, not resolved). The
first run, T-3390, stopped on condition 3: SQ-1 — the quadrant view could not
classify any open task (zero confirmed scores; all 26 Q1/Q2 rows at the
no-signal default 108; signal-bearing tasks unquadrantable because cost needs
`components:`, resolved only at close — OBS-439). The operator reissued the
mandate unchanged. This run treats that as an instruction to proceed under the
mandate's own rules, so its first unit is to make the instrument produce scores
*through the scorer* (`fw bvp estimate` / `estimate-cost`), not to re-derive
the stop.

Run-start state (recorded checks): branch `bleeding-edge` level with origin at
`e41803af9`; focus null; arc focus `ewcr-arc0-contract-evidence`; Watchtower
running at :3002 (identity-verified via `fw watchtower status`); 242 pending
observations; T-3390's four Sovereign questions (SQ-1..SQ-4) unanswered.

## Acceptance Criteria

### Agent
- [x] Every unit of work in `## Run log` states its selection (objective → arc → task → quadrant) and rationale BEFORE the execution entry, with the recorded check or verb output that closed it
- [x] Every task this run scores or re-scores is scored through the scorer (`fw bvp estimate` / `fw bvp estimate-cost`), never by hand-written `bvp_scores*` or `cost_estimate` values — the run log names each such invocation and its output
- [x] Every gate refusal encountered is recorded in `## Gate refusals` with the sanctioned route taken instead (no `--no-verify`, `--force`, `--skip-*`, Tier-2 env vars)
- [x] Every Sovereign question raised is recorded in `## Sovereign questions` with options, and no such question is decided by this run
- [x] `## Handback` covers the six mandated headings (objectives advanced / arc state / remaining Q1-Q2 per task / Sovereign questions in priority order / gate refusals / cost-vs-estimate deltas)

## Run log

### Unit 0 — bootstrap (this record)
- **Checks:** `git rev-list --count origin/bleeding-edge..HEAD` → 1 (e41803af9, pushed this session after the audit lock cleared: `8076e17d1..e41803af9`, audit fails=0); focus null; `fw watchtower status` → running :3002.
- **Gate:** `check-active-task` refused a read pipeline (`xargs … sh -c`) under null focus → filed this task via `fw work-on` first (verb), then re-ran the reads under it.
- **Instrument re-read (prior run's `fw bvp --include-proposed` output, 205 tasks):** 31 tasks carry a cost; of those **26 sit at exactly BVP 108 / norm 0.40 — the no-signal default — and 5 below it**. The quadrant medians are computed over those 31, so the BVP median *is* the default: `hv` ≡ "estimator found no signal", and `lc`/`hc` is a 3.6-vs-3.7 split on the effort term. All 26 Q1/Q2 rows are `workflow_type: inception`; the reason is structural — inceptions get a cost through the T-2189 `target_blast_radius` exception, builds get none until `components:` resolves at close (T-3068). Every signal-bearing open task (T-2667 111, T-2268 94, T-1820 87, T-2170 81 …) is therefore quadrant-less, and would read `lv` even if costed, because it scores below the default. Sharper form of OBS-439; recorded, not adjusted (producer-not-judge).

### Unit 1 — selection
- **Objective:** D2 Reliability / D1 Antifragility — a decision the project has since made elsewhere (arc-019 EWCR took up procedure-level enforcement) is still open as an inception in arc-014.
- **Arc:** arc-014 designer-corpus (rollup 86, in flight, not blocked). Skipped above it: arc-013 (SQ-2, hypervisor stack absent), arc-019 (SQ-3, operator review transfer / finalisation), arc-002 (no open agent work: T-1718/T-1719 are partial-complete, `owner: human`), arc-011 (only quadrant row T-2323 is DEFER'd by recorded decision — SQ-4).
- **Task:** T-2668 "guided-mode procedural enforcement (package Lock 6) inside mirror+rails" — **Q1 (hv-lc, 108 proposed)**. Tie-break over T-2669/T-2670 (same 108): T-2668's question has decisive existing evidence (EWCR architecture c9070637, Arc 0 contracts v1, T-3147), so its three Agent ACs close by read-only research; T-2669/T-2670 need design exploration with no such evidence base. T-2268 (94) and T-2170 (81) rejected: `owner: human`, T-2268 has only Human ACs left; both are below the instrument's value median anyway.
- **Activities (AC-required only):** problem statement validated; assumptions tested; recommendation written with rationale. Then `fw task review T-2668` — the go/no-go is Sovereign and is NOT taken here.
- **Execution mode:** self-executed (inception class — "dispatch the review, never the exploration"); TermLink not used for the research, recorded here as the reason. Research artefact first per C-001 (`docs/reports/T-2668-*.md`).

### Unit 1 — execution (T-2668)
- **Verb:** `fw work-on T-2668` (focus switched, status started-work). **Gate:** G-067 inception Open-Questions readiness refused a non-allowlisted read until an IW question was filed → filed IW-1..3 first (Edit), then researched with plain reads.
- **Checks recorded:** `fw assumption add` ×3 (A-054/A-055/A-056) → `invalidate A-054` (T-2663 GO "or park it as a named future arc"), `invalidate A-055` (git log windows on `agents/context/check-tier0.sh`: baseline 20/6, interim 1, post-rail 3/0 — unattributable), `validate A-056` (architecture §7.2/§7.3/§9/§11, contracts v1). `fw reviewer T-2668` → **Overall: PASS, Needs Human: no, Findings: none**. Mechanical: artefact present; 3 dispositions (2 answered, 1 dissolved), 0 open; Recommendation NO-GO.
- **Closed/parked:** three Agent ACs ticked as each landed; `fw task review T-2668` → http://192.168.10.107:3002/inception/T-2668 — go/no-go reserved to the operator. Commit c07504a05 (exploration commit 1/15).
- **What changed:** `docs/reports/T-2668-guided-mode-supersession-review.md` (new), T-2668 body filled (problem statement, assumptions, IW dispositions, plan, fence, criteria, NO-GO recommendation, decision record), `assumptions.yaml` +3. No source, no policy.
- **Cost vs estimate:** estimator `effort=6, tier=4, blast_radius=3` — all `(no-signal)`. Actual: read-only research, ~35 tool calls, 1 commit, zero components touched. The estimate carried no information either way; the cost driver that mattered (evidence already existing) is not something the heuristic reads.
- **Surfaced:** (a) P4's falsifiability test is confounded by maturity — transfers to arc-019's evidence design; (b) T-2670's subject appears in EWCR §8.3 → same supersession check warranted.

### Unit 2 — selection
- **Objective / arc:** unchanged (D2/D1; arc-014 designer-corpus, still the highest-ranked unblocked arc with Q1 rows).
- **Task:** T-2670 "workflow fabric: queryable cross-map index (package Lock 4 / SD-15)" — **Q1 (hv-lc, 108)**. Over T-2669 (same score): EWCR §8.3 "Workflow Fabric: the process-topology join" and roadmap Arc 4 ("Operator control and Workflow Fabric projection") / Arc 5 item 3 ("Workflow Fabric derived index, and impact query") name T-2670's deliverable directly, so the same read-only supersession research applies; T-2669 (audience lenses) has no supersession signal and would need design dialogue.
- **Activities:** the three Agent ACs; `fw task review T-2670`. Self-executed, same reason as Unit 1.

### Unit 2 — execution (T-2670)
- **Verb:** `fw work-on T-2670`. G-067 handled by filing IW-1..3 before any non-allowlisted read.
- **Operator event mid-unit:** commit f4a1ee07d (author Dimitri Geelen, "T-2668: inception decision GO (via Watchtower)", 2026-09-19T16:11Z) moved T-2668 to `completed/` with **Decision: GO** — carrying the NO-GO rationale verbatim. Recorded as **SQ-5** below; nothing is built off it. Side effect: the index held a stale reversal of that commit (episodic shown deleted, task file reverted) while the working tree equalled HEAD → re-`git add` of both paths realigned the index without a gated verb; the post-commit footprint refresh of `.context/episodic/T-2668.yaml` remains staged for the handover sweep (see Gate refusals).
- **Checks recorded:** store census `ls .context/designer/projects` → 16 entries; `grep -rl callActivity|calledElement|handoff` → 10 maps / 29 hits; search of tasks/inbox/concerns for cross-map demand since 2026-07-28 → none filed, two bespoke scans found (`tools/corpus_lint.py:614 cross_map_typed_events`, `tools/corpus_explain.py --search`). `fw assumption` A-057 invalidated, A-058 invalidated, A-059 validated. `fw reviewer T-2670` → **Overall: PASS, Needs Human: no, Findings: none**. Mechanical: artefact present; dispositions 2 answered + 1 dissolved, 0 open; Recommendation NO-GO.
- **Closed/parked:** three Agent ACs ticked; commit 0f22cac39; `fw task review T-2670` → http://192.168.10.107:3002/inception/T-2670. Go/no-go reserved to the operator; the form text spells out what GO and NO-GO each mean, because of SQ-5.
- **What changed:** `docs/reports/T-2670-workflow-fabric-supersession-review.md` (new); T-2670 body filled; `assumptions.yaml` +3. No source, no policy.
- **Cost vs estimate:** estimator `effort=6, tier=4, blast_radius=3`, all no-signal. Actual: ~25 tool calls, 1 commit, zero components. Same finding as Unit 1.
- **Calibration data point (unsolicited):** the cron `bvp-estimator-sweep-15m` scored this run record at 16:15Z from its filled body — D1=4 (structural-gate), D2=4 (fw-audit-or-doctor), D3=3, D4=2 — so the 108 rows are template bodies the heuristic cannot read, not estimator blindness to prose. Cost still `blast_radius=?` (no components).

### Unit 3 — selection
- **Objective / arc:** unchanged; arc-014's last Q1 row.
- **Task:** T-2669 "audience lenses on corpus maps (package P1: functional/logical/technical/pseudocode)" — **Q1 (hv-lc, 108)**. Last remaining Q1/Q2 row in an unblocked in-flight arc. T-2662 §4 already routed SD-14 here with "rec NO-GO — no read-pull yet; operator may override"; no EWCR section names audience lenses, so the research question is narrower: has a read-pull appeared since 2026-07-28, and is anything in arc-019 or elsewhere an owner. Same read-only method; if the evidence needs design dialogue, park with the question stated rather than invent a design.
- **Activities:** the three Agent ACs; `fw task review T-2669`.

### Unit 3 — execution (T-2669)
- **Verb:** `fw work-on T-2669`; IW-1..3 filed first (G-067).
- **Checks recorded:** T-2622 closed 2026-07-26; reader references since 2026-07-28 → 11 tasks (grep `corpus explain` ∩ `created: 2026-0[89]`), 8 episodics; `bin/fw:566-572` T-2942 note — arc-017 curriculum carries 10 `fw corpus explain` routes in operator sections; audience-lens vocabulary grep dated 2026-08/09 → only T-2668/T-2669/T-3391; architecture §10 lens list read. `fw assumption` A-060 invalidated, A-061 invalidated, A-062 validated. `fw reviewer T-2669` → **Overall: PASS, Needs Human: no, Findings: none**. Mechanical: artefact present; 2 answered + 1 dissolved, 0 open; Recommendation NO-GO.
- **Closed/parked:** three Agent ACs ticked; commit 12b19a472; `fw task review T-2669` → http://192.168.10.107:3002/inception/T-2669.
- **What changed:** `docs/reports/T-2669-audience-lenses-supersession-review.md` (new); T-2669 body filled, July NO-GO premise corrected on the record; `assumptions.yaml` +3. No source, no policy.
- **Cost vs estimate:** estimator `effort=6, tier=4, blast_radius=3` (no-signal). Actual: ~20 tool calls, 1 commit, zero components.
- **Surfaced:** the first real read consumer of the corpus is the operator (through the curriculum, via prose) — arc-019 §10's Business lens has a live consumer before it exists.

### Stop — condition 1
- arc-014's Q1/Q2 rows (T-2668, T-2669, T-2670) are all executed to their Agent ACs and parked on the operator's go/no-go (`/inception/` pages above). Re-entered at level 2: the only other arc-tagged quadrant rows are T-2323 (arc-011, hv-hc — DEFER'd by recorded decision, SQ-4) and T-2137 (arc-008 `inception-review-loop`, **draft** arc — starting an arc is a Sovereign act); the remaining 20 Q1/Q2 rows carry no `arc_id` and fail the arc gate. No other arc has eligible Q1/Q2 work → **stop condition 1**. Not stopped mid-task: T-3391 closes through the verb after this record is complete.

## Sovereign questions

### SQ-5 — T-2668 was decided GO with a NO-GO rationale (priority: high — it is a recorded decision)
Commit f4a1ee07d records `Decision: GO` on T-2668 while the stored rationale reads "A GO here would authorise a second procedure runtime beside a ratified one, against a Sovereign sequencing decision." Two readings: (a) GO = "approve the recommendation; close as dissolved" — then the record needs a one-line clarification and nothing is built; (b) GO = "build Lock 6 guided-mode enforcement under arc-014 now" — then it contradicts the 2026-08-20 EWCR decision and needs an explicit reconciliation before any build task is filed. This run did not file build tasks from it. T-2670's form now spells out both verbs' meanings so the same ambiguity cannot recur there.

### SQ-1..SQ-4 — carried from T-3390, still unanswered
SQ-1 selection rule while BVP is unconfirmed (this run's Unit 0 sharpens it: the value median *is* the no-signal default); SQ-3 arc-019 exit (T-3389 review transfer, T-3147 finalisation); SQ-2 T-2433 hypervisor prerequisites; SQ-4 T-2323 revisit.

## Gate refusals

| # | Gate | Refused | Route taken |
|---|---|---|---|
| 1 | `check-active-task` (focus null) | read pipeline using `xargs … sh -c` | filed T-3391 via `fw work-on`, re-ran reads under it |
| 2 | G-067 inception Open-Questions readiness (T-2668, then T-2670) | non-allowlisted read before any IW question existed | filed IW-1..3 with Edit first, then plain reads |
| 3 | Focus-drift gate T-1730 (focus T-2670, target T-2668) | `git commit` of T-2668's post-decision episodic footprint refresh | left staged for the handover sweep — the offered routes (`--switch-focus`, `FW_SWITCH_FOCUS=1`) are Tier-2 logged bypasses the mandate excludes; every later commit names its paths explicitly |
| 4 | AC-structure check T-2420 (close of this record) | `--status work-completed`: the template's commented `### Human` block sat after the run-log sections, outside `## Acceptance Criteria` | removed the template block (no Human ACs on this record — the template's own instruction), re-ran the close; `FW_ALLOW_AC_STRUCTURE_DRIFT=1` not used |

No `--no-verify`, `--force`, `--skip-*`, or Tier-2 env var used. No direct writes to `focus.yaml` / `arc-focus.yaml` / `.next-directive.yaml` (every focus change via `fw work-on`). No `bvp_scores*` / `cost_estimate` values hand-written; the only scoring event was the cron estimator's own sweep on this record.

## Handback

**Stop condition:** #1 — every Q1/Q2 row in the active arc executed to its Agent ACs and parked on the operator; no other arc has eligible Q1/Q2 work.

### Objectives advanced vs run start
- **D2 Reliability / D1 Antifragility:** three inceptions that had been carrying superseded decisions since 2026-07-28 (the whole open Q1 set of arc-014) now carry evidence-based recommendations with disposed IW questions and validated/invalidated assumptions, handed to the operator via the class-correct URL. One is already decided (T-2668, GO — see SQ-5). Before the run: three blank template bodies with placeholder DEFER/NO-GO. Verifiable by `fw reviewer` PASS ×3 (recorded per unit), `fw assumption list` A-054..A-062, and the three artefacts in `docs/reports/`.
- **Instrument (arc-006 objective, unsolicited):** two measured findings for OBS-439 — the value median *is* the no-signal default (Unit 0); a filled body yields signal (this record scored D1=4/D2=4/D3=3/D4=2 by the cron worker at 16:15Z), so the 108 rows are template bodies, not estimator blindness.
- **Nothing built.** Zero source, policy, web or lib commits (checked in Verification).

### Arc state (arc-014 designer-corpus)
| Task | Quadrant | Status at run start | Status now |
|---|---|---|---|
| T-2668 | Q1 hv-lc 108 | captured, DEFER placeholder | **completed — operator Decision: GO** (f4a1ee07d) with NO-GO rationale → SQ-5 |
| T-2670 | Q1 hv-lc 108 | captured, DEFER placeholder | started-work, Agent ACs 3/3, awaiting go/no-go at `/inception/T-2670` |
| T-2669 | Q1 hv-lc 108 | captured, NO-GO placeholder | started-work, Agent ACs 3/3, awaiting go/no-go at `/inception/T-2669` |
| T-2667 | no quadrant (111, no cost) | captured, operator-gated | unchanged (draft-promotion ceremony) |
| T-2665 / T-2666 | no quadrant | captured | unchanged |
Other arcs: arc-019 blocked (SQ-3); arc-013 no Q1/Q2, blocked (SQ-2); arc-011 T-2323 DEFER'd (SQ-4); arc-002 no open agent work; arc-008 draft (T-2137).

### Remaining Q1/Q2, per task, why not done
- **T-2323** (arc-011, Q2) — DEFER recorded; reopening is SQ-4.
- **T-2137** (arc-008, Q2) — arc is `draft`; starting an arc is Sovereign.
- **T-1265, T-1271, T-1309, T-1611, T-1685, T-2321, T-2770, T-2899, T-2963, T-3240, T-3276, T-3331, T-3332, T-3333, T-3334, T-550, T-558, T-682, T-704, T-705, T-844** — no `arc_id`; fail the arc gate (level 2). All are inceptions at the no-signal default.

### Sovereign questions, priority order
1. **SQ-5** — T-2668 decided GO with a NO-GO rationale: approve-the-dissolution or build-Lock-6? Nothing filed off it until clarified.
2. **SQ-1** — selection rule while BVP is unconfirmed; now with the measured fact that the value median equals the no-signal default. Cheapest structural fix candidates live in arc-006 (OBS-439).
3. **SQ-3** — arc-019 exit: T-3389 review transfer, T-3147 finalisation.
4. **SQ-2** — T-2433 hypervisor prerequisites.
5. **SQ-4** — T-2323 revisit / close.

### Gates that refused, and what was done instead
See `## Gate refusals` (3 rows). Route in each case was the sanctioned one; no bypass.

### Cost-vs-estimate deltas for calibration
- All three inceptions carried `effort=6, tier=4, blast_radius=3`, every term `(no-signal)`, from 2026-07-28 template bodies. Actual cost per unit: 20–35 read-only tool calls, one commit, zero components. The heuristic cannot see the cost driver that mattered — *the evidence already existed elsewhere*.
- `effort` is measured from template line/AC counts at filing (`lines=319,acs=7` on this record), not from the task — same finding as T-3390.
- Positive control: this record, once filled, scored with signal on every constitutional driver within 15 minutes via the cron sweep — the instrument works on prose; it is blind to templates.

## Verification

# L1 — every Unit N has a selection block that precedes its execution block, and each execution block records a check
F=$(ls .tasks/*/T-3391-*.md | head -1); python3 -c "import re,sys; t=open(sys.argv[1]).read(); log=t.split('\n## Run log\n',1)[1].split('\n## Sovereign questions\n',1)[0]; units={1,2,3}; ok=all(log.find(f'### Unit {n} — selection')>=0 and log.find(f'### Unit {n} — selection')<log.find(f'### Unit {n} — execution') for n in units); ex=[log.split(f'### Unit {n} — execution',1)[1].split('\n### ',1)[0] for n in units]; ok=ok and all('**Checks recorded:**' in e for e in ex); sys.exit(0 if ok else 1)" "$F"
# L2 — no hand-written scores: no confirmed bvp_scores key on this record or the three inceptions; the only scoring event is named as the estimator's own sweep
F=$(ls .tasks/*/T-3391-*.md | head -1); python3 -c "import re,sys,glob; files=[sys.argv[1]]+[glob.glob(f'.tasks/*/{t}-*.md')[0] for t in ('T-2668','T-2669','T-2670')]; bad=[f for f in files if re.search(r'^bvp_scores:', open(f).read(), re.M)]; t=open(sys.argv[1]).read(); sys.exit(0 if not bad and 'bvp-estimator-sweep-15m' in t and 'estimator: bvp-estimator-v1-heuristic' in t else 1)" "$F"
# L3 — gate refusals: table has >=3 numbered rows and names the route taken; no bypass named as used
F=$(ls .tasks/*/T-3391-*.md | head -1); python3 -c "import re,sys; t=open(sys.argv[1]).read(); s=t.split('\n## Gate refusals\n',1)[1].split('\n## Handback\n',1)[0]; rows=re.findall(r'^\| \d+ \|', s, re.M); sys.exit(0 if len(rows)>=3 and 'No \`--no-verify\`' in s else 1)" "$F"
# L4 — Sovereign questions section names SQ-5 and SQ-1 and contains no decision marker
F=$(ls .tasks/*/T-3391-*.md | head -1); python3 -c "import re,sys; t=open(sys.argv[1]).read(); s=t.split('\n## Sovereign questions\n',1)[1].split('\n## Gate refusals\n',1)[0]; sys.exit(0 if 'SQ-5' in s and 'SQ-1' in s and not re.search(r'\*\*(Decision|Decided|Chose)[:*]', s) else 1)" "$F"
# L5 — Handback carries the six mandated headings
F=$(ls .tasks/*/T-3391-*.md | head -1); python3 -c "import sys; t=open(sys.argv[1]).read(); h=t.split('\n## Handback\n',1)[1]; need=['Objectives advanced','Arc state','Remaining Q1/Q2','Sovereign questions, priority','Gates that refused','Cost-vs-estimate']; sys.exit(0 if all(n in h for n in need) else 1)" "$F"
# L6 — the three units' deliverables exist and each carries an independent reviewer PASS verdict
python3 -c "import glob,sys; pairs=(('T-2668','T-2668-guided-mode-supersession-review.md'),('T-2669','T-2669-audience-lenses-supersession-review.md'),('T-2670','T-2670-workflow-fabric-supersession-review.md')); bodies=[open(glob.glob(f'.tasks/*/{t}-*.md')[0]).read() for t,_ in pairs]; reps=[open('docs/reports/'+r).read().strip() for _,r in pairs]; sys.exit(0 if all('**Overall:** PASS' in b and 'disposition: open' not in b for b in bodies) and all(reps) else 1)"
# L7 — the run wrote no source, policy or web code
[ -z "$(git log --format=%H 75000e5d8~1..HEAD -- lib agents bin web policy)" ]

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).
#
# ── Mutable-corpus anchor (T-3326) ────────────────────────────────────────────
# Do NOT anchor a verification line (or a unit test it runs) to MUTABLE corpus
# state — an exact live count, or a grep of live `fw audit`/`fw doctor` output
# for a specific corpus entity (a named arc, a task count, a census number).
# The corpus moves under the check, and the line rots: it goes red (or vanishes
# its pattern) for reasons unrelated to the code under test, blocking closes.
# Pin the INVARIANT (categories sum, count > 0, property holds) or run the code
# against a COMMITTED FIXTURE — never the live count or a live-audit line.
# Origin: T-2969 line grepping live audit for one arc's status; T-2871's census
# test pinning exact live counts (56→74 files) — both blocked closes (OBS-377).
#
# ── Pipefail/SIGPIPE: grepping a command's output (L-387, T-2090, T-2743, T-2738) ──
#
# THE DEFAULT — redirect to a file, then grep the file:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
#     curl -sf "$(bin/fw watchtower url)/page" -o /tmp/.out && grep -q "PAT" /tmp/.out
# Correct at any output size, and `&&` keeps the PRODUCING command's exit code in
# the verdict. Reach for this first; the alternative below is the special case.
#
# Why not `cmd | grep -q PAT` (L-387): P-011 runs each line with PIPEFAIL LIVE
# (errexit is not — see below). When grep matches it exits and closes stdin while cmd is still
# writing, cmd takes SIGPIPE, the pipeline exits 141 — verification "fails" with
# the pattern present. Captured 4× (T-1716, T-1838, T-1862, T-1863).
#
# THE EXCEPTION — capture first, grep the capture:
#     out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"
# Valid ONLY while "$out" fits the 65536-byte pipe buffer, and it is on you to
# know that it does. Above that the form inverts and becomes the very failure
# L-387 describes: echo blocks on the full pipe, grep -q exits, echo takes
# SIGPIPE, rc=141 (T-2743 — measured on a 146,366-byte Watchtower page, 3/3 runs,
# deterministic not racy; rendered routes run 50-200KB, so anything that curls a
# page is over the line). It also discards cmd's exit code, so a 404 yields an
# empty capture that grep merely fails to match rather than a failed line.
# If you do use it: single pipe only, no intermediate tail/awk/sed stage between
# capture and grep (T-2090) — the middle stage is what `grep -q` slams its stdin
# on, and grep scans the whole captured string anyway, so the `tail -3` was
# cosmetic. `echo "$out" | grep -q PAT`, nothing between.
#
# TEST RUNNERS need a guard either way (T-2738). `set -e` is suppressed inside the
# `if` condition the gate runs each line in, so in `cmd1; cmd2` only cmd2 is the
# verdict — and the pass marker you grep for survives a partial failure: a suite
# printing "3 failed, 9 passed" satisfies `grep -q "9 passed"`, and generalising
# to `grep -qE "[0-9]+ passed"` matches the same output. Keep the exit code:
#     python3 -m pytest <file> -q > /tmp/.out 2>&1 && grep -q passed /tmp/.out
# or add the guard the exit code used to supply:
#     out=$(python3 -m pytest <file> -q 2>&1); echo "$out" | grep -q passed && ! echo "$out" | grep -q failed
#     out=$(bats <file> 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# The close gate refuses the unguarded form. Bypass: FW_ALLOW_UNJUDGED_TEST_RUN=1.
#
# ── A SKIPPED BATS TEST REPORTS `ok` (T-3217) ─────────────────────────────────
#
# `! grep -q "^not ok"` does NOT mean the suite ran. Bats emits a skip as
#     ok 6 <name> # skip <reason>
# which is not a `not ok`, so the gate passes and the report says ok while the
# thing the test covers was measured NOWHERE. Origin: T-3213 guarded a test with
# `[ "$(id -u)" -eq 0 ] && skip` — the suite runs as root here and in CI, so it
# skipped on every run that mattered, for as long as it existed.
#
# Add a skip clause to any bats verification line. `# skip` is the marker bats
# writes; counting it is the whole check:
#     timeout 300 bats <file> > /tmp/.out 2>&1 && ! grep -q "^not ok" /tmp/.out
#     test "$(grep -c '# skip' /tmp/.out)" -eq 0
# Two lines, because they answer different questions — "did anything fail" and
# "did everything run". If some skips are legitimate on your host (an optional
# dependency is genuinely absent), assert the COUNT you expect rather than zero,
# and say in the task why that number is right.
#
# Corpus-wide, the same check runs from `bin/fw test lint`
# (tools/bats-silent-skip-lint.py): static mode flags guards that are fixed for
# a deployment rather than probing an optional dependency, and `--tap FILE`
# reports the skips a real run actually fired.
#
# REHEARSING A LINE BY HAND DOES NOT REHEARSE THE GATE (T-2743). Your interactive
# shell has no pipefail. A line has returned 0 by hand and 141 under P-011, from
# the same directory, the same second. To rehearse for real:
#     bash -c 'set -o pipefail; <your verification line>'
#
# NOTE THE MISSING `-e` — it is not a typo (T-3203). This file used to prescribe
# `set -eo pipefail` here, which is NOT the gate: it adds errexit the gate does
# not have, so it FAILS lines the gate PASSES. Measured, 10 lines, 3 diverged:
#     line                            gate    set -eo (old)   set -o (this)
#     false; true                     PASS    FAIL  wrong     PASS  ok
#     cd /nonexistent; echo ok        PASS    FAIL  wrong     PASS  ok
#     grep -q MISS file; true         PASS    FAIL  wrong     PASS  ok
# The divergence is one-directional and that is the trap: the old rehearsal only
# ever fails lines the gate accepts, so it produces false REDS, and an author
# who "fixes" a line to satisfy it is fixing something that was never broken —
# while the line that actually is broken (`cmd1; cmd2` where cmd1 fails) passes
# both. Re-derive rather than trust this table — it is pinned, not asserted:
#     bats tests/unit/t3203_p011_gate_semantics.bats
#
# ── `cmd1; cmd2` IS JUDGED ONLY ON cmd2 (T-3203) ──────────────────────────────
#
# The gate runs each line as the CONDITION of an `if` (update-task.sh:1215), and
# POSIX suppresses errexit for a compound command in an `if` condition — through
# the subshell. So pipefail applies and `set -e` does not, and in a sequence only
# the LAST command's status reaches the verdict. `cd /nonexistent; echo ok` passes.
# 2,644 of 10,997 verification lines in this corpus contain `;` (re-derive with
# the query in docs/reports/T-3203-p011-gate-semantics.md).
#
# SAFE SHAPES — both verified biting, each against a passing control:
#   A. one command whose own status is the verdict (prefer this):
#        out=$(cmd 2>&1); echo "$out" | grep -q PAT && ! echo "$out" | grep -q BAD
#      the leading assignments are setup; the trailing `&&` chain is the verdict.
#   B. an explicit sub-shell, whose errexit the outer `if` cannot reach into:
#        bash -c 'set -eo pipefail; cmd1; cmd2'
#      use when you genuinely need every command in the sequence to count.
#
# The rule of thumb: put the assertion LAST, and make sure it is an assertion.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

## RCA

<!-- REQUIRED for bug-class tasks (workflow_type=build with bug-tag, OR title matches
     fix/bug/rca/broken/crash/error/regression/fail/hotfix).
     Non-bug-class tasks may leave this section empty or remove it.

     For bug-class, fill in:
       **Symptom:** what was observed (the user-facing manifestation).
       **Root cause:** the specific structural/logical gap — not "the code was wrong".
       **Why structurally allowed:** what in the framework/code/tooling let this go undetected.
       **Prevention:** what catches the next instance (test/lint/gate/doc/learning) — distinct from the fix itself.

     The completion gate (T-1550, G-019) blocks --status work-completed when
     bug-class AND this section is empty/template-only. Use --skip-rca to bypass (logged).
-->

## Evolution

<!-- REQUIRED for arc-tagged build tasks (tags include arc:*). Captures how
     understanding evolved during build — what was learned that wasn't known at
     filing, what in the original plan no longer fits, what triggered pivots
     or new sub-tasks. Mandatory at slice boundaries (when applicable) and
     before --status work-completed.

     Origin: T-1717 grill Q4 — "the understanding of what we need and want
     evolves with the process of materialisation." Structural counter to §ACD:
     spec-vs-build divergence is logged as soon as it happens, not lost as
     folklore.

     Format (one entry per slice boundary or significant insight):
       ### YYYY-MM-DD — [topic]
       - **What changed:** [what we learned that we didn't know at filing]
       - **Plan impact:** [what in the plan no longer fits]
       - **Triggered:** [new sub-task / pivot / scope cut, with task ID if filed]

     The completion gate (T-1718) blocks --status work-completed when this
     section exists but is empty/template-only. Use --skip-evolution to bypass
     (logged Tier-2). Non-arc tasks may leave this empty.
-->

## Recommendation

<!-- T-2945: same shape as inception.md's block — the gate that reads it
     (audit_inception_recommendation, lib/task-audit.sh:117) is shared, so the
     shape is copied rather than reinvented.

     REQUIRED once this task reaches partial-complete: Agent ACs done, at least
     one `### Human` AC still unticked. `lib/review.sh:205-211` (T-2421) BLOCKS
     `fw task review` emission for build/refactor/test/decommission tasks in that
     state with no substantive block here — the operator would otherwise open
     /review/<id> to a blank Recommendation card and be asked to approve a form.

     Not required while every Human AC is ticked or the task has none: the gate
     only fires on the partial-complete transition. It is here from the start so
     you write it while you still have the evidence, not when the gate refuses.

     Format (the parser wants the `**Recommendation:**` line at the start of a
     line; a leading `-` or `*` bullet is also accepted):
     **Recommendation:** GO / NO-GO / DEFER
     **Rationale:** Why (cite evidence — what shipped, what was proven, what remains)
     **Evidence:**
     - Finding 1
     - Finding 2

     DEFER is for evidence gaps, not confidence gaps (CLAUDE.md §Presenting Work
     for Human Review). If the artefact is complete and you still don't want to
     commit, that is a calibration failure — recommend GO or NO-GO.
-->

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-09-19T15:59:56Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3391-autonomous-run-2026-09-19-top-down-bvp-s.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-be56ae37
- **Timestamp:** 2026-09-19T16:24:10Z
- **Catalogue:** v1.3-seed
- **Overall:** FAIL
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **swallowed-errors** (severe, deterministic) @ Verification:line 6
     - evidence: `F=$(ls .tasks/*/T-3391-*.md | head -1); python3 -c "import re,sys; t=open(sys.argv[1]).read(); s=t.split('\n## Gate refusals\n',1)[1].split('\n## Handback\n',1)[0]; rows=re.findall(r'^\| \d+ \|', s, r`

### 2026-09-19T16:24:08Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
