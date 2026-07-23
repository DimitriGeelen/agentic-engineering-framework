---
id: T-2615
name: "re-pin designer 0.3.2 (T-240 uuid auto-resolve hotfix) — flag flip + alias drop + e2e"
description: >
  re-pin designer 0.3.2 (T-240 uuid auto-resolve hotfix) — flag flip + alias drop + e2e

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
created: 2026-07-23T07:55:16Z
last_update: 2026-07-23T07:55:16Z
date_finished: null
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

# T-2615: re-pin designer 0.3.2 (T-240 uuid auto-resolve hotfix) — flag flip + alias drop + e2e

## Context

832 cut 0.3.2 — the T-240 hotfix (uuid workflowRef auto-resolve at load) requested in
T-2612's rail-168 escalation, plus T-242. Announced rail 171 with the agreed flow:
sha-confirm → re-pin → flip resolves_workflow_ref → e2e → drop the compat aliases.
Delivered via file_send (announced sha 983e0e30…d38a, 866701 bytes, tag
designer-v0.3.2). This task runs the full T-2611-pattern re-pin cycle PLUS the
T-2612 unwind: emit must become pin-flag-conditional (alias only while the pinned
editor can't resolve uuids), corpus regenerated back to uuid-only form, e2e must
prove auto-resolve on a uuid-ONLY link (the case 0.3.1 failed).

## Acceptance Criteria

### Agent
- [x] Delivered artifact received and INDEPENDENTLY verified: sha256
      983e0e304a3dc12e41ed9ea7270ba6edd032453c72c9ee423f466aa9d9e8d38a, 866701
      bytes — exact match to the rail-171 release pin; T-240 marker
      ("auto-resolved from workflow ref") present on delivered bytes, 0.3.1
      markers retained (_loadSrcKey x5, EVENT_KIND_TYPE x2); match confirmed to
      832 at rail offset 172 BEFORE sync (T-559/T-2611 flow).

**SESSION-BOUNDARY RESUME STATE (budget gate fired mid-flight, 2026-07-23):**
- DONE: file received + sha-verified; rail 172 = pre-sync confirm posted.
- Artifact at (session scratchpad, may not survive):
  `/tmp/claude-0/-opt-999-Agentic-Engineering-Framework/127bca7a-7a5a-4195-b80f-bbc9cea4c5a4/scratchpad/aef-workflow-designer-0.3.2.html`
  If gone: re-receive via `termlink file_receive` target "aef"
  (transfer xfer-mcp-888946-1784792300564-0) and re-verify sha.
- NEXT (in order): (1) pin bump in policy/designer-pin.yaml → version 0.3.2, sha
  983e0e30…d38a, bytes 866701, tag designer-v0.3.2, vendored_path
  vendor/designer/aef-workflow-designer-0.3.2.html, content-note (T-240+T-242
  surgical hotfix), flip `resolves_workflow_ref: true`; (2) `fw designer sync
  --from <artifact>` → doctor → served-bytes sha check; (3) make emit_map alias
  CONDITIONAL on the pin flag (tools/corpus_spec.py — alias currently
  unconditional; add pin read + unit tests both ways); (4) regenerate the 4
  handoff maps uuid-only as new versions (task-lifecycle, dispatch-loop,
  inception-flow — NOTE inception-flow latest is v3 w/ restored subProcess);
  (5) Playwright e2e per 832's rail-171 suggestion: uuid-ONLY jump + dual-form
  jump, both bind via uuid w/ "auto-resolved" marker; (6) lint baseline + suites;
  (7) verdict to 832 on the rail; (8) then finish T-2613 (audit-cron agt_6_warn
  wiring — separate task, still active).
- [ ] Pin bumped to 0.3.2 (sha/bytes/tag/vendored_path/content-note) with
      `resolves_workflow_ref: true`; `fw designer sync` clean; doctor OK; served
      bytes sha-identical to the pin.
- [ ] emit_map made capability-conditional: targetWorkflow compat alias emitted
      ONLY while the pin lacks resolves_workflow_ref (pinned both ways in unit
      tests); corpus maps with handoffs regenerated back to uuid-only form as new
      versions, uuids preserved.
- [ ] T-240 proven on served bytes: a uuid-ONLY link (no targetWorkflow attr —
      exactly the 0.3.1-dead case) auto-resolves in the editor: target shows the
      map name, jump enabled, jump completes (Playwright, operator path).
- [ ] Corpus lint at pinned baseline; editor-unbindable dormant under the flipped
      flag; suites green.

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

### 2026-07-23T07:55:16Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2615-re-pin-designer-032-t-240-uuid-auto-reso.md
- **Context:** Initial task creation
