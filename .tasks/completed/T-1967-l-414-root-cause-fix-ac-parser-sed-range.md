---
id: T-1967
name: "L-414 root-cause fix: AC parser sed-range comment strip swallows Agent ACs
  when one-line HTML comments precede the section"
description: >
  L-414 root-cause fix: AC parser sed-range comment strip swallows Agent ACs when
  one-line HTML comments precede the section

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [ac-parser, bug, L-414-rootcause, update-task, arc:bvp]
components: []
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-20T19:20:25Z
last_update: '2026-06-11T22:24:04Z'
date_finished: 2026-05-20T19:26:00Z
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
  - ts: '2026-06-11T22:24:04Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); 
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1967: L-414 root-cause fix: AC parser sed-range comment strip swallows Agent ACs when one-line HTML comments precede the section

## Context

L-414 root cause: `agents/task-create/update-task.sh:check_acceptance_criteria()` line 87 uses `sed '/<!--/,/-->/d'` to strip HTML comments before parsing ACs. sed range matching does NOT see the closing pattern on the SAME line as the opening pattern — it waits for the NEXT line containing `-->`. Consequence: a one-line `<!-- helper comment -->` directly under `### Agent` (the template default) causes sed to enter delete-mode at that line and stay there until it finds another `-->` later in the file — typically inside `### Human`'s multi-line example comment. Everything between (including the 7 ticked Agent ACs) is silently swallowed.

T-1941 hit this: parser reported 1/1 AC (just the [REVIEW]) and refused completion, masking 7 ticked Agent ACs above. `--skip-acceptance-criteria` was required to bypass.

Fix: replace the single sed range with a two-step strip — first remove same-line comments (`sed -E 's/<!--[^>]*-->//g'`), then run the range strip for genuine multi-line comments.

## Acceptance Criteria

### Agent
- [x] `check_acceptance_criteria()` in `agents/task-create/update-task.sh` strips one-line `<!-- ... -->` comments BEFORE applying the range strip — two-step: `sed -E 's/<!--[^>]*-->//g' | sed '/<!--/,/-->/d'` at line 87 and again at line 950 (`Re-checking partial-complete` branch)
- [x] Bats regression test `tests/unit/ac_counter_sed_range_one_line_comment.bats` — 5 tests cover the fix, the regression repro (single-step pipeline returns 0 ticks when 2 expected), preserved counting of real Human ACs, and `bash -n` parse. All 5 PASS.
- [x] Manual reproduction confirmed fixed: re-running the parser on T-1941's body (the L-414 origin) returns `agent_acs total: 7, checked: 7, human_acs total: 1, checked: 0` — matches the file's actual state.

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

grep -q "T-1967" agents/task-create/update-task.sh
test $(grep -c "sed -E 's/" agents/task-create/update-task.sh) -ge 2
bash -n agents/task-create/update-task.sh
out=$(bats tests/unit/ac_counter_sed_range_one_line_comment.bats 2>&1); grep -qE '^ok [0-9]+' <<<"$out" && ! grep -qE '^not ok' <<<"$out"

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

**Symptom:** T-1941 close was refused by P-010 with "1/1 agent AC unchecked" while the task file had 7 ticked Agent ACs and 1 unchecked Human [REVIEW] AC. The parser miscounted — the 7 Agent ACs were invisible. Workaround: `--skip-acceptance-criteria` to bypass (Tier-2 logged).

**Root cause:** `agents/task-create/update-task.sh:check_acceptance_criteria()` uses `sed '/<!--/,/-->/d'` to strip HTML comments from the AC section before counting. sed's range operator `/A/,/B/` does NOT see B on the SAME line as A — it waits for the NEXT line containing B. The template default places a one-line `<!-- Criteria the agent can verify ... -->` directly under `### Agent`. sed enters delete-mode on that line and waits for the next `-->`, which lives inside the `### Human` multi-line example comment ~40 lines later. Everything between (the 7 ticked Agent ACs + the `### Human` header) is silently swallowed.

**Why structurally allowed:** Two factors combined to create the silent fault.
1. The bug only triggers when BOTH a one-line helper comment under `### Agent` AND a multi-line example comment under `### Human` are present. The split-AC template ships with exactly that combination as the default. So the bug is dormant whenever a task has NO Human section, NO multi-line comment, or NO one-line helper — which is most legacy tasks. It only fires on the modern split-AC template.
2. The sibling cousin family (T-1620, lib/inception.sh + lib/verify-acs.sh) was fixed with Python regex (`re.DOTALL`) which handles same-line comments correctly. The update-task.sh implementation pre-dates T-1620 and uses pure sed — and the sed quirk was not documented or pinned by a regression test on this code path.

**Prevention:**
1. **Code fix (this task):** two-step strip — `sed -E 's/<!--[^>]*-->//g'` first (handles one-line), then `sed '/<!--/,/-->/d'` for multi-line.
2. **Regression test (this task):** `tests/unit/ac_counter_sed_range_one_line_comment.bats` — 5 tests, including a regression repro that confirms the OLD single-step pipeline still swallows ACs. If anyone reverts the fix, the repro test will fail.
3. **Sibling code paths checked:** the same sed strip appears at line 950 (the partial-complete recheck branch). Fixed in the same task — both call sites now use the two-step pattern.
4. **L-414 (filed earlier) → L-414-rootcause cross-link:** the inline learning is now backed by a structural fix + test.

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

### 2026-05-20 — Two call sites, not one
- **What changed:** Filing assumed a single sed strip line in `check_acceptance_criteria()`. Grep revealed a second copy on line 950 (the `OLD_STATUS = NEW_STATUS = work-completed` partial-complete recheck branch). Fixing only one site would have left a stealth-failure path: closing a fresh task → fine; re-running update on a partial-complete → still buggy.
- **Plan impact:** Scope grew from 1 line edit to 2; both sites now use identical two-step pattern. The second site references the first ("see line ~87") to keep the rationale co-located.
- **Triggered:** No new task. Captured here so a future audit (or someone re-reading the diff) knows to look for the cousin call site.

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

### 2026-05-20T19:20:25Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1967-l-414-root-cause-fix-ac-parser-sed-range.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-1d61a084
- **Timestamp:** 2026-06-02T15:00:41Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-20T19:26:00Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
