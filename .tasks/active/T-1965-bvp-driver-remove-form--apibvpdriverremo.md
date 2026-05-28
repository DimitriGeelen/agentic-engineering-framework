---
id: T-1965
name: "BVP driver remove form — /api/bvp/driver/remove POST + per-row remove button
  (T-1958 B)"
description: >
  T-1958 build child B: web/blueprints/bvp.py /api/bvp/driver/remove POST + remove
  button per free-driver row in weight-sliders table. Shell-out: `bin/fw bvp driver
  --remove Dn --rationale '...' --from-watchtower`. Confirm prompt: 'free drivers
  only; D1-D4 cannot be removed' — backend refuses Dn matching D1-D4 with 400 surfacing
  the protected-driver message.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [watchtower, bvp, approval-ux, T-1958-followup, arc:bvp]
components: [web/blueprints/bvp.py, web/templates/bvp.html]
related_tasks: [T-1958, T-1964]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-20T17:57:47Z
last_update: '2026-05-28T22:54:10Z'
date_finished: 2026-05-20T18:13:33Z
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
  - ts: '2026-05-20T18:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-20T18:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T22:54:10Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 0
      D4: 2
      F1: 1
      F2: 0
    rationale: "D1=4 (body:structural-gate); D2=2 (body:telemetry-or-audit-entry);
      D3=0 (no-signal); D4=2 (body:env-class-handled); F1=1 (body/tag hits for 'F1':
      1); F2=0 (no-signal)"
    rubric_sha: e4a00f38e801
---

# T-1965: BVP driver remove form — /api/bvp/driver/remove POST + per-row remove button (T-1958 B)

## Context

T-1958 GO (driver CRUD belongs in Watchtower) → T-NEW-B: per-row remove button for free drivers in the live weight sliders table. Mirrors T-1964 (add form) but inline per-row to keep visual locality with the slider it's removing. Server refuses Dn ∈ {D1..D4} with 400 (D1-D4 immutable in identity).

## Acceptance Criteria

### Agent
- [x] `/api/bvp/driver/remove` POST route exists in `web/blueprints/bvp.py` and shells `bin/fw bvp driver --remove Fn --rationale "<R>" --from-watchtower`
- [x] Server-side validation matches CLI: driver id `[A-Za-z][A-Za-z0-9_-]*`, D1-D4 rejected with 400 (protected drivers), rationale ≥30 chars
- [x] `web/templates/bvp.html` renders a Remove button in each free-driver row of the weight sliders table (visible only on rows where `driver_id` does NOT start with `D`)
- [x] Click handler prompts for rationale (≥30 chars), confirms ("free drivers only; D1-D4 cannot be removed"), then POSTs to `/api/bvp/driver/remove`
- [x] Successful remove returns JSON `{ok: true, message, removed}` 200; validation errors return plain-text 400
- [x] Route is registered (Flask URL map includes `/api/bvp/driver/remove`)
- [x] Remove smoke: F1 added via T-1964 form → removed via T-1965 form → policy file shows `free_drivers: []`

### Human
- [ ] [REVIEW] Remove button feels right inline with the slider it removes — confirm/prompt flow is not jarring
  **Steps:**
  1. Open http://192.168.10.107:3000/bvp in browser
  2. Add a test driver via the "Add free driver" form (T-1964): name=`test-driver-1`, weight=3, any 30+ char rationale
  3. After reload, find the new row in the sliders table — Remove button should be in the rightmost column
  4. Click Remove; confirm the JS confirm dialog wording is acceptable; provide a 30+ char rationale; verify success message + reload
  **Expected:** Remove button is inline with the slider so it's visually clear which driver is being removed; confirm/prompt flow is acceptable (not too many dialogs); D1-D4 rows show "protected" instead of a button
  **If not:** screenshot the layout; consider whether button placement should be in the add-driver section instead

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
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

python3 -c "import ast; ast.parse(open('web/blueprints/bvp.py').read())"
python3 -c "import sys; sys.path.insert(0,'.'); from web.app import app; assert '/api/bvp/driver/remove' in [str(r) for r in app.url_map.iter_rules()], 'route missing'"
WT=$(bin/fw watchtower url); out=$(curl -sf "$WT/bvp" 2>&1); grep -q 'dr-remove-btn' <<<"$out"
WT=$(bin/fw watchtower url); out=$(curl -sf "$WT/bvp" 2>&1); grep -q 'protected</span>' <<<"$out"
COOKIE=$(mktemp); WT=$(bin/fw watchtower url); CSRF=$(curl -sS -c "$COOKIE" "$WT/bvp" | grep -oP 'csrf-token" content="\K[^"]+' | head -1); resp=$(curl -sS -b "$COOKIE" -X POST "$WT/api/bvp/driver/remove" -d "_csrf_token=$CSRF&driver=D1" --data-urlencode "rationale=T-1965 verify D1 protected refusal — must return 400" -w "%{http_code}"); rm -f "$COOKIE"; grep -q "400" <<<"$resp" && grep -q "protected driver D1" <<<"$resp"
COOKIE=$(mktemp); WT=$(bin/fw watchtower url); CSRF=$(curl -sS -c "$COOKIE" "$WT/bvp" | grep -oP 'csrf-token" content="\K[^"]+' | head -1); resp=$(curl -sS -b "$COOKIE" -X POST "$WT/api/bvp/driver/remove" -d "_csrf_token=$CSRF&driver=F1&rationale=short" -w "%{http_code}"); rm -f "$COOKIE"; grep -q "400" <<<"$resp" && grep -q "Rationale must be" <<<"$resp"

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

