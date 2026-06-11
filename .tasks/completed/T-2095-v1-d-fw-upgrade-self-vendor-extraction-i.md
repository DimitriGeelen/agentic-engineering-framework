---
id: T-2095
name: "V1-d fw upgrade: self-vendor extraction into a separate verb (T-2078 GO, closes
  F2)"
description: >
  V1 slice from T-2078 GO. Closes F2: upgrade.sh self-vendors framework files inside
  the upgrade flow, blurring concerns. Extract into a separate verb (fw vendor or
  fw self-vendor) so upgrade is just orchestration. Spec: docs/reports/T-2078-fw-upgrade-reliability-review.md
  F2. Sequence after V1-c.

status: work-completed
workflow_type: refactor
owner: agent
horizon:
tags: [fw-upgrade, reliability, v1, T-2078-slice]
components: [C-004, bin/fw, lib/upgrade.sh]
related_tasks: [T-2078, T-2092]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-29T11:58:39Z
last_update: '2026-06-11T22:24:07Z'
date_finished: 2026-06-06T20:34:26Z
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
  - ts: '2026-06-05T18:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 3
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=3 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-06T18:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 3
      effort: 7
    rationale: blast_radius=0 (no-signal); tier=3 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-06-05T18:00:03Z'
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
  - ts: '2026-06-06T20:30:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=2 (body:default-change); D4=2 
      (body:env-class-handled); F-RECALL=2 (body:lightly-promoted); F-ORCH=0 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:24:07Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 2
      D4: 5
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=2 (body:default-change); D4=5 
      (body:class-neutral); F-RECALL=2 (body:lightly-promoted); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-2095: V1-d fw upgrade: self-vendor extraction into a separate verb (T-2078 GO, closes F2)

## Context

V1-D slice of T-2078 GO. Closes F2 (self-vendor runs unconditionally on every consumer upgrade — N×M redundancy when developer machines run `fw upgrade` across multiple consumers, and the inline code organisationally conflates "framework prepares to vendor out" with "consumer upgrades from framework"). Spec: `docs/reports/T-2078-fw-upgrade-reliability-review.md` §F2 (line 57). Sequence after V1-C (T-2094 SHIPPED, F8/F10 closed).

