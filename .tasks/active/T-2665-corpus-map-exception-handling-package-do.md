---
id: T-2665
name: "corpus map: exception-handling (package dogfood catalog)"
description: >
  Map the exception-handling process (detection → classification → escalation routing
  per Error Escalation Ladder → resolution → learning capture; lib healing + status:issues
  flow) as a corpus map + conformance rail. Second of the package's four worst-regression
  processes (T-2662 gap 6). Gated on the tier0-escalation P4 test outcome — promote
  horizon only after that lands.

status: started-work
workflow_type: build
owner: agent
horizon: now
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
created: 2026-07-28T16:19:32Z
last_update: '2026-07-29T16:30:09Z'
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
  - ts: '2026-07-29T16:30:09Z'
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

# T-2665: corpus map: exception-handling (package dogfood catalog)

## Context

Second dogfood round of the process-layer package's four worst-regression processes
(T-2662 gap 6). Maps the exception-handling machine: status:issues trigger →
auto-diagnose (update-task.sh Trigger 1) → keyword classification → pattern lookup →
Error Escalation Ladder suggestions → fix → resolve (FP + L capture). Rail candidate:
vocabulary-set on the "failure type?" gateway vs the enforced classification enum in
`agents/healing/lib/diagnose.sh` (CLASSIFY_ORDER 5 types + the `unknown` fallback = 6
outcomes; extraction regex `(?:FAILURE_KEYWORDS_|best_type=")([a-z]+)` verified to
yield exactly those 6 tokens).

## Regression-History Baseline (AC-1)

Mined 2026-07-29 (episodics, concerns.yaml, learnings.yaml, git log, prior audits):

- **Code churn:** 14 commits on `agents/healing/` — 1 implementation (T-007) + 13
  touches, including a 4-commit consecutive pure-fix cluster (T-796, T-868, T-871,
  T-1076) plus T-872 re-applying T-871's fix to the vendored copy (fix regressed
  across the copy boundary → duplicate learnings L-213/L-214).
- **Multi-defect incident:** T-028 found THREE simultaneous healing defects in one
  pass — classifier ordering (generic `code` matched before specific types → L-003),
  pattern lookup dumping all patterns, wrong section boundaries.
- **Loop legs empirically broken:** G-016 (mitigated) — 72% of bugfix tasks (31/43)
  produced zero learnings; the "log resolution" leg simply didn't fire. G-019 (still
  `watching`) — Level D self-escalation never fires on its own; two bolt-ons (T-1550
  RCA gate, T-1555 cron scanner) exist, no map. T-1767 — the escalation drift scanner
  itself shipped undeployed (detector for escalation failures silently failed).
- **Structural verdicts on record:** T-629 governance self-audit ranks self-healing
  #3 among failures — "zero proactive detection, zero auto-recovery, zero
  self-triggering... a knowledge base with a CLI, not a self-healing system"
  (docs/reports/fw-agent-t629-03-healing.md:39). T-580: retry-based recovery
  suggested for ALL failure types, no permanent-vs-transient distinction.
- **Status-flow blindness:** 61 episodic files mention `healing`, only 2 mention
  `status: issues` — the code churns constantly while the flow is never narrated.
  G-041: the status enum is re-enumerated at duplicate sites with no rail.
- **Pre-existing corpus hooks:** T-2551/T-2559 BPMN fixtures already carry
  `binding=status:issues` error-event annotations that nothing consumes yet.

Six concrete instances: T-028 (3 defects), T-871→T-872 (vendored regression),
T-868 (suggest.sh crash under set -e), T-580 (blanket retry advice), T-629/G-019
(Level D never self-fires), T-1767 (scanner undeployed). Baseline verdict: highest
defect density per line of any agent this size, and the process it implements is
the framework's declared "antifragile immune system" (T-396) — exactly the P4 claim's
target class.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Regression-history baseline captured in task body before mapping (episodic +
      concerns evidence for exception-handling reiterations).
