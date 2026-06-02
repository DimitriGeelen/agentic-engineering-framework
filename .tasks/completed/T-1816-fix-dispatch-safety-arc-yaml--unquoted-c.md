---
id: T-1816
name: "fix dispatch-safety arc YAML — unquoted colon in name field breaks Watchtower /arcs page"
description: >
  fix dispatch-safety arc YAML — unquoted colon in name field breaks Watchtower /arcs page

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: ["bug", "yaml", "watchtower"]
components: [C-004, lib/arc.sh, tests/unit/test_arc_system.py]
related_tasks: ["T-1812", "T-1813", "T-1815"]
arc_id: dispatch-safety
created: 2026-05-13T20:15:46Z
last_update: 2026-05-13T20:28:54Z
date_finished: 2026-05-13T20:28:54Z
---

# T-1816: fix dispatch-safety arc YAML — unquoted colon in name field breaks Watchtower /arcs page

## Context

`.context/arcs/dispatch-safety.yaml` line 2 reads `name: Dispatch safety: Worker uncertainty handling` — the unquoted colon makes YAML treat `Dispatch safety` as a key with `Worker uncertainty handling` as its value, nested inside the top-level mapping. yaml.safe_load fails with `mapping values are not allowed here`.

Result: Watchtower `/arcs/dispatch-safety` returns 404 (arc not loadable), and `_list_arcs` silently excludes it from the `/arcs` list. The human's closure UI for the dispatch-safety arc is **unreachable**. Closure command `bin/fw arc close dispatch-safety` still works (it reads the file via a different path), but the human can't visit the page that would normally guide closure.

Discovery: T-1816 was filed after the dispatch-safety arc reached 9/9 completion and the agent went to verify the human-facing closure UI surface. Without this fix, the handoff state from the prior 4 tasks (T-1812, T-1813, T-1814, T-1815) is structurally complete but operationally dark for the human.

Scope: (1) quote the name value to fix the immediate page; (2) add a structural prevention so future `fw arc create` calls quote values containing `:` — or, simpler, add an audit/lint that all `.context/arcs/*.yaml` files parse as valid YAML.

## Acceptance Criteria

### Agent
- [x] `.context/arcs/dispatch-safety.yaml` parses as valid YAML (`python3 -c "import yaml; yaml.safe_load(open(...))"` exits 0).
- [x] Watchtower `/arcs/dispatch-safety` returns HTTP 200.
- [x] Watchtower `/arcs` page lists `dispatch-safety` (curl → grep hit confirmed).
- [x] All `.context/arcs/*.yaml` files parse cleanly (all 4 verified — none have the same bug class).
- [x] Audit check (structure section) verifies all arc YAML files parse, fails on any that don't (dogfooded: temp-broken embeddings-strategy.yaml → audit FAIL surfaced with mitigation path).
- [x] `lib/arc.sh:arc_create` yaml-safe-quotes name/description/headline_mechanic via `yaml.safe_dump default_style='"'`.
- [x] Unit test pins arc_create YAML safety with colons/hashes/arrows in name and description (`test_arc_create_yaml_safe_with_colons_in_name`).
- [x] All 11 arc-system unit tests pass.

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

python3 -c "import yaml; yaml.safe_load(open('.context/arcs/dispatch-safety.yaml'))"
curl -sf -o /dev/null -w '%{http_code}' "$(bin/fw watchtower url)/arcs/dispatch-safety" | grep -q '^200$'
curl -s "$(bin/fw watchtower url)/arcs" | grep -q 'dispatch-safety'
python3 -c "import yaml, glob; [yaml.safe_load(open(f)) for f in glob.glob('.context/arcs/*.yaml')]; print('all arc yaml parse OK')"
python3 -m pytest tests/unit/test_arc_system.py -q 2>&1 | tail -3 | grep -qE "passed"
bash -n lib/arc.sh
bash -n agents/audit/audit.sh

# Original verification comment block left intact below for reference:
# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).

## RCA

**Symptom:** Watchtower `/arcs/dispatch-safety` returned 404 and `/arcs` list page silently excluded the arc, leaving the human closure UI for a 9/9-complete arc unreachable. Discovered post-arc-completion when verifying the human handoff surface (T-1815 follow-through).

