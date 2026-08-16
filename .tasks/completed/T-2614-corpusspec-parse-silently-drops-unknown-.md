---
id: T-2614
name: "corpus_spec parse silently drops unknown BPMN tags — subProcess lost from inception-flow,
  strict-parse + restore"
description: >
  corpus_spec parse silently drops unknown BPMN tags — subProcess lost from inception-flow,
  strict-parse + restore

status: work-completed
workflow_type: build
owner: agent
horizon:
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
created: 2026-07-23T07:46:37Z
last_update: '2026-08-16T22:25:12Z'
date_finished: 2026-07-23T07:54:25Z
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
  - ts: '2026-08-16T22:25:12Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 3
      D3: 2
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=3 
      (body:component-silent-failure); D3=2 (body:default-change); D4=2 
      (body:env-class-handled); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2614: corpus_spec parse silently drops unknown BPMN tags — subProcess lost from inception-flow, strict-parse + restore

## Context

Operator (2026-07-23): "aef-inception-flow — the workflow is disconnected." Root
cause: `parse_map` (tools/corpus_spec.py) only knows 7 flow-node tags and SILENTLY
SKIPS anything else. The pre-recreate aef-inception-flow carried `hum_3_inception`
as a `bpmn:subProcess` (designer palette: "Sub-process collapsed composite") — the
T-2609 recreate parsed-and-dropped it while keeping the two flows referencing it,
so the served map renders as two disconnected halves with the operator's
inception-decision node missing. The canonical-diff identity guard was blind
because BOTH sides of the comparison pass through the same lossy parse. Sweep also
found t2530-verify carries `parallelGateway`, `scriptTask`, `conditionExpression`
(all designer-supported) which the parser would equally destroy on any future
prove/regenerate run. Same class as T-2557 (silent gateway loss in compile).

## Acceptance Criteria

### Agent
- [x] parse_map fails LOUDLY (non-zero, naming the tag and node id) on any
      unmapped bpmn flow-node tag — silent skips eliminated; pinned both ways in
      unit tests. (test_unknown_tag_is_a_hard_error_not_a_silent_drop; laneSet /
      extensionElements structural containers exempt.)
- [x] Vocabulary extended to the designer-palette types found in the corpus:
      subProcess, scriptTask, parallelGateway round-trip parse→emit (unknown ext
      children preserved verbatim via ext_raw — aef:constituents, aef:endpoint,
      aef:contextReads); sequenceFlow conditionExpression preserved via
      raw_children. Pinned in tests/unit/test_corpus_spec_roundtrip.py.
- [x] aef-inception-flow restored: regenerated from the last pre-loss source
      (git ddde8b2b1 v2) with the fixed parser — hum_3_inception subProcess back
      with its full constituents block, all 9 flows attached, uuid 6178cf0a
      preserved, saved as v3 (non-destructive), dual-form link per T-2612;
      canonical-identity vs pre-loss source asserted before the save.
- [x] New lint rule `dangling-flow-ref` shipped in tools/corpus_lint.py; pinned
      both ways in test_corpus_lint.py; live corpus clean (2-finding baseline
      unchanged).
- [x] Live e2e: aef-inception-flow v3 renders CONNECTED on the served surface —
      all 9 edges (if_e1..if_e9; e3/e4 were the missing pair) + the restored
      inception subProcess (uid if_inception) present in the rendered DOM
      (Playwright, operator path). t2530-verify round-trips loss-free through
      the fixed parser (canonical-identical, parallelGateway/scriptTask/
      conditionExpression preserved; store untouched).
- [x] Suites green: 27/27 (roundtrip 4 + lint 17 + prove-guard 2 + DR 1 + s4 3).

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

python3 -m pytest tests/unit/test_corpus_spec_roundtrip.py tests/unit/test_corpus_lint.py tests/unit/test_corpus_prove_guard.py -q

# restored latest version carries the subProcess + constituents, dual-form link
out=$(cat .context/designer/projects/aef-inception-flow/v3.bpmn); echo "$out" | grep -q '<bpmn:subProcess id="hum_3_inception"' && echo "$out" | grep -q 'aef:constituents' && echo "$out" | grep -q 'targetWorkflow="aef-task-lifecycle" workflowRef="1f9b5f0c'

# live corpus lint clean at pinned baseline — no dangling-flow-ref, no unbindable
out=$(python3 tools/corpus_lint.py 2>&1); echo "$out" | grep -q "2 finding(s)" && ! echo "$out" | grep -q "dangling-flow-ref" && ! echo "$out" | grep -q "editor-unbindable"

# strict parse: unknown tag is a hard error naming tag + id
out=$(python3 -c "import sys; sys.path.insert(0,'tools'); import corpus_spec; corpus_spec.parse_map(open('.context/designer/projects/aef-inception-flow/v3.bpmn').read().replace('bpmn:subProcess','bpmn:callActivity'))" 2>&1); echo "$out" | grep -q "callActivity" && echo "$out" | grep -q "hum_3_inception"

# uuid preserved through restore (6178cf0a…)
python3 -c "import json; assert json.load(open('.context/designer/projects/aef-inception-flow/meta.json'))['uuid'].startswith('6178cf0a')"

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

**Symptom:** aef-inception-flow rendered as two disconnected halves on the served
designer — the operator's inception-decision node (`hum_3_inception`) missing from
the canvas, edges e3/e4 not drawn. Operator report: "the workflow is disconnected."

**Root cause:** `parse_map` recognized exactly 7 flow-node tags and silently
skipped everything else. `hum_3_inception` was authored as `bpmn:subProcess`
(designer palette "Sub-process collapsed composite", carrying an
`aef:constituents` block) — the T-2609 recreate parsed-and-dropped the node while
keeping the two sequenceFlows referencing it. The editor renders the nodes it has
and silently drops dangling edges → disconnected graph.

**Why structurally allowed:** Three stacked blindnesses. (1) The parse's unknown-tag
branch was a silent `else: pass` — loss with no signal. (2) The canonical-diff
identity guard compares `parse(source)` vs `parse(emit)` — BOTH sides pass through
the same lossy parse, so a dropped node diffs as "identical". (3) No lint rule
checked flow endpoints against node existence, so the served store carried dangling
refs for a full day without any surface turning red. Same class as T-2557 (silent
gateway loss in compile) — known in the backlog, not yet generalized to parse.

**Prevention (distinct from the fix):** (1) Unknown identified process children are
now a hard SystemExit naming tag + node id — the loss mode is structurally
unreachable; extending coverage requires a deliberate TYPE_TO_TAG edit. (2) Lint
rule `dangling-flow-ref` turns any future dropped-node state red at lint time and
in the live-corpus baseline test. (3) The store-level pin
test_live_inception_flow_carries_the_restored_subprocess fails if the node ever
vanishes from the served latest again. Note the guard-blindness lesson: an identity
proof is only as strong as the representation it compares — raw-XML-level checks
(dangling refs, node counts) must back up parse-level canonical diffs.

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

### 2026-07-23T07:46:37Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2614-corpusspec-parse-silently-drops-unknown-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-6b5fce20
- **Timestamp:** 2026-07-23T07:54:28Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **mock-only-integration** (partial, heuristic) @ AC vs Verification cross-check
     - evidence: `python3 -m pytest tests/unit/test_corpus_spec_roundtrip.py tests/unit/test_corpus_lint.py tests/unit/test_corpus_prove_guard.py -q`

### 2026-07-23T07:54:25Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
