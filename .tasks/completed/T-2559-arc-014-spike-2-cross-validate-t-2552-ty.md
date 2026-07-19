---
id: T-2559
name: "arc-014 Spike-2: cross-validate T-2552 typed-event + gateway detectors against 832's real fixtures (typed-events, boundary-events)"
description: >
  arc-014 Spike-2: cross-validate T-2552 typed-event + gateway detectors against 832's real fixtures (typed-events, boundary-events)

status: work-completed
workflow_type: test
owner: agent
horizon: null
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
created: 2026-07-19T20:37:17Z
last_update: 2026-07-19T20:45:01Z
date_finished: 2026-07-19T20:45:01Z
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
---

# T-2559: arc-014 Spike-2: cross-validate T-2552 typed-event + gateway detectors against 832's real fixtures (typed-events, boundary-events)

## Context

832 delivered both T-204 round-trip fixtures rail-inline (offsets 88/89, base64 + SHA256 pins, 832 master 2bff553): `typed-events.bpmn` (three intermediate catch events, kind rides `aef:eventDef`, IW-1 no native `bpmn:*EventDefinition`) and `boundary-events.bpmn` (host serviceTask + two native `bpmn:boundaryEvent attachedToRef=` carrying `aef:eventDef` + `aef:boundaryPos`, interrupting + non-interrupting). This is arc-014 Spike-2: byte-exact cross-validation of the T-2552 Pass-3 typed-event WARN detector against the peer's REAL fixtures (L-501), and the direct test of my offset-85 claim that the detector iterates ALL nodes (so boundaryEvent should fire too). Verdict relayed to 832 over the rail.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Both fixtures decoded from the rail payloads verify byte-exact against 832's pinned SHA256 (typed-events: 5467071b…ca5ff, 4556 bytes; boundary-events: 37eec1b0…06f1a, 5509 bytes) and are pinned into `tests/fixtures/aef-bpmn/` (mirrors 832's path) unmodified
- [x] `fw bpmn compile` on typed-events.bpmn exits 0 and emits exactly 3 Pass-3 typed-event WARNs (ev_err error/status:issues, ev_tmr timer/cron, ev_msg message/bus:designer-events) — no silent drop
- [x] `fw bpmn compile` on boundary-events.bpmn exits 0; the offset-85 claim (detector iterates ALL nodes) is tested against both boundaryEvent nodes and the actual result — BOTH FIRE, claim holds; recorded in the compile log report and in regression tests; the one honest limit (attachment semantics absent from WARN text) filed as T-2560
- [x] Regression tests pinning both fixtures' detector behavior added to tests/unit/test_bpmn_to_tasks.py; full suite green (40/40)
- [x] Verdict (including the T-2560 WARN-completeness limit flagged as WARN-first buffer case per 832's offset-89 note) relayed to 832 on the rail (offset 90) and the report `docs/reports/T-2559-spike2-fixture-cross-validation.md` captures verbatim compile output

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

test "$(sha256sum tests/fixtures/aef-bpmn/typed-events.bpmn | cut -d' ' -f1)" = "5467071b3a3909629b224ed6357abb5fc8a57c12e18e402106307dd91d2ca5ff"
test "$(sha256sum tests/fixtures/aef-bpmn/boundary-events.bpmn | cut -d' ' -f1)" = "37eec1b0f10ad02aa5622e28e0e9977ae8bfa9308f59fd36d91048da6d106f1a"
out=$(bin/fw bpmn compile tests/fixtures/aef-bpmn/typed-events.bpmn 2>&1); test "$(echo "$out" | grep -c "typed-event annotation")" = "3"
out=$(bin/fw bpmn compile tests/fixtures/aef-bpmn/boundary-events.bpmn 2>&1); test "$(echo "$out" | grep -c "typed-event annotation")" = "2" && echo "$out" | grep -q "bnd_err" && echo "$out" | grep -q "bnd_tmr"
python3 -m pytest tests/unit/test_bpmn_to_tasks.py -q > /tmp/.t2559-pytest.out 2>&1 && grep -q "40 passed" /tmp/.t2559-pytest.out
test -f docs/reports/T-2559-spike2-fixture-cross-validation.md

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

### 2026-07-19 — offset-85 claim proven, one WARN-completeness limit surfaced

- **What changed:** 832's boundary-events.bpmn was designed as the counter-example that would disprove my claim that the T-2552 detector iterates all nodes. It did not — both boundaryEvent variants fire. What Spike-2 DID surface is that the WARN text is kind+binding only: boundary attachment semantics (attachedToRef, cancelActivity interrupting flag, boundaryPos) drop without mention, so a WARN reader can't distinguish an interrupting boundary from a free-standing intermediate event.
- **Plan impact:** T-2551's "no live consumer for error/message" NO-GO evidence is unchanged; the detection substrate is now cross-validated against the peer's real encoding, so any future consumption slice starts from a byte-exact pinned contract instead of a synthetic fixture.
- **Triggered:** T-2560 (extend Pass-3 WARN with attachment context for boundary carriers; captured/later, arc-014 accumulator).

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

### 2026-07-19T20:37:17Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2559-arc-014-spike-2-cross-validate-t-2552-ty.md
- **Context:** Initial task creation

### 2026-07-19T20:38:03Z — status-update [task-update-agent]
- **Change:** tags: +arc:designer-corpus

## Reviewer Verdict (v1.5)

- **Scan ID:** R-61ab3cc8
- **Timestamp:** 2026-07-19T20:45:04Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** yes
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 4
     - evidence: `out=$(bin/fw bpmn compile tests/fixtures/aef-bpmn/boundary-events.bpmn 2>&1); test "$(echo "$out" | grep -c "typed-event annotation")" = "2" && echo "$out" | grep -q "bnd_err" && echo "$out" | grep -q`

- **Layer-1 escalations:** 1
  1. **cross-project-blast** (medium) — Cross-project or cross-repo change
     - matched: `ALL nodes`

### 2026-07-19T20:45:01Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
