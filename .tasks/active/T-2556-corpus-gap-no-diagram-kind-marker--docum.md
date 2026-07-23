---
id: T-2556
name: "corpus gap: no diagram-kind marker — documentation diagrams compile as promotable
  work-plans"
description: >
  arc-014 D1 finding: fw bpmn compile emitted 7 promotable task skeletons from a process-DOCUMENTATION
  diagram (aef-task-lifecycle v1). No vocabulary exists to mark a diagram's kind (documentation
  vs work-plan), so promote would offer filing process steps as real tasks. Propose
  additive aef:workflowMeta kind= attribute to 832 (they own vocabulary; rail loop).

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [arc:designer-corpus]
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
created: 2026-07-19T20:07:24Z
last_update: 2026-07-23T08:59:22Z
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
bvp_scores_proposed:
  - ts: '2026-07-19T20:09:39Z'
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
  - ts: '2026-07-21T19:15:08Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=2 (body:default-change); D4=2 
      (body:env-class-handled); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-07-22T22:00:08Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=2 (body:default-change); D4=2 
      (body:env-class-handled); F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-07-19T20:15:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2556: corpus gap: no diagram-kind marker — documentation diagrams compile as promotable work-plans

## Context

Corpus diagrams D1-D5 are documentation (framework processes drawn for humans), but the
serialized file carries no marker distinguishing them from actionable work-plans — so
`fw bpmn promote` mints real tasks from illustrative nodes (T-2548/T-2549 live defect,
L-504 DEFER-injection origin). Fix is an additive `aef:workflowMeta kind="documentation|
work-plan"` attribute; 832 owns the vocabulary (arc-014 continuity spine ratification
loop), AEF consumes it at compile (advisory notice) and promote (refusal + override).
Absent marker = byte-identical today-behavior (frozen-v1 additive-only discipline).
`workflowMeta` is currently write-only from 832's editor — nothing AEF-side reads it yet,
so `kind=` is the first consumed attribute.

### Progress
- 2026-07-21: proposal posted to 832 on the DM rail — **offset 125** (vocabulary, AEF
  consumption legs 1-3, editor-side optional asks, disposition menu: ratify / amend /
  reject). Awaiting 832 disposition; build legs (AC2, AC3) gated on ratification.
  Rail monitor armed (offset ≥123 watcher).
- 2026-07-21 **832 disposition recorded — offset 127** (ts 1784661590608): proposal
  received and routed to their operator via their **T-213** (inception, owner:human —
  vocabulary is 832-owned, so their agent cannot ratify unilaterally). Their
  engineering read (non-binding): **recommend ratify-as-is** — shape is clean,
  additive, frozen-v1 safe (absent/unknown → byte-identical both sides), closes the
  live L-504 / T-2548-9 defect; default-UNSET-on-new-diagrams endorsed. One amendment
  flagged to their operator: **closed enum {documentation, work-plan}** over an open
  string (a third value stays additive later) — compatible with our consumption
  sketch, which already treats unknown-as-absent. If ratified, execution runs like
  the seam: 832 delivers a byte-exact kind=documentation fixture (validate-clean →
  byte-pin → rail-inline) + surfaces kind in their meta-edit UI + re-marks the 5
  corpus diagrams via normal saves; WE wire compile-notice + promote-refusal legs
  (AC2, AC3) only after their delivery. They post the ruling on this rail when their
  operator decides. AC1 complete; AC2/AC3 remain gated on that ruling + fixture.
- 2026-07-21 **AC3 absent-marker half PINNED (harness-first, T-2579/T-2590 pattern —
  not the feature build):** `tests/web/test_bpmn_frozen_v1_pin.py` (3 tests, green;
  tests/web 113 green) pins today's behavior on a NO-kind-marker diagram using the
  byte-pinned pair-draft-3 fixture (which carries workflowMeta WITHOUT kind= — the
  exact absent case): (1) premise guard — fixture has workflowMeta, no kind=;
  (2) staged manifest sha256 golden `bbb2e46e6dcb…` byte-exact + no `kind:` key;
  (3) reconcile → all 4 proposals plain NEW (no refusal/flag). Valid regardless of
  ratification outcome; the post-ratification legs MUST keep all three green. The
  kind=documentation half of AC3 (notice/refusal/override paths) still gated on
  ruling + 832's fixture delivery. Fabric card registered (created_by T-2556).
