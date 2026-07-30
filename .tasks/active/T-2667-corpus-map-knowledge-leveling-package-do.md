---
id: T-2667
name: "corpus map: knowledge-leveling (package dogfood catalog)"
description: >
  Map the knowledge-leveling process (capture → universal-vs-framework classification
  → graduation criteria → level promotion → ratification; learnings/practices pipeline)
  as a corpus map + conformance rail. Fourth of the package's four worst-regression
  processes (T-2662 gap 6). Gated on the tier0-escalation P4 test outcome.

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
created: 2026-07-28T16:20:57Z
last_update: '2026-07-30T16:45:08Z'
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
  - ts: '2026-07-29T16:30:09Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 4
      F-RECALL: 3
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=4 (body:cross-machine); F-RECALL=3 
      (body:fw-recall-or-memory-link); F-AUTONOMY=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-07-30T16:45:08Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 2
      D4: 4
      F-RECALL: 3
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=2
      (body:default-change); D4=4 (body:cross-machine); F-RECALL=3 
      (body:fw-recall-or-memory-link); F-AUTONOMY=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
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

**832 round-4 verdict (rail 324): v2 VALID, zero findings at seed** — second consecutive
clean seed. Verdict applied in v3 (sha8 b82668c8, live-verified):
1. **Q1 — ONE map confirmed.** "The disconnection IS the finding — no automatic path from
   captured to promoted; splitting into four maps would hide exactly what the map
   discovered." 4 starts = new corpus max (prior ceiling 2), validator unions reachability.
2. **Q2 — fw_end_already gains `terminalKind="error"`** (corpus precedent: 7 exit-1-refusal
   instances across review-emission/release-pipeline/git-commit-flow/harvest-pipeline; no
   typed errorEndEvent exists in corpus, none introduced).
3. **Q3 — grep-able `DEAD:` token adopted** on dead-leg notes (no visual marker convention;
   tooling can census dead legs — exactly 4 in aef:meta notes at v3). 832 may file an
   editor-side gallery marker as inception candidate only if operator wants it.
4. **Fixed legs flipped LIVE** per mid-round addendum (rail 322): T-2676 harvest greps,
   T-2677 audit counter (first fire ever — audit now WARNs "550 learnings"). Still-dead
   census: 4 (2+/3+ classification, candidates tier, programmatic consolidate, ratification).
5. **832 precision nit honored:** consolidate is manual-only (CLI route exists), not
   caller-less — "no PROGRAMMATIC caller" is the true claim.

