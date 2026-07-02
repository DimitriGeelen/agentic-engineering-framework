---
id: T-2067
name: "fix update-task.sh components: flow-style continuation regex (T-2062 RCA outcome)"
description: >
  fix update-task.sh components: flow-style continuation regex (T-2062 RCA outcome)

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [agents/task-create/update-task.sh]
related_tasks: [T-2062, T-2018, T-2059, T-2060, T-2061]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-28T14:17:41Z
last_update: '2026-06-11T22:24:06Z'
date_finished: 2026-05-28T14:25:21Z
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
  - ts: '2026-06-11T22:24:06Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 2
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=2
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); 
      F2=1 (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-2067: fix update-task.sh components: flow-style continuation regex (T-2062 RCA outcome)

## Context

`agents/task-create/update-task.sh:1731` auto-resolves the `components:` frontmatter field from git history on `--status work-completed`. The replacement regex is:

```python
pattern = re.compile(r'^components:[^\n]*\n(?:[ \t]+-[^\n]*\n)*', re.MULTILINE)
```

This matches the `components:` line plus block-style continuation lines (`  - item`). It does **NOT** match flow-style continuation lines (e.g. when an Edit operation wrapped a long flow list at `,`). So a pre-existing wrap like:

```yaml
components: [a, b, c,
      d]
```

…gets the first line replaced and leaves the orphan `      d]` — net result:

```yaml
components: [a, b, c, new-resolved]
      d]
```

Invalid YAML. `parse_frontmatter()` returns False. `/review/T-XXX` then renders the "Task Not Found" 404 page (the 200-for-completed branch never fires).

4 corpus victims found this session: T-2018, T-2059, T-2060, T-2061 (3 of those are tasks I closed earlier this session and the prior — the symptom appeared as soon as I handed off /review/ URLs to the user). All 4 repaired in commit preceding this task (see Updates).

The fix is contained: extend the regex to also eat flow-style continuation lines (any indented line that isn't a new YAML key).

## Acceptance Criteria

### Agent
- [x] Regex in `agents/task-create/update-task.sh:1731` accepts both block-style (`  -`) and flow-style (indented continuation) `components:` line shapes — orphan continuation lines no longer remain after replacement.
- [x] Bats fixture `tests/unit/test_components_replacement_regex.bats` pins the regex against (a) flat single-line flow list, (b) wrapped flow list (origin bug), (c) pre-mangled orphan continuation (idempotent cleanup), (d) block-style list, (e) empty flow, (f) next-YAML-key not eaten by continuation match. 6/6 green.
- [x] Audit run across `.tasks/{active,completed}/` after fix — only T-1845 remains frontmatter-broken (different class: folded scalar + numbered-list body, pre-T-2067).
- [x] `fw audit` learns to detect frontmatter-broken tasks and surface a WARN; defense in depth for the regex fix (added to STRUCTURE CHECKS in audit.sh).

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

bats tests/unit/test_components_replacement_regex.bats > /tmp/.t2067-bats.out 2>&1; grep -q "^ok 6" /tmp/.t2067-bats.out
bash -n agents/task-create/update-task.sh
bash -n agents/audit/audit.sh
python3 -c "import sys; sys.path.insert(0, '.'); from web.shared import parse_frontmatter; import glob; bad = [f for f in glob.glob('.tasks/active/T-*.md') + glob.glob('.tasks/completed/T-*.md') if not parse_frontmatter(open(f).read())[0]]; assert len(bad) <= 1, f'unexpected new frontmatter breakage: {bad}'"

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

**Symptom:** `/review/T-XXX` returned HTTP 404 "Task Not Found" for several recently-closed tasks (T-2059, T-2060, T-2061). User asked "2061 2059 404 task not found ???!" — T-2062 inception scoped the symptom as a route logic bug. Empirical exploration during T-2063 work surfaced the real cause: the route is fine; frontmatter YAML parsing was failing, and the 404 page is what `_render_review_404(reason="not_found")` renders when `parse_frontmatter()` returns False.

**Root cause:** `agents/task-create/update-task.sh:1731` auto-rewrites the `components:` frontmatter field from git history on `--status work-completed`. The regex matched the `components:` line + block-style continuations (`  -`) but NOT flow-style continuations (lines like `      d]`). When a previous Edit/Write had already wrapped the flow list, the regex replaced only line 1 and left the orphan closing-bracket continuation — producing invalid YAML.

**Why structurally allowed:** Two factors. (1) The regex was authored at T-1469 to fix a sed-based orphan-continuation problem in the OTHER direction (block-style); the flow-style case wasn't in scope and no test pinned it. (2) The downstream consumer (`parse_frontmatter`) returns False on any YAML error, and Watchtower's `/review/T-XXX` route treats False as "task not found" — same surface as a missing file. The two failure modes were indistinguishable from the user's vantage point, so the failure surfaced as a route bug instead of a writer bug.

**Prevention:** (1) Regex extended with `(?!\w+:)` negative lookahead to capture continuation lines that aren't new YAML keys — accepts both block and flow continuations. (2) Bats fixture pins 6 shapes including the origin bug + idempotent cleanup. (3) `fw audit` STRUCTURE CHECKS gains a task-frontmatter parse check — any future YAML-mangling writer surfaces as a daily WARN. Defense in depth: the writer is fixed AND the audit catches it if a new writer regresses the class.

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

**Rationale:** Bug class identified empirically, fix contained to one regex + one audit check, 6/6 bats green, 4 corpus victims repaired (commit 1e0c98b4). The fix is idempotent — re-running the regex over a mangled file would now clean it up (case 3 of the bats matrix). Defense in depth via audit ensures future regressions surface daily, not weeks later via a confused user.

**Evidence:**
- `tests/unit/test_components_replacement_regex.bats` — 6/6 PASS covering flat, wrapped (origin bug), pre-mangled (idempotent cleanup), block-style, empty flow, next-key-not-eaten.
- `agents/task-create/update-task.sh:1731-1742` — regex extended with `(?!\w+:)` negative lookahead, multi-line comment captures the T-2067 rationale + T-1469 history.
- `agents/audit/audit.sh:591-620` — task-frontmatter parse check added to STRUCTURE CHECKS section, emits WARN on any broken task file.
- Corpus state after commit 1e0c98b4: 4 victims (T-2018, T-2059, T-2060, T-2061) repaired; T-1845 remains as a different-class case (folded scalar, pre-existing, not in scope here).
- `/review/T-2059`, `/review/T-2060`, `/review/T-2061` all return HTTP 200 post-repair (curl-verified).

## Decisions

### 2026-05-28 — regex shape choice

- **Chose:** Extend the existing inline regex with a negative-lookahead `(?!\w+:)` for the continuation match, keeping the inline-python approach.
- **Why:** Minimal blast radius. The inline-python pattern is well-tested in production for the block-style case (T-1469 origin); extending it preserves that behaviour and adds the flow-style branch in a single character class change. Round-trip risk is low (no yaml.safe_dump that would strip comments / reformat).
- **Rejected:** Switch to `yaml.safe_load` → mutate dict → `yaml.safe_dump`. Would handle ALL frontmatter shapes uniformly but loses comment preservation (the frontmatter has copious # commentary about field semantics that authors rely on). Larger refactor; defer.
- **Rejected:** Sed-based replacement. The original T-1469 reason for switching to python — sed left orphan continuations — would re-introduce the class.

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

### 2026-05-28T14:17:41Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2067-fix-update-tasksh-components-flow-style-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-8a6faa10
- **Timestamp:** 2026-06-02T15:00:58Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-28T14:25:21Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
