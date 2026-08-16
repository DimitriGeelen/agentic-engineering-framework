---
id: T-2235
name: "build fw consumer-recover wrapper — SSH+TermLink, dry-run-default, sentinel
  idempotency"
description: >
  build fw consumer-recover wrapper — SSH+TermLink, dry-run-default, sentinel idempotency

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [bin/fw, lib/consumer-recover.sh, 
      tests/unit/test_consumer_recover.bats]
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-06-07T12:15:54Z
last_update: '2026-08-16T22:24:58Z'
date_finished: 2026-06-07T12:24:04Z
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
  - ts: '2026-06-11T22:24:12Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:58Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2235: build fw consumer-recover wrapper — SSH+TermLink, dry-run-default, sentinel idempotency

## Context

Build slice for the `fw consumer-recover` wrapper authorised under T-2233 GO (2026-06-07). Full design spec is `docs/reports/T-2233-consumer-recover-design.md` — this task implements §3 (CLI surface), §4 (flow), §5 (transport abstraction), §6 (heredoc), §7 (dry-run output), §8 (tests), and §9 (wire-up).

Purpose: replace the 4-step legacy-consumer recovery recipe (SSH + clone + env-scoped upgrade + cleanup) with one verb. Forward-looking durable fix lives at T-2232; this wrapper handles consumers vendored before T-2232 (and before T-1634).

## Acceptance Criteria

### Agent
- [x] `lib/consumer-recover.sh` exists with `do_consumer_recover()` entrypoint, flag parser for the 6 documented flags (`--apply`, `--upstream`, `--via`, `--keep-temp`, `--dry-run`, `--json`), and 4 exit codes (0/1/2/3) per design §3
- [x] Transport abstraction shipped: inlined as `_cr_remote_exec` / `_cr_remote_script` shell functions in `lib/consumer-recover.sh` (the design's §5 split into separate files was over-engineering for two small functions; same surface, fewer files)
- [x] Dry-run is the DEFAULT — invoking `fw consumer-recover HOST PATH` without `--apply` prints the recipe (with substituted host/path/upstream values) and exits 0; matches sample in design §7
- [x] Sentinel idempotency: if the consumer has `.agentic-framework/.upstream` present and non-empty, wrapper refuses with exit 2 and a redirect to plain `fw upgrade`
- [x] Auto-detect upstream URL from the framework repo's preferred remotes (github first for credential-free canonical mirror, then origin); `--upstream URL` flag overrides; embedded `TOKEN@host` credentials are stripped from URLs before display/execution
- [x] bats tests at `tests/unit/test_consumer_recover.bats` cover the 8 cases in design §8 (plus 6 additional regression cases for credential-strip / --via invalid / --json on refuse / dispatcher wiring); 14/14 PASS via `bats tests/unit/test_consumer_recover.bats`
- [x] `bin/fw` dispatcher routes `consumer-recover` to `lib/consumer-recover.sh:do_consumer_recover`; `fw help` lists it under setup/upgrade
- [x] `fw reviewer T-2235` returns Overall PASS

### Human
<!-- All ACs above are deterministic. No Human AC needed; reviewer + bats provide structural coverage. -->
<!-- Render-surface gate (T-1766): does NOT apply — pure shell library, no web/templates change. -->

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

# Build verification:
test -f lib/consumer-recover.sh && bash -n lib/consumer-recover.sh
# Transport abstraction inlined into lib/consumer-recover.sh (functions
# _cr_remote_exec / _cr_remote_script) — separate transport-*.sh files
# from the design were folded as over-engineering for two small functions.
grep -q "_cr_remote_exec\b" lib/consumer-recover.sh
grep -q "_cr_remote_script\b" lib/consumer-recover.sh
# Test suite (mocked transport, no real SSH/network):
bats tests/unit/test_consumer_recover.bats
# Dispatcher wiring smoke test (--help routes to do_consumer_recover):
out=$(bin/fw consumer-recover --help 2>&1); echo "$out" | grep -q "consumer-recover"
# Reviewer static-scan:
out=$(bin/fw reviewer T-2235 2>&1); echo "$out" | grep -qE "Overall:.*(PASS|CONCERN)" && ! echo "$out" | grep -q "Overall:.*FAIL"

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

## Updates

### 2026-06-07T12:15:54Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2235-build-fw-consumer-recover-wrapper--sshte.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-63c05009
- **Timestamp:** 2026-06-07T12:24:05Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-07T12:24:04Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
