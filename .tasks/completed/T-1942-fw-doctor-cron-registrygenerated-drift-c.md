---
id: T-1942
name: "fw doctor cron registry→generated drift check (close L-364 cousin that bit
  T-1935/T-1941)"
description: >
  fw doctor cron registry→generated drift check (close L-364 cousin that bit T-1935/T-1941)

status: work-completed
workflow_type: build
owner: agent
horizon: now
tags: [arc:value-prioritisation, future-prevention, drift, cron]
components: [C-004, bin/fw, tests/unit/test_audit_cron_registry_generated_drift.bats, tests/unit/test_cron_registry_generated_drift.bats]
related_tasks: [T-1935, T-1941, T-1771, T-1112, T-1114, T-1558]
arc_id: value-prioritisation
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-19T22:11:54Z
last_update: 2026-05-19T23:11:45Z
date_finished: 2026-05-19T23:11:45Z
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
  - ts: '2026-05-19T22:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-19T22:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 1
      tier: 2
      effort: 8
    rationale: blast_radius=1 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1942: fw doctor cron registry→generated drift check (close L-364 cousin that bit T-1935/T-1941)

## Context

`fw doctor`'s "Cron registry in sync" check covers the **generated → deployed** transition
(diff `.context/cron/agentic-audit.crontab` against `/etc/cron.d/agentic-audit-<slug>`).
It does NOT cover **registry → generated** drift: if `.context/cron-registry.yaml` is
edited but `fw cron generate` is never run, the source-of-truth diverges from the
generated artefact, the deployed file matches the (stale) generated, and doctor reports
"in sync" while the new cron entry is invisible to the OS scheduler.

This is the exact class that bit T-1935 (bvp-cost-estimator-sweep entry added to registry
but never regenerated) — T-1941 fixed the symptom by running `fw cron generate`, but the
gap stayed open. The future-prevention fix is structural: extend the drift check to also
re-run the generate logic in dry-run mode, diff against the on-disk generated file, and
WARN on divergence.

L-364 captures the registry→deployed contract; this task closes the third leg of the
three-step sync (registry → generated → deployed).

## Acceptance Criteria

### Agent
- [x] `fw doctor` detects registry→generated drift: when `cron-registry.yaml` declares a
      job that is absent from `.context/cron/agentic-audit.crontab`, doctor emits
      `WARN  Cron registry edited but not generated — run: fw cron generate`
- [x] Drift check uses content comparison (not just job count) — catches modified
      schedules / commands / status flips, not only add/remove
- [x] On clean state (registry matches generated), doctor still emits the existing
      `OK  Cron registry in sync` line (no regression on the happy path)
- [x] New unit test pins both directions: drifted-registry → WARN line present;
      in-sync registry → OK line present, no WARN
- [x] Test runs in tmp dir via `FW_CRON_INSTALL_DIR` env-var override (no /etc/cron.d
      assumption)
- [x] L-364 strengthened (or new L-XXX added) capturing the three-step sync contract:
      registry → generated → deployed; each transition is a separate drift class

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

bats tests/unit/test_cron_registry_generated_drift.bats
out=$(bin/fw doctor 2>&1); echo "$out" | grep -qE "Cron registry (in sync|edited but not generated|drift)"

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

### 2026-05-19 — Three-leg sync taxonomy
- **What changed:** Cron sync is THREE transitions, not two. L-364 originally framed it
  as "wired ≠ deployed" (a two-state contract); T-1771 wired audit-side coverage for
  one of the three classes; T-1942 surfaces the missed leg (registry → generated).
- **Plan impact:** The mental model "registry/generated/deployed" was already in
  L-364's text, but the enforcement only covered two of three pairings. This task
  upgrades the model from "two state, one check" to "three states, three drift
  classes, three checks".
- **Triggered:** L-364 strengthening with explicit three-class taxonomy; T-1943
  sibling task (audit-side parity); L-408 (separate but discovered during this
  segment: bin/fw heredoc edit lockup class — 3rd incident).

## Recommendation

**Recommendation:** GO

**Rationale:** Closes the third leg of the cron three-step sync (registry → generated →
deployed). Before T-1942, `fw doctor`'s "Cron registry in sync" line covered only
generated→deployed — registry→generated drift sat invisibly for 3+ days on T-1935 before
T-1941 ran `fw cron generate` to clear it. The new check re-runs the generate logic in
dry-run mode (Python heredoc reuses the exact production logic from bin/fw:3073-3139)
and content-diffs against the on-disk source, catching add/remove/modify drift uniformly.

**Evidence:**
- bin/fw:1696-1768 — registry→generated drift block added before the existing
  generated→deployed checks
- tests/unit/test_cron_registry_generated_drift.bats — 3 tests all PASS:
  1. drifted registry (added job, not regenerated) → WARN
  2. in-sync registry → OK, no WARN regression
  3. modified-in-place (schedule change, no job-count delta) → WARN
- L-364 strengthened with the three-class taxonomy and the rule "a sync-chain with N
  transitions has N drift classes; auditing only the endpoints misses middle-link drift"
- Same Python generate logic shared between `fw cron generate` and doctor's dry-run —
  no duplicate maintenance surface

## Decisions

### 2026-05-19 — Dry-run inline vs `fw cron check` subcommand
- **Chose:** Inline dry-run inside doctor (Python heredoc), no new subcommand.
- **Why:** Minimal surface change; doctor already invokes Python for other checks; the
  generate logic is small enough (~30 lines) that duplicating in dry-run form is
  cheaper than designing a new subcommand contract. Future refactor can extract
  shared `fw cron _dry_run` if a third consumer emerges.
- **Rejected:** `fw cron check` subcommand (would have required new exit-code contract,
  new help text, new tests for the subcommand surface itself).

### 2026-05-19 — Content comparison vs job-count comparison
- **Chose:** Full content diff between dry-run output and on-disk source.
- **Why:** Job-count comparison would miss modify-in-place edits (schedule changes,
  command changes, paused→active flips). The bug class is "registry edited, generate
  not run" — that includes ANY edit, not just add/remove. Test 3 pins this directly.
- **Rejected:** count-only comparison (would have missed the most insidious class).

### 2026-05-19 — Why no Human AC
- **Chose:** All ACs as Agent (no Human review section).
- **Why:** Pure tooling/CLI change with deterministic shell-command verification. No
  render surface, no aesthetic judgment, no irreversible action. Per T-954 risk matrix
  and T-1878 author-time default (route to Agent + Verification when grep-able), this
  belongs entirely on the Agent side.

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

### 2026-05-19T22:11:54Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1942-fw-doctor-cron-registrygenerated-drift-c.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.4)

- **Scan ID:** R-90436723
- **Timestamp:** 2026-05-19T23:16:01Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#5 (Agent)** — Test runs in tmp dir via `FW_CRON_INSTALL_DIR` env-var override (no /etc/cron.d
  - **AC-verify-mismatch** (narrow, heuristic) — `path=etc/cron.d in: Test runs in tmp dir via `FW_CRON_INSTALL_DIR` env-var override (no /etc/cron.d`

### 2026-05-19T23:11:45Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
