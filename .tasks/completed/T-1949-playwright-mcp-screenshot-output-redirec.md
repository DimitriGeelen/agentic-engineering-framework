---
id: T-1949
name: "Playwright MCP screenshot output redirect + cleanup 82 root PNGs (12 MB)"
description: >
  Playwright MCP screenshot output redirect + cleanup 82 root PNGs (12 MB)

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-20T09:01:05Z
last_update: '2026-06-11T22:24:04Z'
date_finished: 2026-05-21T08:59:53Z
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
  - ts: '2026-05-20T09:15:01Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-20T09:15:01Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 3
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=3 (body:portability-abstraction)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:24:04Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 3
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=3 (body:portability-abstraction); F-RECALL=2 
      (body:lightly-promoted); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1949: Playwright MCP screenshot output redirect + cleanup 82 root PNGs (12 MB)

## Context

82 untracked PNGs (12 MB total) accumulated in the repo root over ~3 months from
Playwright MCP browser-automation screenshot output writing to cwd. Already
gitignored via `*.png` but no cleanup mechanism. Two-part fix: (a) configure
Playwright MCP to write to a dedicated subdir (root cause), (b) one-shot remove
the existing 82 files.

## Acceptance Criteria

### Agent
- [x] `.mcp.json` Playwright server gets `--output-dir` (or equivalent flag) pointing to a non-root subdir (likely `.context/screenshots/` or `/tmp/playwright-mcp/`) — verified by reading the MCP server's actual `--help` output
- [x] Chose `/tmp/playwright-mcp` (ephemeral, not project-tracked). Existing `*.png` gitignore covers any drift back to cwd as belt-and-braces
- [x] 82 root-level PNGs removed; root has zero `*.png` / `*.jpg` / `*.jpeg` / `*.gif`
- [x] Repo size: 343 MB → 332 MB (11 MB reclaimed)
- [x] `.gitignore` comment updated to reference `/tmp/playwright-mcp/` and T-1949
- [x] Post-config residual cleanup (2026-05-21): 4 PNGs landed in repo root *after* `--output-dir` config went live (arc-badge-before/after.png from T-1969 visual diff; badge-contrast-after.png + badge-contrast-arcs-after.png from T-1970). Root cause: Playwright MCP `browser_take_screenshot` honours `--output-dir` only for *auto-named* screenshots; when called with explicit `filename: "X.png"` (no path prefix), it still writes relative to cwd. Mitigation in this task: relocated T-1970 evidence to `docs/reports/T-1970-evidence/` (gitignore exception added: `!docs/reports/T-*-evidence/*.png`); deleted unreferenced T-1969 visual-diff PNGs (T-1969's [REVIEW] AC is structural — `' · '` separator — verifiable without the PNGs)
- [x] gitignore exception added at `.gitignore:54` to track per-task evidence subdirs (`!docs/reports/T-*-evidence/*.png`) — symmetric with existing `T-*-demo-evidence/` exception

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

## Recommendation

**Recommendation:** GO

**Rationale:** Auto-named MCP screenshot output is redirected to `/tmp/playwright-mcp/` (verified by `.mcp.json` args); the original 82-PNG repo bloat (12 MB) was reclaimed; the gitignore guard remains in place as belt-and-braces for the *named*-screenshot case where Playwright MCP still honours cwd. The 4 PNGs that landed in repo root since the original fix are now relocated to per-task evidence subdirs (with a fresh gitignore exception for tracked evidence), so the root tree is clean again and T-1970's visual evidence is preserved at a stable path.

**Evidence:**
- `ls *.png *.jpg *.jpeg *.gif | wc -l` → 0 (root clean)
- `.mcp.json` args contain `--output-dir /tmp/playwright-mcp`
- `.gitignore:54` exception `!docs/reports/T-*-evidence/*.png` (symmetric with existing `T-*-demo-evidence/`)
- T-1970 evidence relocated to `docs/reports/T-1970-evidence/` and references updated in `.tasks/active/T-1970-…md:92,283`
- Followup gap captured inline in AC#5: named screenshots still bypass `--output-dir`; mitigation is the standing gitignore. No new follow-up task — the inline gitignore guard plus the cleanup pattern (relocate to `T-*-evidence/`) is sufficient prevention.

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

test "$(ls *.png *.jpg *.jpeg *.gif 2>/dev/null | wc -l)" -eq 0
python3 -c "import json; c=json.load(open('.mcp.json')); args=c['mcpServers']['playwright']['args']; assert any('output' in a.lower() or 'dir' in a.lower() for a in args), 'no output-dir flag'"
grep -q '!docs/reports/T-\*-evidence/\*.png' .gitignore

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

### 2026-05-20T09:01:05Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1949-playwright-mcp-screenshot-output-redirec.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f343eca4
- **Timestamp:** 2026-06-02T15:00:37Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#6 (Agent)** — Post-config residual cleanup (2026-05-21): 4 PNGs landed in repo root *after* `--output-dir` config went live (arc-badge-before/after.png from T-1969 visual diff; badge-contrast-after.png + badge-cont
  - **AC-verify-mismatch** (narrow, heuristic) — `path=arc-badge-before/after.png in: Post-config residual cleanup (2026-05-21): 4 PNGs landed in repo root *after* `--output-dir` config went live (arc-badge-before/after.png from T-1969 `
### 2026-05-21T08:59:53Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
