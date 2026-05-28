---
id: T-1964
name: "BVP driver add form — /api/bvp/driver/add POST + add-driver form below sliders
  (T-1958 A)"
description: >
  T-1958 build child A: web/blueprints/bvp.py /api/bvp/driver/add POST + web/templates/bvp.html
  add-driver form. Shell-out: `bin/fw bvp driver --add '<name>' --weight N --rationale
  '...' [--drop Dn] --from-watchtower`. Validations: name regex [A-Za-z][A-Za-z0-9_-]*,
  weight 0-9 slider, rationale >=30 chars, drop-driver dropdown visible only at cap=9.
  ~80 LOC blueprint + ~60 LOC template.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [watchtower, bvp, approval-ux, T-1958-followup, arc:bvp]
components: []
related_tasks: [T-1958, T-1929, T-1933]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-20T17:57:35Z
last_update: '2026-05-28T22:54:10Z'
date_finished: 2026-05-20T18:07:30Z
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

# T-1964: BVP driver add form — /api/bvp/driver/add POST + add-driver form below sliders (T-1958 A)

## Context

T-1958 GO (driver CRUD belongs in Watchtower) → T-NEW-A: web form for adding a free driver.
Mirrors `bvp_commit_weights` (web/blueprints/bvp.py:409) — shell out to `fw bvp driver --add`
with `--from-watchtower` so the §ACD gate and `bvp-weight-history.jsonl` audit stay in fw.
Cap=9 (M1: total D1-D4 + free ≤ 9); drop-driver dropdown visible only at cap.

## Acceptance Criteria

### Agent
- [x] `/api/bvp/driver/add` POST route exists in `web/blueprints/bvp.py` and shells `bin/fw bvp driver --add <name> --weight N --rationale "<R>" [--drop Dn] --from-watchtower`
- [x] Server-side validation matches CLI: name regex `[A-Za-z][A-Za-z0-9_-]*`, weight 0-9 int, rationale ≥30 chars, `--drop Dn` rejected (D1-D4 are protected)
- [x] `web/templates/bvp.html` renders an "Add free driver" form below the live weight sliders (after `bvp_commit_weights` form, inside `{% if weights %}` block)
- [x] Form fields: name input (pattern attr), weight slider 0-9 + numeric display, rationale textarea (minlength=30 required), drop-driver `<select>` (only enabled when total drivers = 9, M1 add-one-drop-one)
- [x] JS posts to `/api/bvp/driver/add`, displays success or first-line error
- [x] Successful add returns JSON `{ok: true, message, name, weight, dropped}` 200; validation errors return plain-text 400
- [x] Route is registered (Flask URL map includes `/api/bvp/driver/add`)

### Human
- [ ] [REVIEW] Add-driver form on `/bvp` reads cleanly under the sliders section — name/weight/rationale flow visually parses without crowding
  **Steps:**
  1. Open http://192.168.10.107:3000/bvp in browser
  2. Scroll past the "Live weight sliders" section to "Add free driver"
  3. Try entering a short rationale + submitting — confirm error text appears in red next to the submit button
  4. Try a valid add (real driver — pick a name like `test-driver-1`) then immediately remove it via CLI: `bin/fw bvp driver --remove F1 --rationale "test cleanup" --from-watchtower`
  **Expected:** form sits below the sliders with the same visual rhythm; weight slider live-updates the numeric display; rationale field is wide enough to compose a 30-char explanation; error/success messages are clearly distinguishable
  **If not:** screenshot the layout, note which element crowds or wraps awkwardly

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
python3 -c "import sys; sys.path.insert(0,'.'); from web.app import app; assert '/api/bvp/driver/add' in [str(r) for r in app.url_map.iter_rules()], 'route missing'"
WT=$(bin/fw watchtower url); out=$(curl -sf "$WT/bvp" 2>&1); grep -q 'bvp-driver-add-form' <<<"$out"
WT=$(bin/fw watchtower url); out=$(curl -sf "$WT/bvp" 2>&1); grep -q 'id="da-name"' <<<"$out"
WT=$(bin/fw watchtower url); out=$(curl -sf "$WT/bvp" 2>&1); grep -q 'Add free driver' <<<"$out"
COOKIE=$(mktemp); WT=$(bin/fw watchtower url); CSRF=$(curl -sS -c "$COOKIE" "$WT/bvp" | grep -oP 'csrf-token" content="\K[^"]+' | head -1); resp=$(curl -sS -b "$COOKIE" -X POST "$WT/api/bvp/driver/add" -d "_csrf_token=$CSRF&name=&weight=3&rationale=$(printf 'x%.0s' {1..40})" -w "%{http_code}"); rm -f "$COOKIE"; grep -q "400" <<<"$resp" && grep -q "Bad driver name" <<<"$resp"
COOKIE=$(mktemp); WT=$(bin/fw watchtower url); CSRF=$(curl -sS -c "$COOKIE" "$WT/bvp" | grep -oP 'csrf-token" content="\K[^"]+' | head -1); resp=$(curl -sS -b "$COOKIE" -X POST "$WT/api/bvp/driver/add" -d "_csrf_token=$CSRF&name=foo&weight=99&rationale=$(printf 'x%.0s' {1..40})" -w "%{http_code}"); rm -f "$COOKIE"; grep -q "400" <<<"$resp" && grep -q "out of range" <<<"$resp"
COOKIE=$(mktemp); WT=$(bin/fw watchtower url); CSRF=$(curl -sS -c "$COOKIE" "$WT/bvp" | grep -oP 'csrf-token" content="\K[^"]+' | head -1); resp=$(curl -sS -b "$COOKIE" -X POST "$WT/api/bvp/driver/add" -d "_csrf_token=$CSRF&name=foo&weight=3&rationale=short" -w "%{http_code}"); rm -f "$COOKIE"; grep -q "400" <<<"$resp" && grep -q "Rationale must be" <<<"$resp"
COOKIE=$(mktemp); WT=$(bin/fw watchtower url); CSRF=$(curl -sS -c "$COOKIE" "$WT/bvp" | grep -oP 'csrf-token" content="\K[^"]+' | head -1); resp=$(curl -sS -b "$COOKIE" -X POST "$WT/api/bvp/driver/add" -d "_csrf_token=$CSRF&name=foo&weight=3&rationale=$(printf 'x%.0s' {1..40})&drop=D1" -w "%{http_code}"); rm -f "$COOKIE"; grep -q "400" <<<"$resp" && grep -q "protected driver D1" <<<"$resp"

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

