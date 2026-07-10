---
id: T-2519
name: "fabric orphaned-card check flags gitignored runtime-data artifacts (transient FP, T-2427 sibling)"
description: >
  fabric orphaned-card check flags gitignored runtime-data artifacts (transient FP, T-2427 sibling)

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
created: 2026-07-10T05:49:07Z
last_update: 2026-07-10T05:49:07Z
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

# T-2519: fabric orphaned-card check flags gitignored runtime-data artifacts (transient FP, T-2427 sibling)

## Context

`fw fabric drift` section 2 (orphaned-card check, `agents/fabric/lib/drift.sh:50-71`)
flags **any** card whose `location:` file is missing from disk. But some cards
legitimately point at **gitignored runtime data artifacts** (e.g. `F-004
budget-gate-counter` → `.context/working/.budget-gate-counter`, a counter the
budget-gate hook creates lazily and which is absent between sessions / after a
`.context/working/` clean). When such a file is transiently absent at scan time,
the orphaned check falsely reports `orphaned: 1` → audit WARN. The sibling
stale-edges check (section 3) already got exactly this exemption in T-2427/G-070
(runtime/data-artifact targets whose absence is expected → not drift); the
orphaned-card check never did. Discriminator: a **gitignored** location is
runtime/generated state whose absence is expected; a **tracked** location that's
missing is a genuinely-deleted source file (real drift). `git check-ignore`
cleanly separates the two, and only runs on the rare missing-file branch (no scan
slowdown). Sibling of L-290 ("drift reports stale edges for files that exist").

## Acceptance Criteria

### Agent
- [x] orphaned-card check in `agents/fabric/lib/drift.sh` skips a card whose `location:` file is missing **when that path is gitignored** (`git check-ignore`), and still flags a missing **tracked** location as orphaned
- [x] a bats regression test (`tests/unit/fabric_drift_orphaned_gitignored.bats`) proves both directions: gitignored-missing → NOT orphaned, tracked-missing → orphaned
- [x] vendored copy `.agentic-framework/agents/fabric/lib/drift.sh` re-synced (`fw vendor self`) so audit does not FAIL on vendor drift (T-2240)
- [x] `bin/fw fabric drift` reports `orphaned: 0` with the real `.budget-gate-counter` file moved aside (the transient-absence case that produced the WARN)

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

bash -n agents/fabric/lib/drift.sh
grep -q 'check-ignore' agents/fabric/lib/drift.sh
bats tests/unit/fabric_drift_orphaned_gitignored.bats
diff -q agents/fabric/lib/drift.sh .agentic-framework/agents/fabric/lib/drift.sh
out=$(bin/fw fabric drift 2>&1); echo "$out" | grep -qE "orphaned: 0,"

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

**Symptom:** The pre-push audit in handover `S-2026-0710-0647` reported
`[WARN] Fabric: 1 orphaned card(s) (file deleted but card remains) — 1 cards
reference missing files`. The single "orphaned" card was `F-004
budget-gate-counter` → `.context/working/.budget-gate-counter` — a file that was
not actually deleted, merely transiently absent (the budget-gate hook re-created
it at 07:47, after which `fw fabric drift` reported `orphaned: (none)`).

**Root cause:** `drift.sh` section 2 (orphaned-card check) treats *file missing on
disk* as *card is orphaned*, unconditionally. It has no notion that some cards
legitimately point at **runtime data artifacts** — gitignored, lazily-created
state files whose absence between runs is normal, not drift. `.budget-gate-counter`
is gitignored (`.gitignore:6`), `type: data`, created on demand by the budget-gate
hook.

**Why structurally allowed:** The exact analogous case for *edges* was already
recognised and fixed in T-2427/G-070 — the stale-edges check (section 3) skips
targets that resolve to real on-disk artifacts and skips `writes*` edge types
whose targets are created lazily. That fix was scoped to section 3 (edges) and
never mirrored into section 2 (orphaned cards). So a known, already-solved class
(runtime artifact ≠ drift) still had one un-patched surface. Sibling of L-290
("drift reports stale edges for files that DO exist", T-1494).

**Prevention:** (1) The fix itself: orphaned check now skips a missing location
when `git check-ignore` says it is ignored (runtime/generated state); a missing
*tracked* location is still flagged (a genuinely-deleted source file is not
gitignored). (2) Distinct from the fix — a bats regression test
(`tests/unit/fabric_drift_orphaned_gitignored.bats`) pins **both** directions
(gitignored-missing → not orphaned; tracked-missing → orphaned), so a future
refactor that drops the discriminator fails CI rather than re-flaking the audit.

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

### 2026-07-10T05:49:07Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2519-fabric-orphaned-card-check-flags-gitigno.md
- **Context:** Initial task creation
