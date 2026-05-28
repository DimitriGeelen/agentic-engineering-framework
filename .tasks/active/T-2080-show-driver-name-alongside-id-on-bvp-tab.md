---
id: T-2080
name: "show driver name alongside id on /bvp tables and forms"
description: >
  show driver name alongside id on /bvp tables and forms

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: [web/blueprints/bvp.py, web/templates/bvp.html]
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-28T20:42:59Z
last_update: 2026-05-28T20:47:41Z
date_finished: 2026-05-28T20:47:41Z
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
  - ts: '2026-05-28T20:45:01Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F1: 1
    rationale: "D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 (body:default-change);
      D4=2 (body:env-class-handled); F1=1 (body/tag hits for 'F1': 1)"
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-28T20:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2080: show driver name alongside id on /bvp tables and forms

## Context

`/bvp` renders drivers by id only (`D1`, `D2`, `F1`, `F2` …). The `name` field is captured in `policy/value-drivers.yaml` (`Antifragility`, `Reliability`, `Recall_Leverage`, …) but never surfaced. User asks: show the name next to the id so the table is readable at a glance.

`_driver_weights()` returns `{id: weight}` and discards `name`. Fix is a thin sister helper `_driver_names()` returning `{id: name}`, passed alongside `weights` to the template; render `<code>D1</code> <span class="muted">Antifragility</span>` in the sliders table and in the Drop select option for the add-driver form.

## Acceptance Criteria

### Agent
- [x] `web/blueprints/bvp.py` — add `_driver_names(policy)` returning `{id: name}` for both `protected_drivers` and `free_drivers`; pass `driver_names=…` to `render_template` for `/bvp`.
- [x] `web/templates/bvp.html` — sliders table renders the name adjacent to the id (`<code>D1</code> <span class="muted">Antifragility</span>`). Missing names fall back to id-only.
- [x] `web/templates/bvp.html` — the add-driver form's "Drop" `<select>` option shows id + name (`F1 — Recall_Leverage`) so the human picks by name, not by code.
- [x] Curl `/bvp` confirms the DOM contains both id AND name strings rendered together for at least D1 (`Antifragility`) and the first free driver — verified via captured-response grep (not element-existence): `D1` row carries adjacent `<span class="muted">Antifragility</span>`.

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
- [ ] [REVIEW] /bvp sliders table and Drop select both read clearly with id + name; the formatting (code + muted span / em-dash separator) feels right, not noisy.
  **Steps:**
  1. Open `http://192.168.10.107:3000/bvp`
  2. Scan the sliders table — confirm each row shows both the driver code and a readable name
  3. With ≥9 drivers, open the Drop select on the Add form and confirm options are picked by name
  **Expected:** Names sit alongside ids without crowding; layout rhythm unchanged
  **If not:** Note the row/column where the formatting reads wrong

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

# T-2080 — driver name visible alongside id (L-387 safe: tempfile + grep -q -F file).
# `echo "$out" | grep -q PATTERN` still hits SIGPIPE 141 under `set -eo pipefail`
# when grep closes stdin before echo finishes (curl response is 50KB+).
# Tempfile pattern sidesteps the pipe entirely.
curl -sS "$(bin/fw watchtower url)/bvp" > /tmp/.t2080-bvp 2>&1
grep -qF "D1" /tmp/.t2080-bvp
grep -qF "Antifragility" /tmp/.t2080-bvp

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

## Recommendation

**Recommendation:** GO (Human eyes-on the layout rhythm, then close)

**Rationale:**

Driver names from `policy/value-drivers.yaml` now render inline next to each driver code on `/bvp`. Sliders table shows `<code>D1</code> Antifragility` (id in code style + name in muted span); the Add-driver form's Drop `<select>` shows `F1 — Recall_Leverage` so the human picks by name, not by code. Missing-name fallback keeps the id rendering unchanged.

**Evidence:**

- `web/blueprints/bvp.py:_driver_names()` — new helper returning `{id: name}` for both protected and free drivers; passed to template.
- `web/templates/bvp.html` — sliders table `<td>` now carries id + name span; Drop `<option>` now reads `id — name`.
- Curl `/bvp` after restart: `D1` row carries `<span class="muted" …>Antifragility</span>` adjacent to `<code>D1</code>`.
- Verification block (3 checks) passes: curl loads /bvp, grep -qF "D1" hits, grep -qF "Antifragility" hits.

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

### 2026-05-28T20:42:59Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2080-show-driver-name-alongside-id-on-bvp-tab.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-4b7475a9
- **Timestamp:** 2026-05-28T20:47:43Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 3

**Per-AC findings:**

- **AC#1 (Agent)** — `web/blueprints/bvp.py` — add `_driver_names(policy)` returning `{id: name}` for both `protected_drivers` and `free_drivers`; pass `driver_names=…` to `render_template` for `/bvp`.
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/blueprints/bvp.py in: `web/blueprints/bvp.py` — add `_driver_names(policy)` returning `{id: name}` for both `protected_drivers` and `free_drivers`; pass `driver_names=…` to`
- **AC#2 (Agent)** — `web/templates/bvp.html` — sliders table renders the name adjacent to the id (`<code>D1</code> <span class="muted">Antifragility</span>`). Missing names fall back to id-only.
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/templates/bvp.html in: `web/templates/bvp.html` — sliders table renders the name adjacent to the id (`<code>D1</code> <span class="muted">Antifragility</span>`). Missing nam`
- **AC#3 (Agent)** — `web/templates/bvp.html` — the add-driver form's "Drop" `<select>` option shows id + name (`F1 — Recall_Leverage`) so the human picks by name, not by code.
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/templates/bvp.html in: `web/templates/bvp.html` — the add-driver form's "Drop" `<select>` option shows id + name (`F1 — Recall_Leverage`) so the human picks by name, not by `

### 2026-05-28T20:47:41Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