**v5 LIFECYCLE REWORK (operator single-chain doctrine, 2026-07-29 late).** Operator
rejected the four-disjoint-strand shape ("a workflow should contain a single chain of
cause and effect; different start points only when they converge"). 832 conceded fully
(rail 329): "your operator's token test is the better razor; my one-map ruling conflated
shared SUBSTRATE (learnings.yaml) with shared TOKEN. Split by token, not by verb."
v5 (647133ebe): token = ONE LEARNING; 3 converging capture channels → append →
fw_wait_dormant intermediateCatchEvent (FIRST mid-chain wait in corpus, gap finding
embodied ON the wait) → count → readiness gateway (rail anchor unchanged) →
practice-active / already-promoted error terminal. Harvest + consolidate OUT (different
token: whole store) → pointer note on the success terminal, separate-map candidates.
12 nodes/13 flows. DEAD census 4 → 2 (candidates tier, ratification).

**Operator pair-rounds v6 + v7 (designer UI saves, 17:04 + 17:27).** Semantics untouched
(same 12 uids/13 flows/names/notes); layout finalized (chain top row, channels bottom-left
converging, edge port anchors added). Lane membership flipped on 10/12 nodes vs v5 —
only kl_dormant stayed Framework and kl_healing stayed Agent. Open pair questions for
next round (flagged, not patched): (a) lane-membership-vs-position semantics — is
membership operator intent (promote leg = initiative-driven) or a designer save-side
position-derivation artifact?; (b) v7 workflowMeta gained uuid d7c7cfc0-… ≠ project uuid
906e14cc-… (single-uuid-namespace contract, T-2571); (c) workflowMeta version attr stuck
at "5" across v6/v7 saves.

**v7 verify battery GREEN (2026-07-29 17:4x, this session):** XML parse OK; corpus lint
baseline 2 (v7's untyped intermediateCatchEvent correctly does NOT fire the T-2551
emitterless-typed-event lint — the watch item from the v5 commit resolved clean);
rail dry-run MATCH {promoted, ready, almost, building} vs promote.sh ladder (with the
sharpened unique anchor — see AC-4 Prep comment: the original 3-occurrence anchor
extracts zero tokens); DEAD census == 2 per the contains-once-per-note contract;
/api/version serves v7 bytes exactly (sha8 0cd8022a).

**v8 IS THE PROMOTION CANDIDATE (T-2682 repair, not a design change).** Risk-checking v7
before promotion surfaced silent data loss across the designer↔corpus seam: the designer's
save path drops the leading doc comment (confirmed twice — this project v5→v6, and
draft-trigger-handling v1→v2), and our own `parse_map` masked it by adopting the emitter's
trailing `BPMN DI (visual layout) omitted…` boilerplate as the map's semantic doc. The
field read plausible-and-wrong, never empty, so every check passed. Worse, `generate`
re-emitted the adopted trailer in *leading* position, laundering corruption into
indistinguishable-from-authored doc — that is how aef-audit-cron and aef-session-lifecycle
reached the promoted corpus doc-less (OBS-101).

v8 = v7 topology byte-for-byte + the v5 doc restored. Semantic diff v7→v8 is exactly one
key (`doc`); round-trip derive→generate→diff IDENTICAL; live-serve confirmed (sha8
5594f6aa). Reader fixed in T-2682 (leading + non-boilerplate only, 9 tests); save path is
832's leg, reported rail 332 with the schema alternative (carry doc as an `aef:` attr on
`workflowMeta`, which survives any DOM round-trip).

**Promote v8, not v7** — promoting v7 would have shipped the map with the generator's
boilerplate standing in for its rationale block.

Remaining for close: operator taste + promotion GO on **v8** (arc-014 ritual), then
AC-3/AC-4 (promote, registry entry from AC-4 Prep, prove, pin test).

**Dispatch check-in (2026-07-29 late):** v8.bpmn confirmed byte-identical to the
committed candidate (f74de5257); no new feedback-stream entries, paused dispatches,
or commits against this task since T-2683's OBS-101 repair landed. No operator GO
signal found. AC-3/AC-4 remain blocked on operator taste + promotion GO —
declining to fabricate approval.

**Dispatch check-in (2026-07-30) — new evidence changes the promotion picture.**
T-2684 (sibling task, landed since the prior check-in) shipped a `lane-geometry`
corpus lint rule and its live survey named `draft-knowledge-leveling` v8 by id:
exactly `kl_dormant`/`kl_healing` disagree between declared lane membership
(`flowNodeRef`) and rendered node position — independently confirming this
task's own open pair question (a) from the v6/v7 round ("is lane membership
operator intent, or a designer-save-side position-derivation artifact?").
Live-verified this session: `bin/fw corpus lint draft-knowledge-leveling` →
1 finding, exit 1 (reproduced below). T-2686 (also landed since) fixed the
*other* two disagreeing drafts (exception-handling, task-creation — wholesale
inversions, zero-semantic laneSet reorders) but explicitly left this map's
2-node case as "an authority call for the operator" (T-2686 body, both
occurrences) — same call this task already had open, now structurally
detected rather than just observed in the designer UI.

```
[lane-geometry] draft-knowledge-leveling@v8 :: agt_1_healing, fw_5_dormant —
lane "agent" is declared above "framework" but their node geometry crosses:
agt_1_healing (y=600, declared agent) is drawn at/below fw_5_dormant (y=140,
declared framework). 2/7 agent-nodes and 5/5 framework-nodes sit on the wrong
side of the crossing.
```

