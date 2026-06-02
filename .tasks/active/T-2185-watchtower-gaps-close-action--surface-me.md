---
id: T-2185
name: "Watchtower /gaps Close action — surface mechanical-gauge-READY gaps as one-click closure"
description: >
  Add server + UI surface so /gaps shows a Close button for status=watching gaps whose status_notes specify a mechanical closure gauge that currently reports READY. Discovered live in operator session 2026-06-02: G-064 closure gauge (tools/g064-readiness.py) reports VERDICT=READY (12 cron firings ≥3 threshold) but /gaps renders gap entries read-only; operator cannot close even when their own prior decision (the gauge mechanism) authorised the closure. Recurring class — any gap with a mechanical-gauge closure contract will hit this same dead end. Build: POST /gaps/<id>/close handler that flips status: watching → closed + sets closed_date + closure_notes; UI surface on /gaps page renders Close button only for entries where status_notes specifies a gauge AND the gauge reports READY (or operator-override path with rationale logged); audit trail entry written. Render-surface — needs [REVIEW] Human AC.

status: captured
workflow_type: build
owner: agent
horizon: next
tags: []
components: []
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-06-02T21:02:45Z
last_update: 2026-06-02T21:05:03Z
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

# T-2185: Watchtower /gaps Close action — surface mechanical-gauge-READY gaps as one-click closure

## Context

Origin: live operator session 2026-06-02. T-2184 surfaced OBS-048 (G-064 closure-readiness gauge VERDICT=READY, 12 cron firings ≥3 threshold) with a handoff doc pointing the operator at `/gaps`. Operator opened the page and reported: *"ok located it but there is nothing i as operator can do ??"* — the page renders gap entries as read-only text, `bin/fw gaps` CLI is also read-only, and there is no closure surface at all.

Two structural gaps revealed in one observation:
1. **No closure surface on `/gaps`** — the page lists `status: watching` gaps with closure-readiness signals (the CLI already prints `Closure: READY (12/3)` for G-064) but exposes no action.
2. **No CLI verb** — `fw gaps` is purely read; there is no `fw gaps close <id>` or equivalent.

This is **recurring class, not one-off**: any gap whose `status_notes:` specifies a mechanical closure gauge (per T-1750 contract) and reports READY will hit the same dead end. G-064 is the first; future gaps with this pattern will be the second, third, fourth.

**Alternative considered + rejected this turn:** Path A (agent edits `concerns.yaml` directly per L-329 propagation-of-authorised-decisions). Operator chose Path B (build the surface). Rationale: solves the class, not just the one instance.

**Filed and ACs locked, build deferred to next session.** Reason: ≥6 ACs touching Flask blueprint, audit trail, render-surface (T-1766 P-013 mandates [REVIEW] Human AC), Playwright test, fw doctor check, and a CLI verb. Started here at 72% budget — per CLAUDE.md work-proposal rule, building this slice at 75-85% urgent risks partial-state regression on a render-touching surface. ACs are stable; pickup in a fresh session is clean.

Predecessors: T-2184 (closed — fabric enrich + OBS-048 handoff). Related: T-1750 (gauge mechanism + status_notes closure-contract), T-2169 (retire_when audit advisory that fires F-ORCH retirement on G-064 close — cascade dependency).

## Acceptance Criteria

### Agent
- [ ] `web/blueprints/gaps.py` POST handler `/gaps/<gap_id>/close` exists: parses gap_id, loads `.context/project/concerns.yaml`, validates the gap is currently `status: watching` (refuses already-closed gaps with 409), runs the mechanical gauge if `status_notes:` specifies one (search for `python3 tools/<name>-readiness.py` shape), refuses with 412 if gauge is NOT_READY unless `--override` rationale is supplied, writes `status: closed` + `closed_date: <today>` + `closure_notes: <auto or operator-supplied>` back to YAML atomically (load → mutate → `os.replace`), returns JSON `{ok: true, gap_id, new_status}`, logs the close to `.context/audits/gap-closures.jsonl`.
- [ ] Render surface: `/gaps` page renders a "Close" button next to each `status: watching` gap, disabled when gauge=NOT_READY (or gauge-not-specified) with hover-tooltip explaining why, enabled when gauge=READY. Button POSTs to the handler via htmx with confirmation modal asking for `closure_notes` (auto-populated if gauge specifies notes contract). Page state refreshes inline on 200.
- [ ] CLI verb `bin/fw gaps close <gap_id> [--rationale "..."]` calls the same code path as the POST handler (shared lib in `lib/gaps.py`). `bin/fw gaps close` without args lists closure-eligible gaps and prompts for selection (or refuses non-interactive).
- [ ] `bin/fw doctor` check: WARN when ≥1 gap has `status: watching` AND status_notes specifies a gauge AND that gauge reports READY for ≥7 days (operator-procrastination signal; mirror of OBS-048-class).
- [ ] bats unit test (`tests/unit/gaps_close.bats`) — covers: happy-path close on gauge-READY, refuse on already-closed, refuse on gauge-NOT_READY, override path with rationale logged, atomic YAML write does not corrupt other gap entries.
- [ ] Playwright test (`tests/playwright/test_gaps_close.py`) — page loads, Close button visible on G-064-style mock gap, click triggers modal, submit calls POST and the gap row updates inline; disabled-state hover-tooltip present for NOT_READY mocks.
- [ ] Consumer-fresh simulation green (`tests/unit/upgrade_fresh_machine_simulation.bats` 3/3 PASS).

### Human
- [ ] [REVIEW] The Close button + modal layout reads cleanly on `/gaps` — visual hierarchy correctly subordinates the action to the gap entry, gauge-READY/NOT_READY indicator is unambiguous at a glance, modal confirmation is not jarring or excessive friction for the routine case.
  **Steps:**
  1. Open `http://192.168.10.107:3000/gaps` (operator's primary host)
  2. Locate a `status: watching` gap; observe button visibility + state
  3. Click; observe modal; submit; observe inline refresh
  4. Close the gap that's gauge-NOT_READY (should refuse with helpful message)
  **Expected:** layout reads clean, action is obvious, no surprise modals or scroll jumps
  **If not:** screenshot the awkward state and note paragraphs/elements needing rework

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

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-06-02T21:02:45Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2185-watchtower-gaps-close-action--surface-me.md
- **Context:** Initial task creation

### 2026-06-02T21:05:03Z — status-update [task-update-agent]
- **Change:** status: started-work → captured
- **Change:** horizon: now → next
