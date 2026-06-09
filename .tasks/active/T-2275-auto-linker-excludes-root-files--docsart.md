---
id: T-2275
name: "Auto-linker excludes root files + docs/articles/ — file paths in Human AC Steps
  render as <code> not <a>"
description: >
  Inception: Auto-linker excludes root files + docs/articles/ — file paths in Human
  AC Steps render as <code> not <a>

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-06-09T08:03:48Z
last_update: 2026-06-09T08:06:37Z
date_finished:
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
bvp_scores_proposed:
  - ts: '2026-06-09T08:06:37Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2275: Auto-linker excludes root files + docs/articles/ — file paths in Human AC Steps render as <code> not <a>

## Problem Statement

**Symptom (operator-observed).** On `/review/T-2274`, the Human AC Steps say:
- "Read the opening 40 lines of `README.md`"
- "Compare cadence … against `docs/articles/launch-article.md` paragraphs 1–6"

Neither is clickable. Both render as `<code>README.md</code>` and
`<code>docs/articles/launch-article.md</code>` — code spans with no anchor.
The operator opens `/review/T-XXX` expecting to navigate from each Step's
file reference straight into the file. Today they have to copy-paste paths
into a terminal or shell out to grep — friction at the exact moment when
the operator is doing the Human AC work the framework cannot do.

**Why now.** T-1722 codified the auto-linker (paths inside backticks
should become clickable). T-1575 codified the same rule for URLs. The
contract reads "any URL appearing in rendered task content [...] is
clickable, regardless of how the agent wrote it." Bare file paths are
the natural sibling — they read like URLs to a reader, and the framework
already has a `/file/<path>` route to serve them.

**Affected surfaces.** Every page that renders Markdown task content
via `render_markdown_safe` (`web/shared.py:624`): `/review/T-XXX`,
`/tasks/T-XXX`, `/inception/T-XXX`, `/approvals`, plus the task body
on cockpit and arc pages. Same renderer feeds all of them.

## Assumptions

- The `/file/<path>` route serves files only from the same whitelist
  consulted by the auto-linker (T-1764 lockstep guard, `web/shared.py:514-516`).
  Extending the whitelist must extend BOTH ends in lockstep, not just the
  regex — otherwise the linker emits anchors the route 404s.
- Path-traversal guards (`if ".." in filepath`, `web/shared.py:555-556`)
  catch `../etc/passwd`-style attacks regardless of the prefix list, so
  extending the prefix list is not a security loosening.
- Existence-gating (`(PROJECT_ROOT / path).exists()`, `web/shared.py:612`)
  prevents typos from becoming false anchors. Prose mentioning a
  non-existent file stays untouched.

Register with `fw assumption add "..." --task T-2275` if any of the
above turns out wrong during build.

## Open Questions

<!-- T-2190 (T-2186 Slice 4): every IW-N question must be disposed before
     --status work-completed. Disposition gate (agents/task-create/update-task.sh
     check_disposition_gate) refuses on under-disposed inceptions.

     Per-question shape:

       - **IW-1: <question text>**
         confidence: 0-3      (your confidence in your current answer; 0=guess, 3=verified)
         disposition: answered | deferred | dissolved
         rationale: <one-line evidence — file:line, decision id, dialogue ref>

     Never bare yes/no — the gate refuses bare checkboxes. See 050-Inceptions.md
     §Disposition Gate. Bypass: --skip-disposition-gate "rationale" (direct) or
     FW_SKIP_DISPOSITION_GATE=1 (env-var, T-1890 producer/consumer parity).
-->

- **IW-1: Which root files belong in the allowlist for Prong B?**
  confidence: 2
  disposition: answered
  rationale: README.md (root), CLAUDE.md (root), FRAMEWORK.md (root), VERSION
  (root), LICENSE (root), CHANGELOG (if/when added). These are the depth-0
  files agents reference in task ACs and Recommendation blocks. Verified via
  `ls / | grep -E "\.(md|txt)$"` on this repo. Extension whitelist already
  permits these (md/yaml/yml/py/sh/bats/json/toml — `web/shared.py:540`);
  the issue is the *directory* prefix requirement.

