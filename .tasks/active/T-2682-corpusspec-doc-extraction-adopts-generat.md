---
id: T-2682
name: "corpus_spec doc extraction adopts generator boilerplate as semantic doc"
description: >
  parse_map takes the FIRST XML comment child as the map's semantic 'doc' with no
  positional or content guard. When the real leading doc comment is absent (destroyed
  by designer UI saves), it silently adopts the generator's own trailing DI boilerplate
  comment, so the field reads plausible-and-wrong instead of empty. 5 of 11 maps affected,
  2 already promoted. G-071 silent-wrong-value class, found same-day.

status: started-work
workflow_type: build
owner: agent
horizon: now
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
created: 2026-07-29T17:51:07Z
last_update: 2026-07-29T17:52:45Z
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
  - ts: '2026-07-29T17:52:46Z'
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
---

# T-2682: corpus_spec doc extraction adopts generator boilerplate as semantic doc

## Context

Found while checking the three designer-side observations flagged to 832 (rail 331)
for promotion risk on `draft-knowledge-leveling` v7 — a check that was supposed to be
routine and instead surfaced silent data loss.

**Two defects, one on each side of the designer↔corpus seam:**

1. **Designer save path drops the leading doc comment** (832's leg, reported rail 332).
   Confirmed on two independent projects: `draft-knowledge-leveling` v5→v6 and
   `draft-trigger-handling` v1→v2. Pattern is exact — the last agent-authored version
   carries the doc, the first UI save drops it, every save after inherits the loss.
   Nothing else is harmed: uid set, flow topology, names and `aef:meta` notes all
   round-trip faithfully.

2. **Our reader masked it** (this task). `parse_map` took the FIRST comment child of
   `<bpmn:definitions>` as the semantic `doc`, with no positional or content guard.
   Every generated file ends with the emitter's own `BPMN DI (visual layout) omitted…`
   trailer, so when the real doc vanished the reader adopted the trailer instead. The
   field never read empty — it read plausible-and-wrong, which is why neither side
   noticed.

**Laundering made it permanent.** Once adopted, `generate` re-emitted the boilerplate in
LEADING position, so the next read could not distinguish corruption from authored doc.
`aef-audit-cron` and `aef-session-lifecycle` reached the *promoted* corpus that way —
which is why the positional guard alone is insufficient and a content guard is also
load-bearing.

**Census at discovery:** 5 of 11 maps carried the boilerplate as their doc; 2 were
already promoted.

This is a same-day instance of the **G-071 class** (T-2679, filed hours earlier): a
deterministic component encoding a world-assumption — "the first comment is the doc" —
that stayed true only while every file was agent-authored, then silently produced a
wrong value rather than an error when the world changed. Recorded as dogfood evidence
on that gap.

Follow-on: **OBS-101** — the two promoted maps now honestly report no doc and need real
doc text authored (not auto-fixable). `draft-trigger-handling` is deliberately NOT
repaired here: it is under active operator editing, and restoring its doc is futile
until 832 fixes the save path — the next UI save would drop it again.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `parse_map` accepts a comment as `doc` only in LEADING position (before the first
      non-comment child of `<bpmn:definitions>`), matching the generator's own emission
      at `tools/corpus_spec.py:327-329`. A trailing comment is never adopted as `doc`.
- [x] Loud-fail rather than silent-wrong: when a map has no leading doc comment, `doc`
      is absent from the spec (not populated with boilerplate). The absence is what a
      future doc-presence check can detect.
- [x] `draft-knowledge-leveling` v7 and `draft-trigger-handling` v6 derive with NO `doc`
      key (previously both carried the DI boilerplate string).
- [x] `draft-exception-handling` v3 and `aef-task-lifecycle` v1 still derive their real
      doc unchanged (no regression on maps whose doc is intact).
- [x] Round-trip identity preserved: `derive → generate → diff` remains IDENTICAL for a
      map with a real doc and for a map with none.
- [x] Unit tests pin all four shapes (leading doc, trailing-only comment, both, neither).
- [x] Corpus lint baseline unchanged at 2 findings.

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

python3 -m pytest tests/unit/test_corpus_spec_doc_guard.py tests/unit/test_corpus_spec_roundtrip.py -q
# knowledge-leveling v8 (promotion candidate) carries a real doc, not the boilerplate
out=$(python3 tools/corpus_spec.py derive .context/designer/projects/draft-knowledge-leveling/v8.bpmn); echo "$out" | grep -q "^doc:.*DRAFT (pair-draft session, T-2667"
# the two UI-saved drafts no longer report a fake doc
out=$(python3 tools/corpus_spec.py derive .context/designer/projects/draft-trigger-handling/v6.bpmn); ! echo "$out" | grep -q "BPMN DI (visual layout) omitted"
# maps with a real doc are untouched
out=$(python3 tools/corpus_spec.py derive .context/designer/projects/aef-task-lifecycle/v1.bpmn); echo "$out" | grep -q "^doc:.*designer-corpus D1"
# round-trip identity holds for both shapes (doc present / doc absent)
python3 tools/corpus_spec.py derive .context/designer/projects/draft-knowledge-leveling/v8.bpmn > /tmp/.t2682a.yaml && python3 tools/corpus_spec.py generate /tmp/.t2682a.yaml > /tmp/.t2682a.bpmn && python3 tools/corpus_spec.py diff .context/designer/projects/draft-knowledge-leveling/v8.bpmn /tmp/.t2682a.bpmn
python3 tools/corpus_spec.py derive .context/designer/projects/draft-trigger-handling/v6.bpmn > /tmp/.t2682b.yaml && python3 tools/corpus_spec.py generate /tmp/.t2682b.yaml > /tmp/.t2682b.bpmn && python3 tools/corpus_spec.py diff .context/designer/projects/draft-trigger-handling/v6.bpmn /tmp/.t2682b.bpmn
# corpus lint baseline unchanged at 2
out=$(bin/fw corpus lint 2>&1); echo "$out" | grep -q "^2 finding(s)"

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

**Symptom:** `draft-knowledge-leveling` v7 derived with
`doc: "BPMN DI (visual layout) omitted in this demo; AEF generates it from node
coordinates"` — the generator's own trailer standing in for the map's rationale block.
The v5 doc (token definition, chain description, DEAD census, scan contract, sources of
truth) was gone. Across the corpus, 5 of 11 maps were in this state and 2 were already
promoted.

**Root cause:** `parse_map` selected the map's semantic `doc` as *the first comment child
of `<bpmn:definitions>`, wherever it appeared*. The writer (`generate`) emits the doc as
a **leading** comment and the DI note as a **trailing** one — an asymmetry the reader
never encoded. So the reader's selection rule was correct only under the accidental
condition that a leading doc always exists.

**Why structurally allowed:** three compounding reasons, and the third is the important
one.
1. Nothing asserted the reader/writer positional contract; the two evolved independently
   (the T-1890 / L-399 producer-consumer parity class, applied to a file format instead
   of a CLI flag).
2. The bad value was *self-perpetuating*: `generate` re-emitted the adopted trailer in
   leading position, so one derive→generate cycle laundered corruption into
   indistinguishable-from-authored doc. That is how it reached the promoted corpus.
3. **The failure produced a plausible value instead of an absence.** Every check that
   could have caught it — canonical diff, round-trip identity, `fw corpus lint`, both
   validators — passed, because a populated `doc` field is indistinguishable from a
   correct one without knowing what the doc *should* say. An empty `doc` would have been
   noticed months ago.

**Prevention (distinct from the fix):**
- `tests/unit/test_corpus_spec_doc_guard.py` — 9 tests pinning both guards and both
  failure legs, including the laundering case (leading boilerplate) that the positional
  guard alone does not catch, and the inverse case (an authored doc that merely mentions
  DI) so the content guard cannot over-reach.
- Absence is now *detectable*: the `doc` key is omitted rather than set to a placeholder,
  which is the hook a future doc-presence check in `fw corpus lint` can key on. Not built
  here — one bug, one task — recorded as the natural next rail.
- Cross-boundary: reported to 832 (rail 332) with the schema question of whether the doc
  should live as an `aef:` attribute on `workflowMeta` instead of an XML comment, which
  would survive any DOM round-trip regardless of editor behaviour.
- Class-level: filed as dogfood evidence on **G-071** (T-2679, same day) — a deterministic
  component whose frozen world-assumption silently produced a wrong value instead of an
  error once the world changed. This is exactly the case the assumption-rail probes
  (T-2681) are meant to catch, and a probe of the form *"every promoted map has a
  non-boilerplate doc"* is a concrete seed for that registry.

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

### 2026-07-29T17:51:07Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2682-corpusspec-doc-extraction-adopts-generat.md
- **Context:** Initial task creation

### 2026-07-29T17:52:45Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
