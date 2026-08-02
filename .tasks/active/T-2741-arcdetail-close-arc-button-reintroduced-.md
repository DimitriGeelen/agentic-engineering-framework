---
id: T-2741
name: "arc_detail close-arc button reintroduced a hardcoded semantic hex"
description: >
  arc_detail close-arc button reintroduced a hardcoded semantic hex

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: [web/templates/arc_detail.html]
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
created: 2026-08-02T22:26:00Z
last_update: 2026-08-02T22:36:11Z
date_finished: 2026-08-02T22:36:11Z
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
  - ts: '2026-08-02T22:30:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-02T22:30:09Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal);
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2741: arc_detail close-arc button reintroduced a hardcoded semantic hex

## Context

T-2027 (arc-007 S5a) converted the four Arcs templates off hardcoded semantic hexes
onto `--wt-*` tokens, and left `tests/unit/test_arcs_pages_tokens.py` behind as the
guard. T-2349 (2026-07-05) then added the "Close this arc" CTA to `arc_detail.html`
with an inline `background: #065f46` — a hardcoded semantic green, exactly the class
the guard forbids. The guard went red that day and stayed red.

Surfaced by OBS-134: T-2027's own `## Verification` line was the T-2738 unjudged-verdict
shape (`echo "$out" | grep -q passed` matched the `5 passed` substring of
`1 failed, 5 passed`), so the task reported green while carrying a red guard. T-2739
added the absence-of-failure guard, which made the red visible.

## Acceptance Criteria

### Agent
- [x] `web/templates/arc_detail.html` close-arc CTA carries no hardcoded hex — background and text colour both come from `--wt-*` tokens
- [x] `tests/unit/test_arcs_pages_tokens.py` passes in full (6/6), including `test_only_neutral_fallback_hexes_remain`
- [x] The four Arcs templates still compile (`test_templates_still_compile` green)
- [x] `/arcs/<slug>` renders HTTP 200 with the close CTA present in the live Watchtower

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

- [ ] [REVIEW] The close-arc CTA still reads as a button you'd press, across palettes
  **Steps:**
  1. Open http://192.168.10.107:3001/arcs/watchtower-redesign
  2. Scroll to the "When you can answer all three with evidence, close the arc:" block
  3. Cycle the palette at http://192.168.10.107:3001/appearance (slate, linen, stone, paper, bone, console) and re-check the button in each, in both light and dark mode
  **Expected:** the label stays legible against the fill in every palette, and the button still reads as the primary action of the page rather than as a link or a status badge.
  **If not:** name the palette(s) where it fails and whether the problem is contrast (label washes out) or semantics (no longer reads as the primary action) — the fix differs. Contrast → the accent/ink pair needs a per-palette tune like T-2006 did for linen. Semantics → the token choice itself is wrong and should go back to a green.

  **Why this is [REVIEW] and not [REVIEWER]:** the grep-able half (no residual hex) is
  already an Agent AC below. What is left is cross-palette legibility and whether the
  control still reads as primary — taste, and the operator is the audience. T-2027 left
  the same judgement open as its own Human AC.

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
# BUT NOT for a test runner (T-2738): the capture above discards the command's
# exit code, and `set -e` is suppressed inside the `if` condition the gate runs
# each line in — so in `cmd1; cmd2` only cmd2 is the verdict. For pytest/bats
# that exit code WAS the verdict, and the pass marker you grep instead survives
# a partial failure: a suite printing "3 failed, 9 passed" satisfies
# `grep -q "9 passed"`. Generalising to `grep -qE "[0-9]+ passed"` matches the
# same output. Either keep the exit code:
#     python3 -m pytest <file> -q > /tmp/.out 2>&1 && grep -q passed /tmp/.out
# or add the guard the exit code used to supply:
#     out=$(python3 -m pytest <file> -q 2>&1); echo "$out" | grep -q passed && ! echo "$out" | grep -q failed
#     out=$(bats <file> 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# The close gate refuses the unguarded form. Bypass: FW_ALLOW_UNJUDGED_TEST_RUN=1.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

# The guard T-2027 left behind, run in full. Guarded per T-2738: the bare
# `grep -q passed` form is exactly what let this sit red for 28 days.
out=$(python3 -m pytest tests/unit/test_arcs_pages_tokens.py -q 2>&1); echo "$out" | grep -q "6 passed" && ! echo "$out" | grep -qE "[0-9]+ (failed|error)"

