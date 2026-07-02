---
id: T-2069
name: "Repair T-1845 frontmatter folded-scalar bleed + tighten audit guard to also
  flag empty-dict parses"
description: >
  Repair T-1845 frontmatter folded-scalar bleed + tighten audit guard to also flag
  empty-dict parses

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [C-004]
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-28T15:05:38Z
last_update: '2026-06-11T22:24:06Z'
date_finished: 2026-05-28T15:16:08Z
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
  - ts: '2026-05-28T15:15:01Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-28T15:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:24:06Z'
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

# T-2069: Repair T-1845 frontmatter folded-scalar bleed + tighten audit guard to also flag empty-dict parses

## Context

T-1845's frontmatter uses `description: >` (folded scalar) followed by a blank line, then `Deliverables:` (col-0), then a numbered list (col-0). The blank line terminates the folded scalar, then YAML tries to parse `Deliverables:` as a new key and `1. ...` as another key without `:` — `yaml.safe_load` raises `ScannerError`. `web.shared.parse_frontmatter` catches the exception and returns `{}` (empty dict, NOT False), so T-2067's audit guard (which only checks `fm is False or fm is None`) silently misses this whole class. T-1845 is the only current corpus victim; tightening the guard prevents the next one.

## Acceptance Criteria

### Agent
- [x] T-1845 frontmatter parses with len(fm) > 0 (description: rewritten as quoted single-string; Deliverables list survives in description text) — verified: 14 keys, id=T-1845, status=work-completed
- [x] `agents/audit/audit.sh` structure check tightened to flag both `fm is False` AND empty-dict (`len(fm) == 0`) parses — same class, different python-yaml outcome; exit codes 2 (False/None) and 3 (empty-dict) distinguish causes for diagnostic
- [x] Direct batch parse-walk across all 2035 task files returns 0 failures — confirms T-1845 was the only victim and the regression net catches the broader empty-dict class going forward

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

python3 -c "import sys; sys.path.insert(0,'.'); from web.shared import parse_frontmatter; fm,_=parse_frontmatter(open('.tasks/completed/T-1845-pre-commit-large-file-gate--untrack-acci.md').read()); sys.exit(0 if (isinstance(fm,dict) and len(fm)>0) else 1)"
bash -n agents/audit/audit.sh
python3 -c "import sys, os; sys.path.insert(0,'.'); from web.shared import parse_frontmatter; fails=[]; [fails.append(p) for p in [f'{r}/{fn}' for r in ['.tasks/active','.tasks/completed'] for fn in os.listdir(r) if fn.startswith('T-') and fn.endswith('.md')] if (lambda fm: fm is False or fm is None or (isinstance(fm,dict) and len(fm)==0))(parse_frontmatter(open(p).read())[0])]; sys.exit(0 if not fails else 1)"

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

**Symptom:** `parse_frontmatter()` on `.tasks/completed/T-1845-*.md` returned an empty dict (NOT False) — Watchtower `/review/T-1845` and `/tasks/T-1845` would render without metadata or 404 depending on route guard. Single corpus victim.

**Root cause:** YAML folded scalar `description: >` followed by a blank line, then col-0 lines (`Deliverables:`, `1. agents/...`, `2. Pre-commit...`). The blank line terminates the folded scalar; YAML then tries to parse `Deliverables:` as a new top-level key and `1. agents/...` as another key — `yaml.safe_load` raises `ScannerError: could not find expected ':'`. `web.shared.parse_frontmatter` catches the exception and returns `({}, body)` instead of `(False, body)`.

**Why structurally allowed:** T-2067's audit guard correctly catches both via Python truthiness (`bool({}) == False`), but the diagnostic message attributed all failures to the components-regex class, masking the folded-scalar class. Author-time, no static-scan exists for "frontmatter has folded-scalar that bleeds at blank lines" — yaml itself raises the right error, but T-1845 was authored before T-2067's audit guard landed (2026-05-15 vs 2026-05-28), so the failure sat dormant for 13 days.

**Prevention:** (1) Audit guard now distinguishes False vs empty-dict exit codes — operators get a class-specific hint pointing at folded-scalar or quoting break rather than chasing a components-regex false trail. (2) The guard already catches the class via truthiness; this fix is diagnostic precision, not coverage extension.

<!-- Template guidance kept below for next bug-class author:
     REQUIRED for bug-class tasks (workflow_type=build with bug-tag, OR title matches
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

### 2026-05-28T15:05:38Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2069-repair-t-1845-frontmatter-folded-scalar-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-068a9017
- **Timestamp:** 2026-06-02T15:00:58Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-28T15:16:08Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
