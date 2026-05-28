---
id: T-2059
name: "L-387 SIGPIPE detector — reviewer pattern + started-work advisory"
description: >
  Ships T-2057 GO scope: detect 'cmd | grep -q PATTERN' / 'ls glob | head -1' shell forms that SIGPIPE-fail under 'set -eo pipefail'. Two surfaces: (1) fw reviewer pattern 'l387-sigpipe-risk' scanning ## Verification blocks of completed tasks; (2) update-task.sh --status started-work emits advisory WARN when the task's ## Verification block contains the risky form. Bats coverage against the 15 historical positives + 26 safe-form negatives from the T-2057 spike corpus. Pinned by docs/reports/T-2057-l-387-detector-spike.md.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [reviewer, detector, l387, sigpipe, antifragility]
components: [lib/reviewer/static_scan.py, agents/task-create/update-task.sh, policy/anti-patterns.yaml]
related_tasks: [T-2057, T-1716, T-1838, T-1862, T-1863, T-2036]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-28T07:43:29Z
last_update: 2026-05-28T07:43:29Z
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

# T-2059: L-387 SIGPIPE detector — reviewer pattern + started-work advisory

## Context

Ships T-2057 GO scope. The L-387 class is `cmd1 | grep -q PATTERN` (and shape-equivalents like `ls glob | head -1`) under `set -eo pipefail`: when the downstream consumer exits early on match, the upstream gets SIGPIPE (exit 141) and `pipefail` propagates that as failure even though the pattern was *present*. 8 captures in 2 sessions (S-2026-0526..-0528 cluster including self-applied in T-2036). Spike report: `docs/reports/T-2057-l-387-detector-spike.md` — corpus scan, refined heuristic distinguishing ~15 true positives from ~26 safe `out=$(cmd); echo "$out" | grep -q` cases.

**Two surfaces:**
1. **`fw reviewer` pattern `l387-sigpipe-risk`** — static-scan rule against `## Verification` blocks. Pass-B audit re-scan catches it daily.
2. **`update-task.sh --status started-work` advisory** — warn-only (not blocking) when the task's `## Verification` block contains the risky form, so the author can switch to the safe pattern *before* the task ships.

Detection heuristic (from spike): match `[^$<]\S+\s*\|\s*(grep -q|head -1|head -n 1)` *inside* `## Verification` (not in code-fence backticks); exempt the safe `out=$(...); echo "$out" | grep -q "..."` shape; exempt `command -v X | head -1` and `set -o pipefail` already-disabled blocks.

## Acceptance Criteria

### Agent
- [ ] New reviewer pattern `l387-sigpipe-risk` registered in `policy/anti-patterns.yaml` with the heuristic, severity=warn, scope=verification-block; schema_version bumped.
- [ ] `lib/reviewer/static_scan.py` parses `## Verification` blocks (line-by-line, skip comments, skip code fences) and emits the pattern when the heuristic matches; needs_human=no (it's deterministic).
- [ ] `agents/task-create/update-task.sh --status started-work` emits a non-blocking advisory WARN to stderr when the task's `## Verification` block matches the heuristic. Includes the safe-form replacement in the message. Override env: `FW_SKIP_L387_ADVISORY=1` (logged Tier-2). Does NOT block transition.
- [ ] Bats test `tests/unit/test_l387_detector.bats` pins the matrix: 15 positives (drawn from T-1716, T-1838, T-1862, T-1863, T-2036, and 10 corpus entries from the spike report) all flagged; 26 negatives (safe `out=$(cmd); echo "$out" | grep -q` forms, `command -v X | head -1` exemptions, code-fence false positives) all silent.
- [ ] `fw reviewer audit --pass-b` on the completed-task corpus reports the 15 known historical positives in its findings; no new false positives introduced (delta vs baseline ≤ 0).

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

out=$(bats tests/unit/test_l387_detector.bats 2>&1); echo "$out" | grep -q "ok 41"
out=$(python3 -c "import yaml; d=yaml.safe_load(open('policy/anti-patterns.yaml')); pats=[p['id'] for p in d.get('patterns',[])]; print('l387-sigpipe-risk' in pats)"); echo "$out" | grep -q "True"
out=$(bin/fw reviewer audit --pass-b --limit 50 2>&1); echo "$out" | grep -q "Pass-B"

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

## Updates

### 2026-05-28T07:43:29Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2059-l-387-sigpipe-detector--reviewer-pattern.md
- **Context:** Initial task creation
