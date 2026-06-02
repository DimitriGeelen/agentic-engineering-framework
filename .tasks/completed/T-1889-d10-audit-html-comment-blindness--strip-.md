---
id: T-1889
name: "D10 audit HTML-comment-blindness — strip <!-- --> before counting Human ACs"
description: >
  D10 audit HTML-comment-blindness — strip <!-- --> before counting Human ACs

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [arc-grooming, audit, false-positive, prevention]
components: [agents/audit/audit.sh, tests/unit/audit_d10_html_comment_blindness.bats]
related_tasks: [T-248, T-1455, T-1846, T-1687]
arc_id: arc-grooming
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-17T21:34:05Z
last_update: 2026-05-17T21:37:10Z
date_finished: 2026-05-17T21:37:10Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
---

# T-1889: D10 audit HTML-comment-blindness — strip <!-- --> before counting Human ACs

## Context

D10 audit ("Decision-without-dialogue") counts `[ ]` / `[x]` markers inside the `### Human` section to detect inception/specification tasks that closed without human review. The current implementation (`agents/audit/audit.sh:2604-2611`) uses naked `human_text.count("[x]")` / `human_text.count("[ ]")` which also counts checkboxes inside `<!-- ... -->` template stubs.

T-1455 has a `### Human` section consisting only of the default template comment block (which contains an example `- [ ] [REVIEW] Dashboard renders correctly` line). D10 false-positive-flags it as "Human ACs exist but none checked".

Canonical strip-comments pattern already used elsewhere: `lib/inception.sh:517` uses `sed '/<!--/,/-->/d'` before counting ACs. D10 should do the same.

Connection to arc-grooming: T-1846 (arc-grooming inception anchor) is correctly D10-flagged (human [REVIEW] AC genuinely waits). T-1455 false-positive dilutes the signal during arc-grooming review.

## Acceptance Criteria

### Agent
- [x] `agents/audit/audit.sh` D10 check strips `<!-- ... -->` comment blocks from the human-section text before counting `[ ]` / `[x]` markers (same canonical pattern as `lib/inception.sh:517`)
- [x] `tests/unit/audit_d10_html_comment_blindness.bats` exists with 3 cases: template-stub-only section (silent), real unchecked AC (fires), real checked AC (silent)
- [x] `bin/fw audit --section discovery` against the current tree no longer flags T-1455 (T-1846 still flagged correctly — real Human AC unticked)

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
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

bats tests/unit/audit_d10_html_comment_blindness.bats
out=$(bin/fw audit --section discovery 2>&1); echo "$out" | grep -q "T-1455" && exit 1 || true
out=$(bin/fw audit --section discovery 2>&1); echo "$out" | grep -q "T-1846" && exit 0 || true

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

### 2026-05-17 — D10 false-positive scope

- **What changed:** During investigation, found that D10 is the only checkbox-counter in the audit that doesn't strip HTML comments. The canonical pattern (`sed '/<!--/,/-->/d'`) already lives at `lib/inception.sh:517` for the inception decide-preflight; D10 was written independently and didn't reuse it.
- **Plan impact:** Scope contained — single one-line fix at the count site, plus a bats suite to pin behaviour. No other audit checks share the bug.
- **Triggered:** Nothing — this is the full slice. The bats suite forward-pins; no further work needed.

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

**Recommendation:** GO — work-completed.

**Rationale:** One-line addition + 4 bats tests. Eliminates the HTML-comment-blindness class of D10 false positives without weakening the real check (T-1846 still flagged). Same canonical strip pattern as `lib/inception.sh:517` — consistency improvement, not new behaviour.

**Evidence:**
- `agents/audit/audit.sh:2604-2618` — added `re.sub(r'<!--.*?-->', '', human_text, flags=re.DOTALL)` before counting (with origin comment)
- `tests/unit/audit_d10_html_comment_blindness.bats` — 4/4 cases PASS
- Live verification: `bin/fw audit --section discovery` BEFORE flagged `T-1846 T-1455`; AFTER flags only `T-1846` (real signal preserved, false-positive removed)

**Arc-grooming impact:** Arc-grooming review cycle now gets cleaner D10 signal. T-1846's flag is real (Human [REVIEW] AC deliberately left unticked per CLAUDE.md). T-1455's flag was noise from the default template stub.

**Future-prevention:** The bats suite pins the strip-comments behaviour. Any future refactor of D10 that removes the strip-comments call will fail test #1.

## RCA

**Symptom:** D10 audit reported 2 flagged tasks (T-1846 T-1455), but T-1455 had no real Human ACs — just the default template stub example inside `<!-- ... -->`.

**Root cause:** D10's checkbox counter used naked `human_text.count("[ ]")` without first stripping HTML comments. The default template's example `- [ ] [REVIEW] Dashboard renders correctly` (commented out) was indistinguishable from a real unchecked AC.

**Why structurally allowed:** The canonical strip-comments pattern exists at `lib/inception.sh:517` (`sed '/<!--/,/-->/d'` used by the inception preflight) but D10 was written independently and didn't reuse it. No lint or test pinned D10's behaviour against template-only sections.

**Prevention:** (1) The fix lives at the count site — `re.sub(r'<!--.*?-->', '', ..., flags=re.DOTALL)` before counting; (2) bats test pins the behaviour for the 4 representative cases (template-stub silent, real unchecked fires, real checked silent, mixed not double-counted). Future code that re-introduces the bug fails test #1.

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

### 2026-05-17T21:34:05Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1889-d10-audit-html-comment-blindness--strip-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-8d4176a4
- **Timestamp:** 2026-06-02T15:00:17Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-17T21:37:10Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
