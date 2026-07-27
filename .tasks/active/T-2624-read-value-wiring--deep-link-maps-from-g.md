---
id: T-2624
name: "Read-value wiring — deep-link maps from gate messages and review pages"
description: >
  DOCS READ-VALUE goal (T-2619 slice): make the existing maps get read where work
  happens, independent of the authority decision. Wire deep links (designer/app?load=...
  with node focus) into: (a) task-lifecycle gate refusal messages (completion gate
  P-010/P-011 stderr points at the map node being enforced), (b) Watchtower /review
  and /inception pages (link the workflow map for the task's current state), (c) relevant
  CLAUDE.md sections reference map uids. Cheap, reversible, serves option-3 value
  even under NO-GO on operationalisation.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [designer, corpus, t2619-slice]
components: []
related_tasks: [T-2619]
arc_id: designer-corpus
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
# demo_target: true               # T-2286: optional — marks task as reserved for an orchestrated demo
#                                 # worker (e.g. arc-010 HM-A dispatches via mcp__fw__work_on). When set,
#                                 # `fw work-on T-XXX` refuses unless --i-am-demo-orchestrator (CLI) or
#                                 # FW_I_AM_DEMO_ORCHESTRATOR=1 (env) is passed. Prevents the parent
#                                 # session from consuming the captured→started-work transition the demo
#                                 # worker expects to drive. Origin OBS-057.
created: 2026-07-25T16:47:07Z
last_update: 2026-07-27T16:51:38Z
date_finished: 2026-07-27T16:51:38Z
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
  - ts: '2026-07-25T17:00:05Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-25T17:00:08Z'
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

# T-2624: Read-value wiring — deep-link maps from gate messages and review pages

## Context

READ-VALUE slice of the T-2619 GO cascade: the corpus maps only pay rent if they get read where work happens. Three cheap wiring legs — (a) completion-gate refusal stderr names the enforcing map node + `fw corpus explain` (audience: agents, per T-2143 audience axis), (b) Watchtower /review + /inception pages link the task-lifecycle map at server-latest (audience: operator), (c) CLAUDE.md §Task Lifecycle points at the map + carrier uids. See docs/reports/T-2619-designer-authority-model.md (option-3 read-value).

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Completion-gate refusal stderr (P-010 unchecked-AC path in update-task.sh) includes a map pointer line naming the enforcing carrier node (tl_archive) and the `fw corpus explain aef-task-lifecycle` read command — live-fired 2026-07-27 against this task's own unchecked ACs
- [x] Watchtower /review/<id> page renders a "workflow map" link that opens the designer at the server-latest aef-task-lifecycle version (no hardcoded version number in the template) — required an additive /api/version change: bare `?id=` now resolves latest (mirrors /api/thumb); live-verified byte-identical to v5
- [x] Watchtower /inception/<id> page renders the same map link (inception board process context) — live-verified on /inception/T-2620, hx-boost off per landing-card rule
- [x] CLAUDE.md Task Lifecycle section references the map id + carrier uids and the `fw corpus explain` command
- [x] Gate stderr wording self-eval (T-2143 agent-audience): one line, appended after the Options block so the unchecked-AC listing stays primary; names the exact runnable command; suppressed on consumers without the corpus (meta.json guard)

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

- [ ] [REVIEW] Map links sit right on the review and inception pages (placement, wording, no layout disruption)
  **Steps:**
  1. Open http://192.168.10.107:3001/review/T-2623 — check the header meta row: "workflow map" link next to Owner
  2. Open http://192.168.10.107:3001/inception/T-2620 — check the small "workflow map" link under the page title
  3. Click either link — the designer should open showing the task-lifecycle map at its latest saved version
  **Expected:** links read naturally in context, don't crowd the header, and land you on the current aef-task-lifecycle map in the editor
  **If not:** note which page and what feels off (placement / wording / target); the link markup is one line in each template (review.html, inception_detail.html)

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
python3 -m pytest tests/web/test_api_version_latest.py -q
curl -s "$(bin/fw watchtower url)/api/version?id=aef-task-lifecycle" -o /tmp/.t2624-v.xml && grep -q "aef:workflowMeta" /tmp/.t2624-v.xml
curl -s "$(bin/fw watchtower url)/review/T-2623" -o /tmp/.t2624-r.html && grep -q "workflow map" /tmp/.t2624-r.html
curl -s "$(bin/fw watchtower url)/inception/T-2620" -o /tmp/.t2624-i.html && grep -q "workflow map" /tmp/.t2624-i.html
grep -q "corpus explain aef-task-lifecycle" agents/task-create/update-task.sh
grep -q "tl_human_review" CLAUDE.md

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

### 2026-07-27 — /api/version had no latest-resolution

- **What changed:** the task description assumed deep links could target "latest" — but `/api/version` required an explicit `v=` (only `/api/thumb` had missing-v resolution). A hardcoded version in the templates would go stale on every map save.
- **Plan impact:** one additive API change joined the slice: bare `?id=` on `/api/version` now resolves latest, mirroring `/api/thumb`. Explicit-v/invalid-v behavior unchanged (832 client always passes v; T-2530 mimetype contract untouched). Pinned by tests/web/test_api_version_latest.py (4 tests).
- **Triggered:** FYI to 832 on the rail (additive server-side change on a contract-adjacent route) — no task; note rides the next rail post.

### 2026-07-27 — node-focus deep link dropped from scope

- **What changed:** the filing text said "designer/app?load=... with node focus"; the 0.6.0 bundle has no node-focus query param and inventing one is 832's seam, not ours.
- **Plan impact:** links open the map at latest; per-node focus routes through the T-2620 overlay contract (aef:annotate) when 832's T-250 ratifies — not through URL params.
- **Triggered:** nothing filed; covered by T-2620 Slice B.

## Recommendation

**Recommendation:** GO

**Rationale:** All three read-value legs are live and verified end-to-end; the single [REVIEW] AC is a placement/wording taste check on two one-line template additions — trivially reversible if either link feels wrong.

**Evidence:**
- Gate stderr live-fired (P-010 refusal on this task's own unchecked ACs printed the map line, consumer-guarded)
- /review/T-2623 and /inception/T-2620 both render the "workflow map" link on the live server; link target verified byte-identical to v5
- /api/version bare-id latest resolution pinned by tests/web/test_api_version_latest.py (4/4) with explicit-v/invalid-v regression coverage
- CLAUDE.md §Task Lifecycle carries the map pointer + carrier uids

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

### 2026-07-25T16:47:07Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2624-read-value-wiring--deep-link-maps-from-g.md
- **Context:** Initial task creation

### 2026-07-27T16:44:45Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-7088bbfd
- **Timestamp:** 2026-07-27T16:51:41Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-07-27T16:51:38Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