# The CTA itself carries no hex. Premise clause first (`Close this arc` must be
# found) so that deleting the button cannot make the hex assertion pass vacuously.
cta=$(grep -A2 "close-arc-button" web/templates/arc_detail.html); echo "$cta" | grep -q "Close this arc" && ! echo "$cta" | grep -qE "#[0-9a-fA-F]{3,6}"

# Live render — the page the operator actually opens (never hard-code :3000).
# NOT the `out=$(curl ...); echo "$out" | grep -q` form the template recommends:
# this page is 146,366 bytes against a 65,536-byte pipe buffer, so `echo` blocks
# on a full pipe while `grep -q` exits at its first match — SIGPIPE, exit 141,
# deterministically (3/3). L-387's capture-first rule only removes SIGPIPE while
# the capture fits the pipe buffer. Redirect to a file instead; this also keeps
# curl's own exit code as part of the verdict rather than discarding it. OBS-137.
curl -sf "$(bin/fw watchtower url)/arcs/watchtower-redesign" -o /tmp/.t2741-arc.html && grep -q "Close this arc" /tmp/.t2741-arc.html

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

**Symptom:** `tests/unit/test_arcs_pages_tokens.py::test_only_neutral_fallback_hexes_remain`
asserted `arc_detail.html: unexpected hexes remain: ['#065f46']`. In the product, the
"Close this arc" CTA was the one control on the Arcs pages that did not re-theme with
the palette — it stayed dark emerald in all six palettes and both modes.

**Root cause:** T-2349 added a new control to a template whose whole point, since
T-2027, is that it carries no hardcoded semantic colour. The inline style was written
from scratch rather than from the sibling convention two lines up in the same file
(`.badge-ok { background: var(--wt-success); }`).

**Why structurally allowed — two independent failures, and the second is the one that matters:**

1. *Nothing stopped the write.* There is no lint forbidding a hex literal in the Arcs
   templates. The guard is a unit test, which runs after the fact, not a gate.

2. *The guard fired and no one heard it.* This is the real defect. The test went red on
   2026-07-05 and stayed red for 28 days. Two reasons compounded:
   - T-2027, the task that owns this guard, carried the T-2738 unjudged-verdict shape in
     its `## Verification` (`echo "$out" | grep -q passed` matched the `5 passed` inside
     `1 failed, 5 passed`). Its own guard's red was invisible to its own close gate.
   - `tests/unit/` as a whole is **25 failed / 2010 passed** right now (measured this
     task, 319s). One more red is indistinguishable from the standing red. Nothing gates
     a push or a close on the suite being green, so the signal has no consumer.

   Failure 1 lets a bug in; failure 2 is why it stayed 28 days. A guard nobody watches
   is not prevention, it is a record kept for an audience that does not exist.

**Prevention:** the fix itself closes the instance. The class is closed by the guard
becoming audible again — T-2027's verification line was already repaired under T-2739,
and the standing-red suite is filed separately (one bug = one task) rather than folded
in here, because "25 unit tests are red" is not this button's fault and needs its own
triage. Filed as OBS-136.

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

### 2026-08-03 — which token replaces `#065f46`

- **Chose:** `background: var(--wt-accent); color: var(--wt-accent-ink);`
- **Why:** accent/ink is the only *pair* in the token system, and the only one whose
  contrast has been deliberately tuned per palette — `foundations.css:31` carries the
  T-2006 note darkening linen's terracotta specifically to get ink-on-accent from 3.83
  to 4.60 for WCAG AA. A filled button with a text label is exactly what that pair is
  for. Semantically it is also right: this is the primary action of the page, and
  `arc_close.html:46` already renders the positive `.verdict-GO` off `--pico-primary`
  (which `foundations.css:127` maps to `--wt-accent`) rather than off success-green.