Scope decision (D7 narrow): refactor + new verb + opt-out flag. **Default behavior is preserved** — the inline call in `do_upgrade` stays ON to keep T-1217's invariant alive on every developer machine that hasn't yet wired pre-push. The §F2 N×M closure (remove inline call + fire from pre-push only) is the operator follow-on, *not* this slice — that change is higher-blast-radius (modifies the framework's own pre-push) and benefits from observing the new verb in the field first.

What this slice ships:
- `_self_vendor_libs()` helper in `lib/upgrade.sh` — pure extraction, same logic, callable in isolation
- `fw vendor self` subcommand at `bin/fw` — explicit entry point for cron / pre-push / manual invocation
- `--no-self-vendor` flag on `fw upgrade` — opt-out for operators who have already wired pre-push, or for fast in-loop upgrades against consumers
- Bats coverage for all three surfaces

What this slice deliberately does NOT ship (T-2095-follow-on territory):
- Pre-push hook modification (wiring the verb is operator step)
- Default-flip (removing inline call) — requires field telemetry showing the verb is in use first

## Acceptance Criteria

### Agent
- [x] **Helper extracted: `_self_vendor_libs()` in `lib/upgrade.sh`** — Same logic as the prior inline block (lib/upgrade.sh:392-414); inline call site now reads `_self_vendor_libs "$dry_run"`. **Evidence:** `lib/upgrade.sh` — helper at `_self_vendor_libs()`, structural bats `t1` PASS confirms both helper definition and the inline call shape `_self_vendor_libs "$dry_run"`.
- [x] **`fw vendor self` subcommand wired in `bin/fw`** — Routes to `_self_vendor_libs` (with `--dry-run` passthrough); `fw vendor self --help` advertises the new verb. Other `fw vendor` args pass through to `do_vendor` unchanged. **Evidence:** bats `t5` PASS; manual: `bin/fw vendor self --dry-run` → `Self-vendor: synced 12 file(s) to .agentic-framework/lib/` exit 0.
- [x] **`--no-self-vendor` flag on `fw upgrade`** — Flag advertised in `do_upgrade --help`; when set, inline call is SKIPPED and `Self-vendor skipped (--no-self-vendor)` line prints; default behavior unchanged. **Evidence:** bats `t6` (help) + `t7` (skip + trip-wire negative) + `t8` (default still calls helper) all PASS.
- [x] **Helper is structurally consumer-safe** — Early-return on missing `$FRAMEWORK_ROOT/.agentic-framework/lib` (T-1217 structural guard preserved). **Evidence:** bats `t2` PASS — helper produces no output when invoked against a directory that has only `lib/` and no `.agentic-framework/lib/`.
- [x] **`fw vendor self` runtime test** — synthetic FRAMEWORK_ROOT with same.sh (match) + changed.sh (diff); helper syncs only the diffed file; same.sh untouched. **Evidence:** bats `t3` PASS (synced 1 file; both files diff-OK post-helper).
- [x] **`--no-self-vendor` runtime test** — `do_upgrade --dry-run --no-self-vendor` emits "Self-vendor skipped" + trip-wire on `_self_vendor_libs` confirms helper was NOT called. **Evidence:** bats `t7` PASS.
- [x] **Default behaviour runtime test** — `do_upgrade --dry-run` (no flag) calls `_self_vendor_libs` (marker observed) and does NOT emit "Self-vendor skipped". **Evidence:** bats `t8` PASS.
- [x] **Bats suite passes** — `bats tests/unit/t2095_upgrade_self_vendor_extraction.bats` → **8/8 PASS** on first run.
- [x] **Sibling regression unaffected** — fresh-machine 3/3 + T-2093 6/6 + T-2094 8/8 + T-2232 8/8 — **25/25 PASS sibling regression** + 8/8 t2095 = **33/33 PASS across the full V1-ladder net**.
- [x] **Reviewer PASS** — `bin/fw reviewer T-2095 --no-write` → R-070694d5 2026-06-06T20:31:38Z, **Overall: PASS**, Findings: none, Needs Human: no.

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

# T-2095 verification commands:
# Helper structural — extracted function exists in lib/upgrade.sh
grep -qE "^_self_vendor_libs\(\)" lib/upgrade.sh && echo "helper extracted"
# Inline call site replaced
grep -qE "_self_vendor_libs.*dry_run" lib/upgrade.sh && echo "inline call uses helper"
# fw vendor self subcommand wired (runtime — verb dispatches and --help exits 0 with new content)
out=$(bin/fw vendor self --help 2>&1); echo "$out" | grep -q "fw vendor self" && echo "$out" | grep -q "T-2095"
# --no-self-vendor flag advertised
out=$(bin/fw upgrade --help 2>&1); echo "$out" | grep -q "no-self-vendor" && echo "flag advertised"
# Bats coverage
bats tests/unit/t2095_upgrade_self_vendor_extraction.bats
# Sibling regression net (4 suites)
bats tests/unit/upgrade_fresh_machine_simulation.bats
bats tests/unit/t2093_upgrade_strict_exit_codes.bats
bats tests/unit/t2094_upgrade_preflight_doctor_advisory.bats
bats tests/unit/t2232_durable_in_consumer_upgrade.bats
# Reviewer (markdown output — .* between : and verdict absorbs bold asterisks)
out=$(bin/fw reviewer T-2095 --no-write 2>&1); echo "$out" | grep -qE "Overall:.*(PASS|CONCERN)" && ! echo "$out" | grep -q "Overall:.*FAIL"

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

## Recommendation

**Recommendation:** GO

**Rationale:** V1-D closes T-2078 §F2's *organisational* concern (self-vendor logic conflated with do_upgrade's consumer-upgrade flow) and *delivers the path-to-default-flip* without changing default behaviour. Pure refactor + new public verb + opt-out flag — T-1217's invariant is preserved on every developer machine (the inline call still runs by default), so this slice ships zero behavioural regression. The §F2 *N×M redundancy* concern is structurally addressable now (operators wire `fw vendor self` into pre-push, then add `--no-self-vendor` to their consumer-upgrade scripts) and the default-flip ("inline call removed; pre-push is the sole entry") becomes a low-risk follow-on once field telemetry confirms the verb is in use. Tested with 33/33 PASS across the V1-ladder regression net; reviewer PASS. V1 ladder (T-2092 → T-2093 → T-2094 → T-2095) is complete with this slice.