### 2026-05-20 — CSRF middleware applies to all /api/* POSTs

- **What changed:** Confirmed during smoke that the existing `csrf_protect` `before_request` in `web/app.py:93` blanket-applies to `/api/*` POSTs. The blueprint route inherits this — no per-route token check needed, just an `_csrf_token` form field or `X-CSRF-Token` header. The template's `csrf_token()` Jinja helper covers it.
- **Plan impact:** No code change needed in the blueprint; the smoke confirmed the existing middleware works for this new route. Originally I was going to verify by reading the middleware; the curl 403 immediately surfaced it without needing the read.
- **Triggered:** No new sub-task. The pattern documented here for T-1965 (driver remove) so the sibling doesn't re-discover.

### 2026-05-20 — Drop dropdown gating: weights|length, not policy round-trip

- **What changed:** The template gates the drop-row visibility on `weights|length >= 9`. Since the `weights` dict already accumulates D1-D4 + free drivers via `_driver_weights(policy)`, the cap=9 trigger condition is computable from what `bvp_scatter()` already passes in. No new context variable.
- **Plan impact:** Originally I considered adding an `at_cap` boolean to the render context. Unnecessary — Jinja's `|length` is enough.
- **Triggered:** None. Same pattern reusable in T-1965 (driver remove).

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

**Recommendation:** GO

**Rationale:** All 7 Agent ACs ticked. End-to-end smoke confirmed:
- Form renders below sliders in `web/templates/bvp.html` (verified by curl + grep on rendered HTML)
- `/api/bvp/driver/add` POST registered in Flask URL map
- 4 validation paths return 400 with correct messages (bad name, bad weight, short rationale, drop=D1)
- Happy-path round-trip (form → blueprint → `fw bvp driver --add --from-watchtower` → policy file → cleanup) succeeded with the F1 driver appearing and getting cleaned via the existing `--remove` CLI
- Cap=9 drop dropdown gated on `weights|length >= 9` (visible only at cap, M1 add-one-drop-one)
- §ACD authority + history audit stay in fw (no policy mutation in the blueprint itself; it's a CLI shell-out exactly like `bvp_commit_weights` at bvp.py:409)

**Evidence:**
- `web/blueprints/bvp.py:468` — `bvp_driver_add()` route (~60 LOC, under 80 LOC budget)
- `web/templates/bvp.html:50` — "Add free driver" section (~85 LOC including inline JS, ~25 LOC over 60 LOC budget; inline JS makes up the diff for fetch+success-reload handling — acceptable given no separate JS file existed)
- `/api/bvp/driver/add` in `app.url_map.iter_rules()` (verified)
- 4 validation curl tests + happy-path smoke (rationale: "T-1964 happy-path smoke...")
- F1 driver successfully created with weight=2 then cleaned via `fw bvp driver --remove F1 --from-watchtower`

**[REVIEW] Human AC pending:** visual layout/rhythm of the add-driver form on `/bvp` — judgment call on whether the form feels crowded under the slider section. Mechanical functionality is structurally verified.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-20T17:57:35Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1964-bvp-driver-add-form--apibvpdriveradd-pos.md
- **Context:** Initial task creation

### 2026-05-20T18:01:42Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.4)

- **Scan ID:** R-023f34b2
- **Timestamp:** 2026-05-20T18:07:33Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** yes
- **Findings:** 1

**Per-AC findings:**

- **AC#3 (Agent)** — `web/templates/bvp.html` renders an "Add free driver" form below the live weight sliders (after `bvp_commit_weights` form, inside `{% if weights %}` block)
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/templates/bvp.html in: `web/templates/bvp.html` renders an "Add free driver" form below the live weight sliders (after `bvp_commit_weights` form, inside `{% if weights %}` b`

- **Layer-1 escalations:** 1
  1. **destructive-action** (high) — Destructive operation in verification or AC
     - matched: `rm -f`

### 2026-05-20T18:07:30Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
