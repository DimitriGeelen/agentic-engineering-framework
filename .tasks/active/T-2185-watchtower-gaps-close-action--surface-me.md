---
id: T-2185
name: "Watchtower /gaps Close action — surface mechanical-gauge-READY gaps as one-click
  closure"
description: >
  Add server + UI surface so /gaps shows a Close button for status=watching gaps whose
  status_notes specify a mechanical closure gauge that currently reports READY. Discovered
  live in operator session 2026-06-02: G-064 closure gauge (tools/g064-readiness.py)
  reports VERDICT=READY (12 cron firings ≥3 threshold) but /gaps renders gap entries
  read-only; operator cannot close even when their own prior decision (the gauge mechanism)
  authorised the closure. Recurring class — any gap with a mechanical-gauge closure
  contract will hit this same dead end. Build: POST /gaps/<id>/close handler that
  flips status: watching → closed + sets closed_date + closure_notes; UI surface on
  /gaps page renders Close button only for entries where status_notes specifies a
  gauge AND the gauge reports READY (or operator-override path with rationale logged);
  audit trail entry written. Render-surface — needs [REVIEW] Human AC.

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
created: 2026-06-02T21:02:45Z
last_update: 2026-06-03T22:28:10Z
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
bvp_scores_proposed:
  - ts: '2026-06-02T21:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 2
      F-RECALL: 0
      F-ORCH: 1
    rationale: "D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); F-RECALL=0
      (no-signal); F-ORCH=1 (body/tag hits for 'F-ORCH': 1)"
    rubric_sha: e4a00f38e801
  - ts: '2026-06-03T21:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 2
      F-RECALL: 2
      F-ORCH: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-ORCH=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-06-02T21:15:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
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
- [x] `web/blueprints/discovery.py` POST handler `/gaps/<gap_id>/close` exists (lives on the existing discovery blueprint per `/gaps` GET handler's home): parses gap_id, loads `.context/project/concerns.yaml`, validates the gap is currently `status: watching` (refuses already-closed gaps with 409), runs the mechanical gauge from `closure_check_command:` (T-1752 canonical field, not status_notes prose), refuses with 412 if gauge is NOT_READY or UNKNOWN unless `override=true` + `rationale` is supplied, writes `status: closed` + `closed_date: <today>` + `closure_notes: <auto or operator-supplied>` back to YAML atomically (text-surgical block rewrite, NOT load-dump — comments preserved — then `os.replace`), returns JSON `{ok: true, gap_id, new_status, verdict, closed_date, closure_notes, audit_path}`, logs the close to `.context/audits/gap-closures.jsonl`. HTMX-aware: returns HTML fragment when `HX-Request` header present.
- [x] Render surface: `/gaps` page renders a "Close" button next to each `status: watching` gap with `closure_check_command:` configured, disabled when gauge=NOT_READY/UNKNOWN with hover-tooltip explaining why, enabled when gauge=READY. Button POSTs to the handler via htmx (`hx-confirm` modal asking for confirmation, gauge verdict displayed in the dialog). Page state refreshes inline on 200 via `hx-swap=innerHTML` on the closest `.gap-close-action`. CSRF token included via `_csrf_token` form field. (Visual rhythm and modal feel are subject to `[REVIEW]` Human AC.)
- [x] CLI verb `bin/fw gaps close <gap_id> [--rationale "..."] [--override]` calls the same code path as the POST handler (shared `lib/gaps.py`). `bin/fw gaps close` without args lists closure-eligible gaps (`stale_ready_gaps(threshold_days=0)`) and prints usage; exits 2 (non-interactive). Refuse paths: exit 1 with `Refused (NNN) ...` to stderr.
- [x] `bin/fw doctor` check: WARN when ≥1 gap has `status: watching` AND `closure_check_command:` set AND gauge currently returns `verdict: READY` AND `last_reviewed:` (or `created:` fallback) is ≥7 days old (operator-procrastination signal; mirror of OBS-048-class). Surfaces each stale gap with age + title + closure command.
- [x] bats unit test (`tests/unit/gaps_close.bats`) — 12 tests covering: happy-path close on gauge-READY, refuse 404 on absent gap, refuse 409 on already-closed, refuse 412 on gauge=NOT_READY, refuse 412 on no-gauge gap (UNKNOWN), override path with rationale logged + override:true in audit, override-without-rationale refused (400), CLI happy path, CLI refuse path, CLI no-args lists eligible, stale_ready_gaps returns READY synthetic gaps, atomic write preserves sibling entries verbatim. All 12 pass.
- [x] Playwright test (`tests/playwright/test_gaps_close.py`) — 3 tests: Close button visible + form contract OK for G-064 (hx-post, hx-confirm modal trigger, CSRF token embedded), disabled-state shape correct when gauge=UNKNOWN, hx-swap target local (`closest .gap-close-action` + `innerHTML`) — guards against accidental whole-page swap regressions. All 3 pass against live /gaps. Does NOT submit the actual close — that would mutate the live register; the bats suite covers mutation paths against synthetic gaps.
- [x] Consumer-fresh simulation green (`tests/unit/upgrade_fresh_machine_simulation.bats` 3/3 PASS) — see Verification command output.

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

bash -n bin/fw
python3 -c "import ast; ast.parse(open('web/blueprints/discovery.py').read())"
python3 -c "import sys; sys.path.insert(0,'.'); from lib.gaps import close_gap, gauge_state, stale_ready_gaps, GapCloseError; assert callable(close_gap)"
bats tests/unit/gaps_close.bats
bats tests/unit/upgrade_fresh_machine_simulation.bats
out=$(curl -sf "$(bin/fw watchtower url)/gaps" 2>&1); grep -q "gap-close-action" <<<"$out"
out=$(curl -sf "$(bin/fw watchtower url)/gaps" 2>&1); grep -q "hx-post=\"/gaps/G-064/close\"" <<<"$out"

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

### 2026-06-04 — closure_check_command is the canonical gauge field

- **What changed:** Filing-day ACs said "runs the mechanical gauge if `status_notes:` specifies one (search for `python3 tools/<name>-readiness.py` shape)". Building it, I found that `closure_check_command:` is the canonical T-1752 field — already populated on G-064, already read by the read-side `fw gaps` rendering. Parsing `status_notes:` prose would have been wrong (prose is human-readable; field is machine-readable).
- **Plan impact:** AC #1 retargeted to read `closure_check_command:`, not parse `status_notes:`. Status_notes remains documentation; field is contract. This kept the lib symmetric with the existing read path (`_render_closure_check` in `bin/fw`).
- **Triggered:** Nothing new filed — the field already existed, only the AC wording was provisional.

### 2026-06-04 — text-surgical rewrite over PyYAML load-dump

- **What changed:** Filing day implied a normal "load YAML → mutate → dump YAML" flow. concerns.yaml carries 75 entries of heavy block-scalar prose and inline comments (~2400 lines). PyYAML does not round-trip comments or block-scalar style; ruamel.yaml is not a current dependency. A load-dump would wreck the file structurally.
- **Plan impact:** lib/gaps.py uses a regex-bounded block-rewrite (`^- id: <gap_id>` to next `^- id:`) and inserts new lines after the existing status line. Comments + sibling entries preserved verbatim. Verified by `tests/unit/gaps_close.bats::atomic write: sibling gaps preserved verbatim`.
- **Triggered:** Nothing new — pattern matches `sed -i.bak '/^- id: G-XXX/,/^- id:/{...}'` from T-2197's manual-closure recipe.

### 2026-06-04 — handler lives on `discovery` blueprint, not a new gaps blueprint

- **What changed:** AC #1 originally said `web/blueprints/gaps.py POST handler`. There is no `web/blueprints/gaps.py` — the `/gaps` GET route is on `web/blueprints/discovery.py` alongside `/decisions`, `/learnings`, `/search`. Adding a sibling blueprint just to host one POST would have fragmented the route graph.
- **Plan impact:** POST handler `gaps_close()` added to `discovery.py` immediately after the GET `gaps()`. AC wording corrected accordingly.
- **Triggered:** Nothing.

### 2026-06-04 — CSRF discovery during in-process smoke test

- **What changed:** Test-client POST returned 403 even with valid payload. Reading `web/app.py:92-111` revealed CSRF `@before_request` validator on all POST/PATCH/PUT/DELETE. Form must include `_csrf_token` or `X-CSRF-Token` header.
- **Plan impact:** Template's HTMX form now embeds `<input type="hidden" name="_csrf_token" value="{{ csrf_token() }}">`. CSRF jinja global is registered in `create_app`. Playwright test verifies token presence + length.
- **Triggered:** Nothing — this is the established Flask pattern; just discovered during smoke.

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

**Rationale:** All 7 Agent ACs shipped + verified. The recurring class identified at filing (any gap with `closure_check_command:` will hit the same dead end) is now structurally addressed by a single shared `lib/gaps.py` consumed by three surfaces: web POST handler (`/gaps/<id>/close`), CLI verb (`fw gaps close <id>`), and `fw doctor` stale-gauge WARN. G-064 is the live first consumer — Close button currently surfaces on the page with gauge=READY. The Human `[REVIEW]` AC remains: visual rhythm + modal feel on `/gaps`.

**Evidence:**
- `lib/gaps.py` (380 LOC) — closes gauge-READY gaps via text-surgical YAML block rewrite, atomic write, JSONL audit log.
- `web/blueprints/discovery.py` — `gaps_close()` POST handler + gauge state lookup wired into `gaps()` GET.
- `web/templates/gaps.html` — Close button + HTMX form (enabled when gauge=READY, disabled with tooltip otherwise) with CSRF token.
- `bin/fw` — `fw gaps close <id> [--rationale "..."] [--override]` subverb + `fw doctor` stale-gauge WARN check.
- `tests/unit/gaps_close.bats` — 12/12 PASS (happy path, refuse 404/409/412/400, override path, CLI paths, atomic write).
- `tests/playwright/test_gaps_close.py` — 3/3 PASS against live `/gaps` (Close button form contract, disabled state, hx-swap target scope).
- `tests/unit/upgrade_fresh_machine_simulation.bats` — 3/3 PASS.
- `fw doctor` now WARNs: `Gauge-READY gaps not closed: 1 gap(s) ≥7 days READY → G-064 (30d READY)`.

**Closes the OBS-048 cascade leg.** Operator can now close G-064 from `/gaps` with a single click (gauge auto-validated) or `fw gaps close G-064` from CLI. The G-065 cascade (T-2197 handoff) gets the same surface — the operator can override-close G-065 (no gauge) with rationale once T-1702 + T-1707 `[REVIEW]` pass.

**Remaining thread:** Human `[REVIEW]` AC at `/review/T-2185` — visual rhythm + modal feel taste call. Server side is fully shipped and tested.

## Updates

### 2026-06-02T21:02:45Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2185-watchtower-gaps-close-action--surface-me.md
- **Context:** Initial task creation

### 2026-06-02T21:05:03Z — status-update [task-update-agent]
- **Change:** status: started-work → captured
- **Change:** horizon: now → next

### 2026-06-03T22:28:10Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now
