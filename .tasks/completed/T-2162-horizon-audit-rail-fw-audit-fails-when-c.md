---
id: T-2162
name: "horizon audit rail: fw audit FAILs when completed/ files have stored horizon
  != null"
description: >
  Slice 3 of arc-009 horizon-axis-hardening (parent T-2159 inception GO). Add structural
  audit check in agents/audit/audit.sh that scans .tasks/completed/ for files where
  stored horizon is non-null (now/next/later). Emits FAIL with the offending file
  list. Prevents future drift after Slice 2 migration nulls the existing pile. AC:
  (i) fw audit FAILs with file list when at least one completed/ file has horizon:
  now/next/later; (ii) fw audit PASSes after Slice 2 has run; (iii) bats test pinning
  both behaviors.

status: work-completed
workflow_type: build
owner: claude-code
horizon: null
components: [agents/context/post-compact-resume.sh, agents/handover/handover.sh, 
      agents/task-create/create-task.sh, agents/task-create/update-task.sh, 
      bin/migrate-horizon-null-completed.sh, web/blueprints/tasks.py, 
      web/templates/tasks.html]
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-06-01T10:10:19Z
last_update: '2026-06-11T22:24:09Z'
date_finished: 2026-06-01T11:59:00Z
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
  - ts: '2026-06-01T10:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=2
      (body:default-change); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:24:09Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 2
      D4: 2
      F-RECALL: 1
      F-ORCH: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=2
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=1 
      (body:episodic-only); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=1 
      (body/components:context-fabric-incidental); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-06-01T10:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2162: horizon audit rail: fw audit FAILs when completed/ files have stored horizon != null

## Context

Slice 3 of arc-009 horizon-axis-hardening. T-2160 derived `past` from `_location`; T-2161 nulled stored horizon on 1828 completed/ files. This slice adds CTL-030 to `fw audit` so that any future drift (a completed/ file with `horizon: now/next/later`) FAILs the audit with the file list — turning hygiene into a structural rail.

Per T-2161's Evolution note: 117 files with absent horizon are LEGITIMATE (pre-frontmatter-template-era) and must NOT trip the rail. Only non-null/non-empty/non-`~` values fire FAIL.

## Acceptance Criteria

### Agent
- [x] `agents/audit/completed-task-scan.py` returns a `horizon_drift` list — task ids whose stored horizon is non-null/non-empty/non-`~`.
- [x] `agents/audit/audit.sh` consumes `horizon_drift`, emits one FAIL per offender via the `fail` helper with task id + offending value + suggested fix command (run the migration), and PASSes when zero drift.
- [x] On the current corpus (post-T-2161), CTL-030 PASSes (0 drift). Confirmed by running `bin/fw audit` and asserting `CTL-030.*PASS` in output.
- [x] Bats test pins both behaviors: synthesise a temporary completed/ task with `horizon: now`, run the scan, expect that id in `horizon_drift`. Then null the horizon, re-run, expect empty drift.
- [x] At least one commit references `T-2162` AND `arc-009` (or `horizon-axis-hardening`).

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

# AC1+AC2: scan emits horizon_drift; audit consumes it
grep -q "horizon_drift" agents/audit/completed-task-scan.py
grep -q "CTL-030" agents/audit/audit.sh

# AC3: live corpus is clean (0 drift) — check the scanner directly (lock-independent)
n=$(python3 agents/audit/completed-task-scan.py .tasks .context/episodic docs/reports | python3 -c 'import sys,json; print(len(json.load(sys.stdin).get("horizon_drift",[])))'); test "$n" = "0"

# AC4: bats tests for CTL-030 all pass
bats tests/unit/audit_ctl030_completed_horizon_drift.bats >/tmp/.t2162-bats 2>&1; grep -q "^ok 10" /tmp/.t2162-bats

# AC5: commit reference verified post-commit; left for git log inspection

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

### 2026-06-01 — first-fire caught itself
- **What changed:** Immediately after wiring CTL-030, the rail fired on `T-2161` itself — the slice-2 task closed under T-2161 was moved to completed/ with `horizon: now` still stored (last-set value from `started-work`). The rail caught the drift in real time before any commit shipped. Re-running `bin/migrate-horizon-null-completed.sh` cleared it.
- **Plan impact:** Confirms the migration is not one-shot — every task that closes is a fresh drift candidate. Audit rail catches it; migration cleans it. **Eventually a Slice 4 should null horizon at close-time in `update-task.sh`** to plug the source (write-side fix vs read-side rail). Filed as observation.
- **Triggered:** Note for Slice 4 candidate; not filed as a task yet — arc-009's headline mechanic is satisfied by Slices 1-3 (derived render + hygiene + audit rail).

### 2026-06-01 — absent vs null distinction matters
- **What changed:** 117 completed/ files have NO horizon field at all (pre-frontmatter-template-era). Initial scan logic risk: treating absent-field as "null" or treating it as drift would both be wrong. Code distinguishes `horizon_seen` (saw the line) from `horizon` (the value).
- **Plan impact:** Both bats and scan logic explicitly cover absent-field as legitimate (skipped, not drift).
- **Triggered:** Test cases #4, #5.

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

## Recommendation

**Recommendation:** GO — close.

**Rationale:** All 5 Agent ACs pass. The audit rail is wired end-to-end (scan → audit.sh → fail/pass emission) and proves itself in practice — caught its own slice-2 drift before any commit shipped (see Evolution). 10 bats tests pin both directions (fires-on-drift, silent-on-clean) and the legitimacy of absent-field state. arc-009 headline mechanic is now structurally closed: derived-past renders correctly (T-2160), stored corpus is clean (T-2161), audit rail prevents recurrence (T-2162).

**Evidence:**
- `agents/audit/completed-task-scan.py:46-50,80-87,114-120` — `horizon_drift` field added end-to-end
- `agents/audit/audit.sh:2833-2862` — CTL-030 block with `fail` on drift + `pass` on clean
- `tests/unit/audit_ctl030_completed_horizon_drift.bats` — 10 cases, all green
- Live audit: `[PASS] CTL-030: All completed/ tasks have null/absent stored horizon (arc-009)`
- Self-test moment: rail caught `T-2161` immediately after wiring; migration cleaned it.

## Decisions

### 2026-06-01 — read-side rail before write-side fix
- **Chose:** Ship the audit rail (read-side recurrence detection) without also patching `update-task.sh` to null horizon at close-time (write-side prevention).
- **Why:** arc-009's headline mechanic is "agent reads handover, sees zero work-completed in now/next, partial-complete footer is explicit, completed/ renders past, re-running migration reports 0 changes". All five conditions are satisfied by Slices 1-3. The write-side fix is a hygiene improvement that prevents one daily-cron migration cycle but adds no functional behaviour. Filed as a candidate Slice 4 idea in Evolution but not blocking arc-009 close.
- **Rejected:** Add `horizon: null` write in `update-task.sh --status work-completed` path — would have widened this slice into write-side update-task.sh changes that need their own bats coverage. Cleaner as a separate slice if it ever proves necessary.

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

### 2026-06-01T10:10:19Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2162-horizon-audit-rail-fw-audit-fails-when-c.md
- **Context:** Initial task creation

### 2026-06-01T10:10:32Z — status-update [task-update-agent]
- **Change:** tags: +arc:horizon-axis-hardening

### 2026-06-01T11:15:46Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ff09e44d
- **Timestamp:** 2026-06-02T15:01:26Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-06-01T11:59:00Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
