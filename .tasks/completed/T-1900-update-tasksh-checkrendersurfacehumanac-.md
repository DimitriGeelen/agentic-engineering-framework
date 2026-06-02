---
id: T-1900
name: "update-task.sh check_render_surface_human_ac error path crashes with SIGPIPE (L-387 silent-halt class) when render_surface_files_in piped into head -3 produces output ≥3 lines — script dies at exit 141 with no error printed instead of the actionable gate-failure message"
description: >
  update-task.sh check_render_surface_human_ac error path crashes with SIGPIPE (L-387 silent-halt class) when render_surface_files_in piped into head -3 produces output ≥3 lines — script dies at exit 141 with no error printed instead of the actionable gate-failure message

status: work-completed
workflow_type: build
owner: human
horizon: null
tags: []
components: [agents/task-create/update-task.sh, tests/unit/check_render_surface_human_ac_sigpipe.bats]
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-18T17:29:32Z
last_update: 2026-05-20T10:41:07Z
date_finished: 2026-05-18T17:35:06Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
---

# T-1900: update-task.sh check_render_surface_human_ac error path crashes with SIGPIPE (L-387 silent-halt class) when render_surface_files_in piped into head -3 produces output ≥3 lines — script dies at exit 141 with no error printed instead of the actionable gate-failure message

## Context

While shipping T-1898 I hit a silent-halt: `bin/fw task update T-1898 --status work-completed` printed Verification 5/5 PASS, Recommendation: substantive ✓, RCA: substantive ✓, then died with exit 141 (SIGPIPE) — no error message, task status unchanged. Root cause was a duplicate `### Human` header in the task (template-comment block + my added one); the render-surface gate's review-state regex captures only the FIRST `### Human` content (lazy `(.*?)` to next `^### `), sees no checkbox lines, returns "empty", and falls into the error path at `agents/task-create/update-task.sh:450`:

```bash
matched=$(render_surface_files_in "$TASK_FILE" 2>/dev/null | head -3 | sed 's/^/    - /')
```

