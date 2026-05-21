---
id: T-1979
name: "T-1976 round-trip: dedup approve-driver + remove from proposed on approval"
description: >
  T-1976 round-trip: dedup approve-driver + remove from proposed on approval

status: work-completed
workflow_type: build
owner: agent
horizon: now
tags: [arc:value-prioritisation, bvp, watchtower, bugfix]
components: [lib/arc.sh, tests/unit/arc_remove_driver_verb.bats]
related_tasks: [T-1976, T-1926, T-1958]
arc_id: value-prioritisation
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-21T13:32:14Z
last_update: 2026-05-21T13:41:22Z
date_finished: 2026-05-21T13:41:22Z
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

# T-1979: T-1976 round-trip: dedup approve-driver + remove from proposed on approval

## Context

Human round-trip on T-1976 surfaced two state-transition bugs in `arc_approve_driver`:
1. **No dedup** — same driver name can be approved twice (verified: `estimator-fidelity` listed twice in `.context/arcs/value-prioritisation.yaml` after human added it via the new form while it was still proposed).
2. **Proposed entry stays after approval** — after `approve-driver foo`, the matching entry in `proposed_scoped_drivers:` is not removed, so the Proposed table still shows it as a candidate.

Both bugs share a single root cause: the python heredoc in `arc_approve_driver` (lib/arc.sh:1205-1238) writes to `scoped_drivers:` without consulting the existing state — neither dedup nor cleanup. T-1976 shipped this surface without bats coverage for state transitions (only happy-path approve and unknown-name refuse on remove).

## Acceptance Criteria

### Agent
- [x] `arc_approve_driver` refuses with exit 1 when the named driver is already in `scoped_drivers:`. Error message names the existing entry's `approved_at` timestamp and points at `remove-driver` as the recovery path.
- [x] On successful approval, any matching entry in `proposed_scoped_drivers:` is removed (case-sensitive name match). Info line emitted: `Removed matching proposal for '<name>'.`
- [x] If no matching proposal existed, no info line is emitted (don't be noisy).
- [x] Bats regression test: dedup refusal (exit 1, error message names timestamp, second approve does not append).
- [x] Bats regression test: proposal cleanup on approval (approve a proposed driver → proposed_scoped_drivers loses that entry, scoped_drivers gains it, other proposals retained).
- [x] Bats regression test: approval of a driver NOT in proposed list does not error and produces no info line about removal.
- [x] One-off cleanup of the duplicate `estimator-fidelity` entry in `.context/arcs/value-prioritisation.yaml` (kept first approval at 12:42:38Z, dropped second at 13:29:20Z, removed matching proposal).
- [x] All existing tests still green: `bats tests/unit/arc_remove_driver_verb.bats` → 18/18 pass.

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
bats tests/unit/arc_remove_driver_verb.bats 2>&1 | tail -1 | grep -q "^ok 18 "
test "$(grep -c 'name: estimator-fidelity' .context/arcs/value-prioritisation.yaml)" -eq 1

## RCA

**Symptom:** Human round-trip on T-1976 surfaced two bugs in arc-scoped driver approval flow:
1. Approving the same driver name twice silently succeeded — produced a duplicate row in `scoped_drivers:`.
2. Approving a driver that was already in `proposed_scoped_drivers:` did not remove it from the proposed list — the Proposed table in `/arcs/<id>` kept rendering it as a candidate even after approval.

**Root cause:** `arc_approve_driver`'s python heredoc (lib/arc.sh:1205-1238) appended to `scoped_drivers:` without consulting the existing state. Two distinct state-transitions both went unmodeled: (a) idempotency on approved-set membership, (b) move-semantics from proposed → approved. The cap check (max 3) was the only existence-aware logic; it counted entries but didn't dedup by name, so two approvals of the same name passed (1 < 3, 2 < 3).

**Why structurally allowed:** T-1976 shipped the approve/remove parity surface with bats coverage for happy paths + unknown-name refusal + §ACD + cap-3, but no coverage for state-transition correctness. The duplicate-approval case was a §ACD-pattern instance: the gate measured a proxy (count ≤ 3) that diverged from the actual invariant (no duplicate names). The proposed-cleanup bug was a missed sub-step of the move semantics — approval was modeled as "add to scoped" rather than "move from proposed to scoped".

**Prevention:** Three new bats tests in `tests/unit/arc_remove_driver_verb.bats` pin the contract for future regressions:
- Dedup refusal with timestamp in error + remove-driver recovery hint.
- Move-semantics on proposed → scoped (matching proposal removed, others retained).
- Quiet path when no matching proposal existed (no spurious info line).

The same `bats` file covers both approve and remove because they're a state-transition pair — keeping their tests adjacent makes future invariant changes harder to miss on one side.

## Evolution

### 2026-05-21 — round-trip-as-coverage

- **What changed:** Two state-transition bugs that T-1976's "ship it" had as zero-test-coverage holes were caught by the first user round-trip on the live page. Three bats tests now pin them.
- **Plan impact:** T-1977 (sliders) is still the natural next pick, but should land alongside a state-transition sweep for weight-change semantics (does the slider commit count as new approval? does it bypass dedup?). T-1977 ACs should explicitly cover this.
- **Triggered:** T-1979 (this task) filed and shipped same session.
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

## Recommendation

**Recommendation:** GO

**Rationale:** Two T-1976 state-transition bugs caught by human round-trip on the live page are now fixed and pinned. The dedup refusal carries a clear recovery hint (remove-driver with rationale). The proposal cleanup makes the Proposed table self-consistent with the Scoped table after approval. The existing duplicate `estimator-fidelity` entry in the live arc YAML is cleaned up to match the new invariant.

**Evidence:**
- `lib/arc.sh` arc_approve_driver: dedup check (lines ~1180-1200) + proposal cleanup (in python heredoc) — `bash -n lib/arc.sh` clean.
- `tests/unit/arc_remove_driver_verb.bats`: 18/18 green (12 original remove + 3 approve-rationale + 3 new T-1979 dedup/cleanup).
- Live CLI smoke: `bin/fw arc approve-driver value-prioritisation "estimator-fidelity" --weight 4 --rationale "..." --from-watchtower` → exit 1, error names timestamp `2026-05-21T12:42:38Z`, points at `remove-driver`.
- `.context/arcs/value-prioritisation.yaml`: 1 occurrence of `estimator-fidelity` in scoped_drivers (was 2); 0 occurrences in proposed_scoped_drivers (was 1).
- T-1957 comment block preserved via ruamel.yaml during cleanup.

## Updates

### 2026-05-21T13:32:14Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1979-t-1976-round-trip-dedup-approve-driver--.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.4)

- **Scan ID:** R-869a5add
- **Timestamp:** 2026-05-21T13:41:27Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-21T13:41:22Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
