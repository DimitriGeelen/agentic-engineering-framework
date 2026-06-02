---
id: T-1665
name: "T-1656 arc-completion detective never fires in cron — wire into oe-daily"
description: >
  T-1656 arc-completion detective never fires in cron — wire into oe-daily

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [C-004, tests/unit/test_audit_arc_completion.py]
related_tasks: []
arc_id: orchestrator-rethink
created: 2026-05-02T05:30:47Z
last_update: 2026-05-02T05:36:03Z
date_finished: 2026-05-02T05:35:38Z
---

# T-1665: T-1656 arc-completion detective never fires in cron — wire into oe-daily

## Context

T-1656 (G-062 mechanism #2) shipped the `arc-completion` audit section — the detective that warns when ≥80% of an arc's constituents are work-completed but the arc itself is still `in-progress`. Mechanism intent: a recurring nudge that fires from cron so the human is reminded to either close the arc or explicitly defer.

**The bug:** `should_run_section "arc-completion"` only returns true when SECTIONS is empty (full audit) or `--section arc-completion` is explicitly passed. None of the production paths invoke either:

- `/etc/cron.d/agentic-audit-999-agentic-engineering-framework` runs `--section observations,gaps` every 6h and `--section oe-daily` daily at 07:00 — neither includes `arc-completion`.
- `.git/hooks/pre-push` (line 198) runs `--section structure` only.
- `agents/audit/audit.sh` SECTIONS default is "" (full audit), but no scheduled job uses that.

Net effect: the detective only fires during interactive `bin/fw audit` (no `--section`) — which is rare. The orchestrator-rethink arc has been ≥80% complete for ~24h with no recurring signal logged. Mech #2 is "shipped but inert" — a §ACD Q3 violation in miniature.

## Acceptance Criteria

### Agent
- [x] `agents/audit/audit.sh` arc-completion `if`-guard widens to also fire under `oe-daily` profile: `if should_run_section "arc-completion" || should_run_section "oe-daily"; then ... fi`
- [x] Manual reproduction proves the change wires the detective into the cron path: `SECTIONS=oe-daily bash agents/audit/audit.sh 2>&1 | grep -q "ARC-COMPLETION"` returns 0
- [x] Today's cron audit at 07:00 already showed `oe-daily` ran (per `.context/audits/cron/LATEST-CRON.yaml`); a follow-up cron-style run with the fix produces an arc-completion finding for `orchestrator-rethink` (84%, ≥ ARC_COMPLETION_THRESHOLD 0.80)
- [x] Pytest pin in `tests/unit/test_audit_arc_completion.py` updated (or new test added) to assert the section runs under `oe-daily`
- [x] Verification block in this task uses structural-only checks (per L-339)

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
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
grep -q 'should_run_section "arc-completion" || should_run_section "oe-daily"' agents/audit/audit.sh
bash -n agents/audit/audit.sh
test -f tests/unit/test_audit_arc_completion.py
grep -q "test_arc_completion_runs_under_oe_daily" tests/unit/test_audit_arc_completion.py

## RCA

**Symptom:** T-1656 arc-completion detective shipped 2026-05-01 but produced zero recurring signals in the 24h that followed despite `orchestrator-rethink` sitting at ≥80% completion. The orchestrator-rethink arc was visibly above threshold on `/arcs/orchestrator-rethink` (the template-side check fires) but no audit log entry referenced it.

**Root cause:** `agents/audit/audit.sh` line 3262 guarded the section with `if should_run_section "arc-completion"; then`. This returns true only when SECTIONS is empty (full audit, rare in production) or when `--section arc-completion` is explicitly passed. None of the production paths invoke either:

- `/etc/cron.d/agentic-audit-999-agentic-engineering-framework`: `--section observations,gaps` (every 6h), `--section oe-daily` (07:00 daily)
- `.git/hooks/pre-push`: `--section structure`
- Interactive `bin/fw audit`: typically `--section <profile>`

The section was section-named for `--section arc-completion` invocation but never wired into a recurring profile.

**Why structurally allowed:** No test asserted the section runs under any production profile. `test_audit_arc_completion.py` only tested via `[fw, audit, --section, arc-completion]` — the explicit invocation path that nobody calls in production. The mech-#2 author and reviewer both verified the *logic* of the detective (warn at threshold, skip closed, no warn below) but neither asserted the *trigger condition* in production. This is a "mechanism shipped without execution path" pattern — the inverse of T-1641's "execution path with no mechanism" (G-061).

**Prevention:** New test `test_arc_completion_runs_under_oe_daily` in `tests/unit/test_audit_arc_completion.py` asserts the section header appears under `--section oe-daily` AND that a real warn fires for an above-threshold arc under that profile. If a future refactor narrows the guard back to `arc-completion` only, this test fails. Cross-cutting prevention: any future detective added under T-1656's pattern (header → guard → check loop) should include a "fires under <production profile>" test as part of its scaffolding.

This is a §ACD Q3 violation in miniature — the framework that built the arc was supposed to be exercising the substrate it built (the detective), but the trigger wiring was missing. T-1664 + T-1665 + T-1655's §ACD codification together constitute the right reflexive answer pattern: ship → wire trigger → test trigger → observe-on-the-wire.

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

## Recommendation

**Recommendation:** GO

**Rationale:** One-line widening of the section guard (`agents/audit/audit.sh:3262`) restores the detective signal that T-1656 was designed to produce. Cron at 07:00 daily now warns when any arc passes `ARC_COMPLETION_THRESHOLD`; today's first run will flag `orchestrator-rethink` at 0.84 with the recommended close-or-defer mitigation. Test pin prevents the trigger wiring from drifting again. RCA captured (§ACD Q3 violation pattern) so the next mech-shipping task includes "fires under production profile" as part of scaffolding.

**Evidence:**
- Manual reproduction: `SECTIONS=oe-daily bash agents/audit/audit.sh 2>&1 | grep "ARC-COMPLETION"` → "ARC-COMPLETION CHECKS" header present + WARN line: "Arc 'orchestrator-rethink': 16/19 tasks completed (0.8421) but arc still in-progress"
- `python3 -m pytest tests/unit/test_audit_arc_completion.py -q` → 5/5 pass (was 4/4 pre-T-1665)
- Diff: single-line change at `agents/audit/audit.sh:3262` widening guard with `||`. No other audit logic touched.

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-05-02T05:30:47Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1665-t-1656-arc-completion-detective-never-fi.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-2c5be144
- **Timestamp:** 2026-06-02T14:58:59Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#3 (Agent)** — Today's cron audit at 07:00 already showed `oe-daily` ran (per `.context/audits/cron/LATEST-CRON.yaml`); a follow-up cron-style run with the fix produces an arc-completion finding for `orchestrator-re
  - **AC-verify-mismatch** (narrow, heuristic) — `path=context/audits/cron/LATEST-CRON.yaml in: Today's cron audit at 07:00 already showed `oe-daily` ran (per `.context/audits/cron/LATEST-CRON.yaml`); a follow-up cron-style run with the fix produ`
### 2026-05-02T05:35:38Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-05-02T05:36:03Z — status-update [task-update-agent]
- **Change:** tags: +arc:orchestrator-rethink