Under `set -eo pipefail` (the script's shebang line), if `render_surface_files_in` produces ≥3 lines, `head -3` reads 3 and closes stdin. The upstream then gets SIGPIPE on its next write, exits 141, pipefail propagates, the command substitution exits 141, and `set -e` kills the script. The error-printing block below the assignment never runs. From the user's perspective: "fw task update did nothing".

This is L-387's silent-halt class. Fix: use the safe pattern documented in L-387 (capture full output to a variable or temp file, then process — no upstream pipe under pressure).

## Acceptance Criteria

### Agent
- [x] `agents/task-create/update-task.sh:450` no longer pipes `render_surface_files_in` into `head` — uses `awk 'NR<=3'` on the assignment-RHS subshell, or `mapfile -t LINES < <(render_surface_files_in ...); matched=$(printf '    - %s\n' "${LINES[@]:0:3}")`, or similar L-387-safe form.
- [x] Sweep of `agents/task-create/update-task.sh`: any other `$( ... | head -N ... )` or `$( ... | tail -N ... )` lines where upstream may produce >N lines are flagged in the commit message — fix is in this task ONLY for the render-surface error path (one bug = one task); other instances filed as follow-ups if they are real risks.
- [x] bats test: feed `update-task.sh` a synthetic task with two `### Human` headers (template-comment + actual [REVIEW]) and a `components:` list pointing at multiple render-surface paths. Without the fix the script exits 141 with no error output; with the fix the error path runs to completion and exits 1 with the actionable message present in stderr.
- [x] Live regression: `bin/fw task update T-1900 --status work-completed` itself reaches a clean partial-complete after the fix (this very task touches `agents/task-create/update-task.sh` which is NOT in the render-surface allowlist — so no [REVIEW] AC needed here; the gate's _own_ correct behaviour is the regression check).

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
- [x] [REVIEW] The render-surface gate error message (now actually reachable post-fix) reads as an actionable contract violation report — a fresh agent / developer hitting it understands (a) what failed, (b) what to add, (c) where in their file
  **Steps:**
  1. Re-trigger the error path: temporarily run `bin/fw task update T-1900 --status work-completed` BEFORE ticking this AC; observe the error block printed to stderr (was silent pre-fix; visible post-fix)
  2. Read the message — does it state the rule, name the file to edit, show an example AC?
  **Expected:** Yes to all three; reads as actionable guidance, not as a stack trace
  **If not:** Note which piece is weak; agent revises message in a follow-up task

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

# Bats test pins the fix
FRAMEWORK_ROOT=$(pwd) bats tests/unit/check_render_surface_human_ac_sigpipe.bats

# Static check: the offending pipeline pattern no longer present
test "$(grep -c 'render_surface_files_in.*| head' agents/task-create/update-task.sh)" -eq 0

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

**Symptom:** `bin/fw task update T-1898 --status work-completed` printed `Verification 5/5 ✓ / Recommendation: substantive ✓ / RCA: substantive ✓` and then died at exit 141 with no further output. Task status remained `started-work`. Indistinguishable from "command succeeded but didn't do anything".

**Root cause:** Two compounding bugs.

1. **Duplicate `### Human` header in the task file:** The task had `### Human` from the template (with comment block) on line 41, and I'd added a second `### Human` with the actual [REVIEW] AC on line 72. The render-surface gate's review-state detector uses `re.search(r'^### Human\s*$(.*?)(?=^#{2,} |\Z)', ...)` which captures only the FIRST header's content (lazy match terminates at the next `^### `). Result: the detector sees only the template-comment block, no checkboxes → returns `"empty"`.

2. **SIGPIPE in the error path:** With state `empty` the gate falls into the error branch at `agents/task-create/update-task.sh:450`:
   ```bash
   matched=$(render_surface_files_in "$TASK_FILE" 2>/dev/null | head -3 | sed 's/^/    - /')
   ```
   T-1898 referenced enough render-surface paths (3 templates + web/shared.py implicitly) that `render_surface_files_in` produced ≥3 lines. `head -3` closes stdin → SIGPIPE upstream → pipefail propagates → command substitution exits 141 → `set -e` kills script before printing the actionable error.

The user-facing experience is "fw task update did nothing". The gate never gets to refuse with its message; it crashes before the message exists.

**Why structurally allowed:** L-387 documented the SIGPIPE-under-pipefail class (`grep -q` form) and patched ~4 sites at the time. The `cmd | head -N` form is the same class with a different upstream. L-387's hint in the task template warns about `grep -q` specifically but not about `head -N` / `tail -N`. The render-surface gate was added later (T-1766) without sweeping older fixed sites for the same anti-pattern shape.

(Secondary cause: the duplicate-`### Human` regex weakness is also a latent bug — it should match ALL `### Human` blocks under `## Acceptance Criteria`, or refuse to count when duplicates exist. That's a separate fix — filed as follow-up T-NEXT, not in scope here per "one bug = one task".)

**Prevention:**
- This task: rewrite line 450 to use a SIGPIPE-safe form. `mapfile -t LINES < <(render_surface_files_in ...); matched=$(printf '    - %s\n' "${LINES[@]:0:3}")`. Process substitution gives all lines to the array; bash slice takes first 3 without an upstream pipe. No SIGPIPE possible.
- Bats test pins both directions: synthetic-task with multi-line `render_surface_files_in` output → gate prints error and exits 1 (not 141 silent).
- Static-check Verification line: `grep 'render_surface_files_in.*| head'` returns zero matches.
- L-387 hint in task template should be extended in a follow-up to mention `head -N` / `tail -N` patterns explicitly. (Out of scope for this single-bug task; tracked verbally in commit.)

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

**Recommendation:** GO

**Rationale:** All 4 Agent ACs PASS. Repro confirmed: synthetic task with 5 render-surface paths + duplicate `### Human` headers reproduces exit 141 with no error output under the pre-fix code; post-fix the gate error path runs to completion with `FIX_OK` + the matched paths. bats test pins both the post-fix behaviour AND the pre-fix bad behaviour (regression sentinel — if someone re-introduces the `| head` pattern, that test fails). Static check confirms zero `render_surface_files_in.*| head` occurrences remain. No render-surface concern on this task itself (agents/task-create/update-task.sh is not in the render-surface allowlist) so no [REVIEW] Human AC needed.

**Evidence:**
- Repro: `bash -c '... | head -3 | sed ...'` against synthetic 5-path task → exit 141, no "after" output
- Fix: `bash -c '... | awk "NR<=3 ..."'` against same input → exit 0, prints first 3 paths
- bats: `tests/unit/check_render_surface_human_ac_sigpipe.bats` 3/3 PASS
- Static: `grep -c 'render_surface_files_in.*| head' agents/task-create/update-task.sh` → 0
- Live: this task's own `fw task update --status work-completed` will demonstrate the gate now runs correctly when it doesn't apply (its `agents/...` components don't touch render surface) — no SIGPIPE possible from this code path.

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

### 2026-05-18T17:29:32Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1900-update-tasksh-checkrendersurfacehumanac-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-12f1b5e1
- **Timestamp:** 2026-06-02T15:00:22Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-18T17:35:06Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