- **IW-2: Should the root-files rule be a special-case branch or a more
  general "depth-0 of known extension" rule?**
  confidence: 1
  disposition: deferred
  rationale: An explicit allowlist (5-6 known filenames) is more conservative
  and easier to reason about; a depth-0-of-known-extension rule covers
  unknown future root files but invites false positives (any prose mention of
  `setup.py` or `index.md` would attempt to link). Recommended candidate:
  explicit allowlist for now; revisit if the list grows organically.

- **IW-3: Are there other artefact directories outside `VIEWABLE_DIR_PREFIXES`
  that should also be added?**
  confidence: 1
  disposition: deferred
  rationale: A sweep of `docs/*/` shows `docs/articles/`, `docs/articles/deep-dives/`,
  `docs/plans/`, `docs/reports/`, `docs/dispatch-templates/`. Only `docs/reports/`
  is currently whitelisted. The other four ALL get referenced from task ACs,
  README, and FRAMEWORK.md. Recommended candidate: add all four in one pass,
  not just `docs/articles/`. Sub-scope decision for the operator.

## Exploration Plan

RCA already complete — captured below + in `docs/reports/T-2275-auto-linker-rca.md`:

1. **Read the renderer** (DONE). `web/shared.py:514-621` defines the
   auto-linker (`_auto_link_files`, T-1722) + `is_viewable_path`. Single
   source of truth: `VIEWABLE_DIR_PREFIXES` (19 entries, line 518-538) +
   `VIEWABLE_EXTENSIONS` (8 entries, line 540).
2. **Map referenced surfaces** (DONE). `render_markdown_safe` (line 624)
   is called from `web/blueprints/tasks.py` (5 call sites: 831, 832, 928,
   929, 930) and `_render_md_inline` / `_render_md_block` (line 364, 384)
   for Steps/Expected/If-not.
3. **Identify the regex behaviour** (DONE). `_build_artefact_path_re()`
   line 572-590: the regex requires `((?:dir1|dir2|...))[A-Za-z0-9_/.-]+\.(ext)`.
   Root-level files (no dir prefix) are structurally unmatched.
4. **Inspect live render of /review/T-2274** (DONE). `README.md` renders
   as `<code>README.md</code>`; `docs/articles/launch-article.md` renders
   as `<code>docs/articles/launch-article.md</code>`. Confirmed via
   `curl -s /review/T-2274 | grep -oE 'README.md.{30}'`.

No spikes needed — the fix surface is small + the test is mechanical
(curl the same page after change, look for `<a href="/file/README.md">`).

## Technical Constraints

- The auto-linker and the `/file/<path>` route MUST stay in lockstep
  (T-1764 RCA). Any change to `VIEWABLE_DIR_PREFIXES` extends both ends
  through `is_viewable_path` — no manual sync, that's the design.
- Existence-gating must remain: `_auto_link_files._replace` checks
  `(PROJECT_ROOT / path).exists()` before emitting an anchor. Any new
  prefix or root-file allowlist inherits this check for free; no extra
  guard needed.
- Path-traversal guard (`..` check in `is_viewable_path`) must stay.
- No XSS surface: the renderer runs after Markdown→HTML escaping, the
  paths are matched as literal text, not interpolated as templates.

## Scope Fence

**IN scope (this inception's GO authorises):**
- Extend `VIEWABLE_DIR_PREFIXES` (`web/shared.py:518-538`) with the
  missing artefact directories: `docs/articles/`, `docs/articles/deep-dives/`,
  `docs/plans/`, `docs/dispatch-templates/`. (Per IW-3 deferred.)
- Add a root-files allowlist to `is_viewable_path` covering: `README.md`,
  `CLAUDE.md`, `FRAMEWORK.md`, `VERSION`, `LICENSE` (and `CHANGELOG` if/when
  it exists). (Per IW-1/IW-2.)
- Update `_build_artefact_path_re()` if the root-files branch needs a
  separate regex alternation.
- Test: `tests/unit/test_auto_link_root_files.py` (or `.bats`) covering
  positive cases for each allowlisted root file + negative case for an
  arbitrary unknown root file (e.g. `random.md` not present at root).
- Visual confirmation: `curl /review/T-2274 | grep -oE '<a href="/file/README.md">'`
  returns one match after the change.

**OUT of scope:**
- General "linkify any path that looks like a file" semantic. Existence-
  gating + explicit whitelist is the design boundary.
- New routes, new template surfaces, new Markdown extensions.
- Changes to the `/file/<path>` route handler beyond the lockstep
  consultation already in place.
- Re-rendering / mass-relinking of completed task files — the renderer
  is request-time; existing tasks will auto-benefit on next view.

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [ ] Problem statement validated
<!-- @auto-tick-on-decide -->
- [ ] Assumptions tested
<!-- @auto-tick-on-decide -->
- [ ] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

<!-- Fill these BEFORE writing the recommendation. The placeholder detector will block review/decide if left empty. -->
**GO if:**
- Root cause identified with bounded fix path
- Fix is scoped, testable, and reversible

**NO-GO if:**
- Problem requires fundamental redesign or unbounded scope
- Fix cost exceeds benefit given current evidence

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).
#
# Toolchain hint (L-291): if a GO decision will mean editing *.vbproj/*.csproj/*.xaml,
# *.go, Cargo.toml, tsconfig.json, or pom.xml in the build task, plan to add the
# matching build command (dotnet build / go build / cargo check / tsc --noEmit /
# mvn compile) to that build task's ## Verification — P-011 only runs what you write.

