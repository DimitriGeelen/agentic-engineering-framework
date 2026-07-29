---
id: T-2667
name: "corpus map: knowledge-leveling (package dogfood catalog)"
description: >
  Map the knowledge-leveling process (capture → universal-vs-framework classification
  → graduation criteria → level promotion → ratification; learnings/practices pipeline)
  as a corpus map + conformance rail. Fourth of the package's four worst-regression
  processes (T-2662 gap 6). Gated on the tier0-escalation P4 test outcome.

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
created: 2026-07-28T16:20:57Z
last_update: 2026-07-29T11:43:54Z
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
      F-RECALL: 3
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=3 
      (body:fw-recall-or-memory-link); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2667: corpus map: knowledge-leveling (package dogfood catalog)

## Context

Fourth and last of the package's worst-regression dogfood rounds (T-2662 gap 6), following
T-2664 (tier0-escalation, P4 armed), T-2665 (exception-handling, validator-clean v3), and
T-2666 (task-creation, v3 GO'd at seed round). Pair-draft ritual per arc-014.

## Pair-Round State (arc-014 ritual)

**Round opened 2026-07-29.** `draft-knowledge-leveling` v2 seeded (16 nodes/14 flows/2 lanes,
four manual entry strands: capture, promote, harvest, consolidate). Dialect lessons from
T-2665/T-2666 applied at seed: no merge gateways (multi-incoming implicit XOR into
fw_3_practice), serviceTask typing throughout the agent lane, dead legs carried as aef:meta
honesty notes (audit nudge dead, harvest learnings leg dead, consolidate caller-less, no
ratification step). Rail dry-run PASS: gateway "promotion readiness?" branch tokens
{almost, building, promoted, ready} == source extraction from lib/promote.sh (anchored
regex). Lint baseline unchanged at 2. Live-verified: /api/version serves v2, bare-id
resolves latest=2. Editor:
http://192.168.10.107:3001/designer/app?load=%2Fapi%2Fversion%3Fid%3Ddraft-knowledge-leveling%26v%3D2

**Open taste questions for operator + 832:**
1. Four disconnected strands in one map — right call (one process, four entries) or should
   harvest/consolidate be separate maps? (They share the store, not the flow.)
2. fw_end_already as a refusal end (exit 1) — keep as endEvent with state, or is a refusal
   a different terminal kind in the dialect?
3. The dead legs are drawn as LIVE nodes with honesty notes (they're reachable code, just
   broken/uncalled) — consistent with T-2659 knowingly-RED precedent, or should dead legs
   get a visual marker?

## AC-4 Prep (parked registry entry — paste at promotion)

```yaml
# Promotion-readiness gateway branches (promoted | ready | almost | building)
# vs the promote.sh status ladder — the only place graduation readiness is
# computed (lib/promote.sh:202-208). Threshold advisory on the write path
# (warns <3 and proceeds) — the rail asserts vocabulary, not enforcement.
# Added at promotion of draft-knowledge-leveling (T-2667).
aef-knowledge-leveling:
  primitive: vocabulary-set
  source: lib/promote.sh
  gateway: "promotion readiness?"
  branch_vocab:
    regex: "[A-Za-z][A-Za-z-]*"
  source_vocab:
    anchor: 'if lid in promoted_ids:'
    regex: "status = f?'(?:\\{[A-Z]+\\})?([a-z]+)(?:\\{NC\\})?'"
```

## Regression-History Baseline (AC-1)

**The enforced machine** (mined 2026-07-29): capture `fw context add-learning` →
`agents/context/lib/learning.sh:do_add_learning` writes `.context/project/learnings.yaml`
(L-/PL- ids; every entry gets `application: TBD` — never updated by anything, learning.sh:100);
bugfix shortcut `fw fix-learned` (bin/fw:5216, hardcoded P-001, "G-016 shortcut"); graduation
`fw promote` (lib/promote.sh) — threshold 3 applications counted by string-match across task
files (promote.sh:103-131), readiness enum `promoted|ready|almost|building` (promote.sh:202-208),
**advisory-only** (warns below 3 and proceeds, promote.sh:262-265); practice write to
practices.yaml is atomic (T-100191 scar) and lands `status: active` immediately — **no
ratification step exists**; harvest `lib/harvest.sh` (project→framework, NEW/DUP/SKIP/NOTE
dispositions); consolidate `agents/context/consolidate.py` (scan/apply/report, Jaccard 0.35).

**Regression counts:** learning.sh 10 commits/5 fix-titled (50%); pattern.sh 6/2; promote.sh
6/3 (50%); harvest.sh 3/1; consolidate.py 2/0. Fix clusters all in capture+promote. In-code
scars: T-1369 (ID allocator dual-format grep), T-1543 (awk backslash collapse), T-100191
(atomic write, L-493 class). Register: G-005 closed (T-087 built fw promote); G-016
**mitigated only** (72% of bugfix tasks produce zero learnings; prompt is advisory; "no audit
check for bugfix-to-learning ratio" still open); G-055 accepted-risk (24 duplicate L-IDs live
in learnings.yaml today; 315 dash-form vs 234 legacy-indent entries — mixed formats).

**Live holes (candidates for post-round Level-C tasks, T-2674/T-2675 rhythm):**
1. **Audit graduation counter DEAD** — audit.sh:2720 greps `^  - id: L-` → 0 against the real
   file; the ≥20 branch never fires; audit forever reports "0 learnings". Same stale pattern
   enshrined in G-005's trigger_check.
2. **Harvest learnings sub-stage DEAD** — harvest.sh:274,283 grep `^    learning:` (4-space)
   but capture writes 2-space (549 matches at 2sp, 0 at 4sp) → "No learnings found in project"
   always. Same indentation-assumption class as T-2672 (resolve.sh, 832 field report). Sibling
   at harvest.sh:173 (`^    pattern:`).
3. **Harvest 2+/3+ project classification documented but unimplemented** — no cross-project
   counting, no universal-vs-framework field anywhere (0 `scope:`/`universal` occurrences in
   learnings.yaml).
4. **Candidates tier vestigial** — insertion anchor `^candidates:` doesn't exist (EOF fallback
   always runs); `fw learnings` renders a candidates list that is always empty.
5. **No ratification + consolidate orphaned** — practices go `active` with no review state;
   `consolidate apply` (the only merge/prune actuator) has NO caller anywhere (no hook, cron,
   or skill) — only the dead audit branch would ever invoke `promote suggest` programmatically.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Regression-history baseline captured in task body before mapping (episodic +
      concerns evidence for knowledge-leveling reiterations).
- [ ] `draft-knowledge-leveling` seeded via the arc-014 pair-draft ritual from the
      enforced machine (add-learning capture, learnings→practices graduation,
      harvest/promote/consolidate verbs); operator + 832 iterate; canonical
      namespace untouched until approval.
- [ ] On approval: promoted, corpus lint baseline unchanged, `fw corpus prove` green.
- [ ] Conformance-rail entry added to `tools/conformance-registry.yaml`; result
      recorded honestly (green, or red with divergent pin test per T-2659 precedent).

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

### 2026-07-28T16:20:57Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2667-corpus-map-knowledge-leveling-package-do.md
- **Context:** Initial task creation

### 2026-07-29T11:43:54Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)
