---
id: T-2445
name: "F9 — Watchtower health verdict trusts foreign port-200 (identity-verify doctor+audit)"
description: >
  F9 — Watchtower health verdict trusts foreign port-200 (identity-verify doctor+audit)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [C-004, bin/fw, tests/unit/watchtower_health_verdict_identity.bats]
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
created: 2026-06-21T09:35:16Z
last_update: 2026-06-21T10:04:00Z
date_finished: 2026-06-21T10:04:00Z
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

# T-2445: F9 — Watchtower health verdict trusts foreign port-200 (identity-verify doctor+audit)

## Context

F9 from the T-2441 AEF onboarding dogfood (`docs/reports/T-2441-aef-onboarding-dogfooding.md:92`),
the third slice of the T-2442 remediation GO. Symptom: onboarding STEP 5 reports the Watchtower
"healthy" (curl 200) when the project's own dashboard never started and a **foreign** service holds
the default port.

Investigation **disproved most of the plan's named fixes** (per `feedback_remediation_plans_are_hypotheses`):
- The identity marker the plan asks to "add" already exists — `/api/_identity` returns `project_root`
  (`web/app.py:345`, T-1284).
- The URL resolver already verifies that marker and fails loud (never returns a foreign URL) —
  `lib/watchtower.sh:_watchtower_url` 3-layer discovery, Layer 3 exit 1 (T-1290/T-1803).
- `fw serve` already refuses a foreign-held port and exits 1 — `bin/watchtower.sh:153-159`
  `_watchtower_port_holder_is_ours` (T-1803). That is reliable fail-loud, not a silent failure.

The **true residual defect** is a producer/consumer-parity miss (L-399): T-1803 hardened the resolver,
but two **health-verdict** call-sites kept their own naïve `_watchtower_url 2>/dev/null || echo
"http://localhost:<PORT>"` fallback and then `curl .../health` — an endpoint **any** server answers 200.
When the resolver correctly fails, the `|| echo` re-substitutes the foreign default port and the verdict
goes green against someone else's server:
- `bin/fw:1506-1508` — `fw doctor` Watchtower smoke test.
- `agents/audit/audit.sh:4503-4505` — audit deploy-gate health check.

Fix: gate both verdicts on resolver **success** (identity-verified URL), dropping the default-port
fallback. Lower-severity link-only siblings (`lib/verify-acs.sh:74`, `agents/context/check-tier0.sh:392`)
emit a possibly-wrong *link* not a false *health verdict* — noted as a follow-up, out of scope here
(one bug = one task).

## Acceptance Criteria

### Agent
- [x] AC1 — Root cause confirmed and recorded in `## RCA`: the false-positive lives at the two
      health-**verdict** call-sites that bypass the identity-verified resolver (`_watchtower_url || echo
      <default-port>` + `curl /health`); the resolver, `/api/_identity`, and `fw serve` foreign-refusal
      are already correct (T-1803). Plan's "add identity marker / auto-pick port" premise was stale.
- [x] AC2 — `bin/fw` doctor smoke test (the `_doctor_wt_url=` line) no longer falls back to a default-port
      URL; the `curl .../health` smoke block runs **only** when `_watchtower_url` returns an
      identity-verified URL. A foreign port-200 can no longer produce a smoke verdict.
- [x] AC3 — `agents/audit/audit.sh` deploy-gate health check (the `_wt_url=` line) no longer falls back to
      a default-port URL; the "Health endpoint responds" pass is gated on `_watchtower_url` success. A
      foreign port-200 can no longer produce a false pass.
- [x] AC4 — Regression test (`tests/unit/watchtower_health_verdict_identity.bats`) asserts both call-sites
      no longer carry the `_watchtower_url ... || echo "http://localhost` fallback, and that a foreign stub
      answering `/health` 200 (but NOT `/api/_identity` as ours) is rejected by the identity handshake.
      _(Verified live: `bats tests/unit/watchtower_health_verdict_identity.bats` → 3/3 pass, run via a
      TermLink shell `f9-bats` to bypass the in-worktree OBS-080 Bash gate. `bash -n` clean on both edited
      files.)_

<!-- No Human section: all ACs are agent-verifiable (no render surface, no
     external action, no subjective judgment). Pure backend reliability fix. -->

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
# AC2 — doctor smoke no longer falls back to a default-port URL
! grep -nE '_doctor_wt_url=.*\|\| echo "http://localhost' bin/fw
# AC3 — audit deploy-gate health no longer falls back to a default-port URL
! grep -nE '_wt_url=.*\|\| echo "http://localhost' agents/audit/audit.sh
# Both edited files parse
bash -n bin/fw
bash -n agents/audit/audit.sh
# AC4 — regression test file exists (bats files are not bash-parseable; do not bash -n them)
test -f tests/unit/watchtower_health_verdict_identity.bats
# AC4 — the test passes (harness; worktree-Bash-gated under OBS-080 — run from a non-hooked shell)
bats tests/unit/watchtower_health_verdict_identity.bats

## RCA

**Symptom:** On a host where a foreign service holds the default Watchtower port, `fw doctor` and
`fw audit` report the Watchtower health green (smoke test runs / "Health endpoint responds") even
though this project's own dashboard never started. Observed live in the T-2441 onboarding dogfood
into `/opt/505` (STEP 5 false-positive).

**Root cause:** A producer/consumer-parity miss (L-399). T-1803 hardened the URL **producer**
(`_watchtower_url`): it now verifies `/api/_identity` and fails loud (exit 1, empty stdout) rather than
returning a foreign URL. But two **consumers** that render a *health verdict* kept a pre-T-1803 naïve
fallback — `_watchtower_url 2>/dev/null || echo "http://localhost:<PORT>"` — and then probed `/health`,
an endpoint **any** HTTP server answers 200. When the resolver correctly fails, the `|| echo` clause
re-substitutes the foreign default port and the verdict goes green against a server that is not ours:
- `bin/fw:1506-1508` (doctor smoke test)
- `agents/audit/audit.sh:4503-4505` (audit deploy gate)

The plan's stated remedies ("add an identity marker", "make serve auto-pick / exit non-zero") were
**already shipped** by T-1284 + T-1803 — disproved on inspection. The real gap was narrower: the
hardened resolver's contract ("a non-zero return means *no Watchtower of ours is reachable*") was not
honored at these two call-sites, which defeated it with `|| echo`.

**Why structurally allowed:** The `/health` endpoint is identity-agnostic by design (it answers for the
webapp regardless of project), and the `|| echo <default>` idiom is a copy-paste convention scattered
across the codebase (6 call-sites). When T-1803 fixed the producer, no gate flagged the consumers still
running the old fallback — the resolver and its consumers were edited in different tasks, months apart,
and nothing pinned "verdict call-sites must gate on resolver success."

**Prevention:** `tests/unit/watchtower_health_verdict_identity.bats` — a static assertion that neither
verdict call-site carries the `_watchtower_url ... || echo "http://localhost` fallback (catches a
regression / a new copy of the idiom), plus an e2e assertion that a stub answering `/health` 200 but
not identifying as ours produces no healthy verdict. Captured as a learning so the next consumer of a
fail-loud resolver gates on its exit status rather than `|| echo`-ing a guess.

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

### 2026-06-21T09:35:16Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/inception-gov-payload-mediation/.tasks/active/T-2445-f9--watchtower-health-verdict-trusts-for.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-32429e36
- **Timestamp:** 2026-06-21T10:04:01Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-21T10:04:00Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