- Build-leg design (sketched pre-ratification, NOT built — T-2541 discipline): kind
  flows through the manifest interface, promote never re-parses BPMN. (1) compile:
  `parse_bpmn` reads `aef:workflowMeta` kind attr (local-name match like every pass);
  kind=documentation appends ONE advisory warning + `--write` stamps `kind:` into
  `<stage>/<stem>/manifest.yaml`. (2) promote: `load_manifests` surfaces kind;
  kind=documentation → refuse with actionable stderr unless `--promote-documentation`
  override (logged to `.bpmn-promote-audit.jsonl` like every write). (3) tests: absent
  marker → manifest byte-identical vs today (frozen-v1 pin); kind=documentation →
  compile-notice + promote-refusal + override-path. Files: tools/bpmn_to_tasks.py
  (Pass-0 meta read), tools/bpmn_promote.py (reconcile gate), tests/web sibling of
  test_pair_draft3_intake.py patterns.
- 2026-07-21 **rail re-checked, no new ruling:** read dm:0e7ee6cad65137fc:6a646ce8b1bc6560
  cursor 120→132 (latest). Offsets 129-132 are 832's unrelated off-page-seam S1/S2 build
  chatter (T-218); nothing past offset 128 touches T-213/kind=. AC2/AC3's
  kind=documentation half remain genuinely blocked on 832's operator ruling — still an
  evidence gap, not a build gap. AC3's absent-marker half re-verified green
  (`tests/web/test_bpmn_frozen_v1_pin.py` 3/3). No action taken; nothing to build until
  832 posts the ruling.
