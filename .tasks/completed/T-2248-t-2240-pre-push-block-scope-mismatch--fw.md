---
id: T-2248
name: "T-2240 pre-push BLOCK scope mismatch — fw vendor self --dry-run misses bin/agents/web
  drift"
description: >
  fw vendor self --dry-run only iterates lib/*.sh + .tasks/templates — bin/agents/web
  drift escapes the BLOCK detection. Sibling of T-2247 (audit message fix) but at
  the detection layer not just messaging

status: work-completed
workflow_type: inception
owner: agent
horizon: null
tags: []
components: []
related_tasks: [T-2240, T-2244, T-2247]
target_blast_radius: 3
voi_score: 0.4
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-06-08T06:14:10Z
last_update: 2026-06-08T07:44:41Z
date_finished:
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
  - ts: '2026-06-08T06:15:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-06-08T06:15:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2248: T-2240 pre-push BLOCK scope mismatch — fw vendor self --dry-run misses bin/agents/web drift

## Context

Sibling of T-2247 at the detection layer. T-2247 fixed the audit
mitigation message; this fixes the pre-push BLOCK that uses an
under-scoped drift detector and silently allows bin/agents/web drift
to escape.

`agents/git/lib/hooks.sh:678` runs `fw vendor self --dry-run` and BLOCKs
on `would sync` output. But `_self_vendor_libs()` (lib/upgrade.sh:141)
ONLY iterates `$FRAMEWORK_ROOT/lib/*.sh` — bin/agents/web are not
scanned. If only those directories drift, dry-run reports 0 changes,
the gate passes, drift escapes to the vendored mirror and silently
ships to consumers.

Three candidate fixes (to evaluate):
1. Widen `_self_vendor_libs` to scan bin/agents/web (changes the verb's
   semantics — `fw vendor self` becomes near-equivalent to `fw vendor`)
2. Add a `fw vendor --check` mode with file-by-file drift detection
   across all classes, swap pre-push to use it
3. Pre-push runs the audit's `check_self_vendor_drift` function
   directly (or a CLI shim around it) — single source of truth shared
   with the audit FAIL leg (T-2244/T-2247)

Option 3 is most aligned with L-399 (producer/consumer parity) — same
detector, same scope, both surfaces.

## Acceptance Criteria

### Agent
<!-- Inception scope — fix shape to be decided at decide-go. -->
- [x] Investigate the three candidates above and record decision in `## Decision` — see Recommendation block
- [x] Confirm `_self_vendor_libs` scope vs audit `check_self_vendor_drift` scope (cite line numbers) — `lib/upgrade.sh:141` (lib/ only) vs `agents/audit/audit.sh:1523-1548` (bin+lib+agents+web + templates)
- [x] Recommendation block populated with GO/NO-GO/DEFER + rationale — GO Candidate 4 (new `fw vendor check` verb)

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

**Decision**: GO

**Rationale**: Two of the three originally listed candidates have material drawbacks:

**Date**: 2026-06-08T06:47:37Z

## Recommendation

**Recommendation:** GO — Candidate 4 (new `fw vendor check` verb with shared scope)

**Rationale:**
Two of the three originally listed candidates have material drawbacks:

- **Candidate 1 (widen `_self_vendor_libs`):** Conflicts with T-2095's
  deliberate narrow scope. Docs (T-2078 RCA §V1-D) state the helper was
  scoped to lib/ on purpose — operators wired pre-push around that
  contract. Widening retroactively breaks the design intent.

- **Candidate 2 (`fw vendor --check` mode):** Conceptually fine but
  conflates `do_vendor` (a copy verb) with drift detection (a read-only
  check). The `--check` flag is non-obvious next to `--dry-run`.

Candidate 4 — surfaced during this evaluation — is the cleanest fit:

- **Candidate 4 (new `fw vendor check` verb):** New top-level subcommand
  dedicated to drift detection. Same scope as audit's
  `check_self_vendor_drift` (bin+lib+agents+web + .tasks/templates).
  Returns one line per class with "would sync N file(s)" prefix that
  pre-push already greps. Audit can optionally call the same internals
  later for L-399 producer/consumer parity (not in scope here — keeps
  the slice small).

**Evidence:**
- `lib/upgrade.sh:141` — `_self_vendor_libs()` iterates `$FRAMEWORK_ROOT/lib/*.sh` only. Scope cited in T-2078 RCA §V1-D as deliberate.
- `agents/audit/audit.sh:1523-1548` — `check_self_vendor_drift()` scans bin+lib+agents+web + .tasks/templates. Correct scope.
- `agents/git/lib/hooks.sh:678` — pre-push runs `fw vendor self --dry-run`, greps for `would sync`. Greps fine; the upstream check is what's wrong.
- T-2247 RCA names the audit-side mitigation message fix. T-2248 is the detection-side sibling.

**Implementation slice (post-decide-go):**
1. New `fw vendor check` subcommand in `bin/fw` — iterates the same
   class lists as audit, emits `would sync N file(s) in <class>` per
   class with drift, exit 0 always (gating done by caller).
2. Update pre-push hook to call `fw vendor check` instead of
   `fw vendor self --dry-run`.
3. Bats tests for the new verb (per-class drift detection, no false
   positives on clean state).
4. Bats integration test: pre-push hook BLOCKs on synthetic bin/ drift
   (closes the bug at the wire-level).

**Estimated effort:** ~1 session. ~80 LoC verb + ~50 LoC tests + 1 line
hook change.

**Sovereignty boundary:** Inception decide is operator's via
`fw task review T-2248` → Watchtower `/inception/T-2248`.

## Updates

### 2026-06-08T06:14:10Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2248-t-2240-pre-push-block-scope-mismatch--fw.md
- **Context:** Initial task creation

### 2026-06-08T06:21:12Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-06-08T06:22:55Z — status-update [task-update-agent]
- **Change:** workflow_type: build → inception

### 2026-06-08T06:47:37Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Two of the three originally listed candidates have material drawbacks:
