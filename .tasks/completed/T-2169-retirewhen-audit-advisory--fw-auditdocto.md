---
id: T-2169
name: "retire_when: audit advisory — fw audit/doctor staleness warning when free-driver
  retire condition is recognisably met (T-NEW-C from v3 follow-ups)"
description: >
  retire_when: audit advisory — fw audit/doctor staleness warning when free-driver
  retire condition is recognisably met (T-NEW-C from v3 follow-ups)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [v3-followup-C, audit-advisory]
components: [C-004, tests/unit/test_audit_retire_when.bats]
related_tasks: [T-2157, T-2165, T-2166, T-2168, L-417]
arc_id: value-prioritisation
created: 2026-06-01T20:32:55Z
last_update: '2026-08-16T22:24:55Z'
date_finished: 2026-06-03T15:47:01Z
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
  - ts: '2026-06-01T20:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 2
      D4: 2
      F-RECALL: 1
      F-ORCH: 1
    rationale: "D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=2
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=1 (body/tag hits
      for 'F-RECALL': 1); F-ORCH=1 (body/tag hits for 'F-ORCH': 1)"
    rubric_sha: e4a00f38e801
  - ts: '2026-06-02T20:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 0
      D4: 2
      F-RECALL: 1
      F-ORCH: 1
    rationale: "D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=0
      (no-signal); D4=2 (body:env-class-handled); F-RECALL=1 (body/tag hits for 'F-RECALL':
      1); F-ORCH=1 (body/tag hits for 'F-ORCH': 1)"
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:24:10Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 0
      D4: 2
      F-RECALL: 4
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=0
      (no-signal); D4=2 (body:env-class-handled); F-RECALL=4 
      (body/components:instruction-sync); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:55Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      estimator-fidelity: 0
      D1: 4
      D2: 4
      D3: 0
      D4: 2
      F-RECALL: 4
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: estimator-fidelity=0 (no-signal); D1=4 (body:structural-gate); 
      D2=4 (body:fw-audit-or-doctor); D3=0 (no-signal); D4=2 
      (body:env-class-handled); F-RECALL=4 (body/components:instruction-sync); 
      F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-06-01T20:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 2
      effort: 8
    rationale: blast_radius=3 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2169: retire_when: audit advisory — fw audit/doctor staleness warning when free-driver retire condition is recognisably met (T-NEW-C from v3 follow-ups)

## Context

Pre-scoped follow-up T-NEW-C from the value-drivers.yaml v3 chain
(T-2157 → T-2165 → T-2166, committed `5a3b643c`).

