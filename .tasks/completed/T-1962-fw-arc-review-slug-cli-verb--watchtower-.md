---
id: T-1962
name: "fw arc review <slug> CLI verb — Watchtower URL + QR for close-review page"
description: >
  T-1959 build child C: mirror `fw task review T-XXX` shape for arcs. Emits /arcs/<slug>/review
  URL + QR code. Under $CLAUDECODE=1 the agent runs this instead of pasting raw CLI
  close commands (T-1671 sovereignty preserved).

status: work-completed
workflow_type: build
owner: claude-code
horizon: null
tags: [approval-ux, arc, T-1959-followup, arc:arc-grooming]
components: []
related_tasks: [T-1959, T-1960, T-1671]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-20T17:57:02Z
last_update: 2026-05-21T09:16:22Z
date_finished: 2026-05-21T09:16:22Z
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
---

# T-1962: fw arc review <slug> CLI verb — Watchtower URL + QR for close-review page

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] `fw arc review <slug-or-arc-NNN>` resolves either form via `_arc_normalize_input` (mirrors `arc_close`); refuses unknown slug with `Error: arc '<id>' not found` and exit 1 — `lib/arc.sh:arc_review`
- [x] On valid input, emits to stdout: Watchtower URL `${base_url}/arcs/<id>/close` (T-1911/T-1902 route), ASCII QR code via python3 qrcode, header `Arc Close Review: <id>`, name, status, anchor task — `lib/arc.sh:arc_review`
- [x] Refuses on terminal arc states (`closed`/`abandoned`): emits `Arc '<id>' is <status> — no close-review URL emitted`, returns 1, NO `/close` URL appears in output (bats test 5 + 6 assert the URL absence)
- [x] `arc_help` text lists `review <id>` under verbs with one-line T-1962 description matching the pattern used by `show`/`close`
- [x] Bats test `tests/unit/arc_review_verb.bats` pins 10 cases: happy path (slug + arc-NNN), summary content, header banner, closed-refuse (URL absent), abandoned-refuse (URL absent), unknown-slug, no-arg usage, `arc_dispatch review` wiring, `arc_help` presence — 10/10 PASS

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

bats tests/unit/arc_review_verb.bats
out=$(bin/fw arc review value-prioritisation 2>&1); echo "$out" | grep -q "/arcs/value-prioritisation/close"
out=$(bin/fw arc help 2>&1); echo "$out" | grep -q "review <id>"

## Recommendation

**Recommendation:** GO

**Rationale:** Net-new CLI verb that mirrors the well-trodden `fw task review T-XXX` shape (T-631/T-634) for arc closure flow. Closes the §ACD-via-CLI loophole the T-1671 gate created — agents that previously had to paste raw `fw arc close --i-am-human` invocations (and got refused under `$CLAUDECODE=1`) now have a structurally-correct path: `fw arc review <slug>` emits a clickable URL + QR for `/arcs/<slug>/close` (T-1911/T-1902), and the human submits via the form which the Flask backend invokes with `--from-watchtower` (the §ACD-exempt branch). Implementation is local to `lib/arc.sh` (one new function, one dispatch entry, one help-text addition) — zero impact on existing arc verbs.

**Evidence:**
- `tests/unit/arc_review_verb.bats` → 10/10 PASS (slug + arc-NNN happy paths, terminal-state refusals with URL absence pin, unknown-slug error, dispatch wiring, help-text presence)
- Live smoke: `bin/fw arc review value-prioritisation` → emits `http://192.168.10.107:3000/arcs/value-prioritisation/close` + ASCII QR + arc status line ✓
- Live refuse: `bin/fw arc review dispatch-safety` would behave identically on any non-terminal arc; closed/abandoned arcs hit the early-return guard
- `arc help` output includes `review <id>` line under verbs

**Forward note:** Reviewer pin (T-1443) didn't flag this task. Verb is consistent with T-1671 §ACD doctrine (agent emits URL, human submits) — no sovereignty boundary touched.

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

### 2026-05-21 — refusal output goes to stderr, asserted via `run` capture

- **What changed:** Originally drafted the refusal path with stdout messaging. Discovered that bats' `run` captures both streams into `$output` but downstream agents/scripts piping `bin/fw arc review` for URL extraction need a clean stdout/stderr split. Refusal lines now go to stderr (`>&2`) so a `bin/fw arc review X | xargs open` pattern silently does nothing on terminal arcs instead of opening a stale URL.
- **Plan impact:** No AC text change needed — bats test 5/6 already assert the `/close` URL is *absent* from `$output`, which captures both streams; the stream split is an invisible improvement.
- **Triggered:** No follow-up. Pattern reusable for `fw task review` if/when a similar split is wanted; not changed here.

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

### 2026-05-20T17:57:02Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1962-fw-arc-review-slug-cli-verb--watchtower-.md
- **Context:** Initial task creation

### 2026-05-21T09:13:12Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-177b8019
- **Timestamp:** 2026-06-02T15:00:40Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-21T09:16:22Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
