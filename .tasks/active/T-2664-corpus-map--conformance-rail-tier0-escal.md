---
id: T-2664
name: "corpus map + conformance rail: tier0-escalation (P4 falsifiability test)"
description: >
  Map the tier-0 escalation process (trigger → halt → human notification → disposition
  → resume/abort + audit) as a corpus map via the arc-014 pair-draft ritual, and rail
  it in tools/conformance-registry.yaml against the enforced machine (check-tier0.sh
  / fw tier0 approve). This is the cheapest honest test of the process-layer package's
  P4 claim (explicit workflows reduce regression on worst-regression-history processes)
  inside the delivered mirror+rails architecture — the package's core experiment,
  never run (T-2662 gap 6).

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [process-layer, corpus]
components: []
related_tasks: [T-2662, T-2652]
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
created: 2026-07-28T16:18:54Z
last_update: 2026-07-28T17:28:25Z
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
  - ts: '2026-07-28T16:30:08Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=1 
      (body/components:context-fabric-incidental); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2664: corpus map + conformance rail: tier0-escalation (P4 falsifiability test)

## Context

Cheapest honest test of the process-layer package's P4 claim (explicit workflows
reduce regression on worst-regression-history processes, T-2662 gap 6) — pick the
process with the richest documented regression/reiteration trail and see whether
mapping it produces any real finding (à la T-2659's knowingly-divergent
dispatch-loop rail) rather than a decorative green tick.

## Regression-History Baseline (P4 falsifiability anchor)

Captured from `.tasks/completed/` + `.context/project/concerns.yaml` BEFORE any
mapping, so a later claim of "explicit workflow reduced regression" is falsifiable
against a real prior count, not vibes. Two distinct clusters on the tier-0
escalation process:

**Cluster A — detection-hook hardening cycles (5 regressions across ~2.3 months,
same ~30-line `check-tier0.sh`):**
1. **T-092** (2026-02-16) — original build: keyword pre-filter + Python pattern
   match against a destructive-command list.
2. **T-094** (2026-02-17, +1 day) — heredoc false-positive: heredoc body content
   falsely tripped destructive patterns; added heredoc-stripping.
3. **T-1427** (2026-04-24) — comment-strip false-positive: a bash `#` comment
   containing the literal phrase "fw inception decide" falsely blocked a stat+grep
   command; heredocs/quotes were already stripped, comments were not.
4. **T-1428** (2026-04-24, same day) — bats test suite leaked approval files into
   the *real* `.context/approvals/` dir, contaminating live state from test runs.
5. **T-1500** (2026-04-26) — hash-drift: `fw tier0 approve`'s stored hash didn't
   match a regenerated command (reflowed whitespace/args on retry) → valid
   approvals silently failed to match.
6. **T-1506 → T-1508** (2026-04-26, same day, RCA→fix pair) — approval
   **self-defeat under duplicate hook registration**: `.claude/settings.json` +
   `/root/.claude/settings.json` both registered `check-tier0.sh`, so the first
   firing consumed the one-time approval and the second (duplicate) firing
   re-blocked the same command. Fixed via idempotency sentinel (T-1508).

Three of these five (T-1427/1428/1500→1506/1508) landed inside a single 3-day
window (2026-04-24→26), i.e. hardening the same enforcement point kept surfacing
new failure modes faster than they could be absorbed as "done."

**Cluster B — disposition/notification surface churn (11 tasks in 18 days,
2026-03-26 → 2026-04-13, after the approval-queue shipped):** T-612/T-620 (agent
approval pickup + human AC buttons), T-611 (approval queue), T-631 (clickable
review URL + QR), T-635/T-636 (deterministic routing / unified approval
experience — i.e. re-doing "how a human disposes" twice in 2 days), T-638/T-639
(watchtower link on block message / unified approvals page merging tier-0 +
human-AC), T-641 (rejection feedback surfaced on retry), T-691/T-709/T-716 (agent
notification wiring, then re-wired into ntfy), T-608 (frictionless confirmation),
T-993 (batch-operation governance guard, 2026-04-13). Reads as the same
"human notification → disposition" leg re-touched ~11 times as the UX was
progressively hardened, rather than specified once.

**Falsifiability anchor:** 16 tier-0-touching tasks total, 6 of them genuine
correctness regressions in the enforcement point itself (Cluster A). If the P4
claim holds, a future audit period of comparable length covering this process
(post-map, post-rail) should show materially fewer Cluster-A-class regressions
per unit time on `check-tier0.sh` / the disposition gateway than the 2026-02→04
baseline above. If a comparable regression rate recurs after this task ships,
P4 is disproven for this process — that is the falsifiable prediction, not a
rhetorical hedge.

## Pair-Round State (2026-07-28)

- Round OPENED with 832 + operator at rail 287; draft raw bytes served at
  `/api/version?id=draft-tier0-escalation` (shared at rail 290).
- **832-side pairing article exists:** their corpus already holds
  `tier0-escalation.workflow.yaml` (their T-025, with friction note) — designated
  the 832-side pairing article at rail 285/291. 832 may pre-validate our draft via
  `validate-workflow.py` + mapping-v1 gateway-label checks (their 282 offer) and
  post findings in-thread; fold any findings into the draft before promotion.

## AEF-Side Pre-Validation (2026-07-28, mirror of 832's committed pass)

- **Round-trip clean:** `fw corpus derive` → `generate` → `diff` on
  `draft-tier0-escalation/v1.bpmn` = IDENTICAL (canonical semantic form). The
  draft is contract-v0 clean before promotion.
- **Compile observations (fw bpmn compile, WARN-level, for the pair-round):**
  1. `hum_2_reject` is a `serviceTask` in the sovereignty lane — lane wins (O-1)
     so owner derives human, but the node type reads agent-flavored. Polish
     candidate: retype to `userTask` (rejection IS recorded by the human via
     /approvals) unless the operator prefers the serviceTask reading (the
     framework records the rejection mechanically after the human clicks).
  2. Framework lane carries `authority='authority'` — owner derivation knows
     only sovereignty→human / initiative→agent (T-2567), so framework-lane
     nodes fall back to name/type derivation. Expected for a mirror map (it
     will never be bpmn-promoted into tasks); noted so nobody reads the WARN
     as a defect later.
  3. Three gateways (trigger-match / pre-auth / disposition) surface the
     T-2557 "decision semantics not representable in task skeletons" WARN —
     same expected class.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Regression-history baseline captured in task body BEFORE mapping: list the
      tier-0 escalation regressions/reiterations from episodic memory + concerns
      register, so the P4 claim ("explicit workflow reduces regression here") is
      falsifiable later.
- [x] `draft-tier0-escalation` seeded in the designer store via the arc-014
      pair-draft ritual (agent skeleton from the enforced machine: check-tier0.sh
      PreToolUse hook, `fw tier0 approve/status`, approval file semantics; operator
      + 832 iterate in the UI; canonical namespace untouched until approval).
- [ ] On operator approval: promoted to `aef-tier0-escalation`, corpus lint
      baseline unchanged, `fw corpus prove` green.
- [ ] Conformance-rail entry added to `tools/conformance-registry.yaml` (primitive
      chosen to fit the machine — likely vocabulary-set on the disposition
      gateway); result recorded honestly (green, or red with a divergent pin test
      per the T-2659 precedent).

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

### 2026-07-28T16:18:54Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2664-corpus-map--conformance-rail-tier0-escal.md
- **Context:** Initial task creation

### 2026-07-28T16:39:05Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)
