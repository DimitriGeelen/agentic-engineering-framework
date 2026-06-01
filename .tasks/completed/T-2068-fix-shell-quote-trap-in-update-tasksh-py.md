---
id: T-2068
name: "fix shell-quote trap in update-task.sh python3 -c comment block - T-2067 follow-up"
description: >
  fix shell-quote trap in update-task.sh python3 -c comment block - T-2067 follow-up

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [bug, framework-tooling, shell-quoting, immediate-followup]
components: [agents/task-create/update-task.sh]
related_tasks: [T-2067, T-1879]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-28T14:26:43Z
last_update: 2026-05-28T14:29:40Z
date_finished: 2026-05-28T14:29:40Z
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

# T-2068: fix shell-quote trap in update-task.sh python3 -c comment block - T-2067 follow-up

## Context

T-2067 added a multi-line comment block above `pattern = re.compile(...)` inside the `python3 -c '...'` invocation at `agents/task-create/update-task.sh:1723-1751`. The comment included a literal pair of double-quote characters around a sample render-page label. Bash terminated the script string at the first inline double-quote, shifted argv positions, and the next `--status work-completed` run crashed with `OSError: [Errno 36] File name too long: '...comment text...'` because the comment text was being passed where `$TASK_FILE` should have been.

The bug surfaced during T-2067 own `--status work-completed` (irony — the regex fix shipped fine, the comment broke the runtime). Task closure succeeded (file moved to completed/), but the post-completion git-history components resolution step crashed loudly.

Same class as L-408 (NEVER edit bin/fw heredoc/command-substitution constructs without bash -n verification) — except `bash -n` alone does not catch this because the syntax IS valid at parse time; quote-balancing breaks only when bash expands the inline content at runtime.

## Acceptance Criteria

### Agent
- [x] Replace the offending inline double-quoted phrase in update-task.sh:1737 with safer wording.
- [x] Add an inline NOTE comment so the next author sees the trap.
- [x] Confirm next `--status work-completed` runs cleanly (no traceback from the python3 -c block).

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

bash -n agents/task-create/update-task.sh
n=$(sed -n '1729,1746p' agents/task-create/update-task.sh | grep -c '"'); test "$n" = "0"

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

## RCA

**Symptom:** Closing T-2067 via `fw task update T-2067 --status work-completed` succeeded (file moved to completed/) but printed an OSError traceback from the post-completion components-resolution step: `OSError: [Errno 36] File name too long: '<long comment text>'`.

**Root cause:** T-2067's commit added a multi-line comment inside the `python3 -c "..."` block at update-task.sh:1723-1751. The comment included a literal pair of double-quote characters around a sample render-page label. Bash terminated the `python3 -c` script at the first inline double-quote, then resumed parsing at the next one, and what was meant to be `$TASK_FILE` argv[2] ended up being the comment text — hence the "File name too long" OSError when Python tried to open it.

**Why structurally allowed:** `bash -n` only catches parse-time syntax errors. Quote-balance breakage inside a double-quoted string is only detected when the shell expands the inline content at runtime — well after the parser ok'd the syntax. L-408 (the bin/fw heredoc rule) was the closest precedent but it specifically named bin/fw; update-task.sh got the same trap. No automated guard rejects inline `"` inside a `python3 -c "..."` block.

**Prevention:** (1) Inline NOTE comment in the affected block warns the next author of the trap; (2) Verification command `grep -c '"' < block` asserts zero inline double-quotes in the comment span so a future edit that re-introduces the bug breaks the gate; (3) the comment uses the phrase "double-quote character (ASCII 0x22)" so the warning itself doesn't contain the trap character.

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

## Recommendation

**Recommendation:** GO — shipped.

**Rationale:** One-character class trap caught at first run; mitigation is a comment + a verification grep. The bug surfaced because T-2067 was self-applying its own fix in the act of closing itself (delicious irony). Same class as L-408 but in a sibling script; this task pins the trap structurally so the next author who writes a python3 -c heredoc block here sees the rule.

**Evidence:**
- `bash -n agents/task-create/update-task.sh` passes.
- `sed -n '1729,1746p' agents/task-create/update-task.sh | grep -c '"'` returns 0 (no inline double-quotes in comment block).
- Smoke-test: synthetic frontmatter (`/tmp/.t2068-fixture.md`) with `components: [a, b]` → after python3 -c invocation → `components: [x, y, z]` correctly rewritten, no traceback.

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

### 2026-05-28T14:26:43Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2068-fix-shell-quote-trap-in-update-tasksh-py.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-87d3d953
- **Timestamp:** 2026-05-28T14:29:42Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-28T14:29:40Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