### 2026-05-20 — Per-row inline button vs separate form section

- **What changed:** Originally T-1958 spec said "per free-driver row in the weight-sliders table". Confirmed during build: a new `<th></th>` column + per-row `{% if not d_id.startswith('D') %}` conditional render is cleaner than a separate "Remove driver" section. Visual locality with the slider it removes is the key UX gain — the user sees the same row they were just sliding and clicks Remove on that exact row.
- **Plan impact:** D1-D4 rows show `protected` muted text instead of a button (decision T-1965-1 below). Originally I considered hiding the column entirely on protected rows, but that breaks table alignment.
- **Triggered:** None. Pattern reusable for future "edit-this-row" workflows in the framework's web surface.

### 2026-05-20 — Confirm + prompt flow vs inline modal

- **What changed:** Used `confirm()` + `prompt()` rather than building an HTML modal. Two dialogs (confirmation, then rationale) is more steps than ideal, but adding a modal would have nearly doubled the JS LOC budget. CLAUDE.md "Don't add features beyond what the task requires" applies — the modal can be a later refinement if the [REVIEW] AC surfaces it as needed.
- **Plan impact:** Two dialogs vs the originally-implied single confirmation. Acceptable trade-off — Remove is rare enough (driver edits are governance acts, not daily) that one extra click is fine.
- **Triggered:** None. If future bvp surfaces need richer interactions, lift to htmx modal.

## Decisions

### 2026-05-20 — D1-D4 rows show "protected", not hidden

- **Chose:** Render `<span class="muted">protected</span>` for D1-D4 instead of an empty cell or no cell at all.
- **Why:** Making the boundary visible reinforces the §Authority Model — D1-D4 *cannot be removed by anyone*. An empty cell is ambiguous (loading state? bug?); "protected" is unambiguous. The `title="D1-D4 are immutable in identity"` tooltip carries the rationale.
- **Rejected:** (a) Show button anyway, refuse server-side. Two reasons not to: server already refuses (defence in depth), but surfacing a button you can't use is bad UX. (b) Drop the column entirely. Breaks table alignment.

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Recommendation

**Recommendation:** GO

**Rationale:** All 7 Agent ACs verified. End-to-end smoke:
- `/api/bvp/driver/remove` POST registered in Flask URL map
- 4 validation paths return correct 400 messages (bad id regex, D1-D4 protected, short rationale)
- Happy-path smoke: F1 added via T-1964 form → removed via T-1965 form → `free_drivers: []` in policy
- D1-D4 rows render `protected` muted text instead of Remove button (4 instances counted; rationale captured in Decisions)
- Per-row Remove appears only for free drivers (verified via temporary smoke driver: 1 button when 1 free driver exists, 0 buttons when none)
- §ACD authority + bvp-weight-history.jsonl audit stay in fw

**Evidence:**
- `web/blueprints/bvp.py:bvp_driver_remove()` — new route (~40 LOC)
- `web/templates/bvp.html` — extra `<th></th>` column + conditional Remove button + click handler (~50 LOC inline JS)
- T-1964 + T-1965 form chain confirmed via add→remove round-trip in same session
- Both inceptions (T-1958/T-1959) now have at least one shipped child — driver CRUD is no longer CLI-only

**[REVIEW] Human AC pending:** UX of inline Remove vs alternative placements; confirm/prompt dialog flow acceptability.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-20T17:57:47Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1965-bvp-driver-remove-form--apibvpdriverremo.md
- **Context:** Initial task creation

### 2026-05-20T18:08:54Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.4)

- **Scan ID:** R-70a56799
- **Timestamp:** 2026-05-20T18:13:35Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** yes
- **Findings:** 1

**Per-AC findings:**

- **AC#3 (Agent)** — `web/templates/bvp.html` renders a Remove button in each free-driver row of the weight sliders table (visible only on rows where `driver_id` does NOT start with `D`)
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/templates/bvp.html in: `web/templates/bvp.html` renders a Remove button in each free-driver row of the weight sliders table (visible only on rows where `driver_id` does NOT `

- **Layer-1 escalations:** 1
  1. **destructive-action** (high) — Destructive operation in verification or AC
     - matched: `rm -f`

### 2026-05-20T18:13:33Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
