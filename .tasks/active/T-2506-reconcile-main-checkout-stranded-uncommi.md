---
id: T-2506
name: "Reconcile MAIN checkout stranded uncommitted work (T-2353 + AC-structure + BVP est) — unblock host go-live"
description: >
  MAIN checkout (/opt/999... on t2417-fw-sessions) has 267 uncommitted changes incl. stranded, committed-nowhere source work from >=3 tasks; blocks host go-live for T-2502. Attribute + land each piece, bring MAIN clean.

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
created: 2026-07-01T11:38:17Z
last_update: 2026-07-01T16:48:42Z
date_finished: null
revisit_at: 2026-07-08            # held per operator (option c); daily G-053 scan surfaces it. Bump if held longer.
revisit_evidence_needed: "Operator picks reconcile approach (a deliverables-only / b full) OR T-2505 C3 detector ships; then run the cherry-pick-onto-master + host go-live for T-2502."
# ── BVP scoring fields (T-1918, arc-006). See docs/reports/T-1915-bvp-inception.md for semantics. ──
# bvp_scores:                     # confirmed per-driver scores 0-5, set by `fw bvp confirm` (T-1924).
#                                 # Sovereignty boundary — only set after human or agent confirmation.
#                                 # Shape: {D1: <int 0-5>, D2: <int 0-5>, D3: <int 0-5>, D4: <int 0-5>, [<free-driver-id>: <int>]...}
# bvp_scores_proposed:            # estimator-proposed scores (T-1922 worker). Persists when ≥2 delta
#                                 # from bvp_scores: on any driver (M3 v2-delta). Shape: list of timestamped entries.
# cost_estimate:                  # F8 composite: 0.6×blast_radius + 0.3×tier + 0.1×effort.
#                                 # Q2 fallback: T-shirt S/M/L/XL mapped to 2/4/6/8 when blast_radius is not yet computable.
---

# T-2506: Reconcile MAIN checkout stranded uncommitted work (T-2353 + AC-structure + BVP est) — unblock host go-live

## Context

Surfaced while taking the host live for T-2502 (deferred per operator, option A). The MAIN checkout `/opt/999-Agentic-Engineering-Framework` (on branch `t2417-fw-sessions`) has **267 uncommitted changes** (152 untracked, 108 modified, 6 deleted, 1 rename). Most are `.context/`/`.tasks/` churn, but **6 real source files** carry stranded, **committed-nowhere** work from ≥3 distinct tasks. This blocks a clean host go-live and is a live instance of T-2505 difficulty #2 (MAIN↔worktree divergence with stranded work).

**Forensic inventory (as of 2026-07-01):**
| File | State | Likely owner | Note |
|------|-------|--------------|------|
| `agents/audit/audit.sh` | M (+141 vs HEAD) | T-2353 (audit `--emit-tasks`) | diverges from branch `t2353-audit-emit-tasks` by 315 lines (241+/74−); committed nowhere |
| `agents/audit/AGENT.md` | M | T-2353 (doc sibling) | verify |
| `agents/context/check-task-ac-structure.py` | M | AC-structure checker (task TBD) | |
| `agents/context/AGENT-check-task-ac-structure.md` | ?? untracked | AC-structure checker | |
| `agents/context/test-helper.sh` | ?? untracked | AC-structure checker | |
| `agents/termlink/bvp-estimator/estimator.py` | M | BVP estimator (T-2354/T-2336?) | verify |

**Goal:** attribute each stranded piece to its owning task, land it on the correct branch (or confirm superseded), bring MAIN to a clean state, and reconcile `t2417-fw-sessions` with `origin/master` so the host can go live cleanly. **Do not discard** without confirming the work is committed elsewhere.

Related: T-2502 (host go-live blocked on this), T-2505 (worktree usage/lifecycle inception — this is difficulty #2 in the flesh).

## Investigation (2026-07-01) — audit.sh is a genuine 3-way divergence, NOT a stray duplicate

Live-verified the forensic hypothesis. The `agents/audit/audit.sh` piece is the crux and it is **two different implementations** of T-2353's emit feature, not a duplicate to discard:

| Ref | audit.sh lines | emit-refs | emit fn | note |
|-----|---------------:|----------:|---------|------|
| `origin/master` | (no emit) | 0 | — | committed base; MAIN's HEAD == this ±7 lines |
| `t2353-audit-emit-tasks` (branch, committed) | 5157 | **10** | uses `section()` helper | cleaner/refactored lineage; MEMORY: T-2353 **+ T-2354 + T-2335** all shipped on this branch stack, "awaiting merge-back" |
| MAIN working tree (`t2417-fw-sessions`, **uncommitted**) | 5324 | **5** | `_emit_findings_as_tasks()` | different/earlier lineage + ~160 unrelated audit.sh lines; committed nowhere |

**Key findings:**
- MAIN's committed audit.sh ≈ origin/master (7-line diff) → **all** of MAIN's emit work is working-tree-only, committed nowhere.
- The branch and MAIN implement emit-tasks **differently** (branch has `section()` + 10 refs; MAIN has `_emit_findings_as_tasks()` + 5 refs). They are not superset/subset — this is a real fork.
- MAIN's uncommitted audit.sh also bundles ~160 lines of **unrelated** audit changes → a blind `git checkout` to adopt the branch would risk losing that non-emit work.

**Reconciliation is an OPERATOR decision, not mechanical:**
1. **Which T-2353 `audit.sh` lineage is canonical** — the committed `t2353-audit-emit-tasks` branch (recommended: MEMORY says T-2353/T-2354/T-2335 all shipped here) OR MAIN's uncommitted `_emit_findings_as_tasks()` copy. Different implementations; picking one supersedes the other.
2. **Preserve MAIN's ~160 unrelated audit.sh lines** before discarding its emit copy (extract to a labeled branch/stash — no work lost).
3. **Merge `t2353-audit-emit-tasks` → master** (operator-gated: landing to master) — this single merge unblocks **3 HV/LC tasks** (T-2353, T-2354, T-2335) at once, plus the deferred T-2502 host go-live.

**Not executed autonomously** (work-loss risk + scope decision + terminates in operator-gated merge). Handed to operator decision-ready.

## Acceptance Criteria

### Agent
- [ ] Each of the 6 stranded source files is attributed to an owning task and either (a) landed on its correct branch, or (b) confirmed already-committed/superseded elsewhere — with evidence per file
- [ ] MAIN checkout has zero uncommitted *real source* changes under `lib/ agents/ bin/ web/` (`git status --porcelain -- lib agents bin web` empty)
- [ ] `t2417-fw-sessions` reconciled with `origin/master` (either FF/merged, or a documented decision to retire the branch) — MAIN carries T-2502's fix
- [ ] Host go-live verified: MAIN's `agents/audit/audit.sh` contains `name "claude-fw"` and `lib/upgrade.sh` contains the `for _shim in fw claude-fw` loop
- [ ] No stranded work lost — any set-aside work preserved on a labeled branch/stash and referenced here

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

### 2026-07-01T11:38:17Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/inception-gov-payload-mediation/.tasks/active/T-2506-reconcile-main-checkout-stranded-uncommi.md
- **Context:** Initial task creation

### 2026-07-01T16:48:42Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