v3 free drivers carry a `retire_when:` field (free-text condition that ends the
driver's focus relevance). policy/value-drivers.yaml lines 84-86 says:
> "retire_when is a free-text reminder, NOT auto-enforced -- it stops a driver
>  quietly outliving its focus and skewing rankings toward work that is already done."

The reminder lives in the YAML but no surface reads it back. F-RECALL retires when
"L4 Reflect criteria are green"; F-ORCH retires when "orchestrator substrate T-1643
lands in production". When those conditions land, the driver SHOULD be flipped to
inactive — but currently nothing nudges the operator.

This task adds an audit advisory rail: `fw audit` (or `fw doctor`) detects
"recognisably met" retire conditions and surfaces a WARN per stale driver.
Recognition is best-effort heuristic (no false-FAIL, only advisory WARN).

Modelled on L-417 detector (stale-slice-reference): policy-text-against-corpus
scan, structural emit, bats-pinned regex.

**Filed `captured + horizon: later`** — operator's call on prioritisation
(T-NEW-A through T-NEW-E pre-scoped from v3 GO-with-refinements).

## Acceptance Criteria

### Agent
- [x] `agents/audit/audit.sh` (or `lib/audit/free_driver_retire_when.py` if Python-extension is the structural pattern in audit.sh) gains a structure-check that parses `policy/value-drivers.yaml`, reads each ACTIVE `free_drivers[]` entry's `retire_when:` text, and runs a per-driver recognition heuristic against the corpus.
- [x] **F-RECALL retire-condition recognition heuristic:** retire_when text is *"L4 Reflect criteria (positive reinforcement capture, preference index, CLAUDE.md auto-sync, durable reflection log) are green."* Recognition = ALL four sub-criteria show evidence: (a) `git log --grep='positive-reinforcement\|happiness' --since=30days | head -1` non-empty (positive capture present); (b) `find . -name 'preference-index.yaml' -o -name 'preferences.yaml' | head -1` non-empty (preference index exists); (c) `grep -l 'auto-sync\|CLAUDE-sync' agents/ lib/ -r | head -1` non-empty (auto-sync code exists); (d) `find .context -name 'reflection*.yaml' -mtime -7 | head -1` non-empty (durable reflection log active). If ALL four match → emit `WARN: free driver F-RECALL retire_when condition appears met (4/4 signals) — review whether to retire`.
- [x] **F-ORCH retire-condition recognition heuristic:** retire_when text is *"Multi-agent orchestration criterion goes green / orchestrator substrate (T-1643) lands in production."* Recognition = (a) T-1643 in `.tasks/completed/` AND its body lacks `partial-complete` or `[REVIEW]` marker; OR (b) G-064 marked closed in `.context/project/concerns.yaml`. Either signal triggers WARN.
- [x] **Generic fallback for any future free driver:** when an active `free_drivers[]` entry has `retire_when:` text but no dedicated recognition heuristic, the audit emits an `INFO: retire_when text present, no recognition heuristic — manual review.` (not a WARN). This keeps the surface honest: only WARN when we have real evidence.
- [x] **WARN cap:** at most ONE WARN per audit run per driver (de-dupe; the bats test pins this — re-running audit produces same count, not N×count).
- [x] **Bats coverage** (`tests/unit/test_audit_retire_when.bats`, new): (a) F-RECALL recognition fires only when all 4 signals present; (b) F-ORCH recognition fires when T-1643 is completed cleanly; (c) generic fallback fires for a fictional `F-TEST` free driver with retire_when text but no heuristic; (d) inactive (commented-out) free drivers are skipped; (e) no false-WARN when retire_when is empty.
- [x] **No FAIL emitted.** This is strictly advisory — operator's call on retirement. Maps to T-1855 stale-arc precedent (WARN, never FAIL).
- [x] **CLAUDE.md §Configuration update:** add `FW_RETIRE_WHEN_ADVISORY` env var (default `1` = on, `0` = silence) for sessions where retire-warns are noisy during exploration. Document in CLAUDE.md §Configuration.

### Human
<!-- All Agent ACs. Audit advisory output may be spot-checked but is not blocking. -->

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

# Bats test (12 cases pin AC #5+#6+#7) — L-387 safe: bats `run` captures output.
bats tests/unit/test_audit_retire_when.bats

# Audit.sh syntax (the new section uses a Python heredoc inside bash)
bash -n agents/audit/audit.sh

# audit.sh contains the new section marker + env-var guard
grep -q "T-2169.*retire_when advisory" agents/audit/audit.sh
grep -q 'FW_RETIRE_WHEN_ADVISORY' agents/audit/audit.sh

# CLAUDE.md §Configuration documents the new env var
grep -q "FW_RETIRE_WHEN_ADVISORY" CLAUDE.md

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

### 2026-06-03 — implementation shape: inline Python heredoc, not separate lib file

- **What changed:** The AC explored a `lib/audit/free_driver_retire_when.py` extraction; in practice the per-driver recognition logic is small (~50 LOC), and audit.sh already inlines comparable Python heredoc passes (T-1927 BVP coherence, the active-task scanner). Inline matches the surrounding pattern and keeps the audit.sh single-file shape.
- **Plan impact:** No new `lib/audit/` directory; the components: list in frontmatter remains accurate (`agents/audit/audit.sh`, no `agents/audit/lib`).
- **Triggered:** None — pure shape choice.

### 2026-06-03 — F-ORCH detection: literal AC reading on `[REVIEW]` marker

- **What changed:** AC #3 specifies "T-1643 in completed/ AND body lacks `partial-complete` or `[REVIEW]` marker". Live T-1643 contains a TICKED `[x] [REVIEW]` line (its Human AC was reviewed). Implementation matches the literal AC text — TICKED `[REVIEW]` still suppresses the F-ORCH WARN. That is conservative-correct: a task whose body still mentions review (ticked or not) hasn't reached the "no review residue" state the AC asks for. A future refinement could distinguish `[ ] [REVIEW]` vs `[x] [REVIEW]`, but the current behaviour is on-spec and safe (false-negative bias matches the WARN-only advisory shape).
- **Plan impact:** None — matches AC.
- **Triggered:** A possible follow-up if operator wants stricter (only unticked) detection.

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

### 2026-06-01T20:32:55Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2169-retirewhen-audit-advisory--fw-auditdocto.md
- **Context:** Initial task creation

### 2026-06-01T20:34:19Z — status-update [task-update-agent]
- **Change:** status: started-work → captured
- **Change:** horizon: now → later

### 2026-06-03T15:26:30Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)

### 2026-06-03T15:26:31Z — status-update [task-update-agent]
- **Change:** horizon: now → now

## Reviewer Verdict (v1.5)

- **Scan ID:** R-77ed4e58
- **Timestamp:** 2026-06-03T15:47:10Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Per-AC findings:**

- **AC#1 (Agent)** — `agents/audit/audit.sh` (or `lib/audit/free_driver_retire_when.py` if Python-extension is the structural pattern in audit.sh) gains a structure-check that parses `policy/value-drivers.yaml`, reads eac
  - **AC-verify-mismatch** (narrow, heuristic) — `path=policy/value-drivers.yaml in: `agents/audit/audit.sh` (or `lib/audit/free_driver_retire_when.py` if Python-extension is the structural pattern in audit.sh) gains a structure-check `
- **AC#3 (Agent)** — **F-ORCH retire-condition recognition heuristic:** retire_when text is *"Multi-agent orchestration criterion goes green / orchestrator substrate (T-1643) lands in production."* Recognition = (a) T-164
  - **AC-verify-mismatch** (narrow, heuristic) — `path=context/project/concerns.yaml in: **F-ORCH retire-condition recognition heuristic:** retire_when text is *"Multi-agent orchestration criterion goes green / orchestrator substrate (T-16`

### 2026-06-03T15:47:01Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
