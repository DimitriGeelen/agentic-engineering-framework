---
id: T-2061
name: "render-surface gate: prefer actual commit diffs over body-text path tokens — fix L-435 false-positive class"
description: >
  render-surface gate: prefer actual commit diffs over body-text path tokens — fix L-435 false-positive class

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [bug, render-surface, governance, false-positive, p-013, l-435]
components: [lib/render_surface.sh, agents/task-create/update-task.sh, tests/unit/test_render_surface_gate.bats]
related_tasks: [T-1766, T-2056, T-2060, T-1763, T-1764, T-1765]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-28T11:37:38Z
last_update: 2026-05-28T11:37:38Z
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

# T-2061: render-surface gate: prefer actual commit diffs over body-text path tokens — fix L-435 false-positive class

## Context

T-2056 has 4 ticked agent ACs + green Verification (`git diff --quiet HEAD -- web/blueprints/settings.py` confirms settings.py untouched), but the P-013 render-surface gate refuses close. Why: `task_touches_render_surface()` in `lib/render_surface.sh` greps the task BODY for path-like tokens and matches `web/blueprints/settings.py` mentioned 5× in prose ("settings.py is untouched", "production behaviour change", etc.). The gate cannot distinguish "this task modifies file X" from "this task DISCUSSES file X". L-435 documents the class and proposes the fix candidate: cross-check against the task's actual commit diffs (`git log --grep TASK_ID --name-only`) rather than relying on body-text path tokens. This fix unblocks T-2056 and the next instance of the same class, and removes a friction point where the sanctioned escape (`--skip-render-review`) is human-gated under autonomy (forces every false-positive into the human review queue).

Affected files:
- `lib/render_surface.sh:67-117` — `task_touches_render_surface()` body-scan logic
- `tests/unit/test_render_surface_gate.bats` — 12 existing cases including "web/blueprints/*.py in body verification block returns 0" (line 70) that explicitly asserts the false-positive behaviour we're fixing
- `agents/task-create/update-task.sh:418` — consumer of the predicate (no change needed if predicate contract is preserved)

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [ ] `lib/render_surface.sh:task_touches_render_surface()` prefers git evidence (committed + staged + working-tree paths matching TASK_ID) over body-text path tokens. When git evidence exists, body-text scan is ignored. When git evidence is empty (brand-new task, no commits), body-text scan still runs as a fallback (preserves first-close behaviour for tasks where the very first commit IS the close).
- [ ] T-2056 closes via the regular path (`bin/fw task update T-2056 --status work-completed`) without `--skip-render-review` — confirmed by gate emitting PASS, not the "Cannot complete build task — touches render surface" block.
- [ ] T-2060 (which genuinely touches `web/templates/approvals.html` + `web/templates/review.html`) still trips the gate when re-tested via the new predicate (committed evidence agrees with body scan → no regression on legitimate render touches).
- [ ] `tests/unit/test_render_surface_gate.bats` updated: new case for body-text-only mention (no git evidence) → predicate returns 1; new case for committed render-surface edit (regardless of body mention) → predicate returns 0; existing 12 cases still green after adapting the "body verification block returns 0" case to the new contract (it must now SHOW a real git-touched path, not just mention it in prose).
- [ ] `bin/fw doctor` still passes (no regression in cross-cutting health check).

### Human
<!-- No render surface touched by this fix — predicate change in lib/render_surface.sh
     is governance infrastructure, not a render surface. Gate self-tests via the bats
     update covering both directions (false-positive rejection + true-positive preservation). -->

## Verification

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

# Full bats suite for the gate stays green
bash -c 'bats tests/unit/test_render_surface_gate.bats 2>&1 | tail -3 | head -1 | grep -qE "^ok |passed"' || bats tests/unit/test_render_surface_gate.bats
# Predicate now rejects body-text-only mention (L-435 false-positive class)
out=$(bash -c 'source lib/render_surface.sh; tf=$(mktemp); cat > "$tf" <<EOF
---
id: T-PROBE
components: []
---
The whole point of this task is that web/blueprints/settings.py is UNTOUCHED.
EOF
task_touches_render_surface "$tf" && echo TOUCHES || echo NO-TOUCH; rm -f "$tf"'); echo "$out" | grep -q "NO-TOUCH"
# Predicate still detects a real git-touched render path (T-2060 regression check)
out=$(bash -c 'source lib/render_surface.sh; task_touches_render_surface .tasks/active/T-2060-polling-containers-inherit-body-hx-targe.md && echo TOUCHES || echo NO-TOUCH'); echo "$out" | grep -q "TOUCHES"

## RCA

**Symptom:** T-2056 has 4 ticked Agent ACs + 4-line green Verification (`git diff --quiet HEAD -- web/blueprints/settings.py` explicitly confirms settings.py is unchanged), yet `bin/fw task update T-2056 --status work-completed` refuses with `ERROR: Cannot complete build task — touches render surface but has no [REVIEW] Human AC` and lists `web/blueprints/settings.py` as the "touched" file. Same false-positive flagged by L-435 (2026-05-25); no fix shipped.

**Root cause:** `task_touches_render_surface()` in `lib/render_surface.sh:67` derives the candidate file list from (a) the task's `components:` frontmatter and (b) a regex sweep of the task BODY for path-like tokens. Both signals are author-controlled prose — they reflect what the task TALKS ABOUT, not what the task MODIFIES. A task whose entire point is "this file is intentionally untouched" still trips the gate because the file path literal appears in the body 5× in the negative-existence assertion.

**Why structurally allowed:** The gate was designed (T-1766) when the dominant false-negative class was "agent forgets to declare render touches and ships without [REVIEW] AC". Body-text scanning errs on the side of catching that — which is correct as a default. The opposite class (false-positive when prose mentions a path that wasn't modified) wasn't seen until 5 months later. No bats test asserted "body-text mention without git diff returns 1" — the test at line 70 of `test_render_surface_gate.bats` actually CODIFIES the false-positive behaviour as intended ("body verification block returns 0"), making it a pinned anti-feature rather than a guarded one.

**Prevention:** (1) Switch the predicate's primary evidence source from body-text scan to git history scan for the task ID (`git log --grep TASK_ID --name-only` + staged + working-tree). (2) Keep body-text scan as a fallback only when git evidence is empty (brand-new task being closed in the same commit it's being created). (3) Update the bats test that pins the false-positive to instead pin the true-positive contract: "body-mention with no git evidence → predicate returns 1; body-mention WITH git evidence on a render path → predicate returns 0". This new bats case is the regression guard for the next instance.

## Evolution

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

### 2026-05-28T11:37:38Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2061-render-surface-gate-prefer-actual-commit.md
- **Context:** Initial task creation
