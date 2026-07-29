---
id: T-2683
name: "restore laundered doc comments on two promoted corpus maps (OBS-101)"
description: >
  restore laundered doc comments on two promoted corpus maps (OBS-101)

status: work-completed
workflow_type: refactor
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
created: 2026-07-29T19:45:57Z
last_update: 2026-07-29T20:54:36Z
date_finished: 2026-07-29T20:54:36Z
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
  - ts: '2026-07-29T20:00:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 3
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=3 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-29T20:00:10Z'
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

# T-2683: restore laundered doc comments on two promoted corpus maps (OBS-101)

## Context

OBS-101 remediation. T-2682 fixed the *reader* (corpus_spec no longer adopts the
generator's DI trailer as a map's semantic `doc`), but two already-promoted corpus maps
had reached the store doc-less: `aef-audit-cron` and `aef-session-lifecycle`. Both showed
the boilerplate `BPMN DI (visual layout) omitted…` where their authored rationale block
should be — visible in `fw corpus explain` as the map's description.

OBS-101 was filed as "not auto-fixable / needs re-authoring". That turned out to be wrong:
both original doc blocks survive verbatim in git history (`bd07caa4a` for D5 audit-cron,
`bb1677872` for D3 session-lifecycle, pre-dating the T-2629 store squash that ran through
the designer UI). So this is a **mechanical restore from history**, not re-authoring —
no new prose, no taste call.

Restore is applied to the *current* promoted bytes (which carry the designer's renumbered
ids and its positions — the accepted current state); only the `doc` key is added back.
Nothing else is reverted.

Confirmed upstream cause, 832 rail 333: `/api/save` does not round-trip comment children
at all — no COMMENT_NODE handling in the parse path, and `buildBpmnXml` unconditionally
emits exactly one hardcoded comment (the DI trailer). Their repair is filed as T-311.

## Acceptance Criteria

### Agent
- [x] Original doc blocks located in git history for both maps (no re-authoring needed)
- [x] `doc` restored verbatim into current `v1.bpmn` for `aef-audit-cron` and `aef-session-lifecycle`, positioned as the first comment child so the T-2682 leading-only reader picks it up
- [x] Semantic delta vs `HEAD` is exactly one key (`doc`) on both maps — no node/flow/lane/position changes
- [x] `parse_map` reports `doc_present=True` and `boilerplate=False` for both
- [x] Round-trip `derive → generate → diff` IDENTICAL on both
- [x] `fw corpus lint` baseline unchanged (2 findings: t2584-scratch legacy-ref, dispatch-loop emitterless-typed-event)
- [x] All 5 conformance rails still PASS (`corpus_conformance.py --all`)
- [x] Live-served bytes match disk and carry the restored doc (`/api/version?id=…&v=1`)

<!-- No Human ACs: this is a verbatim restore from git history, not authored content.
     Every criterion above is a deterministic shell check — no taste call to make.
     Template guidance retained below for reference.

     Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
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

# Both promoted maps carry a non-boilerplate doc (the whole point of the task).
python3 -c "import sys,io; sys.path.insert(0,'tools'); from corpus_spec import parse_map; ok=all((lambda d: d is not None and not d.strip().startswith('BPMN DI'))(parse_map(io.open(f'.context/designer/projects/{m}/v1.bpmn',encoding='utf-8').read()).get('doc')) for m in ('aef-audit-cron','aef-session-lifecycle')); sys.exit(0 if ok else 1)"
# Round-trip stays IDENTICAL on both restored maps.
for m in aef-audit-cron aef-session-lifecycle; do f=.context/designer/projects/$m/v1.bpmn; t=$(mktemp -d); python3 tools/corpus_spec.py derive "$f" > "$t/s.yaml" && python3 tools/corpus_spec.py generate "$t/s.yaml" > "$t/r.bpmn" && python3 tools/corpus_spec.py diff "$f" "$t/r.bpmn" > /dev/null || exit 1; done
# Lint baseline unchanged at 2 findings.
out=$(bin/fw corpus lint 2>&1); echo "$out" | grep -q "^2 finding(s)"
# All conformance rails green.
out=$(python3 tools/corpus_conformance.py --all 2>&1); ! echo "$out" | grep -q "FAIL"

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

