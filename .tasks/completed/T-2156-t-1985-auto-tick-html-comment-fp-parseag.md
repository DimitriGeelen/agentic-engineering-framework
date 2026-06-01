---
id: T-2156
name: "T-1985 auto-tick HTML-comment FP: _parse_agent_acs skips bullets inside markdown comments (OBS-047)"
description: >
  Parser-level fix for the T-1985 auto-tick FP class surfaced under T-2155: when an author drops the template's '### Human' heading but keeps its HTML-commented documentation block, the '- [ ] [REVIEWER] Block message names both bypass mechanisms' example bullet at template line 67 gets parsed as a real '### Agent' AC and auto-ticked on PASS. 9+ closed tasks already carry the FP-ticked line. Fix: track <!--/--> state in _parse_agent_acs and skip lines inside, plus same skip in detect_ac_evidence_untick and any other AC-iterating detectors that need it. HV-LC, arc-003 reviewer governance, direct continuation of T-2155.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [arc-003, reviewer, auto-tick-fp, t-2155-followup]
components: []
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-06-01T09:06:12Z
last_update: 2026-06-01T09:11:36Z
date_finished: 2026-06-01T09:11:36Z
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

# T-2156: T-1985 auto-tick HTML-comment FP: _parse_agent_acs skips bullets inside markdown comments (OBS-047)

## Context

OBS-047 (filed this session under T-2155 work) discovered the T-1985 auto-tick subsystem ticks the `- [ ] [REVIEWER] Block message names both bypass mechanisms` bullet that lives **inside an HTML comment** at template line 67. Mechanism: `_parse_agent_acs` in `lib/reviewer/static_scan.py:216` iterates lines with no HTML-comment awareness, so when an author drops the `### Human` heading while editing the AC section in-place (the L-449 anti-pattern, OBS-041 origin), the bullets in the template's documentation comment get counted as Agent ACs and the auto-tick pass happily flips them to `[x]`. 9+ closed tasks already carry the FP-ticked line (T-1985, T-1857, T-1851, T-1855, T-1890, T-1903, T-1893, T-1854, T-2155).

This is a defense-in-depth fix paired with L-449's author-time discipline: even when the author forgets the `### Human` header, HTML-commented bullets must not be parsed as live ACs. L-414 documents the sed-range pitfall (single-line `<!-- ... -->` followed by multi-line block can swallow content); the parser here uses Python so `re.sub(..., re.DOTALL)` handles both shapes correctly.

Scope: parser-level only. **Not** un-ticking the 9 historical FP-ticked entries — those are inside HTML comments that no human reads, the completion gate already passed those tasks, and editing closed-task bodies needs Tier-2 reasoning. Future regenerations of those tasks (e.g. when their reviewer is re-run) will silently no-op-correct.

## Acceptance Criteria

### Agent
- [x] `_strip_html_comments(text)` helper added to `lib/reviewer/static_scan.py` using Python `re.sub` with `re.DOTALL` (L-414 protection — sed-range alternative is unsafe for mixed single+multi-line shapes).
- [x] `_parse_agent_acs(ac_section)` strips HTML comments before line iteration; docstring updated to reference T-2156 + OBS-047.
- [x] Unit tests in `tests/unit/test_reviewer_html_comment_strip.py` cover: (a) single-line `<!-- ... -->` containing a bullet, (b) multi-line comment block containing a bullet, (c) mixed real-AC + commented-AC, (d) L-414 cross-class shape (single-line opener directly followed by multi-line block — Python `re.DOTALL` handles correctly), (e) `_strip_html_comments` unit cases, (f) parsing T-2155's actual file post-fix returns 6 Agent ACs (not 8). 9 tests, all pass.
- [x] Full reviewer test suite still green: `python3 -m pytest tests/unit/test_reviewer_*.py -q` → 304 passed in 3.07s.
- [x] Smoke: re-parsing T-2155's body returns exactly 6 entries (verified inline via `python3 -c ... count={len(ss._parse_agent_acs(...))}` → `count=6`).

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

# T-2156 verification (L-387 safe):
grep -q "def _strip_html_comments" lib/reviewer/static_scan.py
grep -q "ac_section = _strip_html_comments" lib/reviewer/static_scan.py
python3 -c "import ast; ast.parse(open('lib/reviewer/static_scan.py').read())"
out=$(python3 -m pytest tests/unit/test_reviewer_html_comment_strip.py -q 2>&1); echo "$out" | grep -qE "[0-9]+ passed"
out2=$(python3 -m pytest tests/unit/test_reviewer_*.py -q 2>&1); echo "$out2" | grep -qE "[0-9]+ passed"
out3=$(python3 -c "import sys; sys.path.insert(0, '.'); from lib.reviewer import static_scan as ss; from pathlib import Path; tf=Path('.tasks/completed/T-2155-reviewer-detector--agent-ac-body-evidenc.md'); _,b=ss.parse_task_file(tf); s=ss.extract_section(b,'Acceptance Criteria') or ''; print(f'count={len(ss._parse_agent_acs(s))}')" 2>&1); echo "$out3" | grep -q "count=6"

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

**Rationale:** Defense-in-depth parser fix paired with L-449's author-time discipline. 5/5 Agent ACs pass, 9 new unit tests cover the spec'd 5 cases + 4 extras (multi-shape stripping, real-bullet-still-counts negative, no-op preservation, T-2155 actual-file regression), full 304-test reviewer suite stays green. Python `re.DOTALL` strip avoids the L-414 sed-range pitfall by construction. Closed tasks carrying FP-ticked template lines are not retroactively modified — the FP lives inside HTML comments that no human reads, and the next reviewer scan of any affected task will silently no-op-correct the parse (the auto-tick can't re-flip already-`[x]`'d lines without a fresh untick from a human first; T-1985 sovereignty rail via feedback-stream digest still holds).

**Evidence:**
- Helper: `lib/reviewer/static_scan.py` — `_strip_html_comments(text)` with `re.DOTALL`; T-2156 comment block + L-414 reference.
- Parser: `_parse_agent_acs` strips first via `ac_section = _strip_html_comments(ac_section)`.
- Unit tests: `tests/unit/test_reviewer_html_comment_strip.py` — `9 passed in 0.11s`. Cases (a)…(i).
- Regression: `python3 -m pytest tests/unit/test_reviewer_*.py -q` → `304 passed in 3.07s` (up from 295 baseline + 9 new = matches).
- T-2155 smoke: `_parse_agent_acs` on the closed T-2155 body returns `count=6` (was 8 pre-fix — the AC#7 [REVIEW] and AC#8 [REVIEWER] template-comment FPs are gone).

**What's next:**
- L-449 author-time hook: still TBD. A PreToolUse hook on Write/Edit that detects `### Agent` without a closing subhead before `## Verification` would catch the L-449 anti-pattern at author time. Not in scope for this slice — separate concern, separate task if it surfaces again.
- Historical FP cleanup: the 9 closed tasks with auto-ticked template lines stay as-is. A retroactive un-tick sweep would need sovereignty-aware reasoning and is not worth the touch — the FP lines live in documentation comments that nobody reads.

## Updates

### 2026-06-01T09:06:12Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2156-t-1985-auto-tick-html-comment-fp-parseag.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f75d648c
- **Timestamp:** 2026-06-01T09:11:40Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-01T09:11:36Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