- **Measured, not assumed** (WCAG 2.x relative-luminance, computed this task):

  | pair | ratio | AA (4.5:1) |
  |---|---|---|
  | white on `--wt-success` `#10b981` (slate) | **2.54:1** | ✗ |
  | white on the old `#065f46` | 7.68:1 | ✓ |
  | ink-on-accent — slate | 6.29:1 | ✓ |
  | ink-on-accent — linen | 4.60:1 | ✓ |
  | ink-on-accent — stone | 5.84:1 | ✓ |
  | ink-on-accent — paper | 6.69:1 | ✓ |
  | ink-on-accent — bone | 4.91:1 | ✓ |
  | ink-on-accent — console | 8.28:1 | ✓ |

  Linen computing to exactly 4.60 is the figure the T-2006 comment claims, which
  confirms the pair really is the tuned one and not just the conveniently-named one.

- **Rejected:** `background: var(--wt-success); color: white;` — the literal sibling
  convention (`.badge-ok`, `.badge-warn`, `.verdict-NO-GO` all use it) and the smaller
  diff. Rejected on the measurement above: 2.54:1 is below AA at any text size. That is
  tolerable on a 10px badge where the colour is the signal and the word is a label; it
  is not tolerable on the CTA, where the word *is* the affordance. Taking it would have
  satisfied the guard while making the button *harder* to read than the hardcoded
  `#065f46` it replaced (7.68:1 → 2.54:1) — a green test masking a real regression,
  which is the exact failure mode this task exists to clean up.
- **Left open for the operator:** whether accent *reads* as "close this arc" now that
  it is no longer green. That is the `[REVIEW]` Human AC; if the answer is no, the fix
  is a per-palette success/ink pair, not a return to the hex.

## Recommendation

**Recommendation:** GO — merge as is; the remaining Human AC is a taste call, not a defect check.

**Rationale:** the guard is green, and the re-theming was verified on the live page across
all 12 palette × mode combinations rather than inferred from the CSS. Every combination
resolves to exactly the values in the contrast table above, and all six clear WCAG AA.
The one thing I cannot settle is whether an accent-coloured CTA still *reads* as "close
this arc" now that it is no longer specifically green — that is the `[REVIEW]` AC.

**Evidence:**
- `tests/unit/test_arcs_pages_tokens.py` — 6/6 passed (was 5/6 with
  `arc_detail.html: unexpected hexes remain: ['#065f46']`).
- Live render measured at `/arcs/watchtower-redesign` after a Watchtower restart, per
  palette/mode: slate `#4f46e5`/`#ffffff`, linen `#b35636`/`#fbf8f1`, stone
  `#5a6b3a`/`#ffffff`, paper `#1f4ed8`/`#ffffff`, bone `#b87a17`/`#1b1814`, console
  `#22c55e`/`#06140b`. Dark mode matches light in every case, which is correct —
  `foundations.css:60` documents that only bg/surface/border/text/muted shift in dark
  and the accent set is deliberately held.
- Screenshot (stone, the operator's current palette) captured to
  `docs/reports/T-2741-close-arc-cta-stone.png`, but **not committed** — `.gitignore:51`
  ignores `*.png` repo-wide, and that is a deliberate policy I did not override. It exists
  on this host only; the live page at the URL in the Human AC is the reviewable artefact.
  It rendered as olive-green fill with white label, reading clearly as a button.
- Contrast for all six pairs computed from the WCAG relative-luminance formula, table
  above; lowest is linen at 4.60:1, above the 4.5:1 AA floor.

**Verification-method note — the first live measurement was wrong and said so loudly.**
Flipping `data-wt-palette` and reading `getComputedStyle` in the same tick reported the
background frozen at the stone value in *every* palette, which read as "the fix does not
work". It was an artefact: pico puts `background-color 0.2s ease-in-out` on `<a>`, so the
synchronous read returns a mid-transition value. Two hypotheses were needed — the first
(a transition) was dismissed too early because `grep transition web/static/css/` is empty,
missing that the rule comes from pico, not from our own stylesheet. What settled it was a
synthetic `<div>` probe with the identical inline style: the probe tracked the palette
perfectly while the `<a>` did not, which isolates the difference to the element type
rather than to the tokens. Recorded because the failing form of this measurement looks
exactly like a real regression, and the next person to check a themed control this way
will see the same thing.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-08-02T22:26:00Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2741-arcdetail-close-arc-button-reintroduced-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c9372074
- **Timestamp:** 2026-08-02T22:36:20Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-02T22:36:11Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