**Evidence:**
- **Helper extraction:** `lib/upgrade.sh` — `_self_vendor_libs()` function with `$dry_run` arg; inline call site at `do_upgrade` body now reads `_self_vendor_libs "$dry_run"` (gated on `[ "$no_self_vendor" = true ]`).
- **New subcommand:** `bin/fw vendor self` routes to `_self_vendor_libs`; `--dry-run` passthrough; `--help` documents the verb and the T-1217/T-2078/T-2095 lineage.
- **New flag:** `--no-self-vendor` on `fw upgrade` — opt-out, advertised in `--help`, prints `Self-vendor skipped (--no-self-vendor)` when active.
- **Test net:** `tests/unit/t2095_upgrade_self_vendor_extraction.bats` 8/8 PASS first run; sibling regression suites (fresh-machine, T-2093, T-2094, T-2232) 25/25 PASS — total **33/33 across V1 ladder**.
- **Reviewer:** R-070694d5 — Overall: PASS, Findings: none, Needs Human: no.
- **Manual confirmation:** `bin/fw vendor self --dry-run` → 12 files would sync from current `FRAMEWORK_ROOT/lib/` to `.agentic-framework/lib/` — the new verb successfully exercises the existing T-1217 invariant outside the do_upgrade flow.

**V1 ladder — COMPLETE after this slice:**

| Slice | Concerns | Task | Status |
|-------|----------|------|--------|
| V1-A  | F3 (docker live-sim coverage) | T-2092 | SHIPPED |
| V1-B  | F4 / F5 / F6 (exit-code discipline) | T-2093 | SHIPPED |
| V1-C  | F8 / F10 (pre-flight + doctor advisory) | T-2094 | SHIPPED |
| V1-D  | F2 (self-vendor extraction) | **T-2095** | **SHIPPED (this slice)** |
| Out-of-ladder | T-1542 (durable in-consumer upgrade) | T-2232 | SHIPPED |

**V2 territory (gated on V1 field telemetry):**
- F1 / F13 / F15 — step-driver refactor (substantial, deferred per T-2078 O1)
- §F2 default-flip — remove inline self-vendor call once pre-push wiring is in field use

**Follow-on operator actions for §F2 N×M closure (not blocking this slice's GO):**
1. Wire `bin/fw vendor self` into framework's `.git/hooks/pre-push` (one-line: `bin/fw vendor self --dry-run > /dev/null || bin/fw vendor self`)
2. Add `--no-self-vendor` to any consumer-upgrade cron / scripts on developer machines that have wired the above
3. After observation in field, file V2 task to flip the default (remove inline call entirely)

**Ring20-dashboard recovery (still awaiting operator-call):** Option A (one-shot cross-machine from this host with `--from-upstream` — destructive cross-machine shape, needs explicit GO) vs Option B (one-line yaml edit on ring20 host). Documented in T-2232 Recommendation.

## Updates

### 2026-05-29T11:58:39Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2095-v1-d-fw-upgrade-self-vendor-extraction-i.md
- **Context:** Initial task creation

### 2026-06-06T13:27:33Z — status-update [task-update-agent]
- **Change:** horizon: later → now

### 2026-06-06T16:26:19Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-06-06T16:33:03Z — status-update [task-update-agent]
- **Change:** status: started-work → captured

### 2026-06-06T20:24:04Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-1d3b0bcc
- **Timestamp:** 2026-06-06T20:34:41Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-06T20:34:26Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
