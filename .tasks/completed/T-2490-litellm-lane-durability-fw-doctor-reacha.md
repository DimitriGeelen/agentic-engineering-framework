---
id: T-2490
name: "litellm lane durability: fw doctor reachability check + systemd unit (T-1700/T-2487
  follow-up)"
description: >
  litellm lane durability: fw doctor reachability check + systemd unit (T-1700/T-2487
  follow-up)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [bin/fw]
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
created: 2026-06-24T19:21:05Z
last_update: '2026-08-16T22:25:07Z'
date_finished: 2026-06-24T19:29:43Z
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
  - ts: '2026-08-16T22:25:07Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal);
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2490: litellm lane durability: fw doctor reachability check + systemd unit (T-1700/T-2487 follow-up)

## Context

The litellm `:4000` lane (T-2487) is the local-model worker runtime. `fw doctor`
already HAS a litellm/ollama reachability check (bin/fw:1655-1683, T-1700) — but it
is **buggy**: it curls `/health`, which litellm serves as an auth-required endpoint
returning **HTTP 401**, so `curl -sf` (the `-f` flag) treats it as a failure and
emits a **false WARN "litellm-proxy not reachable" even when the proxy is fully up**.
The working liveness endpoint is `/health/liveliness` (HTTP 200, no auth). This task
fixes the false-negative, makes the port configurable, and adds the missing
persistence leg (systemd unit) so the proxy survives reboot.

## Acceptance Criteria

### Agent
- [x] Fix the litellm doctor false-WARN: the check curls `/health/liveliness`
      (HTTP 200, no auth) instead of `/health` (401 → `curl -f` false-negative). Port
      honors `FW_LITELLM_PORT` (default 4000); start-hint text updated (names the
      systemd unit). `bash -n bin/fw` clean. (bin/fw:1655-1672)
- [x] Regression test `tests/unit/t2490_litellm_doctor.bats` green (3/3): (a) structural —
      the litellm check targets `/health/liveliness`, not bare `/health`; (b) functional —
      against a stub HTTP server, `curl -sf .../health/liveliness` (200) succeeds where
      `curl -sf .../health` (401) fails, proving the endpoint choice was the bug;
      (c) the systemd unit ships Restart + liveliness probe.
- [x] Committed systemd unit `deploy/litellm-proxy.service` (`Restart=on-failure`,
      runs the proxy with `.context/litellm-config.yaml` on port 4000, ExecStartPost
      liveliness probe); enable command documented in the unit header and the doctor hint
      (`sudo systemctl enable --now litellm-proxy`).
- [x] Live: with the proxy up, the exact doctor conditional yields
      `OK  litellm-proxy reachable (http://localhost:4000)` — the false WARN is gone
      (verified: `/health/liveliness`→200, old `/health`→401 fails under `-sf`).

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

bats tests/unit/t2490_litellm_doctor.bats
bash -n bin/fw
grep -q 'health/liveliness' bin/fw
test -f deploy/litellm-proxy.service

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

**Symptom:** `fw doctor` would emit a host WARN "litellm-proxy not reachable on
http://localhost:4000" even when the proxy was fully up and serving requests
(proven the same session: `/v1/chat/completions` returned a real completion).

**Root cause:** The check (bin/fw:1663, T-1700) ran `curl -sf --max-time 2
http://localhost:4000/health`. litellm serves `/health` as an **auth-required**
endpoint — without an API key it returns **HTTP 401**. `curl -f` treats any 4xx as
a failure (non-zero exit), so the `if curl -sf …/health` branch took the `else`
(WARN) path regardless of proxy health. The unauthenticated liveness probe is
`/health/liveliness` (HTTP 200). Endpoint behaviour confirmed live: `/health`→401,
`/health/liveliness`→200, `/health/readiness`→200.

**Why structurally allowed:** The check was authored (T-1700) against an assumed
`/health` endpoint and never exercised end-to-end against a live litellm — the lane
itself only came up this session (T-2487). A health *check* that was never run
against a healthy target shipped a guaranteed false-negative. Same class as OBS-088 /
OBS-087 / PL-014: substrate authored ahead of first real use carries blind spots that
only surface when the thing finally runs.

**Prevention:** (1) Fixed endpoint → `/health/liveliness`; port via `FW_LITELLM_PORT`.
(2) `tests/unit/t2490_litellm_doctor.bats` pins it two ways: a structural guard
(the check targets `/health/liveliness`, not bare `/health`) so a revert is caught,
and a functional guard against an auth-mirroring stub proving `-sf` distinguishes
401 from 200. (3) systemd unit's `ExecStartPost` probes `/health/liveliness` too, so
the persistence path uses the same correct endpoint.

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

### 2026-06-24T19:21:05Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/inception-gov-payload-mediation/.tasks/active/T-2490-litellm-lane-durability-fw-doctor-reacha.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-79d33329
- **Timestamp:** 2026-06-24T19:29:45Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-24T19:29:43Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