**Root cause:** `.context/arcs/dispatch-safety.yaml` line 2 contained `name: Dispatch safety: Worker uncertainty handling`. The unquoted colon caused yaml.safe_load to fail with `mapping values are not allowed here`. Two consumer paths swallowed the error: (a) `web/blueprints/arcs.py:_read_arc` catches `yaml.YAMLError` and returns None → `arc_detail` → `abort(404)`; (b) `web/blueprints/arcs.py:_list_arcs` catches `yaml.YAMLError` with `continue` → arc dropped from list page.

**Why structurally allowed:** (1) `lib/arc.sh:arc_create` interpolated `${name}` and `${description}` directly into a heredoc — only `headline_mechanic` was yaml-safe-dumped. So any free-text field containing `:`, `#`, or `\n` produced broken YAML. (2) The `fw audit` YAML-parse check (T-207) scans `.context/project/*.yaml` only — arc YAMLs were outside its watch. (3) Watchtower's blueprint try/except is a defensive belt-and-suspenders pattern, but it masks the symptom rather than escalating: a broken arc YAML is silent in the UI rather than surfacing in logs or audit output.

**Prevention:**
- `lib/arc.sh:arc_create` now yaml-safe-quotes `name`, `description`, and `headline_mechanic` via `yaml.safe_dump default_style='"'`. New unit test `test_arc_create_yaml_safe_with_colons_in_name` pins this (colon + hash + arrow in name and description).
- `agents/audit/audit.sh` YAML-parse check extended to scan `.context/arcs/` in addition to `.context/project/`. Dogfooded: temp-broken arc YAML now surfaces as `[FAIL]` with mitigation path.
- The web blueprint try/except remains (defensive) — surfacing now happens at the earlier `fw audit` gate.

## Evolution

### 2026-05-13 — scope widened from one-line fix to three-layer prevention

- **What changed:** Initial filing scope was "quote the unquoted colon in dispatch-safety.yaml". Inspection of `lib/arc.sh:arc_create` revealed the generator itself produces unquoted YAML for `name`/`description` — meaning every future arc with a colon in name/description has the same bug latent. Inspection of `agents/audit/audit.sh` revealed the YAML-parse audit doesn't watch `.context/arcs/`.
- **Plan impact:** Three-layer prevention instead of single-file fix — (1) immediate file fix, (2) generator hardening with unit test, (3) audit-time detection. The web blueprint try/except is left intact (defensive — surfacing now happens at the earlier audit gate).
- **Triggered:** No new tasks filed. The scope expansion stays within one bug-class boundary (yaml-safety of arc files).

## Recommendation

- **Recommendation:** GO
- **Rationale:** Three-layer prevention restored the human's closure UI for the dispatch-safety arc and ensures the same bug class can't ship again. The web pages now load (200 OK on `/arcs/dispatch-safety`, dispatch-safety listed on `/arcs`). The audit gates new arcs at task-close time. The `arc_create` generator can no longer produce broken YAML even with adversarial inputs (colon + hash + arrow tested). 11 arc-system unit tests pass.
- **Evidence:**
  - `.context/arcs/dispatch-safety.yaml:2`: `name:` now yaml-quoted
  - `lib/arc.sh:218-227`: yaml-safe-dump of name + description + headline_mechanic
  - `agents/audit/audit.sh:549-579`: YAML-parse loop now iterates over both `.context/project/` and `.context/arcs/`
  - `tests/unit/test_arc_system.py:test_arc_create_yaml_safe_with_colons_in_name`: pins generator safety
  - Dogfood: `bash agents/audit/audit.sh --sections structure` on temp-broken arc → `[FAIL] YAML parse error` surfaced
  - curl `$(bin/fw watchtower url)/arcs/dispatch-safety` → 200
  - curl `$(bin/fw watchtower url)/arcs` → contains `dispatch-safety`

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-05-13T20:15:46Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1816-fix-dispatch-safety-arc-yaml--unquoted-c.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-834247a1
- **Timestamp:** 2026-06-02T14:59:50Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 3

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `curl -sf -o /dev/null -w '%{http_code}' "$(bin/fw watchtower url)/arcs/dispatch-safety" | grep -q '^200$'`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 3
     - evidence: `curl -s "$(bin/fw watchtower url)/arcs" | grep -q 'dispatch-safety'`
  3. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 5
     - evidence: `python3 -m pytest tests/unit/test_arc_system.py -q 2>&1 | tail -3 | grep -qE "passed"`
### 2026-05-13T20:28:54Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
