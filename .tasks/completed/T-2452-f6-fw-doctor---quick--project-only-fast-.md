---
id: T-2452
name: "F6: fw doctor --quick — project-only fast mode skipping host/network probes (T-2441 dogfood; doctor ~72s)"
description: >
  F6: fw doctor --quick — project-only fast mode skipping host/network probes (T-2441 dogfood; doctor ~72s)

status: work-completed
workflow_type: build
owner: agent
horizon: null
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
created: 2026-06-21T12:00:27Z
last_update: 2026-06-21T13:17:54Z
date_finished: 2026-06-21T13:17:54Z
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

# T-2452: F6: fw doctor --quick — project-only fast mode skipping host/network probes (T-2441 dogfood; doctor ~72s)

## Context

T-2441 dogfood F6: `fw doctor` takes ~**72s** per run; STEP 4's "fix and re-run" onboarding loop
compounds it (3 calls timed out a 120s budget). Doctor runs the full host+project+network check set
every invocation with no scoped/fast mode. Proposed: `fw doctor --quick` — project-only, skipping the
slow host/network probes (mirror divergence, global-install size, cron host checks, network reachability)
— for the tight onboarding fix-and-rerun loop.

**Pairs with T-2451 (F7):** F7 segments project vs host findings; F6 lets you *skip* the host set
entirely. Implementing F7's `[project]`/`[host]` tagging first makes F6's `--quick` filter a natural
follow-on (skip everything tagged `[host]` + network). Consider sequencing F7 → F6, or doing both in one
slice. `fw doctor` is large (bin/fw ~760-2210) — `--quick` should be a guard around the host/network
check blocks, not a reorganization.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] AC1 — `fw doctor --quick` runs project-scoped checks only, skipping host + network probes; flag is
      documented in `fw doctor --help` / usage. **Done:** `--quick` parsed into `quick_mode`; the
      `_doctor_quick_skip` helper guards 3 network probe blocks (mirror divergence ls-remote,
      litellm/ollama curls, Watchtower smoke test), each emitting a `SKIP … (--quick)` marker. Documented
      in a new `fw doctor --help` handler and the `fw help` doctor line. Live `--quick` emitted the banner
      + 3 SKIP markers + the F7 project verdict.
- [x] AC2 — `--quick` is measurably faster than full doctor. **Done:** live A/B (T-2452 session):
      **quick=44s vs full=150s (3.4×)**. The SKIP markers (asserted in bats) are the omitted-section
      evidence; the wall-clock delta is recorded here (running full doctor in a unit test is the slow,
      network-coupled anti-pattern this very task addresses — see Decisions / the F7/T-2451 lesson).
- [x] AC3 — full `fw doctor` (no flag) is unchanged; existing doctor tests stay green; a new assertion
      pins `--quick` skipping the host/network blocks. **Done:** full mode is the untouched `else` branch
      of each guard — live full run rendered identically (24 project warnings, zero SKIP-leak, exit 0).
      10/10 existing+F7 doctor source pins green; new `t2452_doctor_quick.bats` (5 pins: flag parse,
      helper, ≥3 guards, --help docs, behavioural --quick skip+verdict) all green.

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

bash -n bin/fw
out=$(bats tests/unit/t2452_doctor_quick.bats 2>&1); echo "$out" | grep -qE "^ok 5 " && ! echo "$out" | grep -q "^not ok"
grep -qE "\-\-quick\) quick_mode=1" bin/fw
test "$(grep -cE 'if _doctor_quick_skip ' bin/fw)" -ge 3

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

### 2026-06-21 — `--quick` skips network probes via guard wrappers, not a full reorder
- **Chose:** a `quick_mode` flag + `_doctor_quick_skip` helper that wraps the 3 slowest host/network
  probe blocks (mirror divergence ls-remote, litellm/ollama curls, Watchtower smoke test) in
  `if _doctor_quick_skip "label"; then :; else <original block>; fi`. Each emits a `SKIP … (--quick)` line.
- **Why:** additive, low-blast (the original blocks are untouched in the `else` branch), and targets the
  measured cost — the mirror `ls-remote` (two `timeout 10` calls) is the dominant sink. quick=44s vs
  full=150s. The remaining 44s is project-scope work (fabric/secret/workflow-lint scans) that legitimately
  belongs in a project-health scan, so it stays.
- **Rejected:** (a) a full project-first/host-last reorder of `do_doctor` (~1450 lines — high blast, the
  task's scope note forbids it); (b) skipping ALL host-tagged `_doctor_warn_host` checks — those are cheap
  (command-existence tests), so skipping them adds no speed and loses useful project-adjacent signal.

### 2026-06-21 — Test --quick behaviourally once; record the full/quick delta, don't run full in bats
- **Chose:** 4 source-level pins (flag parse, helper, ≥3 guards, --help docs) + 1 behavioural `--quick`
  run (~44s) asserting SKIP markers + verdict. The full-vs-quick wall-clock delta (44s vs 150s) is
  recorded in AC2, not asserted by running full doctor in the test.
- **Why:** running full `fw doctor` (~150s, network-coupled) in a unit test is exactly the slowness this
  task fixes — and it blew bats timeouts in the sibling T-2451. The SKIP markers ARE the omitted-section
  proof; the helper structurally guarantees they only fire under `--quick`.
- **Rejected:** a timed A/B inside bats (would run full doctor — 150s, flaky, self-defeating).

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-06-21T12:00:27Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/inception-gov-payload-mediation/.tasks/active/T-2452-f6-fw-doctor---quick--project-only-fast-.md
- **Context:** Initial task creation

### 2026-06-21T12:01:13Z — status-update [task-update-agent]
- **Change:** status: started-work → captured
- **Change:** horizon: now → next

### 2026-06-21T13:04:56Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-e0829cc0
- **Timestamp:** 2026-06-21T13:18:37Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-21T13:17:54Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
