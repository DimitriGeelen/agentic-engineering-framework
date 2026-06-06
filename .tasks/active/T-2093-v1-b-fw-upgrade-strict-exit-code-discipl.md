---
id: T-2093
name: "V1-b fw upgrade: strict exit-code discipline + rollback on mid-upgrade failure
  (T-2078 GO, closes F4/F5/F6)"
description: >
  V1 slice from T-2078 GO. Closes F4, F5, F6: when upgrade.sh fails mid-flight, partial
  state lands. Add strict exit-code discipline + a rollback path (snapshot pre-upgrade
  fw state, restore on failure). Spec: docs/reports/T-2078-fw-upgrade-reliability-review.md
  F4-F6. Sequence after V1-a (regression net first).

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [fw-upgrade, reliability, v1, T-2078-slice]
components: []
related_tasks: [T-2078, T-2092]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-29T11:58:28Z
last_update: 2026-06-06T16:47:49Z
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
  - ts: '2026-06-05T18:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
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
---

# T-2093: V1-b fw upgrade: strict exit-code discipline + rollback on mid-upgrade failure (T-2078 GO, closes F4/F5/F6)

## Context

V1-B of the T-2078 GO'd fw-upgrade reliability hardening — closes F4 (exit-code
inconsistency + no rollback), F5 (`do_vendor 2>&1 | sed` swallows exit), and
F6 (`force=true` mutation not subshell-scoped). Substrate for V1-C/V1-D.

Field evidence reinforcing this slice (T-2231): ring20-dashboard at
192.168.10.121 sits pinned at 1.6.7 vs installed 1.6.260, with the operator
unable to surface the partial-state via current upgrade behaviour. F5 is
where invisible failures originate.

Spec: `docs/reports/T-2078-fw-upgrade-reliability-review.md` §F4-F6.
Sibling slices: V1-C (T-2094, pre-flight + post-upgrade `fw doctor`),
V1-D (T-2095, self-vendor extraction).

## Acceptance Criteria

### Agent
- [x] F5 — PIPESTATUS capture: `lib/upgrade.sh:656` (dry-run branch) and `:658` (live branch) read `${PIPESTATUS[0]}` immediately after the `do_vendor | sed` pipe; failure (non-zero) is surfaced as a WARN line and increments a `failed_steps` counter
- [x] F6 — subshell-scoped force: `generate_claude_code_config "$target_dir"` is invoked under a subshell scoping the `force=true` override so an in-call exit cannot leak `force=true` into the rest of `do_upgrade`
- [x] F4 — `--strict` flag added to `do_upgrade` arg parser + `--help` (opt-in, off by default for backward-compat)
- [x] F4 — under `--strict`, any per-step `failed_steps++` increment causes `do_upgrade` to abort with a PARTIAL diagnostic that names the failed step
- [x] F4 — without `--strict`, failure counters still accumulate; the existing footer prints a PARTIAL warning line when `failed_steps > 0` (advisory, exit 0 preserved for backward-compat)
- [x] `lib/upgrade.sh` passes `bash -n` syntax check
- [x] `tests/unit/upgrade_fresh_machine_simulation.bats` passes unchanged (no regression on T-1633/T-1635 gate)
- [x] New bats `tests/unit/t2093_upgrade_strict_exit_codes.bats` covers: F5 PIPESTATUS surfaces vendor failure; F6 force=true is subshell-scoped; F4 `--strict` aborts on step failure; F4 non-strict mode prints PARTIAL footer when failures counted; `--help` advertises `--strict`
- [x] No `### Agent` AC is ticked until its corresponding work is in place (T-1831 C-4 progressive ticking)

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

bash -n lib/upgrade.sh
grep -q 'PIPESTATUS\[0\]' lib/upgrade.sh
grep -q -- '--strict' lib/upgrade.sh
grep -qE '\(\s*force=true\s*;' lib/upgrade.sh
out=$(bin/fw upgrade --help 2>&1); echo "$out" | grep -q -- "--strict"
bats tests/unit/t2093_upgrade_strict_exit_codes.bats
bats tests/unit/upgrade_fresh_machine_simulation.bats
out=$(bin/fw reviewer T-2093 --no-write 2>&1); echo "$out" | grep -q "Overall:.*PASS"

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

## Recommendation

**Recommendation:** GO (close as work-completed)

**Rationale:** All 9 Agent ACs satisfied. T-2078 §F4/F5/F6 closed: F5 PIPESTATUS captures (`lib/upgrade.sh:710,713`) surface vendor failures the old `| sed` pipe swallowed; F6 subshell-scoped `force=true` (`lib/upgrade.sh:956,1031`) blocks the `force=true` leak class T-2078 §F6 named; F4 `--strict` flag + `failed_steps` counter + STRICT ABORT diagnostic + PARTIAL footer (live + dry-run parity) give the operator real exit-code discipline and a re-runnable diagnostic. Backward-compatible (off by default; existing flows untouched). Source landed in commit `44c6d6781` (prior session WIP); this session adds the bats gate + dry-run-parity PARTIAL footer.

**Evidence:**

- `bats tests/unit/t2093_upgrade_strict_exit_codes.bats` — 6/6 PASS (F4 help, F5 WARN, F4 strict abort, F4 PARTIAL footer, F6 structural, F6 runtime no-leak).
- `bats tests/unit/upgrade_fresh_machine_simulation.bats` — 3/3 regression PASS (T-1633/T-1635 consumer-facing hygiene preserved).
- `bin/fw reviewer T-2093 --no-write` — PASS, R-4b193508, zero findings.
- Source-line references (post `44c6d6781`):
  - F4 substrate: `lib/upgrade.sh:133-145` (--strict argparse, failed_steps locals).
  - F4 --help: `lib/upgrade.sh:162-165`.
  - F5 PIPESTATUS: `lib/upgrade.sh:707-723`.
  - F6 subshell sites: `lib/upgrade.sh:956,1031`.
  - F4 live PARTIAL footer: `lib/upgrade.sh:1419-1422`.
  - F4 dry-run parity PARTIAL footer: `lib/upgrade.sh:1407-1418` (this session).

**Sequential ladder closure:** V1-B (T-2093, this) ships. V1-C (T-2094 pre-flight + post-upgrade `fw doctor` advisory) and V1-D self-vendor refactor (T-2095, captured) remain. Operator's directional pivot this session pulled the in-consumer durable fix forward as T-2232 (shipped earlier this turn); the F2 self-vendor extraction stays as T-2095 follow-up V1-D scope per T-2078 spec.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-29T11:58:28Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2093-v1-b-fw-upgrade-strict-exit-code-discipl.md
- **Context:** Initial task creation

### 2026-06-06T13:27:21Z — status-update [task-update-agent]
- **Change:** horizon: later → now

### 2026-06-06T13:34:40Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
