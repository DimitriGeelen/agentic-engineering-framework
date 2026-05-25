---
id: T-2022
name: "Cockpit System Health knowledge counts always zero (template reads missing
  scan key)"
description: >
  Cockpit System Health knowledge counts always zero (template reads missing scan
  key)

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: [tests/playwright/test_cockpit_knowledge_counts.py, tests/unit/test_cockpit_knowledge_counts.py, web/blueprints/core.py, web/templates/cockpit.html]
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-24T10:36:58Z
last_update: 2026-05-25T22:44:49Z
date_finished: 2026-05-25T22:44:49Z
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
  - ts: '2026-05-24T10:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 7
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-24T10:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
---

# T-2022: Cockpit System Health knowledge counts always zero (template reads missing scan key)

## Context

The Cockpit "System Health" card shows `Knowledge: 0L, 0P, 0D` even though the
corpus has 458 learnings, 19 patterns, and 185 decisions. `cockpit.html` reads
`health.get('knowledge', {}).get('learnings'/'patterns'/'decisions')`, but
`fw scan` never writes a `knowledge` key under `project_health` (nor a top-level
`knowledge`), so the `.get('knowledge', {})` default yields `{}` → all zeros.

The fallback dashboard `index.html` already does this correctly: it sources
`knowledge_counts` (`_get_knowledge_counts()`) for L/D and `pattern_summary`
(`_get_pattern_summary()` sum) for P, both passed by the non-cockpit branch of
`core.index()`. The cockpit branch never passes them. Fix mirrors index.html's
proven pattern. Sibling of T-2021 (same System Health panel; distinct root
cause: missing key + wrong source, vs T-2021's wrong shape).

## Acceptance Criteria

### Agent
- [x] The Cockpit "System Health" Knowledge line shows real counts — L from `knowledge_counts.learnings`, P from the `pattern_summary` type sum, D from `knowledge_counts.decisions` — not `0L, 0P, 0D`. (unit: render the cockpit → Knowledge L and D spans are non-zero given a corpus)
- [x] `core.index()` cockpit branch passes `knowledge_counts` and `pattern_summary` into the template context (mirroring the non-cockpit branch). (unit: cockpit ctx contains both keys; render does not 500)
- [x] Reviewer static scan passes. (Verification: `bin/fw reviewer T-2022` → Overall PASS)

### Human
- [ ] [REVIEW] System Health "Knowledge" counts read correctly
  **Steps:**
  1. Open the cockpit: `cd /opt/999-Agentic-Engineering-Framework && bin/fw watchtower url` → open that URL in a browser
  2. Find the "System Health" card → the "Knowledge" line
  3. Confirm L/P/D show real, non-zero counts (e.g. `458L, 19P, 185D`), not `0L, 0P, 0D`
  **Expected:** The counts match the corpus and are visually consistent with the other pulse values
  **If not:** Screenshot the line and note what it shows

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

# template compiles (Jinja syntax check for the edited cockpit.html)
python3 -c "from web.app import app; app.jinja_env.get_template('cockpit.html')"
# cockpit.py still parses (touched core.py)
python3 -c "import ast; ast.parse(open('web/blueprints/core.py').read())"
# rendered Knowledge counts are non-zero against the corpus
python3 -m pytest tests/unit/test_cockpit_knowledge_counts.py -q
# reviewer static scan passes
out=$(bin/fw reviewer T-2022 2>&1); echo "$out" | grep -q "Overall:.*PASS"

## RCA

**Symptom:** Cockpit "System Health" → `Knowledge: 0L, 0P, 0D` while the corpus
holds 458 learnings, 19 patterns, 185 decisions.

**Root cause:** Producer/consumer mismatch. `cockpit.html` reads
`health.get('knowledge', {}).get(...)`, but `fw scan` never writes a `knowledge`
key under `project_health` — so the `{}` default makes every count zero. The
correct sources (`_get_knowledge_counts()`, `_get_pattern_summary()`) exist and
are used by `index.html`, but `core.index()`'s cockpit branch never passes them.

**Why structurally allowed:** Two cockpit-style templates (`index.html` fallback
and `cockpit.html`) diverged — index.html sources knowledge from helpers,
cockpit.html from a scan key that doesn't exist. No test asserts the rendered
cockpit Knowledge counts, so the divergence was invisible to greps (the `<span>`s
render — just with 0). Surfaced only on eyes-on during T-2021.

**Prevention:** A unit test renders the cockpit and asserts the Knowledge L/D
counts are non-zero given a populated corpus — pinning the helper→template wiring
so a future omission of the context keys fails the gate, not the eye.

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

### 2026-05-24 — source from helpers (mirror index.html), not from the scan
- **Chose:** Pass `knowledge_counts` + `pattern_summary` into the cockpit context and read them in the template, exactly as `index.html` does.
- **Why:** Those helpers are the live, correct source of truth and are already battle-tested on the fallback dashboard. Reusing them removes the divergence between the two templates rather than adding a third path.
- **Rejected:** Making `fw scan` write `project_health.knowledge` — the counts would then be as stale as the last scan, and it adds a producer-side change for data the page can compute live. Also rejected: injecting a synthetic `knowledge` key into the in-memory scan dict (hacky; keeps the wrong template convention).

## Recommendation

**Recommendation:** GO (pending the one [REVIEW] Human AC)

**Rationale:** A contained fix that removes a template-divergence bug by reusing
the same helpers the fallback dashboard already uses. The cockpit now shows real
knowledge counts. Agent ACs are unit-covered; the single Human AC is an eyes-on
check that the counts read correctly.

**Evidence:**
- Unit `tests/unit/test_cockpit_knowledge_counts.py` — cockpit ctx carries `knowledge_counts` + `pattern_summary`; rendered Knowledge L and D spans are non-zero given the corpus.
- Eyes-on screenshot `web/static/ux-review/T-2022-cockpit-knowledge.png` — System Health → Knowledge shows real counts.
- Reviewer `fw reviewer T-2022` — Overall PASS.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-24T10:36:58Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2022-cockpit-system-health-knowledge-counts-a.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-57f0527d
- **Timestamp:** 2026-05-25T22:45:11Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-25T22:44:49Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
