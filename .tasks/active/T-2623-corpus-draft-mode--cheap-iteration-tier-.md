---
id: T-2623
name: "Corpus draft mode — cheap iteration tier for sketch maps"
description: >
  ITERATE goal (T-2619 slice): each map version currently costs a full task + e2e
  ceremony (v3->v4 of task-lifecycle was a session). Add a draft tier: registry draft
  flag per project/version, lint runs advisory-only on drafts (excluded from the 2-finding
  steady baseline), prove/e2e required only at promotion draft->ratified. Lets operator
  or agent sketch a workflow in /designer without the contract-grade ceremony, then
  graduate it. Build only after T-2619 GO.

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
created: 2026-07-25T16:46:22Z
last_update: 2026-07-26T20:51:50Z
date_finished: 2026-07-26T20:51:50Z
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
  - ts: '2026-07-26T17:00:05Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 7
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=7 
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
  - ts: '2026-07-26T17:00:08Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=2 
      (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2623: Corpus draft mode — cheap iteration tier for sketch maps

## Context

**Operator endorsed 2026-07-25 (T-2619 dialogue round 3):** *"makes sense, we can also jointly iterate it and test it before releasing it fully in production."* Draft mode is the joint iteration + testing surface: agent and operator sketch/refine a workflow as DRAFT, exercise it together, and only promotion to production (ratified corpus) pays the full ceremony — uuid audit, lint clean, suites, e2e, operator sign-off as Human AC. Drafts are excluded from the retrieval index and lint baseline, badged DRAFT in the gallery, and never treated as authority (cascading-detail rules from T-2622 apply only to ratified maps). Stale drafts (~30 days untouched) surface as audit INFO. See docs/reports/T-2619-designer-authority-model.md Dialogue Log.

**Session-start triggers (operator question 2026-07-25: "how can I trigger starting a drafting session together with agent?"):** three entry points, all converging on the same ritual:
1. **Chat**: operator says "let's draft <topic>" → agent runs the ritual (task, registry entry status:draft, skeleton seed, deep-link back).
2. **CLI**: `fw designer draft new <name>` → creates draft registry entry + empty/seeded map + prints editor deep-link (+ ntfy push of the URL).
3. **Watchtower**: "New draft" button in /designer gallery → same as CLI, opens editor directly.
The ritual (pair-draft loop, proven in arc-014 D1-D5): agent seeds skeleton from dialogue → operator edits visually in /designer/app → agent re-reads saved version (fw corpus derive/parse), critiques/normalizes, writes next version → repeat until settled → promotion ceremony. Versions v1..vN in .context/designer/projects/<name>/ are the shared medium; operator holds the pen in the UI, agent holds the pen in the spec.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Draft convention settled and documented: map id prefix `draft-` marks a draft (no registry to drift); documented in designer.sh, corpus_lint, corpus_explain docstrings/comments
- [x] `fw designer draft new <name>` live-verified: created draft-smoke-test (seeded 3-node/2-flow skeleton via /api/save), printed deep-link, ntfy best-effort; duplicate refused with the existing deep-link; refuses when Watchtower is down
- [x] Draft exclusions live: lint skips `draft-*` (scanned 9→8 maps, baseline unchanged at 2 findings); `fw search` corpus section skips drafts (verified: "threshold" no longer surfaces draft-trigger-handling); `fw corpus explain draft-trigger-handling` renders "DRAFT — not authority at any stage" provenance
- [x] Stale-draft audit leg shipped (check_stale_drafts in audit.sh structure section, INFO at 30d+ via meta.json updated ts)
- [x] Gallery live-verified after restart: DRAFT badge markup renders for draft maps (dashed card + badge), "New draft" form POSTs to /designer/draft/new (CSRF-tokened) → 302 into editor at seeded v1 (draft-post-smoke round-trip confirmed, then cleaned up)
- [x] Tests (test_corpus_explain.py 9 passed): search excludes drafts; explain DRAFT footer; lint collect_targets skips drafts but lints one explicitly targeted; duplicate-refusal covered live above

### Human
- [ ] [REVIEW] Gallery DRAFT badge + "New draft" affordance read cleanly in the live gallery
  **Steps:**
  1. Open http://192.168.10.107:3001/designer in a browser
  2. Locate draft-trigger-handling — verify the DRAFT badge is visible and unambiguous
  3. Click "New draft", enter a throwaway name, verify the editor opens on a seeded skeleton; delete the throwaway via the gallery if desired
  **Expected:** Badge clearly separates drafts from ratified maps; New draft lands you in the editor without manual URL work
  **If not:** Note what reads wrong; the badge/button styling iterates in the next round

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

out=$(python3 -m pytest tests/unit/test_corpus_explain.py -q 2>&1); echo "$out" | grep -q "9 passed"
out=$(python3 tools/corpus_lint.py 2>&1); echo "$out" | grep -q "^2 finding"
out=$(python3 tools/corpus_lint.py 2>&1); echo "$out" | grep -q "scanned 8 map"
out=$(bin/fw corpus explain draft-trigger-handling 2>&1); echo "$out" | grep -q "DRAFT — not authority"
out=$(python3 tools/corpus_explain.py --search "threshold" 2>&1); test -z "$out"
curl -s "$(bin/fw watchtower url)/designer" -o /tmp/.t2623-gallery.html && grep -q "draft-badge" /tmp/.t2623-gallery.html
grep -q "New draft" /tmp/.t2623-gallery.html

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

### 2026-07-26 — registry dissolved into a naming convention
- **What changed:** Filing assumed a draft *registry* ("registry entry status:draft"). Building revealed the id prefix `draft-` gives the same partition with zero registry to drift — every surface (lint, search, explain, gallery, audit) tests one string prefix. The T-2622 retrieval seam shipping first made this urgent: search was surfacing drafts unbadged for a few hours.
- **Plan impact:** No registry file; promotion = re-author under a production id (new uuid — acceptable since prod maps must never reference draft uuids anyway). Promotion ceremony itself is deliberately NOT built here — it's the settled-draft moment's work, and draft-trigger-handling will be its first live case.
- **Triggered:** CSRF form-token requirement discovered on the gallery POST (403 → `_csrf_token` hidden field per T-1343 idiom).

## Recommendation

**Recommendation:** GO — approve the gallery draft UI as shipped.

**Rationale:** All six agent ACs verified live: the pair-draft ritual now has all three endorsed entry points (chat worked already; `fw designer draft new` and the gallery button shipped here), drafts are structurally partitioned from ratified corpus on every surface (lint 8-map scan/2-finding baseline unchanged, search excludes, explain shows DRAFT provenance, audit nudges stale drafts at 30d as INFO), and the create→edit round-trip was proven end-to-end (POST → 302 → editor on seeded v1, then cleaned up). The only open judgment is visual: whether the DRAFT badge + New draft form read cleanly in the gallery — that's the single [REVIEW] Human AC.

**Evidence:**
- `fw designer draft new "smoke test"` → created + deep-link; duplicate refused with link; drafts deleted after test
- lint: `scanned 8 map(s)` / `2 finding(s)` (draft excluded, baseline intact)
- `fw corpus explain draft-trigger-handling` → "DRAFT — not authority at any stage"
- gallery live at /designer: dashed card + DRAFT badge on draft-trigger-handling, New draft form (CSRF-tokened) → 302 into editor
- tests/unit/test_corpus_explain.py: 9 passed

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

### 2026-07-25T16:46:22Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2623-corpus-draft-mode--cheap-iteration-tier-.md
- **Context:** Initial task creation

### 2026-07-26T20:42:24Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-4cf536fa
- **Timestamp:** 2026-07-26T20:51:53Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-07-26T20:51:50Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
