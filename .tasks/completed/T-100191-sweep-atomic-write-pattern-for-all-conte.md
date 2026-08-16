---
id: T-100191
name: "Sweep: atomic-write pattern for all .context YAML writers (10+ non-atomic yaml.dump
  sites)"
description: >
  Corpus sweep follow-up to T-100190/T-2457/T-2456: convert remaining truncating YAML
  writes to same-dir temp + os.replace (or register a gap if a site is append-only
  safe)

status: work-completed
workflow_type: refactor
owner: agent
horizon:
tags: []
components: [agents/audit/orchestrator-mcp-scan.sh, 
      agents/context/check-tier0.sh, agents/context/inject-next-directive.py, 
      agents/context/lib/focus.sh, agents/termlink/bvp-estimator/estimator.py, 
      lib/arc.sh, lib/assumption.sh, lib/bus.sh, lib/bvp.sh, lib/config-file.sh, 
      lib/pending.sh, lib/pickup.sh, lib/promote.sh]
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
created: 2026-07-05T00:21:25Z
last_update: '2026-08-16T22:24:19Z'
date_finished: 2026-07-06T13:00:49Z
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
  - ts: '2026-07-05T00:30:01Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 3
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=3 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-05T00:30:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 3
      F-RECALL: 0
      F-ORCH: 0
      F-AUTONOMY: 0
      audit_severity: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=3 (body:portability-abstraction); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal); F-AUTONOMY=0 (no-signal); 
      audit_severity=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:19Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 3
      F-RECALL: 0
      F-AUTONOMY: 4
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=3 (body:portability-abstraction); F-RECALL=0 
      (no-signal); F-AUTONOMY=4 (body:auto-promote-class-eligibility); F3=0 
      (no-signal); F1=1 (body/components:context-fabric-incidental); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-100191: Sweep: atomic-write pattern for all .context YAML writers (10+ non-atomic yaml.dump sites)

## Context

Corpus sweep — follow-up to three fixed instances of the non-atomic-YAML-write class: T-2457 (fabric cards, L-493), T-2456 (fw note, L-492), T-100190 (audit metrics-history; a mid-dump kill truncated the file and the pre-push YAML gate blocked all pushes). Census 2026-07-05 — files with `yaml.dump`/`yaml.safe_dump` and ZERO temp+`os.replace` signals:

`lib/config-file.sh`, `lib/assumption.sh`, `lib/pickup.sh`, `lib/bus.sh`, `lib/arc.sh`, `lib/bvp.sh`, `lib/promote.sh`, `lib/pending.sh`, `agents/context/lib/focus.sh`, `agents/audit/orchestrator-mcp-scan.sh`. (`lib/reviewer/{static_scan,audit,overrides}.py` already atomic.)

Scope: for each site, classify (a) full-file rewrite of durable state → convert to same-dir temp + os.replace; (b) ephemeral/regenerable file → document why exempt. One commit per file or logical group; bats/pytest pin per converted writer where a harness exists. Consider a lint (grep-based bats) that fails on new truncating yaml.dump writers under lib/ and agents/.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Every census site classified (convert vs exempt-with-reason) in this task's Decisions
- [x] All convert-class sites write via same-dir temp + os.replace (or mv on the shell side)
- [x] Lint test pins the pattern corpus-wide (new truncating yaml.dump writers on durable .context state fail CI)

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