**Symptom:** `fw corpus explain aef-audit-cron` printed the generator's DI-trailer
boilerplate where the map's authored rationale should be. Same for `aef-session-lifecycle`.
Both are promoted corpus maps.

**Root cause:** two independent defects composing across the designer↔corpus seam.
832's `/api/save` drops comment children entirely at parse and re-emits only its own
hardcoded DI trailer (their T-311, confirmed at rail 333). Our `parse_map` then took the
first comment child positionally, with no content guard, so it adopted that trailer as
`doc`. One `derive → generate` cycle re-emitted the adopted trailer in *leading* position,
making the corruption indistinguishable from authored content. The T-2629 store squash ran
through the designer UI, which is how these two maps reached the promoted store doc-less.

**Why structurally allowed:** the field was never empty — it was plausible-and-wrong. Canonical
diff, round-trip, `fw corpus lint` and both validators (ours and 832's) all passed, because
every one of them is structural and a populated `doc` key satisfies all of them. This is the
G-071 signature exactly: a deterministic component whose frozen world-assumption ("the first
comment is the doc") returns a wrong value rather than an error once the world changes.

**Prevention:** the reader guard + 9 tests shipped in T-2682 stop new instances. This task
clears the two existing ones. The remaining hole is detection: nothing asserts that a
*promoted* map has a real doc. That probe — "every promoted map has a non-boilerplate doc" —
is the concrete seed carried into T-2681's assumption-rail registry, and it is a shell-cheap
count-floor check per the T-2679 A-048 cost constraint. Until it exists, G-071 stays open.

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

### 2026-07-29 — restore onto current bytes rather than reverting to the historic version

- **Chose:** add the `doc` key back to the *current* promoted `v1.bpmn` of each map, leaving
  the designer's renumbered ids and its positions exactly as they are.
- **Why:** the semantic diff between the historic and current versions is not doc-only —
  ids were renumbered (`ac_f1` → `flow_1`, uids stable) and several positions moved. Those
  are the operator's accepted current state, arrived at through the T-2629 squash. Reverting
  them to win back the doc would trade a known-good state for a stale one. Restricting the
  change to one key keeps this a repair rather than a revision, and makes the delta provable.
- **Rejected:** (a) `git checkout` of the historic file — reverts accepted layout/id state;
  (b) re-authoring the doc from scratch — unnecessary, the originals exist verbatim, and new
  prose would need a taste call this task should not incur; (c) repairing
  `draft-trigger-handling` in the same pass — it is under active operator editing and the
  save path still drops the comment, so a restore there would be overwritten on the next save
  (same reasoning as T-2682's deliberate skip).

### 2026-07-29 — decouple the doc repair from the workflowMeta schema question

- **Chose:** treat comment preservation as the immediate fix and keep "carry doc as an `aef:`
  attribute on `workflowMeta`" as a separate, later ratification question.
- **Why:** 832 flagged a trap at rail 333 — `workflowMeta` import is an 8-key allowlist with
  export re-synthesis, so an unratified key drops *silently* on save. That is the T-257 class:
  it would fail exactly the way the comment does, only less visibly. Their recommendation was
  explicit ("I would not couple them") and it is correct — the coupled version blocks the
  promotion this task unblocks, on a dialect change neither side has ratified.
- **Rejected:** pursuing the attribute route now — it trades a working repair for a schema
  negotiation, and would reintroduce silent loss in a harder-to-see place.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-07-29T19:45:57Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2683-restore-laundered-doc-comments-on-two-pr.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-a62eb901
- **Timestamp:** 2026-07-29T20:54:39Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 39
     - evidence: `out=$(python3 tools/corpus_conformance.py --all 2>&1); ! echo "$out" | grep -q "FAIL"`

### 2026-07-29T20:54:36Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