**Why this matters for AC-3 ("corpus lint baseline unchanged"):** promoting
v8 as-is would not leave the baseline unchanged — it would introduce this
finding into the live corpus (the rule currently skips `draft-*` by default,
so it's invisible until promotion flips the map out of draft tier). The
reconciliation choice (keep the drawn geometry and flip declared membership,
or keep declared membership and move the two nodes) is the same authority
call flagged in the v6/v7 notes and explicitly deferred to the operator by
T-2686 — declining to make it unilaterally. Recommend folding this into the
same operator round that decides taste + promotion GO on v8, rather than a
separate cycle: **operator should look at v8 in the designer, decide whether
kl_dormant/kl_healing's *drawn position* or their *declared lane* is the
intended one, and say so** — the fix itself (laneSet reorder for 2 nodes, or
a small node move) is small either way.

**Dispatch check-in (2026-07-30, later) — second defect now lint-confirmed, still no GO.**
Since the prior check-in, T-2687 GO'd a *different* rule than it set out to validate
(`lane-overflow`, not band-model), and T-2688 shipped it live. `bin/fw corpus lint
draft-knowledge-leveling` now reports **two** findings against v8, not one:

```
[lane-geometry] draft-knowledge-leveling@v8 :: agt_1_healing, fw_5_dormant — ...
  (T-2684 finding, unchanged — the two-node membership authority call)
[lane-overflow] draft-knowledge-leveling@v8 :: agt_7_refused, agt_1_healing — lane
  "agent" declares height=260 but its own members span 513px, exceeding it by 253px
  (T-2687 GO / T-2688 finding, new this cycle)
```

T-2687's own scope note explicitly named this: repairing `draft-knowledge-leveling` v8
is "two-node membership call plus the newly-found overflow, both awaiting operator
taste GO" — i.e. the operator authority call this task already had open didn't shrink,
it grew a sibling. No new feedback-stream entry, commit, or Watchtower decision against
T-2667 or `draft-knowledge-leveling` since the prior check-in (b0e5410dc). AC-3/AC-4
remain blocked on operator taste + promotion GO — declining to fabricate approval, and
declining to unilaterally pick a fix for either finding (both are named authority calls,
not layout ones, per T-2684/T-2687). Recommend the operator resolve all three open
questions (2-node membership, 253px overflow, promotion taste) in one pass on v8 in
the designer, since fixing them separately means re-verifying the lint baseline twice.

**Dispatch check-in (2026-07-30, this session) — rail 340 read, a THIRD defect surfaces,
loop broken via G-072.** The prior session's handover flagged an unread 832 rail
(offset 340, answering the H-height question from rail 338); read it live this
dispatch:

```
termlink channel state --hub 192.168.10.107:9100 "dm:0e7ee6cad65137fc:6a646ce8b1bc6560" | awk '/\[340\]/,0'
```

832's finding: **H is not uniform** (events 36px, gateways 48px, tasks 64px) and a
label-below allowance adds 18px to events/gateways at render time, giving *effective*
occupancy of 54px (events), 66px (gateways), 64px (tasks) — the inversion means a
36px event occupies more than a 48px gateway does not, but a 48px gateway occupies
more than a 64px task's raw height suggests. Applied to this map's own headroom table:
**`draft-knowledge-leveling`'s `framework` lane (headroom 18) overflows against ANY
node type**, since the smallest possible occupancy (54px, events) already exceeds 18.
This is distinct from the already-recorded `agent`-lane 253px overflow (T-2687/2688)
and the `kl_dormant`/`kl_healing` membership call (T-2684) — a third, independent
finding against v8, though not yet lint-enforced: the shipped `lane-overflow` rule
(T-2688) is deliberately conservative (top-y-only) pending this exact per-type table,
so `bin/fw corpus lint draft-knowledge-leveling` still reports only 2 findings, not 3.
Implementing the occupancy-aware version is out of scope for this task (T-2667 promotes
the map; it does not own `tools/corpus_lint.py`) — noting it here so the operator's
eventual v8 round accounts for it rather than promoting into a rule that tightens out
from under it. 832 also confirmed the render-defect mechanism likely behind their own
T-310 origin screenshot (capacity, not just ordering) and is filing that as a separate
task on their side; no action needed here.

**Loop-breaking action taken:** this is the 6th consecutive dispatch of T-2667 without
an operator GO signal (11:43, 18:20, 7b1b4b66f, b0e5410dc, 65a12af40, this one) — the
same terminal shape G-072 registered for sibling T-2665 (all agent-verifiable work
exhausted, blocked purely on human taste + promotion decision). Unlike T-2665's
trigger, dispatches 3-5 here each surfaced a genuinely new finding, so this instance
widens G-072 rather than repeating it verbatim (see concerns.yaml G-072 update).
Applying the same interim mitigation as T-2665: **`horizon: later`** (auto-syncs
`status: started-work → captured`), removing T-2667 from the dispatch pool without
touching the Recommendation, evidence, or AC-4 Prep block above — operator decision
via `fw task review T-2667` is unaffected. Not a completion or sovereignty action;
"stop wasted redispatch" is delegated initiative per §Autonomous Mode Boundaries.

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
    # anchor sharpened 2026-07-29: 'if lid in promoted_ids:' occurs 3x in
    # promote.sh (lines 144/155/201) — the ladder is the 3rd; an occurrence-1
    # anchor extracts ZERO tokens (verified live). This anchor is unique (1x)
    # and inclusive-forward extraction yields all 4 tokens (verified MATCH).
    anchor: "status = f'{GREEN}promoted{NC}'"
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
- [x] `draft-knowledge-leveling` seeded via the arc-014 pair-draft ritual from the
      enforced machine (add-learning capture, learnings→practices graduation,
      harvest/promote/consolidate verbs); operator + 832 iterate; canonical
      namespace untouched until approval. (v2 seed VALID zero findings — 832 rail
      324; v3 ships the verdict; operator taste pending.)
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

### 2026-07-29T12:09:55Z — dispatch check-in [build-worker]
- **Checked:** AC-4 prep vocabulary anchor (`if lid in promoted_ids:` →
  `status = f?'...'`) re-verified against current `lib/promote.sh` — single
  matching block at lines 202-208, tokens {promoted, ready, almost, building}
  unchanged. No drift since baseline capture.
- **Checked:** no 832-side pairing article for knowledge-leveling exists yet
  (grep of this repo found none; cross-repo read into `/opt/832-Workflow-designer`
  is blocked by the project-boundary hook — correctly so, per T-559/feedback
  no-cross-repo-edits). No mirror-sync signal of a peer draft either.
- **Status:** draft-knowledge-leveling v2 (seeded prior session) is unchanged.
  AC-2/3/4 remain genuinely blocked on the operator + 832 pair-draft ritual
  (same stage as sibling T-2665/T-2666: "seed round done, awaiting operator
  taste + promotion"). No agent-only action can progress this without that
  human/external step — declining to fabricate promotion or approval.

### 2026-07-29T18:20:00Z — dispatch check-in [build-worker]
- **Checked:** git log for this task file since v7 GREEN commit (33a9cf844)
  — no further commits. `.context/working/feedback-stream.yaml` tail — no
  verdict/scan entries for T-2667. `fw pause list` — empty, no paused
  dispatch awaiting operator answer on this task. `fw resume quick` — session
  focus has since moved to T-2679 (unrelated inception, now GO'd).
- **Status:** v7 (sha8 0cd8022a) remains the current draft; GREEN verify
  battery from the prior dispatch stands unchanged. No operator taste signal
  or promotion GO has arrived since. AC-3 (promote, lint, `fw corpus prove`)
  and AC-4 (registry entry from the parked AC-4 Prep block, honest
  green/red recording) stay blocked on that human input — declining to
  fabricate approval. No further agent-only action available this round.

### 2026-07-30T01:10:28Z — status-update [task-update-agent]
- **Change:** horizon: now → later
- **Change:** status: started-work → captured (auto-sync)