- 2026-07-21/22 **rail re-checked (offsets 129→138, current latest, count=139), still no
  ruling.** Offsets 129-138 are entirely 832's T-218 off-page-seam build (S2 host-tag-
  dialect question, S3a/S3b ghost-derivation + ghost-rescan, S4 verify-live redeploy) —
  unrelated to T-2556. 832 explicitly reconfirms the parked state twice in this window:
  offset 132 ("Reminder of the two parked operator items … kind= ruling (your T-213) and
  the 0.3.1 tag") and offset 136 ("Still tracking the two operator items (T-213 kind=,
  0.3.1 tag)"). No disposition beyond offset 127 exists. AC2/AC3's kind=documentation
  half remains genuinely blocked — evidence gap, not a build gap. AC3's absent-marker
  half re-verified green (`tests/web/test_bpmn_frozen_v1_pin.py` 3/3). No build action
  taken (T-2541 discipline: don't build ahead of ratification).
- 2026-07-22 **rail re-checked (offsets 139→141, current latest, count=142), still no
  ruling.** All three new offsets are 832's T-218/T-228 off-page-seam + claim-mint work
  (S4 e2e cross-verify report at 139, S1 new-map mint-gap fix T-229 at 140, S4a
  server-side claim-on-save landed at 141) — unrelated to T-2556. 832 reconfirms the
  parked state in both trailing messages: offset 140 ("Still tracking T-213 kind= + 0.3.1
  tag (operator-owned)") and offset 141 (identical line). No disposition beyond offset 127
  exists. AC2/AC3's kind=documentation half remains genuinely blocked — evidence gap, not
  a build gap. AC3's absent-marker half re-verified green
  (`tests/web/test_bpmn_frozen_v1_pin.py` 3/3). No build action taken (T-2541 discipline:
  don't build ahead of ratification). Read via `termlink channel subscribe
  dm:0e7ee6cad65137fc:6a646ce8b1bc6560 --cursor 139` (the `channel` verb, not `event
  poll` — the DM rail lives on `channel.*`'s T-1155 agent-comms-bus substrate, not a
  per-session event bus).
- 2026-07-22 **rail re-checked (offsets 142→151, current latest), still no ruling.**
  Entirely 832's T-228/T-2593 off-page claim-seam work (S4b CLI claim shipped, S4a
  picker re-verify, 0.3.0 jump/autosave RCA + 0.3.1 root-fix request, exemplar
  hand-off) — unrelated to T-2556. No message in this window mentions T-213/kind=
  beyond the standing "still tracking" line 832 repeats each post. AC2/AC3's
  kind=documentation half remains blocked on 832's operator ruling — evidence gap,
  not a build gap. AC3's absent-marker half re-verified green
  (`tests/web/test_bpmn_frozen_v1_pin.py` 3/3). No build action taken (T-2541
  discipline).
- 2026-07-22 **rail re-checked (offset 152, current latest), still no ruling.** Offsets
  151-152 are 832's S4a re-verify ack + T-234 (0.3.1 jump/autosave root-fix, RCA
  confirmed and filed) + T-235 (exemplar, filed) + S5a parity-guard landed — all
  T-228/T-2593 off-page-seam work, unrelated to T-213/kind=. 832 explicitly restates
  the parked item in the same message ("the two operator items (T-213 kind=, 0.3.1
  tag — now with T-234 as content)") — still no disposition beyond offset 127.
  AC2/AC3's kind=documentation half remains genuinely blocked — evidence gap, not a
  build gap. AC3's absent-marker half re-verified green
  (`tests/web/test_bpmn_frozen_v1_pin.py` 3/3). No build action taken (T-2541
  discipline).
- 2026-07-22 **rail re-checked (cursor 153, no new offsets beyond 152), still no
  ruling.** 832's latest (offset 152) triple-acks unrelated T-228/T-2593 work
  (S4a re-verify, T-234 RCA+fix-plan for 0.3.1, T-235 exemplar spec) and restates
  the same standing line: "the two operator items (T-213 kind=, 0.3.1 tag — now
  with T-234 as content)". No disposition beyond offset 127 exists. AC2/AC3's
  kind=documentation half remains genuinely blocked — evidence gap, not a build
  gap. AC3's absent-marker half re-verified green
  (`tests/web/test_bpmn_frozen_v1_pin.py` 3/3). No build action taken (T-2541
  discipline).
- 2026-07-22 **rail re-checked (`channel info` Posts: 153, matches prior cursor;
  `--from-latest --once` confirms offset 152 is still the newest post), still no
  ruling.** No new offsets since the previous check. AC2/AC3's kind=documentation
  half remains genuinely blocked on 832's operator ruling — evidence gap, not a
  build gap. AC3's absent-marker half re-verified green
  (`tests/web/test_bpmn_frozen_v1_pin.py` 3 passed). No build action taken (T-2541
  discipline: don't build ahead of ratification).
- 2026-07-22 **rail re-checked (Posts: 154, offset 153 new), still no ruling.**
  Offset 153 is AEF's own outbound note to 832 — a NEW 0.3.1 candidate finding
  (eventDef/linkEventCatch vocabulary collision, sibling of T-234, from T-2601's
  RCA) — not a disposition on T-213/kind=. The note's own waits list ("T-234 fix
  announce, T-235 exemplar, T-213 kind=, 0.3.1 tag") reconfirms kind= is still
  parked. No disposition beyond offset 127 exists. AC2/AC3's kind=documentation
  half remains genuinely blocked — evidence gap, not a build gap. AC3's
  absent-marker half re-verified green (`tests/web/test_bpmn_frozen_v1_pin.py`
  3 passed). No build action taken (T-2541 discipline: don't build ahead of
  ratification).
- 2026-07-22 **rail re-checked (offsets 154→160, current latest, Posts: 161), still
  no ruling.** Entirely 832's T-234/T-237 (0.3.1 fixes: jump-autosave root-fix
  landed 7390131, eventDef/linkEventCatch release-lineage fix landed dd8ce64) plus
  the T-235 picker-claim exemplar delivery (offset 158) and AEF's own intake ack
  (offset 160, tracked as our T-2606) — none of it touches T-213/kind=. 832
  restates the standing wait verbatim at offset 160 ("Remaining waits: T-213 kind=
  ruling, 0.3.1 tag"). No disposition beyond offset 127 exists. AC2/AC3's
  kind=documentation half remains genuinely blocked — evidence gap, not a build
  gap. AC3's absent-marker half re-verified green
  (`tests/web/test_bpmn_frozen_v1_pin.py` 3 passed). No build action taken
  (T-2541 discipline: don't build ahead of ratification).
- 2026-07-22 **rail re-checked (offset 161, current latest, Posts: 162), still no
  ruling.** Offset 161 is 832's ack of our T-2606 intake confirmation (S4 loop
  closed both sides, exemplar sha match) plus their own bookkeeping note about a
  new hermetic editor-behavior test suite (their T-238, closing G-010) — none of
  it touches T-213/kind=. 832 explicitly restates the standing wait verbatim:
  "Both remaining waits (T-213 kind= ruling, 0.3.1 tag) are with our operator —
  quiet on the rail from us until one of those moves." No disposition beyond
  offset 127 exists. AC2/AC3's kind=documentation half remains genuinely
  blocked — evidence gap, not a build gap. AC3's absent-marker half re-verified
  green (`tests/web/test_bpmn_frozen_v1_pin.py` 3 passed). No build action taken
  (T-2541 discipline: don't build ahead of ratification).
- 2026-07-22 **rail re-checked (offsets 162→166, current latest), still no
  ruling.** This window is entirely 832's 0.3.1 release cycle (T-2546/T-2611):
  offset 162 = release cut + re-pin checklist; offset 163 = AEF ack + relay of
  the separate T-2551 consumption NO-GO (unrelated seam, already recorded
  above); offsets 164-166 = file_send delivery, sha-match confirmation, and
  AEF's live e2e re-pin verdict (T-234/T-237 fixes confirmed on served bytes).
  None of it touches T-213/kind=. Both prior "still tracking" lines (offsets
  152/160/161) already named the 0.3.1 tag as the *other* parked item — that
  item is now resolved (0.3.1 shipped and re-pinned); T-213/kind= remains the
  sole open item, still with 832's operator. No disposition beyond offset 127
  exists. AC2/AC3's kind=documentation half remains genuinely blocked —
  evidence gap, not a build gap. AC3's absent-marker half re-verified green
  (`tests/web/test_bpmn_frozen_v1_pin.py` 3 passed). No build action taken
  (T-2541 discipline: don't build ahead of ratification).
- 2026-07-22 **rail re-checked (offset 167, current latest), still no ruling.**
  Offset 167 is 832's ack of our T-234/T-237 e2e re-pin verdict — full 0.3.1
  arc close-out (root-caused, fixed, released, delivered, re-pinned,
  e2e-verified), plus two new unrelated observations filed their-side (832
  T-240 uuid-jump auto-resolve, T-241 /api/thumb fallback — neither touches
  T-213/kind=). 832 explicitly restates the parked item verbatim: "our
  operator still holds T-213 kind= and T-228 finalize." No disposition
  beyond offset 127 exists. AC2/AC3's kind=documentation half remains
  genuinely blocked — evidence gap, not a build gap. AC3's absent-marker
  half re-verified green (`tests/web/test_bpmn_frozen_v1_pin.py` 3 passed).
  No build action taken (T-2541 discipline: don't build ahead of
  ratification).
- 2026-07-23 **rail re-checked (Posts: 168, one new offset since 167), still no
  ruling.** The new post is 832's ack of the 0.3.1 arc close-out (their T-240
  uuid-jump-autoresolve and T-241 thumb-fallback observations confirmed filed
  their-side with our evidence cited) — none of it touches T-213/kind=. 832
  explicitly restates the parked item verbatim: "our operator still holds
  T-213 kind= and T-228 finalize." No disposition beyond offset 127 exists.
  AC2/AC3's kind=documentation half remains genuinely blocked — evidence gap,
  not a build gap. AC3's absent-marker half re-verified green
  (`tests/web/test_bpmn_frozen_v1_pin.py` 3 passed). No build action taken
  (T-2541 discipline: don't build ahead of ratification).
- 2026-07-23 **rail re-checked (Posts: 168, unchanged from prior check), still no
  ruling.** `termlink channel info` and `--from-latest --once` both confirm
  offset 167 (0.3.1 arc close-out ack) remains the newest post — no new
  message since the last re-check. AC2/AC3's kind=documentation half remains
  genuinely blocked on 832's operator ruling — evidence gap, not a build gap.
  AC3's absent-marker half re-verified green
  (`tests/web/test_bpmn_frozen_v1_pin.py` 3 passed). No build action taken
  (T-2541 discipline: don't build ahead of ratification).
- 2026-07-23 **rail re-checked (`termlink channel info` Posts: 168, unchanged),
  still no ruling.** No new message since the prior check — offset 167 (0.3.1
  arc close-out ack) remains the newest post. AC2/AC3's kind=documentation
  half remains genuinely blocked on 832's operator ruling — evidence gap, not
  a build gap. AC3's absent-marker half re-verified green
  (`tests/web/test_bpmn_frozen_v1_pin.py` 3 passed). No build action taken
  (T-2541 discipline: don't build ahead of ratification).
- 2026-07-23 **rail re-checked (`termlink channel info` Posts: 168, unchanged),
  still no ruling.** Offset 167 remains the newest post; no new message from
  832 since the prior check. AC2/AC3's kind=documentation half remains
  genuinely blocked on 832's operator ruling (T-213) — evidence gap, not a
  build gap. AC3's absent-marker half re-verified green
  (`tests/web/test_bpmn_frozen_v1_pin.py` 3 passed). No build action taken
  (T-2541 discipline: don't build ahead of ratification).
- 2026-07-23 **rail re-checked (`termlink channel info` Posts: 168, unchanged),
  still no ruling.** No new message since the prior check — offset 167 (0.3.1
  arc close-out ack) remains the newest post. AC2/AC3's kind=documentation
  half remains genuinely blocked on 832's operator ruling (T-213) — evidence
  gap, not a build gap. AC3's absent-marker half re-verified green
  (`tests/web/test_bpmn_frozen_v1_pin.py` 3 passed). No build action taken
  (T-2541 discipline: don't build ahead of ratification).
- 2026-07-23 **rail re-checked (`termlink channel info` Posts: 168, unchanged;
  `--from-latest --once` confirms offset 167 text unchanged), still no
  ruling.** No new message since the prior check — offset 167 (0.3.1
  arc close-out ack, "our operator still holds T-213 kind= and T-228
  finalize") remains the newest post. AC2/AC3's kind=documentation half
  remains genuinely blocked on 832's operator ruling (T-213) — evidence
  gap, not a build gap. AC3's absent-marker half re-verified green
  (`tests/web/test_bpmn_frozen_v1_pin.py` 3 passed). No build action taken
  (T-2541 discipline: don't build ahead of ratification).
- 2026-07-23 **rail re-checked (`termlink channel info` Posts: 168, unchanged;
  `--from-latest --once` confirms offset 167 text unchanged), still no
  ruling.** No new message since the prior check — offset 167 (0.3.1
  arc close-out ack, "our operator still holds T-213 kind= and T-228
  finalize") remains the newest post. AC2/AC3's kind=documentation half
  remains genuinely blocked on 832's operator ruling (T-213) — evidence
  gap, not a build gap. AC3's absent-marker half re-verified green
  (`tests/web/test_bpmn_frozen_v1_pin.py` 3 passed). No build action taken
  (T-2541 discipline: don't build ahead of ratification). **Loop-frequency
  note:** this is now 15+ consecutive re-checks since offset 127 (2026-07-21)
  with zero state change — the dispatch cadence (~30min) is producing no new
  evidence. Recommend the orchestrator throttle re-dispatch of this task
  (e.g. horizon: later, or a longer poll interval) until 832 posts a new
  offset, rather than continuing to consume dispatch cycles on an unchanged
  external dependency.
- 2026-07-23 **rail re-checked (Posts: 171, offsets 168-170 new), still no
  ruling on T-213.** All three new offsets are 832's T-240/T-242 uuid-
  workflowRef-auto-resolve exchange (a different regression thread, our
  T-2612) -- dual-form corpus compat, hotfix-promote request, and their fix
  confirmation. None mention T-213/kind=. This is now 19+ consecutive
  re-checks since offset 127 with zero movement on the actual blocker.
  Acting on the throttle recommendation logged above: demoting horizon
  to `later` to stop consuming dispatch cycles on an unchanged external
  dependency -- this task should be re-promoted to `now` when 832 posts a
  disposition on T-213 (watch for a new offset explicitly addressing
  kind=/T-213, not their standing "still tracking" line). AC3's
  absent-marker half remains green (`tests/web/test_bpmn_frozen_v1_pin.py`
  3 passed). No build action taken (T-2541 discipline: don't build ahead of
  ratification).

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Additive `aef:workflowMeta kind="documentation|work-plan"` proposed to 832 over the rail (they own the vocabulary; ratification loop per arc-014 continuity spine) and their disposition recorded here — proposed offset 125, disposition offset 127 (routed to 832's T-213 operator ratification, engineering-read recommends ratify-as-is + closed-enum amendment; recorded in §Progress)
- [ ] On 832 ratification: `fw bpmn compile` reads the marker — documentation diagrams compile with a "documentation diagram — skeletons are illustrative, not for promote" notice; `fw bpmn promote` refuses (or requires an explicit override) on kind=documentation staged proposals
- [ ] Missing/absent marker keeps today's behavior byte-identical (additive-only, frozen-v1 discipline); regression test pins both paths

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
# AC3 absent-marker frozen-v1 pin (green today; post-ratification legs must keep it green):
python3 -m pytest tests/web/test_bpmn_frozen_v1_pin.py -q > /tmp/.t2556-pin.out 2>&1 && grep -q "3 passed" /tmp/.t2556-pin.out
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

### 2026-07-19T20:07:24Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2556-corpus-gap-no-diagram-kind-marker--docum.md
- **Context:** Initial task creation

### 2026-07-19T20:07:50Z — status-update [task-update-agent]
- **Change:** tags: +arc:designer-corpus

### 2026-07-19T20:09:39Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)

### 2026-07-19T20:10:30Z — status-update [task-update-agent]
- **Change:** horizon: now → later
- **Change:** status: started-work → captured (auto-sync)

### 2026-07-21T19:05:50Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)

### 2026-07-23T07:29:39Z — status-update [task-update-agent]
- **Change:** horizon: now → later
- **Change:** status: started-work → captured (auto-sync)

### 2026-07-23T08:59:22Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)
