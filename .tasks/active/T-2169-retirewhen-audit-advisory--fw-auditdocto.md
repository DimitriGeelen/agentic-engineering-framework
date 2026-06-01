---
id: T-2169
name: "retire_when: audit advisory — fw audit/doctor staleness warning when free-driver retire condition is recognisably met (T-NEW-C from v3 follow-ups)"
description: >
  retire_when: audit advisory — fw audit/doctor staleness warning when free-driver retire condition is recognisably met (T-NEW-C from v3 follow-ups)

status: captured
workflow_type: build
owner: agent
horizon: later
tags: [v3-followup-C, audit-advisory]
components: [policy/value-drivers.yaml, agents/audit/audit.sh, agents/audit/lib]
related_tasks: [T-2157, T-2165, T-2166, T-2168, L-417]
arc_id: value-prioritisation
created: 2026-06-01T20:32:55Z
last_update: 2026-06-01T20:34:19Z
date_finished: null
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
- [ ] `agents/audit/audit.sh` (or `lib/audit/free_driver_retire_when.py` if Python-extension is the structural pattern in audit.sh) gains a structure-check that parses `policy/value-drivers.yaml`, reads each ACTIVE `free_drivers[]` entry's `retire_when:` text, and runs a per-driver recognition heuristic against the corpus.
- [ ] **F-RECALL retire-condition recognition heuristic:** retire_when text is *"L4 Reflect criteria (positive reinforcement capture, preference index, CLAUDE.md auto-sync, durable reflection log) are green."* Recognition = ALL four sub-criteria show evidence: (a) `git log --grep='positive-reinforcement\|happiness' --since=30days | head -1` non-empty (positive capture present); (b) `find . -name 'preference-index.yaml' -o -name 'preferences.yaml' | head -1` non-empty (preference index exists); (c) `grep -l 'auto-sync\|CLAUDE-sync' agents/ lib/ -r | head -1` non-empty (auto-sync code exists); (d) `find .context -name 'reflection*.yaml' -mtime -7 | head -1` non-empty (durable reflection log active). If ALL four match → emit `WARN: free driver F-RECALL retire_when condition appears met (4/4 signals) — review whether to retire`.
- [ ] **F-ORCH retire-condition recognition heuristic:** retire_when text is *"Multi-agent orchestration criterion goes green / orchestrator substrate (T-1643) lands in production."* Recognition = (a) T-1643 in `.tasks/completed/` AND its body lacks `partial-complete` or `[REVIEW]` marker; OR (b) G-064 marked closed in `.context/project/concerns.yaml`. Either signal triggers WARN.
- [ ] **Generic fallback for any future free driver:** when an active `free_drivers[]` entry has `retire_when:` text but no dedicated recognition heuristic, the audit emits an `INFO: retire_when text present, no recognition heuristic — manual review.` (not a WARN). This keeps the surface honest: only WARN when we have real evidence.
- [ ] **WARN cap:** at most ONE WARN per audit run per driver (de-dupe; the bats test pins this — re-running audit produces same count, not N×count).
- [ ] **Bats coverage** (`tests/unit/test_audit_retire_when.bats`, new): (a) F-RECALL recognition fires only when all 4 signals present; (b) F-ORCH recognition fires when T-1643 is completed cleanly; (c) generic fallback fires for a fictional `F-TEST` free driver with retire_when text but no heuristic; (d) inactive (commented-out) free drivers are skipped; (e) no false-WARN when retire_when is empty.
- [ ] **No FAIL emitted.** This is strictly advisory — operator's call on retirement. Maps to T-1855 stale-arc precedent (WARN, never FAIL).
- [ ] **CLAUDE.md §Configuration update:** add `FW_RETIRE_WHEN_ADVISORY` env var (default `1` = on, `0` = silence) for sessions where retire-warns are noisy during exploration. Document in CLAUDE.md §Configuration.

### Human
<!-- All Agent ACs. Audit advisory output may be spot-checked but is not blocking. -->

## Verification

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

### 2026-06-01T20:32:55Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2169-retirewhen-audit-advisory--fw-auditdocto.md
- **Context:** Initial task creation

### 2026-06-01T20:34:19Z — status-update [task-update-agent]
- **Change:** status: started-work → captured
- **Change:** horizon: now → later
