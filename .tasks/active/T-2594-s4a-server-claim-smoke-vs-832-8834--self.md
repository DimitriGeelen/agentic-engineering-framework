---
id: T-2594
name: "S4a server-claim smoke vs 832 :8834 — self-minted ghost, fixture ghosts preserved"
description: >
  S4a server-claim smoke vs 832 :8834 — self-minted ghost, fixture ghosts preserved

status: started-work
workflow_type: test
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
created: 2026-07-21T22:53:59Z
last_update: '2026-07-21T23:00:08Z'
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
  - ts: '2026-07-21T23:00:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 1
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=1 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-21T23:00:08Z'
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

# T-2594: S4a server-claim smoke vs 832 :8834 — self-minted ghost, fixture ghosts preserved

## Context

832's S4a (server-side claim-on-save, rail offset 141) is LIVE on their :8834 twin: when a
saved map's OWN workflowMeta.uuid matches a pending ghost, gallery-serve records the claim and
drops the ghost; referrers resolve with zero diagram edit. 832 invited an immediate smoke but
suggested spending one of the 2 fixture ghosts preserved for the T-228 picker re-verify. This
task smokes the claim path WITHOUT consuming those fixtures: self-mint a fresh ghost G (save a
map referencing bogus uuid G), then save a second map whose own workflowMeta.uuid == G → claim
fires → G drops. All via the public /api/save on their served surface. Report at rail offset 142
together with our fixture-ghost call (hold both).

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Ghost-mint leg: map `claim-smoke-ref` saved with workflowRef=G (fresh v4) → /api/list ghosts[] contains G with referrer {id: claim-smoke-ref}
- [ ] Claim leg: map `claim-smoke-target` saved with own workflowMeta.uuid == G → G GONE from ghosts[], claim-smoke-target in maps[] with uuid G (claim + drop verified live) — **FAILED on served surface 3× (bare save, re-save, UI-shaped payload); blocked on 832 fix/redeploy, re-run on their ping**
- [ ] Idempotency: re-save of claim-smoke-target is a no-op (no ghost re-appears, no error) — **moot until claim leg passes**
- [x] Fixture preservation: ghosts 1f9b5f0c (aef-task-lifecycle) and adb0e0f2 (review-map) each still present with exactly their original single referrer, before AND after the smoke
- [x] Results + fixture-hold call posted to 832 on the DM rail (offset 142), quoting the live run

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

### 2026-07-21T22:53:59Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2594-s4a-server-claim-smoke-vs-832-8834--self.md
- **Context:** Initial task creation

## Updates

### 2026-07-22 — Smoke run complete: claim leg FAILS on served surface (real finding, reported offset 142)
- **Run:** G=502081ac-3869-479e-bccd-89552115b097 (self-minted v4; 832's 2 fixture ghosts untouched).
  Map A `claim-smoke-ref` (adapted s4-e2e-probe v1 bytes) → ghost G minted w/ 2 referrers + legacy
  store-mint 3ceaf02d + df0b8c59 resolved silent. PASS.
- **Claim leg:** Map B `claim-smoke-target` (adapted task-lifecycle v1; own workflowMeta.uuid=G)
  saved ok v1 → in maps[] with uuid G, but ghost G STILL in ghosts[]. No claim, no drop.
  H1 (drop on subsequent rescan): re-save v2 → persists. H3 (UI-shaped payload, png dataURL+note):
  v3 → persists. H2 (serving process predates S4a commit) untestable from here — project-boundary
  gate correctly blocked probing /opt/832-Workflow-designer; suspected cause (offset-137 class).
- **Sharpest evidence:** merged_ghosts() surfacing uuid G while G is a live map — violates the
  invariant 832 stated as fixed at offset 141. Unit-vs-served gap (their _gallery-claim-verify
  11/11 vs served FAIL) = their PL-046 blind-spot class.
- **Reported:** rail offset 142 with per-leg evidence, honest caveat (possible semantics delta if
  claim keys on picker-seeded marker), housekeeping (smoke artifacts = ready-made re-verify), and
  the fixture call: HOLDING 1f9b5f0c + adb0e0f2 for T-228 picker re-verify.
- **Status:** AC-2/AC-3 blocked on 832's fix/redeploy; re-run the claim leg (one re-save of
  claim-smoke-target) on their ping. Smoke artifacts re-pullable: scratchpad mapA.xml/mapB.xml,
  smoke-uuid.txt.

### 2026-07-22 — Adjacent evidence: T-229 mint-at-birth independently verified (no-save variant)
- Drove served :8834 designer.html: + button → born map workflowMeta =
  `id="workflow_1" uuid="23233f03-ec7f-41aa-bceb-c00ac1209b24"` (v4) read via View XML modal;
  rename to t229-independent-verify → uuid unchanged. Zero store writes (never saved).
- Confirms 832's offset-140 T-229 claim independently: mint fires at creation, rename-invariant.
  Contrast makes the S4a finding sharper — and resolves it: T-229 is EDITOR-side (static
  designer.html, re-read from docroot per request → live without process restart), the S4a claim
  is SERVER-side (gallery-serve.py, a running process → needs re-exec after the commit). If 832
  did not re-exec gallery-serve after landing S4a, T-229-live + claim-dead is exactly the expected
  signature. Static-vs-process deploy asymmetry — posted as addendum offset 143.
