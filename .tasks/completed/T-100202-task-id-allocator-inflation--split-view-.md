---
id: T-100202
name: "Task-ID allocator inflation + split-view collision RCA (T-100xxx band, audit-emit
  runaway)"
description: >
  Task-ID allocator inflation + split-view collision RCA (T-100xxx band, audit-emit
  runaway)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [agents/task-create/create-task.sh]
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
created: 2026-07-05T22:49:00Z
last_update: '2026-08-16T22:24:20Z'
date_finished: 2026-07-21T06:54:42Z
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
  - ts: '2026-07-07T08:00:01Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-07T08:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 2
      D4: 2
      F-RECALL: 1
      F-ORCH: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 1
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=2
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=1 
      (body:episodic-only); F-ORCH=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0
      (no-signal); F1=1 (body/components:context-fabric-incidental); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
  - ts: '2026-07-08T08:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 2
      D4: 2
      F-RECALL: 1
      F-AUTONOMY: 0
      F3: 0
      F1: 1
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=2
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=1 
      (body:episodic-only); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=1 
      (body/components:context-fabric-incidental); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:20Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 2
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 1
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=2
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=2 
      (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=1 
      (body/components:context-fabric-incidental); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-100202: Task-ID allocator inflation + split-view collision RCA (T-100xxx band, audit-emit runaway)

## Context

Operator question (2026-07-06): *"why are we creating tasks with id in 100201 while we are
somewhere at 2300 ish?"* Investigation confirmed the task-ID space has **two coexisting
sequences**: the legitimate hand-authored range (now ~T-2514) and an **inflated T-100xxx band**
(22 files, T-100122→T-100202) that all new tasks now chain into.

**Confirmed facts:**
- `agents/task-create/create-task.sh:generate_id` (lines 168-182) is **global `max_id + 1`** —
  it scans every `.tasks/{active,completed}/T-*.md`, parses the leading `T-<n>`, and returns
  `max + 1`. No persistent counter. So once any large ID exists, every subsequent task inherits
  the inflated ceiling.
- The band's genesis is **T-100000**, whose filename is
  `T-100000-audit-warn--task-t-99974-audit-warn--tas.md` — an **audit-WARN task about a prior
  audit-WARN task (T-99974)**. The audit `--emit-tasks` feature is directly implicated.
- The emit loop is **stopped** — no `--emit-tasks` entry in the current `.context/cron-registry.yaml`
  (consistent with the T-100146 focus-theft fix).
- Only 2 of 22 T-100xxx files are audit-warn residue (9 audit-warn files total); the rest are
  **legitimate work wearing inflated numbers** (T-100196, T-100200, T-100144 handovers, etc.).
- A parallel **T-2505→T-2514 sequence also survives** — the split-view signature (worktree vs
  main checkout see different `.tasks/` views → divergent `max_id` → two sequences). This is the
  same class that caused this session's duplicate-T-100200 cascade.

**NOT yet confirmed (investigation AC below):** the exact arithmetic of the jump from ~T-2514 to
T-99xxx. `generate_id`'s `grep -oE 'T-[0-9]+'` is case-sensitive, so a lowercase `t-99974` in a
slug would NOT be parsed as a max — meaning either (a) a genuine ~T-99xxx task existed, or (b) the
emitter hand-assigned IDs by a scheme other than `generate_id`. Must be pinned before the fix.

## Acceptance Criteria

### Agent
- [x] **Pin the inflation mechanism** — git-archaeology on the T-2514→T-99xxx→T-100000 transition;
      identify exactly what minted the first out-of-band ID (emitter ID scheme vs a parsed large
      number vs a genuine high task). Document in `## RCA`. → DONE: seed T-99971 (commit 0ab1e255f),
      self-feeding audit-finding emitter (removed from HEAD); recorded in RCA. Residual: exact
      99971 arithmetic in removed emitter source (scoped, non-blocking).
- [x] **Harden `generate_id` against runaway** — DONE: `generate_id` now allocates "MAIN-CLUSTER
      max + 1", quarantining any band separated by a gap > `FW_ID_QUARANTINE_GAP` (default 1000).
      New tasks resume at T-2525 without renumbering the T-100xxx band (zero blast radius). Also
      anchors the id parse to leading `^T-` (ignores embedded T-NNNN in recursive slugs).
      Regression: `tests/unit/t100202_id_quarantine.bats` (6/6 green — quarantine, band-dominant,
      backward-compat, sub-threshold gap, leading-anchor, empty corpus).
      **Caveat cleared:** grep found no "highest task-ID = newest" assumption — consumers
      (`estimator.py`, `bvp.sh`, `resolver.py`) sort task *files lexically* for iteration/sampling,
      unaffected in correctness. NOTE (sibling risk, out of scope): `L-`/`P-`/`D-`/`FP-` ID
      allocators (learning.sh/pattern.sh/decision.sh/resolve.sh) share the same max+1 pattern and
      would inflate identically if ever seeded — not quarantined by this fix.
- [x] **Close or gate the split-view divergence** — DONE (cross-view guard): `_task_view_dirs`
      union-scans `.tasks/{active,completed}` across EVERY git worktree of the repo owning
      `TASKS_DIR` (via `git worktree list --porcelain`), falling back to the local view for
      non-git dirs (harness/consumers). The allocation keylock is additionally anchored at the
      MAIN worktree's `.context/locks` so concurrent minting from different views serializes on
      one lock (per-view locks were siloed). Live-fired: from the framework repo the scan sees
      main + 3 linked worktrees and mints T-2584 (correct main-cluster next). Regression:
      bats test 7 (stale worktree unions main → T-021 not T-011) + test 8 (non-git fallback).
      `find_task_file` wrong-file-on-collision is prevented at source — dup IDs can no longer
      be minted across views; canonical-location resolution deferred to T-100201's mechanism call.
- [x] **Prevent the audit-emit recursion** — DONE (two legs): (a) verified the emitter is
      REMOVED from HEAD — zero `emit-tasks`/`emit_tasks` hits in bin/fw, agents/audit/, lib/;
      audit now emits hash-deduped observations via `fw note` (idempotence by
      `audit_finding_hash` dedup, no ID minted). (b) Structural gate in create-task.sh refuses
      ANY task name carrying the recursion signature (two `audit[ -]?warn` occurrences — a WARN
      task named after a WARN task), with a die message routing to `fw note`. Covers all future
      emitter paths, not just the removed one. Regression: bats tests 9 (refusal, no file
      minted) + 10 (single audit-warn mention stays legal).

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
bash -n agents/task-create/create-task.sh
bats tests/unit/t100202_id_quarantine.bats
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

**Symptom:** new tasks mint IDs in the T-100xxx range (T-100202) while real hand-authored work
is at ~T-2514 — a ~97,000 gap that is NOT 97,000 real tasks. Two ID sequences coexist and
duplicate IDs have occurred (this session's two T-100200 files → the "not an inception task"
decide failure).

**Investigation finding (AC #1, 2026-07-06 — mechanism pinned; one arithmetic residual):**
The exact jump is **T-2524 → T-99971** (a single leap, not incremental) in commit `0ab1e255f`
(2026-07-03). The seed T-99971's frontmatter:
```
name: "Audit WARN — Task T-2488-audit-warn--task-t-2462-audit-warn--task.md missing Updates..."
audit_severity: warn
audit_finding_hash: 9deea5d7068a10a0d25736f9350687748404e3fa
tags: [audit-finding, severity:warn, section:audit]
```
This is the **self-feeding audit-finding emitter**, distinct from plain `fw task create`
(it writes `audit_severity` / `audit_finding_hash` / `audit-finding` tag). The loop:
audit finds "T-2462 missing Updates" → emits an audit-finding task **named after the target's
filename** (T-2488-audit-warn--task-t-2462-…) → the next audit flags *that emitted task* as
"missing Updates" → emits another, name nesting one level deeper → unbounded. The emitter (a)
creates a task per WARN, (b) names it after the offending FILENAME (recursive name growth), (c)
then audits its own emissions. That emitter is **removed from HEAD** (no `--emit-tasks` flag in
`audit.sh`/`bin/fw`/`lib`, no cron entry — consistent with the T-100146 fix). **Residual:** the
precise reason the ID assigned was `99971` (vs `2525`) lives in the removed emitter's ID logic at
`0ab1e255f` — recoverable via `git show 0ab1e255f` of the emitter source; the fix does not depend
on it.

**Root cause (compounding defects):**
1. **Unbounded allocator.** `generate_id` is global `max_id + 1` with no sanity bound. It faithfully
   inherits whatever ceiling exists, so a single out-of-band ID permanently inflates the space for
   all future tasks.
2. **Audit-emit runaway (seed).** The audit `--emit-tasks` feature emitted "Audit WARN — task
   T-N …" tasks; a subsequent audit flagged the *emitted* task and emitted another, recursively
   (slug evidence: `T-100000-audit-warn--task-t-99974-audit-warn--tas`). This produced the
   out-of-band seed that #1 then locked in. The exact jump arithmetic (2514→99xxx) is unpinned.
3. **Split-view amplifier.** Worktree and main checkout see different `.tasks/` file sets →
   `generate_id` computes divergent `max` → two parallel sequences → `find_task_file … | head -1`
   returns the wrong file when IDs collide. Same drift class as T-100196/T-100200.

**Why structurally allowed:** the allocator trusts the on-disk corpus as ground truth with no
plausibility bound and no canonical-view guarantee. An emitter that writes tasks + a global-max
allocator + a split filesystem view compose into unbounded inflation, and nothing gates the
composition. Each piece is individually reasonable; the failure is at the joins (same shape as
L-399 producer/consumer parity).

**Prevention:** all three legs now structural (10/10 bats in `t100202_id_quarantine.bats`):
1. Allocator bounded — quarantine band (>1000 gap) excluded from the ceiling.
2. Split view gated — `_task_view_dirs` union-scan across all git worktrees + main-worktree
   keylock anchor; a stale view can no longer compute a lower max or race a sibling view.
3. Recursion impossible — name gate refuses the double-audit-warn signature at create time for
   ANY caller; the removed emitter's successor path (`fw note` observations) is hash-deduped.
Advisory alone is insufficient (L-300/L-405); each leg is a guard + regression test.

**Decision — do NOT renumber the T-100xxx band.** Task IDs are referenced across commits,
episodic memory (`.context/episodic/`), fabric cards, cross-links, and handovers. Renumbering 22
files' IDs has a large blast radius for a cosmetic gain. The IDs are labels; the fix is to stop the
inflation and prevent recurrence, not to churn history. (Operator may override — it's their call,
but the recommendation is leave-the-labels, fix-the-cause.)

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

### 2026-07-05T22:49:00Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/t100199-close/.tasks/active/T-100202-task-id-allocator-inflation--split-view-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-335cf4c4
- **Timestamp:** 2026-07-21T06:54:46Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-07-21T06:54:42Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
