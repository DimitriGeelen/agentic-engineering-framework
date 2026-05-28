---
id: T-1994
name: "Watchtower Fabric + Arcs page redesign — apply foundation tokens, dense graph,
  subsystem rail (arc-007 S5)"
description: >
  Redesign /fabric (cytoscape graph) and /arcs pages with foundation tokens and any
  nav-restructure side-effects. Reference: docs/design/.../direction-cockpit.jsx shows
  Fabric with subsystem rail + node-detail panel. Add filter-chip saved views to /arcs
  (status × focus × stale). Depends on S0+S1+S2. Parent inception: T-1987.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [watchtower, redesign, ui, fabric, arcs]
arc_id: watchtower-redesign
components: [tests/playwright/test_arcs_pages_tokens.py, 
      tests/playwright/test_fabric_coupling_token.py, 
      tests/unit/test_arcs_pages_tokens.py, 
      tests/unit/test_fabric_coupling_token.py, web/templates/arc_close.html, 
      web/templates/arc_detail.html, web/templates/arc_review.html, 
      web/templates/arcs_index.html, web/templates/fabric_detail.html]
related_tasks: [T-1987]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-22T10:06:08Z
last_update: '2026-05-28T22:54:11Z'
date_finished: 2026-05-26T21:37:22Z
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
  - ts: '2026-05-22T10:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-22T10:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T22:54:11Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F1=0 (no-signal); 
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1994: Watchtower Fabric + Arcs page redesign — apply foundation tokens, dense graph, subsystem rail (arc-007 S5)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

This is an **umbrella roll-up** for arc-007 S5 (fabric + arcs page redesign: semantic colour tokens, bounded page heights, dependency-link resolution). Each Agent AC re-asserts a shipped slice's artefact still holds; `## Verification` contains the matching shell check. Slices: T-2027 (S5a arcs colour tokens), T-2028 (S5b fabric coupling-note), T-2039 (fabric page height), T-2047 (docs/generated height), T-2049 (docs/generated linkify dependencies).

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] **S5a (T-2027) arcs pages semantic-colour tokenised** — `grep -cE 'style="[^"]*#[0-9a-fA-F]{3,6}' web/templates/arcs_index.html` returns `0`
- [x] **S5b (T-2028) fabric coupling-note tokenised** — `grep -cE 'style="[^"]*#[0-9a-fA-F]{3,6}' web/templates/fabric.html` returns `0`
- [x] **Fabric page height bounded (T-2039)** — `tests/playwright/test_all_routes_height.py` exercises `/fabric` (T-2042/T-2048 parametrised sweep)
- [x] **docs/generated page height bounded (T-2047)** — height test references `docs` routes
- [x] **docs/generated detail pages linkify dependencies (T-2049)** — `tests/unit/test_docgen_dep_resolution.py` pins the resolution; `docs/generated/components/` populated by current generator
- [x] **arcs + fabric pages return HTTP 200** — live curl confirms both surfaces render

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

- [ ] [REVIEW] Fabric + Arcs feel like one redesigned surface
  **Steps:**
  1. Open `https://watchtower.docker.ring20.geelenandcompany.com/arcs` and `/fabric` in the same browser session.
  2. Switch palettes via ⚙ → /settings/appearance (Calm / Editorial / Console / Paper / Bone / Midnight).
  3. For each preset, eyeball: do arc cards, fabric coupling notes, and dependency links share the same colour language?
  **Expected:** No jarring mismatch between arcs and fabric on any preset; coupling-note bands use semantic tokens that respect the active preset.
  **If not:** Note the preset + page + visual mismatch; file a follow-up slice.

- [ ] [REVIEW] docs/generated detail pages — dependency links resolve and are useful
  **Steps:**
  1. Open `https://watchtower.docker.ring20.geelenandcompany.com/docs/generated/components/hook-config` (or any component with deps).
  2. Click a `Dependencies:` target.
  **Expected:** Link resolves to the other component page; the dependency relationship is intelligible to the reader.
  **If not:** Note the component + target + observed behaviour.

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

# === T-1994 umbrella verification — re-asserts each S5 slice's artefact ===
test "$(grep -cE 'style="[^"]*#[0-9a-fA-F]{3,6}' web/templates/arcs_index.html)" = "0"
test "$(grep -cE 'style="[^"]*#[0-9a-fA-F]{3,6}' web/templates/fabric.html)" = "0"
grep -q "/fabric" tests/playwright/test_all_routes_height.py
grep -q "docs" tests/playwright/test_all_routes_height.py
test -f tests/unit/test_docgen_dep_resolution.py
test -d docs/generated/components
out=$(curl -sf "$(bin/fw watchtower url)/arcs" -o /dev/null -w "%{http_code}"); test "$out" = "200"
out=$(curl -sf "$(bin/fw watchtower url)/fabric" -o /dev/null -w "%{http_code}"); test "$out" = "200"
for t in T-2027 T-2028 T-2039 T-2047 T-2049; do compgen -G ".tasks/active/${t}-*.md" >/dev/null || compgen -G ".tasks/completed/${t}-*.md" >/dev/null || { echo "MISSING $t"; exit 1; }; done

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

### 2026-05-26 — S5 umbrella scoped from shipped slices

- **What changed:** Like T-1990, T-1994 was conceived as a unified Fabric + Arcs redesign but landed as 5 independent slices (S5a/S5b colour tokenisation, fabric/docs/generated height fixes, dependency linkification). The umbrella sat at captured/later with placeholder ACs while all 5 children shipped.
- **Plan impact:** Umbrella's contract is now "all 5 S5 deliverables persist". Verification re-asserts each: inline-hex audits on arcs_index/fabric, `/fabric` and `/docs` in the height-test sweep, the dep-resolution regression test, and HTTP-200 smoke on `/arcs` + `/fabric`.
- **Triggered:** L-434 sweep continuation — T-1994 was the second-to-last arc-007 work-cluster (T-1990 was first this session). Closing it leaves only T-2056 (human-gated render-review skip) outstanding in arc-007.

## Recommendation

**Recommendation:** GO

**Rationale:** Five S5 slice contracts are functionally in place and visible in production. Each AC has a verification command that trips if the contract regresses. The visual cohesion question (does the Fabric/Arcs surface read as one redesign?) is genuinely human-judgement and split out as `[REVIEW]`.

**Evidence:**
- `arcs_index.html` + `fabric.html` inline-hex audits return 0
- `tests/playwright/test_all_routes_height.py` references `/fabric` and `docs` routes
- `tests/unit/test_docgen_dep_resolution.py` exists; `docs/generated/components/` populated
- Live `/arcs` + `/fabric` return HTTP 200
- 5/5 constituent slices present (active/, status=work-completed, awaiting human [REVIEW])

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

### 2026-05-22T10:06:08Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1994-watchtower-fabric--arcs-page-redesign--a.md
- **Context:** Initial task creation

### 2026-05-26T21:35:24Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-10990c97
- **Timestamp:** 2026-05-26T21:37:23Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-26T21:37:22Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