# All landings live on origin/master (worktree-off-origin/master flow); MAIN's
# branch lags, so verify against origin/master content (L-387-safe pattern).
git fetch origin -q
git show origin/master:tests/unit/atomic_yaml_write_lint.bats > /tmp/.t100191_lint && grep -q "atomic-write signal" /tmp/.t100191_lint
git show origin/master:lib/bvp.sh > /tmp/.t100191_bvp && grep -q "_atomic_write_text" /tmp/.t100191_bvp
git show origin/master:lib/arc.sh > /tmp/.t100191_arc && grep -q "os.replace(tmp_fn, fn)" /tmp/.t100191_arc
git show origin/master:agents/context/check-tier0.sh > /tmp/.t100191_t0 && grep -q "os.replace(tmp_path, log_file)" /tmp/.t100191_t0
git show origin/master:agents/termlink/bvp-estimator/estimator.py > /tmp/.t100191_est && grep -q "_atomic_write_text" /tmp/.t100191_est
git show origin/master:lib/config-file.sh > /tmp/.t100191_cfg && grep -q "os.replace(tmp_path, yaml_file)" /tmp/.t100191_cfg
git show origin/master:agents/context/lib/focus.sh > /tmp/.t100191_foc && grep -q "os.replace(tmp_path, focus_file)" /tmp/.t100191_foc

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

### 2026-07-05 — census classification (convert vs exempt)

- **Chose:** convert ALL file-writing YAML dump sites — including new-file
  creates (bus/pickup envelopes, tier0 approval files) — leaving only two
  exempt files: `lib/integrate.py` (string-only dumps; the merge driver
  writes via git plumbing) and `agents/docgen/test_docgen.py` (test fixture).
- **Why:** new-file creates are read by pollers/consumers (bus manifest,
  pickup inbox cron, fw tier0 approve, Watchtower) that can observe a
  half-written file; temp+os.replace makes creation atomic too, and an empty
  exempt class makes the lint story trivial to reason about.
- **Rejected:** exempting new-file creates as "no durable state destroyed" —
  true but leaves the half-read window open for ~zero conversion savings.

**Converted (16 files; original census 10 + 4 census misses + 2 envelope creates):**

| File | Sites | State written |
|------|-------|---------------|
| lib/config-file.sh | 1 | .framework.yaml (config set) |
| lib/assumption.sh | 2 | assumptions.yaml add/update |
| lib/pending.sh | 2 | pending register/resolve |
| lib/promote.sh | 1 | practices.yaml |
| lib/arc.sh | 3 | arc YAML approve/remove/set-weight (ruamel+pyyaml dual path) |
| lib/bvp.sh | 5 | score history, value-drivers policy ×2, task frontmatter, auto-promote log (shared `_atomic_write_text` helper) |
| lib/bus.sh | 1 | result envelope (atomic create) |
| lib/pickup.sh | 1 | pickup envelope (atomic create) |
| agents/context/lib/focus.sh | 1 | focus.yaml |
| agents/audit/orchestrator-mcp-scan.sh | 2 | baseline rewrite + LATEST scan result |
| agents/context/check-tier0.sh | 4 | bypass-log ×2, resolved-approval flip, pending-approval create (census miss) |
| agents/context/consolidate.py | 2 | learnings.yaml rewrite + report (census miss) |
| agents/context/inject-next-directive.py | 1 | continuous-mode state (census miss) |
| agents/termlink/bvp-estimator/estimator.py | 4 | task frontmatter writes (census miss; shared helper) |

**Exempt (2):** lib/integrate.py (string-only), agents/docgen/test_docgen.py
(test fixture). lib/reviewer/{audit,overrides}.py were already atomic via
pathlib `tmp.replace()` — the lint accepts that signal.

### 2026-07-05 — lint granularity

- **Chose:** file-level ratchet in `tests/unit/atomic_yaml_write_lint.bats`
  (file dumps YAML + no atomic signal → fail), with a live-exempt-list guard
  test so stale exemptions get pruned.
- **Why:** mirrors the census method; catches the dominant class (new writer
  files). Verified it fires on a probe violation and passes on clean tree.
- **Rejected:** site-level linting — needs AST analysis of shell-embedded
  python heredocs; cost far exceeds the marginal catch (a new truncating
  site added to a file that already has one atomic site).


## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-07-05T00:21:25Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-100191-sweep-atomic-write-pattern-for-all-conte.md
- **Context:** Initial task creation

### 2026-07-05T09:22:52Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-706bb5d8
- **Timestamp:** 2026-07-06T13:00:50Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-07-06T13:00:49Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
