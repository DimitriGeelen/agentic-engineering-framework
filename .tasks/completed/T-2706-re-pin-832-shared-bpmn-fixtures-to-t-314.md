---
id: T-2706
name: "Re-pin 832 shared BPMN fixtures to T-314 repaired bytes (independent digest
  verification)"
description: >
  Re-pin 832 shared BPMN fixtures to T-314 repaired bytes (independent digest verification)

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
created: 2026-07-31T11:26:21Z
last_update: 2026-07-31T11:47:54Z
date_finished: 2026-07-31T11:47:54Z
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
  - ts: '2026-07-31T11:30:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-31T11:30:10Z'
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

# T-2706: Re-pin 832 shared BPMN fixtures to T-314 repaired bytes (independent digest verification)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

See `## Outcome` below — re-pin COMPLETED after 832 (rail 353) supplied the pullable
ref the tag was missing.

### Agent
- [x] Both transferred files received into a STAGING dir, never written straight
      over the live fixtures — digests decide whether they land at all
- [x] Digests derived INDEPENDENTLY and compared to 832's rail-350 claims
      (`bbfbc5ec…` / `2ba55eed…`). On any mismatch: do NOT re-pin, report to 832 —
      a mismatch means the TRANSFER is lossy, which is the thing we would both
      then be wrong about
      → MATCH. Re-derived from the PUBLIC mirror (`github.com/DimitriGeelen/
      workflow-designer`), not from 832's working tree and not from a transfer.
      `e133cf9` confirmed an ancestor of `origin/master`; blob digests identical at
      `e133cf9`, `origin/master` and `github/master`.
- [x] Zero-semantic claim re-derived here, not taken on faith: flowNodeRef
      membership, every `aef:position`, every `aef:uid`, sequenceFlow source/target
      set, laneMeta heights, process child-element set — all identical pre vs post,
      with only lane element ORDER differing
      → CONFIRMED on both fixtures: element census identical, `id=` set identical,
      `flowNodeRef` multiset identical, byte size identical (4314 / 5491). The sole
      textual change is the `human` lane block relocating from FIRST to LAST inside
      `<laneSet>`. Per our own T-2686 finding (band order = laneSet document order)
      that is not cosmetic — it is precisely the rendered-order fix.
- [x] `CANONICAL_SHA256` in `tests/unit/test_bpmn_to_tasks.py` updated only after
      the above passes, and its tamper-check test goes green against the new bytes
      → Pin proven LIVE first: with new bytes and the OLD constant,
      `test_canonical_fixture_byte_guard` failed loudly (`assert 'bbfbc5ec…' ==
      '093858…'`). Constant then updated → `54 passed`. `bpmn_promote_e2e.bats`
      (the two-lane-joint consumer) 5/5 ok.
- [x] Corpus lint / geometry findings re-checked after the swap — a repair that
      moves a band edge would show up as changed lane_overflow, so confirm it does
      not (832 checked this their side; verify rather than inherit)
      → Checked the fixtures THEMSELVES, not the corpus. `fw corpus lint` scans the
      7-map store, which does not contain these files — reporting its unchanged
      4-finding baseline as coverage would have been a vacuous pass of exactly the
      class this arc keeps finding. `corpus_lint.py` takes `.bpmn` targets, so both
      byte-sets were linted directly, `--summary` so CLEAN is printed rather than
      inferred from silence:
      | bytes | inception-gonogo | two-lane-joint |
      |-------|------------------|----------------|
      | OLD (pre-repair) | `lane-geometry[hum_1_inception, agt_1_request]` | `lane-geometry[hum_1_inception, agt_0_request]` |
      | NEW (T-314) | clean | clean |
      Stronger than the AC asked for: the repair does not merely avoid moving a band
      edge, it CLEARS a real finding that our own rule — built independently, in a
      different week — raises against the old bytes. Independent cross-toolchain
      corroboration of T-314.
- [x] Digests reported back to 832 on the rail — they are explicitly holding T-314
      open pending independent confirmation
      → Rail 354.

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

## Outcome

Re-pinned. Both fixtures now carry 832's T-314 laneSet-order repair, verified
independently before landing.

**What unblocked it.** The previous outcome (re-pin BLOCKED) was correct on its
measurements and wrong on one inference. `designer-v0.8.0` does carry the pre-repair
bytes — that held up. But I concluded from it that the repair was unpublished, and
"absent from the newest tag" is not "not published". 832 (rail 353) pointed at
`e133cf9`, an ancestor of `origin/master`, which had been pullable the whole time.
The ref I needed existed; I had searched only the shape of ref I happened to try.

**Provenance, deliberately not from a transfer.** Bytes came from the PUBLIC mirror
`github.com/DimitriGeelen/workflow-designer` — never 832's working tree (T-559), and
never the file-transfer channel, which OBS-108 makes unable to deliver anything past
the first-ever transfer while still printing "SHA-256 verified" and exiting 0. Both
sides have now adopted refs-only for seam bytes until OBS-108 closes.

**The repair is better than "safe".** Linting the fixture bytes directly through our
own lane rules: the OLD bytes raise `lane-geometry` on BOTH files; the repaired bytes
are clean. Our rule was built independently, in a different week, looking for
something else — so this is cross-toolchain corroboration of T-314, not an inherited
claim.

**Near-miss worth keeping.** The first instinct for that last check was to run
`fw corpus lint` and cite its unchanged 4-finding baseline. That baseline covers the
7-map store, which does not contain these fixtures — unchanged findings about seven
files that never changed, offered as assurance about two files that did. True
statement, false assurance, would have passed review. Same class as T-2701
(reachability ≠ completeness) and 832's "could not evaluate ≠ evaluated clean".
Corrected by targeting the actual bytes and using `--summary` so CLEAN is printed
rather than inferred from an absence of output (T-2695).

**Also corrected.** The prior revision of this file put an `##`-level OUTCOME heading
*inside* `## Acceptance Criteria`, which terminated the AC block for the G-020 parser
— the gate then correctly refused edits under this task for having no ACs. The gate
was right; the task file was malformed. Fixed by demoting the narrative out of the
AC section.

## Verification

python3 -m pytest tests/unit/test_bpmn_to_tasks.py -q
bats tests/unit/bpmn_promote_e2e.bats
test "$(sha256sum tests/fixtures/bpmn/inception-gonogo-canonical.bpmn | cut -d' ' -f1)" = "bbfbc5ec48356c3a643efa21e37912994a3fff56532b7e0ef4815f91fbed00ab"
test "$(sha256sum tests/fixtures/bpmn/two-lane-joint.bpmn | cut -d' ' -f1)" = "2ba55eedbd90ae7805fa9ad3c8a7037913b4788dfc8c7db2ae9f3953d6d7bf7f"
out=$(python3 tools/corpus_lint.py --summary tests/fixtures/bpmn/inception-gonogo-canonical.bpmn tests/fixtures/bpmn/two-lane-joint.bpmn 2>&1); echo "$out" | grep -q "CLEAN"

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

### 2026-07-31T11:26:21Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2706-re-pin-832-shared-bpmn-fixtures-to-t-314.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-15a7318b
- **Timestamp:** 2026-07-31T11:48:02Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-07-31T11:47:54Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
