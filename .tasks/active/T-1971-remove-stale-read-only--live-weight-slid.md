---
id: T-1971
name: "Remove stale 'Read-only — live weight sliders ship in T-1929' text on /bvp — sliders have shipped"
description: >
  Remove stale 'Read-only — live weight sliders ship in T-1929' text on /bvp — sliders have shipped

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
created: 2026-05-21T06:52:30Z
last_update: 2026-05-21T06:52:30Z
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

# T-1971: Remove stale 'Read-only — live weight sliders ship in T-1929' text on /bvp — sliders have shipped

## Context

`/bvp` (web/templates/bvp.html:8) currently shows the page sub-header:

> "Business Value Points vs composite cost. Tasks = small dots, arcs = larger dots. **Read-only — live weight sliders ship in T-1929.**"

T-1929 has shipped (closed work-completed/partial-complete). The sliders are rendered and functional below this paragraph. The "Read-only" framing is stale and actively misleads users into thinking the interactive controls aren't operational.

Discovered during T-1915 demo-evidence capture for arc-006 closure — visible in `docs/reports/T-1915-demo-evidence/03-bvp-scatter.png` header.

## Acceptance Criteria

### Agent
- [x] `Read-only — live weight sliders ship in T-1929` removed from `web/templates/bvp.html:8`
- [x] Replacement text accurately describes the live-slider+commit flow (one sentence, names `fw bvp weight --from-watchtower` + §ACD)
- [x] Page sub-header still names the scatter/dot legend ("Tasks = small dots, arcs = larger dots." preserved)
- [x] Watchtower restarted; live `curl /bvp` confirms stale text count=0, new text count=1

### Human
- [ ] [REVIEW] `/bvp` page sub-header text reads cleanly and accurately describes the slider+commit flow
  **Steps:**
  1. Hard-refresh http://192.168.10.107:3000/bvp
  2. Read the paragraph immediately below the `BVP Quadrant Scatter` heading
  **Expected:** Two sentences. First sentence describes the scatter (BVP vs cost, tasks = small dots, arcs = larger). Second sentence accurately describes the slider+commit flow naming `fw bvp weight --from-watchtower` and §ACD. No mention of "Read-only" or "T-1929".
  **If not:** Note specific phrasing concern; the swap landed in `web/templates/bvp.html:8`.

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

# Re-verify the swap end-to-end against the live Watchtower
out=$(curl -s http://localhost:3000/bvp 2>&1)
echo "$out" | grep -q "Drag a slider below to preview re-ranking"
! echo "$out" | grep -q "Read-only — live weight sliders ship in T-1929"

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

## Recommendation

**Recommendation:** GO

**Rationale:** Stale "Read-only" framing on a shipped interactive surface actively misleads users; the swap is single-line, single-file, and verified end-to-end (live `curl` confirms new text, stale text gone). Render-surface gate satisfied by the [REVIEW] AC for sub-header readability.

**Evidence:**
- `web/templates/bvp.html:8` swapped: "Read-only — live weight sliders ship in T-1929." → "Drag a slider below to preview re-ranking client-side; Commit persists via fw bvp weight --from-watchtower (§ACD)."
- Verification block re-runs the curl check at completion gate
- Watchtower live confirms swap landed (curl grep counts: stale=0, new=1)

**Review on Watchtower:** http://192.168.10.107:3000/review/T-1971

## Updates

### 2026-05-21T06:52:30Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1971-remove-stale-read-only--live-weight-slid.md
- **Context:** Initial task creation
