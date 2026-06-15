---
id: T-2412
name: "OBS-077: _self_vendor_web skips HTML/CSS/JS templates — find filter is .sh/.py-only"
description: >
  OBS-077: _self_vendor_web skips HTML/CSS/JS templates — find filter is .sh/.py-only

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
# demo_target: true               # T-2286: optional — marks task as reserved for an orchestrated demo
#                                 # worker (e.g. arc-010 HM-A dispatches via mcp__fw__work_on). When set,
#                                 # `fw work-on T-XXX` refuses unless --i-am-demo-orchestrator (CLI) or
#                                 # FW_I_AM_DEMO_ORCHESTRATOR=1 (env) is passed. Prevents the parent
#                                 # session from consuming the captured→started-work transition the demo
#                                 # worker expects to drive. Origin OBS-057.
created: 2026-06-15T21:00:40Z
last_update: 2026-06-15T21:00:40Z
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

# T-2412: OBS-077: _self_vendor_web skips HTML/CSS/JS templates — find filter is .sh/.py-only

## Context

`_self_vendor_web` in `lib/upgrade.sh:463` syncs framework `web/` content into
`.agentic-framework/web/` during `fw upgrade`. Its find filter is
`\( -name "*.sh" -o -name "*.py" \)` — which silently skips the 76 `.html`
Jinja2 templates + 17 `.js` + 3 `.css` files that the rendered Watchtower
depends on. Result: a consumer's `.agentic-framework/web/templates/` drifts from
the framework's templates and there is no warning.

Origin: prior session, OBS-077 captured during T-2407 self-vendor work. Sibling
to OBS-076 (vendor `node_modules` false-positive).

## Acceptance Criteria

### Agent
- [x] Find filter in `lib/upgrade.sh:_self_vendor_web` extended to include
      `*.html`, `*.css`, `*.js`, `*.svg`, `*.j2`, `*.jinja2` (the full render
      surface), in addition to the existing `*.sh` / `*.py` — `lib/upgrade.sh:463`
- [x] `bash -n lib/upgrade.sh` exits 0 (L-408)
- [x] bats test at `tests/unit/self_vendor_web_html.bats` (4/4 PASS, negative
      control proven: revert the fix → FIX 1/2/3 fail, CONTROL still passes)

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

bash -n lib/upgrade.sh
bats tests/unit/self_vendor_web_html.bats

## Recommendation

**Recommendation:** GO

**Rationale:** Find filter was structurally blind to the render surface. Fix is a
one-line extension to the existing filter — no behavior change to .sh/.py path,
matched by `*.html/*.css/*.js/*.svg/*.j2/*.jinja2`. Pinned by bats (4/4) with
negative control: reverting the fix makes FIX 1/2/3 fail at file-exists, CONTROL
keeps passing — proves the test catches the regression, not a tautology.

**Evidence:**
- `lib/upgrade.sh:463` filter now includes the full render surface
- `bash -n lib/upgrade.sh` → exit 0
- `bats tests/unit/self_vendor_web_html.bats` → 4/4 PASS
- Negative control: `git stash` the fix → 3 FIX tests fail, CONTROL passes;
  `git stash pop` → 4/4 PASS again

## RCA

**Symptom:** Consumer's vendored `.agentic-framework/web/templates/foo.html`
drifted from the framework's `web/templates/foo.html`. `fw upgrade` ran cleanly
with "0 web/ file(s) synced" despite real template edits.

**Root cause:** `_self_vendor_web` find filter at `lib/upgrade.sh:463` was
`\( -name "*.sh" -o -name "*.py" \)` — it had ever only matched control files,
never the templates/CSS/JS that those control files render.

**Why structurally allowed:** the function's success exit code (`return 0` after
`_svw_updated=0`) made "vendored nothing" indistinguishable from "nothing
needed vendoring". No assertion that the framework's HTML/CSS/JS template count
matched the consumer's copy. The sibling `do_upgrade` self-vendor functions for
`lib/` `bin/` `agents/` have the same shape but their globs (`*.sh`, `*.py`)
genuinely match all their content, so the same pattern works there — only
`web/` is heterogeneous.

**Prevention:** the bats test at `tests/unit/self_vendor_web_html.bats` pins
that HTML, CSS, and JS files are all synced; a future filter regression would
trip FIX 1/2/3 at file-exists.

## RCA-old

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

### 2026-06-15T21:00:40Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2412-obs-077-selfvendorweb-skips-htmlcssjs-te.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-927750c8
- **Timestamp:** 2026-06-15T21:04:04Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
