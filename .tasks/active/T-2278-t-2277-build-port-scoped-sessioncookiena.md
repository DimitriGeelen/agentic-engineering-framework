---
id: T-2278
name: "T-2277 build: port-scoped SESSION_COOKIE_NAME (Candidate 1, Leg A) — eliminates cross-Watchtower CSRF pollution"
description: >
  T-2277 build: port-scoped SESSION_COOKIE_NAME (Candidate 1, Leg A) — eliminates cross-Watchtower CSRF pollution

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
created: 2026-06-09T08:37:19Z
last_update: 2026-06-09T08:40:55Z
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

# T-2278: T-2277 build: port-scoped SESSION_COOKIE_NAME (Candidate 1, Leg A) — eliminates cross-Watchtower CSRF pollution

## Context

Build child of T-2277 (inception, GO). Implements Candidate 1, Leg A —
sets `app.config["SESSION_COOKIE_NAME"] = f"fw_session_{Config.PORT}"`
in `web/app.py` so each Watchtower instance writes to its own browser
cookie slot. Eliminates the cross-instance session-cookie pollution
class documented in `docs/reports/T-2277-watchtower-csrf-pollution.md`.

## Acceptance Criteria

### Agent
- [x] `web/app.py` sets `SESSION_COOKIE_NAME = f"fw_session_{Config.PORT}"` after `app = Flask(...)`
- [x] `tests/unit/test_csrf_cookie_scoping.py` exists with ≥3 tests covering: (a) cookie name format, (b) two apps with different ports produce distinct names, (c) idempotency (same port → same name)
- [x] `python3 -m pytest tests/unit/test_csrf_cookie_scoping.py -q` exits 0
- [x] Existing `tests/unit/test_csrf*` suite still passes (no regression)
- [x] `bin/fw reviewer T-2278` returns PASS

### Human
- [ ] [REVIEW] Confirm cookie-rename has no functional impact on the AEF Watchtower at :3000
  **Steps:**
  1. Open http://192.168.10.107:3000 in a browser AFTER this ships and Watchtower restarts.
  2. Open DevTools → Application → Cookies → http://192.168.10.107:3000.
  3. Verify there is a cookie named `fw_session_3000` (and NOT just `session`).
  4. Try clicking GO on any open inception (e.g. /inception/T-2279).
  **Expected:** Cookie named `fw_session_3000` is present. GO submit completes (decision recorded) without 403.
  **If not:** Hard-reload the page (Ctrl+Shift+R) once to mint a fresh token, retry. If still failing, capture the cookie value + retry and report.

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

grep -q 'SESSION_COOKIE_NAME.*fw_session_' web/app.py
test -f tests/unit/test_csrf_cookie_scoping.py
out=$(python3 -m pytest tests/unit/test_csrf_cookie_scoping.py -q 2>&1); echo "$out" | grep -q "passed"
out=$(bin/fw reviewer T-2278 2>&1); echo "$out" | grep -qE "Overall:.*PASS"

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

### 2026-06-09T08:37:19Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2278-t-2277-build-port-scoped-sessioncookiena.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-38a6b153
- **Timestamp:** 2026-06-09T08:43:44Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
