---
id: T-2099
name: "fork-bomb fix: lib/upgrade.sh handoff + bin/fw resolve_framework FRAMEWORK_ROOT pass-through (SEV-1)"
description: >
  SEV-1 dispatch from /opt/termlink agent. fw upgrade from a consumer auto-clones upstream then re-invokes the cloned bin/fw without scoping FRAMEWORK_ROOT/PROJECT_ROOT — the cloned fw re-resolves to the consumer's vendored copy and infinite-recurses. Two-line fix: env-scope the handoff + respect caller-supplied FRAMEWORK_ROOT in resolve_framework.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [fw-upgrade, reliability, sev-1, fork-bomb, T-2078-cluster]
components: []
related_tasks: [T-2078, T-2092, T-2093, T-2094, T-2095, T-2097, T-2098]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-29T14:22:00Z
last_update: 2026-05-29T14:25:16Z
date_finished: 2026-05-29T14:25:16Z
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

# T-2099: fork-bomb fix: lib/upgrade.sh handoff + bin/fw resolve_framework FRAMEWORK_ROOT pass-through (SEV-1)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `lib/upgrade.sh` handoff line uses `env FRAMEWORK_ROOT=... PROJECT_ROOT=... "$_tmpd/fw/bin/fw"` instead of bare invocation
- [x] `bin/fw` resolve_framework site is gated on `[ -z "${FRAMEWORK_ROOT:-}" ]` (caller-supplied root wins)
- [x] `bash -n` clean on both `bin/fw` and `lib/upgrade.sh`
- [x] `bin/fw version` runs without recursion (smoke test exits in <1s)
- [x] `FRAMEWORK_ROOT=/some/path bin/fw version` honours the caller-supplied root (verifiable via output)
- [x] Both files cite T-2099 in inline comments at the modified site

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

# AC1: lib/upgrade.sh handoff is env-scoped
grep -qE 'env FRAMEWORK_ROOT="\$_tmpd/fw" PROJECT_ROOT="\$target_dir"' lib/upgrade.sh

# AC2: bin/fw resolve_framework is gated on caller-supplied FRAMEWORK_ROOT
grep -qE 'if \[ -z "\$\{FRAMEWORK_ROOT:-\}" \]; then' bin/fw

# AC3: syntax clean
bash -n bin/fw
bash -n lib/upgrade.sh

# AC4: bin/fw version runs without recursion (smoke — must complete in <5s)
timeout 5 bin/fw version > /tmp/.fw-version.out 2>&1; grep -qE "^fw v[0-9]" /tmp/.fw-version.out

# AC5: caller-supplied FRAMEWORK_ROOT is honoured (pass-through smoke)
FRAMEWORK_ROOT=/opt/999-Agentic-Engineering-Framework timeout 5 bin/fw version > /tmp/.fw-version-pt.out 2>&1; grep -qE "Framework: /opt/999" /tmp/.fw-version-pt.out

# AC6: T-2099 cited at the modified sites
grep -q "T-2099 (fork-bomb fix, SEV-1)" lib/upgrade.sh
grep -q "T-2099 (fork-bomb fix, SEV-1)" bin/fw

rm -f /tmp/.fw-version.out /tmp/.fw-version-pt.out

## RCA

**Symptom:** `fw upgrade` from a consumer fork-bombs. Forensic evidence from /opt/termlink: 2 incidents in 1 hour, dozens of nested `bin/bash <tmpdir>/fw/bin/fw upgrade <consumer>` processes, load avg climbing, /tmp filling with `fw-upstream-*` clone tempdirs.

**Root cause:** Two-step interaction between two pre-existing mechanisms:
1. `lib/upgrade.sh:310` (the bare-from-consumer auto-clone handoff, T-1634) re-invokes `"$_tmpd/fw/bin/fw"` WITHOUT scoping `FRAMEWORK_ROOT` or `PROJECT_ROOT`.
2. `bin/fw:498` unconditionally re-runs `resolve_framework`, which (per T-498 preference rule at bin/fw:119-122) picks the **CONSUMER's** vendored copy because `PROJECT_ROOT == consumer`.
3. Cloned fw's `lib/upgrade.sh:222` therefore re-fires the same `_fw_root_canon == _consumer_vendor_canon` check → another auto-clone → infinite recursion.

**Why structurally allowed:** T-1634 (the bare-from-consumer auto-clone milestone) shipped without an integration test exercising the handoff. The cross-process FRAMEWORK_ROOT contract was assumed but not pinned. The fresh-machine simulation bats (`tests/unit/upgrade_fresh_machine_simulation.bats`) only exercises the dry-run path — never the live handoff.

**Prevention:**
- **Mechanical (this PR):** lib/upgrade.sh env-scopes the handoff; bin/fw honours caller-supplied FRAMEWORK_ROOT.
- **Structural (already filed):** T-2092 (V1-a) docker-based live-upgrade simulation gate. Once landed, recursion is caught at PR-time, not on production consumers. T-2099 is the live-fire fix; T-2092 closes the class.
- **Triage (this session):** T-2100 inception filed for the consumer-upgrade-test-fix-report prompt — adds panic-stop, recursion sentinel, fork-bomb forensic fields so consumers CONTAIN the bomb before it scales.

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

**Recommendation:** GO (close in flight — 6/6 Agent ACs ticked, smoke tests pass, both sites cite T-2099).

**Rationale:** Active SEV-1 production blast on /opt/termlink consumer. 2-line bounded fix matching the dispatch's recipe. Smoke-tested: `bin/fw version` runs in <1s with no recursion; caller-supplied `FRAMEWORK_ROOT` is honoured. Structural prevention (T-2092 docker live-simulation, T-2100 prompt hardening) filed separately so this PR stays minimal.

**Evidence:**
- `lib/upgrade.sh:310` — env-scoped handoff with T-2099 origin comment
- `bin/fw:498` — caller-supplied FRAMEWORK_ROOT branch with T-2099 origin comment
- Smoke: `fw version` exits cleanly with framework root resolved correctly
- Pass-through smoke: `FRAMEWORK_ROOT=/path fw version` honours caller env
- Pre-existing recipe from /opt/termlink's T-1699 forensic trail (dispatched via framework.upgrade.report TermLink topic on hubs 141/122/121/107)

**Reply envelope:** post to `framework.upgrade.fix.shipped` on same hubs with msg-type=artifact, metadata.task_id=T-2099, metadata.commit=<this commit SHA> — consumer (/opt/termlink) can then verify before re-running fw upgrade.

## Decisions

### 2026-05-29 — Single-site fix in bin/fw (line 498), not all 3 resolve_framework call sites

- **Chose:** Apply the `[ -z "${FRAMEWORK_ROOT:-}" ]` gate ONLY at bin/fw:498 (universal entry point).
- **Why:** That's where the recursion takes hold. Lines 391 and 479 are inside conditional init branches (non-TTY auto-init, explicit `fw init`) — different code path, not in the fork-bomb chain. Minimal-blast-radius fix.
- **Rejected:** Gate all 3 sites. Premature; only line 498 is in the failing path; adding env-respect to init paths risks behavioural surprises.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-29T14:22:00Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2099-fork-bomb-fix-libupgradesh-handoff--binf.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ab9138ac
- **Timestamp:** 2026-05-29T14:25:17Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** yes
- **Findings:** none

- **Layer-1 escalations:** 1
  1. **destructive-action** (high) — Destructive operation in verification or AC
     - matched: `rm -f`

### 2026-05-29T14:25:16Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
