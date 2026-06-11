---
id: T-2237
name: "doc: add fw consumer-recover to framework docs (CLAUDE.md + FRAMEWORK.md)"
description: >
  Surface T-2235's fw consumer-recover wrapper in primary framework docs. Currently
  zero mentions in CLAUDE.md and FRAMEWORK.md — future agents won't reach for the
  verb when a consumer is stuck pre-T-2232. The wrapper exists with help text on bin/fw
  line ~625 but isn't called out in the Quick Reference table. Make it discoverable.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [docs, durable-fix, t-2233-chain]
components: []
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-06-07T16:40:57Z
last_update: '2026-06-11T22:24:12Z'
date_finished: 2026-06-07T16:43:50Z
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
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:12Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 5
      F-RECALL: 3
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=5 (body:class-neutral); F-RECALL=3 
      (body:fw-recall-or-memory-link); F-ORCH=0 (no-signal); F3=0 (no-signal); 
      F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2237: doc: add fw consumer-recover to framework docs (CLAUDE.md + FRAMEWORK.md)

## Context

`fw consumer-recover` (T-2233 inception → T-2235 build → T-2236 TermLink-leg fix) ships in `bin/fw` + `lib/consumer-recover.sh` with `bin/fw consumer-recover --help` and a one-line entry in `fw help`. CLAUDE.md and FRAMEWORK.md — the two docs agents reach for when surveying available verbs — have zero mentions. Make the verb discoverable in both Quick Reference surfaces so future agents reach for it when encountering a pre-T-2232 consumer.

## Acceptance Criteria

### Agent
- [x] CLAUDE.md §Quick Reference §Setup and upgrade lists `fw consumer-recover` with one-line description naming `--apply` flag, `--via {ssh,termlink}` transport choice, and sentinel-refuse behaviour (exit 2 on already-post-T-2232 consumers). — `CLAUDE.md:1054`.
- [x] FRAMEWORK.md §Quick Reference table has a row "Recover legacy consumer" → `fw consumer-recover <host> [path] [--apply]`. — `FRAMEWORK.md:273`.
- [x] Cross-link from CLAUDE.md to memory `[[feedback_t2232_forward_looking_recovery]]` so future agents can find the recovery rationale + boundary (T-2232 protects forward-looking only). — same `CLAUDE.md:1054` line names the memory.

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

# AC #1: CLAUDE.md mentions fw consumer-recover under Setup and upgrade
out1=$(grep -A4 '^\*\*Setup and upgrade:\*\*' CLAUDE.md); echo "$out1" | grep -q 'fw consumer-recover'
# AC #1 cont: description names --apply, --via, and sentinel-refuse
out2=$(grep -A4 '^\*\*Setup and upgrade:\*\*' CLAUDE.md); echo "$out2" | grep -q -- '--apply' && echo "$out2" | grep -qE 'via|ssh|termlink' && echo "$out2" | grep -qE 'sentinel|exit 2|post-T-2232'
# AC #2: FRAMEWORK.md Quick Reference row exists
grep -q 'Recover legacy consumer' FRAMEWORK.md && grep -q 'fw consumer-recover' FRAMEWORK.md
# AC #3: memory cross-link present in CLAUDE.md
grep -q 'feedback_t2232_forward_looking_recovery' CLAUDE.md

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

### 2026-06-07T16:40:57Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2237-doc-add-fw-consumer-recover-to-framework.md
- **Context:** Initial task creation

### 2026-06-07 — discoverability slice
- **Action:** Added `fw consumer-recover` to CLAUDE.md §Setup and upgrade (1 line including --apply, --via, sentinel-refuse, and memory cross-link) and to FRAMEWORK.md §Quick Reference table.
- **Output:** `CLAUDE.md:1054`, `FRAMEWORK.md:273`.
- **Context:** T-2233/T-2235/T-2236 chain shipped the wrapper but neither primary doc surface mentioned the verb; future agents surveying available commands wouldn't reach for it on a legacy-consumer recovery scenario.

## Recommendation

**Recommendation:** GO

**Rationale:** Two doc surfaces updated. The CLAUDE.md entry carries the operational details (flag list, transport choice, sentinel-refuse exit code) plus the memory cross-link agents need to understand the boundary (T-2232 is forward-looking only). FRAMEWORK.md table row gives the verb single-line discoverability for the provider-neutral surface. All 3 ACs verify mechanically via grep.

**Evidence:**
- `CLAUDE.md:1054`: full `fw consumer-recover` line under §Setup and upgrade, names `--apply` / `--via` / sentinel + `feedback_t2232_forward_looking_recovery` memory link
- `FRAMEWORK.md:273`: "Recover legacy consumer (pre-T-2232)" row in §Quick Reference table
- All 3 Agent ACs ticked + Verification commands pass (AC1.1, AC1.2, AC2, AC3 all OK)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-a2cc9bd8
- **Timestamp:** 2026-06-07T16:43:51Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-07T16:43:50Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
