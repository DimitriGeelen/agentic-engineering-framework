---
id: T-100135
name: "audit emit-tasks dedup hash volatile-token normalization — daily duplicate
  finding tasks"
description: >
  audit emit-tasks dedup hash volatile-token normalization — daily duplicate finding
  tasks

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [C-004]
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
created: 2026-07-04T09:15:13Z
last_update: 2026-07-04T11:34:57Z
date_finished: 2026-07-04T11:34:57Z
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
  - ts: '2026-07-04T09:30:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-04T09:30:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 2
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F-AUTONOMY: 0
      audit_severity: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=2
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal); F-AUTONOMY=0 (no-signal); 
      audit_severity=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-100135: audit emit-tasks dedup hash volatile-token normalization — daily duplicate finding tasks

## Context

The `--emit-tasks` dedup hash in `agents/audit/audit.sh:_emit_findings_as_tasks` is
`sha1(whitespace-normalized check text)`. Several detector check texts embed volatile
numeric measurements — day counters (`T-1062(86d-active)` → `87d-active`), queue
counts (`141 task(s)` → `142 task(s)`) — that change on every daily audit run, so the
hash changes daily and the same finding class mints a fresh "unique" task per run.
Live debris: D5 lifecycle trio (T-100122/T-100126/T-100133), D2 review-queue quad
(T-100086/T-100124/T-100125/T-100127) — 7 tasks for 2 findings. Sibling class to
T-100128 (dedup broken by missing hash); here dedup is *present but keyed on volatile
input*.

Fix: neutralize digit runs in the check text before hashing, EXCEPT task-ID references
(`T-NNNN`), which are structural identity (CTL-012 findings about different inception
tasks must stay distinct). Plus one-time migration: collapse existing duplicate groups
(keep oldest, delete newer) and rewrite the kept tasks' `audit_finding_hash:` to the
new-style hash so the next audit run dedups against them.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Hash computation in `_emit_findings_as_tasks` replaces standalone digit runs with a placeholder before hashing, while `T-\d+` task-ID tokens are preserved verbatim
- [x] bats regression tests pin the normalization: (a) same finding with different day-counts/counts hashes identically; (b) findings differing only by referenced task ID hash differently
- [x] Existing duplicate groups collapsed: exactly one active task remains per finding class (D5 lifecycle, D2 review-queue); survivors carry new-style hashes recomputed from the latest audit YAML
- [x] `bin/fw audit --emit-tasks --dry-run` reports the D5 and D2 findings as SKIP (hash exists) — no new duplicates would be minted
  <!-- Evidence 2026-07-04: `bin/fw audit --section discovery --emit-tasks --dry-run` →
       "[SKIP] FAIL (hash exists): D2: Human review queue — 142 task(s) waiting >30d: T-1701(38..."
       "Summary: 0 created, 1 skipped (hash exists)". D2's day-counters differ from the
       survivor's capture day yet the hash matches — volatile-token normalization proven
       live end-to-end. D5 emitted no finding this run (only D2 fired in discovery).
       Bonus: the 12:xx hourly cron emitted T-100141 with a single correct tags: line —
       T-100136 fix also confirmed in production. -->

## Updates (manual)

### 2026-07-04 — AC4 evidence
- Full-audit dry-run was SIGTERM'd twice by :00/:30 cron audit lock contention; scoped
  `--section discovery` run between cron slots produced the SKIP evidence cleanly.

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

out=$(bats -f "T-100135" tests/unit/test_audit_emit_tasks.bats 2>&1); [ "$(echo "$out" | grep -c '^ok ')" -eq 2 ] && ! echo "$out" | grep -q '^not ok'
# survivor tasks carry new-style (digit-neutralized) hashes; no duplicate hashes remain among active audit-finding tasks
python3 -c "import re, glob; hashes = [m.group(1) for p in glob.glob('.tasks/active/T-*.md') for m in [re.search(r'(?m)^audit_finding_hash: ([0-9a-f]{40})\$', open(p).read())] if m]; assert len(hashes) == len(set(hashes)), 'duplicate hash'; assert len(hashes) >= 8"
# D5/D2 duplicate debris removed
[ -z "$(ls .tasks/active/ | grep -E 'T-100124|T-100125|T-100126|T-100127|T-100133')" ]

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

**Symptom:** The daily cron audit with `--emit-tasks` created a fresh finding task for
the same finding class on every run: 3 active tasks for the single D5 lifecycle finding
(T-100122/T-100126/T-100133), 4 for the single D2 review-queue finding
(T-100086/T-100124/T-100125/T-100127) — 7 tasks for 2 findings in under 36 hours.

**Root cause:** The dedup hash in `_emit_findings_as_tasks` is sha1 of the raw
(whitespace-normalized) check text. Detector check texts for D2/D3/D5 embed volatile
measurements — per-task day counters (`86d-active` → `87d-active`), queue counts
(`141 task(s)` → `142`), velocity ratios — that legitimately change between runs, so
the hash of the *same finding class* changes daily and the dedup lookup never hits.

**Why structurally allowed:** Dedup identity was never designed — the hash input
defaulted to "the whole check string" without asking which parts of the string are
identity (check name, subject task IDs) and which are measurement (counts, ages).
No test exercised two runs of the same finding over time, so the churn only became
visible as active-task debris. Sibling class to T-100128 (dedup silently broken by a
missing hash field): both are failures of the dedup keying, undetected because nothing
audits the emitter's own output for duplicates.

**Prevention:** (1) bats regression tests pin the two identity properties — volatile
digits don't change the hash, subject task IDs do (tests
"emit-tasks hash: volatile counts..." and "...differing only by task ID" in
`test_audit_emit_tasks.bats`). (2) The Verification block asserts no duplicate
`audit_finding_hash` values exist among active tasks — a shape the daily audit could
adopt as a self-check on emitter output.
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

### 2026-07-04T09:15:13Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-100135-audit-emit-tasks-dedup-hash-volatile-tok.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-7c981a37
- **Timestamp:** 2026-07-04T11:34:59Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Verification-level findings:**

  1. **mock-only-integration** (partial, heuristic) @ AC vs Verification cross-check
     - evidence: `out=$(bats -f "T-100135" tests/unit/test_audit_emit_tasks.bats 2>&1); [ "$(echo "$out" | grep -c '^ok ')" -eq 2 ] && ! echo "$out" | grep -q '^not ok'`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 1
     - evidence: `out=$(bats -f "T-100135" tests/unit/test_audit_emit_tasks.bats 2>&1); [ "$(echo "$out" | grep -c '^ok ')" -eq 2 ] && ! echo "$out" | grep -q '^not ok'`

### 2026-07-04T11:34:57Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