- [ ] `draft-exception-handling` seeded via the arc-014 pair-draft ritual from the
      enforced machine (status:issues flow, healing agent classify→lookup→suggest→
      resolve loop, Error Escalation Ladder A-D); operator + 832 iterate; canonical
      namespace untouched until approval.
- [ ] On approval: promoted, corpus lint baseline unchanged, `fw corpus prove` green.
- [ ] Conformance-rail entry added to `tools/conformance-registry.yaml`; result
      recorded honestly (green, or red with divergent pin test per T-2659 precedent).

## Pair-Round State

- **2026-07-29** — v2 seeded (13 nodes / 17 flows / 2 lanes: Agent·Initiative +
  Framework·Authority; deliberately NO human lane — max-3-hypotheses escalation is
  prose, not machine). Rail dry-run PASS pre-seed: 6 tokens {code, dependency,
  design, environment, external, unknown}. Lint baseline untouched (2). Live-verified
  served v2. Round opened with 832 at rail offset 305 with three honesty calls posed:
  advisory-vs-enforced node typing, no-human-lane, immediate 6-branch convergence.
- **2026-07-29 (validator round, rails 306/309/310/311)** — 832 validator on v2:
  1 error (E1 XOR-merge gateway — no exclusive-merge vocabulary in mapping-v1;
  fix = multi-incoming implicit merge) + 4 warns (userTask in initiative lane —
  O-1 lane-wins, type is presentational). v3 shipped both fixes (12 nodes /
  16 flows); **832 verdict: v3 VALIDATOR CLEAN, zero findings** (rail 311, sha
  7d54fcba95ee41b7…). Their honesty-call answers recorded: (1) advisory-ness in
  aef:meta notes, not task typing; (2) human lane earns its place only when a
  human ACTION exists in-process (their healing-loop article HAS one — rung
  choice; our agent-side slice doesn't — both honest, seam documented);
  (3) labeled fan incl. fallback-as-branch endorsed.
- **Cross-validation yield (both directions again):** their code-truth trace of
  OUR machine ✓ everywhere; they found 2 honesty bugs in THEIR OWN article
  (classify wrongly tagged stochastic — it's pure keyword-regex, deterministic;
  apply→resolve drawn unconditional — reality leaks, now marked
  x-advisory-reachability citing our G-016 72%) → their healing-loop v2. Side
  yield: their T-295 field report → our T-2672 resolve.sh fix (both paths,
  4 bats, vendored sync). Healing-loop pairing leg CLOSED both sides (their
  T-297); error-escalation-ladder leg queued their T-298.
- **Remaining:** operator taste/iteration in the editor + promotion GO. On GO:
  promote to `aef-exception-handling`, paste AC-4 registry entry, prove, pin test.
- **2026-07-29 (later)** — v3 folds 832's validator round (rail 306): E1 XOR-merge
  gateway dropped (6 branch edges run directly into lookup — multi-incoming reads as
  an implicit XOR merge under mapping-v1, no separate merge node needed); W1-4
  agent-lane `userTask`→`serviceTask` (O-1: lane wins, node type reflects the real
  performer, advisory-ness stays in `aef:meta` notes rather than node type). Now
  12 nodes / 16 flows. Re-verified this session (dry-run temp-registry probe against
  `draft-exception-handling`, reverted): rail dry-run still PASS on the same 6-token
  vocabulary; whole-store lint baseline still 2 findings, draft correctly excluded
  (T-2600 drafts-excluded convention). 832's leg of the pair-draft ritual reads
  complete for this round. **Outstanding before promotion:** operator UI review of
  v3 in `/designer` + explicit GO — AC-2/3/4 stay unticked until that lands (arc-014
  ritual: "canonical namespace untouched until approval"). AC-4 registry entry +
  pin test below are paste-ready the moment GO is given.

## AC-4 Prep (ready to paste at promotion)

Registry entry for `tools/conformance-registry.yaml` (dry-run verified PASS against
draft v2 on 2026-07-29; re-verified PASS against draft v3 same day, gateway shape
unchanged by the E1/W1-4 fixes):

```yaml
# Failure-type gateway branches (5 CLASSIFY_ORDER types + unknown fallback) vs
# the enforced classification enum in the healing diagnose agent. The regex
# captures BOTH the FAILURE_KEYWORDS_<type> declarations AND best_type="unknown"
# — the fallback is a real machine outcome, encoded as a labeled branch rather
# than hidden. Added at promotion of draft-exception-handling (T-2665).
aef-exception-handling:
  primitive: vocabulary-set
  source: agents/healing/lib/diagnose.sh
  gateway: "failure type?"
  branch_vocab:
    regex: "[A-Za-z][A-Za-z-]*"
  source_vocab:
    regex: '(?:FAILURE_KEYWORDS_|best_type=")([a-z]+)'
```

Pin test for `tests/unit/test_corpus_conformance_registry.py`: rc==0 and all of
{dependency, external, environment, design, code, unknown} in stdout.

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

## Recommendation

**Recommendation:** GO — promote `draft-exception-handling` v3 to `aef-exception-handling`,
following the T-2664 (`aef-tier0-escalation`) promotion pattern exactly.

**Rationale:** The tier0-escalation gate this task was blocked on has landed (P4
ARMED, GREEN). The draft has been through one full pair-draft round: v2 seeded
against the enforced machine (5 `CLASSIFY_ORDER` types + `unknown` fallback), 832
raised two findings (E1 redundant XOR-merge gateway, W1-4 agent-lane node typing),
both were fixed in v3, and this session independently re-verified v3 against the
enforced vocabulary via a temporary registry probe (reverted, not committed) —
still PASS on the same 6 tokens, whole-store lint baseline unchanged at 2 findings
with the draft correctly excluded. There is nothing left for another 832 round to
find; the only remaining step is the human confirmation the ritual requires before
touching the canonical namespace.

**Evidence:**
- `agents/healing/lib/diagnose.sh` CLASSIFY_ORDER + `unknown` fallback → exactly
  `{code, dependency, design, environment, external, unknown}`; v3 gateway
  `"failure type?"` asserts the same 6, confirmed via dry-run `corpus_conformance.py
  --map draft-exception-handling` this session.
- `python3 tools/corpus_lint.py` (whole store): `scanned 7 map(s)`, 2 pre-existing
  findings (`t2584-scratch` legacy-ref, `aef-dispatch-loop` emitterless-typed-event)
  — unrelated to this draft, unchanged.
- `.context/designer/projects/draft-exception-handling/meta.json`: 3 versions
  logged (v1 seed, v2 pair-draft, v3 832-round fold), uuid stable across all three.
- AC-4 registry entry + pin test are pre-written above (paste-ready).

**What GO triggers (agent-executable, mirrors `c5998fc67`):**
1. `git mv` the draft dir to `.context/designer/projects/aef-exception-handling`,
   rewrite `v3.bpmn` → `v1.bpmn`, collapse `meta.json` to a single-version record
   (uuid preserved, note = "T-2665 promotion proof").
2. `fw corpus prove aef-exception-handling` — confirm canonical-identical,
   uuid-preserved.
3. Paste the AC-4 registry entry into `tools/conformance-registry.yaml` + the pin
   test into `tests/unit/test_corpus_conformance_registry.py`.
4. Tick AC-2/3/4, run `## Verification`, close the task.

**If NO-GO/DEFER:** name what in v3 still needs another 832 round or a different
gateway shape — nothing in this session's evidence points at one, so a NO-GO here
would need new information, not a restatement of the original pair-draft-in-progress
caution.

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

### 2026-07-28T16:19:32Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2665-corpus-map-exception-handling-package-do.md
- **Context:** Initial task creation

### 2026-07-29T05:29:17Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)

### 2026-07-29T20:07:00Z — dispatch-recheck [worker]
- **Action:** Re-verified draft state, no operator GO issued since last session.
- **Output:** `corpus_lint.py` still reports 2 pre-existing findings unrelated to
  this draft; `draft-exception-handling` meta.json still at v3 (uuid
  `001362d7-966d-4d14-9dfd-84d938e3791a`, unchanged). No promotion executed —
  `fw task review T-2665` shows 0/0 Human ACs (no structural gate), but the
  arc-014 ritual text in this task's own Recommendation still says "canonical
  namespace untouched until approval," and no such approval is recorded in git
  log, `.gate-bypass-log.yaml`, or the latest handover. Deferring the promotion
  to an explicit human GO rather than treating an unblocking recommendation as
  self-authorizing.

### 2026-07-29T20:38:31Z — dispatch-recheck [worker]
- **Action:** Re-verified draft state again this dispatch; no operator GO
  recorded since the prior recheck.
- **Output:** `corpus_lint.py` unchanged (2 pre-existing findings, unrelated to
  this draft); `draft-exception-handling` meta.json still `v3`, uuid unchanged
  (`001362d7-966d-4d14-9dfd-84d938e3791a`); no new entries for T-2665 in
  `.gate-bypass-log.yaml` or `.context/handovers/LATEST.md` beyond the routine
  status line. No promotion executed. Also fixed a stale `focus.yaml` pointing
  at T-2683 (a different task) that was blocking read-only Bash via G-020 —
  re-focused to T-2665 via `fw context focus` before re-running verification.

### 2026-07-30T00:00:00Z — dispatch-recheck [worker]
- **Action:** Third recheck of draft state; still no operator GO recorded for
  T-2665 anywhere (git log, `.gate-bypass-log.yaml`, `.context/handovers/LATEST.md`
  UNREAD-INBOUND section — which instead names T-2686/T-2687/T-2688 as the
  active operator queue, not T-2665).
- **Output:** whole-store `corpus_lint.py` now reports 3 findings (was 2) —
  the new one is `[lane-geometry] aef-session-lifecycle` from the concurrent
  T-2684/832-T-310 lane-authority work; unrelated to this draft, which is still
  excluded from lint scan (draft-prefixed, T-2600 convention). Re-ran the
  temp-registry dry-run against the paste-ready AC-4 entry (registry restored
  after, `git diff` clean): `conformance: PASS — draft-exception-handling
  gateway 'failure type?' covers exactly the enforced vocabulary {code,
  dependency, design, environment, external, unknown}`. `draft-exception-handling`
  meta.json still `v3`, uuid unchanged. No promotion executed — nothing in this
  recheck changes the standing Recommendation (GO, blocked on human review per
  the arc-014 ritual); not self-authorizing on a broad/absent directive per
  CLAUDE.md §Autonomous Mode Boundaries.

### 2026-07-30T04:00:00Z — dispatch-recheck [worker]
- **Action:** Fourth consecutive dispatch of this task, fourth identical finding:
  no operator GO recorded anywhere (git log, `.gate-bypass-log.yaml`,
  `.context/handovers/LATEST.md`); `draft-exception-handling` meta.json still
  `v3`, uuid unchanged; task file itself has no pending diff. Skipped re-running
  the full lint/dry-run cycle since the prior three rechecks already confirmed
  it stable and nothing in the repo suggests it changed.
- **Flag (new this dispatch):** this is the 4th resolver dispatch in a row that
  produces zero new evidence — the task is fully blocked on a human GO
  (§Autonomous Mode Boundaries forbids self-authorizing it) and has nothing
  further an agent can verify or advance. Recommend the resolver/cron stop
  re-dispatching T-2665 until either (a) the operator records a GO/NO-GO via
  `fw task review T-2665`, or (b) the task is set to a horizon/status that
  excludes it from the dispatch pool. Continuing to redispatch an
  already-fully-verified, human-blocked task burns dispatch cycles for no
  gain — this is a candidate for a `concerns.yaml` entry if the pattern
  repeats on other pair-draft tasks awaiting promotion GO.
