---
id: T-2666
name: "corpus map: task-creation (package dogfood catalog)"
description: >
  Map the task-creation process (capture → classification → BVP estimation → confirmation
  → activation; create-task.sh + estimator worker + fw work-on) as a corpus map +
  conformance rail. Third of the package's four worst-regression processes (T-2662
  gap 6). Gated on the tier0-escalation P4 test outcome.

status: captured
workflow_type: build
owner: agent
horizon: later
tags: [process-layer, corpus]
components: []
related_tasks: [T-2662]
arc_id: designer-corpus
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
created: 2026-07-28T16:20:18Z
last_update: 2026-07-30T01:39:01Z
date_finished:
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
  - ts: '2026-07-28T16:30:05Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-28T16:30:09Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal);
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-07-29T06:47:50Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=2 
      (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2666: corpus map: task-creation (package dogfood catalog)

## Context

Third dogfood round of the package's four worst-regression processes (T-2662 gap 6).
Baseline pre-mined 2026-07-29 while T-2665's pair round was in flight — see below.

## Regression-History Baseline (AC-1)

Mined 2026-07-29 (git log all branches, concerns.yaml, learnings.yaml, episodics):

- **Churn volume:** ~206 commits across the four surfaces with ~40% pure-fix ratio —
  create-task.sh 34 (17 fix-shaped), check-active-task.sh 36 (17), update-task.sh
  100 (37; the script is 102KB, largest in the machine), templates 36.
- **create-task.sh fix chain (~10 consecutive defect commits):** T-141 wrong
  template, T-143 unquoted name → YAML break, T-165 20 broken links same bug,
  T-297 --start didn't set focus, T-555 placeholder names accepted, T-1279
  ID-allocation race, T-1424 keylock silent fail, T-1687 revert of fake-prevention
  chain, T-100160 non-tty hang, T-100202 worktree duplicate IDs (2 commits).
- **ID-race class hit 3×:** T-1279/L-338 (4 parallel work-on → all minted T-1278),
  T-1345 (single pickup_process minted SEVEN tasks numbered T-1345 — flock protected
  across invocations, not within one; concerns.yaml:1401), T-100202 (stale worktree
  re-opened the hole after T-1279's fix).
- **Template/gate classes:** T-471 = G-020 origin (built on `[First criterion]` ACs,
  3 human interventions); OBS-041 duplicate `### Human` headings recurred across 5
  tasks; T-1941→T-1967 sed comment-strip swallowed 7 ticked ACs (same class re-fired
  T-2554 in check-active-task.sh).
- **Live conformance holes (rail-grade):** `owner` — predicate `is_valid_owner`
  (lib/enums.sh:103) EXISTS but create-task.sh:50 never calls it, accepts any string;
  Watchtower hard-whitelists {human, claude-code} → `--owner orchestrator` renders
  broken (concerns.yaml:1151). `status`-at-creation — no validation path at all.
  `workflow_type` — a THIRD parallel enumeration lives in the Watchtower creation
  form (concerns.yaml:1094; new type silently breaks the web form).
- **Canonical vocab source:** status-transitions.yaml (types :17-24, statuses :7-15,
  horizons :26-29, owners :31-33, transitions :35+) read by lib/enums.sh — which
  itself carries hardcoded fallback duplicates at :62-77 (second drift surface).

**Rail candidates (strongest first):** (1) `owner` at creation — provable hole, the
rail would go in knowingly RED per T-2659 precedent, which is the more interesting
dogfood outcome; (2) `workflow_type` — 3-site enumeration incl. Watchtower form;
(3) `status`-at-creation. Note the machine already HAS a transition-table rail
(aef-task-lifecycle) — this map covers the creation ceremony upstream of it.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Regression-history baseline captured in task body before mapping (episodic +
      concerns evidence for task-creation reiterations).
- [ ] `draft-task-creation` seeded via the arc-014 pair-draft ritual from the
      enforced machine (create-task.sh flags/gates incl. inception-recommendation
      gate, BVP estimator worker, `fw work-on` capture→started-work transition);
      operator + 832 iterate; canonical namespace untouched until approval.
- [ ] On approval: promoted, corpus lint baseline unchanged, `fw corpus prove` green.
- [ ] Conformance-rail entry added to `tools/conformance-registry.yaml`; result
      recorded honestly (green, or red with divergent pin test per T-2659 precedent).

## Pair-Round State

- **2026-07-29** — v2 seeded (14 nodes / 20 flows / 3 lanes incl. Human·Sovereignty
  for the Watchtower-form entry — the human ACTION earning the lane per 832's rule
  from the T-2665 round). Dialect lessons applied AT SEED: no merge gateways
  (multi-incoming implicit XOR), agent-lane steps serviceTask, advisory-ness in
  aef:meta notes. Rail dry-run PASS: 7 tokens {specification, design, build, test,
  refactor, decommission, inception} vs status-transitions.yaml workflow_types block
  (block-bounded regex, verified no leak into horizons/owners). Lint baseline 2.
  Round-trip 14/20. Live-verified served v2. Open taste questions posed to round:
  (a) two start events (agent CLI + human form) OK in dialect? (b) fork an
  "activation?" gateway for the bare-create-ends-captured path, or keep note?
  (c) owner/status creation-hole: wire predicates (Level C fix task) or pin the
  hole in the map note?

- **2026-07-29 (round #3 verdict, rail 316)** — 832: draft-task-creation v2 VALID,
  ZERO findings at seed (independent structure recount matched our manifest
  exactly: 14 nodes / 20 flows / 2 starts / 1 end / fw_gw_type 7-way). Taste
  answers, all evidence-cited: **Q1 dual-start** — YES, canonical (mapping-v1 has
  no start-cardinality rule; validator unions reachability from all startEvents;
  2 of their 24 shipped maps are already dual-start). **Q2 activation** — FORK
  THE GATEWAY, not an aef:meta note: a bare `fw task create` (no --start) is a
  real divergent code path, not annotation. Bonus: their task-lifecycle article's
  startEvent ("Task captured (filed)") is literally this map's missing second
  end — cross-article handoff (F5 class). Cost estimate: +1 gw +1 end +2 flows.
  **Q3 conformance hole** — BOTH, in sequence: pin the hole in the article (done
  in v2) AND wire the predicates as their OWN Level-C bug-class task(s) — owner-
  validation and status-predicate called out explicitly as TWO independent holes
  with separate root causes (one bug = one task). G-019 applies: concerns:1151
  stays open until the predicate is CALLED, not just registered. Pairing: their
  catalog has no task-creation article — this draft fills a genuine upstream hole;
  two seam notes recorded (both ends feed their task-lifecycle start; this map's
  G-020 node overlaps their task-gate article — cross-reference, don't merge).

- **2026-07-29 (v3, this session)** — Applied Q2 exactly as specced: forked
  `fw_gw_activation` ("activation?") after `fw_4_write`; the work-on/--start
  branch continues unchanged into `fw_5_focus`; the bare-create branch now ends
  at a new `fw_end_captured` event carrying the cross-article-handoff note
  verbatim. Landed at EXACTLY 832's cost estimate: 16 nodes / 22 flows (+2/+2).
  Q1: no change (already correct). Q3: hole stays pinned in the v3 header
  comment (unchanged content, reworded to cite the round-#3 verdict); predicates
  filed as two separate Level-C tasks per the one-bug-one-task instruction —
  **T-2674** (owner — live-reachable via `--owner`, concerns:1151) and **T-2675**
  (status — structural-only today, no `--status` CLI flag exists yet so not
  currently exploitable, but the missing guard is the same class). Re-verified
  this session: `python3 tools/corpus_lint.py .../v3.bpmn` CLEAN; whole-store
  `fw corpus lint` unchanged at 2 pre-existing findings (draft excluded, T-2600
  convention); AC-4 registry entry dry-run PASS via temp registry probe against
  v3 (reverted, not committed — same pattern as T-2665); served live at
  `192.168.10.107:3001/api/version?id=draft-task-creation`, `fw_gw_activation`/
  `fw_end_captured` confirmed present in the response body. Reported to 832 at
  DM offset 318 (`dm:0e7ee6cad65137fc:6a646ce8b1bc6560`), closing our side of
  round #3 — nothing left for another 832 round to find. **Remaining: operator
  taste/iteration in the editor + promotion GO** (arc-014 ritual: canonical
  namespace untouched until approval) — same gate T-2665 is waiting on.

## Recommendation

**Recommendation:** GO — promote `draft-task-creation` v3 to `aef-task-creation`,
following the T-2664/T-2665 promotion pattern.

**Rationale:** This draft went through exactly one pair-draft round and came back
clean — 832's independent validator found ZERO findings against the v2 seed (the
first of the four package maps to do so), meaning the only round-#3 work was
taste (Q1/Q2/Q3), not defect-fixing. All three taste calls are now resolved and
implemented: Q1 required no change, Q2's gateway fork is live in v3 (structure
matches 832's cost estimate exactly — 16 nodes/22 flows), and Q3's "pin AND wire
separately" instruction is satisfied both ways (hole stays honestly pinned in the
article; T-2674/T-2675 file the predicate fixes as independent Level-C tasks so
promotion isn't blocked on unrelated bugfix work). There is nothing left for
another 832 round to find; the only remaining step is the human confirmation the
ritual requires before touching the canonical namespace.

**Evidence:**
- 832 round-#3 verdict (DM offset 316): "draft-task-creation v2 VALID, ZERO
  findings at seed" — independent structural recount matched our manifest exactly.
- v3 structure: 16 nodes / 22 flows, landing exactly at 832's stated cost
  (+1 gw/+1 end/+2 flows over v2's 14/20).
- `python3 tools/corpus_lint.py .context/designer/projects/draft-task-creation/v3.bpmn`
  → CLEAN. Whole-store `fw corpus lint` → 2 findings, unchanged, unrelated to
  this draft (`t2584-scratch`, `aef-dispatch-loop`).
- AC-4 registry entry re-verified PASS against v3 via a temporary registry probe
  (added, run, reverted — no diff left in `tools/conformance-registry.yaml`):
  `conformance: PASS — draft-task-creation gateway 'workflow type?' covers
  exactly the enforced vocabulary {build, decommission, design, inception,
  refactor, specification, test}`.
- Served live: `curl http://192.168.10.107:3001/api/version?id=draft-task-creation`
  contains both new node ids (`fw_gw_activation`, `fw_end_captured`).
- Follow-up tasks filed and linked: T-2674 (owner-validation predicate),
  T-2675 (status-value predicate) — both `related: [T-2666, ...]`, `horizon: later`.

**What GO triggers (agent-executable, mirrors T-2664/T-2665):**
1. `git mv` the draft dir to `.context/designer/projects/aef-task-creation`,
   rewrite `v3.bpmn` → `v1.bpmn`, collapse `meta.json` to a single-version record
   (uuid preserved, note = "T-2666 promotion proof").
2. `fw corpus prove aef-task-creation` — confirm canonical-identical, uuid-preserved.
3. Paste the AC-4 registry entry (below) into `tools/conformance-registry.yaml` +
   the pin test into `tests/unit/test_corpus_conformance_registry.py`.
4. Tick AC-2/3/4, run `## Verification`, close the task.

**If NO-GO/DEFER:** name what in v3 still needs another 832 round or a different
gateway shape — nothing in this session's evidence points at one.

## AC-4 Prep (ready to paste at promotion)

Registry entry (dry-run verified PASS against draft v2 on 2026-07-29; re-verified
PASS against draft v3 same day via temp registry probe, reverted — gateway shape
unchanged by the Q2 activation-fork fix, which touched `fw_4_write`/`fw_5_focus`
downstream of `fw_gw_type`, not the gateway itself):

```yaml
# Workflow-type gateway branches (7-way fan; inception forks through the
# T-2204 recommendation gate before converging) vs the canonical enum in
# status-transitions.yaml workflow_types block (read by lib/enums.sh
# is_valid_type, enforced at create-task.sh:176). Block-bounded regex —
# capture group spans only the workflow_types items, so horizons/owners
# below it cannot leak in. Added at promotion of draft-task-creation (T-2666).
aef-task-creation:
  primitive: vocabulary-set
  source: status-transitions.yaml
  gateway: "workflow type?"
  branch_vocab:
    regex: "[A-Za-z][A-Za-z-]*"
  source_vocab:
    regex: 'workflow_types:\n((?:[ ]*- [a-z]+\n)+)'
    first_only: true
    split: "- "
```

Pin test: rc==0 and all 7 type tokens in stdout.

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.

     ── Prefix routing (T-1811, T-1878): default to [REVIEWER] if Expected is grep-able ──
     If your Expected clause is grep-able / file-exists / structural (a deterministic
     shell check), prefer [REVIEWER] — that AC should be an Agent AC with the reviewer
     command in `## Verification` instead of a Human AC here. Only keep [REVIEW] if
     verification genuinely needs human taste (tone, feel, layout rhythm).
     See CLAUDE.md §AC Classification Guidance for the conversion rule.

     [REVIEW] example (genuine human judgment):
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error

     [REVIEWER] example (static-scan-verifiable — convert to Agent AC + Verification):
       - [ ] [REVIEWER] Block message names both bypass mechanisms
         **Steps:**
         1. Run `bin/fw reviewer T-XXX`
         **Expected:** Verdict: PASS; no findings on `block-message-completeness`
         **If not:** Inspect hook block-message string and add missing mechanism
       Conversion: this AC should be moved to ### Agent and
       `bin/fw reviewer T-XXX 2>&1 | grep -q "Overall:.*PASS"` added to ## Verification.
-->

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).
#
# Pipefail/SIGPIPE hint (L-387): P-011 runs each command under `set -eo pipefail`.
# `cmd | grep -q PATTERN` exits 141 (SIGPIPE) when grep matches and closes stdin
# while the upstream is still writing — verification then "fails" even though
# the pattern was present. Safe pattern: capture first, grep the capture:
#     out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"
# Or:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
# Origin: L-387, captured 4× (T-1716, T-1838, T-1862, T-1863) before this hint.
#
# Single pipe only — no intermediate tail/awk/sed stages between capture and grep
# (T-2090): `echo "$out" | tail -3 | grep -q PAT` re-introduces the SIGPIPE risk
# the capture step closed off — the middle stage is what `grep -q` slams its
# stdin on. `echo "$out"` is small and immediate; grep scans the whole captured
# string anyway, so the tail-3 was cosmetic. Drop it: `echo "$out" | grep -q PAT`.
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

### 2026-07-28T16:20:18Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2666-corpus-map-task-creation-package-dogfood.md
- **Context:** Initial task creation

### 2026-07-29T06:47:49Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)

### 2026-07-30T00:00:00Z — dispatch-recheck [worker]
- **Action:** First resolver dispatch since round #3 closed (66d782e39).
  Re-verified nothing changed: `draft-task-creation` v3 still lints CLEAN
  (`python3 tools/corpus_lint.py .../v3.bpmn`), meta.json still `latest: 3`
  (uuid `88eb47bd-f40a-4592-bb26-649322eb530b` unchanged), no operator GO
  recorded anywhere (`.gate-bypass-log.yaml` has no decision entry for
  T-2666, `.context/handovers/LATEST.md` still shows "no operator taste
  signal" as the last action). The only intervening commit touching the
  draft (bbe9e1de4, T-2686) was an unrelated laneSet-order repair, not a
  promotion or operator decision.
- **Applied the G-072 mitigation directly** rather than repeating the
  4-5 identical redispatch cycles T-2665/T-2667 went through before
  registering the gap: this task is in the exact state G-072 describes
  (fully agent-verified, blocked only on human GO) and the gap is already
  registered — no need to re-accumulate evidence of the loop before
  breaking it. Ran `fw task update T-2666 --horizon later` (auto-synced
  `status: started-work → captured`), excluding T-2666 from the dispatch
  pool without touching the standing **Recommendation: GO** or any of the
  evidence/paste-ready AC-4 prep above, which remain intact for the
  operator's decision via `fw task review T-2666`.
- **Not done:** did not promote the draft or self-authorize any GO — that
  stays a human decision per §Autonomous Mode Boundaries.

### 2026-07-30T01:39:01Z — status-update [task-update-agent]
- **Change:** horizon: now → later
- **Change:** status: started-work → captured (auto-sync)