## Recommendation

**Recommendation:** GO

**Rationale:**

Two prongs identified via RCA on /review/T-2274. Prong A: docs/articles/ is missing from web/shared.py:518-538 VIEWABLE_DIR_PREFIXES (has docs/reports/ but not docs/articles/) — 19 deep-dive articles + launch-article.md cannot become /file/ anchors. Prong B: is_viewable_path() at web/shared.py:543-562 requires startswith() match against the directory whitelist, structurally excluding all depth-0 root files (README.md, CLAUDE.md, FRAMEWORK.md, VERSION, LICENSE). Both prongs fix in one function + one regex rebuild; ~10-20 line surface. Existence-gating (PROJECT_ROOT/path).exists() and path-traversal guards (".." check) stay in place — neither prong loosens security. Candidate: extend VIEWABLE_DIR_PREFIXES with docs/articles/ + add explicit root-file allowlist (README, CLAUDE, FRAMEWORK, VERSION, LICENSE, CHANGELOG) covering the known top-level surfaces. Operator confirms scope (Prong A alone vs A+B) and root-file allowlist exhaustiveness.

**Evidence:**

- **Symptom captured live** (this session, S-2026-0609-0935):
  `curl -s http://localhost:3000/review/T-2274 | grep -oE 'README\.md.{30}'`
  → `<code>README.md</code> past the title` — code span, no anchor.
  Same shape for `docs/articles/launch-article.md` → `<code>...</code>`.
- **Renderer source identified:** `web/shared.py:514-621`:
  - `VIEWABLE_DIR_PREFIXES` (line 518-538) — 19 dirs; no `docs/articles/`,
    no root, no `docs/plans/`, no `docs/dispatch-templates/`.
  - `is_viewable_path` (line 543-562) — requires `startswith(d)` for one
    of those 19 prefixes; root-files (depth 0) structurally rejected.
  - `_build_artefact_path_re` (line 572-590) — alternates the dirs into a
    required group; root-files have no matching alternation.
  - `_auto_link_files._replace` (line 610-619) — existence-gated
    `(PROJECT_ROOT / path).exists()`, preserves backticks.
- **Lockstep guard** documented (T-1764, line 514-516): "Both the
  auto-linker (T-1722) and the /file/ route (T-632) consult these.
  Diverging them — as happened pre-T-1764 — means the linker emits
  anchors the route can't serve (HTTP 404), silently breaking T-1722's
  contract." → extending the whitelist extends BOTH; no separate
  route changes needed.
- **Fix shape estimate:** ~5-10 lines in `web/shared.py` (add `docs/articles/`
  and siblings to `VIEWABLE_DIR_PREFIXES`; add `ROOT_FILES = frozenset(...)`;
  branch in `is_viewable_path`; either extend the regex with a depth-0
  alternation or add a second regex pass for root files).
- **Test surface:** one `.bats` or one `.py` file covering positive
  cases (all 5-6 root files + each new directory prefix) + negative
  cases (typo, non-existent file, path with `..`).
- **Cross-link:** RCA detail in `docs/reports/T-2275-auto-linker-rca.md`
  (this session).

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

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-06-09T08:06:37Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
