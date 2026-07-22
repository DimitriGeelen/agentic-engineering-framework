---
id: T-2611
name: "re-pin designer 0.3.1 (T-234 jump-autosave root fix + T-237 eventDef classification
  + T-204 vocab)"
description: >
  832 released 0.3.1 (tag designer-v0.3.1, release 1a1f38e; rail 162/164). Artifact
  via file_send xfer-mcp-3359980-1784750781760-1 (862852 bytes, sha256 d99a42da).
  Mirror T-2546/T-2526 flow: receive, sha-verify, confirm on rail BEFORE sync, pin
  bump, fw designer sync, doctor, LIVE e2e incl T-234 jump-autosave repro and T-237
  typed-catch rendering. Nonce decision: recommend KEEP server 302 nonce-mint.

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
created: 2026-07-22T20:10:49Z
last_update: 2026-07-22T20:21:08Z
date_finished: 2026-07-22T20:21:08Z
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
  - ts: '2026-07-22T20:15:05Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-22T20:15:08Z'
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

# T-2611: re-pin designer 0.3.1 (T-234 jump-autosave root fix + T-237 eventDef classification + T-204 vocab)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] 0.3.1 artifact delivered clean: `file_receive` reassembles + integrity-passes (xfer-mcp-3359980-1784750781760-1); landed file sha256 == pin (`d99a42da304fc9377e580a1e34e54467431727058026ded7a8ee85fd464fd05c`), bytes == 862852 — verified independently via sha256sum; in-bundle markers `_loadSrcKey` ×4 (T-234) + `EVENT_KIND_TYPE` ×2 (T-204) on delivered bytes
- [x] sha256 match confirmed back to 832 on the rail BEFORE `fw designer sync` (rail offset 165; T-2546 offset-64 commitment pattern)
- [x] `policy/designer-pin.yaml` bumped to 0.3.1 (version, sha256, bytes, vendored_path, source_artifact, source_tag; 0.3.1 content note added)
- [x] `fw designer sync --from <delivered>` installed read-only to `vendor/designer/aef-workflow-designer-0.3.1.html`; `fw designer status` reports PRESENT ✓ (sha256 matches pin); `fw doctor`: `OK designer vendored build matches pin (d99a42da304f...)`
- [x] LIVE e2e — bundle: `/designer/app` serves the 0.3.1 bytes (served sha256sum == pin, 862852 bytes); `EVENT_KIND_TYPE` present in served bytes; 0.3.1 UI surface visible in browser (Typed events palette Error/Timer/Message, "🔗 Pending refs…" button)
- [x] LIVE e2e — T-234 jump-autosave repro (Playwright, served bundle): loaded aef-task-lifecycle via ?load deep-link (nonce URL captured) → bound + jumped via "↗ Open target workflow" to aef-dispatch-loop (in-place, URL unchanged — the hazard state) → revisited the SAME nonce URL → **renders task-lifecycle** (0.3.0 restored the jumped-to map here). T-237: `agt_msg_result` classifies as `eventMessage` (Bus topic bus:task-channel, boundary/interrupting fields), NO jump affordance — 0.3.0 showed linkEventCatch + inert "Open target workflow"
- [x] Nonce decision recorded in `## Decisions`: server-side 302 nonce-mint KEPT as defense-in-depth — operator may override

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

out=$(bin/fw designer status 2>&1); echo "$out" | grep -q "PRESENT ✓ (sha256 matches pin)"
test "$(sha256sum vendor/designer/aef-workflow-designer-0.3.1.html | cut -d' ' -f1)" = "d99a42da304fc9377e580a1e34e54467431727058026ded7a8ee85fd464fd05c"
test "$(curl -s "$(bin/fw watchtower url)/designer/app" | sha256sum | cut -d' ' -f1)" = "d99a42da304fc9377e580a1e34e54467431727058026ded7a8ee85fd464fd05c"

## RCA

**Symptom:** two operator-facing defect classes on the pinned 0.3.0 bundle: (1) revisiting
a designer deep-link after an in-editor handoff jump rendered the WRONG map (T-2596,
recurred 4×); (2) `agt_msg_result` (typed message catch) rendered as an incoming
handoff with an inert jump affordance (T-2600 RCA → 832 T-237).

**Root cause:** (1) 832-side — post-jump B1 autosaves stamped the entry URL's src, so
same-src restore adopted the jumped-to map (fixed by T-234 `_loadSrcKey`). (2) NOT a
live 832-master defect but a **release-lineage gap**: 0.3.0 was cut 2026-07-18, one day
before the T-204 typed-event vocabulary landed — the pinned bundle had no `eventDef`
support at all, so every catch classified as linkEventCatch.

**Why structurally allowed:** the pin freezes a point-in-time artifact; nothing tied
"vocabulary the corpus uses" to "vocabulary the pinned bundle understands". The corpus
adopted `aef:eventDef` (T-2551/T-2552 era) while the pin predated it.

**Prevention:** (1) re-pin e2e now includes marker checks on the DELIVERED bytes
(`_loadSrcKey`, `EVENT_KIND_TYPE`) before sync — a lineage gap of this class fails the
re-pin instead of surfacing as a rendering bug weeks later; (2) the T-2599 server nonce
stays as defense-in-depth for the restore class (Decisions); (3) 832 backfilled the
missing designer-v0.3.0 tag, closing their protocol drift (a tag per release).

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

### 2026-07-22 — server-side nonce-mint: KEEP after T-234 root fix

- **Chose:** keep the T-2599 server-side 302 nonce-mint on `/designer/app?load=` even
  though 0.3.1's T-234 fix closes the wrong-map-restore class at the root.
- **Why:** defense-in-depth at near-zero cost. Browser history, bookmarks, and cached
  pages replay nonce-less URLs forever; the nonce is invisible when T-234 works and
  load-bearing if any future bundle regression recurs (this class hit the operator
  4 times before the root fix). The e2e above deliberately exercised the SAME-nonce
  revisit — the one path only T-234 protects — and it held.
- **Rejected:** dropping the nonce (832's offer at release, rail 162). Revisit only
  if the nonce itself ever causes a defect.

### 2026-07-22 — observation for 832 (not a blocker): uuid workflowRef does not auto-resolve target on deep-link load

- On a ?load deep-linked map, a throw handoff carrying contract-v0 `workflowRef`
  uuid (+ name) shows "Target workflow — none —" and a disabled jump button until
  the target is bound via "📂 Choose from project…" or a typed id. Legacy slug refs
  bound directly. Whole corpus is uuid-form now (post T-2605/T-2609 recreates), so
  jump requires one extra picker step per session. Reported to 832 as UX observation
  with repro; their call whether uuid→project auto-resolution via /api/list belongs
  in a future release. Also noted: /api/thumb 404s for server-side-regenerated maps
  (no client-generated thumbnail) — picker shows ▦ placeholder, cosmetic.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-07-22T20:10:49Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2611-re-pin-designer-031-t-234-jump-autosave-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-67b5eb8a
- **Timestamp:** 2026-07-22T20:21:10Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#3 (Agent)** — `policy/designer-pin.yaml` bumped to 0.3.1 (version, sha256, bytes, vendored_path, source_artifact, source_tag; 0.3.1 content note added)
  - **AC-verify-mismatch** (narrow, heuristic) — `path=policy/designer-pin.yaml in: `policy/designer-pin.yaml` bumped to 0.3.1 (version, sha256, bytes, vendored_path, source_artifact, source_tag; 0.3.1 content note added)`

### 2026-07-22T20:21:08Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
