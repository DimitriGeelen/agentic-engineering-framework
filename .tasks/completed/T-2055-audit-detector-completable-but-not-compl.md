---
id: T-2055
name: "Audit detector: completable-but-not-completed tasks (Agent ACs all ticked,
  status still started-work)"
description: >
  L-434 prevention. Add a fw audit (and/or fw doctor) check that flags tasks whose
  Agent ACs are 100% ticked but status is still started-work/issues — shipped-but-unclosed
  work that never entered the review queue. Origin: 35 arc-007 child slices found
  stuck this way (S-2026-0526). Distinct from fw task stale (date-based). Emit WARN
  per task with the completion command.

status: work-completed
workflow_type: build
owner: agent
horizon: now
tags: []
components: [C-004, tests/unit/test_audit_completable_not_completed.bats]
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-25T22:45:57Z
last_update: 2026-05-27T22:19:27Z
date_finished: 2026-05-27T22:19:27Z
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
  - ts: '2026-05-25T23:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-25T23:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
---

# T-2055: Audit detector: completable-but-not-completed tasks (Agent ACs all ticked, status still started-work)

## Context

Active tasks where every Agent AC is `[x]` but `status:` is still
`started-work` or `issues` are "shipped-but-unclosed" — the implementation
work is finished but no one ran `fw task update --status work-completed`.
This blocks partial-complete handover to the human (owner flips to human,
file moves to completed/) and pollutes the active board with done work.

The sibling check CTL-028 already catches the opposite drift (in
completed/ but status=started-work). T-2055 is the active/-side mirror.

**Heuristic:** parse `### Agent` block (between `### Agent` header and
either `### Human` or next `## ` heading). Count `^- \[x\]` vs `^- \[ \]`.
If all ticked AND status ∈ {started-work, issues} AND the body is not
template-only (has real AC text), emit WARN.

**False-positive guard:** if no `### Agent` header exists, treat all
`^- \[ \]`/`^- \[x\]` lines under `## Acceptance Criteria` (before the
next `## ` heading) as Agent ACs. Tasks without any ACs (placeholder-only
or completely empty) are silent.

## Acceptance Criteria

### Agent
- [x] New audit check in `agents/audit/audit.sh` (compliance section, alongside CTL-028) that scans `.tasks/active/T-*.md` and emits `WARN CTL-029: T-XXX has all Agent ACs ticked but status=started-work (run: bin/fw task update T-XXX --status work-completed)` for each completable-but-not-completed task
- [x] AC parser handles three task shapes: (a) `### Agent` + `### Human` split — count Agent only; (b) `## Acceptance Criteria` with no sub-headers — count all `- [ ]`/`- [x]` lines; (c) placeholder/empty AC list — silent (no false WARN)
- [x] Detector skips tasks where AC list is entirely template-only (the well-known template stub items the task-creation step ships unedited)
- [x] Bats coverage in `tests/unit/test_audit_completable_not_completed.bats` proves four cases: (a) all-Agent-ticked started-work → WARN, (b) partial-ticked → silent, (c) no-split all-ticked → WARN, (d) placeholder-only → silent; plus two bonus tests: captured-with-pre-ticked-ACs → silent, all-clear → PASS line. 6/6 green. proves four cases: (a) all-Agent-ticked started-work → WARN, (b) partial-ticked → silent, (c) no-split all-ticked → WARN, (d) placeholder-only → silent
- [x] All existing audit-related bats stay green (test_audit_cron_drift 5/5, test_audit_cron_registry_generated_drift 3/3, test_audit_revert_chain 4/4). `test_audit_watchdog_fd.bats` test 4 fails environmentally on this host (orphan watchdog sleeps from other consumers, pre-existing, documented in T-2058 close — unaffected by T-2055).

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
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.
bats tests/unit/test_audit_completable_not_completed.bats

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

## Recommendation

**Recommendation:** GO

**Rationale:** Bounded ~90-line addition to `agents/audit/audit.sh` (new
CTL-029 block, placed adjacent to CTL-028 for symmetry: same trigger
condition `compliance || oe-daily`, same shape as the desync detector but
mirrored to active/-side). Inline Python parser handles the three AC shapes
deterministically:
- frontmatter parsed via `re.match` on the `---` block
- `## Acceptance Criteria` section sliced via regex header lookup
- HTML comment blocks (`<!-- ... -->`) stripped before scan so the Human
  comment block's example ACs never bleed into the count
- `### Agent` sub-section preferred when present; else whole AC block
- placeholder lines `[First criterion]` etc. excluded
- silent when no real ACs OR partial-ticked OR status ∉ {started-work, issues}

Live scan finds 12 completable-but-not-completed tasks in the corpus (T-1062,
T-1274, T-1542, T-1624, T-2056, T-332, T-334, T-464, T-544, T-801, T-802,
T-803). These are exactly the class the detector targets — work shipped,
close never run. CTL-028 was 4 tasks; CTL-029 finds the larger active-side
shadow.

Pinned by `tests/unit/test_audit_completable_not_completed.bats` — 6/6
green, covering the four required shapes plus two edge cases
(captured-with-pre-ticked-ACs is silent; PASS line emits when nothing to
flag).

**Evidence:**
- Code: `agents/audit/audit.sh` CTL-029 block (~90 lines, adjacent to CTL-028)
- Tests: `tests/unit/test_audit_completable_not_completed.bats` — 6/6 green
- Adjacent audit bats remain green: cron-drift 5/5, cron-registry-generated
  3/3, revert-chain 4/4
- Live: 12 tasks flagged in the framework's own corpus

**Why this matters now:** The 4 CTL-028 cases in current audit (T-1902,
T-1901, T-1915, T-1905) are the *symptom*; the active-side mirror catches
the *upstream* class — a task with all Agent ACs ticked but no close-run
is exactly the state that ends up causing CTL-028 when someone eventually
`git mv`s it without going through update-task.sh.

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

### 2026-05-25T22:45:57Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2055-audit-detector-completable-but-not-compl.md
- **Context:** Initial task creation

### 2026-05-27T22:15:13Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-0533914a
- **Timestamp:** 2026-05-27T22:19:31Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-27T22:19:27Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
